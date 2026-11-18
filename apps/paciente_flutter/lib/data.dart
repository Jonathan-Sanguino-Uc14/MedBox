import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config.dart';
import 'exercise_analysis.dart';

enum Specialty {
  physio(
    'Fisioterapia',
    'Movimiento y recuperación',
    Icons.accessibility_new_rounded,
  ),
  skin('Dermatología', 'El cuidado de tu piel', Icons.spa_outlined),
  eyes('Oftalmología', 'Bienestar de tu visión', Icons.visibility_outlined),
  mind('Psicología', 'Un espacio para ti', Icons.psychology_outlined);

  const Specialty(this.label, this.subtitle, this.icon);
  final String label, subtitle;
  final IconData icon;
}

extension SpecialtyPresentation on Specialty {
  String get planTitle => switch (this) {
    Specialty.physio => 'Mis ejercicios de rehabilitación',
    Specialty.skin => 'Mi rutina dermatológica',
    Specialty.mind => 'Mis tareas terapéuticas',
    Specialty.eyes => 'Mis cuidados oculares',
  };
  String get recordTitle => switch (this) {
    Specialty.physio => 'Mi rehabilitación',
    Specialty.skin => 'Mi seguimiento de la piel',
    Specialty.mind => 'Mi diario emocional',
    Specialty.eyes => 'Mi seguimiento ocular',
  };
  String get completedLabel => switch (this) {
    Specialty.physio => 'Completé mi ejercicio',
    Specialty.skin => 'Seguí el cuidado indicado',
    Specialty.mind => 'Realicé mi tarea terapéutica',
    Specialty.eyes => 'Seguí la indicación ocular',
  };
  bool allowsPhysicalExercise(bool isExercise) =>
      this == Specialty.physio && isExercise;
}

const lateralityLabels = {
  'right': 'Derecho',
  'left': 'Izquierdo',
  'both': 'Ambos',
  'na': 'No aplica',
};
const moodLabels = {
  'calm': 'Con calma',
  'joy': 'Con alegría',
  'sadness': 'Con tristeza',
  'worry': 'Con preocupación',
  'tired': 'Con cansancio',
};
const requestStatusLabels = {
  'pending': 'Pendiente de aprobación',
  'approved': 'Aprobada',
  'rejected': 'Rechazada',
};

const _evidenceBucket = 'care-evidence';

