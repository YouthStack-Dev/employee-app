import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/auth_provider.dart';
import '../models/shift_model.dart';
import '../services/booking_service.dart';
import '../services/weekoff_service.dart';
import '../constants/app_theme.dart';
import 'date_picker_screen.dart';
import 'select_shift_screen.dart';

class CreateBookingScreen extends StatefulWidget {
  const CreateBookingScreen({super.key});

  @override
  State<CreateBookingScreen> createState() => _CreateBookingScreenState();
}

class _CreateBookingScreenState extends State<CreateBookingScreen> {
  static const _royalBlue = FxColors.primary;
  static const _navy = FxColors.onSurface;
  static const _secondary = FxColors.onSurfaceVariant;
  static const _border = FxColors.surfaceContainerHigh;
  static const _pageBg = FxColors.background;
  static const _grayText = FxColors.onSurfaceVariant;

  final WeekoffService _weekoffService = WeekoffService();
  final BookingService _bookingService = BookingService();

  bool _isLoading = true;
  bool _isCreating = false;
  String? _error;
  List<String> _weekoffDays = [];
  String? _tenantId;
  int? _employeeId;

  // ---- Travel date ----
  String _dateMode = 'single';
  List<DateTime> _selectedDates = [];
  DateTime? _dateStart;
  DateTime? _dateEnd;

  // ---- Login ----
  bool _loginEnabled = true;
  String? _loginPickup;
  String? _loginDropoff;
  Shift? _loginShift;

  // ---- Logout ----
  bool _logoutEnabled = true;
  bool _logoutNextDay = false;
  String? _logoutPickup;
  String? _logoutDropoff;
  Shift? _logoutShift;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    final user = context.read<AuthProvider>().user;
    final officeName = user?.tenantName ?? user?.tenantId ?? 'Office';
    final pickupName = (user?.address?.trim().isNotEmpty ?? false)
        ? user!.address!.trim()
        : 'Primary Pickup';

    final result = await _weekoffService.getWeekoffConfig();
    final prefs = await SharedPreferences.getInstance();

