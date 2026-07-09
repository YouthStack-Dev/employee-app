import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_theme.dart';
import '../models/shift_model.dart';
import '../services/booking_service.dart';
import '../services/shift_service.dart';
import '../widgets/fx_widgets.dart';
import '../widgets/skeletons.dart';

class EditBookingScreen extends StatefulWidget {
  final int bookingId;
  const EditBookingScreen({super.key, required this.bookingId});

  @override
  State<EditBookingScreen> createState() => _EditBookingScreenState();
}

class _EditBookingScreenState extends State<EditBookingScreen> {
  final BookingService _bookingService = BookingService();
  final ShiftService _shiftService = ShiftService();

  bool _isLoading = true;
  bool _isUpdating = false;
  Map<String, dynamic>? _booking;
  List<Shift> _shifts = [];
  int? _selectedShiftId;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final results = await Future.wait([
      _bookingService.getBookingDetails(widget.bookingId),
      _shiftService.fetchShifts(),
    ]);
    final bookingRes = results[0];
    final shiftRes = results[1];
    if (!mounted) return;
    if (bookingRes['success'] && shiftRes['success']) {
      final bookingObj = bookingRes['data'];
      List<Shift> inShifts = (shiftRes['shifts']['in'] as List).cast<Shift>();
      List<Shift> outShifts = (shiftRes['shifts']['out'] as List).cast<Shift>();

      // Gender-based visibility (strict split), same rule as create-booking.
      final prefs = await SharedPreferences.getInstance();
      final viewerIsFemale = Shift.genderIsFemale(prefs.getString('gender'));
      final all = [...inShifts, ...outShifts];
      var selectable = Shift.visibleFor(all, viewerIsFemale: viewerIsFemale);
      // Always keep the booking's current shift visible for context, even if
      // the gender filter would otherwise hide it.
      final currentId = bookingObj.shiftId;
      if (currentId != null && !selectable.any((s) => s.shiftId == currentId)) {
        final current = all.where((s) => s.shiftId == currentId).toList();
        selectable = [...current, ...selectable];
      }

      setState(() {
        _booking = {
          'id': bookingObj.id,
          'booking_date': bookingObj.date,
          'shift_id': bookingObj.shiftId,
          'status': bookingObj.status,
          'pickup_location': bookingObj.pickupLocation,
          'drop_location': bookingObj.dropLocation,
          'log_type': bookingObj.logType,
        };
        _shifts = selectable;
        _selectedShiftId = bookingObj.shiftId;
        _isLoading = false;
      });
    } else {
      setState(() {
        _error = bookingRes['error'] ?? shiftRes['error'];
        _isLoading = false;
      });
    }
  }

  Future<void> _handleUpdate() async {
    if (_selectedShiftId == null) return;
    final isCancelled = _booking!['status'] == 'Cancelled';
    if (!isCancelled && _selectedShiftId == _booking!['shift_id']) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a different shift')),
      );
      return;
    }
    final actionLabel = isCancelled ? 'Rebook' : 'Update';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          isCancelled ? 'Rebook cancelled booking?' : 'Update booking?',
          style: FxText.headlineSm(),
        ),
        content: Text(
          isCancelled
              ? 'This will rebook the cancelled ride with the selected shift.'
              : 'Switch to the selected shift?',
          style: FxText.body(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(actionLabel),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => _isUpdating = true);
    final updatePayload = <String, dynamic>{'shift_id': _selectedShiftId};
    if (isCancelled) {
      updatePayload['rebook'] = true;
      updatePayload['booking_date'] = _booking!['booking_date'];
    }
    final result = await _bookingService.updateBooking(
      widget.bookingId,
      updatePayload,
    );
    if (!mounted) return;
    setState(() => _isUpdating = false);
    if (result['success']) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isCancelled ? 'Booking rebooked' : 'Booking updated'),
          backgroundColor: FxColors.primary,
        ),
      );
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['error'] ?? 'Update failed'),
          backgroundColor: FxColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: FxColors.background,
        appBar: AppBar(title: const Text('Edit Booking', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600))),
        body: const SingleChildScrollView(
          padding: EdgeInsets.all(20),
          child: Column(
            children: [
              SkeletonBookingDetailsCard(),
              SizedBox(height: 20),
              Text('Select Shift', style: TextStyle(fontSize: 16)),
              SizedBox(height: 16),
              SkeletonShiftRow(),
              SkeletonShiftRow(),
              SkeletonShiftRow(),
              SkeletonShiftRow(),
            ],
          ),
        ),
      );
    }
    if (_error != null) {
      return Scaffold(
        backgroundColor: FxColors.background,
        appBar: AppBar(),
        body: Center(
          child: Text(_error!, style: FxText.body(color: FxColors.error)),
        ),
      );
    }

    final isCancelled = _booking!['status'] == 'Cancelled';
    final dateStr = _booking!['booking_date'];
    final date = DateTime.tryParse(dateStr) ?? DateTime.now();
    final formattedDate = DateFormat('EEEE, MMM d, yyyy').format(date);
    final currentShift = _shifts.firstWhere(
      (s) => s.shiftId == _booking!['shift_id'],
      orElse: () => Shift(name: 'Unknown'),
    );

    return Scaffold(
      backgroundColor: FxColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _topBar(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Edit Booking', style: FxText.headlineLg()),
                          const SizedBox(height: 4),
                          Text(
                            'Modify your scheduled shift transport details.',
                            style: FxText.body(
                              color: FxColors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Merged Booking Card
                    FxCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    FxMetaLabel('Booking ID'),
                                    const SizedBox(height: 4),
                                    Text(
                                      '#MLT-${_booking!['id']}',
                                      style: FxText.headlineLg(),
                                    ),
                                  ],
                                ),
                              ),
                              FxPill(
                                text: (currentShift.logType == 'IN' ? 'LOGIN' : 'LOGOUT'),
                                color: FxColors.primary,
                                background: FxColors.primary.withOpacity(0.1),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              const Icon(Icons.calendar_month_outlined, size: 16, color: FxColors.onSurfaceVariant),
                              const SizedBox(width: 6),
                              Text(formattedDate, style: FxText.title()),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.schedule_rounded, size: 16, color: FxColors.onSurfaceVariant),
                              const SizedBox(width: 6),
                              Text(_formatTime(currentShift.shiftTime), style: FxText.title()),
                              const SizedBox(width: 16),
                              Icon(
                                currentShift.logType == 'IN' ? Icons.login_rounded : Icons.logout_rounded,
                                size: 16,
                                color: FxColors.onSurfaceVariant,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                currentShift.logType == 'IN' ? 'Login' : 'Logout',
                                style: FxText.title(color: FxColors.onSurfaceVariant),
                              ),
                            ],
                          ),
                          if (_booking!['pickup_location'] != null ||
                              _booking!['drop_location'] != null) ...[
                            const SizedBox(height: 20),
                            FxRouteTimeline(
                              pickup:
                                  _booking!['pickup_location'] ??
                                  'Not specified',
                              drop:
                                  _booking!['drop_location'] ?? 'Not specified',
                              pickupLabel: 'PICKUP LOCATION',
                              dropLabel: 'DROP-OFF LOCATION',
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    FxCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isCancelled
                                ? 'Choose Rebook Shift'
                                : 'Choose New Shift',
                            style: FxText.headlineSm(),
                          ),
                          const SizedBox(height: 12),
                          ..._shifts.map((s) => _shiftRow(s)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: FxPrimaryButton(
            label: _isUpdating
                ? (isCancelled ? 'Rebooking...' : 'Updating...')
                : (isCancelled ? 'Rebook booking' : 'Update booking'),
            trailingIcon: Icons.check_rounded,
            onPressed: _isUpdating ? null : _handleUpdate,
            loading: _isUpdating,
          ),
        ),
      ),
    );
  }

  Widget _topBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 16, 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: FxColors.primary),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 4),
          Text('Edit', style: FxText.headlineSm(color: FxColors.primary)),
        ],
      ),
    );
  }

  String _formatTime(String? time) {
    if (time == null || time.isEmpty) return '-';
    final parts = time.split(':');
    if (parts.length >= 2) {
      return '${parts[0]}:${parts[1]}';
    }
    return time;
  }

  Widget _shiftRow(Shift s) {
    final isSelected = _selectedShiftId == s.shiftId;
    final isCurrent = s.shiftId == _booking!['shift_id'];
    return GestureDetector(
      onTap: () => setState(() => _selectedShiftId = s.shiftId),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected
              ? FxColors.primary.withOpacity(0.08)
              : FxColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? FxColors.primary : Colors.transparent,
            width: isSelected ? 2 : 0,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? FxColors.primary : FxColors.outline,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          color: FxColors.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        s.logType == 'IN' ? Icons.login_rounded : Icons.logout_rounded,
                        size: 16,
                        color: isSelected ? FxColors.primary : FxColors.onSurfaceVariant,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        s.logType == 'IN' ? 'Login' : 'Logout',
                        style: FxText.bodySm(
                          color: isSelected ? FxColors.primary : FxColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _formatTime(s.shiftTime),
                    style: FxText.title(
                      color: isSelected ? FxColors.primary : FxColors.onSurface,
                    ),
                  ),
                ],
              ),
            ),
            if (isCurrent)
              FxPill(
                text: 'CURRENT',
                color: FxColors.onPrimary,
                background: const Color(0xFF00B894),
              ),
          ],
        ),
      ),
    );
  }
}
