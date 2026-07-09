import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants/app_theme.dart';
import '../widgets/fx_widgets.dart';
import '../widgets/skeletons.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';
import 'dart:ui' as ui;
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';

class TrackDriverScreen extends StatefulWidget {
  final Map<String, dynamic> booking;
  final String? tenantId;

  const TrackDriverScreen({super.key, required this.booking, this.tenantId});

  @override
  State<TrackDriverScreen> createState() => _TrackDriverScreenState();
}

class _TrackDriverScreenState extends State<TrackDriverScreen> {
  final Completer<GoogleMapController> _controller = Completer();
  DatabaseReference? _driverRef;
  StreamSubscription<DatabaseEvent>? _driverSubscription;
  Timer? _timeoutTimer;

  LatLng? _driverLocation;
  LatLng? _destinationLocation;
  Map<String, dynamic>? _driverData;
  bool _isLoading = true;
  String? _error;
  
  // Debug Vars
  String _debugPath = 'Initializing...';
  String _debugTenantId = '';
  String _debugDriverId = '';
  
  BitmapDescriptor? _driverIcon;
  BitmapDescriptor? _destinationIcon;
  Set<Polyline> _polylines = {};
  bool _hasFetchedRoute = false;

  @override
  void initState() {
    super.initState();
    _loadCustomMarkers();
    _initTracking();
  }

  @override
  void dispose() {
    _driverSubscription?.cancel();
    _timeoutTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadCustomMarkers() async {
    _driverIcon = await _createCustomMarkerBitmap('🚗', const Color(0xFF6C63FF));
    
    final status = widget.booking['status'];
    final isPickup = status == 'Scheduled' || status == 'Request';
    final emoji = isPickup ? '🏁' : '🎯';
    
    _destinationIcon = await _createCustomMarkerBitmap(emoji, const Color(0xFF00b894));
    
    if (mounted) setState(() {});
  }

  Future<BitmapDescriptor> _createCustomMarkerBitmap(String emoji, Color color) async {
    final pictureRecorder = ui.PictureRecorder();
    final canvas = Canvas(pictureRecorder);
    const size = Size(100, 100);
    
    final paint = Paint()..color = color;
    final strokePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8;

    canvas.drawCircle(const Offset(50, 50), 40, paint);
    canvas.drawCircle(const Offset(50, 50), 40, strokePaint);

    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );
    textPainter.text = TextSpan(
      text: emoji,
      style: const TextStyle(fontSize: 40),
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset(50 - textPainter.width / 2, 50 - textPainter.height / 2));

    final picture = pictureRecorder.endRecording();
    final img = await picture.toImage(100, 100);
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    
    return BitmapDescriptor.fromBytes(byteData!.buffer.asUint8List());
  }

