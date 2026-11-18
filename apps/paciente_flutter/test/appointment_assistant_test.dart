import 'package:flutter_test/flutter_test.dart';
import 'package:med_box/appointment_assistant.dart';
import 'package:med_box/data.dart';

// Wednesday 18 Nov 2026, 09:00.
final now = DateTime(2026, 11, 18, 9);

void main() {
  group('parseRequest', () {
    test('weekday + part of day', () {
      final p = parseRequest('¿Hay algo el viernes por la tarde?', now);
      expect(p.intent, AssistantIntent.book);
      expect(p.day, DateTime(2026, 11, 20));
      expect(p.part, DayPart.afternoon);
    });
    test('mañana vs. en la mañana', () {
      expect(parseRequest('quiero cita mañana', now).day, DateTime(2026, 11, 19));
      final p = parseRequest('cita el jueves en la mañana', now);
      expect(p.day, DateTime(2026, 11, 19));
      expect(p.part, DayPart.morning);
    });
    test('day number and hour', () {
      final p = parseRequest('agendar el 25 a las 4', now);
      expect(p.day, DateTime(2026, 11, 25));
      expect(p.hour, 16);
    });
    test('past day number rolls to next month', () {
      expect(parseRequest('cita el 3', now).day, DateTime(2026, 12, 3));
    });
    test('intents', () {
      expect(parseRequest('Quiero mover mi cita del jueves', now).intent, AssistantIntent.reschedule);
      expect(parseRequest('cancela mi cita', now).intent, AssistantIntent.cancel);
      expect(parseRequest('mis citas', now).intent, AssistantIntent.list);
      expect(parseRequest('me duele mucho la rodilla', now).intent, AssistantIntent.clinical);
      expect(parseRequest('hola', now).intent, AssistantIntent.greet);
      expect(parseRequest('fisioterapia', now).specialty, Specialty.physio);
    });
  });

  test('filterSlots keeps nearest hours or part of day', () {
    final slots = [9, 10, 12, 13, 16].map((h) => DateTime(2026, 11, 20, h)).toList();
    expect(filterSlots(slots, part: DayPart.morning).map((s) => s.hour), [9, 10]);
    expect(filterSlots(slots, hour: 12).first.hour, 12);
  });

  group('AppointmentAssistant', () {
    late List<String> calls;
    late AppointmentAssistant a;
    final existing = Appointment(
      id: 'ap1',
      sessionId: 's1',
      start: DateTime(2026, 11, 19, 9),
      end: DateTime(2026, 11, 19, 9, 45),
      status: 'confirmed',
      modality: 'in_person',
      professional: 'Lic. Laura Ríos',
    );
    setUp(() {
      calls = [];
      a = AppointmentAssistant(
        sessions: const [AssistantSession('s1', Specialty.physio, 'Lic. Laura Ríos')],
        appointments: [existing],
        clock: () => now,
        slots: (id, from, days) async => [
          for (var d = 0; d < days; d++)
            if (from.add(Duration(days: d)).weekday == DateTime.friday)
              for (final h in [9, 10, 12, 13]) DateTime(from.year, from.month, from.day + d, h),
        ],
        book: (id, start) async => calls.add('book $id ${start.hour}'),
        reschedule: (id, start) async => calls.add('move $id ${start.day}/${start.hour}'),
        cancel: (id) async => calls.add('cancel $id'),
      );
    });

    test('offers only real slots and books on tap', () async {
      final r = await a.respond('¿Hay algo el viernes?');
      expect(r.action, AssistantAction.showSlots);
      expect(r.slots.map((s) => s.hour), [9, 10, 12, 13]);
      final done = await a.pick(r.slots[1]);
      expect(done.action, AssistantAction.bookingConfirmed);
      expect(calls, ['book s1 10']);
    });

    test('unavailable day suggests the next day with room', () async {
      final r = await a.respond('cita el jueves');
      expect(r.action, AssistantAction.showSlots);
      expect(r.slots.first.day, 20);
      expect(r.text, contains('no hay espacio'));
    });

    test('reschedule moves the single upcoming appointment', () async {
      final r = await a.respond('quiero mover mi cita al viernes por la tarde');
      expect(r.slots.map((s) => s.hour), [12, 13]);
      await a.pick(r.slots.first);
      expect(calls, ['move ap1 20/12']);
    });

    test('cancel asks for confirmation first', () async {
      final r = await a.respond('cancelar');
      expect(r.action, AssistantAction.confirmCancel);
      expect(calls, isEmpty);
      await a.confirmCancel(r.appointments.first);
      expect(calls, ['cancel ap1']);
    });

    test('each specialist has its own bot', () async {
      final derma = AppointmentAssistant(
        sessions: const [AssistantSession('s2', Specialty.skin, 'Dra. Elena Cauich')],
        others: const [AssistantSession('s1', Specialty.physio, 'Lic. Laura Ríos')],
        appointments: [existing],
        clock: () => now,
        slots: (id, from, days) async => const [],
        book: (id, start) async {},
        reschedule: (id, start) async {},
        cancel: (id) async {},
      );
      expect(derma.upcoming, isEmpty); // physio appointment is not this bot's
      expect(derma.greeting().text, contains('Dra. Elena Cauich'));
      final r = await derma.respond('quiero cita de fisioterapia');
      expect(r.text, contains('Lic. Laura Ríos'));
    });

    test('clinical questions are redirected, nothing is booked', () async {
      final r = await a.respond('qué medicamento tomo para el dolor');
      expect(r.text, contains('Lic. Laura Ríos'));
      expect(r.action, AssistantAction.none);
      expect(calls, isEmpty);
    });
  });
}
