import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_theme.dart';
import '../providers/auth_provider.dart';
import 'address_map_screen.dart';

class MyAddressesScreen extends StatelessWidget {
  const MyAddressesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    final address = user?.address?.trim().isNotEmpty == true
        ? user!.address!.trim()
        : '';
    final hasCoords = user?.latitude != null && user?.longitude != null;
    final lat = user?.latitude ?? 0.0;
    final lng = user?.longitude ?? 0.0;

    void viewOnMap() {
      if (!hasCoords) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No location saved for this address.'),
            backgroundColor: FxColors.primary,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AddressMapScreen(
            address: address.isEmpty ? 'Primary Address' : address,
            latitude: lat,
            longitude: lng,
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: FxColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
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
                    'My Addresses',
                    style: FxText.headlineLg(),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
                children: [
                  Row(
                    children: [
                      const Icon(Icons.home_rounded, size: 22, color: FxColors.primary),
                      const SizedBox(width: 10),
                      Text(
                        'Primary Address',
                        style: FxText.headlineMd().copyWith(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: FxColors.surfaceContainerHigh),
                      boxShadow: const [
                        BoxShadow(
                          color: FxColors.primaryContainer,
                          blurRadius: 14,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Address',
                          style: FxText.body(color: FxColors.onSurfaceVariant).copyWith(fontSize: 13),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          address.isEmpty ? 'No address saved yet.' : address,
                          style: FxText.headlineSm().copyWith(fontSize: 16, height: 1.4),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Geocode',
                          style: FxText.body(color: FxColors.onSurfaceVariant).copyWith(fontSize: 13),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          hasCoords ? '$lat,${lng.toStringAsFixed(3)}' : '—',
                          style: FxText.headlineSm().copyWith(fontSize: 16),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 20),
                          child: _DashedDivider(color: FxColors.surfaceContainerHighest),
                        ),
                        SizedBox(
                          width: double.infinity,
                          child: TextButton(
                            onPressed: viewOnMap,
                            style: TextButton.styleFrom(
                              foregroundColor: FxColors.primary,
                              padding: const EdgeInsets.symmetric(vertical: 6),
                            ),
                            child: Text(
                              'VIEW ON MAP',
                              style: FxText.title().copyWith(letterSpacing: 0.4),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    hasCoords
                        ? 'Coordinates: $lat, ${lng.toStringAsFixed(3)}'
                        : 'Saved address has no coordinates yet.',
                    textAlign: TextAlign.center,
                    style: FxText.bodySm().copyWith(fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashedDivider extends StatelessWidget {
  final Color color;

  const _DashedDivider({required this.color});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(double.infinity, 1.5),
      painter: _DashedLinePainter(color),
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