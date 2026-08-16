import 'dart:async';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../models/location_data.dart';
import '../services/camera_service.dart';
import '../services/download.dart';
import '../services/location_service.dart';
import '../services/media_service.dart';
import '../services/secure_context.dart';
import '../services/video_controller.dart';
import '../services/video_compositor.dart';
import '../theme/app_tokens.dart';
import '../widgets/camera_controls.dart';
import '../widgets/gps_overlay.dart';
import '../widgets/mode_selector.dart';

/// UI phases of the camera state machine (architect ARCHITECTURE.md §4).
enum CameraPhase {
  checking,
  initializing,
  live,
  recording,
  photoPreview,
  videoPreview,
  error,
}

/// Single-screen camera app (spec §1): live preview with realtime GPS overlay,
/// photo capture with GPS burn-in, video recording, permission handling and
/// graceful error states (spec §18). No menus, no dashboard.
class CameraScreen extends StatefulWidget {
  const CameraScreen({
    super.key,
    this.cameraService,
    this.locationService,
    this.mediaService,
    this.videoCompositor,
  });

  /// Injectable for widget tests; defaults are created in state.
  final CameraService? cameraService;
  final LocationService? locationService;
  final MediaService? mediaService;
  final VideoCompositor? videoCompositor;

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  late final CameraService _cameraService =
      widget.cameraService ?? CameraService();
  late final LocationService _locationService =
      widget.locationService ?? LocationService();
  late final MediaService _mediaService = widget.mediaService ?? MediaService();
  late final VideoCompositor _videoCompositor =
      widget.videoCompositor ?? PassthroughVideoCompositor(_cameraService);

  CameraPhase _phase = CameraPhase.checking;
  String _errorTitle = '';
  String _errorMessage = '';
  CameraMode _mode = CameraMode.photo;
  bool _secureContext = true;
  bool _flash = false;

  Uint8List? _photoBytes;
  XFile? _videoFile;
  VideoPlayerController? _videoController;
  bool _videoPlaying = false;
  bool _videoWasPlaying = false;

  @override
  void initState() {
    super.initState();
    _secureContext = isSecureContext();
    _init();
  }

  // ── State machine ─────────────────────────────────────────────────────────

  Future<void> _init() async {
    // Let the first frame render the "checking" state before mutating.
    await Future<void>.delayed(Duration.zero);
    if (!mounted) return;
    setState(() => _phase = CameraPhase.initializing);

    try {
      await _cameraService.initialize();
    } on CameraServiceException catch (e) {
      _showError('Kamera tidak tersedia', e.message);
      return;
    } catch (e) {
      _showError('Kamera tidak tersedia', e.toString());
      return;
    }

    if (!mounted) return;
    setState(() => _phase = CameraPhase.live);
    // GPS is independent of the camera: start it without blocking the camera.
    unawaited(_locationService.start());
  }

  Future<void> _retry() async {
    await _cameraService.dispose();
    unawaited(_locationService.restart());
    await _init();
  }

  void _showError(String title, String message) {
    if (!mounted) return;
    setState(() {
      _phase = CameraPhase.error;
      _errorTitle = title;
      _errorMessage = message;
    });
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }

  // ── Capture actions ───────────────────────────────────────────────────────

  Future<void> _onShutterPressed() async {
    if (_phase == CameraPhase.recording) {
      await _stopRecording();
    } else if (_mode == CameraMode.video) {
      await _startRecording();
    } else {
      await _capturePhoto();
    }
  }

  Future<void> _capturePhoto() async {
    setState(() => _flash = true);
    unawaited(
      Future<void>.delayed(const Duration(milliseconds: 70)).then((_) {
        if (mounted) setState(() => _flash = false);
      }),
    );
    try {
      final XFile shot = await _cameraService.takePhoto();
      final Uint8List bytes = await shot.readAsBytes();
      // GPS burn-in at the moment of capture (spec §15).
      final Uint8List stamped =
          await _mediaService.burnGpsOverlay(bytes, _locationService.location.value);
      if (!mounted) return;
      setState(() {
        _photoBytes = stamped;
        _phase = CameraPhase.photoPreview;
      });
    } catch (e) {
      _showSnack('Tangkapan foto gagal: $e');
    }
  }

  Future<void> _startRecording() async {
    try {
      await _videoCompositor.startRecording();
      if (!mounted) return;
      setState(() => _phase = CameraPhase.recording);
    } catch (e) {
      _showSnack('Rakaman gagal dimulakan: $e');
    }
  }

