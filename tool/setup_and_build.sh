#!/usr/bin/env bash
# PRJ-012-T1 GPSCamera — scaffold + verify + build (jalankan di build VM, VM192).
#
# Usage:  bash tool/setup_and_build.sh   (dari mana-mana folder; script cd sendiri)
#
# Langkah:
#   1. flutter create  → lengkapkan scaffolding platform yang hilang
#      (gradle wrapper binaries, ikon web, projek iOS, .metadata) — additive,
#      TIDAK menimpa lib/, pubspec.yaml, atau fail platform yang telah ditulis
#      coder (AndroidManifest.xml/Info.plist/build.gradle.kts dengan minSdk 24).
#   2. Jika ada .git: pulihkan fail platform yang tracked (langkah selamat).
#   3. pub get → analyze → test → build web --release (SEMUA blocking).
#   4. build apk --debug JIKA flutter doctor menunjukkan Android toolchain
#      (kalau tidak: didokumen sebagai limitation — "where environment permits").
#   5. Semua log disalin ke build/verify/<timestamp>/ — bukti untuk QA.
#
# Exit code: 0 = analyze+test+build web lulus (apk boleh gagal tanpa block).
set -euo pipefail

export PATH="$PATH:/home/ubuntu/flutter/bin"
cd "$(dirname "$0")/.."   # → projects/gpscamera

STAMP="$(date +%Y%m%d-%H%M%S)"
LOG_DIR="build/verify/$STAMP"
mkdir -p "$LOG_DIR"
echo "==> Evidence logs: $LOG_DIR"

echo "==> Flutter version"
flutter --version | tee "$LOG_DIR/flutter-version.txt"
df -h . | tee "$LOG_DIR/disk.txt"

echo "==> flutter doctor -v (check Android SDK)"
flutter doctor -v > "$LOG_DIR/flutter-doctor.txt" 2>&1 || true

echo "==> Scaffold missing platform files (idempotent, additive)"
flutter create --org com.earthinfo --project-name gps_camera --platforms android,ios,web . \
  | tee "$LOG_DIR/flutter-create.txt"

# Pulihkan fail platform yang kita jaga sekiranya flutter create menimpanya.
# (Fail baharu seperti gradle-wrapper.jar adalah untracked → kekal.)
if [ -d .git ]; then
  echo "==> Restore tracked platform config (manifest / plist / build.gradle.kts)"
  git checkout -- android ios web 2>/dev/null || true
fi

# Buang test template default yang flutter create jana (widget_test.dart rujuk MyApp,
# tak wujud dalam projek ni — coder ada test sendiri: location_data/media_service/widgets_test).
rm -f test/widget_test.dart

echo "==> pub get"
flutter pub get | tee "$LOG_DIR/pub-get.txt"

echo "==> flutter analyze"
if ! flutter analyze > "$LOG_DIR/analyze.txt" 2>&1; then
  # Acceptance (spec §21): analyze must pass WITHOUT BLOCKING ERRORS. Warnings /
  # infos are reported but do not fail the gate — only real `error •` lines do.
  if grep -qE "^ *error •" "$LOG_DIR/analyze.txt"; then
    echo "!! ANALYZE FAILED (blocking errors) — log: $LOG_DIR/analyze.txt"
    grep -E "^ *error •" "$LOG_DIR/analyze.txt" | head -30
    exit 1
  fi
  echo "!! ANALYZE: issues found (warnings/infos only, non-blocking) — log: $LOG_DIR/analyze.txt"
fi

echo "==> flutter test"
if ! flutter test > "$LOG_DIR/test.txt" 2>&1; then
  echo "!! TEST FAILED — log: $LOG_DIR/test.txt"; tail -80 "$LOG_DIR/test.txt"; exit 1
fi

echo "==> flutter build web --release"
if ! flutter build web --release > "$LOG_DIR/build-web.txt" 2>&1; then
  echo "!! WEB BUILD FAILED — log: $LOG_DIR/build-web.txt"; tail -100 "$LOG_DIR/build-web.txt"; exit 1
fi

# Android: hanya jika toolchain wujud di VM ini.
if grep -q "Android toolchain" "$LOG_DIR/flutter-doctor.txt"; then
  echo "==> flutter build apk --debug"
  if ! flutter build apk --debug > "$LOG_DIR/build-apk.txt" 2>&1; then
    echo "!! APK BUILD FAILED (tidak blocking) — log: $LOG_DIR/build-apk.txt"
    tail -60 "$LOG_DIR/build-apk.txt" || true
  fi
else
  echo "==> SKIP apk — Android toolchain tiada di VM (lihat flutter-doctor.txt)"
  echo "Android toolchain not detected — apk build skipped (documented limitation)." > "$LOG_DIR/build-apk.txt"
fi

echo ""
echo "OK — ANALYZE / TEST / BUILD WEB LULUS"
echo "Evidence logs : $LOG_DIR"
echo "Web build     : $(pwd)/build/web"
ls -la build/web | head -25
echo ""
echo "Deploy: scp -r build/web ubuntu@192.168.2.125:/home/ubuntu/gpscamera-web/"
echo "        PORT=3005 pm2 start deploy/serve_web.js --name gpscamera-web && pm2 save"
