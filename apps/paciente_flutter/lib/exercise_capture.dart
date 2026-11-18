import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:video_player/video_player.dart';

import 'data.dart';
import 'exercise_analysis.dart';
import 'screens.dart';
import 'theme.dart';

/// Records the assigned exercise while estimating the movement pattern on device.
/// Frames never leave the phone; only the video (with consent) and the summary
/// are sent to the physiotherapist of this session.
class ExerciseCaptureScreen extends StatefulWidget {
  const ExerciseCaptureScreen({
    super.key,
    required this.session,
    required this.activity,
    required this.repository,
  });
  final CareSession session;
  final CareActivity activity;
  final CareRepository repository;
  @override
  State<ExerciseCaptureScreen> createState() => _ExerciseCaptureScreenState();
}

class _ExerciseCaptureScreenState extends State<ExerciseCaptureScreen> {
  static const _maxSeconds = 120;
  final detector = PoseDetector(
    options: PoseDetectorOptions(
      mode: PoseDetectionMode.stream,
      model: PoseDetectionModel.base,
    ),
  );

  /// Null for exercises without automatic counting (video only).
  late final ExerciseType? type = widget.activity.exercise;
  late final int target =
      (widget.activity.targetReps ?? 10) * (widget.activity.targetSets ?? 1);
  ExerciseAnalyzer? analyzer;

