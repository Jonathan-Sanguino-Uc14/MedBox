import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:med_box/main.dart';

Future<void> reveal(WidgetTester tester, Finder target) async {
  for (var i = 0; i < 20 && target.hitTestable().evaluate().isEmpty; i++) {
    await tester.drag(find.byType(ListView).last, const Offset(0, -180));
    await tester.pumpAndSettle();
  }
  expect(target.hitTestable(), findsWidgets);
}

void main() {
  testWidgets('Mobile welcome and four specialties render without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MedBoxApp());
    await tester.pumpAndSettle();
    final demo = find.text('Explorar sin cuenta');
    await reveal(tester, demo);
    await tester.tap(demo);
    await tester.pumpAndSettle();
    expect(find.text('Hola, qué gusto verte'), findsOneWidget);
    await tester.ensureVisible(find.text('Psicología').first);
    await tester.pumpAndSettle();
    expect(find.text('Oftalmología'), findsWidgets);
    expect(tester.takeException(), isNull);
    await tester.fling(find.byType(PageView), const Offset(-300, 0), 1000);
    await tester.pumpAndSettle();
    expect(find.text('Tu progreso'), findsOneWidget);
    for (final tab in ['Progreso', 'Mensajes', 'Perfil', 'Hoy']) {
      await tester.tap(find.text(tab).last);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: tab);
    }
    await tester.ensureVisible(find.text('Psicología').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Psicología').first);
    await tester.pumpAndSettle();
    final detail = find.text('Ver todo mi seguimiento de psicología');
    await reveal(tester, detail);
    await tester.tap(detail);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Diario emocional'));
    await tester.pumpAndSettle();
    await reveal(tester, find.text('Escribir en mi diario'));
    await tester.tap(find.text('Escribir en mi diario'));
    await tester.pumpAndSettle();
    final note = find.widgetWithText(TextField, 'Tu nota (opcional)');
    await reveal(tester, note);
    await tester.enterText(note, 'Hoy me sentí mejor');
    final consent = find.widgetWithText(
      CheckboxListTile,
      'Quiero compartir este registro con el profesional de esta sesión.',
    );
    await reveal(tester, consent);
    await tester.tap(consent);
    await tester.pumpAndSettle();
    final save = find.text('Guardar registro');
    await reveal(tester, save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    await reveal(tester, find.text('Nota: Hoy me sentí mejor'));
    expect(find.text('Nota: Hoy me sentí mejor'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
