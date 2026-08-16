import 'package:flutter/material.dart';

import '../models/location_data.dart';
import '../theme/app_tokens.dart';

/// GPS chip rendered at the bottom-center of the camera preview (spec §6).
///
/// Same visual language as the chip burned into captured photos: white text,
/// semi-transparent dark rounded background, small size, above the camera
/// image — never below it.
class GpsOverlay extends StatelessWidget {
  const GpsOverlay({super.key, required this.location});

  /// Null while GPS is unavailable → shows "GPS unavailable".
  final LocationData? location;

  @override
  Widget build(BuildContext context) {
    final bool hasData = location != null;
    return AnimatedSwitcher(
      duration: AppTokens.durChipStatus,
      child: Container(
        key: ValueKey<bool>(hasData),
        constraints: const BoxConstraints(maxWidth: 340),
        padding: const EdgeInsets.symmetric(
          horizontal: AppTokens.spaceSm,
          vertical: AppTokens.spaceXs,
        ),
        decoration: BoxDecoration(
          color: AppTokens.gpsChipBg,
          borderRadius: BorderRadius.circular(AppTokens.radiusChip),
        ),
        child: hasData ? _WithData(location!) : const _Unavailable(),
      ),
    );
  }
}

class _WithData extends StatelessWidget {
  const _WithData(this.location);

  final LocationData location;

  @override
  Widget build(BuildContext context) {
    final String? accuracy = location.accuracyLine;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          location.overlayLine,
          maxLines: 1,
          style: const TextStyle(
            color: AppTokens.white,
            fontSize: AppTokens.textCoords,
            fontWeight: FontWeight.w600,
            fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
          ),
        ),
        if (accuracy != null)
          Text(
            accuracy,
            style: const TextStyle(
              color: AppTokens.white70,
              fontSize: AppTokens.textAccuracy,
              fontWeight: FontWeight.w400,
              fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
            ),
          ),
      ],
    );
  }
}

class _Unavailable extends StatelessWidget {
  const _Unavailable();

  @override
  Widget build(BuildContext context) {
    return const Text(
      'GPS unavailable',
      style: TextStyle(
        color: Color(0xE6FFFFFF), // white 90%
        fontSize: AppTokens.textCoords,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
