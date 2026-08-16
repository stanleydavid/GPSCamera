import 'package:flutter/foundation.dart';

/// True when the page is served in a browser secure context — the only
/// contexts where browsers allow `getUserMedia` (camera) and
/// `navigator.geolocation`: HTTPS or localhost/127.0.0.1 (spec §11).
///
/// Pure-Dart equivalent of `window.isSecureContext`, deliberately free of JS
/// interop. Covers every real deployment for this app: Cloudflare HTTPS URL,
/// cloudflared quick-tunnel HTTPS, LAN http (insecure → banner), localhost dev.
bool isSecureContext() {
  if (!kIsWeb) return true; // Android/iOS are always secure contexts.
  final Uri uri = Uri.base;
  if (uri.scheme == 'https') return true;
  if (uri.scheme == 'http' &&
      (uri.host == 'localhost' || uri.host == '127.0.0.1')) {
    return true;
  }
  return false;
}
