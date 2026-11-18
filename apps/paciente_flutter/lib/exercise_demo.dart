import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import 'data.dart';
import 'exercise_analysis.dart';
import 'exercise_capture.dart';
import 'screens.dart';
import 'theme.dart';

double _rad(double deg) => deg * math.pi / 180;

/// Synthetic body pose for the animated demonstration. [p] goes 0→1→0 per repetition.
List<Landmark> demoPose(ExerciseType type, double p) {
  final lm = List<Landmark>.filled(33, const Landmark(0.5, 0.5));
  void put(int i, double x, double y) => lm[i] = Landmark(x, y);
  void pair(int l, int r, double x, double y, {double dx = 0}) {
    put(l, x + dx, y);
    put(r, x - dx, y);
  }

  switch (type) {
    case ExerciseType.squat:
      // Side view: knee angle 175° → 85°.
      final half = (180 - (175 - 90 * p)) / 2;
      const ankle = Offset(0.5, 0.92);
      final knee =
          ankle + Offset(math.sin(_rad(half)) * .2, -math.cos(_rad(half)) * .2);
      final hip =
          knee + Offset(-math.sin(_rad(half)) * .2, -math.cos(_rad(half)) * .2);
      final lean = half * .7;
      final shoulder =
          hip + Offset(math.sin(_rad(lean)) * .27, -math.cos(_rad(lean)) * .27);
      pair(Lm.leftAnkle, Lm.rightAnkle, ankle.dx, ankle.dy);
      pair(Lm.leftKnee, Lm.rightKnee, knee.dx, knee.dy);
      pair(Lm.leftHip, Lm.rightHip, hip.dx, hip.dy);
      pair(Lm.leftShoulder, Lm.rightShoulder, shoulder.dx, shoulder.dy);
      final reach = .1 + .1 * p;
      pair(
        Lm.leftElbow,
        Lm.rightElbow,
        shoulder.dx + reach * .6,
        shoulder.dy + .08,
      );
      pair(
        Lm.leftWrist,
        Lm.rightWrist,
        shoulder.dx + reach * 1.4,
        shoulder.dy + .1 - .06 * p,
      );
      put(0, shoulder.dx + .02, shoulder.dy - .09);
    case ExerciseType.kneeLift:
    case ExerciseType.quadricepsStretch:
      // Side view, standing; one leg moves.
      const hip = Offset(.5, .5), shoulder = Offset(.5, .24);
      pair(Lm.leftHip, Lm.rightHip, hip.dx, hip.dy);
      pair(Lm.leftShoulder, Lm.rightShoulder, shoulder.dx, shoulder.dy);
      put(0, .51, .15);
      put(Lm.rightKnee, .5, .71);
      put(Lm.rightAnkle, .5, .92);
      if (type == ExerciseType.kneeLift) {
        final a = _rad(100 * p);
        final knee = hip + Offset(math.sin(a) * .21, math.cos(a) * .21);
        put(Lm.leftKnee, knee.dx, knee.dy);
        put(Lm.leftAnkle, knee.dx, knee.dy + .21);
        pair(Lm.leftElbow, Lm.rightElbow, .5, .38);
        pair(Lm.leftWrist, Lm.rightWrist, .53, .5);
      } else {
        const knee = Offset(.5, .71);
        final a = _rad(150 * p);
        final ankle = knee + Offset(-math.sin(a) * .21, math.cos(a) * .21);
        put(Lm.leftKnee, knee.dx, knee.dy);
        put(Lm.leftAnkle, ankle.dx, ankle.dy);
        put(Lm.leftElbow, .47, .38);
        put(Lm.leftWrist, .5 + (ankle.dx - .5) * p, .5 + (ankle.dy - .5) * p);
        put(Lm.rightElbow, .58, .3);
        put(Lm.rightWrist, .66, .26);
      }
    case ExerciseType.bicepCurl:
      // Front view: forearms 0° → 140°.
      pair(Lm.leftShoulder, Lm.rightShoulder, .5, .25, dx: .1);
      pair(Lm.leftHip, Lm.rightHip, .5, .52, dx: .07);
      pair(Lm.leftKnee, Lm.rightKnee, .5, .72, dx: .07);
      pair(Lm.leftAnkle, Lm.rightAnkle, .5, .92, dx: .07);
      pair(Lm.leftElbow, Lm.rightElbow, .5, .4, dx: .11);
      final a = _rad(140 * p);
      final wy = .4 + math.cos(a) * .15;
      pair(Lm.leftWrist, Lm.rightWrist, .5, wy, dx: .11 + math.sin(a) * .02);
      put(0, .5, .14);
    case ExerciseType.shoulderRaise:
      // Front view: abduction 15° → 170°.
      pair(Lm.leftShoulder, Lm.rightShoulder, .5, .27, dx: .1);
      pair(Lm.leftHip, Lm.rightHip, .5, .52, dx: .07);
      pair(Lm.leftKnee, Lm.rightKnee, .5, .72, dx: .07);
      pair(Lm.leftAnkle, Lm.rightAnkle, .5, .92, dx: .07);
      final a = _rad(15 + 155 * p);
      pair(
        Lm.leftElbow,
        Lm.rightElbow,
        .5,
        .27 + math.cos(a) * .14,
        dx: .1 + math.sin(a) * .14,
      );
      pair(
        Lm.leftWrist,
        Lm.rightWrist,
        .5,
        .27 + math.cos(a) * .28,
        dx: .1 + math.sin(a) * .28,
      );
      put(0, .5, .16);
  }
  return lm;
}

