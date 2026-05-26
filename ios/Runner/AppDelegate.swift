import Flutter
import UIKit
import FirebaseCore
import FirebaseMessaging

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Configure Firebase natively FIRST so it is ready before the APNs token
    // callback fires. Without this, FirebaseApp.app() is nil when
    // didRegisterForRemoteNotificationsWithDeviceToken is called, causing
    // the APNs token to be silently dropped → getToken() always returns nil.
    // GoogleService-Info.plist must be in the bundle (added to Xcode target).
    if FirebaseApp.app() == nil {
      FirebaseApp.configure()
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // Forward the APNs device token to Firebase Messaging explicitly.
  // Firebase swizzling should also catch this, but an explicit set is
  // a safety net for edge cases.
  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    if FirebaseApp.app() != nil {
      Messaging.messaging().apnsToken = deviceToken
      print("✅ APNs token forwarded to Firebase (\(deviceToken.count) bytes)")
    } else {
      print("⚠️ APNs token received but Firebase not yet initialized")
    }
    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
  }

  override func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    print("❌ Failed to register for remote notifications: \(error)")
    super.application(application, didFailToRegisterForRemoteNotificationsWithError: error)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    // Register all plugins (sets up Flutter↔native method channels).
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    // Firebase was already configured in didFinishLaunchingWithOptions,
    // so it is safe to register for APNs now — swizzling is in place and
    // FirebaseApp.app() != nil when the token callback fires.
    UIApplication.shared.registerForRemoteNotifications()
    print("✅ registerForRemoteNotifications() called (Firebase already configured)")
  }
}
