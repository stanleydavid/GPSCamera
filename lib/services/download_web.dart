import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

/// Web implementation: triggers a browser download through a temporary
/// `<a download>` anchor with a blob URL. Best-effort — the in-app preview
/// remains available even if a browser blocks the download.
///
/// NOTE (builder fix 2026-08-16): the blob part MUST be a real typed array.
/// A plain JS array of numbers (what `Uint8List.toJS` alone produces) is
/// stringified by the Blob constructor (`new Blob([[71,80,83]]).text()` →
/// `"71,80,83"`), silently corrupting the downloaded file. We therefore wrap
/// the bytes in a `Uint8Array` first — verified in-browser that the resulting
/// blob round-trips the exact bytes.

@JS('Blob')
extension type _Blob(JSObject _) implements JSObject {
  external factory _Blob(JSArray<JSAny> parts, [JSObject? options]);
}

@JS('Uint8Array')
extension type _Uint8Array(JSObject _) implements JSObject {
  external factory _Uint8Array(int length);

  /// `Uint8Array.prototype.set(arrayLike, offset)` — accepts any array-like
  /// (the JSArray produced by `Uint8List.toJS` works here).
  external void set(JSAny array, int offset);
}

@JS('URL.createObjectURL')
external String _createObjectUrl(_Blob blob);

@JS('URL.revokeObjectURL')
external void _revokeObjectUrl(String url);

@JS('document')
external _Document get _document;

extension type _Document(JSObject _) implements JSObject {
  external _Element createElement(String localName);

  external _Element? get body;
}

extension type _Element(JSObject _) implements JSObject {
  external void append(_Element child);

  external void remove();

  external void click();

  external String get href;

  external set href(String value);

  external String get download;

  external set download(String value);
}

Future<void> downloadBytes(Uint8List bytes, String filename, String mimeType) async {
  try {
    // 1. Copy the bytes into a real Uint8Array (valid BlobPart/BufferSource).
    final _Uint8Array u8 = _Uint8Array(bytes.length)..set(bytes.toJS, 0);
    // 2. Blob part list containing exactly that typed array.
    final JSArray<JSAny> parts = <JSAny>[u8].toJS;
    final _Blob blob = _Blob(parts);

    final String url = _createObjectUrl(blob);
    final _Element anchor = _document.createElement('a')
      ..href = url
      ..download = filename;
    final _Element? body = _document.body;
    if (body == null) {
      _revokeObjectUrl(url);
      return;
    }
    body.append(anchor);
    anchor.click();
    anchor.remove();
    // Revoke shortly after — the browser needs the URL while the download
    // starts; an immediate revoke can abort it.
    unawaited(_revokeLater(url));
  } catch (_) {
    // Best-effort; the in-app preview already shows the captured media.
  }
}

Future<void> _revokeLater(String url) async {
  await Future<void>.delayed(const Duration(seconds: 10));
  _revokeObjectUrl(url);
}
