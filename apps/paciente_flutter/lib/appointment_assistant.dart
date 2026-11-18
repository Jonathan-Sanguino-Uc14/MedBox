import 'data.dart';

/// Appointment assistant (agenda only, nothing clinical).
///
/// It understands Spanish requests on the device and acts through the same
/// RPCs the panel uses (get_available_slots, book/reschedule/cancel_appointment),
/// so it never invents a time: every slot it offers comes from the database.
/// Replies follow the contract planned for the `chat-agent` Edge Function
/// ({reply_text, action_type, available_slots, booking_details}) so the parser
/// can later be swapped for Gemini without touching the screen.

enum AssistantIntent {
  book,
  reschedule,
  cancel,
  list,
  clinical,
  greet,
  thanks,
  unknown,
}

enum DayPart { morning, afternoon }

enum AssistantAction {
  none,
  showSlots,
  bookingConfirmed,
  chooseAppointment,
  confirmCancel,
}

class ParsedRequest {
  const ParsedRequest(
    this.intent, {
    this.day,
    this.part,
    this.hour,
    this.specialty,
  });
  final AssistantIntent intent;
  final DateTime? day;
  final DayPart? part;
  final int? hour;
  final Specialty? specialty;
}

class AssistantReply {
  const AssistantReply(
    this.text, {
    this.action = AssistantAction.none,
    this.slots = const [],
    this.appointments = const [],
    this.booking,
    this.suggestions = const [],
  });
  final String text;
  final AssistantAction action;
  final List<DateTime> slots;
  final List<Appointment> appointments;
  final Appointment? booking;

  /// Quick replies shown as chips under the message.
  final List<String> suggestions;
}

const assistantWeekdays = [
  'lunes',
  'martes',
  'miércoles',
  'jueves',
  'viernes',
  'sábado',
  'domingo',
];
const assistantMonths = [
  'enero',
  'febrero',
  'marzo',
  'abril',
  'mayo',
  'junio',
  'julio',
  'agosto',
  'septiembre',
  'octubre',
  'noviembre',
  'diciembre',
];

String _fold(String s) {
  const from = 'áéíóúüñ';
  const to = 'aeiouun';
  final b = StringBuffer();
  for (final ch in s.toLowerCase().split('')) {
    final i = from.indexOf(ch);
    b.write(i < 0 ? ch : to[i]);
  }
  return b.toString();
}

DateTime _d(DateTime x) => DateTime(x.year, x.month, x.day);

String assistantDay(DateTime d, DateTime now) {
  final diff = _d(d).difference(_d(now)).inDays;
  final base = '${assistantWeekdays[d.weekday - 1]} ${d.day}';
  if (diff == 0) return 'hoy $base';
  if (diff == 1) return 'mañana $base';
  return diff < 7 ? base : '$base de ${assistantMonths[d.month - 1]}';
}

String assistantTime(DateTime d) {
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final m = d.minute.toString().padLeft(2, '0');
  return '$h:$m ${d.hour < 12 ? 'a. m.' : 'p. m.'}';
}

bool _has(String t, List<String> words) => words.any(t.contains);

