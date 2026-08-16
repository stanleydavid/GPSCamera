import 'package:video_player/video_player.dart';

import 'video_controller_io.dart'
    if (dart.library.js_interop) 'video_controller_web.dart' as impl;

/// Creates a [VideoPlayerController] for a recorded video [path]:
///  - native: local filesystem `File` path (dart:io);
///  - web: blob: URL from `camera_web` (no dart:io on web).
///
/// Keeps `dart:io` out of the web compilation unit (spec §13 / §21 — web
/// build must succeed).
Future<VideoPlayerController> createVideoControllerFor(String path) {
  return impl.createVideoControllerFor(path);
}