  Future<void> _initTracking() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _hasFetchedRoute = false;
      _polylines.clear();
    });

    // Start 10s Timeout
    _timeoutTimer?.cancel();
    _timeoutTimer = Timer(const Duration(seconds: 10), () {
      if (mounted && _isLoading) {
        setState(() {
          _isLoading = false;
          _error = 'Timeout: Driver location not found.';
        });
      }
    });

    final booking = widget.booking;
    
    // Set destination
    double destLat;
    double destLng;
    
    final status = booking['status'];
    final isGoingToPickup = status == 'Scheduled' || status == 'Request';

    if (isGoingToPickup) {
        destLat = double.tryParse(booking['pickup_latitude']?.toString() ?? '0') ?? 0;
        destLng = double.tryParse(booking['pickup_longitude']?.toString() ?? '0') ?? 0;
    } else {
        destLat = double.tryParse(booking['drop_latitude']?.toString() ?? '0') ?? 0;
        destLng = double.tryParse(booking['drop_longitude']?.toString() ?? '0') ?? 0;
    }

    if (destLat != 0 && destLng != 0) {
       _destinationLocation = LatLng(destLat, destLng);
    }

    final routeDetails = booking['route_details'];
    if (routeDetails != null && routeDetails['driver_details'] != null) {
        final driverId = routeDetails['driver_details']['driver_id'];

        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        
        // Fetch from SharedPreferences as the ultimate fallback/source of truth
        final prefs = await SharedPreferences.getInstance();
        final prefsTenantId = prefs.getString('tenant_id');
        
        // Prioritize: Prefs (Source of Truth) -> Auth User -> Widget Arg -> Booking -> Default 'SAM001'
        String tenantId = prefsTenantId ?? authProvider.user?.tenantId ?? widget.tenantId ?? booking['tenant_id']?.toString() ?? 'SAM001';
        
        // Handle case where API might return "1" as tenant_id, explicitly ignore it if we have a better one.
        if (tenantId == '1' && (prefsTenantId != null || authProvider.user?.tenantId != null)) {
            tenantId = prefsTenantId ?? authProvider.user!.tenantId!;
        }
        
        final vendorId = routeDetails['vendor_details']?['vendor_id'] ?? '1';

        // Capture for Debug View
        _debugTenantId = tenantId;
        _debugDriverId = driverId.toString();

        print('TRACKING DEBUG: Resolved IDs. Tenant: $tenantId, Vendor: $vendorId, Driver: $driverId');

        if (driverId != null) {
            _subscribeToFirebase(tenantId.toString(), vendorId.toString(), driverId.toString());
        } else {
            _fail('Invalid Driver ID');
        }
    } else {
         _fail('Driver details not available');
    }
  }

  void _fail(String message) {
    _timeoutTimer?.cancel();
    if (mounted) {
       setState(() {
         _isLoading = false;
         _error = message;
       });
    }
  }

  void _subscribeToFirebase(String tenantId, String vendorId, String driverId) {
      final path = 'drivers/$tenantId/$vendorId/$driverId';
      _debugPath = path;
      print('TRACKING DEBUG: Subscribing to path: $path');
      
      _driverRef = FirebaseDatabase.instance.ref(path);
      
      _driverSubscription = _driverRef!.onValue.listen((event) {
          final data = event.snapshot.value;
          // print('TRACKING DEBUG: Data received: $data'); // Comment out to reduce noise if needed
          
          if (data != null && data is Map) {
             _timeoutTimer?.cancel(); // Success!
             
             final lat = double.tryParse(data['latitude']?.toString() ?? '');
             final lng = double.tryParse(data['longitude']?.toString() ?? '');
             
             if (lat != null && lng != null) {
                 final newLocation = LatLng(lat, lng);
                 if (mounted) {
                   setState(() {
                      _driverLocation = newLocation;
                      _driverData = Map<String, dynamic>.from(data);
                      _isLoading = false;
                      _error = null;
                   });
                 }
                 
                 if (_destinationLocation != null && _driverLocation != null && _driverData != null) {
                     if (!_hasFetchedRoute) {
                         _hasFetchedRoute = true;
                         _fetchRoute(_driverLocation!, _destinationLocation!);
                     }
                 }
                 
                 _updateCamera();
             }
          }
      }, onError: (e) {
          print('Firebase Error: $e');
          // Don't fail immediately on stream error, let timeout handle it or user retry
      });
  }

  Future<void> _fetchRoute(LatLng start, LatLng end) async {
    PolylinePoints polylinePoints = PolylinePoints(apiKey: 'AIzaSyDKZXT8Yc26YuBRUHIsd7gbaxkzbwUH3r4');
    try {
      PolylineResult result = await polylinePoints.getRouteBetweenCoordinates(
        request: PolylineRequest(
          origin: PointLatLng(start.latitude, start.longitude),
          destination: PointLatLng(end.latitude, end.longitude),
          mode: TravelMode.driving,
        ),
      );

      if (result.points.isNotEmpty) {
        List<LatLng> polylineCoordinates = [];
        for (var point in result.points) {
          polylineCoordinates.add(LatLng(point.latitude, point.longitude));
        }
        if (mounted) {
          setState(() {
            _polylines.add(Polyline(
              polylineId: const PolylineId('driver_route'),
              color: FxColors.primary,
              width: 4,
              points: polylineCoordinates,
            ));
          });
        }
      } else {
        _fallbackStraightLine(start, end);
      }
    } catch (e) {
      _fallbackStraightLine(start, end);
    }
  }

  void _fallbackStraightLine(LatLng start, LatLng end) {
    if (mounted) {
      setState(() {
        _polylines.add(Polyline(
          polylineId: const PolylineId('driver_route_fallback'),
          color: FxColors.primary,
          width: 4,
          points: [start, end],
        ));
      });
    }
  }

  Future<void> _updateCamera() async {
     if (_driverLocation == null || !_controller.isCompleted) return;
     final controller = await _controller.future;
     // Optional: Animate
  }
  
  Future<void> _moveCamera(LatLng target) async {
     final controller = await _controller.future;
     controller.animateCamera(CameraUpdate.newLatLngZoom(target, 16));
  }
  
  Future<void> _fitBounds() async {
      if (_driverLocation == null || _destinationLocation == null) return;
      final controller = await _controller.future;
      
      final bounds = _boundsFromLatLngList([_driverLocation!, _destinationLocation!]);
      controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 100));
  }

  LatLngBounds _boundsFromLatLngList(List<LatLng> list) {
    double? x0, x1, y0, y1;
    for (LatLng latLng in list) {
      if (x0 == null) {
        x0 = x1 = latLng.latitude;
        y0 = y1 = latLng.longitude;
      } else {
        if (latLng.latitude > x1!) x1 = latLng.latitude;
        if (latLng.latitude < x0!) x0 = latLng.latitude;
        if (latLng.longitude > y1!) y1 = latLng.longitude;
        if (latLng.longitude < y0!) y0 = latLng.longitude;
      }
    }
    return LatLngBounds(northeast: LatLng(x1!, y1!), southwest: LatLng(x0!, y0!));
  }

  Future<void> _callDriver() async {
      final phone = widget.booking['route_details']?['driver_details']?['driver_phone'];
      if (phone != null) {
          final status = await Permission.phone.request();
          if (status.isGranted) {
              final uri = Uri.parse('tel:$phone');
              if (await canLaunchUrl(uri)) {
                  await launchUrl(uri);
              } else {
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not launch dialer')));
              }
          } else {
               if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Phone permission required')));
          }
      }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FxColors.background,
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(70),
        child: FxGlassHeader(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Material(
                color: FxColors.surfaceContainerLowest,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => Navigator.pop(context),
                  child: const Padding(
                    padding: EdgeInsets.all(10),
                    child: Icon(Icons.arrow_back_rounded, color: FxColors.onSurface),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text('Track Driver', style: FxText.headlineSm()),
              const Spacer(),
              Material(
                color: FxColors.surfaceContainerLowest,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => _initTracking(),
                  child: const Padding(
                    padding: EdgeInsets.all(10),
                    child: Icon(Icons.refresh_rounded, color: FxColors.primary),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      body: Stack(
         children: [
             // 1. Map View (Only if we have location)
             if (_driverLocation != null)
                 GoogleMap(
                    mapType: MapType.normal,
                    initialCameraPosition: CameraPosition(
                       target: _driverLocation ?? _destinationLocation ?? const LatLng(0,0),
                       zoom: 14,
                    ),
                    onMapCreated: (GoogleMapController controller) {
                       _controller.complete(controller);
                       Future.delayed(const Duration(milliseconds: 500), () => _fitBounds());
                    },
                    markers: _createMarkers(),
                    polylines: _polylines,
                    zoomControlsEnabled: false,
                    myLocationButtonEnabled: false,
                 ),

              // 2. Loading View
              if (_isLoading)
                 const Padding(
                    padding: EdgeInsets.all(20),
                    child: Column(
                       children: [
                          SkeletonMapPlaceholder(),
                          SizedBox(height: 16),
                          SkeletonDriverInfoCard(),
                       ],
                    ),
                 ),

             // 3. Error / Debug View
             if (!_isLoading && (_driverLocation == null || _error != null))
                Container(
                   color: FxColors.background,
                   width: double.infinity,
                   height: double.infinity,
                   padding: const EdgeInsets.all(24),
                   child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                         const Icon(Icons.signal_wifi_off_rounded, size: 64, color: FxColors.amber),
                         const SizedBox(height: 24),
                         Text(_error ?? 'Driver location not available',
                             textAlign: TextAlign.center, style: FxText.headlineSm()),
                         const SizedBox(height: 24),
                         SizedBox(
                           width: 200,
                           child: FxPrimaryButton(
                             label: 'Try again',
                             leadingIcon: Icons.refresh_rounded,
                             onPressed: () => _initTracking(),
                           ),
                         ),
                      ],
                   ),
                ),

             // 4. Control Panels (Only if map is successfully loaded)
             if (!_isLoading && _driverLocation != null)
                 Positioned(
                    bottom: 20,
                    left: 20,
                    right: 20,
                    child: Column(
                       mainAxisSize: MainAxisSize.min,
                       children: [
                          _buildDriverInfoCard(),
                          const SizedBox(height: 16),
                          Row(
                             children: [
                                _buildControlButton('🚗 Driver', () => _driverLocation != null ? _moveCamera(_driverLocation!) : null),
                                const SizedBox(width: 10),
                                _buildControlButton(widget.booking['status'] == 'Scheduled' ? '🏁 Pickup' : '🎯 Drop', 
                                    () => _destinationLocation != null ? _moveCamera(_destinationLocation!) : null),
                                const SizedBox(width: 10),
                                _buildControlButton('🗺️ All', _fitBounds),
                             ],
                          )
                       ],
                    ),
                 )
         ],
      ),
    );
  }
  
  Widget _debugRow(String label, String value) {
     return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
           crossAxisAlignment: CrossAxisAlignment.start,
           children: [
              SizedBox(width: 80, child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              Expanded(child: Text(value, style: const TextStyle(fontFamily: 'monospace', fontSize: 12))),
           ],
        ),
     );
  }

  Set<Marker> _createMarkers() {
      Set<Marker> markers = {};
      
      if (_driverLocation != null) {
         markers.add(Marker(
            markerId: const MarkerId('driver'),
            position: _driverLocation!,
            icon: _driverIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet),
            infoWindow: InfoWindow(title: 'Driver', snippet: 'Speed: ${_driverData?['speed'] ?? 0} km/h'),
         ));
      }
      
      if (_destinationLocation != null) {
          final status = widget.booking['status'];
          final isPickup = status == 'Scheduled' || status == 'Request';
          markers.add(Marker(
             markerId: const MarkerId('destination'),
             position: _destinationLocation!,
             icon: _destinationIcon ?? BitmapDescriptor.defaultMarkerWithHue(isPickup ? BitmapDescriptor.hueGreen : BitmapDescriptor.hueRed),
             infoWindow: InfoWindow(title: isPickup ? 'Pickup Location' : 'Drop Location'),
          ));
      }
      
      return markers;
  }

  Widget _buildControlButton(String label, VoidCallback? onTap) {
      return Expanded(
         child: Material(
           color: FxColors.surfaceContainerLowest,
           borderRadius: BorderRadius.circular(14),
           elevation: 0,
           child: InkWell(
             borderRadius: BorderRadius.circular(14),
             onTap: onTap,
             child: Container(
               padding: const EdgeInsets.symmetric(vertical: 14),
               decoration: BoxDecoration(
                 borderRadius: BorderRadius.circular(14),
                 boxShadow: FxShadows.soft,
               ),
               alignment: Alignment.center,
               child: Text(label, style: FxText.titleSm()),
             ),
           ),
         ),
      );
  }

  Widget _buildDriverInfoCard() {
      final driverDetails = widget.booking['route_details']?['driver_details'];
      final vehicleDetails = widget.booking['route_details']?['vehicle_details'];
      
      if (driverDetails == null) return const SizedBox();

      final speed = _driverData?['speed']?.toStringAsFixed(0) ?? '0';
      final timestamp = _driverData?['timestamp'];
      String timeString = '--:--';
      if (timestamp != null) {
         final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
         timeString = '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
      }

      return FxCard(
         padding: const EdgeInsets.all(18),
         child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
                Row(
                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
                   children: [
                      Text('Driver Information', style: FxText.headlineSm()),
                      FxPill(
                        text: 'LIVE',
                        color: const Color(0xFF00B894),
                        background: const Color(0xFFE7F8EE),
                        pulse: true,
                      ),
                   ],
                ),
                const SizedBox(height: 14),
                Row(
                   children: [
                       Container(
                         width: 48,
                         height: 48,
                         decoration: BoxDecoration(
                           gradient: FxGradients.indigo,
                           borderRadius: BorderRadius.circular(14),
                         ),
                         child: const Icon(Icons.person_rounded, color: FxColors.onPrimary),
                       ),
                       const SizedBox(width: 12),
                       Expanded(
                          child: Column(
                             crossAxisAlignment: CrossAxisAlignment.start,
                             children: [
                                Text(driverDetails['driver_name'] ?? 'Unknown Driver',
                                    style: FxText.title()),
                                const SizedBox(height: 2),
                                Row(
                                   children: [
                                      const Icon(Icons.phone_rounded, size: 14, color: FxColors.primary),
                                      const SizedBox(width: 4),
                                      Text(driverDetails['driver_phone'] ?? '',
                                          style: FxText.bodySm(color: FxColors.primary)),
                                   ],
                                ),
                             ],
                          ),
                       ),
                       Material(
                         color: const Color(0xFF00B894),
                         borderRadius: BorderRadius.circular(20),
                         child: InkWell(
                           borderRadius: BorderRadius.circular(20),
                           onTap: _callDriver,
                           child: Container(
                             padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                             child: Row(
                               mainAxisSize: MainAxisSize.min,
                               children: [
                                 const Icon(Icons.call_rounded, color: Colors.white, size: 14),
                                 const SizedBox(width: 6),
                                 Text('Call', style: FxText.titleSm(color: FxColors.onPrimary)),
                               ],
                             ),
                           ),
                         ),
                       ),
                   ],
                ),
                const SizedBox(height: 14),
                Container(
                   width: double.infinity,
                   padding: const EdgeInsets.all(12),
                   decoration: BoxDecoration(
                      color: FxColors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(12),
                   ),
                   child: Row(
                     children: [
                       const Icon(Icons.directions_car_rounded, color: FxColors.onSurfaceVariant, size: 18),
                       const SizedBox(width: 8),
                       Expanded(
                         child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                               Text(vehicleDetails?['vehicle_number']?.toString() ?? 'N/A', style: FxText.titleSm()),
                               if (vehicleDetails?['model'] != null)
                                  Text(vehicleDetails!['model'].toString(), style: FxText.bodySm()),
                            ],
                         ),
                       ),
                     ],
                   ),
                ),
                const SizedBox(height: 12),
                Row(
                   mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                   children: [
                      Column(
                         children: [
                            FxMetaLabel('Speed'),
                            const SizedBox(height: 2),
                            Text('$speed km/h', style: FxText.title()),
                         ],
                      ),
                      Container(width: 1, height: 30, color: FxColors.surfaceContainerHigh),
                      Column(
                         children: [
                            FxMetaLabel('Last Updated'),
                            const SizedBox(height: 2),
                            Text(timeString, style: FxText.title()),
                         ],
                      ),
                   ],
                )
            ],
         ),
      );
  }
}
