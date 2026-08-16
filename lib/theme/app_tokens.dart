import 'package:flutter/material.dart';

/// Design tokens — single source of truth for all visual values.
/// Translated 1:1 from PRJ-012-T1 designer/design-tokens.md.
abstract final class AppTokens {
  // ── Colors ────────────────────────────────────────────────────────────────
  static const Color background = Color(0xFF000000);
  static const Color white = Color(0xFFFFFFFF);
  static const Color white70 = Color(0xB3FFFFFF); // rgba(255,255,255,0.70)
  static const Color white50 = Color(0x80FFFFFF); // rgba(255,255,255,0.50)
  static const Color white30 = Color(0x4DFFFFFF); // rgba(255,255,255,0.30)
  static const Color white10 = Color(0x1AFFFFFF); // rgba(255,255,255,0.10)
  static const Color gpsChipBg = Color(0x73000000); // rgba(0,0,0,0.45)
  static const Color recordRed = Color(0xFFFF3B30);
  static const Color amber = Color(0xFFFFD60A);
  static const Color amberBg = Color(0x1FFFCC00); // rgba(255,204,0,0.12)
  static const Color amberBorder = Color(0x59FFCC00); // rgba(255,204,0,0.35)

  // ── Spacing ───────────────────────────────────────────────────────────────
  static const double spaceXxs = 4;
  static const double spaceXs = 8;
  static const double spaceSm = 12;
  static const double spaceMd = 16;
  static const double spaceLg = 24;

  // ── Sizes ─────────────────────────────────────────────────────────────────
  static const double sizeShutter = 76;
  static const double sizeShutterFillPhoto = 62;
  static const double sizeShutterFillVideo = 34;
  static const double sizeShutterStop = 20;
  static const double sizeShutterRing = 4;
  static const double sizeFlipButton = 40;
  static const double sizeCloseButton = 40;
  static const double sizeRecDot = 10;
  static const double sizePlayButton = 72;
  static const double sizeIconError = 48;
  static const double maxContentWidth = 520;
  static const double gpsChipMarginBottom = 96;
  static const double scrimTopHeight = 96;
  static const double scrimBottomHeight = 150;

  // ── Radius ────────────────────────────────────────────────────────────────
  static const double radiusChip = 10;
  static const double radiusFull = 999;
  static const double radiusButton = 22;

  // ── Typography ────────────────────────────────────────────────────────────
  static const double textCoords = 15;
  static const double textAccuracy = 12;
  static const double textModeLabel = 13;
  static const double textTimer = 15;
  static const double textErrorTitle = 17;
  static const double textErrorBody = 14;
  static const double textLoading = 14;
  static const double textBanner = 12.5;
  static const double textButtonLabel = 15;

  // ── Animation ─────────────────────────────────────────────────────────────
  static const Duration durPress = Duration(milliseconds: 150);
  static const Duration durFlash = Duration(milliseconds: 250);
  static const Duration durFade = Duration(milliseconds: 200);
  static const Duration durChipStatus = Duration(milliseconds: 150);
  static const Duration durRecPulse = Duration(milliseconds: 900);
}