  List<CameraDescription> cameras = const [];
  CameraController? controller;
  int cameraIndex = 0;
  bool busy = false, recording = false, stopping = false;
  int? countdown;
  List<Landmark>? landmarks;
  String? message, error;
  int reps = 0, elapsed = 0;
  DateTime? startedAt;
  Timer? timer, ticker;
  DateTime? targetReachedAt;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    _init();
  }

  Future<void> _init() async {
    try {
      cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw const FormatException('No se encontró cámara.');
      }
      final front = cameras.indexWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
      );
      cameraIndex = front < 0 ? 0 : front;
      await _open();
    } on CameraException catch (e) {
      setState(
        () => error = e.code.contains('Access')
            ? 'Permite el acceso a la cámara para grabar tu ejercicio.'
            : 'No se pudo abrir la cámara.',
      );
    } catch (e) {
      setState(() => error = friendlyError(e));
    }
  }

  Future<void> _open() async {
    final old = controller;
    controller = null;
    if (mounted) setState(() {});
    await old?.dispose();
    final c = CameraController(
      cameras[cameraIndex],
      // 720p is 16:9 for both preview and video. With a 4:3 preset CameraX
      // switches the preview to 16:9 when recording starts and the image
      // looked stretched.
      ResolutionPreset.high,
      enableAudio: false,
      fps: 30,
      // ~2.5 Mbps keeps a 1-minute recording around 19 MB for a faster upload.
      videoBitrate: 2500000,
      imageFormatGroup: Platform.isAndroid
          ? ImageFormatGroup.nv21
          : ImageFormatGroup.bgra8888,
    );
    await c.initialize();
    await c.lockCaptureOrientation(DeviceOrientation.portraitUp);
    if (type != null) await c.startImageStream(_onFrame);
    if (!mounted) {
      await c.dispose();
      return;
    }
    setState(() {
      controller = c;
      message = type == null
          ? 'Colócate en posición y pulsa Grabar.'
          : 'Buscando tu cuerpo…';
    });
  }

  CameraDescription get camera => cameras[cameraIndex];
  bool get mirrored => camera.lensDirection == CameraLensDirection.front;

  InputImage? _toInputImage(CameraImage image) {
    final rotation = InputImageRotationValue.fromRawValue(
      camera.sensorOrientation,
    );
    final format = InputImageFormatValue.fromRawValue(image.format.raw as int);
    if (rotation == null || format == null || image.planes.length != 1) {
      return null;
    }
    final plane = image.planes.first;
    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  List<Landmark>? _normalize(Pose? pose, CameraImage image) {
    if (pose == null) return null;
    final quarter =
        camera.sensorOrientation == 90 || camera.sensorOrientation == 270;
    final w = (quarter ? image.height : image.width).toDouble();
    final h = (quarter ? image.width : image.height).toDouble();
    return [
      for (final t in PoseLandmarkType.values)
        if (pose.landmarks[t] case final p?)
          Landmark(p.x / w, p.y / h, z: p.z / w, visibility: p.likelihood)
        else
          const Landmark(0, 0, visibility: 0),
    ];
  }

  Future<void> _onFrame(CameraImage image) async {
    final t0 = type;
    if (t0 == null || busy || stopping) return;
    busy = true;
    try {
      final input = _toInputImage(image);
      if (input == null) return;
      final poses = await detector.processImage(input);
      final lm = _normalize(poses.isEmpty ? null : poses.first, image);
      FrameFeedback fb;
      final a = analyzer;
      if (recording && startedAt != null && a != null) {
        final t = DateTime.now().difference(startedAt!).inMilliseconds / 1000;
        fb = a.process(lm, t);
        if (fb.reps >= target && targetReachedAt == null) {
          targetReachedAt = DateTime.now();
          Future.delayed(const Duration(milliseconds: 1500), _stop);
        }
      } else {
        fb = ExerciseAnalyzer(t0).process(lm, 0);
      }
      if (!mounted) return;
      setState(() {
        landmarks = lm;
        reps = recording ? fb.reps : 0;
        if (fb.message != null || !recording) {
          message =
              fb.message ?? 'Listo. Pulsa Grabar cuando estés en posición.';
        }
      });
    } catch (_) {
      // Skip frames ML Kit cannot process.
    } finally {
      busy = false;
    }
  }

  Future<void> _record() async {
    final c = controller;
    if (c == null || recording) return;
    for (var i = 3; i > 0; i--) {
      if (!mounted) return;
      setState(() => countdown = i);
      HapticFeedback.selectionClick();
      await Future<void>.delayed(const Duration(seconds: 1));
    }
    if (!mounted) return;
    setState(() => countdown = null);
    try {
      if (type != null && c.value.isStreamingImages) await c.stopImageStream();
      analyzer = type == null
          ? null
          : ExerciseAnalyzer(type!, targetReps: target);
      targetReachedAt = null;
      startedAt = DateTime.now();
      await c.startVideoRecording(onAvailable: type == null ? null : _onFrame);
      HapticFeedback.mediumImpact();
      setState(() {
        recording = true;
        elapsed = 0;
        message = type == null ? 'Grabando…' : 'Comienza el ejercicio';
      });
      timer = Timer(const Duration(seconds: _maxSeconds), _stop);
      ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => elapsed++);
      });
    } on CameraException {
      if (mounted) notice(context, 'No se pudo iniciar la grabación.');
    }
  }

  Future<void> _stop() async {
    final c = controller;
    if (c == null || !recording || stopping) return;
    stopping = true;
    timer?.cancel();
    ticker?.cancel();
    try {
      final file = await c.stopVideoRecording();
      HapticFeedback.mediumImpact();
      final seconds =
          DateTime.now().difference(startedAt!).inMilliseconds / 1000;
      final summary = analyzer?.summary(seconds);
      if (!mounted) return;
      setState(() => recording = false);
      final saved = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => ExerciseResultScreen(
            session: widget.session,
            activity: widget.activity,
            repository: widget.repository,
            summary: summary,
            videoPath: file.path,
            seconds: seconds,
          ),
        ),
      );
      if (!mounted) return;
      if (saved == true) {
        Navigator.of(context).pop(true);
        return;
      }
      setState(() => reps = 0);
      if (type != null) await c.startImageStream(_onFrame);
    } on CameraException {
      if (mounted) notice(context, 'No se pudo guardar la grabación.');
    } finally {
      stopping = false;
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    ticker?.cancel();
    controller?.dispose();
    detector.close();
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    super.dispose();
  }

  /// Full-screen preview with a fixed cover crop. The box is sized from the
  /// current preview size on every build, so when CameraX rebinds for video
  /// recording the image keeps its proportions instead of being squeezed.
  Widget _preview(CameraController c) {
    final size = c.value.previewSize ?? const Size(640, 480);
    return ClipRect(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: size.shortestSide,
          height: size.longestSide,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // CameraX's preview subtracts the *physical* device orientation
              // and expects the widget above to add it back. CameraPreview adds
              // the locked/recording orientation instead, so a tilted or flat
              // phone made the image rotate or stretch when recording started.
              // Adding back exactly the reported physical orientation keeps the
              // net rotation fixed for our portrait-only screen. While
              // recording, CameraX rebinds and the buffer arrives already
              // oriented, so the raw Texture is drawn without the delegate.
              ValueListenableBuilder<CameraValue>(
                valueListenable: c,
                builder: (_, value, child) => value.isRecordingVideo
                    ? Transform.scale(
                        scaleX: mirrored ? -1 : 1,
                        child: Texture(textureId: c.cameraId),
                      )
                    : RotatedBox(
                        quarterTurns: switch (value.deviceOrientation) {
                          DeviceOrientation.portraitUp => 0,
                          DeviceOrientation.landscapeRight => 1,
                          DeviceOrientation.portraitDown => 2,
                          DeviceOrientation.landscapeLeft => 3,
                        },
                        child: child,
                      ),
                child: c.buildPreview(),
              ),
              if (type != null)
                CustomPaint(
                  painter: SkeletonPainter(landmarks, mirror: mirrored),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: Text(type?.label ?? widget.activity.title),
        actions: [
          if (cameras.length > 1 && !recording)
            IconButton(
              tooltip: 'Cambiar cámara',
              icon: const Icon(Icons.cameraswitch_outlined),
              onPressed: () {
                cameraIndex = (cameraIndex + 1) % cameras.length;
                _open();
              },
            ),
        ],
      ),
      body: error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  error!,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            )
          : c == null || !c.value.isInitialized
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                Positioned.fill(child: _preview(c)),
                SafeArea(
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 56, 16, 0),
                      child: _InfoPanel(
                        reps: reps,
                        target: target,
                        counting: type != null,
                        message: message,
                        recording: recording,
                        elapsed: elapsed,
                      ),
                    ),
                  ),
                ),
                if (countdown != null)
                  Center(
                    child: TweenAnimationBuilder<double>(
                      key: ValueKey(countdown),
                      tween: Tween(begin: 1.6, end: 1),
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeOutBack,
                      builder: (_, s, child) =>
                          Transform.scale(scale: s, child: child),
                      child: Text(
                        '$countdown',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 120,
                          fontWeight: FontWeight.w800,
                          shadows: [Shadow(blurRadius: 18)],
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  left: 24,
                  right: 24,
                  bottom: 28,
                  child: SafeArea(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: recording
                            ? Colors.redAccent
                            : MedColors.secondary,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(58),
                      ),
                      onPressed: countdown != null || stopping
                          ? null
                          : recording
                          ? _stop
                          : _record,
                      icon: Icon(
                        recording
                            ? Icons.stop_rounded
                            : Icons.fiber_manual_record,
                      ),
                      label: Text(
                        stopping
                            ? 'Guardando…'
                            : recording
                            ? 'Terminar'
                            : 'Grabar',
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _InfoPanel extends StatelessWidget {
  const _InfoPanel({
    required this.reps,
    required this.target,
    required this.counting,
    required this.message,
    required this.recording,
    required this.elapsed,
  });
  final int reps, target, elapsed;
  final bool counting, recording;
  final String? message;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: .55),
      borderRadius: BorderRadius.circular(18),
    ),
    child: Row(
      children: [
        if (counting) ...[
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                transitionBuilder: (child, a) =>
                    ScaleTransition(scale: a, child: child),
                child: Text(
                  '$reps',
                  key: ValueKey(reps),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 40,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text('de $target', style: const TextStyle(color: Colors.white70)),
            ],
          ),
          const SizedBox(width: 16),
        ],
        Expanded(
          child: Semantics(
            liveRegion: true,
            child: Text(
              message ?? '',
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
        ),
        if (recording) ...[
          const Icon(Icons.circle, color: Colors.redAccent, size: 12),
          const SizedBox(width: 6),
          Text(
            '${elapsed ~/ 60}:${(elapsed % 60).toString().padLeft(2, '0')}',
            style: const TextStyle(color: Colors.white),
          ),
        ],
      ],
    ),
  );
}

class SkeletonPainter extends CustomPainter {
  SkeletonPainter(this.landmarks, {required this.mirror});
  final List<Landmark>? landmarks;
  final bool mirror;
  static const _bones = [
    (11, 12),
    (11, 13),
    (13, 15),
    (12, 14),
    (14, 16),
    (11, 23),
    (12, 24),
    (23, 24),
    (23, 25),
    (25, 27),
    (24, 26),
    (26, 28),
  ];
  @override
  void paint(Canvas canvas, Size size) {
    final lm = landmarks;
    if (lm == null) return;
    Offset at(Landmark p) =>
        Offset((mirror ? 1 - p.x : p.x) * size.width, p.y * size.height);
    final line = Paint()
      ..color = MedColors.secondary
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    final dot = Paint()..color = Colors.white;
    for (final (a, b) in _bones) {
      if (lm[a].visibility < .5 || lm[b].visibility < .5) continue;
      canvas.drawLine(at(lm[a]), at(lm[b]), line);
    }
    for (final i in [11, 12, 13, 14, 15, 16, 23, 24, 25, 26, 27, 28]) {
      if (lm[i].visibility >= .5) canvas.drawCircle(at(lm[i]), 6, dot);
    }
  }

  @override
  bool shouldRepaint(SkeletonPainter old) => old.landmarks != landmarks;
}

enum _SendStep { prepare, upload, save, done }

class ExerciseResultScreen extends StatefulWidget {
  const ExerciseResultScreen({
    super.key,
    required this.session,
    required this.activity,
    required this.repository,
    required this.summary,
    required this.videoPath,
    required this.seconds,
  });
  final CareSession session;
  final CareActivity activity;
  final CareRepository repository;
  final Map<String, dynamic>? summary;
  final String videoPath;
  final double seconds;
  @override
  State<ExerciseResultScreen> createState() => _ExerciseResultScreenState();
}

class _ExerciseResultScreenState extends State<ExerciseResultScreen> {
  late final VideoPlayerController video = VideoPlayerController.file(
    File(widget.videoPath),
  )..initialize().then((_) => mounted ? setState(() {}) : null);
  final note = TextEditingController();
  bool shareVideo = true, reportPain = false;
  double pain = 0;
  String? error;
  _SendStep? step;
  int sent = 0, total = 0;

  @override
  void dispose() {
    video.dispose();
    note.dispose();
    super.dispose();
  }

  Future<void> send() async {
    video.pause();
    setState(() {
      step = _SendStep.prepare;
      error = null;
      sent = 0;
      total = 0;
    });
    final s = widget.summary;
    try {
      await widget.repository.save(
        widget.session,
        RecordDraft(
          completed: s == null
              ? true
              : (s['complete_reps'] as int) >= (s['target_reps'] as int),
          activityId: widget.activity.id,
          exerciseMetrics: s,
          painAfter: reportPain ? pain.round() : null,
          videoPath: shareVideo ? widget.videoPath : null,
          note: note.text,
        ),
        onStep: (name) {
          if (!mounted) return;
          setState(
            () => step = switch (name) {
              'upload' => _SendStep.upload,
              'save' => _SendStep.save,
              _ => _SendStep.prepare,
            },
          );
        },
        onProgress: (a, b) {
          if (!mounted || b == 0) return;
          // Rebuild about once per percent to keep the animation smooth.
          if (a == b || (a - sent) * 100 ~/ b >= 1) {
            setState(() {
              sent = a;
              total = b;
            });
          }
        },
      );
      if (!mounted) return;
      setState(() => step = _SendStep.done);
      HapticFeedback.mediumImpact();
      await Future<void>.delayed(const Duration(milliseconds: 1400));
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          step = null;
          error = friendlyError(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.summary;
    final ok = s == null || s['pattern_ok'] == true;
    return PopScope(
      canPop: step == null,
      child: Scaffold(
        appBar: AppBar(title: const Text('Resultado del ejercicio')),
        body: Stack(
          children: [
            PageBody(
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: (ok ? MedColors.secondary : Colors.orange)
                        .withValues(alpha: .18),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        ok ? Icons.check_circle_outline : Icons.info_outline,
                        size: 36,
                        color: MedColors.primary,
                      ),
                      const SizedBox(height: 8),
                      if (s != null) ...[
                        for (final line in describeMetrics(s)) Text(line),
                        const SizedBox(height: 8),
                        const Text(
                          'Estimación automática por cámara. Tu fisioterapeuta revisará el video.',
                          style: TextStyle(fontSize: 12),
                        ),
                      ] else
                        Text(
                          'Video de ${widget.seconds.round()} segundos listo para enviar a tu fisioterapeuta.',
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (video.value.isInitialized)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: AspectRatio(
                      aspectRatio: video.value.aspectRatio,
                      child: GestureDetector(
                        onTap: () => setState(
                          () => video.value.isPlaying
                              ? video.pause()
                              : video.play(),
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            VideoPlayer(video),
                            if (!video.value.isPlaying)
                              const Icon(
                                Icons.play_circle_fill,
                                color: Colors.white70,
                                size: 64,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: reportPain,
                  onChanged: (v) => setState(() => reportPain = v),
                  title: const Text('Agregar dolor después del ejercicio'),
                ),
                if (reportPain) ...[
                  Text('Dolor: ${pain.round()} de 10'),
                  Slider(
                    value: pain,
                    max: 10,
                    divisions: 10,
                    label: '${pain.round()}',
                    onChanged: (v) => setState(() => pain = v),
                  ),
                ],
                TextField(
                  controller: note,
                  maxLength: 2000,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Nota para tu fisioterapeuta (opcional)',
                  ),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: shareVideo,
                  onChanged: (v) => setState(() => shareVideo = v!),
                  title: Text(
                    widget.repository.demo
                        ? 'En el modo de exploración el video no se envía.'
                        : 'Compartir el video con ${widget.session.professional}. Se guarda en almacenamiento privado.',
                  ),
                ),
                if (error != null)
                  Text(
                    error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(54),
                  ),
                  onPressed: step != null ? null : send,
                  icon: const Icon(Icons.send_rounded),
                  label: const Text('Enviar a mi fisioterapeuta'),
                ),
                TextButton(
                  onPressed: step != null
                      ? null
                      : () => Navigator.pop(context, false),
                  child: const Text('Repetir grabación'),
                ),
              ],
            ),
            if (step != null)
              Positioned.fill(
                child: _SendingOverlay(
                  step: step!,
                  sent: sent,
                  total: total,
                  withVideo: shareVideo && !widget.repository.demo,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Full-screen progress while sending: real upload percentage, steps and a
/// completion animation, so the app never looks frozen.
class _SendingOverlay extends StatelessWidget {
  const _SendingOverlay({
    required this.step,
    required this.sent,
    required this.total,
    required this.withVideo,
  });
  final _SendStep step;
  final int sent, total;
  final bool withVideo;

  String _mb(int b) => (b / (1024 * 1024)).toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    final uploading = step == _SendStep.upload && total > 0;
    final fraction = uploading ? sent / total : null;
    final done = step == _SendStep.done;
    final steps = [
      ('Preparando envío', _SendStep.prepare),
      if (withVideo) ('Subiendo video', _SendStep.upload),
      ('Guardando resultados', _SendStep.save),
    ];
    return ColoredBox(
      color: MedColors.background.withValues(alpha: .97),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 140,
                height: 140,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 450),
                  transitionBuilder: (child, a) => ScaleTransition(
                    scale: CurvedAnimation(
                      parent: a,
                      curve: Curves.easeOutBack,
                    ),
                    child: child,
                  ),
                  child: done
                      ? Container(
                          key: const ValueKey('done'),
                          decoration: const BoxDecoration(
                            color: MedColors.secondary,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check_rounded,
                            color: Colors.white,
                            size: 84,
                          ),
                        )
                      : Stack(
                          key: const ValueKey('progress'),
                          alignment: Alignment.center,
                          children: [
                            SizedBox.expand(
                              child: fraction == null
                                  ? CircularProgressIndicator(
                                      strokeWidth: 10,
                                      strokeCap: StrokeCap.round,
                                      backgroundColor: MedColors.secondary
                                          .withValues(alpha: .2),
                                      color: MedColors.primary,
                                    )
                                  : TweenAnimationBuilder<double>(
                                      tween: Tween(end: fraction),
                                      duration: const Duration(
                                        milliseconds: 300,
                                      ),
                                      builder: (_, v, _) =>
                                          CircularProgressIndicator(
                                            value: v,
                                            strokeWidth: 10,
                                            strokeCap: StrokeCap.round,
                                            backgroundColor: MedColors.secondary
                                                .withValues(alpha: .2),
                                            color: MedColors.primary,
                                          ),
                                    ),
                            ),
                            if (fraction != null)
                              Text(
                                '${(fraction * 100).round()}%',
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineSmall,
                              )
                            else
                              const Icon(
                                Icons.cloud_upload_outlined,
                                size: 44,
                                color: MedColors.primary,
                              ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 28),
              Text(
                done ? '¡Enviado!' : 'Enviando a tu fisioterapeuta',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                done
                    ? 'Tu fisioterapeuta ya puede revisarlo.'
                    : uploading
                    ? '${_mb(sent)} de ${_mb(total)} MB · no cierres la app'
                    : 'Esto puede tardar unos segundos',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF526C79)),
              ),
              const SizedBox(height: 24),
              for (final (label, s) in steps)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 24,
                        height: 24,
                        child: done || s.index < step.index
                            ? const Icon(
                                Icons.check_circle,
                                color: MedColors.secondary,
                              )
                            : s == step
                            ? const Padding(
                                padding: EdgeInsets.all(3),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                ),
                              )
                            : const Icon(
                                Icons.radio_button_unchecked,
                                color: Colors.black26,
                              ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(width: 190, child: Text(label)),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Plays a private exercise video through a 60-second signed URL.
class EvidenceVideo extends StatefulWidget {
  const EvidenceVideo({
    super.key,
    required this.repository,
    required this.path,
  });
  final CareRepository repository;
  final String path;
  @override
  State<EvidenceVideo> createState() => _EvidenceVideoState();
}

class _EvidenceVideoState extends State<EvidenceVideo> {
  VideoPlayerController? video;
  bool loading = false;
  String? error;

  Future<void> load() async {
    setState(() => loading = true);
    try {
      final url = await widget.repository.evidenceUrl(widget.path);
      final v = VideoPlayerController.networkUrl(Uri.parse(url));
      await v.initialize();
      await v.play();
      if (!mounted) {
        await v.dispose();
        return;
      }
      setState(() => video = v);
    } catch (e) {
      if (mounted) setState(() => error = 'Video no disponible.');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  void dispose() {
    video?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final v = video;
    if (error != null) return Text(error!);
    if (v == null) {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: OutlinedButton.icon(
          onPressed: loading ? null : load,
          icon: loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.play_circle_outline),
          label: Text(loading ? 'Cargando…' : 'Ver video del ejercicio'),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: AspectRatio(
        aspectRatio: v.value.aspectRatio,
        child: GestureDetector(
          onTap: () => setState(() => v.value.isPlaying ? v.pause() : v.play()),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: VideoPlayer(v),
          ),
        ),
      ),
    );
  }
}

/// Exercise metrics card used in the patient history.
class MetricsCard extends StatelessWidget {
  const MetricsCard(this.metrics, {super.key});
  final Map<String, dynamic> metrics;
  @override
  Widget build(BuildContext context) {
    final ok = metrics['pattern_ok'] == true;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: (ok ? MedColors.secondary : Colors.orange).withValues(
          alpha: .15,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [for (final line in describeMetrics(metrics)) Text(line)],
      ),
    );
  }
}
