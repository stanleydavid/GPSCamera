/// Immutable snapshot of the device GPS position (spec §5).
class LocationData {
  final double latitude;
  final double longitude;
  final double? accuracyMeters;

  /// Fix timestamp, kept for record-keeping only (not displayed).
  final DateTime? timestamp;

  const LocationData({
    required this.latitude,
    required this.longitude,
    this.accuracyMeters,
    this.timestamp,
  });

  /// `5.980123, 116.073456` — 6 decimal places (spec §3).
  String get coordsLine =>
      '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}';

  /// `GPS 5.980123, 116.073456` — main overlay line.
  String get overlayLine => 'GPS $coordsLine';

  /// `Accuracy ±8m` when known, else null (spec §5 recommended).
  String? get accuracyLine {
    final double? a = accuracyMeters;
    if (a == null) return null;
    return 'Accuracy ±${a.round()}m';
  }

  /// ASCII-only accuracy line for image burn-in — the bundled bitmap font
  /// (package:image arial_48) does not guarantee the ± glyph, so use "+/-".
  String? get accuracyLineForBurnIn {
    return accuracyLine?.replaceAll('±', '+/-');
  }
}