/// Looping animated figure that performs the exercise.
class ExerciseAnimation extends StatefulWidget {
  const ExerciseAnimation(this.type, {super.key});
  final ExerciseType type;
  @override
  State<ExerciseAnimation> createState() => _ExerciseAnimationState();
}

class _ExerciseAnimationState extends State<ExerciseAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  )..repeat();

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Animación de ${widget.type.label}',
    child: AnimatedBuilder(
      animation: c,
      builder: (context, _) {
        // Ease in-out, pause briefly at both ends.
        final t = c.value;
        final p = Curves.easeInOut.transform(
          (t < .5 ? t * 2 : (1 - t) * 2).clamp(0.0, 1.0),
        );
        return CustomPaint(
          painter: _FigurePainter(demoPose(widget.type, p)),
          size: Size.infinite,
        );
      },
    ),
  );
}

class _FigurePainter extends CustomPainter {
  _FigurePainter(this.lm);
  final List<Landmark> lm;
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
    final s = math.min(size.width, size.height);
    final ox = (size.width - s) / 2, oy = (size.height - s) / 2;
    Offset at(Landmark p) => Offset(ox + p.x * s, oy + p.y * s);
    canvas.drawLine(
      Offset(ox + s * .2, oy + s * .935),
      Offset(ox + s * .8, oy + s * .935),
      Paint()
        ..color = MedColors.primary.withValues(alpha: .15)
        ..strokeWidth = 3,
    );
    final bone = Paint()
      ..color = MedColors.primary
      ..strokeWidth = s * .035
      ..strokeCap = StrokeCap.round;
    for (final (a, b) in _bones) {
      canvas.drawLine(at(lm[a]), at(lm[b]), bone);
    }
    final joint = Paint()..color = MedColors.secondary;
    for (final i in [13, 14, 25, 26]) {
      canvas.drawCircle(at(lm[i]), s * .022, joint);
    }
    canvas.drawCircle(at(lm[0]), s * .055, Paint()..color = MedColors.primary);
  }

  @override
  bool shouldRepaint(_FigurePainter old) => true;
}

/// Shown before recording: how to do the exercise and where to place the phone.
class ExerciseDemoScreen extends StatefulWidget {
  const ExerciseDemoScreen({
    super.key,
    required this.session,
    required this.activity,
    required this.repository,
  });
  final CareSession session;
  final CareActivity activity;
  final CareRepository repository;
  @override
  State<ExerciseDemoScreen> createState() => _ExerciseDemoScreenState();
}

class _ExerciseDemoScreenState extends State<ExerciseDemoScreen> {
  VideoPlayerController? video;
  bool showVideo = false, loadingVideo = false;
  String? videoError;

  CareActivity get a => widget.activity;

