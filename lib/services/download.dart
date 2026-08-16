import 'dart:typed_data';

import 'download_io.dart'
    if (dart.library.js_interop) 'download_web.dart' as impl;

/// Downloads [bytes] as [filename] in the browser (web only). On mobile this
/// is a no-op — captured media is previewed in-app.
Future<void> downloadBytes(Uint8List bytes, String filename, String mimeType) {
  return impl.downloadBytes(bytes, filename, mimeType);
}