    if (!mounted) return;
    setState(() {
      _weekoffDays = List<String>.from(
        result['success'] ? (result['weekoffDays'] ?? []) : [],
      );
      _error = result['success'] ? null : result['error'];
      _tenantId = prefs.getString('tenant_id');
      _employeeId = int.tryParse(prefs.getString('employee_id') ?? '');
      _loginPickup = pickupName;
      _loginDropoff = officeName;
      _logoutPickup = officeName;
      _logoutDropoff = pickupName;
      _isLoading = false;
    });
  }

  bool get _isValid {
    if (_travelDates.isEmpty) return false;
    if (_loginEnabled) {
      if (_loginPickup == null || _loginDropoff == null) return false;
      if (_loginShift == null) return false;
    }
    if (_logoutEnabled) {
      if (_logoutPickup == null || _logoutDropoff == null) return false;
      if (_logoutShift == null) return false;
    }
    return true;
  }

  bool _isWeekoff(DateTime date) {
    final dayNames = ['MONDAY', 'TUESDAY', 'WEDNESDAY', 'THURSDAY', 'FRIDAY', 'SATURDAY', 'SUNDAY'];
    return _weekoffDays.contains(dayNames[date.weekday - 1]);
  }

  String _fmtDate(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

  String _formatTravelDate(DateTime d) {
    final day = d.day;
    final suffix = day % 10 == 1 && day != 11
        ? 'st'
        : day % 10 == 2 && day != 12
            ? 'nd'
            : day % 10 == 3 && day != 13
                ? 'rd'
                : 'th';
    return '$day$suffix ${DateFormat('MMM').format(d)}';
  }

  List<DateTime> get _travelDates {
    if (_dateMode == 'single') return List.of(_selectedDates)..sort();
    if (_dateStart == null || _dateEnd == null) return [];
    final dates = <DateTime>[];
    var c = _dateStart!;
    while (!c.isAfter(_dateEnd!)) {
      dates.add(c);
      c = c.add(const Duration(days: 1));
    }
    return dates;
  }

  String get _dateLabel {
    final dates = _travelDates;
    if (dates.isEmpty) return 'Select date(s)';
    if (_dateMode == 'range') {
      return '${_formatTravelDate(dates.first)} – ${_formatTravelDate(dates.last)}';
    }
    if (dates.length == 1) return _formatTravelDate(dates.first);
    if (dates.length <= 3) return dates.map(_formatTravelDate).join(', ');
    return '${dates.length} dates';
  }

  Future<void> _pickTravelDate() async {
    final result = await Navigator.push<DateSelection>(
      context,
      MaterialPageRoute(
        builder: (_) => DatePickerScreen(
          initialMode: _dateMode,
          initialSingleDates: List.of(_selectedDates),
          initialStart: _dateStart,
          initialEnd: _dateEnd,
        ),
      ),
    );
    if (result == null) return;
    setState(() {
      _dateMode = result.mode;
      _selectedDates = List.of(result.singleDates);
      _dateStart = result.start;
      _dateEnd = result.end;
    });
  }

  Future<void> _pickRoute({required bool isLogin}) async {
    final user = context.read<AuthProvider>().user;
    final officeName = user?.tenantName ?? user?.tenantId ?? 'Office';
    final pickupName = (user?.address?.trim().isNotEmpty ?? false)
        ? user!.address!.trim()
        : 'Primary Pickup';

    if (isLogin) {
      setState(() {
        _loginPickup = pickupName;
        _loginDropoff = officeName;
      });
      _showRouteSheet(
        routes: {
          '$pickupName → $officeName': (pickupName, officeName),
        },
      );
    } else {
      setState(() {
        _logoutPickup = officeName;
        _logoutDropoff = pickupName;
      });
      _showRouteSheet(
        routes: {
          '$officeName → $pickupName': (officeName, pickupName),
        },
      );
    }
  }

  void _showRouteSheet({required Map<String, (String, String)> routes}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                  'Select Route',
                  style: FxText.headlineMd(),
                ),
              const SizedBox(height: 12),
              ...routes.entries.map((e) {
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.route_rounded, color: _royalBlue),
                  title: Text(
                    e.key,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: FxText.headlineSm(),
                  ),
                  onTap: () => Navigator.pop(ctx, e.key),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _selectLoginShift() async {
    final shift = await Navigator.push<Shift>(
      context,
      MaterialPageRoute(
        builder: (_) => const SelectShiftScreen(
          bookingData: {},
          pickerMode: true,
          initialShiftType: 'in',
        ),
      ),
    );
    if (shift != null) setState(() => _loginShift = shift);
  }

  Future<void> _selectLogoutShift() async {
    final shift = await Navigator.push<Shift>(
      context,
      MaterialPageRoute(
        builder: (_) => const SelectShiftScreen(
          bookingData: {},
          pickerMode: true,
          initialShiftType: 'out',
        ),
      ),
    );
    if (shift != null) setState(() => _logoutShift = shift);
  }

  Future<void> _handleCreate() async {
    if (!_isValid) return;
    if (_tenantId == null || _employeeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Session invalid, please login again.'), backgroundColor: FxColors.error),
      );
      return;
    }
    final workingDates = _travelDates.where((d) => !_isWeekoff(d)).toList();
    if (workingDates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$_dateLabel — no valid working days selected.'),
          backgroundColor: FxColors.error,
        ),
      );
      return;
    }

    if (_logoutEnabled && _logoutNextDay) {
      for (final d in workingDates) {
        final ld = d.add(const Duration(days: 1));
        if (_isWeekoff(ld)) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${_formatTravelDate(ld)} is a weekoff. Next-day logout can\'t be booked for ${_formatTravelDate(d)}.',
              ),
              backgroundColor: FxColors.error,
            ),
          );
          return;
        }
      }
    }

    setState(() => _isCreating = true);

    final result = await _bookingService.createRoundTripBooking(
      tenantId: _tenantId!,
      employeeId: _employeeId!,
      bookingDates: workingDates.map(_fmtDate).toList(),
      loginShift: _loginEnabled ? _loginShift : null,
      logoutShift: _logoutEnabled ? _logoutShift : null,
      logoutNextDay: _logoutNextDay,
      loginPickup: _loginPickup,
      loginDropoff: _loginDropoff,
      logoutPickup: _logoutPickup,
      logoutDropoff: _logoutDropoff,
    );

    if (!mounted) return;
    setState(() => _isCreating = false);

    if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Schedule created successfully'),
          backgroundColor: _royalBlue,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      );
      Navigator.pushNamedAndRemoveUntil(context, '/schedules', (route) => false);
    } else {
      setState(() => _error = result['error']);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_error ?? 'Failed to create schedule'), backgroundColor: FxColors.error),
      );
    }
  }

  Future<void> _confirmClose() async {
    final hasInput = _travelDates.isNotEmpty ||
        _loginShift != null ||
        _logoutShift != null ||
        _loginEnabled != true ||
        _logoutEnabled != true ||
        _logoutNextDay;
    if (!hasInput) {
      Navigator.pop(context);
      return;
    }
    final leave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Cancel schedule?'),
        content: const Text('Your selections will be discarded.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep editing')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Discard', style: FxText.titleSm(color: FxColors.error)),
          ),
        ],
      ),
    );
    if (leave == true && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: _pageBg,
        body: SafeArea(
          child: Column(
            children: [
              _header(),
              const Expanded(child: Center(child: CircularProgressIndicator(color: _royalBlue))),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: _pageBg,
      body: SafeArea(
        child: Column(
          children: [
            _header(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ---- Travel date(s) ----
                    Text(
                      'Travel date(s)',
                      style: FxText.titleSm(color: FxColors.onSurfaceVariant).copyWith(fontSize: 14),
                    ),
                    const SizedBox(height: 14),
                    _card(
                      child: _dateField(),
                    ),
                    const SizedBox(height: 22),

                    // ---- Login section ----
                    _sectionCheckbox(
                      label: 'Login (Go to work)',
                      enabled: _loginEnabled,
                      onChanged: (v) => setState(() => _loginEnabled = v),
                    ),
                    if (_loginEnabled) ...[
                      const SizedBox(height: 14),
                      _card(
                        child: Column(
                          children: [
                            _routeRow(
                              pickup: _loginPickup,
                              dropoff: _loginDropoff,
                              onTap: () => _pickRoute(isLogin: true),
                            ),
                            const SizedBox(height: 16),
                            _shiftField(
                              shift: _loginShift,
                              hint: 'Select Shift',
                              onTap: _selectLoginShift,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 22),
                    ] else
                      const SizedBox(height: 22),

                    // ---- Logout section ----
                    _sectionCheckbox(
                      label: 'Logout (Return home)',
                      enabled: _logoutEnabled,
                      onChanged: (v) => setState(() => _logoutEnabled = v),
                    ),
                    if (_logoutEnabled) ...[
                      const SizedBox(height: 14),
                      _card(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _nextDayRow(),
                            const _DashedDivider(color: FxColors.surfaceContainerHighest),
                            _routeRow(
                              pickup: _logoutPickup,
                              dropoff: _logoutDropoff,
                              onTap: () => _pickRoute(isLogin: false),
                            ),
                            const SizedBox(height: 16),
                            _shiftField(
                              shift: _logoutShift,
                              hint: _logoutNextDay
                                  ? 'Select Shift (next day)'
                                  : 'Select Shift',
                              onTap: _selectLogoutShift,
                            ),
                            if (_logoutNextDay)
                              Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: Text(
                                  'Return trip is scheduled for the next day.',
                                  style: FxText.body(color: _secondary),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _bottomBar(),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 8),
      child: Row(
        children: [
          InkWell(
            onTap: _confirmClose,
            borderRadius: BorderRadius.circular(12),
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(Icons.close_rounded, size: 22, color: _navy),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Create Schedule',
            style: FxText.headlineLg(),
          ),
          const Spacer(),
          if (_isCreating)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2.5, color: _royalBlue),
            ),
        ],
      ),
    );
  }

  Widget _bottomBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: FxColors.surfaceContainerHigh, width: 1)),
        boxShadow: const [
          BoxShadow(
            color: FxColors.primaryContainer,
            blurRadius: 12,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(30, 14, 30, 16),
        child: SizedBox(
          height: 72,
          child: ElevatedButton(
            onPressed: _isValid && !_isCreating ? _handleCreate : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: _royalBlue,
              disabledBackgroundColor: FxColors.surfaceContainerHigh,
              disabledForegroundColor: _grayText,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(48)),
            ),
            child: Text(
              _isCreating ? 'Creating...' : 'Create',
              style: FxText.headlineLg().copyWith(fontSize: 20, letterSpacing: 0.2),
            ),
          ),
        ),
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: FxColors.surfaceContainerLow),
      ),
      child: child,
    );
  }

  Widget _dateField() {
    return InkWell(
      onTap: _pickTravelDate,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: FxColors.surfaceContainerLow, width: 1.5),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_month_outlined, size: 22, color: _royalBlue),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _dateLabel,
                style: FxText.bodyLg(
                  color: _travelDates.isNotEmpty ? _navy : _secondary,
                ),
              ),
            ),
            const Icon(Icons.chevron_right_rounded, size: 22, color: _grayText),
          ],
        ),
      ),
    );
  }

  Widget _sectionCheckbox({
    required String label,
    required bool enabled,
    required ValueChanged<bool> onChanged,
  }) {
    return InkWell(
      onTap: () => onChanged(!enabled),
      borderRadius: BorderRadius.circular(10),
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: enabled ? _royalBlue : Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: enabled ? _royalBlue : _border,
                width: 2,
              ),
            ),
            child: enabled
                ? const Icon(Icons.check_rounded, size: 17, color: Colors.white)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: FxText.headlineMd(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _routeRow({
    required String? pickup,
    required String? dropoff,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Row(
        children: [
          const Icon(Icons.home_outlined, size: 22, color: _navy),
          const SizedBox(width: 10),
            Expanded(
              child: Text(
                '${pickup ?? 'Pickup'} → ${dropoff ?? 'Dropoff'}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: FxText.bodyLg(),
              ),
            ),
          const SizedBox(width: 8),
          const Icon(Icons.keyboard_arrow_down_rounded, size: 22, color: _royalBlue),
        ],
      ),
    );
  }

  Widget _shiftField({
    required Shift? shift,
    required String hint,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: FxColors.surfaceContainerLow, width: 1.5),
        ),
        child: Row(
          children: [
            const Icon(Icons.schedule_rounded, size: 22, color: _royalBlue),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                shift != null
                    ? '${shift.shiftCode} • ${_formatTime(shift.shiftTime)}'
                    : hint,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: FxText.bodyLg(
                  color: shift != null ? _navy : _secondary,
                ),
              ),
            ),
            const Icon(Icons.chevron_right_rounded, size: 22, color: _grayText),
          ],
        ),
      ),
    );
  }

  String _formatTime(String? time) {
    if (time == null || time.isEmpty) return '';
    final parts = time.split(':');
    if (parts.length >= 2) return '${parts[0]}:${parts[1]}';
    return time;
  }

  Widget _nextDayRow() {
    return Row(
      children: [
        Expanded(
          child: Text(
            'Logout on next day',
            style: FxText.bodyLg(),
          ),
        ),
        Switch(
          value: _logoutNextDay,
          onChanged: (v) => setState(() => _logoutNextDay = v),
          activeTrackColor: _royalBlue,
          activeThumbColor: Colors.white,
          inactiveThumbColor: Colors.white,
          inactiveTrackColor: FxColors.surfaceContainerHighest,
          trackOutlineColor: WidgetStatePropertyAll(Colors.transparent),
        ),
      ],
    );
  }
}

class _DashedDivider extends StatelessWidget {
  final Color color;

  const _DashedDivider({required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: CustomPaint(
        size: const Size(double.infinity, 1.5),
        painter: _DashedLinePainter(color),
      ),
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  final Color color;

  _DashedLinePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    const dashWidth = 6.0;
    const dashGap = 5.0;
    double x = 0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, 0), Offset(x + dashWidth, 0), paint);
      x += dashWidth + dashGap;
    }
  }

  @override
  bool shouldRepaint(covariant _DashedLinePainter oldDelegate) =>
      oldDelegate.color != color;
}