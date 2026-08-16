import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:gps_camera/models/location_data.dart';
import 'package:gps_camera/services/media_service.dart';
import 'package:image/image.dart' as img;

/// Unit tests for the photo GPS burn-in (spec §15): a synthetic JPEG is
/// stamped and re-decoded — size must be preserved, bottom-center pixels must
/// change (chip + text drawn), and nothing may crash.
void main() {
  final MediaService service = MediaService();

  Uint8List makeJpeg(int width, int height) {
    final img.Image image = img.Image(width: width, height: height, numChannels: 4);
    img.fill(image, color: img.ColorRgb8(120, 140, 160));
    return Uint8List.fromList(img.encodeJpg(image, quality: 90));
  }

  test('burn-in keeps image size and paints the chip at the bottom', () async {
    final Uint8List original = makeJpeg(640, 480);
    final Uint8List stamped = await service.burnGpsOverlay(
      original,
      LocationData(
        latitude: 5.980123,
        longitude: 116.073456,
        accuracyMeters: 8,
        timestamp: DateTime(2026, 8, 16),
      ),
    );

    final img.Image? decoded = img.decodeImage(stamped);
    expect(decoded, isNotNull, reason: 'stamped output must still be a valid image');
    expect(decoded!.width, 640);
    expect(decoded.height, 480);

    // The bottom-center area of the original was uniform (120,140,160).
    // After burn-in the dark chip must have changed those pixels.
    final img.Image before = img.decodeImage(original)!;
    expect(decoded.getPixel(320, 455).r, isNot(before.getPixel(320, 455).r));
    expect(decoded.getPixel(320, 455).g, isNot(before.getPixel(320, 455).g));
  });

  test('null location still stamps "GPS unavailable" chip', () async {
    final Uint8List original = makeJpeg(640, 480);
    final Uint8List stamped = await service.burnGpsOverlay(original, null);

    final img.Image? decoded = img.decodeImage(stamped);
    expect(decoded, isNotNull);
    expect(decoded!.width, 640);
    expect(decoded.height, 480);
  });

  test('larger image scales the chip (no crash, same dimensions)', () async {
    final Uint8List original = makeJpeg(1280, 720);
    final Uint8List stamped = await service.burnGpsOverlay(
      original,
      LocationData(
        latitude: 5.980123,
        longitude: 116.073456,
        timestamp: DateTime(2026, 8, 16),
      ),
    );
    final img.Image? decoded = img.decodeImage(stamped);
    expect(decoded, isNotNull);
    expect(decoded!.width, 1280);
    expect(decoded.height, 720);
  });

  test('non-image bytes pass through unchanged', () async {
    final Uint8List junk = Uint8List.fromList(<int>[1, 2, 3, 4, 5]);
    final Uint8List result = await service.burnGpsOverlay(junk, null);
    expect(result, junk);
  });
}
