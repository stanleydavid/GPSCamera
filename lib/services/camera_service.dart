import 'package:camera/camera.dart';

/// User-facing camera failure carrying a ready-to-display message.
class CameraServiceException implements Exception {
  const CameraServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Thin wrapper around the `camera` plugin (spec §2):
/// enumerate cameras → init rear by default → switch front/rear →
/// capture photo → record video. Camera permission is requested by the
/// plugin itself (`availableCameras` on web = getUserMedia prompt).
class CameraService {
  List<CameraDescription> _cameras = const <CameraDescription>[];
  CameraController? _controller;
  int _cameraIndex = 0;
  bool _enableAudio = true;

  CameraController? get controller => _controller;

  bool get isInitialized => _controller?.value.isInitialized ?? false;

  bool get isRecordingVideo => _controller?.value.isRecordingVideo ?? false;

  List<CameraDescription> get cameras => _cameras;

  bool get canSwitchCamera {
    final bool hasFront = _cameras
        .any((CameraDescription c) => c.lensDirection == CameraLensDirection.front);
    final bool hasBack = _cameras
        .any((CameraDescription c) => c.lensDirection == CameraLensDirection.back);
    return hasFront && hasBack;
  }

  /// Enumerates cameras and initializes the back camera (fallback: first
  /// available). If initialization fails because audio/mic is denied, retries
  /// once with video only so the camera still works (spec §18).
  Future<void> initialize() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        throw const CameraServiceException('No camera found on this device.');
      }
      _cameraIndex = _cameras.indexWhere(
        (CameraDescription c) => c.lensDirection == CameraLensDirection.back,
      );
      if (_cameraIndex < 0) _cameraIndex = 0;

      try {
        await _createController(enableAudio: true);
      } on CameraException {
        // Mic permission denied / no microphone: retry video-only.
        _enableAudio = false;
        await _createController(enableAudio: false);
      }
    } on CameraException catch (e) {
      throw CameraServiceException(_friendlyError(e));
    }
  }

  Future<void> _createController({required bool enableAudio}) async {
    final CameraController controller = CameraController(
      _cameras[_cameraIndex],
      ResolutionPreset.high,
      enableAudio: enableAudio,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    await controller.initialize();
    _controller = controller;
  }

  /// Cycles to the next available camera (front ↔ back).
  Future<void> switchCamera() async {
    if (_cameras.length < 2) return;
    await _disposeController();
    _cameraIndex = (_cameraIndex + 1) % _cameras.length;
    await _createController(enableAudio: _enableAudio);
  }

  Future<XFile> takePhoto() {
    final CameraController? c = _controller;
    if (c == null) throw const CameraServiceException('Camera is not ready.');
    return c.takePicture();
  }

  Future<void> startRecording() {
    final CameraController? c = _controller;
    if (c == null) throw const CameraServiceException('Camera is not ready.');
    return c.startVideoRecording();
  }

  Future<XFile> stopRecording() {
    final CameraController? c = _controller;
    if (c == null) throw const CameraServiceException('Camera is not ready.');
    return c.stopVideoRecording();
  }

  Future<void> dispose() => _disposeController();

  Future<void> _disposeController() async {
    final CameraController? c = _controller;
    _controller = null;
    if (c != null && c.value.isInitialized) {
      await c.dispose();
    }
  }

  String _friendlyError(CameraException e) {
    final String code = e.code.toLowerCase();
    if (code.contains('denied') ||
        code.contains('permission') ||
        code.contains('notallowederror') ||
        code.contains('security')) {
      return 'Camera permission denied or blocked. Allow camera access in the '
          'browser/device settings, or open this page over HTTPS or localhost.';
    }
    if (code.contains('notfound') || code.contains('no camera')) {
      return 'No camera was found on this device.';
    }
    if (code.contains('notsupported')) {
      return 'Camera is not supported by this browser.';
    }
    final String d = (e.description ?? '').trim();
    return d.isNotEmpty ? d : 'Camera could not be started.';
  }
}
