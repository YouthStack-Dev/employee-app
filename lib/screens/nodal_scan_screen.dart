import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../constants/app_theme.dart';
import '../models/nodal_models.dart';
import '../providers/nodal_provider.dart';
import '../widgets/fx_widgets.dart';
import '../widgets/skeletons.dart';

/// Nodal QR onboarding: scan the vehicle's RC-number QR (or type it) to mark
/// yourself boarded at the nodal point.
///   GET  /api/v1/app/employee/nodal/assignment  (assigned hub, shown at top)
///   POST /api/v1/app/employee/nodal/scan         (board)
class NodalScanScreen extends StatefulWidget {
  const NodalScanScreen({super.key});

  @override
  State<NodalScanScreen> createState() => _NodalScanScreenState();
}

class _NodalScanScreenState extends State<NodalScanScreen> {
  final TextEditingController _manualController = TextEditingController();
  MobileScannerController? _scannerController;

  NodalProvider? _nodalRef;
  bool _initStarted = false;
  bool _cameraGranted = false;
  bool _cameraChecked = false;
  bool _handling = false; // guards against double-submit from rapid detections
  bool _disposed = false; // guards camera-control calls that straddle disposal

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _nodalRef = Provider.of<NodalProvider>(context, listen: false);
    if (!_initStarted) {
      _initStarted = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _nodalRef?.fetchAssignment();
        _initCamera();
      });
    }
  }

  Future<void> _initCamera() async {
    final status = await Permission.camera.request();
    if (!mounted) return;
    final granted = status.isGranted;
    setState(() {
      _cameraGranted = granted;
      _cameraChecked = true;
      if (granted) {
        _scannerController = MobileScannerController(
          detectionSpeed: DetectionSpeed.noDuplicates,
          facing: CameraFacing.back,
        );
      }
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _manualController.dispose();
    _scannerController?.dispose();
    super.dispose();
  }

  // Camera-control calls can throw if the controller was disposed (e.g. the
  // user backs out while a scan request is in flight). Guard + swallow.
  Future<void> _pauseCamera() async {
    if (_disposed) return;
    try {
      await _scannerController?.stop();
    } catch (_) {/* controller already disposed */}
  }

  Future<void> _resumeCamera() async {
    if (_disposed || !_cameraGranted) return;
    try {
      await _scannerController?.start();
    } catch (_) {/* controller already disposed */}
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_handling) return;
    final raw = capture.barcodes
        .map((b) => b.rawValue)
        .firstWhere((v) => v != null && v.trim().isNotEmpty, orElse: () => null);
    if (raw == null) return;
    await _submit(raw);
  }

  Future<void> _submitManual() async {
    final text = _manualController.text.trim();
    if (text.isEmpty) return;
    await _submit(text);
  }

  Future<void> _submit(String rawVehicleNumber) async {
    final nodal = _nodalRef;
    if (nodal == null || _handling) return;
    setState(() => _handling = true);
    // Pause the camera while the network call is in flight.
    await _pauseCamera();
    final result = await nodal.scan(rawVehicleNumber);
    if (!mounted) return;
    if (result != null) {
      await _showSuccess(result);
      if (mounted) Navigator.pop(context, true);
      return;
    }
    // Failure — surface the error and re-arm the scanner.
    setState(() => _handling = false);
    await _resumeCamera();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(nodal.scanError ?? 'Onboarding failed'),
        backgroundColor: FxColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _showSuccess(NodalScanResult result) {
    return showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
            decoration: BoxDecoration(
              color: FxColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(28),
              boxShadow: FxShadows.soft,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: const BoxDecoration(
                    color: Color(0xFFE7F8EE),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_circle_rounded, color: Color(0xFF00B894), size: 44),
                ),
                const SizedBox(height: 16),
                Text('Boarded successfully', style: FxText.headlineMd()),
                const SizedBox(height: 6),
                Text(
                  result.message,
                  textAlign: TextAlign.center,
                  style: FxText.body(color: FxColors.onSurfaceVariant),
                ),
                const SizedBox(height: 16),
                if (result.nodalPoint != null)
                  _hubRow(result.nodalPoint!),
                if (result.bookingId != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      FxPill(
                        text: 'Booking #${result.bookingId}',
                        color: FxColors.primary,
                        background: FxColors.surfaceContainerLow,
                      ),
                      const SizedBox(width: 8),
                      FxPill(
                        text: (result.status ?? 'Ongoing').toUpperCase(),
                        color: FxColors.onPrimary,
                        background: FxColors.primary,
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 20),
                FxPrimaryButton(
                  label: 'Done',
                  leadingIcon: Icons.check_rounded,
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _hubRow(NodalPoint hub) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: FxColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: FxColors.primaryContainer.withOpacity(0.25),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.hub_rounded, color: FxColors.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(hub.name, style: FxText.titleSm()),
                if (hub.address != null && hub.address!.isNotEmpty)
                  Text(hub.address!, style: FxText.bodySm(), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
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
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
                children: [
                  _assignmentCard(),
                  const SizedBox(height: 16),
                  _scannerCard(),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      const Expanded(child: Divider(color: FxColors.surfaceContainerHigh)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: FxMetaLabel('or enter manually'),
                      ),
                      const Expanded(child: Divider(color: FxColors.surfaceContainerHigh)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _manualEntry(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: FxColors.primary),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 4),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Board your ride', style: FxText.headlineSm(color: FxColors.primary)),
              Text('Scan the QR inside the vehicle', style: FxText.bodySm()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _assignmentCard() {
    return Consumer<NodalProvider>(
      builder: (context, nodal, _) {
        if (nodal.isLoadingAssignment && nodal.assignment == null) {
          return const SkeletonAssignmentCard();
        }
        final hub = nodal.assignment;
        if (hub == null) {
          return const SizedBox.shrink();
        }
        return FxCard(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: FxGradients.indigo,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.hub_rounded, color: FxColors.onPrimary, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FxMetaLabel('Your nodal hub'),
                    const SizedBox(height: 2),
                    Text(hub.name, style: FxText.title()),
                    if (hub.address != null && hub.address!.isNotEmpty)
                      Text(hub.address!, style: FxText.bodySm(), maxLines: 2, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              if (hub.isOverridden == true)
                FxPill(
                  text: 'CUSTOM',
                  color: FxColors.secondary,
                  background: FxColors.secondaryContainer.withOpacity(0.4),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _scannerCard() {
    return ClipRRect(
      borderRadius: FxRadii.card,
      child: AspectRatio(
        aspectRatio: 1,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_cameraGranted && _scannerController != null)
              MobileScanner(
                controller: _scannerController!,
                onDetect: _onDetect,
                errorBuilder: (context, error) => _scannerFallback(
                  icon: Icons.videocam_off_rounded,
                  text: 'Camera unavailable on this device.\nEnter the number below instead.',
                ),
              )
            else if (!_cameraChecked)
              const ColoredBox(
                color: FxColors.surfaceContainer,
                child: Center(child: CircularProgressIndicator(color: FxColors.primary)),
              )
            else
              _scannerFallback(
                icon: Icons.no_photography_rounded,
                text: 'Camera permission denied.\nEnter the vehicle number below instead.',
              ),
            // Scan frame overlay (purely decorative).
            if (_cameraGranted && _scannerController != null)
              IgnorePointer(
                child: Center(
                  child: Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      border: Border.all(color: FxColors.onPrimary, width: 3),
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              ),
            if (_handling)
              Container(
                color: Colors.black.withOpacity(0.35),
                child: const Center(
                  child: CircularProgressIndicator(color: FxColors.onPrimary),
                ),
              ),
            if (_cameraGranted && _scannerController != null)
              Positioned(
                right: 12,
                bottom: 12,
                child: Material(
                  color: Colors.black.withOpacity(0.4),
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => _scannerController?.toggleTorch(),
                    child: const Padding(
                      padding: EdgeInsets.all(10),
                      child: Icon(Icons.flash_on_rounded, color: Colors.white, size: 22),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _scannerFallback({required IconData icon, required String text}) {
    return ColoredBox(
      color: FxColors.surfaceContainer,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 44, color: FxColors.onSurfaceVariant),
              const SizedBox(height: 12),
              Text(text, textAlign: TextAlign.center, style: FxText.body(color: FxColors.onSurfaceVariant)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _manualEntry() {
    return Column(
      children: [
        FxTextField(
          controller: _manualController,
          label: 'Vehicle number',
          hint: 'e.g. KA01AB1234',
          prefixIcon: Icons.directions_car_rounded,
          onChanged: (_) => _nodalRef?.clearScanError(),
        ),
        const SizedBox(height: 16),
        Consumer<NodalProvider>(
          builder: (context, nodal, _) => FxPrimaryButton(
            label: nodal.isScanning ? 'Boarding…' : 'Board ride',
            leadingIcon: Icons.how_to_reg_rounded,
            loading: nodal.isScanning || _handling,
            onPressed: (nodal.isScanning || _handling) ? null : _submitManual,
          ),
        ),
      ],
    );
  }
}
