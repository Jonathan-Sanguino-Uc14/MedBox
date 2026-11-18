// Exercise pattern analysis from 33-point body landmarks (BlazePose / ML Kit order).
//
// Rep detection thresholds, alignment checks and state machines are ported from
// PhysioBuddy `backend/physioapp/consumers.py` (MIT License, (c) 2026 Onkar Gite,
// https://github.com/onkar0127/PhysioBuddy). Med Box adaptations: the most
// visible body side is used instead of a fixed side, incomplete repetitions,
// range of motion, tempo and alignment are measured, and feedback is in Spanish.
// Output is an automatic estimate for the physiotherapist to review, not a diagnosis.
import 'dart:math' as math;

/// Landmark indices (same order as MediaPipe BlazePose and ML Kit PoseLandmarkType).
abstract final class Lm {
  static const leftShoulder = 11, rightShoulder = 12;
  static const leftElbow = 13, rightElbow = 14;
  static const leftWrist = 15, rightWrist = 16;
  static const leftHip = 23, rightHip = 24;
  static const leftKnee = 25, rightKnee = 26;
  static const leftAnkle = 27, rightAnkle = 28;
}

/// Normalized landmark: x, y in 0..1 of the image, z scaled by image width.
class Landmark {
  const Landmark(this.x, this.y, {this.z = 0, this.visibility = 1});
  final double x, y, z, visibility;
}

enum CameraView { front, side }

enum ExerciseType {
  bicepCurl('bicep_curl', 'Flexión de codo', CameraView.front),
  quadricepsStretch(
    'quadriceps_stretch',
    'Estiramiento de cuádriceps',
    CameraView.side,
  ),
  shoulderRaise('shoulder_raise', 'Elevación de brazos', CameraView.front),
  squat('squat', 'Sentadilla', CameraView.side),
  kneeLift('knee_lift', 'Elevación de rodilla', CameraView.side);

  const ExerciseType(this.code, this.label, this.view);
  final String code, label;
  final CameraView view;
  static ExerciseType? fromCode(String? code) {
    for (final e in values) {
      if (e.code == code) return e;
    }
    return null;
  }
}

double angleDeg(Landmark a, Landmark b, Landmark c) {
  final abx = a.x - b.x, aby = a.y - b.y, cbx = c.x - b.x, cby = c.y - b.y;
  final mab = math.sqrt(abx * abx + aby * aby);
  final mcb = math.sqrt(cbx * cbx + cby * cby);
  if (mab == 0 || mcb == 0) return 0;
  final r = ((abx * cbx + aby * cby) / (mab * mcb)).clamp(-1.0, 1.0);
  return math.acos(r) * 180 / math.pi;
}

class RepRecord {
  const RepRecord(this.peakAngle, this.seconds, {required this.complete});
  final double peakAngle, seconds;
  final bool complete;
}

class FrameFeedback {
  const FrameFeedback(this.reps, this.message, {this.angle});
  final int reps;
  final String? message;
  final double? angle;
}

/// Stateful per-exercise analyzer. Feed frames in order with a timestamp.
class ExerciseAnalyzer {
  ExerciseAnalyzer(this.type, {this.targetReps = 10});
  final ExerciseType type;
  final int targetReps;

  final List<RepRecord> reps = [];
  int framesTotal = 0, framesNoPose = 0, framesMisaligned = 0;

  // PhysioBuddy state machine flags.
  bool _ready = false, _folded = false;
  // Shoulder raise 3-phase flags.
  bool _armsDown = false, _armsRaised = false;
  // Extra tracking for metrics.
  double? _repStart;
  double? _peak;
  double? _restAngle;

  int get completeReps => reps.where((r) => r.complete).length;
  int get incompleteReps => reps.where((r) => !r.complete).length;

  static const _minVisibility = 0.5;
  static const _fastRepSeconds = 1.0;

  bool _facingFront(List<Landmark> lm) =>
      (lm[Lm.leftShoulder].z - lm[Lm.rightShoulder].z).abs() < 0.15;

  bool _visible(List<Landmark> lm, List<int> idx) =>
      idx.every((i) => lm[i].visibility >= _minVisibility);

