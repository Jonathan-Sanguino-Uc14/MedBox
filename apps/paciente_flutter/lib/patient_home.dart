import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'appointment_assistant.dart';
import 'data.dart';
import 'exercise_demo.dart';
import 'screens.dart';
import 'specialty_screen.dart';
import 'territory_screens.dart';
import 'theme.dart';

/// Observatorio estacional y farmacias quedan fuera del SaaS doctor–paciente.
const showPublicHealth = false;

const _weekdays = [
  'lunes',
  'martes',
  'miércoles',
  'jueves',
  'viernes',
  'sábado',
  'domingo',
];
const _weekdayShort = ['LUN', 'MAR', 'MIÉ', 'JUE', 'VIE', 'SÁB', 'DOM'];
const _weekdayLetter = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];
const _months = [
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
const _monthShort = [
  'ene',
  'feb',
  'mar',
  'abr',
  'may',
  'jun',
  'jul',
  'ago',
  'sep',
  'oct',
  'nov',
  'dic',
];

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);
String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
String _hm(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
String _longDate(DateTime d) =>
    '${_cap(_weekdays[d.weekday - 1])} ${d.day} de ${_months[d.month - 1]}';
String _shortDate(DateTime d) => '${d.day} ${_monthShort[d.month - 1]}';
String _relDay(DateTime d) {
  final diff = _day(d).difference(_day(DateTime.now())).inDays;
  if (diff == 0) return 'Hoy';
  if (diff == -1) return 'Ayer';
  if (diff == 1) return 'Mañana';
  if (diff > 1 && diff < 7) return _cap(_weekdays[d.weekday - 1]);
  return _shortDate(d);
}

/// Everything one active session shows in the app (same tables the panel reads).
class SessionData {
  SessionData(this.session, this.activities, this.records, this.reviews);
  final CareSession session;
  final List<CareActivity> activities;
  final List<CareRecord> records; // newest first
  final List<CareReview> reviews;

  Specialty get specialty => session.specialty;
  late final Set<String> reviewed = reviews.map((r) => r.recordId).toSet();

  bool isReviewed(CareRecord r) => reviewed.contains(r.id);

  /// Same wording as the panel: "en revisión" here = "por revisar" there.
  String reviewState(CareRecord r) =>
      isReviewed(r) ? 'Revisado' : 'En revisión';

  /// Activities still in force (no due date or due today or later).
  List<CareActivity> get current {
    final today = _day(DateTime.now());
    return activities
        .where((a) => a.dueOn == null || !_day(a.dueOn!).isBefore(today))
        .toList();
  }

  CareRecord? todayRecord(CareActivity a) {
    final today = _day(DateTime.now());
    for (final r in records) {
      if (r.activityId == a.id && _day(r.date) == today) return r;
    }
    return null;
  }

  String activityTitle(String? id) {
    for (final a in activities) {
      if (a.id == id) return a.title;
    }
    return 'Registro libre';
  }

  Set<DateTime> get activeDays => records.map((r) => _day(r.date)).toSet();

  /// Consecutive days with at least one submission, ending today (or yesterday).
  int get streak {
    final days = activeDays;
    var cursor = _day(DateTime.now());
    if (!days.contains(cursor)) {
      cursor = cursor.subtract(const Duration(days: 1));
    }
    var n = 0;
    while (days.contains(cursor)) {
      n++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return n;
  }

  /// Panel formula (specialty-workspace.tsx resumen): completed records in the
  /// week / active activities, capped at 100. [weeksAgo] 0 = last 7 days.
  int weekCompliance(int weeksAgo) {
    final now = DateTime.now();
    final end = now.subtract(Duration(days: 7 * weeksAgo));
    final start = end.subtract(const Duration(days: 7));
    final done = records
        .where(
          (r) =>
              r.completed == true &&
              !r.date.isBefore(start) &&
              r.date.isBefore(end),
        )
        .length;
    final total = math.max(1, activities.length);
    return math.min(100, (100 * done / total).round());
  }

  CareReview? get lastReview => reviews.isEmpty ? null : reviews.last;

  CareRecord? recordOf(CareReview v) {
    for (final r in records) {
      if (r.id == v.recordId) return r;
    }
    return null;
  }
}

class HomeData {
  HomeData(
    this.sessions,
    this.appointments,
    this.name,
    this.requests,
    this.myId,
  );
  final List<SessionData> sessions;
  final List<Appointment> appointments;
  final String? name;
  final List<LinkRequest> requests;
  final String? myId;

  List<Appointment> get upcoming =>
      appointments
          .where((a) => a.live && a.end.isAfter(DateTime.now()))
          .toList()
        ..sort((a, b) => a.start.compareTo(b.start));
  List<Appointment> get past =>
      appointments
          .where((a) => !a.live || !a.end.isAfter(DateTime.now()))
          .toList()
        ..sort((a, b) => b.start.compareTo(a.start));

  SessionData? sessionById(String id) {
    for (final s in sessions) {
      if (s.session.id == id) return s;
    }
    return null;
  }
}

class ShellNotice {
  const ShellNotice(
    this.icon,
    this.color,
    this.title,
    this.body,
    this.date,
    this.tab,
  );
  final IconData icon;
  final Color color;
  final String title, body;
  final DateTime date;
  final int tab;
}

/// Patient app: Hoy · Progreso · Mensajes · Perfil, with a notifications bell.
class PatientShell extends StatefulWidget {
  const PatientShell({super.key, required this.repository});
  final CareRepository repository;
  @override
  State<PatientShell> createState() => PatientShellState();
}

class PatientShellState extends State<PatientShell> {
  int tab = 0;
  int selected = 0;
  int period = 0; // 0 semana, 1 mes, 2 todo
  int messagesTab = 0;

  /// Assistant conversation survives tab switches while the app is open.
  final Map<String, AppointmentAssistant> assistants = {};
  final Map<String, List<ChatEntry>> chats = {};
  final PageController pages = PageController();

  /// Index of «Mis citas» inside Mensajes (after one tab per specialist).
  int citasTab(HomeData h) => h.sessions.length;

  /// Moves to a main tab (and optionally a Mensajes tab) with animation.
  void goTo(int value, {int? messages}) {
    setState(() {
      tab = value;
      if (messages != null) messagesTab = messages;
    });
    if (pages.hasClients) {
      pages.animateToPage(
        value,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  void dispose() {
    pages.dispose();
    super.dispose();
  }

  DateTime seenAt = DateTime.now().subtract(const Duration(days: 3));
  late Future<HomeData> future = load();

  CareRepository get repo => widget.repository;

  Future<HomeData> load() async {
    final sessions = (await repo.sessions()).where((s) => s.active).toList();
    final data = await Future.wait(
      sessions.map((s) async {
        final r = await Future.wait([
          repo.activities(s.id),
          repo.records(s.id),
          repo.reviews(s.id),
        ]);
        return SessionData(
          s,
          r[0] as List<CareActivity>,
          r[1] as List<CareRecord>,
          r[2] as List<CareReview>,
        );
      }),
    );
    List<Appointment> appts = const [];
    String? name;
    List<LinkRequest> requests = const [];
    try {
      appts = await repo.myAppointments();
    } catch (_) {}
    try {
      name = await repo.myName();
    } catch (_) {}
    try {
      requests = repo.demo ? const [] : await repo.myRequests();
    } catch (_) {}
    return HomeData(data, appts, name, requests, repo.myId);
  }

  void reload() => setState(() {
    future = load();
  });

  void update(VoidCallback fn) => setState(fn);

  ThemeData accentTheme(Specialty s) => Theme.of(context).copyWith(
    colorScheme: Theme.of(context).colorScheme.copyWith(primary: s.accent),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: s.accent,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
  );

  Future<void> push(Widget screen, {Specialty? specialty}) async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => specialty == null
            ? screen
            : Theme(data: accentTheme(specialty), child: screen),
      ),
    );
    if (mounted) reload();
  }

  void openSession(CareSession s) =>
      push(SpecialtyScreen(session: s, repository: repo));
  void link() => push(LinkScreen(repository: repo));

  void startActivity(SessionData d, CareActivity a) {
    if (d.specialty.allowsPhysicalExercise(a.isExercise)) {
      push(
        ExerciseDemoScreen(session: d.session, activity: a, repository: repo),
        specialty: d.specialty,
      );
    } else {
      push(
        RecordScreen(session: d.session, repository: repo, activityId: a.id),
        specialty: d.specialty,
      );
    }
  }

  List<ShellNotice> notices(HomeData h) {
    final out = <ShellNotice>[];
    final now = DateTime.now();
    for (final d in h.sessions) {
      for (final v in d.reviews) {
        if (now.difference(v.date).inDays > 14) continue;
        final rec = d.recordOf(v);
        out.add(
          ShellNotice(
            Icons.rate_review_outlined,
            d.specialty.accent,
            'Revisión de ${d.session.professional}',
            '${d.activityTitle(rec?.activityId)}: «${v.body}»',
            v.date,
            0,
          ),
        );
      }
    }
    for (final a in h.upcoming) {
      if (a.start.difference(now).inHours > 72) continue;
      out.add(
        ShellNotice(
          Icons.event_available_outlined,
          MedColors.brand,
          'Cita ${_relDay(a.start).toLowerCase()} a las ${_hm(a.start)}',
          '${a.professional} · ${a.modalityLabel} · ${a.statusLabel}',
          a.start.subtract(const Duration(days: 1)),
          2,
        ),
      );
    }
    for (final a in h.appointments) {
      if (a.status == 'cancelled' &&
          a.cancelledBy != null &&
          a.cancelledBy != h.myId &&
          a.start.isAfter(now)) {
        out.add(
          ShellNotice(
            Icons.event_busy_outlined,
            MedColors.danger,
            'Tu especialista canceló una cita',
            '${_longDate(a.start)} · ${_hm(a.start)}. Puedes agendar otro horario.',
            a.start.subtract(const Duration(days: 2)),
            2,
          ),
        );
      }
    }
    out.sort((a, b) => b.date.compareTo(a.date));
    return out;
  }

  void openNotices(HomeData h) {
    final list = notices(h);
    setState(() => seenAt = DateTime.now());
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          children: [
            Text('Notificaciones', style: heading(20)),
            const SizedBox(height: 12),
            if (list.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  'No tienes avisos nuevos.',
                  style: TextStyle(color: MedColors.muted),
                ),
              ),
            for (final n in list)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: n.color.withValues(alpha: .12),
                  child: Icon(n.icon, color: n.color, size: 20),
                ),
                title: Text(
                  n.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                subtitle: Text(
                  n.body,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  goTo(n.tab, messages: n.tab == 2 ? h.sessions.length : null);
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<HomeData>(
    future: future,
    builder: (context, snap) {
      final h = snap.data;
      final accent = (h == null || h.sessions.isEmpty)
          ? MedColors.brand
          : h
                .sessions[math.min(selected, h.sessions.length - 1)]
                .specialty
                .accent;
      Widget body;
      if (snap.hasError) {
        body = PageBody(
          children: [
            const SectionTitle('No pudimos cargar tu seguimiento'),
            Text(friendlyError(snap.error!)),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: reload,
              child: const Text('Volver a intentar'),
            ),
          ],
        );
      } else if (h == null) {
        body = const Center(child: CircularProgressIndicator());
      } else {
        body = PageView(
          controller: pages,
          onPageChanged: (v) => setState(() => tab = v),
          children: [
            _KeepAlive(
              child: TodayTab(state: this, home: h),
            ),
            _KeepAlive(
              child: ProgressTab(state: this, home: h),
            ),
            _KeepAlive(
              child: MessagesTab(state: this, home: h),
            ),
            _KeepAlive(
              child: ProfileTab(state: this, home: h),
            ),
          ],
        );
      }
      return Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              if (repo.demo)
                Container(
                  width: double.infinity,
                  color: MedColors.brandSoft,
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  child: const Text(
                    'EXPLORANDO SIN CUENTA · Lo que registres no se guarda',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      color: MedColors.brandDeep,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              Expanded(child: body),
            ],
          ),
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: tab,
          onDestinationSelected: goTo,
          indicatorColor: accent.withValues(alpha: .12),
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded, color: accent),
              label: 'Hoy',
            ),
            NavigationDestination(
              icon: const Icon(Icons.bar_chart_outlined),
              selectedIcon: Icon(Icons.bar_chart_rounded, color: accent),
              label: 'Progreso',
            ),
            NavigationDestination(
              icon: const Icon(Icons.chat_bubble_outline),
              selectedIcon: Icon(Icons.chat_bubble_rounded, color: accent),
              label: 'Mensajes',
            ),
            NavigationDestination(
              icon: const Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person_rounded, color: accent),
              label: 'Perfil',
            ),
          ],
        ),
      );
    },
  );
}