  Future<void> _stopRecording() async {
    try {
      final XFile? file = await _videoCompositor.stopRecording();
      if (!mounted || file == null) return;
      // Platform-isolated: native = File path, web = blob: URL
      // (see services/video_controller*.dart — no dart:io on web).
      final VideoPlayerController controller =
          await createVideoControllerFor(file.path);
      await controller.initialize();
      _videoWasPlaying = false;
      controller.addListener(_onVideoControllerChanged);
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _videoFile = file;
        _videoController = controller;
        _videoPlaying = false;
        _phase = CameraPhase.videoPreview;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _phase = CameraPhase.live);
        _showSnack('Rakaman gagal disimpan: $e');
      }
    }
  }

  void _onVideoControllerChanged() {
    final VideoPlayerController? c = _videoController;
    if (c == null) return;
    final bool playing = c.value.isPlaying;
    if (playing != _videoWasPlaying && mounted) {
      _videoWasPlaying = playing;
      setState(() => _videoPlaying = playing);
    }
  }

  Future<void> _togglePlay() async {
    final VideoPlayerController? c = _videoController;
    if (c == null) return;
    try {
      if (c.value.isPlaying) {
        await c.pause();
      } else {
        final Duration pos = c.value.position;
        final Duration dur = c.value.duration;
        if (dur > Duration.zero && pos >= dur) {
          await c.seekTo(Duration.zero);
        }
        await c.play();
      }
    } catch (_) {
      // Playback is best-effort; preview stays usable.
    }
    if (mounted) setState(() => _videoPlaying = c.value.isPlaying);
  }

  Future<void> _switchCamera() async {
    if (_phase == CameraPhase.recording) return;
    try {
      await _cameraService.switchCamera();
    } catch (e) {
      _showSnack('Tukar kamera gagal: $e');
    }
    if (mounted) setState(() {});
  }

  void _setMode(CameraMode mode) {
    if (_phase == CameraPhase.recording) return; // locked while recording
    setState(() => _mode = mode);
  }

  void _backToLive() {
    _videoController?.removeListener(_onVideoControllerChanged);
    _videoController?.dispose();
    _videoController = null;
    if (!mounted) return;
    setState(() {
      _photoBytes = null;
      _videoFile = null;
      _videoPlaying = false;
      _videoWasPlaying = false;
      _phase = CameraPhase.live;
    });
  }

  Future<void> _downloadPhoto() async {
    final Uint8List? bytes = _photoBytes;
    if (bytes == null) return;
    await downloadBytes(
      bytes,
      'gps_photo_${DateTime.now().millisecondsSinceEpoch}.jpg',
      'image/jpeg',
    );
  }

  Future<void> _downloadVideo() async {
    final XFile? f = _videoFile;
    if (f == null) return;
    final Uint8List bytes = await f.readAsBytes();
    final String mime = f.mimeType?.split(';').first ?? 'video/webm';
    final String ext = mime.contains('mp4') ? 'mp4' : 'webm';
    await downloadBytes(
      bytes,
      'gps_video_${DateTime.now().millisecondsSinceEpoch}.$ext',
      mime,
    );
  }

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _videoController?.removeListener(_onVideoControllerChanged);
    _videoController?.dispose();
    unawaited(_videoCompositor.dispose());
    unawaited(_locationService.dispose());
    unawaited(_cameraService.dispose());
    super.dispose();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTokens.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AppTokens.maxContentWidth),
            child: _buildBody(),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    switch (_phase) {
      case CameraPhase.checking:
      case CameraPhase.initializing:
        return const _LoadingView();
      case CameraPhase.error:
        return _ErrorView(
          title: _errorTitle,
          message: _errorMessage,
          onRetry: _retry,
        );
      case CameraPhase.photoPreview:
        return _PhotoPreviewView(
          bytes: _photoBytes,
          onClose: _backToLive,
          onRetake: _backToLive,
          onDownload: _downloadPhoto,
        );
      case CameraPhase.videoPreview:
        return _VideoPreviewView(
          controller: _videoController,
          playing: _videoPlaying,
          onClose: _backToLive,
          onPlayPause: _togglePlay,
          onDownload: _downloadVideo,
        );
      case CameraPhase.live:
      case CameraPhase.recording:
        return _buildLiveView();
    }
  }

  Widget _buildLiveView() {
    final bool recording = _phase == CameraPhase.recording;
    final bool bannerVisible = kIsWeb && !_secureContext;
    final double topInset = bannerVisible ? 40 : 8;

    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        // 1. Camera preview (cover-cropped, full-bleed).
        _buildPreview(),

        // 2. Top scrim for legibility of the flip button / REC indicator.
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: AppTokens.scrimTopHeight,
          child: const _TopScrim(),
        ),

        // 3. Flip camera button (disabled while recording).
        Positioned(
          top: topInset,
          right: 8,
          child: FlipCameraButton(
            enabled: !recording,
            onPressed: _switchCamera,
          ),
        ),

        // 4. Recording indicator (REC dot + mm:ss), top-center.
        if (recording)
          Positioned(
            top: topInset,
            left: 0,
            right: 0,
            child: Center(
              child: ValueListenableBuilder<Duration>(
                valueListenable: _videoCompositor.elapsed,
                builder: (BuildContext _, Duration d, Widget? __) =>
                    RecordingIndicator(elapsed: d),
              ),
            ),
          ),

        // 5. GPS chip — bottom-center, above the bottom controls (spec §6).
        Positioned(
          left: 0,
          right: 0,
          bottom: AppTokens.scrimBottomHeight + AppTokens.spaceSm,
          child: Center(
            child: ValueListenableBuilder<LocationData?>(
              valueListenable: _locationService.location,
              builder: (BuildContext _, LocationData? data, Widget? __) =>
                  GpsOverlay(location: data),
            ),
          ),
        ),

        // 6. Bottom scrim + controls.
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: _BottomControls(
            mode: _mode,
            recording: recording,
            cameraReady: _cameraService.isInitialized,
            modeLocked: recording,
            onShutter: _onShutterPressed,
            onModeChanged: _setMode,
          ),
        ),

        // 7. White capture flash.
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedOpacity(
              opacity: _flash ? 0.45 : 0.0,
              duration: AppTokens.durFlash,
              child: Container(color: AppTokens.white),
            ),
          ),
        ),

        // 8. Secure-context banner (web, http:// only — spec §11).
        if (bannerVisible)
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SecureContextBanner(),
          ),
      ],
    );
  }

  Widget _buildPreview() {
    final CameraController? c = _cameraService.controller;
    if (c == null || !c.value.isInitialized) {
      return Container(color: AppTokens.background);
    }
    final Size? previewSize = c.value.previewSize;
    if (previewSize == null) {
      return CameraPreview(c);
    }
    // Cover-crop so the GPS chip always sits on top of the camera image
    // (never on a letterbox bar), like a modern phone camera.
    return FittedBox(
      fit: BoxFit.cover,
      clipBehavior: Clip.hardEdge,
      child: SizedBox(
        width: previewSize.height,
        height: previewSize.width,
        child: CameraPreview(c),
      ),
    );
  }
}

