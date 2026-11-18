import 'package:flutter_test/flutter_test.dart';
import 'package:med_box/data.dart';

void main() {
  test('Demo includes four specialties and isolates their records', () async {
    final repo = CareRepository(demo: true);
    final sessions = await repo.sessions();
    expect(sessions.map((s) => s.specialty).toSet(), Specialty.values.toSet());
    final physio = sessions.firstWhere((s) => s.specialty == Specialty.physio);
    await repo.save(
      physio,
      RecordDraft(note: 'Nota de prueba', pain: 3, mood: 'calm'),
    );
    final saved = await repo.records('physio');
    expect(saved, hasLength(1));
    expect(saved.single.details['Dolor reportado (0–10)'], 3);
    expect(
      saved.single.details.containsKey('Estado emocional reportado'),
      isFalse,
    );
    expect(await repo.records('mind'), isEmpty);
    expect(await CareRepository(demo: true).records('physio'), isEmpty);
  });
  test(
    'Invitation creates a pending request without granting another session',
    () async {
      final repo = CareRepository(demo: true);
      await expectLater(repo.requestLink('INVALID'), throwsFormatException);
      await repo.requestLink(' medbox-demo ');
      await repo.requestLink('MEDBOX-DEMO');
      expect(repo.pendingCodes, hasLength(1));
      expect(await repo.sessions(), hasLength(4));
    },
  );
  test('Structured rows map to readable labels', () {
    final r = CareRecord.fromRow({
      'id': 'r1',
      'session_id': 's1',
      'created_at': '2026-11-17T10:00:00Z',
      'details': {},
      'completed': true,
      'laterality': 'left',
      'note': 'Molestia leve',
    });
    expect(r.details['Lateralidad'], 'Izquierdo');
    expect(r.details['Actividad completada'], 'Sí');
    expect(r.details['Nota'], 'Molestia leve');
  });
  test('Generated idempotency keys are v4 UUIDs', () {
    expect(
      RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
      ).hasMatch(newUuid()),
      isTrue,
    );
  });
}
