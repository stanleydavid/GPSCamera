import 'package:video_player/video_player.dart';

/// Web implementation: `camera_web` exposes recorded videos as `XFile` whose
/// path is a blob: URL — play it through the network controller. This file
/// deliberately imports no `dart:io` (unavailable on web).
Future<VideoPlayerController> createVideoControllerFor(String path) async {
  return VideoPlayerController.networkUrl(Uri.parse(path));
}
