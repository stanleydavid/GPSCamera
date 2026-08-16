import 'dart:typed_data';

/// Non-web implementation: no file-system download (out of MVP scope — the
/// captured media is already previewed in-app; mobile gallery integration is
/// a documented future step).
Future<void> downloadBytes(Uint8List bytes, String filename, String mimeType) async {
  // No-op on Android/iOS for this MVP.
}