/// Pure parser: intent, date, part of day, hour and specialty.
ParsedRequest parseRequest(String raw, DateTime now) {
  final t = ' ${_fold(raw).replaceAll(RegExp(r'[¿?¡!.,;]'), ' ')} ';
  final today = _d(now);

  Specialty? specialty;
  if (_has(t, ['fisio', 'rehab', 'rodilla', 'espalda'])) {
    specialty = Specialty.physio;
  }
  if (_has(t, ['derma', 'piel', 'acne'])) specialty = Specialty.skin;
  if (_has(t, ['oftal', ' ojo', 'vista', 'vision'])) specialty = Specialty.eyes;
  if (_has(t, ['psico', 'terapia emocional', 'ansiedad'])) {
    specialty = Specialty.mind;
  }

  // Date.
  DateTime? day;
  if (t.contains('pasado manana')) {
    day = today.add(const Duration(days: 2));
  } else if (RegExp(r' manana ').hasMatch(t) &&
      !RegExp(r'(la|en la|por la|de la) manana').hasMatch(t)) {
    day = today.add(const Duration(days: 1));
  } else if (t.contains(' hoy ')) {
    day = today;
  }
  if (day == null) {
    for (var i = 0; i < 7; i++) {
      final w = _fold(assistantWeekdays[i]);
      if (RegExp(' $w ').hasMatch(t)) {
        var delta = (i + 1 - now.weekday) % 7;
        if (delta == 0) delta = 7;
        if (t.contains('semana que viene') || t.contains('proxima semana')) {
          if (delta < 7) delta += 7;
        }
        day = today.add(Duration(days: delta));
        break;
      }
    }
  }
  if (day == null) {
    final m = RegExp(r' (?:el |dia )?(\d{1,2})(?: de (\w+))? ').firstMatch(t);
    final isHour =
        m != null && RegExp(r'(a las|alas|a la) ' + m.group(1)!).hasMatch(t);
    if (m != null && !isHour) {
      final n = int.parse(m.group(1)!);
      var month = now.month;
      final name = m.group(2);
      if (name != null) {
        final idx = assistantMonths.map(_fold).toList().indexOf(name);
        if (idx >= 0) month = idx + 1;
      }
      if (n >= 1 && n <= 31) {
        var candidate = DateTime(now.year, month, n);
        if (candidate.isBefore(today)) {
          candidate = name == null
              ? DateTime(now.year, now.month + 1, n)
              : DateTime(now.year + 1, month, n);
        }
        if (candidate.day == n) day = candidate;
      }
    }
  }
  if (day == null &&
      (t.contains('semana que viene') || t.contains('proxima semana'))) {
    day = today.add(Duration(days: 8 - now.weekday));
  }

  // Time.
  int? hour;
  final hm =
      RegExp(r'(?:a las|alas|a la|tipo|como a las) (\d{1,2})(?::(\d{2}))?')
          .firstMatch(t) ??
      RegExp(r' (\d{1,2})(?::(\d{2}))? ?(am|pm|hrs|h) ').firstMatch(t);
  if (hm != null) {
    var h = int.parse(hm.group(1)!);
    final pm = t.contains('pm') || t.contains('tarde') || t.contains('noche');
    if (pm && h < 12) h += 12;
    if (!pm && h >= 1 && h <= 6) {
      h += 12; // "a las 4" = 16:00 in a clinic agenda
    }
    if (h <= 23) hour = h;
  }
  DayPart? part;
  if (RegExp(r'(la|en la|por la|de la) manana|temprano').hasMatch(t)) {
    part = DayPart.morning;
  }
  if (_has(t, ['tarde', 'noche'])) part = DayPart.afternoon;

  // Intent (most specific first).
  AssistantIntent intent;
  if (_has(t, [
    'dolor',
    'duele',
    'medicamento',
    'medicina',
    'pastilla',
    'sintoma',
    'receta',
    'dosis',
    'tratamiento',
    'diagnostico',
    'inflam',
    'fiebre',
    'sangr',
    'mareo',
    'urgencia',
    'emergencia',
  ])) {
    intent = AssistantIntent.clinical;
  } else if (_has(t, [
    'cancel',
    'anular',
    'ya no puedo ir',
    'no voy a poder',
    'quitar mi cita',
    'eliminar',
  ])) {
    intent = AssistantIntent.cancel;
  } else if (_has(t, [
    'reagend',
    'mover',
    'cambiar',
    'cambio',
    'recorrer',
    'pasar mi cita',
    'otro dia',
    'otra hora',
    'otro horario',
    'posponer',
    'adelantar',
  ])) {
    intent = AssistantIntent.reschedule;
  } else if (_has(t, [
    'mis citas',
    'cuando es',
    'cuando tengo',
    'proxima cita',
    'tengo cita',
    'que citas',
    'ver citas',
    'a que hora es',
  ])) {
    intent = AssistantIntent.list;
  } else if (_has(t, [
        'agend',
        'reserv',
        'cita',
        'turno',
        'consulta',
        'disponib',
        'horario',
        'hay lugar',
        'espacio',
        'apart',
        'quiero ir',
        'puedo ir',
      ]) ||
      day != null ||
      hour != null ||
      part != null) {
    intent = AssistantIntent.book;
  } else if (_has(t, ['gracias', 'perfecto', 'listo', 'ok ', 'vale'])) {
    intent = AssistantIntent.thanks;
  } else if (_has(t, [
    'hola',
    'buenas',
    'buenos dias',
    'buen dia',
    'que tal',
    'ayuda',
    'que puedes',
  ])) {
    intent = AssistantIntent.greet;
  } else {
    intent = AssistantIntent.unknown;
  }
  return ParsedRequest(
    intent,
    day: day,
    part: part,
    hour: hour,
    specialty: specialty,
  );
}

