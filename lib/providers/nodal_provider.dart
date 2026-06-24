import 'package:flutter/foundation.dart';
import '../models/nodal_models.dart';
import '../services/nodal_service.dart';

class NodalProvider with ChangeNotifier {
  NodalProvider({NodalService? service}) : _service = service ?? NodalService();

  final NodalService _service;

  NodalPoint? _assignment;
  bool _isLoadingAssignment = false;
  String? _assignmentError;

  bool _isScanning = false;
  String? _scanError;
  NodalScanResult? _lastResult;

  bool _isDisposed = false;

  NodalPoint? get assignment => _assignment;
  bool get isLoadingAssignment => _isLoadingAssignment;
  String? get assignmentError => _assignmentError;

  bool get isScanning => _isScanning;
  String? get scanError => _scanError;
  NodalScanResult? get lastResult => _lastResult;

  Future<void> fetchAssignment({bool force = false}) async {
    if (_isLoadingAssignment) return;
    if (_assignment != null && !force) return;
    _isLoadingAssignment = true;
    _assignmentError = null;
    _safeNotify();

    final result = await _service.getAssignment();
    if (_isDisposed) return;
    if (result['success'] == true && result['data'] is NodalPoint) {
      _assignment = result['data'] as NodalPoint;
      _assignmentError = null;
    } else {
      // 404 ASSIGNMENT_NOT_FOUND is a normal "no hub assigned" state, not a hard error.
      _assignmentError = result['error']?.toString();
    }
    _isLoadingAssignment = false;
    _safeNotify();
  }

  /// Validate + normalize the scanned/typed vehicle number, then onboard.
  /// Returns the result on success, or null on failure (see [scanError]).
  Future<NodalScanResult?> scan(String rawVehicleNumber) async {
    final normalized = VehicleNumber.normalize(rawVehicleNumber);
    if (!VehicleNumber.isValid(normalized)) {
      _scanError = 'That doesn\'t look like a valid vehicle number (e.g. KA01AB1234).';
      _safeNotify();
      return null;
    }
    if (_isScanning) return null;
    _isScanning = true;
    _scanError = null;
    _safeNotify();

    final result = await _service.scan(normalized);
    if (_isDisposed) return null;
    _isScanning = false;
    if (result['success'] == true) {
      _lastResult = result['data'] is NodalScanResult ? result['data'] as NodalScanResult : null;
      _scanError = null;
      _safeNotify();
      return _lastResult ?? const NodalScanResult();
    }
    _scanError = result['error']?.toString() ?? 'Onboarding failed. Please try again.';
    _safeNotify();
    return null;
  }

  void clearScanError() {
    if (_scanError == null) return;
    _scanError = null;
    _safeNotify();
  }

  void reset() {
    _isScanning = false;
    _scanError = null;
    _lastResult = null;
    _safeNotify();
  }

  void _safeNotify() {
    if (_isDisposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}
