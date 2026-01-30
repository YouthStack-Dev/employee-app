import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../providers/auth_provider.dart';
import '../providers/booking_provider.dart';
import '../constants/app_colors.dart';
import '../services/booking_service.dart';
import '../models/booking_model.dart';
import 'booking_details_screen.dart';
import 'edit_booking_screen.dart';
import 'track_driver_screen.dart';
import 'create_booking_screen.dart';

class SchedulesScreen extends StatefulWidget {
  const SchedulesScreen({super.key});

  @override
  State<SchedulesScreen> createState() => _SchedulesScreenState();
}

class _SchedulesScreenState extends State<SchedulesScreen> {
  int _currentIndex = 0; // 0: Home, 1: History, 2: Profile
  Completer<GoogleMapController> _mapController = Completer();
  LatLng _userLocation = const LatLng(12.9716, 77.5946); // Default Bangalore
  Set<Marker> _markers = {};
  bool _locationFound = false;
  DateTime _selectedHistoryDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshBookings();
      _determinePosition();
    });
  }

  Future<void> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    if (permission == LocationPermission.deniedForever) return;

    try {
      final position = await Geolocator.getCurrentPosition();
      if (!mounted) return;
      setState(() {
        _userLocation = LatLng(position.latitude, position.longitude);
        _locationFound = true;
      });

      final controller = await _mapController.future;
      controller.animateCamera(CameraUpdate.newLatLngZoom(_userLocation, 14));
    } catch (e) {
      debugPrint('Error determining position: $e');
    }
  }

  void _refreshBookings() {
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    if (user?.employeeId != null) {
      final now = DateTime.now();
      // Fetch -1 day to +8 days for Home Dashboard
      final start = now.subtract(const Duration(days: 1));
      final end = start.add(const Duration(days: 8)); 
      final dateFormat = DateFormat('yyyy-MM-dd');
      
      Provider.of<BookingProvider>(context, listen: false).fetchBookings(
        user!.employeeId!,
        startDate: dateFormat.format(start),
        endDate: dateFormat.format(end),
      );
    }
  }

  void _fetchHistoryBookings(DateTime date) {
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    if (user?.employeeId != null) {
      final dateFormat = DateFormat('yyyy-MM-dd');
      // Fetch specifically for the selected date
      Provider.of<BookingProvider>(context, listen: false).fetchBookings(
        user!.employeeId!,
        startDate: dateFormat.format(date),
        endDate: dateFormat.format(date),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: false, // Ensure map doesn't distort
      body: _buildBody(),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -2))],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
             setState(() => _currentIndex = index);
             if (index == 0) {
                _refreshBookings(); // Restore Home data
             } else if (index == 1) {
                // Default to today for History when switching or keep selected?
                // User asked for "present day and previous days". 
                // We'll init history with today's data.
                _selectedHistoryDate = DateTime.now();
                _fetchHistoryBookings(_selectedHistoryDate);
             }
          },
          backgroundColor: Colors.white,
          selectedItemColor: const Color(0xFF0D47A1),
          unselectedItemColor: Colors.grey,
          showUnselectedLabels: true,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          items: const [
             BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: 'Home'),
             BottomNavigationBarItem(icon: Icon(Icons.history), label: 'History'),
             BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
          ],
        ),
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton(
            heroTag: 'sos_btn',
            onPressed: _triggerSOS,
            backgroundColor: Colors.red,
            child: const Icon(Icons.sos, color: Colors.white, size: 30),
            elevation: 4,
            shape: const CircleBorder(),
          ),
          const SizedBox(height: 16),
          if (_currentIndex == 0)
            FloatingActionButton(
              heroTag: 'create_booking_btn',
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateBookingScreen())),
              backgroundColor: const Color(0xFF0D47A1),
              child: const Icon(Icons.add, color: Colors.white),
            ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    switch (_currentIndex) {
      case 0: return _buildHomeTab();
      case 1: return _buildHistoryTab();
      case 2: return _buildProfileTab();
      default: return _buildHomeTab();
    }
  }

  // ---------------- HOME TAB ----------------
  Widget _buildHomeTab() {
    // Determine active ride to set initial sheet size/content
    final bookings = Provider.of<BookingProvider>(context).bookings;
    // ... filtering logic duplicated for safety inside build ...
    
    return Stack(
      children: [
        // 1. Google Map (Full Screen Background)
        Positioned.fill(
          child: GoogleMap(
            initialCameraPosition: CameraPosition(target: _userLocation, zoom: 12),
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            markers: _markers,
            onMapCreated: (GoogleMapController controller) {
              if (!_mapController.isCompleted) {
                _mapController.complete(controller);
              }
            },
          ),
        ),



        // 2. Map Overlay Gradients/Title
        Positioned(
          top: 0, left: 0, right: 0,
          height: 150,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.white.withOpacity(0.9), Colors.transparent],
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Row(
                   crossAxisAlignment: CrossAxisAlignment.start,
                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
                   children: [
                      const Text('Home', style: TextStyle(fontSize: 34, fontWeight: FontWeight.bold, color: Colors.black)),
                      CircleAvatar(
                        backgroundColor: Colors.white,
                        child: IconButton(
                           icon: const Icon(Icons.refresh, color: Colors.black), 
                           onPressed: _refreshBookings
                        ),
                      )
                   ],
                ),
              ),
            ),
          ),
        ),

        // 3. Draggable Scrollable Sheet
        DraggableScrollableSheet(
          initialChildSize: 0.35, // Show Active Card
          minChildSize: 0.20,     // Just a peek
          maxChildSize: 0.75,     // Expand to user request
          builder: (BuildContext context, ScrollController scrollController) {
             return _buildHomeContent(scrollController);
          },
        ),
      ],
    );
  }

  Widget _buildHomeContent(ScrollController scrollController) {
    return Consumer<BookingProvider>(
      builder: (context, provider, child) {
        final allBookings = provider.bookings;
        
        // Active Filter
        final potentialActive = allBookings.where((b) {
           if (b.status == 'Ongoing') return true;
           if (b.status == 'Scheduled') {
              final hasDriver = b.routeDetails?['driver_details']?['driver_id'] != null;
              return hasDriver;
           }
           return false;
        }).toList();

        potentialActive.sort((a, b) {
           if (a.status == 'Ongoing' && b.status != 'Ongoing') return -1;
           if (b.status == 'Ongoing' && a.status != 'Ongoing') return 1;
           return (a.shiftTime ?? a.pickupTime ?? '').compareTo(b.shiftTime ?? b.pickupTime ?? '');
        });

        final Booking? activeRide = potentialActive.isNotEmpty ? potentialActive.first : null;
        
        final yourRides = allBookings.where((b) {
           if (b.id == activeRide?.id) return false; 
           return ['Request', 'Cancelled', 'Rejected', 'Scheduled'].contains(b.status);
        }).toList();
        
        yourRides.sort((a, b) {
            int cmp = (a.date ?? '').compareTo(b.date ?? '');
            if (cmp != 0) return cmp;
            return (a.shiftTime ?? a.pickupTime ?? '').compareTo(b.shiftTime ?? b.pickupTime ?? '');
        });
        
        // Group by Date
        final groupedRides = <String, List<Booking>>{};
        for (var ride in yourRides) {
            String dateKey = ride.date ?? 'Unknown Date';
            try {
               final date = DateTime.parse(dateKey);
               final now = DateTime.now();
               final today = DateTime(now.year, now.month, now.day);
               final tomorrow = today.add(const Duration(days: 1));
               final rideDate = DateTime(date.year, date.month, date.day);

               if (rideDate == today) dateKey = 'Today';
               else if (rideDate == tomorrow) dateKey = 'Tomorrow';
               else dateKey = DateFormat('EEE, MMM d').format(date);
            } catch (e) {
               // keep original string
            }
            
            if (!groupedRides.containsKey(dateKey)) {
                groupedRides[dateKey] = [];
            }
            groupedRides[dateKey]!.add(ride);
        }

        // Update markers if active ride
        if (activeRide != null && _locationFound) {
            // Marker logic would go here
        }

        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFFF5F7FA),
            borderRadius: BorderRadius.only(topLeft: Radius.circular(30), topRight: Radius.circular(30)),
            boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -5))],
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(0),
            children: [
               // Handle Grip
               Center(
                 child: Container(
                   margin: const EdgeInsets.only(top: 10, bottom: 10),
                   width: 40, height: 5,
                   decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(5)),
                 ),
               ),

               // Header: Active Ride (Moves with sheet)
               Padding(
                 padding: const EdgeInsets.symmetric(horizontal: 20),
                 child: Column(
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: [
                      if (activeRide != null) ...[
                        const Text('Active Ride', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 10),
                        _buildActiveRideCard(activeRide),
                      ] else ...[
                        const Text('Active Ride', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 10),
                        Container(
                           padding: const EdgeInsets.all(20),
                           decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                           child: const Center(child: Text('No Active Rides', style: TextStyle(color: Colors.grey))),
                        ),
                      ]
                   ],
                 ),
               ),
               
               const SizedBox(height: 20),

               // Your Rides List Grouped by Date
               Padding(
                 padding: const EdgeInsets.symmetric(horizontal: 20),
                 child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                       Row(
                         mainAxisAlignment: MainAxisAlignment.spaceBetween,
                         children: [
                            const Text('Your Rides', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                             if (yourRides.isNotEmpty)
                               InkWell(
                                 onTap: () {
                                    // TODO: Implement full list view or similar
                                 },
                                 child: const Text('See All', style: TextStyle(color: Color(0xFF0D47A1), fontWeight: FontWeight.bold)),
                               ),
                         ],
                       ),
                       const SizedBox(height: 10),
                       
                       if (yourRides.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(40),
                            child: Column(
                              children: [
                                Icon(Icons.directions_car_outlined, size: 60, color: Colors.grey.shade300),
                                const SizedBox(height: 10),
                                Text('No upcoming rides', style: TextStyle(color: Colors.grey.shade500)),
                              ],
                            ),
                          ),
                          
                       ...groupedRides.entries.expand((entry) {
                           return [
                               Padding(
                                 padding: const EdgeInsets.symmetric(vertical: 10),
                                 child: Text(entry.key, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 14)),
                               ),
                               ...entry.value.map((b) => _buildSimpleRideCard(b)),
                           ];
                       }),
                       
                       const SizedBox(height: 80), // Bottom padding
                    ],
                 ),
               ),
            ],
          ),
        );
      },
    );
  }

  // ... (History and Profile tabs unchanged)

  // ---------------- WIDGETS ----------------

  Widget _buildActiveRideCard(Booking b) {
     final isLogin = b.logType == 'IN';
     String time = b.shiftTime ?? '--:--';
     if (time.length > 5) time = time.substring(0, 5);
     
     // Color logic
     Color statusColor = Colors.green;
     String statusText = b.status ?? 'Scheduled';
     if (b.status == 'Ongoing') { statusColor = Colors.blue; }
     
     return Container(
         width: double.infinity,
         padding: const EdgeInsets.all(16),
         decoration: BoxDecoration(
           color: Colors.white,
           borderRadius: BorderRadius.circular(20),
           boxShadow: [
             BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5))
           ]
         ),
         child: Column(
           crossAxisAlignment: CrossAxisAlignment.start,
           children: [
              // Header
              Row(
                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
                 children: [
                    Row(
                       children: [
                          Icon(isLogin ? Icons.login : Icons.logout, color: Colors.black, size: 20),
                          const SizedBox(width: 8),
                          Column(
                             crossAxisAlignment: CrossAxisAlignment.start,
                             children: [
                                Text(isLogin ? 'Login' : 'Logout', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                Text(time, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                             ],
                          )
                       ],
                    ),
                    const Icon(Icons.keyboard_arrow_up, color: Colors.grey), // Expanded indicator
                 ],
              ),
              const SizedBox(height: 12),
              
              // Status Pill
              Container(
                 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                 decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20)
                 ),
                 child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                       Icon(Icons.access_time_filled, size: 16, color: statusColor),
                       const SizedBox(width: 4),
                       Text(statusText, style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12)),
                    ],
                 ),
              ),
              const SizedBox(height: 16),
              
              // Location Dots
              _buildLocationRow(Colors.red, b.pickupLocation ?? 'Unknown Pickup'),
              Container(
                 margin: const EdgeInsets.only(left: 7),
                 height: 16,
                 decoration: const BoxDecoration(
                    border: Border(left: BorderSide(color: Colors.grey, width: 1)),
                 ),
              ),
              _buildLocationRow(Colors.green, b.dropLocation ?? 'Unknown Drop'),
              
              const SizedBox(height: 16),
              
              // OTP Box
              if (b.boardingOtp != null || b.deboardingOtp != null)
              Container(
                 padding: const EdgeInsets.all(12),
                 decoration: BoxDecoration(
                    color: const Color(0xFFF8F9FE), // Light blueish grey
                    borderRadius: BorderRadius.circular(12)
                 ),
                 child: Column(
                    children: [
                       const Row(children: [Text('Trip OTPs', style: TextStyle(fontWeight: FontWeight.bold))]),
                       const SizedBox(height: 8),
                       Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                             if (b.boardingOtp != null)
                             Column(
                                children: [
                                   const Text('Boarding', style: TextStyle(color: Colors.grey, fontSize: 12)),
                                   Text(b.boardingOtp!, style: const TextStyle(color: Color(0xFF5B7FFF), fontWeight: FontWeight.bold, fontSize: 16)),
                                ],
                             ),
                             if (b.deboardingOtp != null)
                             Column(
                                children: [
                                   const Text('Deboarding', style: TextStyle(color: Colors.grey, fontSize: 12)),
                                   Text(b.deboardingOtp!, style: const TextStyle(color: Color(0xFF5B7FFF), fontWeight: FontWeight.bold, fontSize: 16)),
                                ],
                             ),
                          ],
                       )
                    ],
                 ),
              ),
              
              const SizedBox(height: 16),
              
              // Actions
              Row(
                 children: [
                    // Edit/Cancel not shown for active usually? User request implies showing edit/cancel even in "smaller version" UI.
                    // But active ride usually can't be edited/cancelled.
                    // We will just show Track button prominently for Active.
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => BookingDetailsScreen(bookingId: b.id!))),
                        style: ElevatedButton.styleFrom(
                           backgroundColor: Colors.white,
                           foregroundColor: Colors.black,
                           elevation: 0,
                           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: const BorderSide(color: Colors.grey, width: 0.5)),
                           padding: const EdgeInsets.symmetric(vertical: 12)
                        ),
                        icon: const Icon(Icons.map_outlined, size: 18),
                        label: const Text('Track'),
                      ),
                    ),
                 ],
              )
           ],
         ),
     );
  }

  Widget _buildSimpleRideCard(Booking b) {
     final isLogin = b.logType == 'IN';
     
     // Safe Time Formatting
     String time = '--:--';
     if (b.shiftTime != null && b.shiftTime!.length >= 5) {
       time = b.shiftTime!.substring(0, 5);
     } else if (b.pickupTime != null && b.pickupTime!.length >= 5) {
       time = b.pickupTime!.substring(0, 5);
     } else {
        time = b.shiftTime ?? b.pickupTime ?? '--:--';
      }
      if (time.length > 5) time = time.substring(0, 5);

     final isScheduled = b.status == 'Scheduled';
     Color statusColor = Colors.green;
     if (b.status == 'Request') statusColor = Colors.orange;
     if (b.status == 'Cancelled' || b.status == 'Rejected') statusColor = Colors.red;

     return GestureDetector(
       onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => BookingDetailsScreen(bookingId: b.id!))),
       child: Container(
         margin: const EdgeInsets.only(bottom: 16),
         padding: const EdgeInsets.all(16),
         decoration: BoxDecoration(
           color: Colors.white,
           borderRadius: BorderRadius.circular(16),
           border: Border.all(color: Colors.grey.shade200),
         ),
         child: Column(
           children: [
             // Header
             Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                   Row(
                      children: [
                         Icon(isLogin ? Icons.login : Icons.logout, color: Colors.black87, size: 20),
                         const SizedBox(width: 8),
                         Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                               Text(isLogin ? 'Login' : 'Logout', style: const TextStyle(fontWeight: FontWeight.bold)),
                               Text(time, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            ],
                         ),
                      ],
                   ),
                   Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                      child: Text(b.status ?? '', style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.bold)),
                   )
                ],
             ),
             const SizedBox(height: 12),
             
             // Route
             _buildLocationRow(Colors.red, b.pickupLocation ?? 'Unknown Pickup'),
             Container(
                 margin: const EdgeInsets.only(left: 7),
                 height: 12,
                 decoration: const BoxDecoration(
                    border: Border(left: BorderSide(color: Colors.grey, width: 1)),
                 ),
             ),
             _buildLocationRow(Colors.green, b.dropLocation ?? 'Unknown Drop'),
             
             const SizedBox(height: 16),
             
             // Actions (Cancel, Edit, Track)
             Row(
               children: [
                  // Cancel
                  if (b.status != 'Cancelled' && b.status != 'Rejected' && b.status != 'Completed')
                  SizedBox(
                    width: 40, height: 40,
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.red),
                      style: IconButton.styleFrom(backgroundColor: Colors.red.withOpacity(0.1), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                      onPressed: () => _showCancelDialog(b),
                    ),
                  ),
                  if (b.status != 'Cancelled' && b.status != 'Rejected' && b.status != 'Completed') ...[
                     const SizedBox(width: 10),
                     // Edit
                     SizedBox(
                       width: 40, height: 40,
                       child: IconButton(
                         icon: const Icon(Icons.edit, color: Colors.grey),
                         style: IconButton.styleFrom(backgroundColor: Colors.grey.shade100, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                         onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EditBookingScreen(bookingId: b.id!))),
                       ),
                     ),
                  ],
                  const Spacer(),
                  // Track
                  ElevatedButton.icon(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => BookingDetailsScreen(bookingId: b.id!))),
                    style: ElevatedButton.styleFrom(
                       backgroundColor: Colors.white,
                       foregroundColor: Colors.black,
                       elevation: 0,
                       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: Colors.grey.shade300)),
                    ),
                    icon: const Icon(Icons.remove_red_eye_outlined, size: 16),
                    label: const Text('View'),
                  ),
               ],
             )
           ],
         ),
       ),
     );
  }

  Widget _buildLocationRow(Color color, String text) {
     return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
           Container(
              margin: const EdgeInsets.only(top: 2),
              width: 14, height: 14,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
           ),
           const SizedBox(width: 10),
           Expanded(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14))),
        ],
     );
  }

  void _showCancelDialog(Booking b) {
     showDialog(
       context: context,
       builder: (ctx) => AlertDialog(
          title: const Text('Cancel Ride?'),
          content: Text('Are you sure you want to cancel the ride for ${b.date ?? ''}?'),
          actions: [
             TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('No')),
                TextButton(
                onPressed: () async {
                   Navigator.pop(ctx);
                   if (b.id == null) return;
                   final provider = Provider.of<BookingProvider>(context, listen: false);
                   final result = await provider.cancelBooking(b.id!);
                   if (context.mounted) {
                     if (result['success']) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ride cancelled successfully')));
                     } else {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['error'] ?? 'Cancellation failed'), backgroundColor: Colors.red));
                     }
                   }
                }, 
               child: const Text('Yes, Cancel', style: TextStyle(color: Colors.red))
             ),
          ],
       ),
     );
  }

  // ---------------- HISTORY TAB ----------------
  Widget _buildHistoryTab() {
    return Column(
      children: [
        AppBar(
          title: const Text('Ride History', style: TextStyle(color: Colors.black)),
          backgroundColor: Colors.white,
          elevation: 0,
          automaticallyImplyLeading: false,
        ),
        
        // Date Selection Section
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          color: Colors.white,
          child: Row(
            children: [
               const Icon(Icons.calendar_today, color: Color(0xFF0D47A1), size: 20),
               const SizedBox(width: 10),
               Text(
                 DateFormat('EEE, MMM d, yyyy').format(_selectedHistoryDate),
                 style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
               ),
               const Spacer(),
               OutlinedButton.icon(
                 onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _selectedHistoryDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(), // Present and previous days only
                      builder: (context, child) {
                        return Theme(
                          data: Theme.of(context).copyWith(
                            colorScheme: const ColorScheme.light(primary: Color(0xFF0D47A1)),
                          ),
                          child: child!,
                        );
                      }
                    );
                    if (picked != null && picked != _selectedHistoryDate) {
                       setState(() => _selectedHistoryDate = picked);
                       _fetchHistoryBookings(picked);
                    }
                 },
                 icon: const Icon(Icons.edit_calendar, size: 16),
                 label: const Text('Select Date'),
                 style: OutlinedButton.styleFrom(
                   foregroundColor: const Color(0xFF0D47A1),
                   side: const BorderSide(color: Color(0xFF0D47A1)),
                 ),
               )
            ],
          ),
        ),
        const Divider(height: 1),

        Expanded(
          child: Consumer<BookingProvider>(
            builder: (context, provider, child) {
              if (provider.isLoading) {
                 return const Center(child: CircularProgressIndicator(color: Color(0xFF0D47A1)));
              }

              // Show ALL rides for the selected date as requested
              // Provider data is already filtered by API to only return this date's bookings
              final history = provider.bookings;
              
              // Sort desc by time (since date is same)
              // Note: provider.bookings might include active rides if date is today.
              history.sort((a, b) => (b.shiftTime ?? b.pickupTime ?? '').compareTo(a.shiftTime ?? a.pickupTime ?? ''));

              if (history.isEmpty) {
                 return Center(
                   child: Column(
                     mainAxisAlignment: MainAxisAlignment.center,
                     children: [
                       Icon(Icons.history_toggle_off, size: 60, color: Colors.grey.shade300),
                       const SizedBox(height: 10),
                       Text('No rides found for ${DateFormat('MMM d').format(_selectedHistoryDate)}', style: TextStyle(color: Colors.grey.shade500)),
                     ],
                   ),
                 );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(20),
                itemCount: history.length,
                itemBuilder: (context, index) => _buildSimpleRideCard(history[index]),
              );
            },
          ),
        ),
      ],
    );
  }

  // ---------------- PROFILE TAB ----------------
  Widget _buildProfileTab() {
     final user = Provider.of<AuthProvider>(context).user;
     return Column(
       children: [
         const SizedBox(height: 60),
         Center(
            child: CircleAvatar(
              radius: 50,
              backgroundColor: const Color(0xFF0D47A1),
              child: Text((user?.name != null && user!.name!.isNotEmpty) ? user.name![0] : 'U', style: const TextStyle(fontSize: 40, color: Colors.white)),
            ),
         ),
         const SizedBox(height: 20),
         Text(user?.name ?? 'User', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
         Text(user?.email ?? '', style: const TextStyle(color: Colors.grey)),
         const SizedBox(height: 40),
         ListTile(
           leading: const Icon(Icons.person_outline),
           title: const Text('Edit Profile'),
           trailing: const Icon(Icons.chevron_right),
           onTap: () {}, // TODO
         ),
         const Divider(),
         ListTile(
           leading: const Icon(Icons.logout, color: Colors.red),
           title: const Text('Logout', style: TextStyle(color: Colors.red)),
           onTap: () {
              Provider.of<AuthProvider>(context, listen: false).logout();
              Navigator.pushReplacementNamed(context, '/login');
           },
         ),
       ],
     );
  }

  Future<void> _triggerSOS() async {
    // 1. Identify if there is an active booking to link
    final provider = Provider.of<BookingProvider>(context, listen: false);
    final allBookings = provider.bookings;
    
    Booking? activeRide;
    try {
      final potentialActive = allBookings.where((b) => b.status == 'Ongoing' || (b.status == 'Scheduled' && b.routeDetails?['driver_details']?['driver_id'] != null)).toList();
      if (potentialActive.isNotEmpty) {
         // Sort same as Home Tab
         potentialActive.sort((a, b) {
             if (a.status == 'Ongoing' && b.status != 'Ongoing') return -1;
             if (b.status == 'Ongoing' && a.status != 'Ongoing') return 1;
             return (a.shiftTime ?? a.pickupTime ?? '').compareTo(b.shiftTime ?? b.pickupTime ?? '');
         });
         activeRide = potentialActive.first;
      }
    } catch (e) {
      // safe fallback
    }

    // 2. Confirmation Dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(children: [Icon(Icons.warning_amber_rounded, color: Colors.red), SizedBox(width: 8), Text('Emergency Alert')]),
        content: const Text('Are you sure you want to trigger an SOS alert? This will verify your location and notify the transport team immediately.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true), 
            child: const Text('TRIGGER SOS')
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // 3. Trigger
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Triggering SOS...'), duration: Duration(seconds: 1)));
      
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final result = await authProvider.triggerGenericSOS(bookingId: activeRide?.id);

      if (mounted) {
        if (result['success']) {
           showDialog(
             context: context, 
             builder: (_) => AlertDialog(
               title: const Icon(Icons.check_circle, color: Colors.green, size: 50),
               content: const Text('SOS Alert Sent Successfully. Help is on the way.', textAlign: TextAlign.center),
               actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
             )
           );
        } else {
           ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: ${result['error'] ?? 'Unknown Error'}'), backgroundColor: Colors.red));
        }
      }
    }
  }
}
