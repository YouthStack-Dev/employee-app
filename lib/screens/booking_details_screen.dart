import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_colors.dart';
import '../models/booking_model.dart';
import '../services/booking_service.dart';
import '../providers/auth_provider.dart';
import 'edit_booking_screen.dart';
import 'track_driver_screen.dart';

class BookingDetailsScreen extends StatefulWidget {
  final int bookingId;
  final bool isReadOnly;

  const BookingDetailsScreen({super.key, required this.bookingId, this.isReadOnly = false});

  @override
  State<BookingDetailsScreen> createState() => _BookingDetailsScreenState();
}

class _BookingDetailsScreenState extends State<BookingDetailsScreen> {
  final BookingService _bookingService = BookingService();
  Booking? _booking;
  bool _isLoading = true;
  String? _error;
  bool _isCancelling = false;
  String? _tenantId; // Resolved Tenant ID

  @override
  void initState() {
    super.initState();
    _fetchBookingDetails();
  }

  Future<void> _fetchBookingDetails() async {
    setState(() => _isLoading = true);
    final result = await _bookingService.getBookingDetails(widget.bookingId);
    
    // Fetch stored tenant ID as fallback
    final prefs = await SharedPreferences.getInstance();
    final prefsTenantId = prefs.getString('tenant_id');
    
    if (mounted) {
      if (result['success']) {
        final bookingData = result['data'] as Booking;
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        
        // Resolve Tenant ID: Booking -> Prefs -> Auth -> Default
        String resolvedId = bookingData.tenantId?.toString() ?? prefsTenantId ?? authProvider.user?.tenantId ?? 'SAM001';
        
        // Fix for API returning '1' when it should be the alphanumeric tenant ID
        if (resolvedId == '1' && (prefsTenantId != null || authProvider.user?.tenantId != null)) {
           resolvedId = prefsTenantId ?? authProvider.user!.tenantId!;
        }

        setState(() {
          _booking = bookingData;
          _tenantId = resolvedId;
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = result['error'];
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleCancelBooking() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Booking'),
        content: Text('Are you sure you want to cancel booking #${widget.bookingId}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('No')),
          TextButton(onPressed: () => Navigator.pop(context, true), style: TextButton.styleFrom(foregroundColor: Colors.red), child: const Text('Yes, Cancel')),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isCancelling = true);
      final result = await _bookingService.cancelBooking(widget.bookingId);
      if (mounted) {
        setState(() => _isCancelling = false);
        if (result['success']) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Booking cancelled successfully'), backgroundColor: Colors.green));
          Navigator.pop(context, true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['error'] ?? 'Failed to cancel'), backgroundColor: Colors.red));
        }
      }
    }
  }

  Future<void> _handleEditBooking() async {
    final result = await Navigator.push(context, MaterialPageRoute(builder: (context) => EditBookingScreen(bookingId: widget.bookingId)));
    if (result == true) _fetchBookingDetails();
  }

