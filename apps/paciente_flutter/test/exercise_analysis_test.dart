import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:med_box/exercise_analysis.dart';

/// Point at distance [d] from [o], rotated [deg] from direction [dir].
Landmark rot(
  Landmark o,
  (double, double) dir,
  double deg,
  double d, {
  double z = 0,
}) {
  final r = deg * math.pi / 180;
  final x = dir.$1 * math.cos(r) - dir.$2 * math.sin(r);
  final y = dir.$1 * math.sin(r) + dir.$2 * math.cos(r);
  return Landmark(o.x + x * d, o.y + y * d, z: z);
}

List<Landmark> blank({double leftZ = 0, double rightZ = 0}) =>
    List.generate(33, (i) => Landmark(0.5, 0.5, z: i.isOdd ? leftZ : rightZ));

/// Front view, elbow angle [deg] on both arms (curl).
List<Landmark> curl(double deg) {
  final lm = blank();
  for (final (s, e, w, sx) in [
    (Lm.leftShoulder, Lm.leftElbow, Lm.leftWrist, 0.6),
    (Lm.rightShoulder, Lm.rightElbow, Lm.rightWrist, 0.4),
  ]) {
    final shoulder = Landmark(sx, 0.3);
    final elbow = Landmark(sx, 0.5);
    lm[s] = shoulder;
    lm[e] = elbow;
    lm[w] = rot(elbow, (0, -1), deg, 0.2);
  }
  return lm;
}

/// Side view (shoulders at different depth) with knee and hip angles.
List<Landmark> squat(double knee, double hip) {
  final lm = blank(leftZ: 0, rightZ: 0.4);
  lm[Lm.leftShoulder] = const Landmark(0.5, 0.3, z: 0);
  lm[Lm.rightShoulder] = const Landmark(0.5, 0.3, z: 0.4);
  for (final (h, k, a, s) in [
    (Lm.leftHip, Lm.leftKnee, Lm.leftAnkle, Lm.leftShoulder),
    (Lm.rightHip, Lm.rightKnee, Lm.rightAnkle, Lm.rightShoulder),
  ]) {
    const kneePt = Landmark(0.5, 0.7);
    lm[k] = kneePt;
    lm[a] = const Landmark(0.5, 0.9);
    final hipPt = rot(kneePt, (0, 1), knee, 0.2);
    lm[h] = hipPt;
    final toKnee = ((kneePt.x - hipPt.x) / 0.2, (kneePt.y - hipPt.y) / 0.2);
    final sh = rot(hipPt, toKnee, hip, 0.25, z: lm[s].z);
    lm[s] = sh;
  }
  return lm;
}

void feed(
  ExerciseAnalyzer a,
  List<double> angles,
  List<Landmark> Function(double) make, {
  double dt = 0.1,
  double start = 0,
}) {
  var t = start;
  for (final ang in angles) {
    a.process(make(ang), t);
    t += dt;
  }
}

List<double> sweep(double from, double to, int steps) =>
    List.generate(steps + 1, (i) => from + (to - from) * i / steps);

void main() {
  test('angleDeg computes joint angles', () {
    expect(
      angleDeg(
        const Landmark(0, 1),
        const Landmark(0, 0),
        const Landmark(1, 0),
      ),
      closeTo(90, 0.01),
    );
    expect(
      angleDeg(
        const Landmark(-1, 0),
        const Landmark(0, 0),
        const Landmark(1, 0),
      ),
      closeTo(180, 0.01),
    );
  });

  test('Bicep curl counts full repetitions and flags an incomplete one', () {
    final a = ExerciseAnalyzer(ExerciseType.bicepCurl, targetReps: 3);
    final pattern = [
      ...sweep(170, 30, 15), ...sweep(30, 170, 15), // rep 1 (3 s)
      ...sweep(170, 100, 8), ...sweep(100, 170, 8), // partial
      ...sweep(170, 30, 15), ...sweep(30, 170, 15), // rep 2
      ...sweep(170, 30, 15), ...sweep(30, 170, 15), // rep 3
    ];
    feed(a, pattern, curl);
    final s = a.summary(10);
    expect(s['complete_reps'], 3);
    expect(s['incomplete_reps'], 1);
    expect(s['fast_reps'], 0);
    expect(
      s['pattern_ok'],
      isFalse,
      reason: '1 de 4 intentos incompleto (<80%)',
    );
    expect((s['avg_peak_angle_deg'] as double), lessThan(45));
  });

  test('Fast repetitions are counted but reported', () {
    final a = ExerciseAnalyzer(ExerciseType.bicepCurl, targetReps: 2);
    feed(a, [
      ...sweep(170, 30, 3),
      ...sweep(30, 170, 3),
      ...sweep(170, 30, 3),
      ...sweep(30, 170, 3),
    ], curl);
    final s = a.summary(2);
    expect(s['complete_reps'], 2);
    expect(s['fast_reps'], 2);
    expect(s['pattern_ok'], isFalse);
  });

  test('Front exercise rejects side view and missing pose', () {
    final a = ExerciseAnalyzer(ExerciseType.bicepCurl);
    expect(
      a.process(squat(170, 170), 0).message,
      'Ponte de frente a la cámara',
    );
    expect(a.process(null, 0.1).message, contains('cuerpo completo'));
    expect(a.summary(1)['tracked_ratio'], 0.0);
  });

  test('Squat requires depth; shallow squat is incomplete', () {
    final a = ExerciseAnalyzer(ExerciseType.squat, targetReps: 2);
    List<Landmark> make(double k) => squat(k, k);
    feed(a, [
      ...sweep(175, 85, 15), ...sweep(85, 175, 15), // full
      ...sweep(175, 125, 10), ...sweep(125, 175, 10), // shallow
      ...sweep(175, 85, 15), ...sweep(85, 175, 15), // full
    ], make);
    final s = a.summary(8);
    expect(s['complete_reps'], 2);
    expect(s['incomplete_reps'], 1);
  });

  test('Clean session yields adequate pattern', () {
    final a = ExerciseAnalyzer(ExerciseType.kneeLift, targetReps: 2);
    List<Landmark> make(double k) => squat(k, 170);
    feed(a, [
      ...sweep(175, 80, 15),
      ...sweep(80, 175, 15),
      ...sweep(175, 80, 15),
      ...sweep(80, 175, 15),
    ], make);
    final s = a.summary(6);
    expect(s['complete_reps'], 2);
    expect(s['pattern_ok'], isTrue);
    expect(describeMetrics(s).last, contains('adecuado'));
  });
}
