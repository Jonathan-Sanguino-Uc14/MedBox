import 'package:flutter_test/flutter_test.dart';
import 'package:med_box/data.dart';
import 'package:med_box/patient_home.dart';

void main() {
  test('Appointment parses PostgREST tstzrange like the panel', () {
    final a = Appointment.fromRow({
      'id': 'a1',
      'session_id': 's1',
      'period': '["2026-11-19 15:00:00+00","2026-11-19 15:45:00+00")',
      'status': 'confirmed',
      'modality': 'in_person',
      'care_sessions': {'title': 'Rodilla', 'specialty': 'physio', 'professional_name': 'Lic. Laura Ríos'},
    });
    expect(a.start.toUtc(), DateTime.utc(2026, 11, 19, 15));
    expect(a.minutes, 45);
    expect(a.statusLabel, 'Confirmada');
    expect(a.specialty, Specialty.physio);
    expect(a.live, isTrue);
  });

  test('Weekly compliance and review state follow the panel formula', () {
    const session = CareSession(id: 's1', specialty: Specialty.physio, title: 't', professional: 'p', instructions: '');
    final now = DateTime.now();
    final d = SessionData(
      session,
      const [CareActivity('a1', 'Sentadilla', '', null), CareActivity('a2', 'Curl', '', null)],
      [
        CareRecord('s1', now, const {}, id: 'r1', activityId: 'a1', completed: true, pain: 3),
        CareRecord('s1', now.subtract(const Duration(days: 1)), const {}, id: 'r2', activityId: 'a2', completed: true, pain: 5, painAfter: 4),
      ],
      [CareReview('r2', 'Bien', now)],
    );
    expect(d.weekCompliance(0), 100);
    expect(d.weekCompliance(1), 0);
    expect(d.reviewState(d.records[0]), 'En revisión');
    expect(d.reviewState(d.records[1]), 'Revisado');
    expect(d.records[1].reportedPain, 4);
    expect(d.streak, 2);
  });
}
