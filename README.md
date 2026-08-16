# GPS Camera — MVP (PRJ-012-T1)

Flutter camera app gaya iPhone yang minimal: **live camera preview + overlay GPS
lat/lng masa nyata**, tangkap foto **dengan GPS dibakar ke dalam imej**, rakam
video dengan GPS terus berjalan — untuk **Android, iOS, dan Web preview**.

> Dibina oleh coder worker PRJ-012-T1 mengikut `architect/ARCHITECTURE.md` dan
> `designer/DESIGN-SPEC.md` + `design-tokens.md` (folder output architect/designer).
> Sumber kebenaran visual: `design-tokens.md`.

---

## Ciri

- Live camera preview (kamera belakang default; switch depan/belakang bila ada)
- Overlay GPS masa nyata di bawah preview: `GPS 5.980123, 116.073456` + `Accuracy ±8m`
- Photo capture dengan **GPS burn-in** ke dalam fail imej (spec §15)
- Video recording: indicator REC + duration, GPS terus update, playback preview
- Permission handling penuh (kamera, mikrofon, lokasi) + error states tanpa crash
- Banner amaran pada web bila bukan HTTPS/localhost (spec §11)
- Responsif: portrait/landscape/desktop (desktop = lajur tengah ala-phone, max 520px)

## Struktur

```
lib/
├── main.dart                  # entry
├── app.dart                   # MaterialApp (dark, single screen)
├── theme/app_tokens.dart      # design tokens (sumber nilai visual)
├── screens/camera_screen.dart # state machine induk (checking→…→live/recording/preview)
├── widgets/
│   ├── camera_controls.dart   # shutter ◯/●/■, REC indicator, flip button
│   ├── gps_overlay.dart       # chip GPS (live & rujukan burn-in)
│   └── mode_selector.dart     # PHOTO | VIDEO
├── services/
│   ├── camera_service.dart    # wrapper camera plugin
│   ├── location_service.dart  # wrapper geolocator (permission + stream)
│   ├── media_service.dart     # burn-in GPS ke foto (package:image)
│   ├── video_compositor.dart  # interface compositing video (spec §4.3)
│   ├── secure_context.dart    # pengesanan HTTPS/localhost
│   └── download.dart          # download blob (web) / no-op (mobile)
└── models/location_data.dart  # lat/lng 6dp + accuracy
```

---

## Cara jalankan

Prasyarat: Flutter SDK (disahkan di VM build: **3.44.8**, `/home/ubuntu/flutter`).

```bash
cd projects/gpscamera

# 1) Lengkapkan scaffolding platform (gradle wrapper, ikon web, dll) — idempotent,
#    tidak menimpa lib/ atau pubspec.
flutter create --org com.earthinfo --project-name gps_camera --platforms android,ios,web .

flutter pub get
```

### Web (preview development — perlu HTTPS atau localhost untuk kamera/GPS)

```bash
# Dev loop cepat (debug, DWDS):
flutter run -d web-server --web-hostname 0.0.0.0 --web-port 8080

# Preview stabil (release, untuk Output Panel / deploy) — WAJIB:
flutter build web --release
# kemudian serve build/web dengan static server (lihat deploy/ + ENVIRONMENT-DEPLOYMENT.md)
```

> **Penting (spec §11):** kamera (`getUserMedia`) dan GPS (`navigator.geolocation`)
> HANYA berfungsi dalam secure context: `https://` atau `localhost`.
> `http://192.168.x.x:3005` dari komputer operator akan disekat browser — app
> memaparkan banner amber dan UI kekal jalan (tiada mock data).

### Android

```bash
flutter build apk --debug     # atau: flutter run
```

Permission (sudah dikonfigurasi di `android/app/src/main/AndroidManifest.xml`):
`CAMERA`, `RECORD_AUDIO`, `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`,
minSdk 24 (keperluan `camera` 0.12 / CameraX).

### iOS (perlu macOS + Xcode — config lengkap, build di Linux mustahil)

```bash
flutter build ios --debug     # jalankan di Mac
```

Usage descriptions sudah dikonfigurasi di `ios/Runner/Info.plist`:
`NSCameraUsageDescription`, `NSMicrophoneUsageDescription`,
`NSLocationWhenInUseUsageDescription`.

---

## Ujian

```bash
flutter analyze      # sasaran: 0 error (blocking)
flutter test         # unit + widget tests
flutter build web --release
```

Test yang disertakan:

| Fail | Liputan |
|---|---|
| `test/location_data_test.dart` | format 6dp (termasuk negatif & rounding), baris accuracy |
| `test/media_service_test.dart` | burn-in GPS pada imej sintetik: saiz kekal, pixel bawah berubah, null-location, bytes bukan-imej |
| `test/widgets_test.dart` | GpsOverlay (ada/tiada data), ModeSelector toggle/disabled, ShutterButton |

---

## Pakej

Disahkan di pub.dev pada 2026-08-16 (serasi Flutter 3.44.8 / Dart 3.12.2):

| Pakej | Versi | Kegunaan |
|---|---|---|
| `camera` | ^0.12.0+2 | preview, foto, video, switch kamera (web = camera_web/MediaRecorder) |
| `geolocator` | ^14.0.3 | GPS stream (web = navigator.geolocation) |
| `video_player` | ^2.14.0 | playback video preview |
| `image` | ^4.9.1 | burn-in GPS (pure Dart, semua platform) |

Tiada permission_handler / bloc / riverpod / ffmpeg — kekal lean (spec §12, §13).

---

## Known limitations (jujur, spec §4 & §21)

1. **Video: overlay GPS tidak dibakar ke dalam fail video** (web & native v1).
   Plugin kamera merakam stream mentah; Dart tiada akses ke frame terenkod.
   Seperti yang dibenarkan spec §4, MVP menyediakan: (a) overlay GPS masa nyata
   atas preview semasa rakam, (b) rakaman video normal, (c) `VideoCompositor`
   diasingkan (`lib/services/video_compositor.dart`) supaya post-process
   compositor (ffmpeg/media_kit) boleh di-plug tanpa ubah UI.
2. **Web: kamera/GPS memerlukan HTTPS atau localhost** — `http://` LAN disekat
   browser; app papar banner amber (spec §11, tiada mock).
3. **Foto burn-in guna `package:image` re-encode JPEG** — EXIF asal tidak
   dipelihara. EXIF GPS adalah optional stretch (spec §16); overlay visible
   adalah mandatori dan siap dilaksanakan.
4. **iOS build** tidak boleh dijalankan di Linux (perlu macOS/Xcode) — konfigurasi
   Info.plist lengkap + arahan disediakan ("where environment permits").
5. **Mobile save-to-gallery** di luar scope MVP (tiada path_provider/galeri) —
   preview in-app + download web disediakan untuk bukti eksport.

## Deployment (Output Panel)

- Deploy target: EXT-002 (Charlie VM193, 192.168.2.125) port **3005**.
  (Nota builder 2026-08-16: 3002 = D-Billboard DBKK, 3003 = Public Complaint,
  3004 = Smart City Friends sudah diambil; 3005 disahkan kosong.)
- Skrip: `tool/setup_and_build.sh` (scaffold + verify + build web + apk bila ada
  Android SDK).
- Static server: `deploy/serve_web.js` (SPA fallback + MIME wasm/js — guna PM2,
  `PORT=3005`).
- URL preview MESTI HTTPS (Cloudflare bind `gpscamera.dbkk.my` atau cloudflared
  quick tunnel) — lihat `architect/ENVIRONMENT-DEPLOYMENT.md` §3.
- `flutter run -d web-server` hanya untuk dev loop, BUKAN preview akhir.
