import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:med_box/data.dart';
import 'package:med_box/specialty_screen.dart';

void main() {
  for (final specialty in Specialty.values) {
    testWidgets('${specialty.label}: every section renders on a phone', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = CareRepository(demo: true);
      final session = (await repository.sessions()).firstWhere(
        (s) => s.specialty == specialty,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: SpecialtyScreen(session: session, repository: repository),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(specialty.label), findsOneWidget);
      for (var i = 0; i < 4; i++) {
        await tester.tap(find.byType(GridView).evaluate().isEmpty
            ? find.byTooltip('Volver')
            : find.descendant(of: find.byType(GridView), matching: find.byType(InkWell)).at(i));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'sección $i');
        await tester.tap(find.byTooltip('Volver'));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.text('Notificaciones').last);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
