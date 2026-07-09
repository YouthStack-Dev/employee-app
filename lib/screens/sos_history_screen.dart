import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../constants/app_theme.dart';
import '../services/alert_service.dart';
import '../widgets/fx_widgets.dart';
import '../widgets/skeletons.dart';
import 'sos_details_screen.dart';

class SosHistoryScreen extends StatefulWidget {
  const SosHistoryScreen({super.key});

  @override
  State<SosHistoryScreen> createState() => _SosHistoryScreenState();
}

class _SosHistoryScreenState extends State<SosHistoryScreen> {
  final AlertService _service = AlertService();
  bool _isLoading = false;
  List<dynamic> _alerts = [];
  String? _error;
  DateTime _from = DateTime.now().subtract(const Duration(days: 7));
  DateTime _to = DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetch());
  }

  Future<void> _fetch() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    final fmt = DateFormat('yyyy-MM-dd');
    final r = await _service.fetchMyAlerts(
      startDate: fmt.format(_from),
      endDate: fmt.format(_to),
    );
    if (!mounted) return;
    if (r['success']) {
      setState(() {
        _alerts = r['data']?['data']?['alerts'] ?? [];
        _isLoading = false;
      });
    } else {
      setState(() {
        _error = r['error'] ?? 'Failed to load SOS history';
        _isLoading = false;
      });
    }
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final initial = isFrom ? _from : _to;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: FxColors.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        if (isFrom) {
          _from = picked;
          if (_to.isBefore(_from)) _to = _from;
        } else {
          _to = picked;
          if (_from.isAfter(_to)) _from = _to;
        }
      });
    }
  }

  Color _statusColor(String status, bool falseAlarm) {
    if (falseAlarm) return FxColors.outline;
    switch (status) {
      case 'CLOSED':
        return const Color(0xFF00B894);
      case 'TRIGGERED':
        return FxColors.error;
      case 'ACKNOWLEDGED':
        return const Color(0xFFE17055);
      default:
        return FxColors.outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalCount = _alerts.length;
    final activeCount = _alerts
        .where((a) => a['status'] == 'TRIGGERED' || a['status'] == 'ACKNOWLEDGED')
        .length;

    return Scaffold(
      backgroundColor: FxColors.background,
      body: Column(
        children: [
          _redHeader(),
          Expanded(
            child: RefreshIndicator(
              color: FxColors.primary,
              onRefresh: _fetch,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                children: [
                  const SizedBox(height: 16),
                  _filterCard(),
                  const SizedBox(height: 24),
                  _statsBento(totalCount: totalCount, activeCount: activeCount),
                  const SizedBox(height: 24),
                  if (_isLoading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Column(
                        children: [
                          SkeletonAlertCard(),
                          SizedBox(height: 8),
                          SkeletonAlertCard(),
                          SizedBox(height: 8),
                          SkeletonAlertCard(),
                        ],
                      ),
                    )
                  else if (_error != null)
                    _errorView()
                  else if (_alerts.isEmpty)
                    _emptyView()
                  else
                    ..._alerts.map((a) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _alertCard(a),
                        )),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _redHeader() {
    return Container(
      padding: EdgeInsets.fromLTRB(8, MediaQuery.of(context).padding.top + 6, 8, 14),
      decoration: const BoxDecoration(
        color: FxColors.error,
        boxShadow: [
          BoxShadow(color: Color(0x33B41340), blurRadius: 20, offset: Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 4),
          Text('SOS History', style: FxText.headlineLg(color: FxColors.onError)),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: _fetch,
          ),
        ],
      ),
    );
  }

  Widget _filterCard() {
    return FxCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _dateChip('From Date', _from, () => _pickDate(isFrom: true))),
              const SizedBox(width: 12),
              Expanded(child: _dateChip('To Date', _to, () => _pickDate(isFrom: false))),
            ],
          ),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: _fetch,
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: FxColors.error,
                borderRadius: BorderRadius.circular(14),
                boxShadow: FxShadows.sosButton,
              ),
              alignment: Alignment.center,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.filter_alt_rounded, color: FxColors.onError, size: 18),
                  const SizedBox(width: 6),
                  Text('Apply filters', style: FxText.titleSm(color: FxColors.onError)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dateChip(String label, DateTime value, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: FxColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FxMetaLabel(label, color: FxColors.error.withOpacity(0.7)),
            const SizedBox(height: 2),
            Row(
              children: [
                Expanded(
                  child: Text(
                    DateFormat('MMM d, yyyy').format(value),
                    style: FxText.titleSm(),
                  ),
                ),
                const Icon(Icons.calendar_today_rounded, color: FxColors.error, size: 14),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statsBento({required int totalCount, required int activeCount}) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: FxColors.error.withOpacity(0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: FxColors.error.withOpacity(0.15)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: FxColors.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.emergency_share_rounded, color: FxColors.error, size: 18),
                  ),
                  const Spacer(),
                  const SizedBox(height: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FxMetaLabel('Total Alerts', color: FxColors.error.withOpacity(0.8)),
                      Text('$totalCount', style: FxText.displaySm(color: FxColors.errorDim)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: FxColors.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: FxColors.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.timer_rounded, color: FxColors.onSurfaceVariant, size: 18),
                  ),
                  const Spacer(),
                  const SizedBox(height: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FxMetaLabel('Open / Active'),
                      Text('$activeCount', style: FxText.displaySm()),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _alertCard(Map<String, dynamic> alert) {
    final status = (alert['status'] ?? 'UNKNOWN').toString();
    final falseAlarm = alert['is_false_alarm'] == true;
    final color = _statusColor(status, falseAlarm);
    final isActive = status == 'TRIGGERED' || status == 'ACKNOWLEDGED';
    final triggered = alert['triggered_at'];
    DateTime? dt;
    if (triggered is String) dt = DateTime.tryParse(triggered);
    final dateLabel = dt != null ? DateFormat('MMM d, yyyy').format(dt.toLocal()) : '';
    final timeLabel = dt != null ? DateFormat('h:mm a').format(dt.toLocal()) : '';

    final lat = alert['trigger_latitude'];
    final lng = alert['trigger_longitude'];
    // Try to use location_name from API if available
    final locationName = alert['location_name'] ?? alert['address'] ?? alert['location'];
    String locationDisplay;
    if (locationName != null && locationName.toString().isNotEmpty) {
      locationDisplay = locationName.toString();
    } else if (lat != null && lng != null) {
      final latVal = lat is String ? double.tryParse(lat) ?? 0.0 : (lat as num).toDouble();
      final lngVal = lng is String ? double.tryParse(lng) ?? 0.0 : (lng as num).toDouble();
      locationDisplay = '${latVal.toStringAsFixed(4)}° ${latVal >= 0 ? 'N' : 'S'}, ${lngVal.toStringAsFixed(4)}° ${lngVal >= 0 ? 'E' : 'W'}';
    } else {
      locationDisplay = 'Location unavailable';
    }

    return FxCard(
      padding: const EdgeInsets.all(16),
      border: Border(left: BorderSide(color: color, width: 4)),
      onTap: () {
        final id = alert['alert_id'];
        if (id != null) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => SOSDetailsScreen(alertId: id)),
          );
        }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FxPill(
                      text: falseAlarm
                          ? 'FALSE ALARM'
                          : (isActive ? 'ACTIVE ALERT' : 'RESOLVED'),
                      color: color,
                      background: color.withOpacity(0.12),
                      pulse: isActive && !falseAlarm,
                    ),
                    const SizedBox(height: 6),
                    Text('#SOS-${alert['alert_id'] ?? '-'}', style: FxText.headlineSm()),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(dateLabel, style: FxText.bodySm()),
                  Text(timeLabel, style: FxText.titleSm()),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: FxColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.location_on_rounded, color: color, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    locationDisplay,
                    style: FxText.bodySm(),
                  ),
                ),
                const SizedBox(width: 8),
                Text('Details →', style: FxText.labelSm(color: FxColors.primary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyView() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: FxColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(28),
            ),
            child: const Icon(Icons.shield_outlined, color: FxColors.outline, size: 40),
          ),
          const SizedBox(height: 18),
          Text('No SOS alerts in this window', style: FxText.headlineSm()),
          const SizedBox(height: 4),
          Text('You haven\'t triggered an alert between the selected dates.',
              textAlign: TextAlign.center,
              style: FxText.body(color: FxColors.onSurfaceVariant)),
        ],
      ),
    );
  }

  Widget _errorView() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          const Icon(Icons.error_outline_rounded, color: FxColors.error, size: 56),
          const SizedBox(height: 12),
          Text(_error!, textAlign: TextAlign.center, style: FxText.body(color: FxColors.error)),
          const SizedBox(height: 18),
          SizedBox(
            width: 200,
            child: FxPrimaryButton(
              label: 'Retry',
              leadingIcon: Icons.refresh_rounded,
              onPressed: _fetch,
            ),
          ),
        ],
      ),
    );
  }
}
