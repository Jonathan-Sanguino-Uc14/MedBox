import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:med_box/data.dart';
import 'package:med_box/specialty_checkin.dart';

void main() {
 test('Only physiotherapy enables physical capture and labels stay specific', () {
  for(final specialty in Specialty.values) {
   expect(specialty.allowsPhysicalExercise(true), specialty == Specialty.physio);
   expect(specialty.allowsPhysicalExercise(false), isFalse);
  }
  expect(Specialty.mind.planTitle, 'Mis tareas terapéuticas');
  expect(Specialty.skin.planTitle, 'Mi rutina dermatológica');
  expect(Specialty.eyes.planTitle, 'Mis cuidados oculares');
 });

  testWidgets('Unanswered scales stay absent and zero remains valid', (
    tester,
  ) async {
    final values = <String, dynamic>{};
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: StatefulBuilder(
              builder: (context, setState) => SpecialtyCheckIn(
                specialty: Specialty.mind,
                values: values,
                onChanged: (key, value) => setState(() {
                  if (value == null) {
                    values.remove(key);
                  } else {
                    values[key] = value;
                  }
                }),
              ),
            ),
          ),
        ),
      ),
    );
    expect(values.containsKey('Ansiedad'), isFalse);
    await tester.tap(find.text('Registrar ansiedad'));
    await tester.pump();
    expect(values['Ansiedad'], 5);
    tester.widget<Slider>(find.byType(Slider).first).onChanged!(0);
    await tester.pump();
    expect(values['Ansiedad'], 0);
    await tester.tap(find.text('Registrar ansiedad'));
    await tester.pump();
    expect(values.containsKey('Ansiedad'), isFalse);
  });
  test('Observations survive save and remain isolated by session', () async {
    final repo = CareRepository(demo: true);
    final session = (await repo.sessions()).firstWhere(
      (s) => s.specialty == Specialty.mind,
    );
    await repo.save(
      session,
      RecordDraft(details: {'Ansiedad': 0, 'Estrés': 4}),
    );
    final result = await repo.records(session.id);
    expect(result.single.details['Ansiedad'], 0);
    expect(result.single.details['Estrés'], 4);
    expect(await repo.records('skin'), isEmpty);
  });
}
