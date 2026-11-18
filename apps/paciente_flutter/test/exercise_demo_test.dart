import 'package:flutter_test/flutter_test.dart';
import 'package:med_box/exercise_analysis.dart';
import 'package:med_box/exercise_demo.dart';

void main() {
  double knee(List<Landmark> lm) =>
      angleDeg(lm[Lm.leftHip], lm[Lm.leftKnee], lm[Lm.leftAnkle]);
  double elbow(List<Landmark> lm) =>
      angleDeg(lm[Lm.leftShoulder], lm[Lm.leftElbow], lm[Lm.leftWrist]);

  test('Demo animations reach the thresholds the analyzer expects', () {
    // Squat: standing > 150°, bottom < 100°.
    expect(knee(demoPose(ExerciseType.squat, 0)), greaterThan(150));
    expect(knee(demoPose(ExerciseType.squat, 1)), lessThan(100));
    // Knee lift: straight > 150°, lifted < 95°.
    expect(knee(demoPose(ExerciseType.kneeLift, 0)), greaterThan(150));
    expect(knee(demoPose(ExerciseType.kneeLift, 1)), lessThan(95));
    // Quadriceps stretch: folded < 60° with ankle above knee.
    final q = demoPose(ExerciseType.quadricepsStretch, 1);
    expect(knee(q), lessThan(60));
    expect(q[Lm.leftAnkle].y, lessThan(q[Lm.leftKnee].y));
    // Bicep curl: extended > 140°, flexed < 45°.
    expect(elbow(demoPose(ExerciseType.bicepCurl, 0)), greaterThan(140));
    expect(elbow(demoPose(ExerciseType.bicepCurl, 1)), lessThan(45));
    // Shoulder raise: wrists go from below to above the shoulders.
    final down = demoPose(ExerciseType.shoulderRaise, 0);
    final up = demoPose(ExerciseType.shoulderRaise, 1);
    expect(down[Lm.leftWrist].y, greaterThan(down[Lm.leftShoulder].y));
    expect(up[Lm.leftWrist].y, lessThan(up[Lm.leftShoulder].y));
  });
}
