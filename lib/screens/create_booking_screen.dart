import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_theme.dart';
import '../services/weekoff_service.dart';
import '../widgets/calendar_widget.dart';
import '../widgets/fx_widgets.dart';
import '../widgets/skeletons.dart';
import 'select_shift_screen.dart';

class CreateBookingScreen extends StatefulWidget {
  const CreateBookingScreen({super.key});

  @override
  State<CreateBookingScreen> createState() => _CreateBookingScreenState();
}

class _CreateBookingScreenState extends State<CreateBookingScreen> {
  final WeekoffService _weekoffService = WeekoffService();
  bool _isLoading = true;
  String? _error;
  List<String> _weekoffDays = [];
  String _selectionMode = 'single';
  List<DateTime> _selectedDates = [];
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _loadWeekoffConfig();
  }

  Future<void> _loadWeekoffConfig() async {
    final result = await _weekoffService.getWeekoffConfig();
    if (!mounted) return;
    if (result['success']) {
      setState(() {
        _weekoffDays = List<String>.from(result['weekoffDays']);
        _isLoading = false;
      });
    } else {
      setState(() {
        _error = result['error'];
        _isLoading = false;
      });
    }
  }

  void _onSelectionChanged(List<DateTime> single, DateTime? start, DateTime? end) {
    setState(() {
      _selectedDates = single;
      _startDate = start;
      _endDate = end;
    });
  }

  int _workingDayCount() {
    if (_selectionMode == 'single') return _selectedDates.length;
    if (_startDate == null || _endDate == null) return _startDate != null ? 1 : 0;
    int n = 0;
    DateTime c = _startDate!;
    while (!c.isAfter(_endDate!)) {
      final day = DateFormat('EEEE').format(c).toUpperCase();
      if (!_weekoffDays.contains(day)) n++;
      c = c.add(const Duration(days: 1));
    }
    return n;
  }

  void _continueToShift() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SelectShiftScreen(bookingData: {
          'selectionMode': _selectionMode,
          'selectedDates': _selectedDates,
          'startDate': _startDate,
          'endDate': _endDate,
          'daysCount': _workingDayCount(),
        }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: FxColors.background,
        body: SafeArea(
          child: Column(
            children: [
              _topBar(),
              const Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(20, 20, 20, 100),
                  child: SkeletonCalendar(),
                ),
              ),
            ],
          ),
        ),
      );
    }
    final count = _workingDayCount();
    final hasValid = _selectionMode == 'single' ? _selectedDates.isNotEmpty : (_startDate != null && _endDate != null);

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
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('New Booking', style: FxText.headlineLg()),
                        ],
                      ),
                    ),
                    if (_error != null) ...[
                      FxCard(
                        color: FxColors.onError,
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline_rounded, color: FxColors.error),
                            const SizedBox(width: 10),
                            Expanded(child: Text(_error!, style: FxText.body(color: FxColors.error))),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    FxCard(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          FxMetaLabel('Selection Mode'),
                          const SizedBox(height: 10),
                          FxSegmented(
                            labels: const ['Specific Dates', 'Date Range'],
                            selectedIndex: _selectionMode == 'single' ? 0 : 1,
                            onChanged: (i) => setState(() {
                              _selectionMode = i == 0 ? 'single' : 'range';
                              _selectedDates = [];
                              _startDate = null;
                              _endDate = null;
                            }),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    FxCard(
                      padding: const EdgeInsets.all(16),
                      child: CalendarWidget(
                        selectionMode: _selectionMode,
                        weekoffDays: _weekoffDays,
                        onSelectionChanged: _onSelectionChanged,
                      ),
                    ),
                    if (hasValid) ...[
                      const SizedBox(height: 16),
                      _selectionSummary(count),
                    ],
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
            label: hasValid ? 'Continue ($count ${count == 1 ? 'day' : 'days'})' : 'Select date(s)',
            trailingIcon: Icons.arrow_forward_rounded,
            onPressed: hasValid ? _continueToShift : null,
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
          Text('Create Booking', style: FxText.headlineSm(color: FxColors.primary)),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: FxColors.onSurfaceVariant),
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.clear();
              if (context.mounted) {
                Navigator.pushNamedAndRemoveUntil(context, '/login', (r) => false);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _selectionSummary(int count) {
    final summary = _selectionMode == 'single'
        ? '${_selectedDates.length} specific date${_selectedDates.length == 1 ? '' : 's'} selected'
        : 'Range: ${_startDate != null ? DateFormat('MMM d').format(_startDate!) : '—'} → ${_endDate != null ? DateFormat('MMM d').format(_endDate!) : '—'}';
    return FxCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: FxColors.primaryContainer.withOpacity(0.2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.event_available_rounded, color: FxColors.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(summary, style: FxText.titleSm()),
                Text('$count working ${count == 1 ? 'day' : 'days'} (weekoffs excluded)', style: FxText.bodySm()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