// ------------------------------------------------------------------ pieces

class _Panel extends StatelessWidget {
  const _Panel({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color = Colors.white,
    this.border,
  });
  final Widget child;
  final EdgeInsets padding;
  final Color color;
  final Color? border;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: padding,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(16),
      border: border == null ? null : Border.all(color: border!, width: 2),
    ),
    child: child,
  );
}

class _Scroll extends StatelessWidget {
  const _Scroll({required this.children, this.onRefresh});
  final List<Widget> children;
  final Future<void> Function()? onRefresh;
  @override
  Widget build(BuildContext context) {
    final list = Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) const SizedBox(height: 16),
              children[i],
            ],
          ],
        ),
      ),
    );
    return onRefresh == null
        ? list
        : RefreshIndicator(onRefresh: onRefresh!, child: list);
  }
}

class _SessionChips extends StatelessWidget {
  const _SessionChips({required this.state, required this.home});
  final PatientShellState state;
  final HomeData home;
  @override
  Widget build(BuildContext context) {
    if (home.sessions.length < 2) return const SizedBox.shrink();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < home.sessions.length; i++)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                selected: state.selected == i,
                showCheckmark: false,
                avatar: Icon(
                  home.sessions[i].specialty.icon,
                  size: 18,
                  color: state.selected == i
                      ? Colors.white
                      : home.sessions[i].specialty.accent,
                ),
                label: Text(home.sessions[i].specialty.label),
                labelStyle: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: state.selected == i ? Colors.white : MedColors.ink,
                ),
                selectedColor: home.sessions[i].specialty.accent,
                backgroundColor: Colors.white,
                side: BorderSide.none,
                onSelected: (_) => state.update(() => state.selected = i),
              ),
            ),
        ],
      ),
    );
  }
}

