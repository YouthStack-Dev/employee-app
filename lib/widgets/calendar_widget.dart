import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../constants/app_theme.dart';

class CalendarWidget extends StatefulWidget {
  final String selectionMode; // 'single' or 'range'
  final List<String> weekoffDays;
  final Function(List<DateTime> singleDates, DateTime? start, DateTime? end) onSelectionChanged;
  final List<DateTime> initialSingleDates;
  final DateTime? initialStart;
  final DateTime? initialEnd;

  const CalendarWidget({
    super.key,
    required this.selectionMode,
    required this.weekoffDays,
    required this.onSelectionChanged,
    this.initialSingleDates = const [],
    this.initialStart,
    this.initialEnd,
  });

  @override
  State<CalendarWidget> createState() => _CalendarWidgetState();
}

class _CalendarWidgetState extends State<CalendarWidget> {
  DateTime _currentDate = DateTime.now();
  List<DateTime> _selectedDates = [];
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _selectedDates = List<DateTime>.of(widget.initialSingleDates);
    _startDate = widget.initialStart;
    _endDate = widget.initialEnd;
    if (widget.initialSingleDates.isNotEmpty) {
      final first = widget.initialSingleDates.reduce(
        (a, b) => a.isAfter(b) ? b : a,
      );
      _currentDate = DateTime(first.year, first.month, 1);
    } else if (widget.initialStart != null) {
      _currentDate = DateTime(widget.initialStart!.year, widget.initialStart!.month, 1);
    }
  }

  @override
  void didUpdateWidget(CalendarWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectionMode != widget.selectionMode) {
      _clearSelection();
    }
  }

  void _clearSelection() {
    setState(() {
      _selectedDates = [];
      _startDate = null;
      _endDate = null;
    });
  }

  void _changeMonth(int delta) {
    setState(() {
      _currentDate = DateTime(_currentDate.year, _currentDate.month + delta, 1);
    });
  }

  bool _isWeekoff(DateTime date) {
    final dayName = DateFormat('EEEE').format(date).toUpperCase();
    return widget.weekoffDays.contains(dayName);
  }

  bool _isPast(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return date.isBefore(today);
  }

  void _handleDateTap(DateTime date) {
    if (_isPast(date) || _isWeekoff(date)) return;

    setState(() {
      if (widget.selectionMode == 'single') {
        if (_selectedDates.any((d) => d.isAtSameMomentAs(date))) {
          _selectedDates.removeWhere((d) => d.isAtSameMomentAs(date));
        } else {
          _selectedDates.add(date);
        }
      } else {
        // Range mode
        if (_startDate == null || (_startDate != null && _endDate != null)) {
          _startDate = date;
          _endDate = null;
        } else if (_startDate != null && _endDate == null) {
          if (date.isBefore(_startDate!)) {
            _endDate = _startDate;
            _startDate = date;
          } else {
            _endDate = date;
          }
        }
      }
    });

    widget.onSelectionChanged(_selectedDates, _startDate, _endDate);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildHeader(),
            const SizedBox(height: 20),
            _buildWeekDays(),
            const SizedBox(height: 10),
            _buildCalendarGrid(),
            const SizedBox(height: 20),
            _buildLegend(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          onPressed: () => _changeMonth(-1),
          icon: const Icon(Icons.arrow_back_ios, color: FxColors.primary),
        ),
        Text(
          DateFormat('MMMM yyyy').format(_currentDate),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        IconButton(
          onPressed: () => _changeMonth(1),
          icon: const Icon(Icons.arrow_forward_ios, color: FxColors.primary),
        ),
      ],
    );
  }

  Widget _buildWeekDays() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
          .map((day) => Expanded(
                child: Center(
                  child: Text(
                    day,
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
                  ),
                ),
              ))
          .toList(),
    );
  }

  Widget _buildCalendarGrid() {
    final daysInMonth = DateTime(_currentDate.year, _currentDate.month + 1, 0).day;
    final firstDayOfWeek = DateTime(_currentDate.year, _currentDate.month, 1).weekday % 7;
    
    final List<Widget> dayWidgets = [];

    // Empty cells for days before the 1st
    for (int i = 0; i < firstDayOfWeek; i++) {
        dayWidgets.add(Container());
    }

    // Days
    for (int i = 1; i <= daysInMonth; i++) {
      final date = DateTime(_currentDate.year, _currentDate.month, i);
      final isWeekoff = _isWeekoff(date);
      final isPast = _isPast(date);
      final isDisabled = isWeekoff || isPast;

      bool isSelected = false;
      bool isStart = false;
      bool isEnd = false;
      bool isInRange = false;

      if (widget.selectionMode == 'single') {
        isSelected = _selectedDates.any((d) => d.year == date.year && d.month == date.month && d.day == date.day);
      } else {
        if (_startDate != null) {
          isStart = date.year == _startDate!.year && date.month == _startDate!.month && date.day == _startDate!.day;
        }
        if (_endDate != null) {
          isEnd = date.year == _endDate!.year && date.month == _endDate!.month && date.day == _endDate!.day;
        }
        if (_startDate != null && _endDate != null) {
            // Check if strictly between start and end
            if (date.isAfter(_startDate!) && date.isBefore(_endDate!)) {
                isInRange = true;
            }
        }
      }

      dayWidgets.add(
        GestureDetector(
          onTap: isDisabled ? null : () => _handleDateTap(date),
          child: Container(
            margin: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: isSelected || isStart || isEnd 
                  ? FxColors.primary 
                  : isInRange && !isWeekoff
                      ? FxColors.primary.withValues(alpha: 0.2)
                      : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Text(
                  '$i',
                  style: TextStyle(
                    color: isDisabled 
                        ? Colors.grey.withValues(alpha: 0.5) 
                        : (isSelected || isStart || isEnd ? Colors.white : Colors.black),
                    decoration: isDisabled ? TextDecoration.lineThrough : null,
                  ),
                ),
                if (isWeekoff && !isPast && ((widget.selectionMode == 'single') || isInRange))
                  Positioned(
                    bottom: 2,
                    child: Container(
                      width: 4, 
                      height: 4, 
                      decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                    ),
                  )
              ],
            ),
          ),
        ),
      );
    }

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 7,
      children: dayWidgets,
    );
  }

  Widget _buildLegend() {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 15,
      children: [
        _buildLegendItem('Weekoff', Colors.white, borderColor: Colors.red),
        _buildLegendItem('Selected', FxColors.primary),
        if (widget.selectionMode == 'range')
           _buildLegendItem('In Range', FxColors.primary.withValues(alpha: 0.2)),
      ],
    );
  }
  
  Widget _buildLegendItem(String label, Color color, {Color? borderColor}) {
      return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
              Container(
                  width: 16, height: 16,
                  decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(4),
                      border: borderColor != null ? Border.all(color: borderColor) : null,
                  ),
              ),
              const SizedBox(width: 8),
              Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
      );
  }
}
