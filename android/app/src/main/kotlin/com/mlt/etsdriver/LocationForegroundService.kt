package com.mlt.etsdriver

import android.app.*
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.location.Location
import android.location.LocationManager
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.os.*
import android.util.Log
import androidx.core.app.NotificationCompat
import com.google.android.gms.location.*
import kotlinx.coroutines.*
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlin.coroutines.coroutineContext
import java.io.OutputStreamWriter
import java.net.HttpURLConnection
import java.net.URL
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class LocationForegroundService : Service() {

    companion object {
        const val TAG = "MLT_TrackingService"
        const val CHANNEL_ID = "mlt_tracking_channel"
        const val NOTIF_ID = 1001
        const val NOTIF_ALERT_ID = 1002
        const val PREFS_NAME = "FlutterSharedPreferences"   // flutter shared_prefs namespace
        const val KEY_ROUTE_ID = "flutter.active_route_id"
        const val KEY_TOKEN = "flutter.bg_access_token"
        const val KEY_DRIVER_ID = "flutter.driver_id"
        const val KEY_TENANT_ID = "flutter.tenant_id"
        const val KEY_VENDOR_ID = "flutter.vendor_id"
        const val PING_INTERVAL_MS = 7_000L   // 7 seconds — matches spec (5–10 s)
        const val BASE_URL = "https://api.mltcorporate.com"
        const val ACTION_START = "com.mlt.etsdriver.START_TRACKING"
        const val ACTION_STOP = "com.mlt.etsdriver.STOP_TRACKING"
        const val HEARTBEAT_INTERVAL_MS = 300_000L // 5 minutes

        @Volatile
        var isServiceRunning = false
    }

    private lateinit var fusedLocationClient: FusedLocationProviderClient
    private lateinit var locationCallback: LocationCallback
    private lateinit var prefs: SharedPreferences
    private val serviceScope = CoroutineScope(Dispatchers.IO + SupervisorJob())

    // Last known location — updated by FusedLocationProvider
    @Volatile private var lastLocation: Location? = null
    // Ping timer job
    private var pingJob: Job? = null
    private var isLocationUpdatesActive = false
    private var networkCallback: ConnectivityManager.NetworkCallback? = null

    // Offline storage & heartbeat properties
    private lateinit var dbHelper: LocationDbHelper
    private var wakeLock: PowerManager.WakeLock? = null
    private var heartbeatJob: Job? = null
    private val uploadMutex = Mutex()

    // Auth infrastructure
    private lateinit var tokenRepository: DriverTokenRepository
    private lateinit var authHttpClient: NativeAuthHttpClient
    private lateinit var refreshCoordinator: DriverTokenRefreshCoordinator

    // ─────────────────────────────────────────────────────────────────────────
    // Lifecycle
    // ─────────────────────────────────────────────────────────────────────────

    override fun onCreate() {
        super.onCreate()
        Log.i(TAG, "Service onCreate")
        isServiceRunning = true
        dbHelper = LocationDbHelper(this)
        prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        fusedLocationClient = LocationServices.getFusedLocationProviderClient(this)
        createNotificationChannel()
        registerNetworkCallback()

        // Initialize shared token repository
        tokenRepository = DriverTokenRepository.getInstance(this)
        authHttpClient = NativeAuthHttpClient(BASE_URL)
        refreshCoordinator = DriverTokenRefreshCoordinator(tokenRepository, authHttpClient)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val action = intent?.action ?: ACTION_START
        Log.i(TAG, "onStartCommand: action=$action")

        // ── CRITICAL: Android requires startForeground() to be called within 5 seconds
        // of startForegroundService(), before ANY early returns. Failure to do so causes
        // ForegroundServiceDidNotStartInTimeException and a fatal crash.
        // We always call it here first, then immediately stop if there's nothing to track.
        startForegroundWithNotification()

        when (action) {
            ACTION_STOP -> {
                Log.i(TAG, "STOP action received — stopping service")
                stopForegroundService()
                return START_NOT_STICKY
            }
            else -> {
                val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                nm.cancel(NOTIF_ALERT_ID)

                val routeId = prefs.getString(KEY_ROUTE_ID, "") ?: ""
                if (routeId.isEmpty()) {
                    Log.w(TAG, "No active_route_id — stopping service")
                    stopForegroundService()
                    return START_NOT_STICKY
                }

                // Guard: service is already running & tracking
                if (isLocationUpdatesActive) {
                    Log.i(TAG, "Tracking is already active. Skipping redundant initialization.")
                    val timeString = SimpleDateFormat("h:mm a", Locale.getDefault()).format(Date())
                    updateNotification(routeId, timeString)
                    return START_STICKY
                }

                Log.i(TAG, "START action for route=$routeId")
                acquireWakeLock()
                startLocationUpdates()
                startPingLoop()
                startHeartbeatLoop()
            }
        }
        // START_STICKY: system restarts service with null intent if killed
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    // ─────────────────────────────────────────────────────────────────────────
    // Survive swipe-from-recents
    // ─────────────────────────────────────────────────────────────────────────
    // Called by Android when the user removes the task from recents.
    // stopWithTask="false" in manifest keeps us alive, but some OEMs still kill
    // the process. Scheduling a restart via AlarmManager ensures we come back.
    override fun onTaskRemoved(rootIntent: Intent?) {
        super.onTaskRemoved(rootIntent)
        Log.i(TAG, "onTaskRemoved — scheduling service restart via AlarmManager")

        val routeId = prefs.getString(KEY_ROUTE_ID, "") ?: ""
        val token   = prefs.getString(KEY_TOKEN, "") ?: ""

        // Only restart if there is an active trip to track
        if (routeId.isEmpty() || token.isEmpty()) {
            Log.i(TAG, "No active route/token — not scheduling restart")
            return
        }

        // Show a high-priority heads-up/floating notification
        showFloatingAlertNotification()

        val restartIntent = Intent(applicationContext, LocationForegroundService::class.java).apply {
            action = ACTION_START
        }
        val pendingIntent = PendingIntent.getService(
            applicationContext,
            1001,
            restartIntent,
            PendingIntent.FLAG_ONE_SHOT or PendingIntent.FLAG_IMMUTABLE
        )
        val am = getSystemService(Context.ALARM_SERVICE) as AlarmManager
        // Restart after 1 second — fast enough to feel seamless
        val triggerAt = SystemClock.elapsedRealtime() + 1_000L
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            if (am.canScheduleExactAlarms()) {
                am.setExactAndAllowWhileIdle(AlarmManager.ELAPSED_REALTIME_WAKEUP, triggerAt, pendingIntent)
            } else {
                am.setAndAllowWhileIdle(AlarmManager.ELAPSED_REALTIME_WAKEUP, triggerAt, pendingIntent)
            }
        } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            am.setExactAndAllowWhileIdle(AlarmManager.ELAPSED_REALTIME_WAKEUP, triggerAt, pendingIntent)
        } else {
            am.setExact(AlarmManager.ELAPSED_REALTIME_WAKEUP, triggerAt, pendingIntent)
        }
        Log.i(TAG, "Service restart scheduled in 1 second")
    }

    private fun showFloatingAlertNotification() {
        val alertChannelId = "mlt_driver_alert_channel"
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                alertChannelId,
                "MLT Driver Alerts",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "High priority alerts for active rides"
                enableVibration(true)
                setShowBadge(true)
            }
            val nm = getSystemService(NotificationManager::class.java)
            nm?.createNotificationChannel(channel)
        }

        val openAppIntent = packageManager.getLaunchIntentForPackage(packageName)?.apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val pendingIntent = PendingIntent.getActivity(
            this, 2, openAppIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val notification = NotificationCompat.Builder(this, alertChannelId)
            .setContentTitle("Ride Ongoing 🚖")
            .setContentText("Your active trip is running. Tap to reopen the app.")
            .setSmallIcon(android.R.drawable.ic_menu_mylocation)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setDefaults(NotificationCompat.DEFAULT_ALL)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setAutoCancel(true)
            .build()

        val nm = getSystemService(NotificationManager::class.java)
        nm?.notify(NOTIF_ALERT_ID, notification)
    }

    override fun onDestroy() {
        Log.i(TAG, "Service onDestroy")
        isServiceRunning = false
        pingJob?.cancel()
        heartbeatJob?.cancel()
        serviceScope.cancel()
        unregisterNetworkCallback()
        releaseWakeLock()
        if (isLocationUpdatesActive && ::locationCallback.isInitialized) {
            fusedLocationClient.removeLocationUpdates(locationCallback)
        }
        super.onDestroy()
    }

    private fun registerNetworkCallback() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            try {
                val cm = getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
                networkCallback = object : ConnectivityManager.NetworkCallback() {
                    override fun onAvailable(network: Network) {
                        super.onAvailable(network)
                        Log.i(TAG, "Network available — triggering offline queue upload")
                        serviceScope.launch(Dispatchers.IO) {
                            uploadPendingLocations()
                        }
                    }
                }
                cm.registerDefaultNetworkCallback(networkCallback!!)
            } catch (e: Exception) {
                Log.e(TAG, "Failed to register network callback: ${e.message}")
            }
        }
    }

    private fun unregisterNetworkCallback() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N && networkCallback != null) {
            try {
                val cm = getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
                cm.unregisterNetworkCallback(networkCallback!!)
            } catch (e: Exception) {
                Log.e(TAG, "Failed to unregister network callback: ${e.message}")
            }
            networkCallback = null
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Foreground notification
    // ─────────────────────────────────────────────────────────────────────────

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "MLT Driver Tracking",
                NotificationManager.IMPORTANCE_LOW   // LOW = no sound, but stays visible
            ).apply {
                description = "Keeps trip tracking active in background"
                setShowBadge(false)
            }
            val nm = getSystemService(NotificationManager::class.java)
            nm.createNotificationChannel(channel)
        }
    }

    private fun buildNotification(routeId: String = "", lastUpdateTime: String = ""): Notification {
        // Tapping notification opens the app
        val openAppIntent = packageManager.getLaunchIntentForPackage(packageName)?.apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val pendingIntent = PendingIntent.getActivity(
            this, 0, openAppIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val endDutyIntent = packageManager.getLaunchIntentForPackage(packageName)?.apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
            action = "com.mlt.etsdriver.ACTION_END_DUTY"
        }
        val endDutyPendingIntent = PendingIntent.getActivity(
            this, 1, endDutyIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val contentText = "Trip tracking active"

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("MLT Driver")
            .setContentText(contentText)
            .setStyle(NotificationCompat.BigTextStyle().bigText(contentText))
            .setSmallIcon(android.R.drawable.ic_menu_mylocation)
            .setOngoing(true)           // Cannot be dismissed by user
            .setAutoCancel(false)
            .setContentIntent(pendingIntent)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .addAction(android.R.drawable.ic_menu_close_clear_cancel, "End Duty", endDutyPendingIntent)
            .addAction(android.R.drawable.ic_menu_view, "Open App", pendingIntent)
            .build()
    }

    private fun startForegroundWithNotification() {
        val routeId = prefs.getString(KEY_ROUTE_ID, "") ?: ""
        val notification = buildNotification(routeId, "")
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(NOTIF_ID, notification, android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION)
        } else {
            startForeground(NOTIF_ID, notification)
        }
    }

    private fun updateNotification(routeId: String, lastUpdateTime: String) {
        val notification = buildNotification(routeId, lastUpdateTime)
        val nm = getSystemService(NotificationManager::class.java)
        nm.notify(NOTIF_ID, notification)
    }

    private fun stopForegroundService() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
        if (isLocationUpdatesActive && ::locationCallback.isInitialized) {
            fusedLocationClient.removeLocationUpdates(locationCallback)
            isLocationUpdatesActive = false
        }
        stopSelf()
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Location updates (FusedLocationProvider — battery efficient)
    // ─────────────────────────────────────────────────────────────────────────

    private fun startLocationUpdates() {
        if (isLocationUpdatesActive) {
            Log.i(TAG, "Location updates already active, skipping re-registration")
            return
        }

        val request = LocationRequest.Builder(Priority.PRIORITY_HIGH_ACCURACY, PING_INTERVAL_MS)
            .setMinUpdateIntervalMillis(PING_INTERVAL_MS / 2)
            .setMaxUpdateDelayMillis(PING_INTERVAL_MS)
            .build()

        locationCallback = object : LocationCallback() {
            override fun onLocationResult(result: LocationResult) {
                result.lastLocation?.let {
                    // Accuracy filter: discard fixes with accuracy > 100 meters
                    if (it.hasAccuracy() && it.accuracy > 100f) {
                        Log.w(TAG, "Ignoring poor accuracy location fix: ${it.accuracy}m")
                        return
                    }
                    lastLocation = it
                    Log.i(TAG, "📍 FusedLocation received: Lat=${it.latitude}, Lng=${it.longitude}, Acc=${it.accuracy}m, Speed=${it.speed * 3.6} km/h")
                }
            }
        }

        try {
            fusedLocationClient.requestLocationUpdates(request, locationCallback, Looper.getMainLooper())
            isLocationUpdatesActive = true
            Log.i(TAG, "FusedLocation updates started")
        } catch (e: SecurityException) {
            Log.e(TAG, "Location permission missing: ${e.message}")
            stopForegroundService()
        }
    }

    private fun getPingIntervalMs(): Long {
        val intervalSec = try {
            prefs.getLong("flutter.upload_interval_seconds", 7L)
        } catch (e: ClassCastException) {
            prefs.getInt("flutter.upload_interval_seconds", 7).toLong()
        }
        return intervalSec * 1000L
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Ping loop — enqueues location & triggers upload oldest first
    // ─────────────────────────────────────────────────────────────────────────

    private fun startPingLoop() {
        pingJob?.cancel()
        pingJob = serviceScope.launch {
            Log.i(TAG, "Ping loop started")
            while (isActive) {
                val interval = getPingIntervalMs()
                val routeId = prefs.getString(KEY_ROUTE_ID, "") ?: ""
                if (routeId.isEmpty()) {
                    Log.i(TAG, "Route cleared — stopping service from ping loop")
                    withContext(Dispatchers.Main) { stopForegroundService() }
                    break
                }
                val loc = lastLocation
                if (loc != null) {
                    val speedKmh = if (loc.hasSpeed()) loc.speed * 3.6 else null
                    dbHelper.enqueueLocation(routeId, loc.latitude, loc.longitude, speedKmh)
                } else {
                    Log.w(TAG, "No location fix yet — skipping DB queue enqueue")
                }
                
                // Trigger background upload
                uploadPendingLocations()
                
                delay(interval)
            }
        }
    }

    private suspend fun uploadPendingLocations() {
        if (uploadMutex.isLocked) return
        uploadMutex.withLock {
            val tokens = tokenRepository.readTokens()
            if (tokens.accessToken.isEmpty()) {
                Log.w(TAG, "No access token — skipping upload")
                return
            }

            val authState = tokenRepository.getAuthenticationState()
            if (authState == DriverTokenRepository.AuthenticationState.REQUIRES_LOGIN) {
                Log.w(TAG, "Auth requires login — stopping authenticated uploads")
                return
            }

            while (coroutineContext.isActive) {
                val queued = dbHelper.getOldestLocation() ?: break
                val success = sendLocationPingWithRefresh(queued)
                if (success) {
                    dbHelper.deleteLocation(queued.id)
                } else {
                    Log.w(TAG, "Failed to upload location ID ${queued.id} — stopping queue upload")
                    break
                }
            }
        }
    }

    private suspend fun sendLocationPingWithRefresh(queued: QueuedLocation): Boolean {
        if (tokenRepository.getAuthenticationState() == DriverTokenRepository.AuthenticationState.REQUIRES_LOGIN) {
            Log.w(TAG, "Auth requires login — not uploading location")
            return false
        }

        val tokens = tokenRepository.readTokens()
        if (tokens.accessToken.isEmpty()) return false

        val result = sendLocationPingSync(queued, tokens.accessToken)
        if (result) return true

        val currentTokens = tokenRepository.readTokens()
        val latestToken = currentTokens.accessToken
        if (latestToken != tokens.accessToken && latestToken.isNotEmpty()) {
            Log.i(TAG, "Token changed externally — retrying with latest")
            return sendLocationPingSync(queued, latestToken)
        }

        val httpResult = executeLocationPing(queued, tokens.accessToken)
        if (httpResult == null) return false
        if (httpResult.statusCode != 401) return false

        Log.i(TAG, "Location upload received 401 — attempting token refresh")
        return performLocationRefreshRetry(queued, tokens.accessToken, httpResult)
    }

    private suspend fun performLocationRefreshRetry(
        queued: QueuedLocation,
        usedToken: String,
        httpResult: NativeAuthHttpClient.HttpResult
    ): Boolean {
        if (httpResult.responseBody.isNotEmpty()) {
            val classifyResult = AuthErrorClassifier.classify(httpResult.statusCode, httpResult.responseBody)
            if (classifyResult is AuthPermanentFailure) {
                Log.w(TAG, "Permanent auth failure: ${classifyResult.code} — marking requires login")
                tokenRepository.markRequiresLogin()
                return false
            }
        }

        val refreshResult = refreshCoordinator.refreshForToken(usedToken)

        return when (refreshResult) {
            is DriverTokenRefreshCoordinator.RefreshResult.Success -> {
                Log.i(TAG, "Refresh succeeded — retrying location upload")
                sendLocationPingSync(queued, refreshResult.newAccessToken)
            }
            is DriverTokenRefreshCoordinator.RefreshResult.NotNeeded -> {
                Log.i(TAG, "Token already refreshed — retrying with latest")
                sendLocationPingSync(queued, refreshResult.accessToken)
            }
            is DriverTokenRefreshCoordinator.RefreshResult.PermanentFailure -> {
                Log.w(TAG, "Refresh permanent failure: ${refreshResult.code}")
                false
            }
            is DriverTokenRefreshCoordinator.RefreshResult.TemporaryFailure -> {
                Log.w(TAG, "Refresh temporary failure: ${refreshResult.message}")
                false
            }
        }
    }

    private fun executeLocationPing(queued: QueuedLocation, token: String): NativeAuthHttpClient.HttpResult? {
        val headers = mutableMapOf<String, String>()
        val driverId = prefs.getString(KEY_DRIVER_ID, "") ?: ""
        val tenantId = prefs.getString(KEY_TENANT_ID, "") ?: ""
        val vendorId = prefs.getString(KEY_VENDOR_ID, "") ?: ""
        if (driverId.isNotEmpty()) headers["X-Driver-Id"] = driverId
        if (tenantId.isNotEmpty()) headers["X-Tenant-Id"] = tenantId
        if (vendorId.isNotEmpty()) headers["X-Vendor-Id"] = vendorId

        val speedKmh = queued.speed
        val queryParams = mutableMapOf(
            "route_id" to queued.routeId,
            "latitude" to queued.latitude.toString(),
            "longitude" to queued.longitude.toString()
        )
        if (speedKmh != null) {
            queryParams["speed"] = "%.2f".format(speedKmh)
        }

        return try {
            authHttpClient.sendAuthenticatedPost(
                urlString = "$BASE_URL/api/v1/driver/location",
                accessToken = token,
                queryParams = queryParams,
                headers = headers
            )
        } catch (e: Exception) {
            null
        }
    }

    private fun sendLocationPingSync(queued: QueuedLocation, token: String): Boolean {
        val speedKmh = queued.speed
        val url = "$BASE_URL/api/v1/driver/location" +
                "?route_id=${queued.routeId}" +
                "&latitude=${queued.latitude}" +
                "&longitude=${queued.longitude}" +
                (if (speedKmh != null) "&speed=${"%.2f".format(speedKmh)}" else "")

        try {
            val driverId = prefs.getString(KEY_DRIVER_ID, "") ?: ""
            val tenantId = prefs.getString(KEY_TENANT_ID, "") ?: ""
            val vendorId = prefs.getString(KEY_VENDOR_ID, "") ?: ""

            Log.d(TAG, "╔══ 🌐 KOTLIN BACKGROUND REQUEST ════════════════════════════")
            Log.d(TAG, "║ Method: POST")
            Log.d(TAG, "║ URL: $url")
            Log.d(TAG, "║ Headers:")
            Log.d(TAG, "║   Authorization: Bearer ...${token.takeLast(10)}")
            if (driverId.isNotEmpty()) Log.d(TAG, "║   X-Driver-Id: $driverId")
            if (tenantId.isNotEmpty()) Log.d(TAG, "║   X-Tenant-Id: $tenantId")
            if (vendorId.isNotEmpty()) Log.d(TAG, "║   X-Vendor-Id: $vendorId")
            Log.d(TAG, "╚════════════════════════════════════════════════════════════")

            val conn = URL(url).openConnection() as HttpURLConnection
            conn.apply {
                requestMethod = "POST"
                setRequestProperty("Authorization", "Bearer $token")
                setRequestProperty("Content-Type", "application/json")
                setRequestProperty("Accept", "application/json")
                if (driverId.isNotEmpty()) setRequestProperty("X-Driver-Id", driverId)
                if (tenantId.isNotEmpty()) setRequestProperty("X-Tenant-Id", tenantId)
                if (vendorId.isNotEmpty()) setRequestProperty("X-Vendor-Id", vendorId)

                connectTimeout = 15_000
                readTimeout = 15_000
                doOutput = true
                OutputStreamWriter(outputStream).use { it.write("") }
            }
            val code = conn.responseCode
            val responseBody = try {
                if (code in 200..299) {
                    conn.inputStream.bufferedReader().use { it.readText() }
                } else {
                    conn.errorStream?.bufferedReader()?.use { it.readText() } ?: ""
                }
            } catch (ex: Exception) {
                "Failed to read body: ${ex.message}"
            }
            conn.disconnect()

            Log.d(TAG, "╔══ ✅ KOTLIN BACKGROUND RESPONSE ═══════════════════════════")
            Log.d(TAG, "║ Status: $code")
            Log.d(TAG, "║ Body: $responseBody")
            Log.d(TAG, "╚════════════════════════════════════════════════════════════")

            if (code in 200..299) {
                val timeString = SimpleDateFormat("h:mm a", Locale.getDefault()).format(Date(queued.timestamp))
                updateNotification(queued.routeId, timeString)
                return true
            } else {
                return false
            }
        } catch (e: Exception) {
            Log.w(TAG, "❌ Location upload exception: ${e.message}")
            return false
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Heartbeat Loop (Metrics: Battery, GPS, Network Type, version)
    // ─────────────────────────────────────────────────────────────────────────

    private fun startHeartbeatLoop() {
        heartbeatJob?.cancel()
        heartbeatJob = serviceScope.launch {
            Log.i(TAG, "Heartbeat loop started")
            while (isActive) {
                sendHeartbeat()
                delay(HEARTBEAT_INTERVAL_MS)
            }
        }
    }

    private fun sendHeartbeat() {
        val routeId = prefs.getString(KEY_ROUTE_ID, "") ?: ""
        if (routeId.isEmpty()) {
            Log.w(TAG, "No active route for heartbeat")
            return
        }

        if (tokenRepository.getAuthenticationState() == DriverTokenRepository.AuthenticationState.REQUIRES_LOGIN) {
            Log.w(TAG, "Auth requires login — skipping heartbeat")
            return
        }

        val tokens = tokenRepository.readTokens()
        if (tokens.accessToken.isEmpty()) {
            Log.w(TAG, "No access token for heartbeat")
            return
        }

        val battery = getBatteryPercentage()
        val gps = isGpsEnabled()
        val network = getNetworkType()
        val version = getAppVersion()
        val tracking = isServiceRunning

        val queryParams = mutableMapOf(
            "route_id" to routeId,
            "battery" to battery.toString(),
            "gps_enabled" to gps.toString(),
            "network" to network,
            "version" to version,
            "tracking_active" to tracking.toString()
        )

        val headers = mutableMapOf<String, String>()
        val driverId = prefs.getString(KEY_DRIVER_ID, "") ?: ""
        val tenantId = prefs.getString(KEY_TENANT_ID, "") ?: ""
        val vendorId = prefs.getString(KEY_VENDOR_ID, "") ?: ""
        if (driverId.isNotEmpty()) headers["X-Driver-Id"] = driverId
        if (tenantId.isNotEmpty()) headers["X-Tenant-Id"] = tenantId
        if (vendorId.isNotEmpty()) headers["X-Vendor-Id"] = vendorId

        serviceScope.launch(Dispatchers.IO) {
            try {
                var result = authHttpClient.sendAuthenticatedPost(
                    urlString = "$BASE_URL/api/v1/driver/heartbeat",
                    accessToken = tokens.accessToken,
                    queryParams = queryParams,
                    headers = headers
                )

                if (result.statusCode == 401) {
                    Log.i(TAG, "Heartbeat received 401 — attempting refresh")
                    val refreshResult = refreshCoordinator.refreshForToken(tokens.accessToken)

                    when (refreshResult) {
                        is DriverTokenRefreshCoordinator.RefreshResult.Success -> {
                            Log.i(TAG, "Heartbeat refresh succeeded — retrying")
                            result = authHttpClient.sendAuthenticatedPost(
                                urlString = "$BASE_URL/api/v1/driver/heartbeat",
                                accessToken = refreshResult.newAccessToken,
                                queryParams = queryParams,
                                headers = headers
                            )
                        }
                        is DriverTokenRefreshCoordinator.RefreshResult.NotNeeded -> {
                            Log.i(TAG, "Heartbeat token already refreshed — retrying")
                            result = authHttpClient.sendAuthenticatedPost(
                                urlString = "$BASE_URL/api/v1/driver/heartbeat",
                                accessToken = refreshResult.accessToken,
                                queryParams = queryParams,
                                headers = headers
                            )
                        }
                        is DriverTokenRefreshCoordinator.RefreshResult.PermanentFailure -> {
                            Log.w(TAG, "Heartbeat refresh permanent failure: ${refreshResult.code}")
                            tokenRepository.markRequiresLogin()
                        }
                        is DriverTokenRefreshCoordinator.RefreshResult.TemporaryFailure -> {
                            Log.w(TAG, "Heartbeat refresh temporary failure — will retry next cycle")
                        }
                    }
                }

                Log.d(TAG, "Heartbeat result: status=${result.statusCode}")
            } catch (e: Exception) {
                Log.w(TAG, "❌ Heartbeat execution exception: ${e.message}")
            }
        }
    }

    private fun getBatteryPercentage(): Int {
        val bm = getSystemService(Context.BATTERY_SERVICE) as BatteryManager
        return bm.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY)
    }

    private fun isGpsEnabled(): Boolean {
        val lm = getSystemService(Context.LOCATION_SERVICE) as LocationManager
        return lm.isProviderEnabled(LocationManager.GPS_PROVIDER)
    }

    private fun getNetworkType(): String {
        val cm = getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val activeNet = cm.activeNetwork ?: return "Offline"
            val caps = cm.getNetworkCapabilities(activeNet) ?: return "Offline"
            return when {
                caps.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) -> "WiFi"
                caps.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) -> "Cellular"
                else -> "Other"
            }
        } else {
            @Suppress("DEPRECATION")
            val info = cm.activeNetworkInfo
            if (info == null || !info.isConnected) return "Offline"
            return when (info.type) {
                ConnectivityManager.TYPE_WIFI -> "WiFi"
                ConnectivityManager.TYPE_MOBILE -> "Cellular"
                else -> "Other"
            }
        }
    }

    private fun getAppVersion(): String {
        return try {
            val packageInfo = packageManager.getPackageInfo(packageName, 0)
            packageInfo.versionName ?: "Unknown"
        } catch (e: Exception) {
            "Unknown"
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // WakeLock management
    // ─────────────────────────────────────────────────────────────────────────

    private fun acquireWakeLock() {
        if (wakeLock == null) {
            val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
            wakeLock = pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "MLT:LocationTrackingWakeLock").apply {
                acquire()
            }
            Log.i(TAG, "Partial WakeLock acquired")
        }
    }

    private fun releaseWakeLock() {
        wakeLock?.let {
            if (it.isHeld) {
                it.release()
                Log.i(TAG, "Partial WakeLock released")
            }
            wakeLock = null
        }
    }
}