// ── Private views ───────────────────────────────────────────────────────────

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(
              color: AppTokens.white70,
              strokeWidth: 3,
            ),
          ),
          SizedBox(height: AppTokens.spaceMd),
          Text(
            'Memulakan kamera…',
            style: TextStyle(
              color: AppTokens.white70,
              fontSize: AppTokens.textLoading,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({
    required this.title,
    required this.message,
    required this.onRetry,
  });

  final String title;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.spaceLg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Icons.videocam_off_outlined,
              color: AppTokens.white70,
              size: AppTokens.sizeIconError,
            ),
            const SizedBox(height: AppTokens.spaceMd),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppTokens.white,
                fontSize: AppTokens.textErrorTitle,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppTokens.spaceXs),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppTokens.white70,
                fontSize: AppTokens.textErrorBody,
                height: 1.4,
              ),
            ),
            const SizedBox(height: AppTokens.spaceLg),
            _PillButton(label: 'Retry', onPressed: onRetry),
          ],
        ),
      ),
    );
  }
}

class _PhotoPreviewView extends StatelessWidget {
  const _PhotoPreviewView({
    required this.bytes,
    required this.onClose,
    required this.onRetake,
    required this.onDownload,
  });

  final Uint8List? bytes;
  final VoidCallback onClose;
  final VoidCallback onRetake;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    final Uint8List? data = bytes;
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        Container(color: AppTokens.background),
        if (data != null)
          Center(
            child: InteractiveViewer(
              maxScale: 4,
              child: Image.memory(data, fit: BoxFit.contain),
            ),
          ),
        Positioned(
          top: 8,
          left: 8,
          child: _CloseButton(onPressed: onClose),
        ),
        if (data != null)
          Positioned(
            left: 0,
            right: 0,
            bottom: AppTokens.spaceLg,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                _PillButton(
                  label: 'Ambil Lagi',
                  onPressed: onRetake,
                  outlined: true,
                ),
                if (kIsWeb) const SizedBox(width: AppTokens.spaceSm),
                if (kIsWeb)
                  _PillButton(label: 'Download', onPressed: onDownload),
              ],
            ),
          ),
      ],
    );
  }
}