/// Keeps the slots that match the requested part of day / hour.
List<DateTime> filterSlots(List<DateTime> slots, {DayPart? part, int? hour}) {
  var list = slots;
  if (hour != null) {
    final near = list.where((s) => (s.hour - hour).abs() <= 1).toList()
      ..sort(
        (a, b) => ((a.hour * 60 + a.minute) - hour * 60).abs().compareTo(
          ((b.hour * 60 + b.minute) - hour * 60).abs(),
        ),
      );
    return near;
  }
  if (part == DayPart.morning) list = list.where((s) => s.hour < 12).toList();
  if (part == DayPart.afternoon) {
    list = list.where((s) => s.hour >= 12).toList();
  }
  return list;
}

typedef SlotSource = Future<List<DateTime>> Function(
  String sessionId,
  DateTime from,
  int days,
);

class AssistantSession {
  const AssistantSession(this.id, this.specialty, this.professional);
  final String id, professional;
  final Specialty specialty;
}

/// Conversation state machine. All writes go through the callbacks (RPCs).
class AppointmentAssistant {
  AppointmentAssistant({
    required this.sessions,
    required this.appointments,
    required this.slots,
    required this.book,
    required this.reschedule,
    required this.cancel,
    this.others = const [],
    String? sessionId,
    DateTime Function()? clock,
  }) : _sessionId = sessionId ?? (sessions.isEmpty ? null : sessions.first.id),
       _now = clock ?? DateTime.now;

  final List<AssistantSession> sessions;

  /// Specialists that have their own assistant (one bot per specialist).
  final List<AssistantSession> others;
  List<Appointment> appointments;
  final SlotSource slots;
  final Future<void> Function(String sessionId, DateTime start) book;
  final Future<void> Function(String appointmentId, DateTime start) reschedule;
  final Future<void> Function(String appointmentId) cancel;
  final DateTime Function() _now;

  String? _sessionId;
  Appointment? _moving;
  bool _choosingForCancel = false;
  DateTime? _lastDay;

  AssistantSession? get session {
    for (final s in sessions) {
      if (s.id == _sessionId) return s;
    }
    return sessions.isEmpty ? null : sessions.first;
  }

  bool get isRescheduling => _moving != null;

  List<Appointment> get upcoming {
    final now = _now();
    final mine = sessions.map((s) => s.id).toSet();
    return appointments
        .where(
          (a) => mine.contains(a.sessionId) && a.live && a.end.isAfter(now),
        )
        .toList()
      ..sort((a, b) => a.start.compareTo(b.start));
  }

  static const help = [
    'Agendar una cita',
    'Mis citas',
    'Reagendar',
    'Cancelar',
  ];

  AssistantReply greeting() {
    final s = session;
    if (s == null) {
      return const AssistantReply(
        'Hola. Cuando te vincules con tu especialista podré agendar tus citas.',
      );
    }
    final names = sessions.length == 1
        ? '${s.professional} (${s.specialty.label.toLowerCase()})'
        : sessions.map((x) => x.professional).toSet().join(' y ');
    final next = upcoming.firstOrNull;
    final tail = next == null
        ? ''
        : ' Tu próxima cita es el ${assistantDay(next.start, _now())} a las ${assistantTime(next.start)}.';
    return AssistantReply(
      'Hola, soy el asistente de citas de $names. Puedo agendar, reagendar o cancelar tus citas.$tail ¿Qué necesitas?',
      suggestions: help,
    );
  }

  String _who(AssistantSession s) =>
      '${s.professional} (${s.specialty.label.toLowerCase()})';

