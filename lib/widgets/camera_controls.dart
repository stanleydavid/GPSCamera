import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';
import 'mode_selector.dart';

/// Large circular shutter (spec §7):
///  - photo mode: white ring + white inner disc;
///  - video mode: white ring + red (#FF3B30) inner disc;
///  - while recording: white ring + white square (stop).
/// Press feedback: scale 1.0 → 0.92 (150ms).
class ShutterButton extends StatefulWidget {
  const ShutterButton({
    super.key,
    required this.mode,
    required this.isRecording,
    required this.onPressed,
    this.enabled = true,
  });

  final CameraMode mode;
  final bool isRecording;
  final VoidCallback onPressed;
  final bool enabled;

  @override
  State<ShutterButton> createState() => _ShutterButtonState();
}

class _ShutterButtonState extends State<ShutterButton> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _pressed ? 0.92 : 1.0,
      duration: AppTokens.durPress,
      curve: Curves.easeOutCubic,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: widget.enabled ? (_) => _setPressed(true) : null,
        onTapUp: widget.enabled ? (_) => _setPressed(false) : null,
        onTapCancel: widget.enabled ? () => _setPressed(false) : null,
        onTap: widget.enabled ? widget.onPressed : null,
        child: Opacity(
          opacity: widget.enabled ? 1 : 0.4,
          child: Container(
            width: AppTokens.sizeShutter,
            height: AppTokens.sizeShutter,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: AppTokens.white,
                width: AppTokens.sizeShutterRing,
              ),
            ),
            alignment: Alignment.center,
            child: _buildInner(),
          ),
        ),
      ),
    );
  }

  Widget _buildInner() {
    if (widget.isRecording) {
      return Container(
        width: AppTokens.sizeShutterStop,
        height: AppTokens.sizeShutterStop,
        decoration: BoxDecoration(
          color: AppTokens.white,
          borderRadius: BorderRadius.circular(4),
        ),
      );
    }
    final bool isVideo = widget.mode == CameraMode.video;
    final double fill = isVideo
        ? AppTokens.sizeShutterFillVideo
        : AppTokens.sizeShutterFillPhoto;
    final Color color = isVideo ? AppTokens.recordRed : AppTokens.white;
    return Container(
      width: fill,
      height: fill,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

/// Pulsing red dot + elapsed mm:ss while recording (spec §4).
class RecordingIndicator extends StatefulWidget {
  const RecordingIndicator({super.key, required this.elapsed});

  final Duration elapsed;

  @override
  State<RecordingIndicator> createState() => _RecordingIndicatorState();
}

class _RecordingIndicatorState extends State<RecordingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: AppTokens.durRecPulse,
    lowerBound: 0.3,
    upperBound: 1.0,
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppTokens.gpsChipBg,
        borderRadius: BorderRadius.circular(AppTokens.radiusChip),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          FadeTransition(
            opacity: _pulse,
            child: Container(
              width: AppTokens.sizeRecDot,
              height: AppTokens.sizeRecDot,
              decoration: const BoxDecoration(
                color: AppTokens.recordRed,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: AppTokens.spaceXs),
          Text(
            _format(widget.elapsed),
            style: const TextStyle(
              color: AppTokens.white,
              fontSize: AppTokens.textTimer,
              fontWeight: FontWeight.w600,
              fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  static String _format(Duration d) {
    final String minutes = d.inMinutes.toString().padLeft(2, '0');
    final String seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}

/// Ghost circular button for switching front/rear camera (spec §2).
/// Disabled while recording (re-creating the controller kills the recording).
class FlipCameraButton extends StatelessWidget {
  const FlipCameraButton({super.key, required this.onPressed, this.enabled = true});

  final VoidCallback onPressed;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? onPressed : null,
        child: Container(
          width: AppTokens.sizeFlipButton,
          height: AppTokens.sizeFlipButton,
          decoration: const BoxDecoration(
            color: AppTokens.white30,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: const Icon(
            Icons.flip_camera_ios_outlined,
            color: AppTokens.white,
            size: 20,
          ),
        ),
      ),
    );
  }
}