Widget _statusDot(Color bg, Color fg, IconData icon) => Container(
  width: 28,
  height: 28,
  decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
  child: Icon(icon, size: 16, color: fg),
);

String _activityDose(CareActivity a) {
  final parts = <String>[];
  if (a.targetSets != null && a.targetReps != null) {
    parts.add('${a.targetSets} series × ${a.targetReps}');
  } else if (a.targetReps != null) {
    parts.add('${a.targetReps} repeticiones');
  }
  if (a.exercise != null) {
    parts.add('cuenta la cámara');
  } else if (a.isExercise) {
    parts.add('con video');
  }
  if (a.dueOn != null) parts.add('hasta ${_shortDate(a.dueOn!)}');
  return parts.isEmpty
      ? (a.instructions.isEmpty
            ? 'Indicación de tu especialista'
            : a.instructions)
      : parts.join(' · ');
}

// ------------------------------------------------------------------ Hoy

class TodayTab extends StatelessWidget {
  const TodayTab({super.key, required this.state, required this.home});
  final PatientShellState state;
  final HomeData home;

  @override
  Widget build(BuildContext context) {
    final unseen = state
        .notices(home)
        .where((n) => n.date.isAfter(state.seenAt))
        .length;
    final first = home.name?.trim().split(' ').first;
    final header = Row(
      children: [
        const Brand(height: 30),
        const Spacer(),
        Semantics(
          button: true,
          label: unseen == 0
              ? 'Notificaciones'
              : 'Notificaciones, $unseen nuevas',
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => state.openNotices(home),
              child: SizedBox(
                width: 44,
                height: 44,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    const Icon(
                      Icons.notifications_none_rounded,
                      color: MedColors.ink,
                    ),
                    if (unseen > 0)
                      Positioned(
                        top: 7,
                        right: 7,
                        child: Container(
                          constraints: const BoxConstraints(minWidth: 16),
                          height: 16,
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            color: MedColors.danger,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '$unseen',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
    final greeting = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _longDate(DateTime.now()),
          style: const TextStyle(
            fontSize: 13,
            color: MedColors.muted,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          first == null || first.isEmpty
              ? 'Hola, qué gusto verte'
              : 'Hola, $first',
          style: heading(26),
        ),
      ],
    );
    if (home.sessions.isEmpty) {
      return _Scroll(
        onRefresh: () async => state.reload(),
        children: [
          header,
          greeting,
          _Panel(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Conecta con tu especialista', style: heading(18)),
                const SizedBox(height: 6),
                const Text(
                  'Pídele tu código de invitación. Cuando apruebe tu solicitud, aquí verás tu plan, tus citas y sus revisiones.',
                  style: TextStyle(color: MedColors.body),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: state.link,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Vincular con un código'),
                ),
              ],
            ),
          ),
          ..._requests(home),
        ],
      );
    }
    final d = home.sessions[math.min(state.selected, home.sessions.length - 1)];
    final s = d.specialty;
    final acts = d.current;
    final doneToday = acts.where((a) => d.todayRecord(a) != null).length;
    final pending = acts.where((a) => d.todayRecord(a) == null).toList();
    final unit = s == Specialty.physio
        ? (acts.length == 1 ? 'ejercicio' : 'ejercicios')
        : (acts.length == 1 ? 'actividad' : 'actividades');
    final next =
        home.upcoming.where((a) => a.sessionId == d.session.id).firstOrNull ??
        home.upcoming.firstOrNull;
    final review = d.lastReview;
    final today = _day(DateTime.now());
    final days = d.activeDays;

    final hero = Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: s.accent,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  d.session.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .18),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'Racha: ${d.streak} ${d.streak == 1 ? 'día' : 'días'}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (acts.isEmpty)
            const Text(
              'Tu especialista aún no te asigna actividades.',
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            )
          else ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text('$doneToday', style: heading(40, color: Colors.white)),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'de ${acts.length} $unit hoy',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: doneToday / acts.length,
                minHeight: 8,
                color: Colors.white,
                backgroundColor: Colors.white.withValues(alpha: .25),
              ),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              for (var i = 6; i >= 0; i--)
                Expanded(
                  child: Builder(
                    builder: (_) {
                      final day = today.subtract(Duration(days: i));
                      final on = days.contains(day);
                      return Column(
                        children: [
                          Container(
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                              color: on
                                  ? Colors.white
                                  : Colors.white.withValues(alpha: .18),
                              shape: BoxShape.circle,
                            ),
                            child: on
                                ? Icon(
                                    Icons.check_rounded,
                                    size: 15,
                                    color: s.accent,
                                  )
                                : null,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _weekdayLetter[day.weekday - 1],
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
            ],
          ),
        ],
      ),
    );

    final focus = pending.firstOrNull;
    final plan = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Tu plan de hoy', style: heading(17, weight: FontWeight.w700)),
        const SizedBox(height: 10),
        if (acts.isEmpty)
          const _Panel(
            child: Text(
              'Cuando tu especialista te asigne algo, aparecerá aquí.',
              style: TextStyle(color: MedColors.muted),
            ),
          ),
        if (focus != null)
          _Panel(
            border: s.accent,
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: s.soft,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        focus.isExercise
                            ? Icons.fitness_center_rounded
                            : s.icon,
                        color: s.accent,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            focus.title,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            _activityDose(focus),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              color: MedColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: s.accent,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => state.startActivity(d, focus),
                  icon: Icon(
                    s.allowsPhysicalExercise(focus.isExercise)
                        ? Icons.videocam_outlined
                        : Icons.edit_note_rounded,
                  ),
                  label: Text(
                    s.allowsPhysicalExercise(focus.isExercise)
                        ? 'Ver demostración y grabar'
                        : s.completedLabel,
                  ),
                ),
              ],
            ),
          ),
        for (final a in acts.where((a) => a != focus)) ...[
          const SizedBox(height: 10),
          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => state.startActivity(d, a),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                child: Builder(
                  builder: (_) {
                    final r = d.todayRecord(a);
                    return Row(
                      children: [
                        r != null
                            ? _statusDot(s.soft, s.accent, Icons.check_rounded)
                            : _statusDot(
                                const Color(0xFFF1F4F8),
                                MedColors.muted,
                                Icons.schedule_rounded,
                              ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                a.title,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                r != null
                                    ? 'Enviado ${_hm(r.date)} · ${d.reviewState(r).toLowerCase()}'
                                    : _activityDose(a),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: MedColors.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ],
    );

    return _Scroll(
      onRefresh: () async => state.reload(),
      children: [
        header,
        greeting,
        _SessionChips(state: state, home: home),
        hero,
        plan,
        if (next != null)
          _AppointmentTile(
            appt: next,
            onTap: () => state.goTo(2, messages: state.citasTab(home)),
          ),
        if (next == null && !state.repo.demo)
          _Panel(
            child: Row(
              children: [
                const Icon(Icons.event_outlined, color: MedColors.brand),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Sin citas próximas',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                TextButton(
                  onPressed: () => state.goTo(
                    2,
                    messages: math.min(
                      state.selected,
                      home.sessions.length - 1,
                    ),
                  ),
                  child: const Text('Agendar'),
                ),
              ],
            ),
          ),
        if (review != null)
          _Panel(
            color: MedColors.warnSoft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Revisión ${_relDay(review.date).toLowerCase()} · ${d.activityTitle(d.recordOf(review)?.activityId).toLowerCase()}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: MedColors.warn,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '«${review.body}»',
                  style: const TextStyle(fontSize: 14, color: MedColors.body),
                ),
              ],
            ),
          ),
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => state.openSession(d.session),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
            child: Row(
              children: [
                Icon(Icons.folder_open_outlined, color: s.accent, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Ver todo mi seguimiento de ${s.label.toLowerCase()}',
                    style: TextStyle(
                      color: s.accentDeep,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: s.accent),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

List<Widget> _requests(HomeData home) {
  final open = home.requests.where((r) => r.status != 'approved').toList();
  if (open.isEmpty) return const [];
  return [
    Text('Tus solicitudes', style: heading(16, weight: FontWeight.w700)),
    for (final r in open)
      _Panel(
        child: Row(
          children: [
            Icon(r.specialty.icon, color: r.specialty.accent),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                r.specialty.label,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            Text(
              requestStatusLabels[r.status] ?? r.status,
              style: const TextStyle(
                fontSize: 12,
                color: MedColors.warn,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
  ];
}

class _AppointmentTile extends StatelessWidget {
  const _AppointmentTile({required this.appt, this.onTap});
  final Appointment appt;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final cancelled = !appt.live;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: cancelled
                      ? const Color(0xFFF1F4F8)
                      : MedColors.brandSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _weekdayShort[appt.start.weekday - 1],
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: cancelled
                            ? MedColors.muted
                            : MedColors.brandDeep,
                      ),
                    ),
                    Text(
                      '${appt.start.day}',
                      style: heading(
                        16,
                        color: cancelled
                            ? MedColors.muted
                            : MedColors.brandDeep,
                      ).copyWith(height: 1),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      appt.professional.isEmpty
                          ? 'Cita'
                          : 'Cita con ${appt.professional}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        decoration: cancelled
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                    Text(
                      '${_hm(appt.start)} · ${appt.modalityLabel.toLowerCase()} · ${appt.statusLabel}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: MedColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              if (onTap != null)
                const Icon(Icons.chevron_right_rounded, color: MedColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ Progreso

class ProgressTab extends StatelessWidget {
  const ProgressTab({super.key, required this.state, required this.home});
  final PatientShellState state;
  final HomeData home;

  @override
  Widget build(BuildContext context) {
    if (home.sessions.isEmpty) {
      return _Scroll(
        children: [
          Text('Tu progreso', style: heading(26)),
          const _Panel(
            child: Text(
              'Cuando tengas un plan activo verás aquí tu cumplimiento, tus registros y las revisiones de tu especialista.',
              style: TextStyle(color: MedColors.muted),
            ),
          ),
        ],
      );
    }
    final d = home.sessions[math.min(state.selected, home.sessions.length - 1)];
    final s = d.specialty;
    final weeks = [1, 4, 26][state.period];
    final from = DateTime.now().subtract(Duration(days: 7 * weeks));
    final inPeriod = d.records.where((r) => r.date.isAfter(from)).toList();
    final weekly = [for (var i = 0; i < weeks; i++) d.weekCompliance(i)];
    final compliance = weekly.isEmpty
        ? 0
        : (weekly.reduce((a, b) => a + b) / weekly.length).round();
    final pains = inPeriod.reversed
        .map((r) => r.reportedPain)
        .whereType<int>()
        .toList();
    final allPains = d.records.reversed
        .map((r) => r.reportedPain)
        .whereType<int>()
        .toList();
    final avgPain = pains.isEmpty
        ? null
        : pains.reduce((a, b) => a + b) / pains.length;
    final physio = s == Specialty.physio;
    final bars = [for (var i = 5; i >= 0; i--) d.weekCompliance(i)];
    final reviewedCount = d.records.where(d.isReviewed).length;
    final fullMonth = [for (var i = 0; i < 4; i++) d.weekCompliance(i)]
        .every((v) => v > 0);
    final badges = [
      (
        Icons.local_fire_department_outlined,
        'Racha de 5 días',
        d.streak >= 5,
        const Color(0xFFFFF1DB),
        const Color(0xFFB45309),
      ),
      (
        Icons.task_alt_rounded,
        '20 envíos',
        d.records.length >= 20,
        s.soft,
        s.accent,
      ),
      (
        Icons.calendar_month_outlined,
        'Mes completo',
        fullMonth,
        MedColors.brandSoft,
        MedColors.brand,
      ),
    ];

    Widget stat(String label, String value, String sub, {Color? color}) =>
        Expanded(
          child: _Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: MedColors.muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(value, style: heading(28, color: color ?? MedColors.ink)),
                Text(
                  sub,
                  style: const TextStyle(fontSize: 12, color: MedColors.muted),
                ),
              ],
            ),
          ),
        );

    return _Scroll(
      onRefresh: () async => state.reload(),
      children: [
        Text('Tu progreso', style: heading(26)),
        _SessionChips(state: state, home: home),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              for (final (i, label) in const ['Semana', 'Mes', 'Todo'].indexed)
                Expanded(
                  child: Semantics(
                    selected: state.period == i,
                    button: true,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(9),
                      onTap: () => state.update(() => state.period = i),
                      child: Container(
                        height: 38,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: state.period == i
                              ? s.soft
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Text(
                          label,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: state.period == i
                                ? FontWeight.w700
                                : FontWeight.w600,
                            color: state.period == i
                                ? s.accentDeep
                                : MedColors.muted,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        Row(
          children: [
            stat(
              'Cumplimiento',
              '$compliance%',
              'esta semana: ${d.weekCompliance(0)}%',
              color: s.accentDeep,
            ),
            const SizedBox(width: 12),
            physio
                ? stat(
                    'Dolor promedio',
                    avgPain == null ? '–' : avgPain.toStringAsFixed(1),
                    allPains.isEmpty
                        ? 'sin registros'
                        : 'al inicio: ${allPains.first}',
                  )
                : stat(
                    'Registros',
                    '${inPeriod.length}',
                    '$reviewedCount revisados en total',
                  ),
          ],
        ),
        if (physio)
          _Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cómo va tu dolor',
                  style: heading(16, weight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                if (allPains.length < 2)
                  const Text(
                    'Necesitamos al menos dos envíos con dolor reportado para mostrar la tendencia.',
                    style: TextStyle(color: MedColors.muted, fontSize: 13),
                  )
                else ...[
                  Semantics(
                    label:
                        'Dolor por envío: ${allPains.length > 12 ? allPains.sublist(allPains.length - 12).join(', ') : allPains.join(', ')} de 10',
                    child: SizedBox(
                      height: 130,
                      width: double.infinity,
                      child: CustomPaint(
                        painter: _PainPainter(
                          allPains.length > 12
                              ? allPains.sublist(allPains.length - 12)
                              : allPains,
                          s.accent,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _painSentence(allPains.first, allPains.last),
                    style: const TextStyle(fontSize: 13, color: MedColors.body),
                  ),
                ],
              ],
            ),
          ),
        _Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Cumplimiento semanal',
                style: heading(16, weight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 120,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (var i = 0; i < 6; i++)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 5),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(
                                '${bars[i]}%',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: MedColors.muted,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                height: math.max(4, bars[i] * 0.8),
                                decoration: BoxDecoration(
                                  color: i == 5 ? s.accent : s.faded,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _shortDate(
                                  DateTime.now().subtract(
                                    Duration(days: 7 * (6 - i)),
                                  ),
                                ),
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: MedColors.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Text('Logros', style: heading(16, weight: FontWeight.w700)),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (i, b) in badges.indexed) ...[
                if (i > 0) const SizedBox(width: 10),
                Expanded(
                  child: Opacity(
                    opacity: b.$3 ? 1 : .55,
                    child: _Panel(
                      padding: const EdgeInsets.symmetric(
                        vertical: 14,
                        horizontal: 8,
                      ),
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 22,
                            backgroundColor: b.$4,
                            child: Icon(b.$1, color: b.$5, size: 20),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            b.$2,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        _Panel(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Envíos recientes',
                style: heading(16, weight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              if (inPeriod.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'Sin envíos en este periodo.',
                    style: TextStyle(color: MedColors.muted),
                  ),
                ),
              for (final r in inPeriod.take(8))
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: Color(0xFFEEF1F5))),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              d.activityTitle(r.activityId),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              _recordLine(r),
                              style: const TextStyle(
                                fontSize: 12,
                                color: MedColors.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        d.reviewState(r),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: d.isReviewed(r)
                              ? s.accentDeep
                              : MedColors.warn,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

String _recordLine(CareRecord r) {
  final parts = [_relDay(r.date)];
  final m = r.metrics;
  if (m != null && m['complete_reps'] != null) {
    final target = m['target_reps'];
    parts.add(
      target == null
          ? '${m['complete_reps']} reps'
          : '${m['complete_reps']}/$target reps',
    );
  }
  if (r.reportedPain != null) parts.add('dolor ${r.reportedPain}');
  if (r.completed == false) parts.add('no completada');
  return parts.join(' · ');
}

String _painSentence(int first, int last) {
  final diff = first - last;
  if (diff > 0) {
    return 'Bajó $diff ${diff == 1 ? 'punto' : 'puntos'} desde que empezaste. Sigue así.';
  }
  if (diff < 0) {
    return 'Subió ${-diff} ${diff == -1 ? 'punto' : 'puntos'}. Coméntalo con tu especialista.';
  }
  return 'Se mantiene igual que al inicio.';
}

class _PainPainter extends CustomPainter {
  _PainPainter(this.values, this.color);
  final List<int> values;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    const px = 22.0, py = 8.0;
    final grid = Paint()
      ..color = MedColors.line
      ..strokeWidth = 1;
    final label = TextPainter(textDirection: TextDirection.ltr);
    double y(int v) => size.height - py - (v / 10) * (size.height - 2 * py);
    for (final v in const [0, 5, 10]) {
      canvas.drawLine(Offset(px, y(v)), Offset(size.width, y(v)), grid);
      label
        ..text = TextSpan(
          text: '$v',
          style: const TextStyle(fontSize: 10, color: MedColors.muted),
        )
        ..layout();
      label.paint(
        canvas,
        Offset(px - 6 - label.width, y(v) - label.height / 2),
      );
    }
    final pts = [
      for (var i = 0; i < values.length; i++)
        Offset(
          px + 4 + i * (size.width - px - 10) / math.max(1, values.length - 1),
          y(values[i]),
        ),
    ];
    final area = Path()..moveTo(pts.first.dx, y(0));
    for (final p in pts) {
      area.lineTo(p.dx, p.dy);
    }
    area
      ..lineTo(pts.last.dx, y(0))
      ..close();
    canvas.drawPath(area, Paint()..color = color.withValues(alpha: .08));
    final line = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (final p in pts.skip(1)) {
      line.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(
      line,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(pts.last, 5, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_PainPainter old) =>
      old.values != values || old.color != color;
}

// ------------------------------------------------------------------ Mensajes

/// Keeps a page alive when it scrolls out of a PageView/TabBarView.
class _KeepAlive extends StatefulWidget {
  const _KeepAlive({required this.child});
  final Widget child;
  @override
  State<_KeepAlive> createState() => _KeepAliveState();
}

class _KeepAliveState extends State<_KeepAlive>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

/// Mensajes: one appointment assistant per specialist plus «Mis citas».
/// Tabs can be changed by swiping.
class MessagesTab extends StatefulWidget {
  const MessagesTab({super.key, required this.state, required this.home});
  final PatientShellState state;
  final HomeData home;
  @override
  State<MessagesTab> createState() => _MessagesTabState();
}

class _MessagesTabState extends State<MessagesTab>
    with TickerProviderStateMixin {
  late TabController tabs = make();

  PatientShellState get shell => widget.state;
  int get count => widget.home.sessions.length + 1;

  TabController make() {
    final c = TabController(
      length: widget.home.sessions.length + 1,
      vsync: this,
      initialIndex: shell.messagesTab.clamp(0, widget.home.sessions.length),
    );
    c.addListener(() => shell.messagesTab = c.index);
    return c;
  }

  @override
  void didUpdateWidget(MessagesTab old) {
    super.didUpdateWidget(old);
    if (tabs.length != count) {
      tabs.dispose();
      tabs = make();
    } else {
      final want = shell.messagesTab.clamp(0, count - 1);
      if (tabs.index != want && !tabs.indexIsChanging) tabs.animateTo(want);
    }
  }

  @override
  void dispose() {
    tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sessions = widget.home.sessions;
    return Column(
      children: [
        Container(
          width: double.infinity,
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Mensajes', style: heading(22)),
              const SizedBox(height: 4),
              TabBar(
                controller: tabs,
                isScrollable: sessions.length > 1,
                tabAlignment: sessions.length > 1
                    ? TabAlignment.start
                    : TabAlignment.fill,
                labelColor: MedColors.ink,
                unselectedLabelColor: MedColors.muted,
                labelStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                indicatorColor: MedColors.brand,
                indicatorWeight: 2,
                dividerColor: Colors.transparent,
                tabs: [
                  for (final d in sessions)
                    Tab(
                      height: 52,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            d.specialty.icon,
                            size: 18,
                            color: d.specialty.accent,
                          ),
                          const SizedBox(width: 6),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                d.session.professional,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                d.specialty.label,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: MedColors.muted,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  const Tab(height: 52, text: 'Mis citas'),
                ],
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: MedColors.line),
        Expanded(
          child: TabBarView(
            controller: tabs,
            children: [
              for (final d in sessions)
                _KeepAlive(
                  child: AssistantChatView(
                    state: shell,
                    home: widget.home,
                    session: d,
                  ),
                ),
              _KeepAlive(
                child: AgendaView(state: shell, home: widget.home),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// One line of the assistant conversation.
class ChatEntry {
  ChatEntry.user(this.text) : mine = true, reply = null;
  ChatEntry.bot(AssistantReply r) : mine = false, text = r.text, reply = r;
  final bool mine;
  final String text;
  final AssistantReply? reply;

  /// Buttons of this entry were already used.
  bool used = false;
}

/// Chat with the appointment assistant (agenda only). Slot chips book directly.
class AssistantChatView extends StatefulWidget {
  const AssistantChatView({
    super.key,
    required this.state,
    required this.home,
    required this.session,
  });
  final PatientShellState state;
  final HomeData home;

  /// The specialist this bot schedules with (one independent bot each).
  final SessionData session;
  @override
  State<AssistantChatView> createState() => _AssistantChatViewState();
}

class _AssistantChatViewState extends State<AssistantChatView> {
  final input = TextEditingController();
  final scroll = ScrollController();
  bool busy = false;

  PatientShellState get shell => widget.state;
  String get id => widget.session.session.id;
  List<ChatEntry> get chat => shell.chats.putIfAbsent(id, () => []);
  AppointmentAssistant get bot => shell.assistants[id]!;

  @override
  void initState() {
    super.initState();
    final repo = shell.repo;
    final h = widget.home;
    AssistantSession of(SessionData d) =>
        AssistantSession(d.session.id, d.specialty, d.session.professional);
    shell.assistants[id] ??= AppointmentAssistant(
      sessions: [of(widget.session)],
      others: [
        for (final d in h.sessions)
          if (d.session.id != id) of(d),
      ],
      appointments: h.appointments,
      sessionId: id,
      slots: (id, from, days) => repo.availableSlots(id, from, days: days),
      book: (id, start) => repo.bookAppointment(id, start),
      reschedule: (id, start) => repo.rescheduleAppointment(id, start),
      cancel: (id) => repo.cancelAppointment(id),
    );
    if (chat.isEmpty) chat.add(ChatEntry.bot(bot.greeting()));
  }

  @override
  void didUpdateWidget(AssistantChatView old) {
    super.didUpdateWidget(old);
    shell.assistants[id]?.appointments = widget.home.appointments;
  }

  @override
  void dispose() {
    input.dispose();
    scroll.dispose();
    super.dispose();
  }

  void toBottom() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (scroll.hasClients) {
      scroll.animateTo(
        scroll.position.maxScrollExtent + 200,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  });

  Future<void> run(
    String userText,
    Future<AssistantReply> Function() action, {
    bool refresh = false,
  }) async {
    if (busy) return;
    setState(() {
      for (final e in chat) {
        e.used = true;
      }
      chat.add(ChatEntry.user(userText));
      busy = true;
    });
    toBottom();
    AssistantReply reply;
    try {
      reply = await action();
    } catch (e) {
      reply = AssistantReply(
        friendlyError(e),
        suggestions: AppointmentAssistant.help,
      );
    }
    if (!mounted) return;
    setState(() {
      chat.add(ChatEntry.bot(reply));
      busy = false;
    });
    toBottom();
    if (refresh || reply.action == AssistantAction.bookingConfirmed) {
      shell.reload();
    }
  }

  void send([String? preset]) {
    final text = (preset ?? input.text).trim();
    if (text.isEmpty) return;
    input.clear();
    run(text, () => bot.respond(text));
  }

  Widget bubble(ChatEntry e) {
    final mine = e.mine;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 310),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: mine ? widget.session.specialty.accent : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(mine ? 18 : 4),
            bottomRight: Radius.circular(mine ? 4 : 18),
          ),
        ),
        child: Text(
          e.text,
          style: TextStyle(
            fontSize: 14,
            height: 1.4,
            color: mine ? Colors.white : MedColors.ink,
          ),
        ),
      ),
    );
  }

  Widget extras(ChatEntry e, bool last) {
    final r = e.reply!;
    final a = bot;
    final now = DateTime.now();
    final children = <Widget>[];
    switch (r.action) {
      case AssistantAction.showSlots:
        children.add(
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final t in r.slots)
                ActionChip(
                  label: Text(assistantTime(t)),
                  onPressed: e.used || busy
                      ? null
                      : () => run(assistantTime(t), () => a.pick(t)),
                  backgroundColor: MedColors.brandSoft,
                  labelStyle: const TextStyle(
                    color: MedColors.brandDeep,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                  side: const BorderSide(color: Color(0xFFC9D5F2), width: 1.5),
                  shape: const StadiumBorder(),
                ),
            ],
          ),
        );
        if (!e.used) {
          children.add(
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text(
                'Toca un horario para confirmarlo.',
                style: TextStyle(fontSize: 12, color: MedColors.muted),
              ),
            ),
          );
        }
      case AssistantAction.chooseAppointment:
        for (final ap in r.appointments) {
          children.add(
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: OutlinedButton(
                onPressed: e.used || busy
                    ? null
                    : () => run(
                        '${_cap(assistantDay(ap.start, now))}, ${assistantTime(ap.start)}',
                        () => a.choose(ap),
                      ),
                child: Text(
                  '${_cap(assistantDay(ap.start, now))} · ${assistantTime(ap.start)} · ${ap.professional}',
                ),
              ),
            ),
          );
        }
      case AssistantAction.confirmCancel:
        final ap = r.appointments.first;
        children.add(
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: MedColors.danger,
                    minimumSize: const Size(0, 44),
                  ),
                  onPressed: e.used || busy
                      ? null
                      : () => run(
                          'Sí, cancelar',
                          () => a.confirmCancel(ap),
                          refresh: true,
                        ),
                  child: const Text('Sí, cancelar'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: e.used || busy
                      ? null
                      : () => run(
                          'No',
                          () async => const AssistantReply(
                            'De acuerdo, tu cita sigue en pie.',
                            suggestions: AppointmentAssistant.help,
                          ),
                        ),
                  child: const Text('No'),
                ),
              ),
            ],
          ),
        );
      case AssistantAction.bookingConfirmed:
        final b = r.booking!;
        children.add(
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFCDEBE5)),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  color: const Color(0xFFE8F6F3),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  child: const Row(
                    children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: Color(0xFF0F766E),
                        child: Icon(
                          Icons.check_rounded,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(width: 10),
                      Text(
                        'Cita confirmada',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0B5E57),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_cap(assistantDay(b.start, now))} · ${assistantTime(b.start)}',
                        style: heading(17),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${b.professional} · ${b.specialty?.label ?? ''}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: MedColors.body,
                        ),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton(
                        onPressed: () => shell.goTo(
                          2,
                          messages: shell.citasTab(widget.home),
                        ),
                        child: const Text('Ver mis citas'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      case AssistantAction.none:
        break;
    }
    if (last && !busy && r.suggestions.isNotEmpty) {
      children.add(
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final sgg in r.suggestions)
                ActionChip(
                  label: Text(sgg),
                  onPressed: () => send(sgg),
                  backgroundColor: Colors.white,
                  side: const BorderSide(color: Color(0xFFD5DCE7)),
                  shape: const StadiumBorder(),
                ),
            ],
          ),
        ),
      );
    }
    if (children.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 340),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (shell.repo.demo || widget.home.sessions.isEmpty) {
      return _Scroll(
        children: [
          _Panel(
            child: Text(
              shell.repo.demo
                  ? 'El asistente agenda con los horarios reales de tu especialista. Crea tu cuenta y vincúlate para usarlo.'
                  : 'Vincúlate con tu especialista para que el asistente pueda agendar tus citas.',
              style: const TextStyle(color: MedColors.muted),
            ),
          ),
        ],
      );
    }
    return Column(
      children: [
        Expanded(
          child: ListView(
            controller: scroll,
            padding: const EdgeInsets.all(16),
            children: [
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAEEF3),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    'Solo agenda citas. Dudas clínicas: consulta a tu especialista.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, color: MedColors.muted),
                  ),
                ),
              ),
              for (final (i, e) in chat.indexed) ...[
                const SizedBox(height: 12),
                bubble(e),
                if (!e.mine)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: extras(e, i == chat.length - 1),
                  ),
              ],
              if (busy)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Buscando…',
                      style: TextStyle(fontSize: 13, color: MedColors.muted),
                    ),
                  ),
                ),
            ],
          ),
        ),
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: input,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => send(),
                  decoration: InputDecoration(
                    hintText: 'Escribe al asistente…',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    fillColor: MedColors.background,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(22),
                      borderSide: const BorderSide(color: Color(0xFFD5DCE7)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                tooltip: 'Enviar',
                style: IconButton.styleFrom(
                  backgroundColor: widget.session.specialty.accent,
                  minimumSize: const Size(44, 44),
                ),
                onPressed: busy ? null : send,
                icon: const Icon(
                  Icons.arrow_forward_rounded,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Patient agenda: upcoming appointments and booking with real open slots.
/// Tapping a slot calls book_appointment directly (no LLM), as designed.
class AgendaView extends StatefulWidget {
  const AgendaView({super.key, required this.state, required this.home});
  final PatientShellState state;
  final HomeData home;
  @override
  State<AgendaView> createState() => _AgendaViewState();
}

class _AgendaViewState extends State<AgendaView> {
  DateTime day = _day(DateTime.now());
  Future<List<DateTime>>? slots;
  String? sessionId;
  Appointment? moving;
  bool busy = false;
  Appointment? confirmed;

  CareRepository get repo => widget.state.repo;
  HomeData get home => widget.home;

  @override
  void initState() {
    super.initState();
    final sessions = home.sessions;
    if (sessions.isNotEmpty) {
      sessionId = sessions[math.min(widget.state.selected, sessions.length - 1)]
          .session
          .id;
      fetch();
    }
  }

  void fetch() {
    if (sessionId == null) return;
    setState(() {
      slots = repo.availableSlots(sessionId!, day, days: 1);
    });
  }

  Future<void> pick(DateTime start) async {
    final session = home.sessionById(sessionId!)!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(moving == null ? 'Confirmar cita' : 'Confirmar cambio'),
        content: Text(
          '${_longDate(start)} a las ${_hm(start)}\n${session.session.professional} · ${session.specialty.label}'
          '${moving == null ? '' : '\n\nTu cita del ${_longDate(moving!.start).toLowerCase()} a las ${_hm(moving!.start)} se cancelará.'}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Volver'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => busy = true);
    try {
      if (moving != null) {
        await repo.rescheduleAppointment(moving!.id, start);
      } else {
        await repo.bookAppointment(sessionId!, start);
      }
      if (!mounted) return;
      notice(context, moving == null ? 'Cita agendada.' : 'Cita reagendada.');
      setState(() {
        moving = null;
        busy = false;
      });
      widget.state.reload();
    } catch (e) {
      if (!mounted) return;
      setState(() => busy = false);
      notice(context, e is FormatException ? e.message : friendlyError(e));
      fetch();
    }
  }

  Future<void> cancel(Appointment a) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Cancelar esta cita?'),
        content: Text(
          '${_longDate(a.start)} a las ${_hm(a.start)} con ${a.professional}. Tu especialista verá la cancelación en su agenda.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Mantener'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: MedColors.danger,
              minimumSize: const Size(0, 44),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cancelar cita'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await repo.cancelAppointment(a.id);
      if (mounted) notice(context, 'Cita cancelada.');
      widget.state.reload();
    } catch (e) {
      if (mounted) {
        notice(context, e is FormatException ? e.message : friendlyError(e));
      }
    }
  }

  void startMove(Appointment a) {
    setState(() {
      moving = a;
      sessionId = a.sessionId;
      day = _day(a.start).isBefore(_day(DateTime.now()))
          ? _day(DateTime.now())
          : _day(a.start);
    });
    fetch();
  }

  @override
  Widget build(BuildContext context) {
    final upcoming = home.upcoming;
    final past = home.past.take(6).toList();
    if (repo.demo || home.sessions.isEmpty) {
      return _Scroll(
        children: [
          _Panel(
            child: Text(
              repo.demo
                  ? 'Crea tu cuenta y vincúlate con tu especialista para ver sus horarios y agendar citas.'
                  : 'Vincúlate con tu especialista para ver sus horarios y agendar citas.',
              style: const TextStyle(color: MedColors.muted),
            ),
          ),
        ],
      );
    }
    final session = home.sessionById(sessionId!) ?? home.sessions.first;
    return _Scroll(
      onRefresh: () async {
        widget.state.reload();
        fetch();
      },
      children: [
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFEAEEF3),
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Text(
              'Agenda, reagenda o cancela. Las dudas clínicas resuélvelas con tu especialista.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: MedColors.muted),
            ),
          ),
        ),
        if (upcoming.isNotEmpty) ...[
          Text('Próximas citas', style: heading(16, weight: FontWeight.w700)),
          for (final a in upcoming)
            Column(
              children: [
                _AppointmentTile(appt: a),
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: busy ? null : () => startMove(a),
                          child: Text(
                            moving?.id == a.id
                                ? 'Elige el nuevo horario'
                                : 'Reagendar',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: MedColors.danger,
                          ),
                          onPressed: busy ? null : () => cancel(a),
                          child: const Text('Cancelar'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
        ],
        _Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      moving == null ? 'Agendar una cita' : 'Nuevo horario',
                      style: heading(16, weight: FontWeight.w700),
                    ),
                  ),
                  if (moving != null)
                    TextButton(
                      onPressed: () => setState(() => moving = null),
                      child: const Text('No cambiar'),
                    ),
                ],
              ),
              Text(
                '${session.session.professional} · ${session.specialty.label}',
                style: const TextStyle(fontSize: 13, color: MedColors.muted),
              ),
              if (home.sessions.length > 1 && moving == null) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final s in home.sessions)
                      ChoiceChip(
                        label: Text(s.specialty.label),
                        selected: s.session.id == sessionId,
                        onSelected: (_) {
                          setState(() => sessionId = s.session.id);
                          fetch();
                        },
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              SizedBox(
                height: 76,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: 21,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final d = _day(DateTime.now()).add(Duration(days: i));
                    final on = d == day;
                    return Semantics(
                      selected: on,
                      button: true,
                      label: _longDate(d),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          setState(() => day = d);
                          fetch();
                        },
                        child: Container(
                          width: 52,
                          decoration: BoxDecoration(
                            color: on ? MedColors.brand : MedColors.brandSoft,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _weekdayShort[d.weekday - 1],
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: on
                                      ? Colors.white
                                      : MedColors.brandDeep,
                                ),
                              ),
                              Text(
                                '${d.day}',
                                style: heading(
                                  17,
                                  color: on
                                      ? Colors.white
                                      : MedColors.brandDeep,
                                ).copyWith(height: 1.1),
                              ),
                              Text(
                                _monthShort[d.month - 1],
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: on
                                      ? Colors.white
                                      : MedColors.brandDeep,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 14),
              FutureBuilder<List<DateTime>>(
                future: slots,
                builder: (context, snap) {
                  if (snap.connectionState != ConnectionState.done) {
                    return const Padding(
                      padding: EdgeInsets.all(12),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  if (snap.hasError) {
                    return Text(
                      friendlyError(snap.error!),
                      style: const TextStyle(
                        color: MedColors.danger,
                        fontSize: 13,
                      ),
                    );
                  }
                  final list = (snap.data ?? const [])
                      .where((t) => _day(t) == day)
                      .toList();
                  if (list.isEmpty) {
                    return const Text(
                      'Sin horarios libres este día. Prueba otro.',
                      style: TextStyle(color: MedColors.muted, fontSize: 13),
                    );
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final t in list)
                            ActionChip(
                              label: Text(_hm(t)),
                              onPressed: busy ? null : () => pick(t),
                              backgroundColor: MedColors.brandSoft,
                              labelStyle: const TextStyle(
                                color: MedColors.brandDeep,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                              side: const BorderSide(
                                color: Color(0xFFC9D5F2),
                                width: 1.5,
                              ),
                              shape: const StadiumBorder(),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Toca un horario para confirmarlo.',
                        style: TextStyle(fontSize: 12, color: MedColors.muted),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
        if (past.isNotEmpty) ...[
          Text('Historial', style: heading(16, weight: FontWeight.w700)),
          for (final a in past) _AppointmentTile(appt: a),
        ],
      ],
    );
  }
}

// ------------------------------------------------------------------ Perfil

class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key, required this.state, required this.home});
  final PatientShellState state;
  final HomeData home;

  @override
  Widget build(BuildContext context) {
    final repo = state.repo;
    final email = repo.client?.auth.currentUser?.email;
    return _Scroll(
      children: [
        Text('Perfil', style: heading(26)),
        _Panel(
          child: Row(
            children: [
              const CircleAvatar(
                radius: 26,
                backgroundColor: MedColors.brandSoft,
                child: Icon(Icons.person_rounded, color: MedColors.brand),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      repo.demo
                          ? 'Explorando sin cuenta'
                          : (home.name ?? 'Paciente'),
                      style: heading(17),
                    ),
                    if (!repo.demo && email != null)
                      Text(
                        email,
                        style: const TextStyle(
                          fontSize: 13,
                          color: MedColors.muted,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Text('Mis especialistas', style: heading(16, weight: FontWeight.w700)),
        if (home.sessions.isEmpty)
          const _Panel(
            child: Text(
              'Aún no tienes especialistas vinculados.',
              style: TextStyle(color: MedColors.muted),
            ),
          ),
        for (final d in home.sessions)
          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            child: ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 6,
              ),
              leading: CircleAvatar(
                backgroundColor: d.specialty.soft,
                child: Icon(d.specialty.icon, color: d.specialty.accent),
              ),
              title: Text(
                d.session.professional,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                '${d.specialty.label} · ${d.session.title}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => state.openSession(d.session),
            ),
          ),
        OutlinedButton.icon(
          onPressed: state.link,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Vincular con un código'),
        ),
        ..._requests(home),
        if (showPublicHealth)
          OutlinedButton.icon(
            onPressed: () => state.push(
              Scaffold(
                appBar: AppBar(title: const Text('Prevención')),
                body: PreventionScreen(repository: repo),
              ),
            ),
            icon: const Icon(Icons.shield_outlined),
            label: const Text('Prevención en tu zona'),
          ),
        Text('Tu privacidad', style: heading(16, weight: FontWeight.w700)),
        const Text(
          'Tus registros solo los ve el especialista de cada sesión activa. Al cerrarse una sesión pierde el acceso y tú conservas tu historial. Med Box no es un servicio de emergencias.',
          style: TextStyle(color: MedColors.body),
        ),
        if (!repo.demo)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final kind in const [
                ('export', 'Solicitar copia de mis datos'),
                ('delete', 'Solicitar eliminación'),
              ])
                OutlinedButton(
                  onPressed: () async {
                    try {
                      await repo.requestData(kind.$1);
                      if (context.mounted) {
                        notice(
                          context,
                          'Solicitud registrada. Se atenderá manualmente; no es inmediata.',
                        );
                      }
                    } catch (e) {
                      if (context.mounted) notice(context, friendlyError(e));
                    }
                  },
                  child: Text(kind.$2),
                ),
            ],
          ),
        OutlinedButton.icon(
          onPressed: () async {
            try {
              if (!repo.demo) await repo.client!.auth.signOut();
              if (context.mounted) Navigator.of(context).pop();
            } catch (e) {
              if (context.mounted) notice(context, friendlyError(e));
            }
          },
          icon: const Icon(Icons.logout),
          label: Text(repo.demo ? 'Salir' : 'Cerrar sesión'),
        ),
        const Text(
          'Med Box 0.3 · Fisioterapia · Dermatología · Oftalmología · Psicología',
          style: TextStyle(fontSize: 12, color: MedColors.muted),
        ),
      ],
    );
  }
}