  /// Picks the side (left/right) whose joints are more visible.
  List<int> _side(List<Landmark> lm, List<int> left, List<int> right) {
    double score(List<int> s) => s.fold(0.0, (a, i) => a + lm[i].visibility);
    return score(left) >= score(right) ? left : right;
  }

  FrameFeedback process(List<Landmark>? lm, double tSeconds) {
    framesTotal++;
    if (lm == null || lm.length < 33) {
      framesNoPose++;
      return FrameFeedback(
        completeReps,
        'Colócate de cuerpo completo frente a la cámara',
      );
    }
    if (type.view == CameraView.front && !_facingFront(lm)) {
      framesMisaligned++;
      return FrameFeedback(completeReps, 'Ponte de frente a la cámara');
    }
    if (type.view == CameraView.side && _facingFront(lm)) {
      framesMisaligned++;
      return FrameFeedback(completeReps, 'Ponte de lado a la cámara');
    }
    return switch (type) {
      ExerciseType.bicepCurl => _flexion(
        lm,
        tSeconds,
        left: const [Lm.leftShoulder, Lm.leftElbow, Lm.leftWrist],
        right: const [Lm.rightShoulder, Lm.rightElbow, Lm.rightWrist],
        upper: 140,
        lower: 45,
        hint: 'Dobla más el codo',
      ),
      ExerciseType.quadricepsStretch => _flexion(
        lm,
        tSeconds,
        left: const [Lm.leftHip, Lm.leftKnee, Lm.leftAnkle],
        right: const [Lm.rightHip, Lm.rightKnee, Lm.rightAnkle],
        upper: 150,
        lower: 60,
        hint: 'Lleva el talón más cerca del glúteo',
        extraFolded: (s) => lm[s[2]].y < lm[s[1]].y,
      ),
      ExerciseType.kneeLift => _flexion(
        lm,
        tSeconds,
        left: const [Lm.leftHip, Lm.leftKnee, Lm.leftAnkle],
        right: const [Lm.rightHip, Lm.rightKnee, Lm.rightAnkle],
        upper: 150,
        lower: 95,
        hint: 'Sube más la rodilla',
      ),
      ExerciseType.squat => _squat(lm, tSeconds),
      ExerciseType.shoulderRaise => _shoulder(lm, tSeconds),
    };
  }

  void _trackPeak(double angle, {bool lowerIsDeeper = true}) {
    _peak = _peak == null
        ? angle
        : (lowerIsDeeper ? math.min(_peak!, angle) : math.max(_peak!, angle));
  }

  void _closeRep(double t, {required bool complete}) {
    reps.add(
      RepRecord(
        _peak ?? 0,
        _repStart == null ? 0 : t - _repStart!,
        complete: complete,
      ),
    );
    _repStart = null;
    _peak = null;
  }

  String? _tempoMessage() {
    if (reps.isEmpty) return null;
    final last = reps.last;
    if (last.complete && last.seconds > 0 && last.seconds < _fastRepSeconds) {
      return 'Más despacio, controla el movimiento';
    }
    return last.complete ? '¡Bien!' : null;
  }

  /// Generic flexion pattern (bicep curl, quadriceps stretch, knee lift):
  /// extended (> upper) -> flexed (< lower) -> extended counts one repetition.
  FrameFeedback _flexion(
    List<Landmark> lm,
    double t, {
    required List<int> left,
    required List<int> right,
    required double upper,
    required double lower,
    required String hint,
    bool Function(List<int> side)? extraFolded,
  }) {
    final s = _side(lm, left, right);
    if (!_visible(lm, s)) {
      framesNoPose++;
      return FrameFeedback(
        completeReps,
        'No veo bien la articulación; ajusta la cámara',
      );
    }
    final angle = angleDeg(lm[s[0]], lm[s[1]], lm[s[2]]);
    String? message;
    final folded = angle < lower && (extraFolded?.call(s) ?? true);
    if (completeReps >= targetReps) {
      return FrameFeedback(completeReps, '¡Meta alcanzada!', angle: angle);
    }
    if (angle > upper && !_ready) {
      _ready = true;
      _folded = false;
      _restAngle = angle;
    } else if (_ready && !_folded) {
      if (angle < upper) {
        _repStart ??= t;
        _trackPeak(angle);
      }
      if (folded) {
        _folded = true;
      } else if (angle < upper - 25) {
        message = hint;
      } else if (angle > upper && _repStart != null) {
        // Back to extension without reaching the target: incomplete if it was a real attempt.
        if (_peak != null && _peak! < upper - 25) {
          _closeRep(t, complete: false);
          message = hint;
        } else {
          _repStart = null;
          _peak = null;
        }
      }
    } else if (_ready && _folded) {
      _trackPeak(angle);
      if (angle > upper) {
        _closeRep(t, complete: true);
        _ready = true; // already extended, ready for next one
        _folded = false;
        message = _tempoMessage();
      }
    }
    return FrameFeedback(completeReps, message, angle: angle);
  }

