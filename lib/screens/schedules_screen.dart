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
import '../services/alert_service.dart';

class SchedulesScreen extends StatefulWidget {
  const SchedulesScreen({super.key});

  @override
  State<SchedulesScreen> createState() => _SchedulesScreenState();
}

class _SchedulesScreenState extends State<SchedulesScreen> {
  int _currentIndex = 0; // 0: Home, 1: History
  DateTime _selectedHistoryDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshBookings();
    });
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
        type: BookingType.home,
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
        type: BookingType.history,
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
      default: return _buildHomeTab();
    }
  }

  // ---------------- HOME TAB ----------------
  Widget _buildHomeTab() {
    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.fromLTRB(20, 50, 20, 20),
          color: Colors.white,
          child: Row(
             mainAxisAlignment: MainAxisAlignment.spaceBetween,
             children: [
                const Text('Home', style: TextStyle(fontSize: 34, fontWeight: FontWeight.bold, color: Colors.black)),
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.grey.shade100,
                      child: IconButton(
                         icon: const Icon(Icons.refresh, color: Colors.black), 
                         onPressed: _refreshBookings
                      ),
                    ),
                    const SizedBox(width: 10),
                    CircleAvatar(
                      backgroundColor: Colors.red.shade50,
                      child: IconButton(
                         icon: const Icon(Icons.logout, color: Colors.red), 
                         onPressed: () {
                             Provider.of<AuthProvider>(context, listen: false).logout();
                             Navigator.pushReplacementNamed(context, '/login');
                         }
                      ),
                    ),
                  ],
                )
             ],
          ),
        ),

        // Body
        Expanded(
          child: _buildHomeContent(null),
        ),
      ],
    );
  }

  Widget _buildHomeContent(ScrollController? scrollController) {
    return Consumer<BookingProvider>(
      builder: (context, provider, child) {
        final allBookings = List<Booking>.from(provider.homeBookings);
        
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

        return Column(
          children: [
             // 1. STICKY ACTIVE SECTION
             Container(
               padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
               decoration: BoxDecoration(
                 color: Colors.white,
                 boxShadow: [
                   BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5))
                 ],
                 // Ensure it looks like it sits on top if we want that visual
               ),
               child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                     if (activeRide != null) ...[
                       const Text('Active Ride', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                       const SizedBox(height: 10),
                       _buildActiveRideCard(activeRide),
                     ]
                     // If no active ride, we could hide it or show empty state. 
                     // Since user wants "Sticky Active Ride", if there IS one, it sticks. 
                     // If not, we can show nothing or a small placeholder?
                     // Let's stick (pun intended) to hiding it if null to save space, but per UI mocks often we show it.
                     // The previous code showed "No Active Rides". Let's keep that but maybe smaller?
                     // Actually, if we show "No Active Rides", it uses 1/3 screen.
                     // The request is about "Active rides stay sticky".
                     else ...[
                        const Text('Active Ride', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 10),
                        Container(
                           padding: const EdgeInsets.all(20),
                           decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
                           child: const Center(child: Text('No Active Rides', style: TextStyle(color: Colors.grey))),
                        ),
                     ]
                  ],
               ),
             ),

             // 2. SCROLLABLE UPCOMING LIST
             Expanded(
               child: ListView(
                  padding: const EdgeInsets.only(top: 20, bottom: 80), // Padding for separation and bottom nav
                  children: [
                     Padding(
                       padding: const EdgeInsets.symmetric(horizontal: 20),
                       child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                             Row(
                               mainAxisAlignment: MainAxisAlignment.spaceBetween,
                               children: [
                                  const Text('Upcoming Rides', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), // RENAMED
                                   // See All button removed as per user request (list is scrollable)
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
                          ],
                       ),
                     ),
                  ],
               ),
             ),
          ],
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
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => BookingDetailsScreen(bookingId: b.id!, isReadOnly: false))), // Active is theoretically "home" context but track is primary
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

  Widget _buildSimpleRideCard(Booking b, {bool isHistory = false}) {
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
       onTap: () async {
          final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => BookingDetailsScreen(bookingId: b.id!, isReadOnly: isHistory)));
          if (result == true && !isHistory) {
             _refreshBookings();
          } else if (result == true && isHistory) {
             _fetchHistoryBookings(_selectedHistoryDate);
          }
       },
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
                  if (!isHistory && b.status != 'Cancelled' && b.status != 'Rejected' && b.status != 'Completed')
                  SizedBox(
                    width: 40, height: 40,
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.red),
                      style: IconButton.styleFrom(backgroundColor: Colors.red.withOpacity(0.1), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                      onPressed: () => _showCancelDialog(b),
                    ),
                  ),
                  // Edit
                  // Show for Request, Scheduled, OR Cancelled (if Today/Future)
                  if (!isHistory && (b.status == 'Request' || b.status == 'Scheduled' || (b.status == 'Cancelled' && (() {
                      final now = DateTime.now();
                      final today = DateTime(now.year, now.month, now.day);
                      final bDate = DateTime.tryParse(b.date ?? '') ?? DateTime.now();
                      return !bDate.isBefore(today);
                  })()))) ...[
                     const SizedBox(width: 10),
                     SizedBox(
                       width: 40, height: 40,
                       child: IconButton(
                         icon: const Icon(Icons.edit, color: Colors.grey),
                         style: IconButton.styleFrom(backgroundColor: Colors.grey.shade100, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                         onPressed: () async {
                            final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => EditBookingScreen(bookingId: b.id!)));
                            if (result == true) {
                               _refreshBookings();
                            }
                         },
                       ),
                     ),
                  ],
               ],
             ),
             
             const SizedBox(height: 16),

             // Actions (Cancel, Track) - Note: Edit is handled above in the header-like row or we consolidate? 
             // Wait, the previous code block inserted Edit specific logic into a row. 
             // Let's ensure I'm targeting the right block.
             // The previous edit was:
             /*
                  // Edit
                  // Show for Request, Scheduled, OR Cancelled (if Today/Future)
                  if (!isHistory && (b.status == 'Request' ...)) ...[
                     const SizedBox(width: 10),
                     SizedBox(
                       width: 40, height: 40,
                       child: IconButton(
                         icon: const Icon(Icons.edit, color: Colors.grey),
                         style: IconButton.styleFrom(backgroundColor: Colors.grey.shade100, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                         onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EditBookingScreen(bookingId: b.id!))),
                       ),
                     ),
                  ],
             */
             // I need to replace that exact block's onPressed.

                   // Track / View
                   SizedBox(
                     width: double.infinity,
                     child: ElevatedButton.icon(
                       onPressed: () async {
                          final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => BookingDetailsScreen(bookingId: b.id!, isReadOnly: isHistory)));
                           if (result == true && !isHistory) {
                              _refreshBookings();
                           }
                       },
                       style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: Colors.grey.shade300)),
                       ),
                       icon: const Icon(Icons.remove_red_eye_outlined, size: 16),
                       label: const Text('View'),
                     ),
                   ),
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
                        _refreshBookings();
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
  int _historyToggleIndex = 0; // 0: Bookings, 1: SOS
  List<dynamic> _sosHistory = [];
  bool _isLoadingSOS = false;

  void _fetchSOSHistory([DateTime? date]) async {
    setState(() => _isLoadingSOS = true);
    final targetDate = date ?? _selectedHistoryDate;
    final dateStr = DateFormat('yyyy-MM-dd').format(targetDate);
    
    final service = AlertService();
    // Fetch for the specific date selected
    final result = await service.fetchMyAlerts(
      startDate: dateStr,
      endDate: dateStr,
    );
    
    if (mounted) {
      if (result['success']) {
         setState(() {
           _sosHistory = result['data']['data']['alerts'] ?? []; 
           _isLoadingSOS = false;
         });
      } else {
         setState(() => _isLoadingSOS = false);
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['error'] ?? 'Failed to load SOS history')));
      }
    }
  }

  Widget _buildHistoryTab() {
    return Column(
      children: [
        AppBar(
          title: const Text('History', style: TextStyle(color: Colors.black)),
          backgroundColor: Colors.white,
          elevation: 0,
          automaticallyImplyLeading: false,
        ),
        
        // Toggle (Bookings vs SOS)
        Container(
           margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
           padding: const EdgeInsets.all(4),
           decoration: BoxDecoration(
             color: Colors.grey.shade100,
             borderRadius: BorderRadius.circular(12),
           ),
           child: Row(
             children: [
               Expanded(child: _buildToggleBtn('Bookings', 0)),
               Expanded(child: _buildToggleBtn('SOS History', 1)),
             ],
           ),
        ),

        // Shared Date Selection Section
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
                      lastDate: DateTime.now(), 
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
                       if (_historyToggleIndex == 0) {
                          _fetchHistoryBookings(picked);
                       } else {
                          _fetchSOSHistory(picked);
                       }
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
          child: _historyToggleIndex == 0 ? _buildBookingsHistoryList() : _buildSOSHistoryList(),
        ),
      ],
    );
  }

  Widget _buildToggleBtn(String label, int index) {
     final isSelected = _historyToggleIndex == index;
     return GestureDetector(
       onTap: () {
         setState(() => _historyToggleIndex = index);
         if (index == 1 && _sosHistory.isEmpty) {
            _fetchSOSHistory();
         }
       },
       child: Container(
         padding: const EdgeInsets.symmetric(vertical: 12),
         decoration: BoxDecoration(
           color: isSelected ? Colors.white : Colors.transparent,
           borderRadius: BorderRadius.circular(10),
           boxShadow: isSelected ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)] : [],
         ),
         child: Center(
           child: Text(label, style: TextStyle(
             color: isSelected ? Colors.black : Colors.grey,
             fontWeight: FontWeight.bold,
           )),
         ),
       ),
     );
  }

  Widget _buildBookingsHistoryList() {
      return Consumer<BookingProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
             return const Center(child: CircularProgressIndicator(color: Color(0xFF0D47A1)));
          }

          final history = List<Booking>.from(provider.historyBookings);
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
            itemBuilder: (context, index) => _buildSimpleRideCard(history[index], isHistory: true),
          );
        },
      );
  }

  Widget _buildSOSHistoryList() {
     if (_isLoadingSOS) return const Center(child: CircularProgressIndicator(color: Colors.red));
     
     if (_sosHistory.isEmpty) {
        return Center(child: Text('No SOS Alerts found', style: TextStyle(color: Colors.grey.shade500)));
     }

     return ListView.builder(
       padding: const EdgeInsets.all(20),
       itemCount: _sosHistory.length,
       itemBuilder: (context, index) {
          final alert = _sosHistory[index];
          // Alert fields: alert_id, status, triggered_at, location: {latitude, longitude}
          final dateStr = alert['triggered_at'];
          DateTime? date;
          if (dateStr != null) date = DateTime.tryParse(dateStr);
          
          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
               color: Colors.white,
               borderRadius: BorderRadius.circular(16),
               border: Border.all(color: Colors.red.withOpacity(0.2)),
               boxShadow: [BoxShadow(color: Colors.red.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))]
            ),
            child: Column(
               crossAxisAlignment: CrossAxisAlignment.start,
               children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                       Row(
                         children: [
                            const Icon(Icons.warning_amber_rounded, color: Colors.red),
                            const SizedBox(width: 8),
                            Column(
                               crossAxisAlignment: CrossAxisAlignment.start,
                               children: [
                                  const Text('SOS Alert', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  if (date != null)
                                    Text(DateFormat('MMM d, yyyy • h:mm a').format(date.toLocal()), style: const TextStyle(color: Colors.grey, fontSize: 12)),
                               ],
                            )
                         ],
                       ),
                       Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                             color: (alert['status'] == 'CLOSED' ? Colors.green : Colors.red).withOpacity(0.1),
                             borderRadius: BorderRadius.circular(8)
                          ),
                          child: Text(alert['status'] ?? 'UNKNOWN', style: TextStyle(
                             color: alert['status'] == 'CLOSED' ? Colors.green : Colors.red,
                             fontWeight: FontWeight.bold, fontSize: 12
                          )),
                       )
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text('Location Details:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 4),
                  if (alert['location'] != null) ...[
                      Text('Lat: ${alert['location']['latitude'] ?? '-'}', style: const TextStyle(fontSize: 14)),
                      Text('Lng: ${alert['location']['longitude'] ?? '-'}', style: const TextStyle(fontSize: 14)),
                  ] else 
                      const Text('Location not available', style: TextStyle(fontStyle: FontStyle.italic)),
               ],
            ),
          );
       },
     );
  }

  // ---------------- PROFILE TAB ----------------


  Future<void> _triggerSOS() async {
    // 1. Identify if there is an active booking to link
    final provider = Provider.of<BookingProvider>(context, listen: false);
    final allBookings = List<Booking>.from(provider.homeBookings); // Use home bookings copy for safety
    
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
