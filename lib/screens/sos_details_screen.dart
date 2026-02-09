import 'package:employee_flutter/services/alert_service.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';

class SOSDetailsScreen extends StatefulWidget {
  final int alertId;

  const SOSDetailsScreen({Key? key, required this.alertId}) : super(key: key);

  @override
  State<SOSDetailsScreen> createState() => _SOSDetailsScreenState();
}

class _SOSDetailsScreenState extends State<SOSDetailsScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _alertData;
  String? _error;
  Set<Marker> _markers = {};

  @override
  void initState() {
    super.initState();
    _fetchDetails();
  }

  void _fetchDetails() async {
    final service = AlertService();
    final result = await service.fetchAlertDetails(widget.alertId);

    if (mounted) {
      if (result['success']) {
        final data = result['data']['data'];
        setState(() {
          _alertData = data;
          _isLoading = false;
          
          if (data['trigger_latitude'] != null && data['trigger_longitude'] != null) {
              final lat = data['trigger_latitude'] is String ? double.parse(data['trigger_latitude']) : data['trigger_latitude'];
              final lng = data['trigger_longitude'] is String ? double.parse(data['trigger_longitude']) : data['trigger_longitude'];
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
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'CLOSED': return Colors.green;
      case 'TRIGGERED': return Colors.red;
      case 'ACKNOWLEDGED': return Colors.orange;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = _alertData?['status'] ?? 'UNKNOWN';
    final color = _getStatusColor(status);

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Alert Details', style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading 
          ? Center(child: CircularProgressIndicator(color: color))
          : _error != null 
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
              : SingleChildScrollView(
                  child: Column(
                    children: [
                      // Status Banner
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        color: color.withOpacity(0.1),
                        child: Column(
                          children: [
                            Icon(Icons.warning_amber_rounded, size: 40, color: color),
                            const SizedBox(height: 8),
                            Text(status, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 20)),
                            if (_alertData?['is_false_alarm'] == true)
                              Container(
                                margin: const EdgeInsets.only(top: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(20)
                                ),
                                child: const Text('False Alarm', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              )
                          ],
                        ),
                      ),

                      // Map Section
                      if (_alertData?['trigger_latitude'] != null)
                        SizedBox(
                          height: 250,
                          child: GoogleMap(
                            initialCameraPosition: CameraPosition(
                              target: _markers.first.position,
                              zoom: 15,
                            ),
                            markers: _markers,
                            liteModeEnabled: true, // Lightweight map for scrolling lists/details
                          ),
                        ),

                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                             // Basic Info Card
                             Container(
                               padding: const EdgeInsets.all(16),
                               decoration: BoxDecoration(
                                 color: Colors.white,
                                 borderRadius: BorderRadius.circular(12),
                                 boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: const Offset(0,2))]
                               ),
                               child: Column(
                                 children: [
                                   _buildRow('Alert ID', '#${_alertData!['alert_id']}'),
                                   const Divider(),
                                   _buildRow('Severity', _alertData!['severity'] ?? 'N/A', 
                                      valueColor: (_alertData!['severity'] == 'CRITICAL' || _alertData!['severity'] == 'HIGH') ? Colors.red : Colors.black),
                                   const Divider(),
                                   _buildRow('Triggered At', _formatDate(_alertData!['triggered_at'])),
                                   if (_alertData!['booking_id'] != null) ...[
                                      const Divider(),
                                      _buildRow('Booking ID', '#${_alertData!['booking_id']}'),
                                   ],
                                   if (_alertData!['driver_name'] != null) ...[
                                      const Divider(),
                                      _buildRow('Driver', _alertData!['driver_name']),
                                   ]
                                 ],
                               ),
                             ),

                             const SizedBox(height: 20),
                             const Text('Resolution Timeline', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                             const SizedBox(height: 10),
                             
                             // Timeline
                             _buildTimelineItem(
                               title: 'Triggered',
                               time: _alertData!['triggered_at'],
                               icon: Icons.notifications_active,
                               color: Colors.red,
                               isLast: status == 'TRIGGERED'
                             ),
                             if (_alertData!['acknowledged_at'] != null)
                               _buildTimelineItem(
                                 title: 'Acknowledged',
                                 subtitle: 'By ${_alertData!['acknowledged_by_name'] ?? 'Responder'}',
                                 time: _alertData!['acknowledged_at'],
                                 icon: Icons.thumb_up,
                                 color: Colors.orange,
                                 isLast: status == 'ACKNOWLEDGED'
                               ),
                             if (_alertData!['closed_at'] != null)
                               _buildTimelineItem(
                                 title: 'Closed',
                                 subtitle: _alertData!['resolution_notes'] != null ? 'Notes: ${_alertData!['resolution_notes']}' : null,
                                 time: _alertData!['closed_at'],
                                 icon: Icons.check_circle,
                                 color: Colors.green,
                                 isLast: true
                               ),
                          ],
                        ),
                      )
                    ],
                  ),
                ),
    );
  }

  Widget _buildRow(String label, String value, {Color valueColor = Colors.black}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: valueColor)),
        ],
      ),
    );
  }

  Widget _buildTimelineItem({required String title, String? subtitle, required String time, required IconData icon, required Color color, bool isLast = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 20),
            ),
            if (!isLast)
              Container(width: 2, height: 40, color: Colors.grey.shade300)
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Text(_formatDate(time), style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
              if (subtitle != null)
                 Padding(
                   padding: const EdgeInsets.only(top: 4),
                   child: Text(subtitle, style: const TextStyle(fontStyle: FontStyle.italic)),
                 ),
              const SizedBox(height: 24),
            ],
          ),
        )
      ],
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '-';
    try {
      final date = DateTime.parse(dateStr).toLocal();
      return DateFormat('MMM d, yyyy • h:mm a').format(date);
    } catch (e) {
      return dateStr;
    }
  }
}
