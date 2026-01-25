import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../providers/auth_provider.dart';
import '../providers/booking_provider.dart';
import '../constants/app_colors.dart';
import '../services/booking_service.dart';
import '../services/alert_service.dart';
import '../models/booking_model.dart';
import 'booking_details_screen.dart';
import 'edit_booking_screen.dart';
import 'track_driver_screen.dart';

class SchedulesScreen extends StatefulWidget {
  const SchedulesScreen({super.key});

  @override
  State<SchedulesScreen> createState() => _SchedulesScreenState();
}

class _SchedulesScreenState extends State<SchedulesScreen> with TickerProviderStateMixin {
  String _selectedTab = 'active';
  bool _isSOSPressed = false;
  double _sosProgress = 0.0;
  Timer? _sosTimer;
  late AnimationController _pulseController;
  late AnimationController _progressController;
  final AlertService _alertService = AlertService();

  final List<Map<String, dynamic>> _tabs = [
    {
      'key': 'active',
      'label': 'Active',
      'statuses': ['Ongoing', 'Scheduled', 'Request', 'Approved'],
    },
    {
      'key': 'completed',
      'label': 'Completed',
      'statuses': ['Completed', 'No-Show'],
    },
    {
      'key': 'cancelled',
      'label': 'Cancelled',
      'statuses': ['Cancelled', 'Rejected'],
    },
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
      lowerBound: 1.0,
      upperBound: 1.1,
    );
    _progressController = AnimationController(
        vsync: this,
        duration: const Duration(seconds: 3)
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshBookings();
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _progressController.dispose();
    _sosTimer?.cancel();
    super.dispose();
  }

  void _refreshBookings() {
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    if (user?.employeeId != null) {
      // Logic from RN: Yesterday to +6 days from today
      final now = DateTime.now();
      final start = now.subtract(const Duration(days: 1));
      final end = start.add(const Duration(days: 6)); // cover 7 days total

      final dateFormat = DateFormat('yyyy-MM-dd');
      
      Provider.of<BookingProvider>(context, listen: false).fetchBookings(
        user!.employeeId!,
        startDate: dateFormat.format(start),
        endDate: dateFormat.format(end),
      );
    }
  }

  List<Booking> _getFilteredBookings(List<Booking> allBookings) {
    final currentTab = _tabs.firstWhere((t) => t['key'] == _selectedTab);
    final allowedStatuses = currentTab['statuses'] as List<String>;
    
    return allBookings.where((b) {
      return allowedStatuses.contains(b.status);
    }).toList();
  }

