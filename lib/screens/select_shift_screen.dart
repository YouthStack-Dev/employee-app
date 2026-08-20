import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/shift_model.dart';
import '../providers/time_format_provider.dart';
import '../utils/time_format.dart';
import '../services/shift_service.dart';
import '../services/booking_service.dart';
import '../services/weekoff_service.dart';
import '../constants/app_theme.dart';
import '../constants/app_colors.dart';
import '../widgets/fx_widgets.dart';
import '../widgets/skeletons.dart';
import 'booking_success_screen.dart';

class SelectShiftScreen extends StatefulWidget {
  final Map<String, dynamic> bookingData;

  /// When true, this screen acts as a shift picker: selecting a shift pops
  /// back with the chosen [Shift] instead of booking.
  final bool pickerMode;

  /// Preselects the Login/Logout tab ('in' or 'out') at open time.
  final String? initialShiftType;

  const SelectShiftScreen({
    super.key,
    required this.bookingData,
    this.pickerMode = false,
    this.initialShiftType,
  });

  @override
  State<SelectShiftScreen> createState() => _SelectShiftScreenState();
}

class _SelectShiftScreenState extends State<SelectShiftScreen> {
  final ShiftService _shiftService = ShiftService();
  final BookingService _bookingService = BookingService();

  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _error;
  
  // Tab state
  late String _shiftType; // 'in' or 'out'
  List<Shift> _inShifts = [];
  List<Shift> _outShifts = [];
  List<String> _weekoffDays = [];
  Shift? _selectedShift;

  @override
  void initState() {
    super.initState();
    _shiftType = widget.initialShiftType ?? 'in';
    _fetchShiftsAndWeekoff();
  }

  Future<void> _fetchShiftsAndWeekoff() async {
    // Parallel fetch
    final shiftsFuture = _shiftService.fetchShifts();
    final weekoffFuture = WeekoffService().getWeekoffConfig();
    
    final results = await Future.wait([shiftsFuture, weekoffFuture]);
    final shiftResult = results[0];
    final weekoffResult = results[1];

    if (mounted) {
      // Handle Weekoff
      List<String> weekoffDays = [];
      if (weekoffResult['success'] == true) {
          weekoffDays = (weekoffResult['weekoffDays'] as List).cast<String>();
      }

      // Handle Shifts
      if (shiftResult['success']) {
        // Gender-based shift visibility (strict split): a female employee sees
        // only female-only shifts; everyone else sees all EXCEPT female-only.
        // Gender comes from the login profile (persisted to prefs at login).
        final prefs = await SharedPreferences.getInstance();
        final viewerIsFemale = Shift.genderIsFemale(prefs.getString('gender'));

        final inAll = (shiftResult['shifts']['in'] as List).cast<Shift>();
        final outAll = (shiftResult['shifts']['out'] as List).cast<Shift>();

        setState(() {
          _inShifts = Shift.visibleFor(inAll, viewerIsFemale: viewerIsFemale);
          _outShifts = Shift.visibleFor(outAll, viewerIsFemale: viewerIsFemale);
          _weekoffDays = weekoffDays;
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = shiftResult['error'];
          _isLoading = false;
        });
      }
    }
  }

  bool _isWeekoff(DateTime date) {
      final dayNames = ['MONDAY', 'TUESDAY', 'WEDNESDAY', 'THURSDAY', 'FRIDAY', 'SATURDAY', 'SUNDAY'];
      // DateTime.weekday: 1=Mon, 7=Sun
      final dayName = dayNames[date.weekday - 1]; 
      return _weekoffDays.contains(dayName);
  }

  void _switchTab(String type) {
    setState(() {
      _shiftType = type;
      _selectedShift = null; // Clear selection on tab switch
    });
  }

  void _handleSelectShift(Shift shift) {
    if (widget.pickerMode) {
      Navigator.pop(context, shift);
      return;
    }
    setState(() {
      _selectedShift = shift;
    });
  }

  void _handleConfirm() {
    if (_selectedShift == null) return;
    if (widget.pickerMode) {
      Navigator.pop(context, _selectedShift);
      return;
    }
    _bookDirectly();
  }