String newUuid() {
  final r = Random.secure();
  final b = List<int>.generate(16, (_) => r.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40;
  b[8] = (b[8] & 0x3f) | 0x80;
  final h = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
}

class CareSession {
  const CareSession({
    required this.id,
    required this.specialty,
    required this.title,
    required this.professional,
    required this.instructions,
    this.active = true,
    this.patientId,
  });
  final String id, title, professional, instructions;
  final Specialty specialty;
  final bool active;
  final String? patientId;
  factory CareSession.fromJson(Map<String, dynamic> row) => CareSession(
    id: row['id'] as String,
    specialty: Specialty.values.byName(row['specialty'] as String),
    title: row['title'] as String,
    professional: row['professional_name'] as String,
    instructions: row['instructions'] as String,
    active: row['active'] as bool? ?? true,
    patientId: row['patient_id'] as String?,
  );
}

class CareActivity {
  const CareActivity(
    this.id,
    this.title,
    this.instructions,
    this.dueOn, {
    this.exerciseCode,
    this.targetReps,
    this.targetSets,
    this.detector,
    this.cameraView,
    this.demoVideoPath,
    this.demoVideoUrl,
  });
  final String id, title, instructions;
  final DateTime? dueOn;
  final String? exerciseCode, detector, cameraView, demoVideoPath, demoVideoUrl;
  final int? targetReps, targetSets;

  /// Movement pattern used for automatic counting (null = video only).
  ExerciseType? get exercise => ExerciseType.fromCode(detector ?? exerciseCode);

  /// True when the activity is a recordable exercise (with or without counting).
  bool get isExercise => exerciseCode != null;
  bool get hasDemoVideo => demoVideoPath != null || demoVideoUrl != null;
}

/// Upload progress: bytes sent of total.
typedef UploadProgress = void Function(int sent, int total);

class CatalogExercise {
  const CatalogExercise(
    this.code,
    this.name,
    this.description,
    this.bodyRegion,
    this.cameraView,
    this.defaultReps,
    this.precautions,
  );
  final String code, name, description, bodyRegion, cameraView, precautions;
  final int defaultReps;
  factory CatalogExercise.fromRow(Map<String, dynamic> r) => CatalogExercise(
    r['code'] as String,
    r['name'] as String,
    r['description'] as String,
    r['body_region'] as String,
    r['camera_view'] as String,
    r['default_reps'] as int,
    r['precautions'] as String,
  );
}

class CareReview {
  const CareReview(this.recordId, this.body, this.date);
  final String recordId, body;
  final DateTime date;
}

/// What the patient fills in. Only the fields of the session specialty are sent.
class RecordDraft {
  RecordDraft({
    this.completed = false,
    this.pain,
    this.laterality,
    this.mood,
    this.bodyZone,
    this.note = '',
    this.image,
    this.imageExtension = 'jpg',
    this.activityId,
    this.exerciseMetrics,
    this.painAfter,
    this.videoPath,
    this.details = const {},
  });
  Map<String, dynamic> details;
  bool completed;
  int? pain, painAfter;
  String? laterality, mood, bodyZone, activityId;
  String note;
  Uint8List? image;
  String imageExtension;
  Map<String, dynamic>? exerciseMetrics;

  /// Local file of a recorded exercise video (physio only).
  String? videoPath;
}

class CareRecord {
  const CareRecord(
    this.sessionId,
    this.date,
    this.details, {
    this.id = '',
    this.evidencePath,
    this.metrics,
    this.activityId,
    this.completed,
    this.pain,
    this.painAfter,
  });
  final String id, sessionId;
  final DateTime date;
  final Map<String, dynamic> details;
  final String? evidencePath, activityId;
  final Map<String, dynamic>? metrics;
  final bool? completed;
  final int? pain, painAfter;

  /// Same pain value the panel charts: after the exercise when present.
  int? get reportedPain => painAfter ?? pain;
  bool get hasVideo =>
      evidencePath != null &&
      (evidencePath!.endsWith('.mp4') || evidencePath!.endsWith('.mov'));

  static Map<String, dynamic> labels({
    bool? completed,
    int? pain,
    String? laterality,
    String? mood,
    String? bodyZone,
    String? note,
    bool hasImage = false,
    int? painAfter,
    bool hasVideo = false,
  }) => {
    if (completed != null) 'Actividad completada': completed ? 'Sí' : 'No',
    'Dolor reportado (0–10)': ?pain,
    'Dolor después del ejercicio (0–10)': ?painAfter,
    if (hasVideo) 'Video': 'Adjunto (privado)',
    if (laterality != null) 'Lateralidad': lateralityLabels[laterality],
    if (mood != null) 'Estado emocional reportado': moodLabels[mood],
    if (bodyZone != null && bodyZone.isNotEmpty) 'Zona corporal': bodyZone,
    if (hasImage && !hasVideo) 'Foto': 'Adjunta (privada)',
    if (note != null && note.isNotEmpty) 'Nota': note,
  };

  factory CareRecord.fromRow(Map<String, dynamic> r) => CareRecord(
    r['session_id'] as String,
    DateTime.parse(r['created_at'] as String).toLocal(),
    {
      ...Map<String, dynamic>.from(r['details'] as Map? ?? const {}),
      ...labels(
        completed: r['completed'] as bool?,
        pain: r['pain'] as int?,
        laterality: r['laterality'] as String?,
        mood: r['mood'] as String?,
        bodyZone: r['body_zone'] as String?,
        note: r['note'] as String?,
        hasImage: r['evidence_path'] != null,
        painAfter: r['pain_after'] as int?,
        hasVideo: ((r['evidence_path'] as String?) ?? '').endsWith('.mp4'),
      ),
    },
    id: r['id'] as String,
    evidencePath: r['evidence_path'] as String?,
    metrics: r['exercise_metrics'] == null
        ? null
        : Map<String, dynamic>.from(r['exercise_metrics'] as Map),
    activityId: r['activity_id'] as String?,
    completed: r['completed'] as bool?,
    pain: r['pain'] as int?,
    painAfter: r['pain_after'] as int?,
  );
}

/// Appointment as stored in public.appointments (same rows the panel agenda shows).
class Appointment {
  const Appointment({
    required this.id,
    required this.sessionId,
    required this.start,
    required this.end,
    required this.status,
    required this.modality,
    this.specialty,
    this.professional = '',
    this.sessionTitle = '',
    this.cancelledBy,
  });
  final String id, sessionId, status, modality, professional, sessionTitle;
  final String? cancelledBy;
  final DateTime start, end;
  final Specialty? specialty;

  bool get live => status == 'requested' || status == 'confirmed';
  int get minutes => end.difference(start).inMinutes;

  /// Same labels as the panel (apps/panel_web/src/lib/agenda.ts statusText).
  static const statusText = {
    'requested': 'Por confirmar',
    'confirmed': 'Confirmada',
    'cancelled': 'Cancelada',
    'completed': 'Atendida',
    'no_show': 'No asistió',
  };
  static const modalityText = {
    'in_person': 'Presencial',
    'video': 'Videollamada',
  };
  String get statusLabel => statusText[status] ?? status;
  String get modalityLabel => modalityText[modality] ?? modality;

  /// Parses a PostgREST tstzrange: '["2026-11-19 15:00:00+00","2026-11-19 15:45:00+00")'.
  static (DateTime, DateTime) parseRange(String range) {
    final inner = range.trim().replaceAll(RegExp(r'^[\[(]|[\])]$'), '');
    final parts = inner
        .split(',')
        .map((s) => s.trim().replaceAll('"', ''))
        .toList();
    DateTime fix(String s) {
      var v = s.replaceFirst(' ', 'T');
      if (RegExp(r'[+-]\d{2}$').hasMatch(v)) v = '$v:00';
      return DateTime.parse(v).toLocal();
    }

    return (fix(parts[0]), fix(parts[1]));
  }

  factory Appointment.fromRow(Map<String, dynamic> r) {
    final (start, end) = parseRange(r['period'] as String);
    final s = r['care_sessions'] is List
        ? ((r['care_sessions'] as List).isEmpty
              ? null
              : (r['care_sessions'] as List).first as Map)
        : r['care_sessions'] as Map?;
    final sp = s?['specialty'] as String?;
    return Appointment(
      id: r['id'] as String,
      sessionId: r['session_id'] as String,
      start: start,
      end: end,
      status: r['status'] as String,
      modality: r['modality'] as String? ?? 'in_person',
      specialty: sp == null ? null : Specialty.values.byName(sp),
      professional: s?['professional_name'] as String? ?? '',
      sessionTitle: s?['title'] as String? ?? '',
      cancelledBy: r['cancelled_by'] as String?,
    );
  }
}

class LinkRequest {
  const LinkRequest(
    this.id,
    this.specialty,
    this.status,
    this.date, {
    this.email,
  });
  final String id, status;
  final Specialty specialty;
  final DateTime date;
  final String? email;
  factory LinkRequest.fromRow(Map<String, dynamic> r) => LinkRequest(
    r['id'] as String,
    Specialty.values.byName(r['specialty'] as String),
    r['status'] as String,
    DateTime.parse(r['created_at'] as String).toLocal(),
    email: r['recipient_email'] as String?,
  );
}

class AccountRole {
  const AccountRole({
    this.isSpecialist = false,
    this.displayName,
    this.specialties = const [],
    this.verified = false,
    this.wantsProfessional = false,
  });
  final bool isSpecialist, verified;

  /// Signed up as a professional but has not completed the professional profile.
  final bool wantsProfessional;
  final String? displayName;
  final List<Specialty> specialties;
}

/// Regla preventiva versionada (R01, R02…) del catálogo público.
class PreventionRule {
  const PreventionRule(
    this.title,
    this.body,
    this.source,
    this.url,
    this.reviewed, {
    this.code = '',
    this.scope = 'Educación general',
    this.isLocalAlert = false,
    this.expiresOn,
  });
  final String title, body, source, url, reviewed, code, scope;
  final bool isLocalAlert;

  /// Caducidad editorial (AAAA-MM-DD); no es la fecha del dato.
  final String? expiresOn;

  factory PreventionRule.fromRow(Map<String, dynamic> r) {
    final src = Map<String, dynamic>.from(r['data_sources'] as Map? ?? {});
    return PreventionRule(
      r['title'] as String,
      r['body'] as String,
      src['name'] as String? ?? 'Fuente no disponible',
      src['url'] as String? ?? '',
      r['reviewed_on'] as String,
      code: r['code'] as String? ?? '',
      scope: r['scope'] as String? ?? 'Educación general',
      isLocalAlert: r['is_local_alert'] as bool? ?? false,
      expiresOn: r['expires_on'] as String?,
    );
  }
}

class CareRepository {
  CareRepository({required this.demo, this.client});

  /// A blocked DNS or captive network must end in a retryable error, not an endless spinner.
  static const networkTimeout = Duration(seconds: 15);
  final bool demo;
  final SupabaseClient? client;
  final List<CareRecord> _records = [];
  final List<String> pendingCodes = [];

  SupabaseClient get _db => client!;
  String get _uid => _db.auth.currentUser!.id;

  static Map<String, dynamic> _ok(Object? result, String fallback) {
    if (result is Map && result['ok'] == true) {
      return Map<String, dynamic>.from(result);
    }
    throw FormatException(
      result is Map ? result['error'] as String? ?? fallback : fallback,
    );
  }

  Future<AccountRole> role() async {
    if (demo) return const AccountRole();
    final r = Map<String, dynamic>.from(
      await _db.rpc('my_role').timeout(networkTimeout) as Map,
    );
    final specialties = (r['specialties'] as List? ?? const [])
        .map((s) => Specialty.values.byName(s as String))
        .toList();
    final meta = _db.auth.currentUser?.userMetadata ?? const {};
    final isSpecialist = r['role'] == 'specialist' && specialties.isNotEmpty;
    return AccountRole(
      isSpecialist: isSpecialist,
      displayName: r['display_name'] as String?,
      specialties: specialties,
      verified: r['verified'] == true,
      wantsProfessional: !isSpecialist && meta['account_type'] == 'specialist',
    );
  }

  // ---------------------------------------------------------------- patient
  Future<List<CareSession>> sessions() async {
    if (demo) {
      return Specialty.values
          .map(
            (s) => CareSession(
              id: s.name,
              specialty: s,
              title: switch (s) {
                Specialty.physio => 'Volver a moverte con confianza',
                Specialty.skin => 'Tu piel, paso a paso',
                Specialty.eyes => 'Acompañamos tu visión',
                Specialty.mind => 'Tiempo para tu bienestar',
              },
              professional: 'Tu especialista',
              instructions: 'Explora cómo funciona tu seguimiento: registra cómo te sientes y comparte una nota con tu especialista.',
            ),
          )
          .toList();
    }
    final rows = await _db
        .from('care_sessions')
        .select(
          'id, patient_id, specialty, title, professional_name, instructions, active',
        )
        .order('created_at')
        .timeout(networkTimeout);
    return rows.map(CareSession.fromJson).toList();
  }

  Future<List<CareRecord>> records(String sessionId) async {
    if (demo) {
      return _records
          .where((r) => r.sessionId == sessionId)
          .toList()
          .reversed
          .toList();
    }
    final rows = await _db
        .from('care_records')
        .select()
        .eq('session_id', sessionId)
        .order('created_at', ascending: false);
    return rows.map(CareRecord.fromRow).toList();
  }

  Future<List<CareActivity>> activities(String sessionId) async {
    if (demo) {
      return sessionId == Specialty.physio.name
          ? const [
              CareActivity(
                'demo-squat',
                'Sentadilla',
                'Baja la cadera como si te sentaras y vuelve a subir. Coloca el teléfono de lado, a unos 2 metros.',
                null,
                exerciseCode: 'squat',
                targetReps: 5,
              ),
              CareActivity(
                'demo-curl',
                'Flexión de codo',
                'De frente a la cámara, dobla el codo llevando la mano al hombro.',
                null,
                exerciseCode: 'bicep_curl',
                targetReps: 5,
              ),
            ]
          : const [];
    }
    final rows = await _db
        .from('care_activities')
        .select(
          'id, title, instructions, due_on, exercise_code, target_reps, target_sets, '
          'exercise_catalog(detector, camera_view, demo_video_path, demo_video_url)',
        )
        .eq('session_id', sessionId)
        .eq('cancelled', false)
        .order('created_at');
    return rows
        .map(
          (r) => CareActivity(
            r['id'] as String,
            r['title'] as String,
            r['instructions'] as String,
            r['due_on'] == null ? null : DateTime.parse(r['due_on'] as String),
            exerciseCode: r['exercise_code'] as String?,
            targetReps: r['target_reps'] as int?,
            targetSets: r['target_sets'] as int?,
            detector: (r['exercise_catalog'] as Map?)?['detector'] as String?,
            cameraView:
                (r['exercise_catalog'] as Map?)?['camera_view'] as String?,
            demoVideoPath:
                (r['exercise_catalog'] as Map?)?['demo_video_path'] as String?,
            demoVideoUrl:
                (r['exercise_catalog'] as Map?)?['demo_video_url'] as String?,
          ),
        )
        .toList();
  }

  Future<List<CatalogExercise>> exerciseCatalog() async {
    final rows = await _db
        .from('exercise_catalog')
        .select()
        .eq('camera_supported', true)
        .order('name');
    return rows.map(CatalogExercise.fromRow).toList();
  }

  Future<void> registerAsSpecialist({
    required String displayName,
    required Specialty specialty,
    required String licenseNumber,
    String? qualification,
    String? phone,
    String? clinicName,
    int? experienceYears,
  }) async {
    _ok(
      await _db.rpc(
        'register_as_specialist',
        params: {
          'p_display_name': displayName.trim(),
          'p_specialty': specialty.name,
          'p_license_number': licenseNumber.trim(),
          'p_qualification': qualification,
          'p_phone': phone,
          'p_clinic_name': clinicName,
          'p_experience_years': experienceYears,
        },
      ),
      'No se pudo completar el registro profesional.',
    );
  }

  Future<String> evidenceUrl(String path) =>
      _db.storage.from(_evidenceBucket).createSignedUrl(path, 60);

  Future<List<CareReview>> reviews(String sessionId) async {
    if (demo) return const [];
    final rows = await _db
        .from('care_reviews')
        .select('record_id, body, created_at')
        .eq('session_id', sessionId)
        .order('created_at');
    return rows
        .map(
          (r) => CareReview(
            r['record_id'] as String,
            r['body'] as String,
            DateTime.parse(r['created_at'] as String).toLocal(),
          ),
        )
        .toList();
  }

  Future<String> demoVideoUrl(CareActivity a) async => a.demoVideoPath != null
      ? await _db.storage
            .from('exercise-demos')
            .createSignedUrl(a.demoVideoPath!, 300)
      : a.demoVideoUrl!;

  /// Streams a file to private storage reporting real progress.
  Future<void> _uploadWithProgress(
    String bucket,
    String path,
    File file,
    String contentType,
    UploadProgress? onProgress,
  ) async {
    final total = await file.length();
    final token = _db.auth.currentSession?.accessToken;
    if (token == null) throw const FormatException('Inicia sesión de nuevo.');
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 20);
    try {
      final request = await client.postUrl(
        Uri.parse('$supabaseUrl/storage/v1/object/$bucket/$path'),
      );
      request.headers
        ..set('Authorization', 'Bearer $token')
        ..set('apikey', supabasePublishableKey)
        ..set('Content-Type', contentType)
        ..set('x-upsert', 'false');
      request.contentLength = total;
      var sent = 0;
      await request.addStream(
        file.openRead().map((chunk) {
          sent += chunk.length;
          onProgress?.call(sent, total);
          return chunk;
        }),
      );
      final response = await request.close();
      final body = await response
          .transform(const SystemEncoding().decoder)
          .join();
      if (response.statusCode >= 300) {
        throw FormatException(
          response.statusCode == 413
              ? 'El video es demasiado grande.'
              : 'No se pudo subir el video (${response.statusCode}). $body',
        );
      }
    } finally {
      client.close();
    }
  }

  Future<void> save(
    CareSession session,
    RecordDraft draft, {
    UploadProgress? onProgress,
    void Function(String step)? onStep,
  }) async {
    final s = session.specialty;
    final pain = s == Specialty.physio ? draft.pain : null;
    final laterality = s == Specialty.eyes ? draft.laterality : null;
    final mood = s == Specialty.mind ? draft.mood : null;
    final zone = s == Specialty.skin ? draft.bodyZone?.trim() : null;
    final image = s == Specialty.skin ? draft.image : null;
    final metrics = s == Specialty.physio ? draft.exerciseMetrics : null;
    final painAfter = s == Specialty.physio ? draft.painAfter : null;
    final video = s == Specialty.physio ? draft.videoPath : null;
    if (demo) {
      _records.add(
        CareRecord(
          session.id,
          DateTime.now(),
          {
            ...draft.details,
            ...CareRecord.labels(
              completed: draft.completed,
              pain: pain,
              laterality: laterality,
              mood: mood,
              bodyZone: zone,
              note: draft.note.trim(),
              painAfter: painAfter,
            ),
          },
          id: newUuid(),
          metrics: metrics,
          activityId: draft.activityId,
          completed: draft.completed,
          pain: pain,
          painAfter: painAfter,
        ),
      );
      return;
    }
    String? evidencePath;
    if (video != null) {
      final file = File(video);
      if (await file.length() > 50 * 1024 * 1024) {
        throw const FormatException(
          'El video supera 50 MB. Graba una serie más corta.',
        );
      }
      onStep?.call('consent');
      await _db.from('consents').insert({
        'user_id': _uid,
        'purpose': 'video',
        'granted': true,
      });
      evidencePath = '${session.id}/$_uid/${newUuid()}.mp4';
      onStep?.call('upload');
      await _uploadWithProgress(
        _evidenceBucket,
        evidencePath,
        file,
        'video/mp4',
        onProgress,
      );
    }
    onStep?.call('save');
    if (image != null) {
      await _db.from('consents').insert({
        'user_id': _uid,
        'purpose': 'images',
        'granted': true,
      });
      evidencePath = '${session.id}/$_uid/${newUuid()}.${draft.imageExtension}';
      await _db.storage
          .from(_evidenceBucket)
          .uploadBinary(
            evidencePath,
            image,
            fileOptions: FileOptions(
              contentType: draft.imageExtension == 'png'
                  ? 'image/png'
                  : 'image/jpeg',
            ),
          );
    }
    await _db.from('care_records').insert({
      'session_id': session.id,
      'patient_id': _uid,
      'idempotency_key': newUuid(),
      'activity_id': draft.activityId,
      'completed': draft.completed,
      'pain': pain,
      'laterality': laterality,
      'mood': mood,
      'body_zone': (zone?.isEmpty ?? true) ? null : zone,
      'note': draft.note.trim().isEmpty ? null : draft.note.trim(),
      'evidence_path': evidencePath,
      'details': draft.details,
      'exercise_metrics': metrics,
      'pain_after': painAfter,
    });
  }

  Future<Uint8List> evidence(String path) =>
      _db.storage.from(_evidenceBucket).download(path);

  Future<void> requestLink(String code) async {
    final normalized = code.trim().toUpperCase();
    if (demo) {
      if (normalized != 'MEDBOX-DEMO') {
        throw const FormatException('Prueba el código MEDBOX-DEMO.');
      }
      if (!pendingCodes.contains(normalized)) pendingCodes.add(normalized);
      return;
    }
    _ok(
      await _db.rpc(
        'request_care_link',
        params: {'invitation_code': normalized},
      ),
      'No se pudo enviar la solicitud.',
    );
  }

  Future<List<LinkRequest>> myRequests() async {
    if (demo) return const [];
    final rows = await _db.rpc('my_link_requests') as List;
    return rows
        .map((r) => LinkRequest.fromRow(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  Future<void> requestData(String kind) async {
    if (demo) return;
    await _db.from('data_requests').insert({'user_id': _uid, 'kind': kind});
  }

  Future<List<PreventionRule>> preventionRules() async {
    if (demo || client == null) return const [];
    final rows = await _db
        .from('prevention_rules')
        .select(
          'code, title, body, scope, is_local_alert, reviewed_on, expires_on, '
          'data_sources(name, url)',
        )
        .order('code');
    return rows.map(PreventionRule.fromRow).toList();
  }

  // ------------------------------------------------------------- specialist
  Future<List<LinkRequest>> specialistRequests() async {
    final rows = await _db.rpc('specialist_link_requests') as List;
    return rows
        .map((r) => LinkRequest.fromRow(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  Future<String> createInvite(Specialty specialty, String email) async {
    final r = _ok(
      await _db.rpc(
        'create_care_invite',
        params: {
          'p_specialty': specialty.name,
          'p_recipient_email': email.trim(),
        },
      ),
      'No se pudo crear la invitación.',
    );
    return r['code'] as String;
  }

  Future<void> approve(
    String requestId,
    String title,
    String instructions,
  ) async {
    _ok(
      await _db.rpc(
        'approve_care_link',
        params: {
          'p_request_id': requestId,
          'p_title': title.trim(),
          'p_instructions': instructions.trim(),
        },
      ),
      'No se pudo aprobar.',
    );
  }

  Future<void> reject(String requestId) async {
    _ok(
      await _db.rpc('reject_care_link', params: {'p_request_id': requestId}),
      'No se pudo rechazar.',
    );
  }

  Future<void> closeSession(String sessionId) async {
    _ok(
      await _db.rpc('close_care_session', params: {'p_session_id': sessionId}),
      'No se pudo cerrar la sesión.',
    );
  }

  Future<void> addActivity(
    String sessionId,
    String title,
    String instructions,
    DateTime? dueOn, {
    String? exerciseCode,
    int? targetReps,
    int? targetSets,
  }) async {
    await _db.from('care_activities').insert({
      'session_id': sessionId,
      'created_by': _uid,
      'title': title.trim(),
      'instructions': instructions.trim(),
      'due_on': dueOn?.toIso8601String().substring(0, 10),
      'exercise_code': exerciseCode,
      'target_reps': targetReps,
      'target_sets': targetSets,
    });
  }

  Future<void> addReview(String sessionId, String recordId, String body) async {
    await _db.from('care_reviews').insert({
      'session_id': sessionId,
      'record_id': recordId,
      'specialist_id': _uid,
      'body': body.trim(),
    });
  }

  // ------------------------------------------------------------- agenda
  /// Patient's own name from profiles (null in exploration or when empty).
  Future<String?> myName() async => demo ? null : patientName(_uid);

  String? get myId => demo ? null : _db.auth.currentUser?.id;

  /// Appointments of the signed-in patient (RLS: patient_id = auth.uid()).
  Future<List<Appointment>> myAppointments() async {
    if (demo) return const [];
    final from = DateTime.now().subtract(const Duration(days: 60)).toUtc();
    final to = DateTime.now().add(const Duration(days: 180)).toUtc();
    final rows = await _db
        .from('appointments')
        .select(
          'id, session_id, period, status, modality, cancelled_by, care_sessions(title, specialty, professional_name)',
        )
        .eq('patient_id', _uid)
        .overlaps(
          'period',
          '[${from.toIso8601String()},${to.toIso8601String()})',
        )
        .order('period')
        .timeout(networkTimeout);
    return rows.map(Appointment.fromRow).toList();
  }

  /// Open slots computed by the same RPC the panel uses.
  Future<List<DateTime>> availableSlots(
    String sessionId,
    DateTime from, {
    int days = 7,
  }) async {
    if (demo) return const [];
    final d =
        '${from.year.toString().padLeft(4, '0')}-${from.month.toString().padLeft(2, '0')}-${from.day.toString().padLeft(2, '0')}';
    final rows =
        await _db
                .rpc(
                  'get_available_slots',
                  params: {
                    'p_session_id': sessionId,
                    'p_from': d,
                    'p_days': days,
                  },
                )
                .timeout(networkTimeout)
            as List;
    return rows
        .map(
          (r) => DateTime.parse((r as Map)['slot_start'] as String).toLocal(),
        )
        .toList();
  }

  Future<void> bookAppointment(
    String sessionId,
    DateTime start, {
    String modality = 'in_person',
  }) async {
    _ok(
      await _db
          .rpc(
            'book_appointment',
            params: {
              'p_session_id': sessionId,
              'p_start': start.toUtc().toIso8601String(),
              'p_modality': modality,
            },
          )
          .timeout(networkTimeout),
      'Ese horario ya no está disponible.',
    );
  }

  Future<void> rescheduleAppointment(
    String appointmentId,
    DateTime start,
  ) async {
    _ok(
      await _db
          .rpc(
            'reschedule_appointment',
            params: {
              'p_appointment_id': appointmentId,
              'p_new_start': start.toUtc().toIso8601String(),
            },
          )
          .timeout(networkTimeout),
      'No se pudo reagendar.',
    );
  }

  Future<void> cancelAppointment(String appointmentId) async {
    _ok(
      await _db
          .rpc(
            'cancel_appointment',
            params: {'p_appointment_id': appointmentId},
          )
          .timeout(networkTimeout),
      'Cita no disponible.',
    );
  }

  Future<String?> patientName(String patientId) async {
    final row = await _db
        .from('profiles')
        .select('full_name')
        .eq('id', patientId)
        .maybeSingle();
    final name = row?['full_name'] as String?;
    return (name == null || name.isEmpty) ? null : name;
  }
}