  void _handleTrackDriver() {
     if (_booking == null || _tenantId == null) return;
     
     Navigator.push(context, MaterialPageRoute(builder: (context) => TrackDriverScreen(booking: {
        'booking_id': _booking!.id,
        'status': _booking!.status,
        'pickup_latitude': _booking!.pickupLatitude,
        'pickup_longitude': _booking!.pickupLongitude,
        'drop_latitude': _booking!.dropLatitude,
        'drop_longitude': _booking!.dropLongitude,
        'pickup_location': _booking!.pickupLocation,
        'drop_location': _booking!.dropLocation,
        'route_details': _booking!.routeDetails,
        'tenant_id': _tenantId,
     },
     tenantId: _tenantId,
     )));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Booking Details', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF6C63FF),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Text(_error!, style: const TextStyle(color: Colors.red)), const SizedBox(height: 10), ElevatedButton(onPressed: _fetchBookingDetails, child: const Text('Retry'))]));
    if (_booking == null) return const Center(child: Text('Booking not found'));

    final statusColors = {
      'Request': const Color(0xFFfdcb6e),
      'Scheduled': const Color(0xFF74b9ff),
      'Ongoing': const Color(0xFFa29bfe),
      'Completed': const Color(0xFF00b894),
      'Cancelled': const Color(0xFF636e72),
      'No-Show': const Color(0xFFe17055),
    };
    final bookingDate = DateTime.tryParse(_booking!.date ?? '');
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    // Comparison: bookingDate (which is usually just YYYY-MM-DD or start of day) >= today
    // If date is null/invalid, assume it's NOT future/today (safest default)
    final isFutureOrToday = bookingDate != null && !bookingDate.isBefore(today);

    final statusColor = statusColors[_booking!.status] ?? const Color(0xFF6C63FF);
    
    final isRequestOrScheduled = _booking!.status == 'Request' || _booking!.status == 'Scheduled';
    final isCancelled = _booking!.status == 'Cancelled';

    final canCancel = !widget.isReadOnly && isRequestOrScheduled;
    
    // Enable Edit if:
    // 1. It's Request or Scheduled
    // 2. OR It's Cancelled AND is for Today or Future (Reactivate)
    final canEdit = !widget.isReadOnly && (isRequestOrScheduled || (isCancelled && isFutureOrToday));
    
    // Check if driver is assigned
    final hasDriver = _booking!.routeDetails?['driver_details'] != null;
    final canTrack = ['Scheduled', 'Ongoing'].contains(_booking!.status) && hasDriver;
    
    // Resolve Shift Time
    final displayShiftTime = _booking!.shiftTime?.substring(0, 5) ?? _booking!.pickupTime?.substring(0, 5) ?? 'N/A';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Header Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: const Color(0xFF6C63FF), borderRadius: BorderRadius.circular(15), boxShadow: [BoxShadow(color: const Color(0xFF6C63FF).withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))]),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Booking #${_booking!.id}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                    Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(15)), child: Text(_booking!.status ?? 'UNKNOWN', style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.bold))),
                  ],
                ),
                const SizedBox(height: 10),
                Text('📅 ${DateFormat('EEEE, MMMM d, yyyy').format(DateTime.tryParse(_booking!.date ?? '') ?? DateTime.now())}', style: const TextStyle(color: Colors.white, fontSize: 16)),
                const SizedBox(height: 5),
                const Text('👤 Employee Access', style: TextStyle(color: Colors.white70, fontSize: 14)),
                
                // Track Button if active AND driver assigned
                if (canTrack)
                   Padding(
                     padding: const EdgeInsets.only(top: 15),
                     child: ElevatedButton.icon(
                        onPressed: _handleTrackDriver,
                        icon: const Icon(Icons.map, size: 16, color: Color(0xFF6C63FF)),
                        label: const Text('Track Driver', style: TextStyle(color: Color(0xFF6C63FF), fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                     ),
                   )
              ],
            ),
          ),

          const SizedBox(height: 15),

          // Location Details
          _buildInfoCard('📍 Location Details', [
            _buildLocationItem('Pickup Location', _booking!.pickupLocation, _booking!.pickupLatitude, _booking!.pickupLongitude, icon: '📍'),
            const Divider(height: 30),
            _buildLocationItem('Drop Location', _booking!.dropLocation, _booking!.dropLatitude, _booking!.dropLongitude, icon: '🎯'),
          ]),

          const SizedBox(height: 15),

          // Booking Info
          _buildInfoCard('ℹ️ Booking Information', [
            _buildRow('Shift ID', '${_booking!.shiftId ?? "N/A"}'),
            _buildRow('Shift Time', displayShiftTime),
            _buildRow('Tenant ID', _tenantId ?? 'N/A'),
            _buildRow('Type', _booking!.logType ?? 'N/A'),
            _buildRow('Active', _tenantId != null ? '✓ Yes' : '✗ No', valueColor: Colors.green),
          ]),

          const SizedBox(height: 15),

          // OTP Section
          if (_booking!.boardingOtp != null || _booking!.deboardingOtp != null)
             Container(
               padding: const EdgeInsets.all(20),
               decoration: BoxDecoration(color: const Color(0xFFF0EFFF), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF6C63FF), width: 2)),
               child: Column(
                 children: [
                    const Text('🔐 Trip OTPs', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 15),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                         if (_booking!.boardingOtp != null) _buildOtpDisplay('Boarding', _booking!.boardingOtp!),
                         if (_booking!.deboardingOtp != null) _buildOtpDisplay('Deboarding', _booking!.deboardingOtp!),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Text('Share these with your driver', style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey, fontSize: 12)),
                 ],
               ),
             ),

          const SizedBox(height: 24),

          // Action Buttons
          if (canCancel || canEdit)
            Column(
              children: [
                if (canEdit)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _handleEditBooking,
                      style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), backgroundColor: const Color(0xFF6C63FF)),
                      child: Text(isCancelled ? 'Reactivate Booking' : 'Edit Booking', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                if (canCancel) ...[
                  if (canEdit) const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: _isCancelling ? null : _handleCancelBooking,
                      style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFFD63031), width: 2), padding: const EdgeInsets.symmetric(vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      child: _isCancelling ? const CircularProgressIndicator(strokeWidth: 2) : const Text('Cancel This Booking', style: TextStyle(color: Color(0xFFD63031), fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ],
            )
        ],
      ),
    );
  }

  Widget _buildInfoCard(String title, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2D3436))),
          const SizedBox(height: 15),
          ...children,
        ],
      ),
    );
  }

  Widget _buildLocationItem(String label, String? address, double? lat, double? lng, {required String icon}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
        const SizedBox(height: 5),
        Text(address ?? 'Not specified', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, height: 1.4)),
        if (lat != null && lng != null)
           Padding(
             padding: const EdgeInsets.only(top: 5),
             child: Text('$icon ${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}', style: const TextStyle(fontSize: 12, color: Colors.blueGrey, fontFamily: 'monospace')),
           ),
      ],
    );
  }

  Widget _buildRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w600)),
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: valueColor ?? Colors.black)),
        ],
      ),
    );
  }

  Widget _buildOtpDisplay(String label, String value) {
     return Column(
       children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 5),
          Text(value, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF6C63FF), letterSpacing: 2)),
       ],
     );
  }
}
