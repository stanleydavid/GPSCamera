import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

/// Capture mode: photo or video (spec §7).
enum CameraMode { photo, video }

/// Minimal PHOTO | VIDEO selector below the shutter — labels with a small dot
/// on the active mode. Locked (disabled) while recording.
class ModeSelector extends StatelessWidget {
  const ModeSelector({
    super.key,
    required this.mode,
    required this.onChanged,
    this.enabled = true,
  });

  final CameraMode mode;
  final ValueChanged<CameraMode> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _ModeItem(
          label: 'PHOTO',
          active: mode == CameraMode.photo,
          enabled: enabled,
          onTap: () => onChanged(CameraMode.photo),
        ),
        const SizedBox(width: 56),
        _ModeItem(
          label: 'VIDEO',
          active: mode == CameraMode.video,
          enabled: enabled,
          onTap: () => onChanged(CameraMode.video),
        ),
      ],
    );
  }
}

class _ModeItem extends StatelessWidget {
  const _ModeItem({
    required this.label,
    required this.active,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool active;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                label,
                style: TextStyle(
                  color: active ? AppTokens.white : AppTokens.white50,
                  fontSize: AppTokens.textModeLabel,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: AppTokens.spaceXxs),
              AnimatedContainer(
                duration: AppTokens.durFade,
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  color: active ? AppTokens.white : Colors.transparent,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