  void _handleSOSPressIn() {
    setState(() {
      _isSOSPressed = true;
      _sosProgress = 0.0;
    });
    _pulseController.repeat(reverse: true);
    _progressController.forward(from: 0);

    _sosTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      setState(() {
        _sosProgress += 0.1;
      });
      if (_sosProgress >= 3.0) {
        timer.cancel();
        _triggerSOS();
      }
    });
  }

  void _handleSOSPressOut() {
    if (_sosProgress < 3.0) {
      setState(() {
        _isSOSPressed = false;
        _sosProgress = 0.0;
      });
      _pulseController.stop();
      _pulseController.value = 1.0;
      _progressController.stop();
      _sosTimer?.cancel();
    }
  }

  Future<void> _triggerSOS() async {
    setState(() {
      _isSOSPressed = false;
      _sosProgress = 0.0;
    });
    _pulseController.stop();
    _progressController.stop();

    // Find active booking
    final bookingProvider = Provider.of<BookingProvider>(context, listen: false);
    final ongoing = bookingProvider.bookings.firstWhere(
      (b) => ['Ongoing', 'Scheduled', 'Request'].contains(b.status),
      orElse: () => Booking(),
    );

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    final result = await _alertService.triggerSOSAlert(
      bookingId: ongoing.id,
      notes: "Emergency SOS triggered from Flutter Schedules screen",
    );

    if (mounted) {
      Navigator.pop(context); // Remove loader
      if (result['success']) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('✓ SOS Alert Sent'),
            content: const Text('Your emergency alert has been sent successfully. Help is on the way!'),
            actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
          ),
        );
      } else {
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text(result['error'] ?? 'SOS Failed'), backgroundColor: Colors.red),
         );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              _buildSliverAppBar(),
              SliverToBoxAdapter(child: _buildTabs()),
              _buildBookingList(),
            ],
          ),
          if (_isSOSPressed) _buildSOSOverlay(),
          _buildFloatingButtons(),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 120,
      floating: false,
      pinned: true,
      backgroundColor: const Color(0xFF6C63FF),
      elevation: 8,
      flexibleSpace: FlexibleSpaceBar(
        title: const Text('Schedules', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        centerTitle: false,
        titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh, color: Colors.white),
          onPressed: _refreshBookings,
        ),
        IconButton(
          icon: const Icon(Icons.logout, color: Colors.white),
          onPressed: () {
            Provider.of<AuthProvider>(context, listen: false).logout();
            Navigator.pushReplacementNamed(context, '/login');
          },
        ),
      ],
    );
  }

  Widget _buildTabs() {
    final bookingProvider = Provider.of<BookingProvider>(context);
    final allBookings = bookingProvider.bookings;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
      child: Row(
        children: _tabs.map((tab) {
          final isActive = _selectedTab == tab['key'];
          final allowedStatuses = tab['statuses'] as List<String>;
          final count = allBookings.where((b) => allowedStatuses.contains(b.status)).length;

          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedTab = tab['key']),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isActive ? const Color(0xFF6C63FF) : const Color(0xFFF8F9FA),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      tab['label'],
                      style: TextStyle(
                        color: isActive ? Colors.white : const Color(0xFF636E72),
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                      child: Text('$count', style: const TextStyle(color: Color(0xFF6C63FF), fontWeight: FontWeight.bold, fontSize: 10)),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBookingList() {
    return Consumer<BookingProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading) return const SliverFillRemaining(child: Center(child: CircularProgressIndicator()));
        
        final filtered = _getFilteredBookings(provider.bookings);
        if (filtered.isEmpty) {
          return SliverFillRemaining(
            child: Center(child: Text('No bookings found', style: TextStyle(color: Colors.grey[600]))),
          );
        }

        // Grouping by date
        Map<String, List<Booking>> grouped = {};
        for (var b in filtered) {
           final date = b.date ?? 'Unknown';
           if (!grouped.containsKey(date)) grouped[date] = [];
           grouped[date]!.add(b);
        }

        List<String> sortedDates = grouped.keys.toList()..sort();

        return SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 100),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                  final dateStr = sortedDates[index];
                  final dayBookings = grouped[dateStr]!;
                  
                  DateTime? dt = DateTime.tryParse(dateStr);
                  String header = dt != null ? DateFormat('MMM d, EEEE').format(dt) : dateStr;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(header, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2D3436))),
                      ),
                      ...dayBookings.map((b) => _buildBookingCard(b)),
                    ],
                  );
              },
              childCount: sortedDates.length,
            ),
          ),
        );
      },
    );
  }

  Widget _buildBookingCard(Booking booking) {
    final statusColors = {
      'Request': const Color(0xFFfdcb6e),
      'Scheduled': const Color(0xFF7c3aed),
      'Ongoing': const Color(0xFF0984e3),
      'Completed': const Color(0xFF00b894),
      'Cancelled': const Color(0xFF636e72),
      'No-Show': const Color(0xFFd63031),
    };
    final color = statusColors[booking.status] ?? const Color(0xFF6C63FF);
    final tripType = booking.logType == 'IN' ? 'Login' : 'Logout';
    final hasDriver = booking.routeDetails?['driver_details']?['driver_id'] != null;

    final canCancel = booking.status == 'Request' || booking.status == 'Scheduled';

    // Get Tenant ID from AuthProvider if missing in booking
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final tenantId = booking.tenantId ?? authProvider.user?.tenantId ?? 'SAM001';

    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => BookingDetailsScreen(bookingId: booking.id!))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF4F46E5), width: 1.5),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 2))],
        ),
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Text('🏁', style: TextStyle(fontSize: 20)),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(tripType, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          Text(booking.shiftTime?.substring(0, 5) ?? booking.pickupTime?.substring(0, 5) ?? 'N/A', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18)),
                        ],
                      )
                    ],
                  ),
                  const Icon(Icons.expand_less, color: Colors.grey),
                ],
              ),
            ),

            // Status Badge
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(20)),
                child: Text('⏰ ${booking.status}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12)),
              ),
            ),

            // Locations
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildLocationRow(const Color(0xFFEF4444), booking.pickupLocation),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(margin: const EdgeInsets.only(left: 5), width: 2, height: 16, color: Colors.grey[300]),
                  ),
                  _buildLocationRow(const Color(0xFF10B981), booking.dropLocation),
                ],
              ),
            ),

            // OTP Section
            if (booking.boardingOtp != null || booking.deboardingOtp != null || booking.escortOtp != null)
              _buildOTPSection(booking),

            // Actions
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                children: [
                  if (canCancel)
                     _buildActionIcon(Icons.close, Colors.red, () => _handleCancel(booking)),
                  
                  const SizedBox(width: 8),
                  
                  _buildActionIcon(Icons.edit, Colors.grey[700]!, () => _handleEdit(booking), 
                      disabled: (booking.status != 'Request' && booking.status != 'Cancelled')),
                  
                  if (hasDriver) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TrackDriverScreen(booking: {
                           'booking_id': booking.id,
                           'status': booking.status,
                           'pickup_latitude': booking.pickupLatitude,
                           'pickup_longitude': booking.pickupLongitude,
                           'drop_latitude': booking.dropLatitude,
                           'drop_longitude': booking.dropLongitude,
                           'pickup_location': booking.pickupLocation,
                           'drop_location': booking.dropLocation,
                           'route_details': booking.routeDetails,
                           'tenant_id': tenantId.toString(), // Use resolved Tenant ID
                        },
                        tenantId: tenantId.toString(), // Explicitly pass tenantId
                        ))),
                        icon: const Icon(Icons.map, size: 16),
                        label: const Text('Track'),
                        style: ElevatedButton.styleFrom(
                           backgroundColor: const Color(0xFFF3F4F6),
                           foregroundColor: Colors.black,
                           elevation: 0,
                           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
                        ),
                      ),
                    )
                  ]
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildLocationRow(Color dotColor, String? text) {
     return Row(
       children: [
         Container(width: 12, height: 12, decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle)),
         const SizedBox(width: 12),
         Expanded(child: Text(text ?? '---', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis)),
       ],
     );
  }

  Widget _buildOTPSection(Booking b) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFFF8F9FA), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFE9ECEF))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Trip OTPs', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          const SizedBox(height: 8),
          Row(
            children: [
              if (b.boardingOtp != null) _buildOTPItem('Boarding', b.boardingOtp!),
              if (b.deboardingOtp != null) _buildOTPItem('Deboarding', b.deboardingOtp!),
              if (b.escortOtp != null) _buildOTPItem('Escort', b.escortOtp!),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildOTPItem(String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF6C63FF), fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildActionIcon(IconData icon, Color color, VoidCallback onTap, {bool disabled = false}) {
     return GestureDetector(
       onTap: disabled ? null : onTap,
       child: Container(
         width: 40, height: 40,
         decoration: BoxDecoration(color: disabled ? const Color(0xFFE5E7EB) : const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(8)),
         child: Icon(icon, color: disabled ? Colors.grey[400] : color, size: 20),
       ),
     );
  }

  Widget _buildSOSOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.7),
      width: double.infinity,
      height: double.infinity,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ScaleTransition(
              scale: _pulseController,
              child: Container(
                width: 150,
                height: 150,
                decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('🚨', style: TextStyle(fontSize: 40)),
                      Text('${(3 - _sosProgress).ceil()}', style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 30),
            const Text('Hold for Emergency SOS', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            const Text('Release to cancel', style: TextStyle(color: Colors.white, fontSize: 16)),
            const SizedBox(height: 30),
            Container(
              width: 200,
              height: 10,
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(5)),
              child: AnimatedBuilder(
                animation: _progressController,
                builder: (context, child) {
                  return FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: _progressController.value,
                    child: Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(5))),
                  );
                },
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingButtons() {
    return Positioned(
      bottom: 20,
      right: 20,
      left: 20,
      child: Row(
        children: [
          // SOS Button
          Expanded(
            flex: 2,
            child: GestureDetector(
              onLongPressStart: (_) => _handleSOSPressIn(),
              onLongPressEnd: (_) => _handleSOSPressOut(),
              child: Container(
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [BoxShadow(color: Colors.red.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))],
                ),
                child: const Center(child: Text('SOS', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold))),
              ),
            ),
          ),
          const SizedBox(width: 15),
          // Add Button
          FloatingActionButton(
            heroTag: 'addBtn',
            backgroundColor: const Color(0xFF6C63FF),
            onPressed: () => Navigator.pushNamed(context, '/create_booking'),
            child: const Icon(Icons.add, size: 36, color: Colors.white),
          ),
        ],
      ),
    );
  }

  void _handleCancel(Booking b) {
     final bookingService = BookingService();
     showDialog(
       context: context,
       builder: (context) => AlertDialog(
         title: const Text('Cancel Booking'),
         content: const Text('Are you sure you want to cancel this booking?'),
         actions: [
           TextButton(onPressed: () => Navigator.pop(context), child: const Text('No')),
           TextButton(
             onPressed: () async {
               // Show loading
               showDialog(
                 context: context,
                 barrierDismissible: false,
                 builder: (_) => const Center(child: CircularProgressIndicator()),
               );
               
               final res = await bookingService.cancelBooking(b.id!);
               
               if (mounted) {
                 Navigator.pop(context); // Close loading
                 Navigator.pop(context); // Close confirm dialog
                 
                 if (res['success']) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cancelled successfully'), backgroundColor: Colors.green));
                    _refreshBookings();
                 } else {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['error'] ?? 'Failed'), backgroundColor: Colors.red));
                 }
               }
             },
             child: const Text('Yes', style: TextStyle(color: Colors.red)),
           )
         ],
       ),
     );
  }

  void _handleEdit(Booking b) {
     Navigator.push(context, MaterialPageRoute(builder: (_) => EditBookingScreen(bookingId: b.id!)))
        .then((value) { if (value == true) _refreshBookings(); });
  }
}
