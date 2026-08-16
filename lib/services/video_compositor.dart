import 'dart:async';

import 'package:camera/camera.dart' show XFile;
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../models/location_data.dart';
import '../widgets/gps_overlay.dart';
import 'camera_service.dart';

/// Video compositing boundary (spec §4.3).
///
/// v1 limitation (documented, spec §4 explicitly allows it): the camera
/// plugin records the raw stream (web = MediaRecorder, native = CameraX /
/// AVFoundation) and Dart has no access to the encoded frames, so the GPS
/// overlay cannot be burned into the video FILE from Dart. The MVP therefore
/// ships:
///   1. a realtime GPS overlay rendered over the live preview while recording;
///   2. normal browser/device video recording;
///   3. this isolated compositing seam, so a native/mobile post-process
///      compositor (e.g. ffmpeg / media_kit) can be plugged in later without
///      touching the UI.
abstract class VideoCompositor {
  /// Stable identifier of the compositing implementation.
  String get id;

  /// Human-readable limitation note (surfaced in README/report).
  String get limitationNote;

  bool get isRecording;

  /// Elapsed recording time (updates ~2×/s while recording).
  ValueListenable<Duration> get elapsed;

  Future<void> startRecording();

  /// Returns the recorded video file, or null if nothing was recorded.
  Future<XFile?> stopRecording();

  /// Live overlay widget shown on top of the preview while recording.
  Widget buildOverlay(LocationData? location);

  Future<void> dispose();
}

/// v1 implementation: records via the camera plugin; the GPS overlay is only
/// live on screen. See [VideoCompositor] for the documented limitation.
class PassthroughVideoCompositor implements VideoCompositor {
  PassthroughVideoCompositor(this._cameraService);

  final CameraService _cameraService;

  final ValueNotifier<Duration> _elapsed = ValueNotifier<Duration>(Duration.zero);
  Stopwatch? _stopwatch;
  Timer? _ticker;

  @override
  String get id => 'passthrough-v1';

  @override
  String get limitationNote =>
      'GPS overlay is rendered live over the preview only; the recorded video '
      'file does not contain the overlay (web + native v1). A post-process '
      'compositor can be plugged into VideoCompositor later.';

  @override
  bool get isRecording => _stopwatch != null;

  @override
  ValueListenable<Duration> get elapsed => _elapsed;

  @override
  Future<void> startRecording() async {
    if (isRecording) return;
    await _cameraService.startRecording();
    _stopwatch = Stopwatch()..start();
    _ticker = Timer.periodic(const Duration(milliseconds: 500), (_) {
      _elapsed.value = _stopwatch!.elapsed;
    });
  }

  @override
  Future<XFile?> stopRecording() async {
    if (!isRecording) return null;
    _ticker?.cancel();
    _ticker = null;
    final XFile file = await _cameraService.stopRecording();
    _elapsed.value = _stopwatch!.elapsed;
    _stopwatch = null;
    return file;
  }

  @override
  Widget buildOverlay(LocationData? location) => GpsOverlay(location: location);

  @override
  Future<void> dispose() async {
    _ticker?.cancel();
    _ticker = null;
    _stopwatch = null;
    _elapsed.dispose();
  }
}
