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
      backgroundColor: Colors.white, // Cleaner background
      appBar: AppBar(
        title: const Text('Alert Details', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
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
              : Column(
                  children: [
                    // Map Section (Top)
                    if (_markers.isNotEmpty)
                      SizedBox(
                        height: 250,
                        child: GoogleMap(
                          initialCameraPosition: CameraPosition(
                            target: _markers.first.position,
                            zoom: 15,
                          ),
                          markers: _markers,
                          liteModeEnabled: true,
                        ),
                      ),
                    
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                             // Header Section
                             Row(
                               mainAxisAlignment: MainAxisAlignment.spaceBetween,
                               children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                       Text('SOS Alert #${_alertData?['alert_id'] ?? '-'}', 
                                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                                       const SizedBox(height: 4),
                                       Text(_formatDate(_alertData?['triggered_at']), 
                                          style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
                                    ],
                                  ),
                                  // Status Badge
                                  Container(
                                     padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                     decoration: BoxDecoration(
                                        color: color.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(color: color.withOpacity(0.3))
                                     ),
                                     child: Row(
                                       mainAxisSize: MainAxisSize.min,
                                       children: [
                                          Icon(
                                            _alertData?['is_false_alarm'] == true ? Icons.error_outline : Icons.circle, 
                                            size: 10, color: color
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            _alertData?['is_false_alarm'] == true ? 'FALSE ALARM' : status, 
                                            style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)
                                          ),
                                       ],
                                     ),
                                  )
                               ],
                             ),
                             
                             const SizedBox(height: 24),

                             // Basic Info Grid
                             Wrap(
                               spacing: 16,
                               runSpacing: 16,
                               children: [
                                  _buildInfoChip(Icons.priority_high, 'Severity', _alertData?['severity'] ?? 'N/A', 
                                    iconColor: (_alertData?['severity'] == 'CRITICAL') ? Colors.red : Colors.orange),
                                  if (_alertData?['driver_name'] != null)
                                    _buildInfoChip(Icons.person, 'Driver', _alertData!['driver_name']),
                                  if (_alertData?['booking_id'] != null)
                                    _buildInfoChip(Icons.directions_car, 'Ride ID', '#${_alertData!['booking_id']}'),
                               ],
                             ),

                             const SizedBox(height: 32),
                             const Text('Resolution Timeline', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                             const SizedBox(height: 16),
                             
                             // Timeline
                             _buildTimelineItem(
                               title: 'Triggered',
                               time: _alertData?['triggered_at'],
                               icon: Icons.notifications_active,
                               color: Colors.red,
                               isLast: status == 'TRIGGERED'
                             ),
                             if (_alertData?['acknowledged_at'] != null)
                               _buildTimelineItem(
                                 title: 'Acknowledged',
                                 subtitle: 'By ${_alertData?['acknowledged_by_name'] ?? 'Responder'}',
                                 time: _alertData?['acknowledged_at'],
                                 icon: Icons.thumb_up,
                                 color: Colors.orange,
                                 isLast: status == 'ACKNOWLEDGED'
                               ),
                             if (_alertData?['closed_at'] != null)
                               _buildTimelineItem(
                                 title: 'Closed',
                                 subtitle: _alertData?['resolution_notes'] != null ? 'Notes: ${_alertData!['resolution_notes']}' : null,
                                 time: _alertData?['closed_at'],
                                 icon: Icons.check_circle,
                                 color: Colors.green,
                                 isLast: true
                               ),
                          ],
                        ),
                      ),
                    )
                  ],
                ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label, String value, {Color iconColor = Colors.grey}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200)
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
           Icon(icon, size: 16, color: iconColor),
           const SizedBox(width: 8),
           Column(
             crossAxisAlignment: CrossAxisAlignment.start,
             children: [
                Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
             ],
           )
        ],
      ),
    );
  }

  Widget _buildTimelineItem({required String title, String? subtitle, String? time, required IconData icon, required Color color, bool isLast = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                 color: Colors.white,
                 shape: BoxShape.circle,
                 border: Border.all(color: color.withOpacity(0.5), width: 2)
              ),
              child: Icon(icon, color: color, size: 16),
            ),
            if (!isLast)
              Container(width: 2, height: 40, color: Colors.grey.shade200)
          ],
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 2),
              Text(_formatDate(time), style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
              if (subtitle != null)
                 Padding(
                   padding: const EdgeInsets.only(top: 6),
                   child: Text(subtitle, style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.black87)),
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
      return DateFormat('MMM d, h:mm a').format(date);
    } catch (e) {
      return dateStr;
    }
  }
}