  /// Books the selected shift immediately, skipping the confirmation page.
  Future<void> _bookDirectly() async {
    final shift = _selectedShift;
    if (shift == null) return;

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      // Compute booking dates the same way the confirmation screen did
      // (single selection vs date range, excluding weekoffs).
      List<DateTime> dates = [];
      final selectionMode = widget.bookingData['selectionMode'];
      if (selectionMode == 'single') {
        dates = List<DateTime>.from(widget.bookingData['selectedDates']);
      } else {
        final start = widget.bookingData['startDate'] as DateTime;
        final end = widget.bookingData['endDate'] as DateTime;
        var current = start;
        while (!current.isAfter(end)) {
          dates.add(current);
          current = current.add(const Duration(days: 1));
        }
      }
      final validDates = dates.where((d) => !_isWeekoff(d)).toList()..sort();

      final bookingDates = validDates.map((d) {
        final y = d.year.toString().padLeft(4, '0');
        final m = d.month.toString().padLeft(2, '0');
        final day = d.day.toString().padLeft(2, '0');
        return '$y-$m-$day';
      }).toList();

      if (bookingDates.isEmpty) {
        setState(() {
          _error = 'No valid working days selected.';
          _isSubmitting = false;
        });
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      final tenantId = prefs.getString('tenant_id');
      final employeeId = prefs.getString('employee_id');

      if (tenantId == null || employeeId == null) {
        setState(() {
          _error = 'User session invalid. Please login again.';
          _isSubmitting = false;
        });
        return;
      }

      final result = await _bookingService.createBooking(
        tenantId: tenantId,
        employeeId: int.parse(employeeId),
        bookingDates: bookingDates,
        shiftId: shift.shiftId!,
      );

      if (!mounted) return;

      if (result['success']) {
        final createdCount = (result['createdCount'] as num?)?.toInt() ?? bookingDates.length;
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => BookingSuccessScreen(
              bookingId: result['bookingId']?.toString(),
              status: 'Request',
              message: result['message']?.toString() ?? 'Booking created successfully',
              daysCount: createdCount,
            ),
          ),
          (route) => route.settings.name == '/schedules' || route.isFirst,
        );
      } else {
        setState(() {
          _error = result['error'];
          _isSubmitting = false;
        });
        _showError(_error ?? 'Failed to book');
      }
    } catch (e) {
      setState(() {
        _error = 'Booking failed. Please try again.';
        _isSubmitting = false;
      });
      _showError(_error!);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.red));
  }

  @override
  Widget build(BuildContext context) {
    final currentShifts = _shiftType == 'in' ? _inShifts : _outShifts;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Shift', style: TextStyle(color: Colors.white)),
        backgroundColor: AppColors.primary,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: FxPrimaryButton(
            label: _selectedShift != null
                ? (widget.pickerMode ? 'Choose ${_selectedShift!.shiftCode}' : 'Book ${_selectedShift!.shiftCode}')
                : (widget.pickerMode ? 'Select Shift' : 'Select a Shift'),
            trailingIcon: Icons.arrow_forward_rounded,
            onPressed: (_isLoading || _isSubmitting) ? null : (_selectedShift != null ? _handleConfirm : null),
            loading: _isSubmitting,
          ),
        ),
      ),
      body: _isLoading 
          ? const Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                children: [
                  SizedBox(height: 60),
                  SkeletonShiftCard(),
                  SkeletonShiftCard(),
                  SkeletonShiftCard(),
                  SkeletonShiftCard(),
                ],
              ),
            )
          : Column(
              children: [
                if (_error != null)
                   Padding(
                     padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                     child: Text(_error!, style: const TextStyle(color: Colors.red)),
                   ),
                 if (!(widget.pickerMode && widget.initialShiftType != null))
                   _buildTabs(),
                 Padding(
                   padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
                   child: Align(
                     alignment: Alignment.centerLeft,
                     child: Text('Available Shifts',
                         style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black87)),
                   ),
                 ),
                 Expanded(
                    child: currentShifts.isEmpty 
                       ? _buildEmptyState()
                       : GridView.builder(
                           padding: const EdgeInsets.fromLTRB(20, 0, 20, 15),
                           gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                             crossAxisCount: 3,
                             mainAxisSpacing: 16,
                             crossAxisSpacing: 16,
                             mainAxisExtent: 40,
                           ),
                           itemCount: currentShifts.length,
                           itemBuilder: (context, index) {
                              return _buildShiftCard(currentShifts[index]);
                           },
                         ),
                  ),
              ],
            ),
    );
  }

  Widget _buildTabs() {
      return Container(
          margin: const EdgeInsets.fromLTRB(20, 15, 20, 0),
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
              children: [
                  _buildTabItem('Login (Go to Work)', 'in', Icons.login_rounded),
                  _buildTabItem('Logout (Return to Home)', 'out', Icons.logout_rounded),
              ],
          ),
      );
  }
  
  Widget _buildTabItem(String label, String type, IconData icon) {
      final isSelected = _shiftType == type;
      return Expanded(
          child: GestureDetector(
              onTap: () => _switchTab(type),
              child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                  decoration: BoxDecoration(
                      color: isSelected ? AppColors.primary : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                          Icon(icon, size: 16, color: isSelected ? Colors.white : Colors.grey[600]),
                          const SizedBox(width: 5),
                          Flexible(
                              child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                      label, 
                                      style: TextStyle(
                                          fontSize: 13,
                                          color: isSelected ? Colors.white : Colors.grey[600],
                                          fontWeight: FontWeight.bold,
                                      ),
                                  ),
                              ),
                          ),
                      ],
                  ),
              ),
          ),
      );
  }

  Widget _buildEmptyState() {
      return Center(
          child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                  Icon(Icons.calendar_today_outlined, size: 60, color: Colors.grey[300]),
                  const SizedBox(height: 15),
                  Text('No ${_shiftType == 'in' ? 'login' : 'logout'} shifts available', 
                      style: TextStyle(fontSize: 18, color: Colors.grey[600], fontWeight: FontWeight.bold)),
              ],
          ),
      );
  }

  String _formatTime(String? time) {
    if (time == null || time.isEmpty) return '';
    return formatTimeOfDay(time, is24Hour: context.watch<TimeFormatProvider>().is24Hour);
  }

  Widget _buildShiftCard(Shift shift) {
      final isSelected = _selectedShift?.shiftId == shift.shiftId;
      
      return GestureDetector(
          onTap: () => _handleSelectShift(shift),
          child: Container(
              decoration: BoxDecoration(
                  color: isSelected ? FxColors.primaryContainer.withValues(alpha: 0.25) : Colors.white,
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(
                      color: isSelected ? AppColors.primary : Colors.grey[300]!,
                      width: 1,
                  ),
              ),
              alignment: Alignment.center,
              child: Text(
                  _formatTime(shift.shiftTime ?? shift.startTime),
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: isSelected ? AppColors.primary : Colors.black87,
                  ),
              ),
          ),
      );
  }
}
