import 'dart:io' show File;

import 'package:video_player/video_player.dart';

/// Native (Android/iOS) implementation: plays the recorded video from the
/// local filesystem.
Future<VideoPlayerController> createVideoControllerFor(String path) async {
  return VideoPlayerController.file(File(path));
}
