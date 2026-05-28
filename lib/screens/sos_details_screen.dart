import 'package:employee_flutter/services/alert_service.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import '../constants/app_theme.dart';
import '../widgets/fx_widgets.dart';

class SOSDetailsScreen extends StatefulWidget {
  final int alertId;
  const SOSDetailsScreen({super.key, required this.alertId});

  @override
  State<SOSDetailsScreen> createState() => _SOSDetailsScreenState();
}

class _SOSDetailsScreenState extends State<SOSDetailsScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _alertData;
  String? _error;
  final Set<Marker> _markers = {};

  @override
  void initState() {
    super.initState();
    _fetchDetails();
  }

  Future<void> _fetchDetails() async {
    final service = AlertService();
    final result = await service.fetchAlertDetails(widget.alertId);
    if (!mounted) return;
    if (result['success']) {
      final data = result['data']['data'];
      setState(() {
        _alertData = data;
        _isLoading = false;
        if (data['trigger_latitude'] != null && data['trigger_longitude'] != null) {
          final lat = data['trigger_latitude'] is String
              ? double.parse(data['trigger_latitude'])
              : data['trigger_latitude'];
          final lng = data['trigger_longitude'] is String
              ? double.parse(data['trigger_longitude'])
              : data['trigger_longitude'];
          _markers.add(Marker(
            markerId: const MarkerId('trigger_loc'),
            position: LatLng(lat, lng),
            infoWindow: const InfoWindow(title: 'SOS Trigger Location'),
          ));
        }
      });
    } else {
      setState(() {
        _error = result['error'] ?? 'Failed to load details';
        _isLoading = false;
      });
    }
  }

  Color _statusColor(String? status, {bool falseAlarm = false}) {
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

  String _fmt(String? dateStr) {
    if (dateStr == null) return '-';
    try {
      return DateFormat('MMM d, h:mm a').format(DateTime.parse(dateStr).toLocal());
    } catch (_) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = _alertData?['status'] ?? 'UNKNOWN';
    final falseAlarm = _alertData?['is_false_alarm'] == true;
    final statusColor = _statusColor(status, falseAlarm: falseAlarm);

    return Scaffold(
      backgroundColor: FxColors.background,
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: FxColors.primary))
            : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(_error!,
                          textAlign: TextAlign.center, style: FxText.body(color: FxColors.error)),
                    ),
                  )
                : Column(
                    children: [
                      _topBar(),
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                          children: [
                            _headerHero(status, statusColor, falseAlarm),
                            const SizedBox(height: 16),
                            if (_markers.isNotEmpty) _mapCard(),
                            if (_markers.isNotEmpty) const SizedBox(height: 16),
                            _infoChips(),
                            const SizedBox(height: 16),
                            _timeline(status, statusColor),
                          ],
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }

  Widget _topBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 16, 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: FxColors.primary),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 4),
          Text('Alert Details', style: FxText.headlineSm(color: FxColors.primary)),
        ],
      ),
    );
  }

  Widget _headerHero(String status, Color statusColor, bool falseAlarm) {
    return FxCard(
      padding: const EdgeInsets.all(20),
      border: Border(left: BorderSide(color: statusColor, width: 6)),
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
                    FxMetaLabel('Incident ID'),
                    const SizedBox(height: 4),
                    Text('#SOS-${_alertData?['alert_id'] ?? '-'}',
                        style: FxText.headlineLg()),
                    const SizedBox(height: 6),
                    Text(_fmt(_alertData?['triggered_at']),
                        style: FxText.body(color: FxColors.onSurfaceVariant)),
                  ],
                ),
              ),
              FxPill(
                text: falseAlarm ? 'FALSE ALARM' : status.toUpperCase(),
                color: statusColor,
                background: statusColor.withOpacity(0.12),
                pulse: status == 'TRIGGERED' && !falseAlarm,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _mapCard() {
    return ClipRRect(
      borderRadius: FxRadii.card,
      child: SizedBox(
        height: 200,
        child: GoogleMap(
          initialCameraPosition: CameraPosition(target: _markers.first.position, zoom: 15),
          markers: _markers,
          liteModeEnabled: true,
          zoomControlsEnabled: false,
          myLocationButtonEnabled: false,
        ),
      ),
    );
  }

  Widget _infoChips() {
    final severity = _alertData?['severity']?.toString() ?? 'N/A';
    final driver = _alertData?['driver_name'];
    final bookingId = _alertData?['booking_id'];
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _chip(Icons.priority_high_rounded, 'Severity', severity, severity == 'CRITICAL' ? FxColors.error : const Color(0xFFE17055)),
        if (driver != null) _chip(Icons.person_rounded, 'Driver', driver.toString(), FxColors.primary),
        if (bookingId != null) _chip(Icons.directions_car_rounded, 'Ride ID', '#$bookingId', FxColors.secondary),
      ],
    );
  }

  Widget _chip(IconData icon, String label, String value, Color tint) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: FxColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: tint),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FxMetaLabel(label),
              Text(value, style: FxText.titleSm()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _timeline(String status, Color statusColor) {
    return FxCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Resolution Timeline', style: FxText.headlineSm()),
          const SizedBox(height: 16),
          _tlItem(
            title: 'Triggered',
            time: _alertData?['triggered_at'],
            icon: Icons.notifications_active_rounded,
            color: FxColors.error,
            isLast: status == 'TRIGGERED',
          ),
          if (_alertData?['acknowledged_at'] != null)
            _tlItem(
              title: 'Acknowledged',
              subtitle: 'By ${_alertData?['acknowledged_by_name'] ?? 'Responder'}',
              time: _alertData?['acknowledged_at'],
              icon: Icons.thumb_up_rounded,
              color: const Color(0xFFE17055),
              isLast: status == 'ACKNOWLEDGED',
            ),
          if (_alertData?['closed_at'] != null)
            _tlItem(
              title: 'Closed',
              subtitle: _alertData?['resolution_notes'] != null
                  ? 'Notes: ${_alertData!['resolution_notes']}'
                  : null,
              time: _alertData?['closed_at'],
              icon: Icons.check_circle_rounded,
              color: const Color(0xFF00B894),
              isLast: true,
            ),
        ],
      ),
    );
  }

  Widget _tlItem({
    required String title,
    String? subtitle,
    String? time,
    required IconData icon,
    required Color color,
    bool isLast = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 16),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 32,
                color: FxColors.surfaceContainerHigh,
              ),
          ],
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: FxText.title()),
                const SizedBox(height: 2),
                Text(_fmt(time), style: FxText.bodySm()),
                if (subtitle != null) ...[
                  const SizedBox(height: 6),
                  Text(subtitle,
                      style: FxText.body(color: FxColors.onSurface)
                          .copyWith(fontStyle: FontStyle.italic)),
                ],
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
