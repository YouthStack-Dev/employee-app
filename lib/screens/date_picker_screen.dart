import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../constants/app_theme.dart';
import '../services/weekoff_service.dart';
import '../widgets/calendar_widget.dart';
import '../widgets/fx_widgets.dart';
import '../widgets/skeletons.dart';

class DateSelection {
  final String mode; // 'single' or 'range'
  final List<DateTime> singleDates;
  final DateTime? start;
  final DateTime? end;

  const DateSelection({
    required this.mode,
    required this.singleDates,
    this.start,
    this.end,
  });
}

class DatePickerScreen extends StatefulWidget {
  final String initialMode;
  final List<DateTime> initialSingleDates;
  final DateTime? initialStart;
  final DateTime? initialEnd;

  const DatePickerScreen({
    super.key,
    this.initialMode = 'single',
    this.initialSingleDates = const [],
    this.initialStart,
    this.initialEnd,
  });

  @override
  State<DatePickerScreen> createState() => _DatePickerScreenState();
}

class _DatePickerScreenState extends State<DatePickerScreen> {
  static const _royalBlue = FxColors.primary;
  static const _navy = FxColors.onSurface;
  static const _grayText = FxColors.onSurfaceVariant;

  final WeekoffService _weekoffService = WeekoffService();

  bool _isLoading = true;
  String? _error;
  List<String> _weekoffDays = [];
  late String _selectionMode;
  List<DateTime> _singleDates = [];
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _selectionMode = widget.initialMode;
    _singleDates = List.of(widget.initialSingleDates);
    _startDate = widget.initialStart;
    _endDate = widget.initialEnd;
    _loadWeekoffConfig();
  }

  Future<void> _loadWeekoffConfig() async {
    final result = await _weekoffService.getWeekoffConfig();
    if (!mounted) return;
    setState(() {
      _weekoffDays = List<String>.from(
        result['success'] ? (result['weekoffDays'] ?? []) : [],
      );
      _error = result['success'] ? null : result['error'];
      _isLoading = false;
    });
  }

  bool get _isValid {
    if (_selectionMode == 'single') return _singleDates.isNotEmpty;
    return _startDate != null && _endDate != null;
  }

  void _onSelectionChanged(List<DateTime> single, DateTime? start, DateTime? end) {
    setState(() {
      _singleDates = single;
      _startDate = start;
      _endDate = end;
    });
  }

  bool _isWeekoff(DateTime date) {
    final dayNames = ['MONDAY', 'TUESDAY', 'WEDNESDAY', 'THURSDAY', 'FRIDAY', 'SATURDAY', 'SUNDAY'];
    return _weekoffDays.contains(dayNames[date.weekday - 1]);
  }

  List<DateTime> _workingDates() {
    if (_selectionMode == 'single') return List.of(_singleDates);
    if (_startDate == null || _endDate == null) {
      return _startDate != null ? [_startDate!] : [];
    }
    final dates = <DateTime>[];
    var c = _startDate!;
    while (!c.isAfter(_endDate!)) {
      dates.add(c);
      c = c.add(const Duration(days: 1));
    }
    return dates.where((d) => !_isWeekoff(d)).toList();
  }

  String _formatShort(DateTime d) {
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

  void _confirm(List<DateTime> workingDates) {
    Navigator.pop(
      context,
      DateSelection(
        mode: _selectionMode,
        singleDates: List.of(workingDates),
        start: _startDate,
        end: _endDate,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FxColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _header(),
            Expanded(
              child: _isLoading
                  ? const SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(18, 12, 18, 100),
                      child: SkeletonCalendar(),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(18, 12, 18, 100),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_error != null) ...[
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: FxColors.onError,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                _error!,
                                style: FxText.body(color: FxColors.error),
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                          Text(
                            'Selection Mode',
                            style: FxText.title(color: FxColors.onSurfaceVariant),
                          ),
                          const SizedBox(height: 10),
                          FxSegmented(
                            labels: const ['Specific Dates', 'Date Range'],
                            selectedIndex: _selectionMode == 'single' ? 0 : 1,
                            onChanged: (i) => setState(() {
                              _selectionMode = i == 0 ? 'single' : 'range';
                              _singleDates = [];
                              _startDate = null;
                              _endDate = null;
                            }),
                          ),
                          const SizedBox(height: 16),
                          CalendarWidget(
                            selectionMode: _selectionMode,
                            weekoffDays: _weekoffDays,
                            onSelectionChanged: _onSelectionChanged,
                          ),
                          const SizedBox(height: 14),
                          Text(
                            _summaryText(),
                            style: FxText.bodyLg(),
                          ),
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

  String _summaryText() {
    final working = _workingDates();
    if (working.isEmpty) {
      return _selectionMode == 'single'
          ? 'Tap dates to pick specific travel days.'
          : 'Choose a start and end date for the range.';
    }
    final workingCount = _selectionMode == 'range'
        ? working.length
        : working.length;
    final label = _selectionMode == 'range'
        ? '${_formatShort(_startDate!)} – ${_formatShort(_endDate!)}'
        : working.length == 1
            ? _formatShort(working.first)
            : working.map(_formatShort).join(', ');
    return '$label · $workingCount day${workingCount == 1 ? '' : 's'}';
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
      child: Row(
        children: [
          InkWell(
            onTap: () => Navigator.pop(context),
            borderRadius: BorderRadius.circular(12),
            child: const Padding(
              padding: EdgeInsets.all(6),
              child: Icon(Icons.arrow_back_rounded, size: 24, color: _navy),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'Select Travel Date(s)',
            style: FxText.headlineLg().copyWith(fontSize: 20),
          ),
        ],
      ),
    );
  }

  Widget _bottomBar() {
    return Container(
      decoration: BoxDecoration(
        color: FxColors.surfaceContainerLowest,
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
            onPressed: _isValid ? () => _confirm(_workingDates()) : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: _royalBlue,
              disabledBackgroundColor: FxColors.surfaceContainerHigh,
              disabledForegroundColor: _grayText,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(48)),
            ),
            child: Text(
              'Continue',
              style: FxText.headlineLg().copyWith(fontSize: 20, letterSpacing: 0.2),
            ),
          ),
        ),
      ),
    );
  }
}