  Future<AssistantReply> respond(String text) async {
    final now = _now();
    var p = parseRequest(text, now);
    if (session == null) return greeting();
    final folded = _fold(text);
    if (folded.contains('otro dia') && _lastDay != null && p.day == null) {
      return nextDay(_lastDay!);
    }
    // "por la tarde" right after a list of slots refers to that same day.
    if (p.intent == AssistantIntent.book &&
        p.day == null &&
        (p.part != null || p.hour != null) &&
        _lastDay != null) {
      p = ParsedRequest(
        p.intent,
        day: _lastDay,
        part: p.part,
        hour: p.hour,
        specialty: p.specialty,
      );
    }
    if (p.intent == AssistantIntent.book &&
        (folded.contains('agend') || folded.contains('nueva'))) {
      _moving = null;
    }

    if (p.specialty != null) {
      final match = sessions
          .where((s) => s.specialty == p.specialty)
          .firstOrNull;
      final other = others.where((s) => s.specialty == p.specialty).firstOrNull;
      if (match == null && other != null) {
        return AssistantReply(
          'Aquí solo agendo con ${_who(session!)}. Para ${other.specialty.label.toLowerCase()}, desliza a la pestaña de ${other.professional}.',
          suggestions: help,
        );
      }
      if (match == null) {
        return AssistantReply(
          'No tienes una sesión activa de ${p.specialty!.label.toLowerCase()}. Pide a tu especialista un código para vincularte.',
          suggestions: help,
        );
      }
      _sessionId = match.id;
    }

    switch (p.intent) {
      case AssistantIntent.clinical:
        return AssistantReply(
          'Solo puedo ayudarte con tus citas. Para dudas sobre síntomas, dolor o tu tratamiento, consulta a ${session!.professional}. '
          'Si es una urgencia, llama al 911.',
          suggestions: const ['Agendar una cita'],
        );
      case AssistantIntent.greet:
        return greeting();
      case AssistantIntent.thanks:
        return const AssistantReply(
          'Con gusto. Te recordaré tu cita un día antes.',
          suggestions: ['Mis citas'],
        );
      case AssistantIntent.list:
        return _list();
      case AssistantIntent.cancel:
        _moving = null;
        return _askCancel(p);
      case AssistantIntent.reschedule:
        return _askReschedule(p);
      case AssistantIntent.book:
        return _offer(p);
      case AssistantIntent.unknown:
        return const AssistantReply(
          'No te entendí. Puedes escribir, por ejemplo: «¿Hay algo el viernes por la tarde?» o «Quiero cambiar mi cita».',
          suggestions: help,
        );
    }
  }

  AssistantReply _list() {
    final list = upcoming;
    if (list.isEmpty) {
      return const AssistantReply(
        'No tienes citas próximas. ¿Quieres agendar una?',
        suggestions: ['Agendar una cita'],
      );
    }
    final lines = list
        .take(5)
        .map(
          (a) =>
              '• ${assistantDay(a.start, _now())}, ${assistantTime(a.start)} con ${a.professional} · ${a.statusLabel.toLowerCase()}',
        )
        .join('\n');
    return AssistantReply(
      'Tus próximas citas:\n$lines',
      suggestions: const ['Reagendar', 'Cancelar'],
    );
  }

  Appointment? _byDay(List<Appointment> list, DateTime? day) => day == null
      ? null
      : list.where((a) => _d(a.start) == _d(day)).firstOrNull;

  AssistantReply _askCancel(ParsedRequest p) {
    final list = upcoming;
    if (list.isEmpty) {
      return const AssistantReply('No tienes citas próximas que cancelar.');
    }
    final target =
        _byDay(list, p.day) ?? (list.length == 1 ? list.first : null);
    if (target != null) {
      return AssistantReply(
        '¿Cancelo tu cita del ${assistantDay(target.start, _now())} a las ${assistantTime(target.start)} con ${target.professional}?',
        action: AssistantAction.confirmCancel,
        appointments: [target],
      );
    }
    _choosingForCancel = true;
    return AssistantReply(
      '¿Cuál cita quieres cancelar?',
      action: AssistantAction.chooseAppointment,
      appointments: list,
    );
  }

  Future<AssistantReply> _askReschedule(ParsedRequest p) async {
    final list = upcoming;
    if (list.isEmpty) {
      return AssistantReply(
        'No tienes citas próximas para mover. Te muestro horarios para agendar una nueva.',
        action: AssistantAction.none,
        suggestions: const ['Agendar una cita'],
      );
    }
    // The date in "move my Thursday appointment to Friday" usually names the new day.
    final target = list.length == 1
        ? list.first
        : _moving ?? (_byDay(list, p.day));
    if (target == null) {
      _choosingForCancel = false;
      return AssistantReply(
        '¿Cuál cita quieres cambiar?',
        action: AssistantAction.chooseAppointment,
        appointments: list,
      );
    }
    _moving = target;
    _sessionId = target.sessionId;
    final newDay = (p.day != null && _d(p.day!) != _d(target.start))
        ? p.day
        : null;
    return _offer(
      ParsedRequest(
        AssistantIntent.reschedule,
        day: newDay,
        part: p.part,
        hour: p.hour,
      ),
    );
  }

  /// User tapped one of the listed appointments.
  Future<AssistantReply> choose(Appointment a) async {
    if (_choosingForCancel) {
      _choosingForCancel = false;
      return AssistantReply(
        '¿Cancelo tu cita del ${assistantDay(a.start, _now())} a las ${assistantTime(a.start)}?',
        action: AssistantAction.confirmCancel,
        appointments: [a],
      );
    }
    _moving = a;
    _sessionId = a.sessionId;
    return _offer(const ParsedRequest(AssistantIntent.reschedule));
  }

