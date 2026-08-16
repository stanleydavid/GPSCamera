import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../models/location_data.dart';

/// Wraps `geolocator`: permission flow + realtime position stream (spec §5).
///
/// Exposes a [ValueNotifier<LocationData?>] that stays `null` while location
/// is unavailable (permission denied, service disabled, no fix yet). The
/// camera keeps working regardless — callers must NOT block camera init on
/// this service. Coordinates are always real: never mocked.
class LocationService {
  final ValueNotifier<LocationData?> location = ValueNotifier<LocationData?>(null);

  /// Human-readable reason while GPS is unavailable (shown in logs/banner).
  final ValueNotifier<String?> status = ValueNotifier<String?>(null);

  StreamSubscription<Position>? _subscription;
  bool _started = false;

  /// Requests location permission and starts automatic position updates.
  Future<void> start() async {
    if (_started) return;
    _started = true;

    try {
      final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        status.value = 'Location service is disabled.';
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        status.value = permission == LocationPermission.deniedForever
            ? 'Location permission denied forever.'
            : 'Location permission denied.';
        return;
      }

      final LocationSettings settings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 0,
      );

      _subscription =
          Geolocator.getPositionStream(locationSettings: settings).listen(
        (Position p) {
          location.value = LocationData(
            latitude: p.latitude,
            longitude: p.longitude,
            accuracyMeters: p.accuracy,
            timestamp: p.timestamp,
          );
          status.value = null;
        },
        onError: (Object e) {
          // GPS temporarily unavailable — keep camera running.
          location.value = null;
          status.value = 'GPS temporarily unavailable.';
        },
        cancelOnError: false,
      );
    } catch (_) {
      location.value = null;
      status.value = 'GPS unavailable.';
    }
  }

  /// Re-runs the whole permission + stream flow (used by Retry).
  Future<void> restart() async {
    await _subscription?.cancel();
    _subscription = null;
    _started = false;
    location.value = null;
    await start();
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
    location.dispose();
    status.dispose();
  }
}
