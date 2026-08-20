import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_theme.dart';
import '../models/shift_model.dart';
import '../providers/time_format_provider.dart';
import '../utils/time_format.dart';
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
  String _shiftType = 'in';
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
        final logType = (bookingObj.logType ?? '').toString().toLowerCase();
        _shiftType = logType == 'out' ? 'out' : 'in';
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
                              Text(formattedDate, style: FxText.bodyLg()),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.schedule_rounded, size: 16, color: FxColors.onSurfaceVariant),
                              const SizedBox(width: 6),
                              Text(_formatTime(currentShift.shiftTime), style: FxText.bodyLg()),
                              const SizedBox(width: 16),
                              Icon(
                                currentShift.logType == 'IN' ? Icons.login_rounded : Icons.logout_rounded,
                                size: 16,
                                color: FxColors.onSurfaceVariant,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                currentShift.logType == 'IN' ? 'Login' : 'Logout',
                                style: FxText.bodyLg(color: FxColors.onSurfaceVariant),
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
                          _buildShiftTabs(),
                          const SizedBox(height: 14),
                          if (_filteredShifts.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 24),
                              child: Center(
                                child: Text(
                                  'No ${_shiftType == 'in' ? 'login' : 'logout'} shifts available',
                                  style: FxText.body(color: FxColors.onSurfaceVariant),
                                ),
                              ),
                            )
                          else
                            GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              padding: const EdgeInsets.fromLTRB(0, 0, 0, 15),
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                mainAxisSpacing: 16,
                                crossAxisSpacing: 16,
                                mainAxisExtent: 40,
                              ),
                              itemCount: _filteredShifts.length,
                              itemBuilder: (context, index) => _shiftCard(_filteredShifts[index]),
                            ),
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
    return formatTimeOfDay(time, is24Hour: context.watch<TimeFormatProvider>().is24Hour);
  }

  List<Shift> get _filteredShifts =>
      _shifts.where((s) => _shiftType == 'in' ? s.logType == 'IN' : s.logType == 'OUT').toList();

  Widget _buildShiftTabs() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: FxColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _buildShiftTabItem('Login (Go to Work)', 'in', Icons.login_rounded),
          _buildShiftTabItem('Logout (Return to Home)', 'out', Icons.logout_rounded),
        ],
      ),
    );
  }

  Widget _buildShiftTabItem(String label, String type, IconData icon) {
    final selected = _shiftType == type;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _shiftType = type;
            if (_filteredShifts.isNotEmpty && !_filteredShifts.any((s) => s.shiftId == _selectedShiftId)) {
              _selectedShiftId = null;
            }
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 17, color: selected ? FxColors.primary : FxColors.onSurfaceVariant),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: selected ? FxColors.primary : FxColors.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _shiftCard(Shift s) {
    final isSelected = _selectedShiftId == s.shiftId;
    final isCurrent = s.shiftId == _booking!['shift_id'];
    return Stack(
      clipBehavior: Clip.none,
      children: [
        GestureDetector(
          onTap: () => setState(() => _selectedShiftId = s.shiftId),
          child: Container(
            decoration: BoxDecoration(
              color: isSelected ? FxColors.primaryContainer.withValues(alpha: 0.25) : Colors.white,
              borderRadius: BorderRadius.circular(5),
              border: Border.all(
                color: isSelected ? FxColors.primary : Colors.grey[300]!,
                width: 1,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              _formatTime(s.shiftTime),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: isSelected ? FxColors.primary : Colors.black87,
              ),
            ),
          ),
        ),
        if (isCurrent)
          Positioned(
            top: -4,
            right: -4,
            child: Container(
              width: 12,
              height: 12,
              decoration: const BoxDecoration(
                color: Color(0xFF00B894),
                shape: BoxShape.circle,
              ),
            ),
          ),
      ],
    );
  }
}