  /// Squat: knee (hip-knee-ankle) and hip (knee-hip-shoulder) angles.
  FrameFeedback _squat(List<Landmark> lm, double t) {
    final s = _side(
      lm,
      const [Lm.leftHip, Lm.leftKnee, Lm.leftAnkle, Lm.leftShoulder],
      const [Lm.rightHip, Lm.rightKnee, Lm.rightAnkle, Lm.rightShoulder],
    );
    if (!_visible(lm, s)) {
      framesNoPose++;
      return FrameFeedback(
        completeReps,
        'Necesito ver cadera, rodilla y tobillo',
      );
    }
    final knee = angleDeg(lm[s[0]], lm[s[1]], lm[s[2]]);
    final hip = angleDeg(lm[s[1]], lm[s[0]], lm[s[3]]);
    const upper = 150.0, kneeDown = 100.0, hipDown = 100.0;
    final standing = knee > upper && hip > upper;
    final down = knee < kneeDown && hip < hipDown;
    String? message;
    if (completeReps >= targetReps) {
      return FrameFeedback(completeReps, '¡Meta alcanzada!', angle: knee);
    }
    if (standing && !_ready) {
      _ready = true;
      _folded = false;
    } else if (_ready && !_folded) {
      if (knee < upper) {
        _repStart ??= t;
        _trackPeak(knee);
      }
      if (down) {
        _folded = true;
      } else if (knee < upper - 20) {
        message = 'Baja un poco más la cadera';
      } else if (standing && _repStart != null) {
        if (_peak != null && _peak! < upper - 20) {
          _closeRep(t, complete: false);
          message = 'Baja un poco más la cadera';
        } else {
          _repStart = null;
          _peak = null;
        }
      }
    } else if (_ready && _folded) {
      _trackPeak(knee);
      if (hip < 60) message = 'Mantén el pecho más erguido';
      if (standing) {
        _closeRep(t, complete: true);
        _folded = false;
        message = _tempoMessage();
      }
    }
    return FrameFeedback(completeReps, message, angle: knee);
  }

