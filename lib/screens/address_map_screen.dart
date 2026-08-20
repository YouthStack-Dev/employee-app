import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants/app_theme.dart';

class AddressMapScreen extends StatefulWidget {
  final String address;
  final double latitude;
  final double longitude;

  const AddressMapScreen({
    super.key,
    required this.address,
    required this.latitude,
    required this.longitude,
  });

  @override
  State<AddressMapScreen> createState() => _AddressMapScreenState();
}

class _AddressMapScreenState extends State<AddressMapScreen> {
  bool _mapReady = false;
  bool _loadFailed = false;

  LatLng get _target => LatLng(widget.latitude, widget.longitude);

  Future<void> _openDirections() async {
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=${widget.latitude},${widget.longitude}',
    );
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open maps. Please try again.'),
          backgroundColor: FxColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _reload() {
    setState(() {
      _mapReady = false;
      _loadFailed = false;
    });
  }

  @override
  void initState() {
    super.initState();
    Timer(const Duration(seconds: 12), () {
      if (mounted && !_mapReady) {
        setState(() => _loadFailed = true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FxColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 8),
              child: Row(
                children: [
                  InkWell(
                    onTap: () => Navigator.pop(context),
                    borderRadius: BorderRadius.circular(12),
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: FxColors.onSurface),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Location Map',
                    style: FxText.headlineLg(),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Get Directions',
                    onPressed: _openDirections,
                    icon: const Icon(Icons.directions_rounded, color: FxColors.primary),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: _loadFailed
                        ? _buildLoadError()
                        : ClipRRect(
                            borderRadius: BorderRadius.circular(24),
                            child: GoogleMap(
                              initialCameraPosition: CameraPosition(
                                target: _target,
                                zoom: 15,
                              ),
                              myLocationEnabled: false,
                              myLocationButtonEnabled: false,
                              zoomControlsEnabled: true,
                              compassEnabled: true,
                              markers: {
                                Marker(
                                  markerId: const MarkerId('saved-address'),
                                  position: _target,
                                  infoWindow: InfoWindow(
                                    title: 'Primary Address',
                                    snippet: widget.address,
                                  ),
                                ),
                              },
                              onMapCreated: (GoogleMapController controller) {
                                setState(() => _mapReady = true);
                              },
                            ),
                          ),
                  ),
                  if (!_mapReady && !_loadFailed)
                    const Center(
                      child: CircularProgressIndicator(color: FxColors.primary),
                    ),
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 16,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: FxColors.surfaceContainerHigh),
                        boxShadow: const [
                          BoxShadow(
                            color: FxColors.primaryContainer,
                            blurRadius: 20,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'PRIMARY ADDRESS',
                            style: FxText.label(color: FxColors.onSurfaceVariant).copyWith(fontSize: 12),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            widget.address,
                            style: FxText.headlineSm().copyWith(fontSize: 16),
                          ),
                          const SizedBox(height: 14),
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton.icon(
                              onPressed: _openDirections,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: FxColors.primary,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              icon: const Icon(Icons.directions_rounded, size: 20),
                              label: Text(
                                'GET DIRECTIONS',
                                style: FxText.title().copyWith(letterSpacing: 0),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.map_outlined, size: 56, color: FxColors.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(
              'Map could not be loaded. Check your internet connection and try again.',
              textAlign: TextAlign.center,
              style: FxText.bodyLg(color: FxColors.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _reload,
              style: FilledButton.styleFrom(
                backgroundColor: FxColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}