  @override
  void initState() {
    super.initState();
    if (a.hasDemoVideo && !widget.repository.demo) {
      showVideo = true;
      _loadVideo();
    }
  }

  Future<void> _loadVideo() async {
    setState(() => loadingVideo = true);
    try {
      final url = await widget.repository.demoVideoUrl(a);
      final v = VideoPlayerController.networkUrl(Uri.parse(url));
      await v.initialize();
      await v.setLooping(true);
      await v.play();
      if (!mounted) {
        await v.dispose();
        return;
      }
      setState(() => video = v);
    } catch (_) {
      if (mounted) setState(() => videoError = 'No se pudo cargar el video.');
    } finally {
      if (mounted) setState(() => loadingVideo = false);
    }
  }

  @override
  void dispose() {
    video?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final type = a.exercise;
    final front = (a.cameraView ?? type?.view.name) == 'front';
    return Scaffold(
      appBar: AppBar(title: const Text('Antes de empezar')),
      body: PageBody(
        children: [
          Text(a.title, style: Theme.of(context).textTheme.headlineSmall),
          if (a.targetReps != null)
            Text(
              'Meta: ${a.targetSets ?? 1} × ${a.targetReps} repeticiones',
              style: const TextStyle(color: Color(0xFF526C79)),
            ),
          const SizedBox(height: 16),
          if (type != null && a.hasDemoVideo && !widget.repository.demo)
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, label: Text('Video del fisio')),
                ButtonSegment(value: false, label: Text('Animación')),
              ],
              selected: {showVideo},
              onSelectionChanged: (v) => setState(() => showVideo = v.first),
            ),
          const SizedBox(height: 12),
          Container(
            height: 320,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
            ),
            clipBehavior: Clip.antiAlias,
            child: showVideo
                ? (video != null
                      ? GestureDetector(
                          onTap: () => setState(
                            () => video!.value.isPlaying
                                ? video!.pause()
                                : video!.play(),
                          ),
                          child: Center(
                            child: AspectRatio(
                              aspectRatio: video!.value.aspectRatio,
                              child: VideoPlayer(video!),
                            ),
                          ),
                        )
                      : Center(
                          child: loadingVideo
                              ? const CircularProgressIndicator()
                              : Text(videoError ?? ''),
                        ))
                : type != null
                ? Padding(
                    padding: const EdgeInsets.all(16),
                    child: ExerciseAnimation(type),
                  )
                : const Center(child: Text('Sin demostración disponible')),
          ),
          const SectionTitle('Cómo hacerlo'),
          Text(a.instructions),
          const SectionTitle('Prepara la grabación'),
          for (final (icon, text) in [
            (
              Icons.stay_current_portrait,
              'Apoya el teléfono vertical a la altura de la cadera, a unos 2 metros.',
            ),
            (
              front ? Icons.person_outline : Icons.directions_walk,
              front
                  ? 'Colócate de frente a la cámara.'
                  : 'Colócate de lado a la cámara.',
            ),
            (
              Icons.fullscreen,
              'Que se vea tu cuerpo completo, de la cabeza a los pies.',
            ),
            (
              Icons.wb_sunny_outlined,
              'Busca buena luz y un espacio despejado.',
            ),
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Icon(icon, color: MedColors.primary),
                  const SizedBox(width: 12),
                  Expanded(child: Text(text)),
                ],
              ),
            ),
          if (type == null)
            const Text(
              'Este ejercicio se envía como video para que tu fisioterapeuta lo revise; no tiene conteo automático.',
              style: TextStyle(fontSize: 13, color: Color(0xFF526C79)),
            ),
          const SizedBox(height: 20),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(54),
            ),
            onPressed: () async {
              video?.pause();
              final saved = await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                  builder: (_) => ExerciseCaptureScreen(
                    session: widget.session,
                    activity: a,
                    repository: widget.repository,
                  ),
                ),
              );
              if (saved == true && context.mounted) {
                Navigator.pop(context, true);
              }
            },
            icon: const Icon(Icons.videocam_outlined),
            label: const Text('Estoy listo, grabar'),
          ),
        ],
      ),
    );
  }
}