  /// Shoulder raise: arms straight (> 160) and wrists below -> above -> below shoulders.
  FrameFeedback _shoulder(List<Landmark> lm, double t) {
    const idx = [
      Lm.leftShoulder,
      Lm.leftElbow,
      Lm.leftWrist,
      Lm.rightShoulder,
      Lm.rightElbow,
      Lm.rightWrist,
      Lm.leftHip,
      Lm.rightHip,
    ];
    if (!_visible(lm, idx)) {
      framesNoPose++;
      return FrameFeedback(completeReps, 'Necesito ver ambos brazos completos');
    }
    final l = angleDeg(lm[Lm.leftShoulder], lm[Lm.leftElbow], lm[Lm.leftWrist]);
    final r = angleDeg(
      lm[Lm.rightShoulder],
      lm[Lm.rightElbow],
      lm[Lm.rightWrist],
    );
    // Abduction angle (hip-shoulder-elbow) as range-of-motion metric.
    final abd = math.min(
      angleDeg(lm[Lm.leftHip], lm[Lm.leftShoulder], lm[Lm.leftElbow]),
      angleDeg(lm[Lm.rightHip], lm[Lm.rightShoulder], lm[Lm.rightElbow]),
    );
    if (completeReps >= targetReps) {
      return FrameFeedback(completeReps, '¡Meta alcanzada!', angle: abd);
    }
    if (l <= 160 || r <= 160) {
      return FrameFeedback(
        completeReps,
        'Mantén los brazos estirados',
        angle: abd,
      );
    }
    final up =
        lm[Lm.leftWrist].y < lm[Lm.leftShoulder].y &&
        lm[Lm.rightWrist].y < lm[Lm.rightShoulder].y;
    final down =
        lm[Lm.leftWrist].y > lm[Lm.leftShoulder].y &&
        lm[Lm.rightWrist].y > lm[Lm.rightShoulder].y;
    String? message;
    if (down && !_armsRaised) {
      if (_repStart != null && _peak != null && _peak! > 60) {
        _closeRep(t, complete: false);
        message = 'Sube los brazos por encima de la cabeza';
      }
      _armsDown = true;
      _repStart = null;
      _peak = null;
    } else if (_armsDown && !_armsRaised) {
      _repStart ??= t;
      _trackPeak(abd, lowerIsDeeper: false);
      if (up) {
        _armsRaised = true;
        _armsDown = false;
      }
    } else if (_armsRaised) {
      _trackPeak(abd, lowerIsDeeper: false);
      if (down) {
        _closeRep(t, complete: true);
        _armsRaised = false;
        _armsDown = true;
        message = _tempoMessage();
      }
    }
    return FrameFeedback(completeReps, message, angle: abd);
  }

  /// Summary sent to the physiotherapist with the recording.
  Map<String, dynamic> summary(double durationSeconds) {
    final complete = reps.where((r) => r.complete).toList();
    final fast = complete
        .where((r) => r.seconds > 0 && r.seconds < _fastRepSeconds)
        .length;
    final analysed = framesTotal == 0
        ? 0.0
        : 1 - (framesNoPose + framesMisaligned) / framesTotal;
    final attempted = reps.length;
    final ratio = attempted == 0 ? 0.0 : complete.length / attempted;
    final patternOk =
        complete.length >= targetReps &&
        ratio >= 0.8 &&
        fast <= (complete.length * 0.2) &&
        analysed >= 0.6;
    double? avg(Iterable<double> v) =>
        v.isEmpty ? null : v.reduce((a, b) => a + b) / v.length;
    double? round1(double? v) => v == null ? null : (v * 10).round() / 10;
    return {
      'version': 1,
      'exercise': type.code,
      'target_reps': targetReps,
      'complete_reps': complete.length,
      'incomplete_reps': attempted - complete.length,
      'fast_reps': fast,
      'avg_peak_angle_deg': round1(avg(complete.map((r) => r.peakAngle))),
      'avg_rep_seconds': round1(avg(complete.map((r) => r.seconds))),
      'rest_angle_deg': round1(_restAngle),
      'tracked_ratio': round1(analysed * 100),
      'duration_seconds': round1(durationSeconds),
      'pattern_ok': patternOk,
      'method': 'Estimación automática por cámara (ML Kit Pose); requiere revisión profesional.',
    };
  }
}

/// Human-readable lines for a stored summary (patient and specialist views).
List<String> describeMetrics(Map<String, dynamic> m) {
  final type = ExerciseType.fromCode(m['exercise'] as String?);
  return [
    'Ejercicio: ${type?.label ?? m['exercise']}',
    'Repeticiones completas: ${m['complete_reps']} de ${m['target_reps']}',
    if ((m['incomplete_reps'] as num? ?? 0) > 0)
      'Repeticiones incompletas: ${m['incomplete_reps']}',
    if ((m['fast_reps'] as num? ?? 0) > 0)
      'Repeticiones muy rápidas: ${m['fast_reps']}',
    if (m['avg_peak_angle_deg'] != null)
      'Ángulo promedio alcanzado: ${m['avg_peak_angle_deg']}°',
    if (m['avg_rep_seconds'] != null)
      'Tiempo por repetición: ${m['avg_rep_seconds']} s',
    'Cuerpo detectado: ${m['tracked_ratio']}% del video',
    m['pattern_ok'] == true
        ? 'Patrón: adecuado (estimación)'
        : 'Patrón: revisar con tu fisioterapeuta',
  ];
}
