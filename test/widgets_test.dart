import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gps_camera/models/location_data.dart';
import 'package:gps_camera/widgets/camera_controls.dart';
import 'package:gps_camera/widgets/gps_overlay.dart';
import 'package:gps_camera/widgets/mode_selector.dart';

void main() {
  group('GpsOverlay', () {
    testWidgets('shows coordinates and accuracy when location present',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: GpsOverlay(
                location: LocationData(
                  latitude: 5.980123,
                  longitude: 116.073456,
                  accuracyMeters: 8,
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.text('GPS 5.980123, 116.073456'), findsOneWidget);
      expect(find.text('Accuracy ±8m'), findsOneWidget);
    });

    testWidgets('shows "GPS unavailable" when location is null',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: Center(child: GpsOverlay(location: null))),
        ),
      );
      expect(find.text('GPS unavailable'), findsOneWidget);
    });
  });

  group('ModeSelector', () {
    testWidgets('toggles between PHOTO and VIDEO', (WidgetTester tester) async {
      CameraMode current = CameraMode.photo;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ModeSelector(
              mode: current,
              onChanged: (CameraMode m) => current = m,
            ),
          ),
        ),
      );
      await tester.tap(find.text('VIDEO'));
      expect(current, CameraMode.video);
      await tester.tap(find.text('PHOTO'));
      expect(current, CameraMode.photo);
    });

    testWidgets('ignores taps when disabled', (WidgetTester tester) async {
      CameraMode current = CameraMode.photo;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ModeSelector(
              mode: current,
              enabled: false,
              onChanged: (CameraMode m) => current = m,
            ),
          ),
        ),
      );
      await tester.tap(find.text('VIDEO'));
      expect(current, CameraMode.photo);
    });
  });

  group('ShutterButton', () {
    testWidgets('renders photo and recording variants without errors',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ShutterButton(
              mode: CameraMode.photo,
              isRecording: false,
              onPressed: _noop,
            ),
          ),
        ),
      );
      expect(find.byType(ShutterButton), findsOneWidget);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ShutterButton(
              mode: CameraMode.video,
              isRecording: true,
              onPressed: _noop,
            ),
          ),
        ),
      );
      expect(find.byType(ShutterButton), findsOneWidget);
    });

    testWidgets('invokes onPressed when tapped', (WidgetTester tester) async {
      int taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ShutterButton(
              mode: CameraMode.photo,
              isRecording: false,
              onPressed: () => taps++,
            ),
          ),
        ),
      );
      await tester.tap(find.byType(ShutterButton));
      expect(taps, 1);
    });
  });
}

void _noop() {}
