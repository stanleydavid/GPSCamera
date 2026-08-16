import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../models/location_data.dart';

/// Photo GPS burn-in (spec §15): renders the same GPS chip the user sees in
/// the live preview into the actual image file, so opening/exporting the
/// image still shows `GPS 5.980123, 116.073456`.
///
/// Pure Dart (`package:image`) — one code path for Android, iOS and Web.
/// Font/geometry scale with image width per designer design-tokens.md §6.
class MediaService {
  // Dark chip background, alpha 115/255 ≈ 0.45 — matches AppTokens.gpsChipBg.
  // Note: ColorRgba8 is a mutable (non-const) class in package:image 4.x.
  static final img.Color _chipBg = img.ColorRgba8(0, 0, 0, 115);
  static final img.Color _textColor = img.ColorRgba8(255, 255, 255, 255);
  static final img.Color _textColorDim = img.ColorRgba8(255, 255, 255, 218);

  /// Returns JPEG bytes of [original] with the GPS chip painted at the
  /// bottom-center. When [location] is null the chip shows
  /// "GPS unavailable" (camera still works — spec §5).
  ///
  /// Returns the original bytes unchanged if the image cannot be decoded.
  Future<Uint8List> burnGpsOverlay(Uint8List original, LocationData? location) async {
    final img.Image? photo = img.decodeImage(original);
    if (photo == null) return original;

    final int w = photo.width;
    // arial_48 is the largest bundled bitmap font; render at native size onto
    // a transparent layer, then scale the layer to the target size.
    final double fontSize = (w * 0.025).clamp(18.0, 120.0).toDouble();

    final String line1 = location?.overlayLine ?? 'GPS unavailable';
    // ASCII-safe: the bitmap font does not guarantee the ± glyph.
    final String? line2 = location?.accuracyLineForBurnIn;

    final img.BitmapFont font = img.arial48;
    final int textW = math.max(
      _stringWidth(line1, font),
      line2 == null ? 0 : _stringWidth(line2, font),
    );
    final int gap = (fontSize * 0.12).round();
    final int textH = line2 == null ? 48 + 8 : 48 * 2 + gap + 8;
    final img.Image textLayer = img.Image(width: textW + 8, height: textH, numChannels: 4);

    img.drawString(textLayer, line1, font: font, x: 4, y: 0, color: _textColor);
    if (line2 != null) {
      img.drawString(textLayer, line2, font: font, x: 4, y: 48 + gap, color: _textColorDim);
    }

    final double scale = fontSize / 48.0;
    final img.Image scaled = img.copyResize(
      textLayer,
      width: (textLayer.width * scale).round(),
      height: (textLayer.height * scale).round(),
      interpolation: img.Interpolation.linear,
    );

    final int padH = (fontSize * 0.35).round();
    final int padV = (fontSize * 0.18).round();
    final int radius = (fontSize * 0.16).round();
    final int marginBottom = (w * 0.02).round();

    final int chipW = scaled.width + padH * 2;
    final int chipH = scaled.height + padV * 2;
    final int chipX = math.max(0, (w - chipW) ~/ 2);
    final int chipY = math.max(0, photo.height - chipH - marginBottom);

    // Rounded dark chip (`radius` on fillRect) then the text on top.
    img.fillRect(
      photo,
      x1: chipX,
      y1: chipY,
      x2: chipX + chipW - 1,
      y2: chipY + chipH - 1,
      color: _chipBg,
      radius: radius,
    );
    img.compositeImage(photo, scaled, dstX: chipX + padH, dstY: chipY + padV);

    return img.encodeJpg(photo, quality: 90);
  }

  /// Width of [s] rendered with [font] (sum of character advances), using the
  /// same fallback the bitmap-font renderer uses for unknown glyphs.
  int _stringWidth(String s, img.BitmapFont font) {
    int width = 0;
    for (final int codeUnit in s.codeUnits) {
      final img.BitmapFontCharacter? ch = font.characters[codeUnit];
      width += ch?.xAdvance ?? font.base ~/ 2;
    }
    return width;
  }
}