class _VideoPreviewView extends StatelessWidget {
  const _VideoPreviewView({
    required this.controller,
    required this.playing,
    required this.onClose,
    required this.onPlayPause,
    required this.onDownload,
  });

  final VideoPlayerController? controller;
  final bool playing;
  final VoidCallback onClose;
  final VoidCallback onPlayPause;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    final VideoPlayerController? c = controller;
    final bool ready = c != null && c.value.isInitialized;
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        Container(color: AppTokens.background),
        if (ready)
          Center(
            child: AspectRatio(
              aspectRatio: c.value.aspectRatio,
              child: VideoPlayer(c),
            ),
          ),
        Positioned(top: 8, left: 8, child: _CloseButton(onPressed: onClose)),
        if (ready && !playing)
          Center(
            child: GestureDetector(
              onTap: onPlayPause,
              child: Container(
                width: AppTokens.sizePlayButton,
                height: AppTokens.sizePlayButton,
                decoration: const BoxDecoration(
                  color: AppTokens.white30,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  color: AppTokens.white,
                  size: 40,
                ),
              ),
            ),
          ),
        Positioned(
          left: 0,
          right: 0,
          bottom: AppTokens.spaceLg,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              _PillButton(
                label: 'Selesai',
                onPressed: onClose,
                outlined: true,
              ),
              if (kIsWeb) const SizedBox(width: AppTokens.spaceSm),
              if (kIsWeb) _PillButton(label: 'Download', onPressed: onDownload),
            ],
          ),
        ),
      ],
    );
  }
}

class _BottomControls extends StatelessWidget {
  const _BottomControls({
    required this.mode,
    required this.recording,
    required this.cameraReady,
    required this.modeLocked,
    required this.onShutter,
    required this.onModeChanged,
  });

  final CameraMode mode;
  final bool recording;
  final bool cameraReady;
  final bool modeLocked;
  final VoidCallback onShutter;
  final ValueChanged<CameraMode> onModeChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: AppTokens.scrimBottomHeight,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Colors.transparent, Color(0x8C000000)], // 0.55 alpha
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: <Widget>[
          ShutterButton(
            mode: mode,
            isRecording: recording,
            enabled: cameraReady,
            onPressed: onShutter,
          ),
          const SizedBox(height: AppTokens.spaceSm),
          ModeSelector(
            mode: mode,
            enabled: !modeLocked,
            onChanged: onModeChanged,
          ),
          const SizedBox(height: AppTokens.spaceMd),
        ],
      ),
    );
  }
}

class _TopScrim extends StatelessWidget {
  const _TopScrim();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Color(0x59000000), Colors.transparent], // 0.35 alpha
        ),
      ),
    );
  }
}

class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onPressed,
      child: Container(
        width: AppTokens.sizeCloseButton,
        height: AppTokens.sizeCloseButton,
        decoration: const BoxDecoration(
          color: AppTokens.white30,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.close, color: AppTokens.white, size: 20),
      ),
    );
  }
}

class _PillButton extends StatelessWidget {
  const _PillButton({
    required this.label,
    required this.onPressed,
    this.outlined = false,
  });

  final String label;
  final VoidCallback onPressed;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    final Color bg = outlined ? AppTokens.white10 : AppTokens.white;
    final Color fg = outlined ? AppTokens.white : AppTokens.background;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 28,
          vertical: 12,
        ),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AppTokens.radiusButton),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: fg,
            fontSize: AppTokens.textButtonLabel,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

/// Amber banner shown on web when the page is not served over HTTPS or
/// localhost — camera & GPS are blocked by the browser (spec §11).
class SecureContextBanner extends StatelessWidget {
  const SecureContextBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: AppTokens.spaceSm, vertical: 8),
      decoration: const BoxDecoration(
        color: AppTokens.amberBg,
        border: Border(bottom: BorderSide(color: AppTokens.amberBorder)),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(Icons.warning_amber_rounded, color: AppTokens.amber, size: 14),
          SizedBox(width: 6),
          Flexible(
            child: Text(
              'Camera & GPS memerlukan HTTPS atau localhost',
              style: TextStyle(
                color: AppTokens.amber,
                fontSize: AppTokens.textBanner,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
