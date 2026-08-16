import 'package:flutter_test/flutter_test.dart';
import 'package:gps_camera/models/location_data.dart';

void main() {
  group('LocationData', () {
    test('formats coordinates with 6 decimal places', () {
      final LocationData d = LocationData(
        latitude: 5.980123,
        longitude: 116.073456,
        timestamp: DateTime(2026, 8, 16),
      );
      expect(d.coordsLine, '5.980123, 116.073456');
      expect(d.overlayLine, 'GPS 5.980123, 116.073456');
      expect(d.accuracyLine, isNull);
    });

    test('handles negative coordinates (southern/western hemisphere)', () {
      final LocationData d = LocationData(
        latitude: -5.980123,
        longitude: -116.073456,
        timestamp: DateTime(2026, 8, 16),
      );
      expect(d.coordsLine, '-5.980123, -116.073456');
      expect(d.overlayLine, 'GPS -5.980123, -116.073456');
    });

    test('rounds to 6 decimal places', () {
      final LocationData d = LocationData(
        latitude: 1.0000004,
        longitude: 2.9999996,
        timestamp: DateTime(2026, 8, 16),
      );
      expect(d.coordsLine, '1.000000, 3.000000');
    });

    test('formats accuracy line with rounding', () {
      final LocationData d8 = LocationData(
        latitude: 5.980123,
        longitude: 116.073456,
        accuracyMeters: 8.4,
        timestamp: DateTime(2026, 8, 16),
      );
      expect(d8.accuracyLine, 'Accuracy ±8m');

      final LocationData d13 = LocationData(
        latitude: 5.980123,
        longitude: 116.073456,
        accuracyMeters: 12.6,
        timestamp: DateTime(2026, 8, 16),
      );
      expect(d13.accuracyLine, 'Accuracy ±13m');
    });
  });
}