  Future<AssistantReply> _offer(ParsedRequest p) async {
    final s = session!;
    final now = _now();
    final from = p.day ?? _d(now);
    final raw = await slots(s.id, from, p.day == null ? 14 : 1);
    var dayList = p.day == null
        ? raw
        : raw.where((x) => _d(x) == _d(p.day!)).toList();
    var filtered = filterSlots(dayList, part: p.part, hour: p.hour);
    final prefix = _moving == null
        ? ''
        : 'Vamos a mover tu cita del ${assistantDay(_moving!.start, now)}. ';

    if (p.day != null && filtered.isEmpty) {
      // Nothing that day: look ahead a week from the requested day.
      final ahead = await slots(
        s.id,
        _d(p.day!).add(const Duration(days: 1)),
        7,
      );
      final alt = filterSlots(ahead, part: p.part, hour: p.hour);
      final pick = alt.isNotEmpty ? alt : ahead;
      if (pick.isEmpty) {
        return AssistantReply(
          '$prefix${_who(s)} no tiene horarios libres el ${assistantDay(p.day!, now)} ni en los días siguientes. Prueba con otra fecha.',
          suggestions: const ['Mis citas'],
        );
      }
      final first = _d(pick.first);
      final list = pick.where((x) => _d(x) == first).take(8).toList();
      _lastDay = first;
      return AssistantReply(
        '${prefix}El ${assistantDay(p.day!, now)} no hay espacio${p.part != null || p.hour != null ? ' en ese horario' : ''}. '
        'El siguiente día con lugar es el ${assistantDay(first, now)}:',
        action: AssistantAction.showSlots,
        slots: list,
      );
    }
    if (filtered.isEmpty) {
      filtered = p.day == null ? raw : dayList;
      if (filtered.isEmpty) {
        return AssistantReply(
          '$prefix${_who(s)} no tiene horarios libres en las próximas dos semanas. Intenta más adelante o pregúntale en tu próxima consulta.',
          suggestions: const ['Mis citas'],
        );
      }
    }
    final first = _d(filtered.first);
    final list = filtered.where((x) => _d(x) == first).take(8).toList();
    _lastDay = first;
    return AssistantReply(
      '${prefix}Estos son los horarios libres de ${_who(s)} el ${assistantDay(first, now)}:',
      action: AssistantAction.showSlots,
      slots: list,
      suggestions: const ['Otro día', 'Por la tarde', 'Por la mañana'],
    );
  }

  /// Slot chip tapped: book (or reschedule) directly through the RPC.
  Future<AssistantReply> pick(DateTime start) async {
    final s = session!;
    final moving = _moving;
    try {
      if (moving != null) {
        await reschedule(moving.id, start);
      } else {
        await book(s.id, start);
      }
    } on FormatException catch (e) {
      return AssistantReply(
        '${e.message} Elige otro horario.',
        suggestions: const ['Otro día'],
      );
    }
    _moving = null;
    _lastDay = null;
    final booked = Appointment(
      id: '',
      sessionId: s.id,
      start: start,
      end: start.add(const Duration(minutes: 45)),
      status: 'confirmed',
      modality: 'in_person',
      specialty: s.specialty,
      professional: s.professional,
    );
    final tail = moving == null
        ? ''
        : ' Tu cita del ${assistantDay(moving.start, _now())} a las ${assistantTime(moving.start)} quedó cancelada.';
    return AssistantReply(
      'Listo, tu cita quedó registrada.$tail',
      action: AssistantAction.bookingConfirmed,
      booking: booked,
      suggestions: const ['Mis citas'],
    );
  }

  Future<AssistantReply> confirmCancel(Appointment a) async {
    try {
      await cancel(a.id);
    } on FormatException catch (e) {
      return AssistantReply(e.message);
    }
    return AssistantReply(
      'Cancelé tu cita del ${assistantDay(a.start, _now())} a las ${assistantTime(a.start)}. ${a.professional} lo verá en su agenda. ¿Quieres agendar otra?',
      suggestions: const ['Agendar una cita'],
    );
  }

  /// "Otro día": next day after the last offered slots.
  Future<AssistantReply> nextDay(DateTime after) => _offer(
    ParsedRequest(
      AssistantIntent.book,
      day: _d(after).add(const Duration(days: 1)),
    ),
  );

  void stopRescheduling() => _moving = null;
}
