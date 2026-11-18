import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'data.dart';
import 'exercise_demo.dart';
import 'screens.dart' show RecordScreen;

const _ink = Color(0xFF2B2340);
const _muted = Color(0xFF7A7289);
const _line = Color(0xFFF0EBF2);
const _peach = Color(0xFFFFEDE2);
const _mint = Color(0xFFDDF4E8);
const _lilac = Color(0xFFEFE6FB);
const _sky = Color(0xFFE3EEFF);
const _sun = Color(0xFFFFF4DC);
const _orange = Color(0xFFF26B3A);
const _green = Color(0xFF2EA57E);
const _purple = Color(0xFF8D61CC);
const _blue = Color(0xFF3B86D6);
const _amber = Color(0xFFF5A623);
const _red = Color(0xFFE5484D);

/// Visual identity and wording of each specialty. Data and flows are shared.
class _Look {
  const _Look({
    required this.accent,
    required this.soft,
    required this.bg,
    required this.heroColors,
    required this.subtitle,
    required this.heroTitle,
    required this.heroText,
    required this.heroIcon,
    required this.tiles,
    required this.tileIcons,
    required this.planHeader,
    required this.planHeading,
    required this.planEmpty,
    required this.progressHeading,
    required this.progressEmpty,
    required this.progressButton,
    required this.progressIcon,
  });
  final Color accent, soft, bg;
  final List<Color> heroColors;
  final String subtitle, heroTitle, heroText, planHeader, planHeading, planEmpty;
  final String progressHeading, progressEmpty, progressButton;
  final IconData heroIcon, progressIcon;
  final List<String> tiles;
  final List<IconData> tileIcons;

  static _Look of(Specialty s) => switch (s) {
    Specialty.skin => const _Look(
      accent: Color(0xFFBE3A5A),
      soft: Color(0xFFFBE7EC),
      bg: Color(0xFFFFFAF7),
      heroColors: [Color(0xFFFFE6D6), Color(0xFFFFC2A6)],
      subtitle: 'Expediente y seguimiento dermatológico',
      heroTitle: 'Cuida tu piel',
      heroText: 'Registra tu tratamiento\ny sigue su evolución',
      heroIcon: Icons.spa_rounded,
      tiles: ['Información general', 'Tratamiento', 'Seguimiento fotográfico', 'Sesiones'],
      tileIcons: [Icons.assignment_rounded, Icons.medication_rounded, Icons.photo_camera_rounded, Icons.calendar_month_rounded],
      planHeader: 'Tu tratamiento actual',
      planHeading: 'Medicamentos y cuidados',
      planEmpty: 'Tu dermatólogo aún no ha asignado cuidados. Aquí aparecerán sus indicaciones.',
      progressHeading: 'Evolución de la lesión',
      progressEmpty: 'Tu primera fotografía será el inicio de tu historial. Usa el mismo identificador de lesión en cada foto.',
      progressButton: 'Agregar fotografía',
      progressIcon: Icons.add_a_photo_rounded,
    ),
    Specialty.physio => const _Look(
      accent: Color(0xFF0F766E),
      soft: Color(0xFFE8F6F3),
      bg: Color(0xFFF6FBFA),
      heroColors: [Color(0xFFD9F3EC), Color(0xFF9FDCCD)],
      subtitle: 'Rehabilitación y seguimiento del movimiento',
      heroTitle: 'Muévete con confianza',
      heroText: 'Haz tus ejercicios\ny mide tu avance',
      heroIcon: Icons.accessibility_new_rounded,
      tiles: ['Información general', 'Mis ejercicios', 'Mi progreso', 'Sesiones'],
      tileIcons: [Icons.assignment_rounded, Icons.fitness_center_rounded, Icons.insights_rounded, Icons.calendar_month_rounded],
      planHeader: 'Tu plan de rehabilitación',
      planHeading: 'Ejercicios asignados',
      planEmpty: 'Tu fisioterapeuta aún no ha asignado ejercicios. Aquí aparecerán con su demostración.',
      progressHeading: 'Tu avance',
      progressEmpty: 'Aún no hay registros. Al completar un ejercicio verás aquí tu dolor y tu avance.',
      progressButton: 'Registrar cómo me siento',
      progressIcon: Icons.edit_note_rounded,
    ),
    Specialty.eyes => const _Look(
      accent: Color(0xFF2457D6),
      soft: Color(0xFFEEF3FF),
      bg: Color(0xFFF6F9FF),
      heroColors: [Color(0xFFDDEAFF), Color(0xFFA9C8F7)],
      subtitle: 'Expediente y seguimiento oftalmológico',
      heroTitle: 'Cuida tu visión',
      heroText: 'Tus gotas, indicaciones\ny cada revisión',
      heroIcon: Icons.visibility_rounded,
      tiles: ['Información general', 'Tratamiento', 'Registro visual', 'Sesiones'],
      tileIcons: [Icons.assignment_rounded, Icons.water_drop_rounded, Icons.remove_red_eye_rounded, Icons.calendar_month_rounded],
      planHeader: 'Tu tratamiento actual',
      planHeading: 'Gotas e indicaciones',
      planEmpty: 'Tu oftalmólogo aún no ha asignado indicaciones. Aquí aparecerán tus gotas y cuidados.',
      progressHeading: 'Tus registros',
      progressEmpty: 'Aún no hay registros. Anota cómo sientes tus ojos y comparte una foto si te la piden.',
      progressButton: 'Registrar seguimiento ocular',
      progressIcon: Icons.edit_note_rounded,
    ),
    Specialty.mind => const _Look(
      accent: Color(0xFF6D4AB8),
      soft: Color(0xFFF1ECFA),
      bg: Color(0xFFFBF8FF),
      heroColors: [Color(0xFFEDE3FB), Color(0xFFCDB6F2)],
      subtitle: 'Acompañamiento psicológico',
      heroTitle: 'Un espacio para ti',
      heroText: 'Registra cómo te sientes,\na tu ritmo',
      heroIcon: Icons.self_improvement_rounded,
      tiles: ['Información general', 'Tareas terapéuticas', 'Diario emocional', 'Sesiones'],
      tileIcons: [Icons.assignment_rounded, Icons.checklist_rounded, Icons.auto_stories_rounded, Icons.calendar_month_rounded],
      planHeader: 'Tu plan terapéutico',
      planHeading: 'Tareas asignadas',
      planEmpty: 'Tu psicólogo aún no ha asignado tareas. Aquí aparecerán cuando lo haga.',
      progressHeading: 'Cómo te has sentido',
      progressEmpty: 'Tu diario está vacío. Escribe cómo te sientes hoy; solo lo lee tu psicólogo de esta sesión.',
      progressButton: 'Escribir en mi diario',
      progressIcon: Icons.edit_note_rounded,
    ),
  };
}

typedef _Content = (List<CareActivity>, List<CareRecord>, List<CareReview>, String?);

/// Patient home for one care session, with the same layout for every specialty.
class SpecialtyScreen extends StatefulWidget {
  const SpecialtyScreen({super.key, required this.session, required this.repository});
  final CareSession session;
  final CareRepository repository;
  @override
  State<SpecialtyScreen> createState() => _SpecialtyScreenState();
}

class _SpecialtyScreenState extends State<SpecialtyScreen> {
  int section = -1;
  int sessionTab = 0;
  int photoPage = 0;
  String? lesion;
  late Future<_Content> content;
  final Map<String, Future<Uint8List>> _images = {};

  Specialty get specialty => widget.session.specialty;
  _Look get look => _Look.of(specialty);
  bool get skin => specialty == Specialty.skin;
  bool get physio => specialty == Specialty.physio;
  List<String> get titles => [...look.tiles, 'Notificaciones'];

  @override
  void initState() {
    super.initState();
    reload();
  }

  void reload() {
    content = load();
  }

  Future<_Content> load() async {
    final repo = widget.repository;
    final id = widget.session.id;
    final results = await Future.wait([repo.activities(id), repo.records(id), repo.reviews(id)]);
    String? name;
    final patient = widget.session.patientId;
    if (!repo.demo && patient != null) {
      try {
        name = await repo.patientName(patient);
      } catch (_) {}
    }
    return (results[0] as List<CareActivity>, results[1] as List<CareRecord>, results[2] as List<CareReview>, name);
  }

  Future<Uint8List> image(String path) => _images.putIfAbsent(path, () => widget.repository.evidence(path));

  Future<void> push(Widget screen) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => Theme(data: theme(context), child: screen)),
    );
    if (saved == true && mounted) setState(reload);
  }

  Future<void> record({String? activityId}) =>
      push(RecordScreen(session: widget.session, repository: widget.repository, activityId: activityId));

  Future<void> exercise(CareActivity a) =>
      push(ExerciseDemoScreen(session: widget.session, activity: a, repository: widget.repository));

  void open(int value) => setState(() => section = value);

  String date(DateTime d) => MaterialLocalizations.of(context).formatMediumDate(d);

  bool isPhoto(CareRecord r) => r.evidencePath != null && !r.hasVideo;

  ThemeData theme(BuildContext context) => Theme.of(context).copyWith(
    scaffoldBackgroundColor: look.bg,
    colorScheme: Theme.of(context).colorScheme.copyWith(primary: look.accent, secondary: _green, surface: Colors.white),
    appBarTheme: AppBarTheme(backgroundColor: look.bg, foregroundColor: _ink, centerTitle: true, elevation: 0, scrolledUnderElevation: 0),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: look.accent,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    ),
  );

  // ---------- Building blocks ----------

  Widget card(Widget child, {Color color = Colors.white, EdgeInsets padding = const EdgeInsets.all(18)}) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 12),
    padding: padding,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: color == Colors.white ? _line : Colors.transparent),
      boxShadow: const [BoxShadow(color: Color(0x0D2B2340), blurRadius: 16, offset: Offset(0, 6))],
    ),
    child: child,
  );

  Widget heading(String text, {Widget? trailing}) => Padding(
    padding: const EdgeInsets.only(top: 10, bottom: 10),
    child: Row(
      children: [
        Expanded(child: Text(text, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: _ink))),
        ?trailing,
      ],
    ),
  );

  Widget empty(String text, {IconData? icon}) => card(
    Row(
      children: [
        Icon(icon ?? specialty.icon, color: look.accent.withValues(alpha: .7)),
        const SizedBox(width: 12),
        Expanded(child: Text(text, style: const TextStyle(color: _muted, fontSize: 13, height: 1.35))),
      ],
    ),
  );

  Widget badge(IconData icon, Color tone, Color bg, {double size = 44}) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(size * .32)),
    child: Icon(icon, color: tone, size: size * .52),
  );

  Widget rows(List<(IconData, Color, String, String)> items) => card(
    Column(
      children: [
        for (var i = 0; i < items.length; i++)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 11),
            decoration: BoxDecoration(border: i == items.length - 1 ? null : const Border(bottom: BorderSide(color: _line))),
            child: Row(
              children: [
                Icon(items[i].$1, color: items[i].$2, size: 19),
                const SizedBox(width: 12),
                Expanded(flex: 5, child: Text(items[i].$3, style: const TextStyle(fontSize: 13, color: _ink))),
                Expanded(flex: 6, child: Text(items[i].$4, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _ink))),
              ],
            ),
          ),
      ],
    ),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
  );

  Widget softButton(IconData icon, String label, VoidCallback onTap) => Material(
    color: look.soft,
    borderRadius: BorderRadius.circular(18),
    child: InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: look.accent, size: 21),
            const SizedBox(width: 10),
            Flexible(
              child: Text(label, overflow: TextOverflow.ellipsis, style: TextStyle(color: look.accent, fontWeight: FontWeight.w700, fontSize: 15)),
            ),
          ],
        ),
      ),
    ),
  );

  Widget thumb(String path, {double? height, double radius = 16}) => ClipRRect(
    borderRadius: BorderRadius.circular(radius),
    child: Container(
      height: height,
      color: look.soft,
      child: FutureBuilder<Uint8List>(
        future: image(path),
        builder: (context, snap) {
          if (snap.hasError) return const Center(child: Icon(Icons.broken_image_outlined, color: _muted));
          if (!snap.hasData) return const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)));
          return Image.memory(
            snap.data!,
            fit: BoxFit.cover,
            width: double.infinity,
            height: height,
            semanticLabel: 'Fotografía del registro',
            errorBuilder: (_, e, s) => const Center(child: Icon(Icons.broken_image_outlined, color: _muted)),
          );
        },
      ),
    ),
  );

  Widget statusChip() {
    final active = widget.session.active;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: active ? _mint : _line, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(active ? Icons.check_rounded : Icons.lock_outline, size: 14, color: active ? _green : _muted),
          const SizedBox(width: 4),
          Text(active ? 'Activo' : 'Cerrado', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: active ? _green : _muted)),
        ],
      ),
    );
  }

  (IconData, Color, Color) careIcon(CareActivity a) {
    if (a.isExercise) return (Icons.fitness_center_rounded, look.accent, look.soft);
    final t = a.title.toLowerCase();
    if (t.contains('solar') || t.contains('fps')) return (Icons.wb_sunny_rounded, _amber, _sun);
    if (t.contains('gota') || t.contains('lágrima') || t.contains('colirio')) return (Icons.water_drop_rounded, _blue, _sky);
    if (t.contains('limpi') || t.contains('jabón')) return (Icons.water_drop_rounded, _blue, _sky);
    if (t.contains('crema') || t.contains('ungüento') || t.contains('pomada') || t.contains('hidrat')) return (Icons.sanitizer_outlined, _blue, _sky);
    if (t.contains('pastilla') || t.contains('tableta') || t.contains('cápsula')) return (Icons.medication_rounded, _green, _mint);
    if (t.contains('respira') || t.contains('medita') || t.contains('relaja')) return (Icons.air_rounded, _purple, _lilac);
    if (t.contains('diario') || t.contains('escrib') || t.contains('registro')) return (Icons.edit_note_rounded, _purple, _lilac);
    if (t.contains('pantalla') || t.contains('descanso')) return (Icons.visibility_off_outlined, _blue, _sky);
    return switch (specialty) {
      Specialty.skin => (Icons.healing_outlined, _orange, _peach),
      Specialty.physio => (Icons.directions_walk_rounded, look.accent, look.soft),
      Specialty.eyes => (Icons.remove_red_eye_outlined, look.accent, look.soft),
      Specialty.mind => (Icons.psychology_alt_outlined, look.accent, look.soft),
    };
  }

  // ---------- Home ----------

  Widget hero() => Container(
    constraints: const BoxConstraints(minHeight: 150),
    clipBehavior: Clip.antiAlias,
    margin: const EdgeInsets.only(bottom: 14),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(24),
      gradient: LinearGradient(colors: look.heroColors, begin: Alignment.topLeft, end: Alignment.bottomRight),
    ),
    child: Stack(
      children: [
        Positioned(right: -10, top: -6, child: _HeroLens(icon: look.heroIcon, accent: look.accent, glass: look.heroColors.first)),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 22, 130, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(look.heroTitle, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: _ink)),
              const SizedBox(height: 8),
              Text(look.heroText, style: const TextStyle(fontSize: 13, color: _ink, height: 1.35)),
            ],
          ),
        ),
      ],
    ),
  );

  Widget tile(int i) {
    final colors = [look.soft, _mint, _lilac, _sky];
    final tones = [look.accent, _green, _purple, _blue];
    if (specialty == Specialty.mind) {
      colors[2] = _peach;
      tones[2] = _orange;
    }
    if (specialty == Specialty.physio) {
      colors[1] = _peach;
      tones[1] = _orange;
    }
    return Material(
      color: colors[i],
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () => open(i),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 20, 14, 26),
              child: Column(
                children: [
                  Icon(look.tileIcons[i], size: 40, color: tones[i]),
                  const SizedBox(height: 12),
                  Text(
                    look.tiles[i],
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _ink, height: 1.2),
                  ),
                ],
              ),
            ),
            Positioned(right: 10, bottom: 8, child: Icon(Icons.chevron_right_rounded, color: tones[i])),
          ],
        ),
      ),
    );
  }

  Widget home(List<CareActivity> acts, List<CareRecord> records, List<CareReview> reviews) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: look.heroColors)),
            child: Icon(specialty.icon, color: look.accent, size: 28),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(specialty.label, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: _ink)),
                Text(look.subtitle, style: const TextStyle(fontSize: 12, color: _muted)),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Notificaciones',
            onPressed: () => open(4),
            icon: Badge(isLabelVisible: reviews.isNotEmpty, backgroundColor: look.accent, smallSize: 9, child: const Icon(Icons.notifications_none_rounded, color: _ink)),
          ),
        ],
      ),
      const SizedBox(height: 16),
      hero(),
      GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 4,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, mainAxisExtent: 150),
        itemBuilder: (context, i) => tile(i),
      ),
      const SizedBox(height: 8),
      heading('Tu seguimiento'),
      rows([
        (Icons.person_outline, look.accent, 'Especialista', widget.session.professional),
        (physio ? Icons.fitness_center_rounded : Icons.medication_outlined, _green, physio ? 'Ejercicios asignados' : 'Indicaciones', '${acts.length}'),
        if (skin) (Icons.photo_camera_outlined, _purple, 'Fotografías', '${records.where(isPhoto).length}'),
        (Icons.history, _blue, 'Registros compartidos', '${records.length}'),
      ]),
    ],
  );

  // ---------- Información general ----------

  List<(String, List<(IconData, Color, String, String)>)> profileGroups(String Function(String) v) => switch (specialty) {
    Specialty.skin => [
      ('Datos dermatológicos', [
        (Icons.wb_sunny_rounded, _amber, 'Fototipo', v('Fototipo de piel')),
        (Icons.water_drop_rounded, _blue, 'Tipo de piel', v('Tipo de piel')),
        (Icons.science_outlined, _orange, 'Alergias', v('Alergias conocidas')),
      ]),
      ('Antecedentes', [
        (Icons.favorite_rounded, _red, 'Antecedentes cutáneos', v('Antecedentes cutáneos')),
        (Icons.medication_rounded, _purple, 'Medicamentos actuales', v('Medicamentos actuales')),
      ]),
    ],
    Specialty.physio => [
      ('Datos de rehabilitación', [
        (Icons.place_outlined, look.accent, 'Zona tratada', v('Zona corporal')),
        (Icons.compare_arrows_rounded, _blue, 'Lado', v('Lateralidad')),
        (Icons.sentiment_neutral_rounded, _amber, 'Último dolor', v('Dolor reportado (0–10)')),
        (Icons.sentiment_satisfied_alt_rounded, _green, 'Dolor tras ejercicio', v('Dolor después del ejercicio (0–10)')),
      ]),
    ],
    Specialty.eyes => [
      ('Datos oculares', [
        (Icons.remove_red_eye_outlined, look.accent, 'Ojo en seguimiento', v('Lateralidad')),
        (Icons.task_alt_rounded, _green, 'Último cumplimiento', v('Actividad completada')),
        (Icons.notes_rounded, _purple, 'Última nota', v('Nota')),
      ]),
    ],
    Specialty.mind => [
      ('Tu bienestar', [
        (Icons.mood_rounded, look.accent, 'Estado emocional', v('Estado emocional reportado')),
        (Icons.favorite_border_rounded, _red, 'Emociones predominantes', v('Emociones predominantes')),
        (Icons.cloud_outlined, _blue, 'Situaciones de malestar', v('Situaciones de malestar')),
      ]),
      ('Cambios reportados', [
        (Icons.change_circle_outlined, _amber, 'Cambios importantes', v('Cambios importantes')),
        (Icons.medication_rounded, _purple, 'Medicamentos', v('Medicamentos y cambios reportados')),
      ]),
    ],
  };

  List<Widget> info(Map<String, dynamic> profile, List<CareRecord> photos, String? name) {
    String v(String key) {
      final value = profile[key]?.toString().trim() ?? '';
      return value.isEmpty ? 'Sin registrar' : value;
    }

    final display = (name ?? widget.session.title).trim();
    return [
      card(
        Row(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(shape: BoxShape.circle, color: look.soft),
              child: Center(
                child: Text(display.isEmpty ? '?' : display[0].toUpperCase(), style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: look.accent)),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name ?? 'Mi expediente', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _ink)),
                  const SizedBox(height: 4),
                  Text(widget.session.title, style: const TextStyle(fontSize: 13, color: _muted)),
                ],
              ),
            ),
            if (widget.session.active)
              IconButton.filledTonal(
                tooltip: 'Actualizar mis datos',
                style: IconButton.styleFrom(backgroundColor: look.soft, foregroundColor: look.accent),
                onPressed: record,
                icon: const Icon(Icons.edit_rounded, size: 19),
              ),
          ],
        ),
      ),
      heading('Datos de la sesión'),
      rows([
        (Icons.person_outline, look.accent, 'Especialista', widget.session.professional),
        (Icons.event_available_outlined, look.accent, 'Estado', widget.session.active ? 'Activa' : 'Cerrada'),
        if (skin) (Icons.place_outlined, look.accent, 'Zona tratada', v('Zona corporal')),
      ]),
      for (final (title, items) in profileGroups(v)) ...[heading(title), rows(items)],
      if (skin) ...[
        heading(
          'Fotografías de referencia',
          trailing: photos.isEmpty
              ? null
              : TextButton(
                  onPressed: () => open(2),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [Text('Ver todas'), Icon(Icons.arrow_forward_rounded, size: 16)]),
                ),
        ),
        if (photos.isEmpty) empty('Aún no hay fotografías. Agrega una desde Seguimiento fotográfico.', icon: Icons.photo_camera_outlined),
        if (photos.isNotEmpty)
          SizedBox(
            height: 74,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: photos.length,
              separatorBuilder: (_, i) => const SizedBox(width: 10),
              itemBuilder: (_, i) => SizedBox(width: 96, child: thumb(photos[i].evidencePath!, height: 74, radius: 14)),
            ),
          ),
        const SizedBox(height: 12),
      ],
      heading('Indicaciones de tu especialista'),
      card(
        Text(
          widget.session.instructions.isEmpty ? 'Tu especialista todavía no ha registrado indicaciones generales.' : widget.session.instructions,
          style: const TextStyle(fontSize: 13, color: _ink, height: 1.4),
        ),
      ),
    ];
  }

  // ---------- Plan ----------

  List<Widget> plan(List<CareActivity> acts) {
    final dated = acts.where((a) => a.dueOn != null).map((a) => a.dueOn!).toList()..sort();
    final until = dated.isEmpty ? null : dated.last;
    return [
      card(
        Row(
          children: [
            badge(look.tileIcons[1], look.accent, Colors.white, size: 54),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(look.planHeader, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: _ink)),
                  const SizedBox(height: 4),
                  Text(
                    until != null ? 'Vigente hasta el\n${date(until)}' : '${acts.length} ${acts.length == 1 ? 'indicación' : 'indicaciones'}',
                    style: const TextStyle(fontSize: 13, color: _muted, height: 1.3),
                  ),
                ],
              ),
            ),
            statusChip(),
          ],
        ),
        color: look.soft,
      ),
      heading(look.planHeading),
      if (acts.isEmpty) empty(look.planEmpty, icon: look.tileIcons[1]),
      for (final a in acts) a.isExercise ? exerciseTile(a) : careTile(a),
      heading('Recordatorios'),
      card(
        Row(
          children: [
            Icon(Icons.notifications_active_rounded, color: look.accent, size: 30),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                widget.session.instructions.isNotEmpty ? widget.session.instructions : 'Sigue las indicaciones de tu especialista y registra cada avance.',
                style: const TextStyle(fontSize: 13, color: _ink, height: 1.35),
              ),
            ),
          ],
        ),
        color: look.soft,
      ),
      const SizedBox(height: 4),
      softButton(Icons.calendar_month_rounded, 'Ver calendario completo', () => setState(() {
        section = 3;
        sessionTab = 0;
      })),
    ];
  }

  Widget careTile(CareActivity a) {
    final (icon, tone, bg) = careIcon(a);
    return card(
      InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => showCare(a),
        child: Row(
          children: [
            badge(icon, tone, bg, size: 52),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(a.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: _ink)),
                  if (a.instructions.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(a.instructions, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, color: _muted)),
                  ],
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: _ink),
          ],
        ),
      ),
      padding: const EdgeInsets.all(14),
    );
  }

  Widget exerciseTile(CareActivity a) => card(
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            badge(Icons.fitness_center_rounded, look.accent, look.soft, size: 52),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(a.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: _ink)),
                  if (a.targetReps != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text('${a.targetSets ?? 1} × ${a.targetReps} repeticiones', style: TextStyle(fontSize: 13, color: look.accent, fontWeight: FontWeight.w600)),
                    ),
                ],
              ),
            ),
            if (a.detector != null)
              Tooltip(message: 'Conteo automático con la cámara', child: Icon(Icons.auto_awesome_rounded, color: look.accent, size: 20)),
          ],
        ),
        if (a.instructions.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(a.instructions, style: const TextStyle(fontSize: 13, color: _ink, height: 1.4)),
        ],
        if (a.dueOn != null) ...[
          const SizedBox(height: 8),
          Text('Fecha: ${date(a.dueOn!)}', style: const TextStyle(fontSize: 12, color: _muted)),
        ],
        if (widget.session.active) ...[
          const SizedBox(height: 14),
          FilledButton.icon(onPressed: () => exercise(a), icon: const Icon(Icons.play_circle_outline_rounded), label: const Text('Ver demostración y grabar')),
        ],
      ],
    ),
  );

  void showCare(CareActivity a) {
    final (icon, tone, bg) = careIcon(a);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (sheet) => Padding(
        padding: const EdgeInsets.fromLTRB(22, 0, 22, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                badge(icon, tone, bg, size: 52),
                const SizedBox(width: 14),
                Expanded(child: Text(a.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: _ink))),
              ],
            ),
            const SizedBox(height: 16),
            Text(a.instructions.isEmpty ? 'Sin instrucciones adicionales.' : a.instructions, style: const TextStyle(fontSize: 14, height: 1.45, color: _ink)),
            if (a.dueOn != null) ...[
              const SizedBox(height: 10),
              Text('Fecha indicada: ${date(a.dueOn!)}', style: const TextStyle(fontSize: 13, color: _muted)),
            ],
            if (widget.session.active) ...[
              const SizedBox(height: 20),
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: look.accent, minimumSize: const Size.fromHeight(52)),
                onPressed: () {
                  Navigator.pop(sheet);
                  a.isExercise && physio ? exercise(a) : record(activityId: a.id);
                },
                icon: Icon(a.isExercise && physio ? Icons.play_circle_outline_rounded : Icons.check_circle_outline),
                label: Text(a.isExercise && physio ? 'Ver demostración y grabar' : 'Registrar cumplimiento'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ---------- Progress (photos for skin) ----------

  List<String> lesionIds(List<CareRecord> photos) =>
      photos.map((r) => r.details['Identificador de lesión']?.toString()).whereType<String>().where((s) => s.isNotEmpty).toSet().toList();

  List<Widget> photosView(List<CareRecord> allPhotos) {
    final ids = lesionIds(allPhotos);
    final selected = ids.contains(lesion) ? lesion : (ids.isEmpty ? null : ids.first);
    final photos = (selected == null ? allPhotos : allPhotos.where((r) => r.details['Identificador de lesión']?.toString() == selected).toList())
      ..sort((a, b) => a.date.compareTo(b.date));
    final pairs = <(CareRecord, CareRecord)>[
      if (photos.length >= 2)
        for (var i = photos.length - 1; i > 0; i--) (photos.first, photos[i]),
    ];
    final page = pairs.isEmpty ? 0 : photoPage.clamp(0, pairs.length - 1);
    final change = photos.isEmpty ? '' : photos.last.details['Cambios en la apariencia']?.toString().trim() ?? '';
    return [
      heading(selected == null ? look.progressHeading : 'Evolución · $selected'),
      if (photos.isEmpty) empty(look.progressEmpty, icon: Icons.photo_camera_outlined),
      if (photos.length == 1) photoCard(photos.first, '(Inicio)', 230),
      if (pairs.isNotEmpty) ...[
        SizedBox(
          height: 250,
          child: PageView.builder(
            itemCount: pairs.length,
            onPageChanged: (i) => setState(() => photoPage = i),
            itemBuilder: (_, i) => Row(
              children: [
                Expanded(child: photoCard(pairs[i].$1, '(Inicio)', 190)),
                const SizedBox(width: 10),
                Expanded(child: photoCard(pairs[i].$2, i == 0 ? '(Actual)' : '', 190)),
              ],
            ),
          ),
        ),
        if (pairs.length > 1) dots(pairs.length, page),
        const SizedBox(height: 16),
      ],
      if (photos.isNotEmpty)
        summaryCard(
          Icons.bar_chart_rounded,
          change.isNotEmpty ? 'Lo que notaste' : '${photos.length} ${photos.length == 1 ? 'fotografía' : 'fotografías'} registradas',
          change.isNotEmpty
              ? change
              : photos.length > 1
              ? 'Seguimiento de ${photos.last.date.difference(photos.first.date).inDays} días. Tu dermatólogo valorará la evolución.'
              : 'Agrega otra foto con la misma luz y distancia para comparar.',
        ),
      const SizedBox(height: 4),
      if (widget.session.active) softButton(look.progressIcon, look.progressButton, record),
      if (photos.length > 2) ...[
        const SizedBox(height: 12),
        heading('Todas las fotografías'),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: photos.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, mainAxisSpacing: 8, crossAxisSpacing: 8, mainAxisExtent: 128),
          itemBuilder: (_, i) {
            final r = photos[photos.length - 1 - i];
            return Column(
              children: [
                Expanded(child: thumb(r.evidencePath!, radius: 14)),
                const SizedBox(height: 4),
                Text(date(r.date), maxLines: 1, style: const TextStyle(fontSize: 11, color: _muted)),
              ],
            );
          },
        ),
      ],
    ];
  }

  Widget dots(int count, int page) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      for (var i = 0; i < count; i++)
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: i == page ? 18 : 8,
          height: 6,
          decoration: BoxDecoration(color: i == page ? look.accent : look.accent.withValues(alpha: .25), borderRadius: BorderRadius.circular(4)),
        ),
    ],
  );

  Widget photoCard(CareRecord r, String tag, double height) => Container(
    padding: const EdgeInsets.all(6),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: _line)),
    child: Column(
      children: [
        thumb(r.evidencePath!, height: height, radius: 16),
        const SizedBox(height: 8),
        Text(date(r.date), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _ink)),
        if (tag.isNotEmpty) Text(tag, maxLines: 1, style: const TextStyle(fontSize: 12, color: _muted)),
        const SizedBox(height: 4),
      ],
    ),
  );

  Widget summaryCard(IconData icon, String title, String body) => card(
    Row(
      children: [
        Icon(icon, color: look.accent, size: 40),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _ink)),
              const SizedBox(height: 4),
              Text(body, style: const TextStyle(fontSize: 13, color: _ink, height: 1.35)),
            ],
          ),
        ),
      ],
    ),
    color: look.soft,
  );

  /// Pain for physiotherapy, mood frequency for psychology, adherence otherwise.
  Widget? chart(List<CareRecord> records) {
    if (physio) {
      final pains = records.reversed
          .map((r) => int.tryParse('${r.details['Dolor después del ejercicio (0–10)'] ?? r.details['Dolor reportado (0–10)'] ?? ''}'))
          .whereType<int>()
          .toList();
      final last = pains.length > 10 ? pains.sublist(pains.length - 10) : pains;
      if (last.isEmpty) return null;
      return card(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Dolor reportado (0–10)', style: TextStyle(fontWeight: FontWeight.w700, color: _ink)),
            const SizedBox(height: 4),
            const Text('Tus últimos registros, del más antiguo al más reciente', style: TextStyle(fontSize: 12, color: _muted)),
            const SizedBox(height: 14),
            SizedBox(
              height: 110,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final p in last)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text('$p', style: const TextStyle(fontSize: 11, color: _muted)),
                            const SizedBox(height: 4),
                            Container(
                              height: 8 + 80 * p / 10,
                              decoration: BoxDecoration(
                                color: p >= 7 ? _red.withValues(alpha: .8) : p >= 4 ? _amber : look.accent,
                                borderRadius: BorderRadius.circular(6),
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
      );
    }
    if (specialty == Specialty.mind) {
      final counts = <String, int>{};
      for (final r in records) {
        final mood = r.details['Estado emocional reportado']?.toString();
        if (mood != null && mood.isNotEmpty) counts[mood] = (counts[mood] ?? 0) + 1;
      }
      if (counts.isEmpty) return null;
      final total = counts.values.fold(0, (a, b) => a + b);
      return card(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Tus emociones registradas', style: TextStyle(fontWeight: FontWeight.w700, color: _ink)),
            const SizedBox(height: 12),
            for (final e in counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value)))
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    SizedBox(width: 120, child: Text(e.key, style: const TextStyle(fontSize: 13, color: _ink))),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(value: e.value / total, minHeight: 10, color: look.accent, backgroundColor: look.soft),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text('${e.value}', style: const TextStyle(fontSize: 12, color: _muted)),
                  ],
                ),
              ),
          ],
        ),
      );
    }
    return null;
  }

  List<Widget> progressView(List<CareRecord> records) {
    final completed = records.where((r) => r.details['Actividad completada'] == 'Sí').length;
    final graph = chart(records);
    final days = records.length > 1 ? records.first.date.difference(records.last.date).inDays : 0;
    return [
      heading(look.progressHeading),
      if (records.isEmpty) empty(look.progressEmpty, icon: look.tileIcons[2]),
      if (records.isNotEmpty) ...[
        Row(
          children: [
            Expanded(child: stat('${records.length}', 'registros')),
            const SizedBox(width: 10),
            Expanded(child: stat('$completed', physio ? 'ejercicios hechos' : 'cumplidos')),
            const SizedBox(width: 10),
            Expanded(child: stat('$days', 'días de seguimiento')),
          ],
        ),
        const SizedBox(height: 12),
        ?graph,
      ],
      if (widget.session.active) softButton(look.progressIcon, look.progressButton, record),
      if (records.isNotEmpty) ...[
        const SizedBox(height: 12),
        heading(specialty == Specialty.mind ? 'Entradas del diario' : 'Historial de registros'),
        timeline(records, full: true),
      ],
    ];
  }

  Widget stat(String value, String label) => Container(
    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: _line)),
    child: Column(
      children: [
        Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: look.accent)),
        const SizedBox(height: 2),
        Text(label, textAlign: TextAlign.center, maxLines: 2, style: const TextStyle(fontSize: 11, color: _muted)),
      ],
    ),
  );

  // ---------- Sesiones ----------

  List<Widget> sessions(List<CareActivity> acts, List<CareRecord> records, List<CareReview> reviews) {
    final today = DateUtils.dateOnly(DateTime.now());
    final upcoming = acts.where((a) => a.dueOn != null && !a.dueOn!.isBefore(today)).toList()..sort((a, b) => a.dueOn!.compareTo(b.dueOn!));
    const tabs = ['Próximas', 'Historial', 'Notas'];
    return [
      Container(
        padding: const EdgeInsets.all(4),
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: _line)),
        child: Row(
          children: [
            for (var i = 0; i < tabs.length; i++)
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => sessionTab = i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(color: sessionTab == i ? look.accent : Colors.transparent, borderRadius: BorderRadius.circular(14)),
                    child: Text(tabs[i], textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w600, color: sessionTab == i ? Colors.white : _ink)),
                  ),
                ),
              ),
          ],
        ),
      ),
      if (sessionTab == 0) ...[
        if (upcoming.isEmpty) empty('No hay fechas próximas. Las citas se acuerdan con tu especialista.', icon: Icons.calendar_month_outlined),
        for (final a in upcoming)
          card(
            InkWell(
              onTap: () => showCare(a),
              child: Row(
                children: [
                  badge(Icons.calendar_month_rounded, look.accent, look.soft, size: 46),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(date(a.dueOn!), style: const TextStyle(fontWeight: FontWeight.w700, color: _ink)),
                        Text(a.title, style: const TextStyle(fontSize: 13, color: _muted)),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: look.accent),
                ],
              ),
            ),
            padding: const EdgeInsets.all(14),
          ),
        heading('Historial de consultas'),
        if (records.isEmpty) empty('Aún no has compartido registros.', icon: Icons.history),
        timeline(records.take(3).toList()),
        if (records.length > 3) softButton(Icons.arrow_forward_rounded, 'Ver todo el historial', () => setState(() => sessionTab = 1)),
      ],
      if (sessionTab == 1) ...[
        if (records.isEmpty) empty('Aún no has compartido registros. Aquí verás tu seguimiento.', icon: Icons.history),
        timeline(records, full: true),
      ],
      if (sessionTab == 2) ...notes(reviews),
    ];
  }

  Widget timeline(List<CareRecord> items, {bool full = false}) {
    if (items.isEmpty) return const SizedBox.shrink();
    return card(
      Column(
        children: [
          for (var i = 0; i < items.length; i++)
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: 22,
                    child: Column(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          margin: const EdgeInsets.only(top: 4),
                          decoration: BoxDecoration(color: look.accent, shape: BoxShape.circle, border: Border.all(color: look.soft, width: 3)),
                        ),
                        if (i < items.length - 1) Expanded(child: Container(width: 2, color: look.accent.withValues(alpha: .25))),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(date(items[i].date), style: const TextStyle(fontWeight: FontWeight.w700, color: _ink)),
                          const SizedBox(height: 4),
                          for (final e in items[i].details.entries.where((e) => e.value != null && e.value.toString().isNotEmpty).take(full ? 99 : 2))
                            Text('${e.key}: ${e.value}', style: const TextStyle(fontSize: 13, color: _muted, height: 1.35)),
                          if (full && isPhoto(items[i])) ...[
                            const SizedBox(height: 8),
                            thumb(items[i].evidencePath!, height: 150),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> notes(List<CareReview> reviews) => [
    if (reviews.isEmpty) empty('Tu especialista aún no ha dejado comentarios.', icon: Icons.chat_bubble_outline),
    for (final r in reviews)
      card(
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            badge(Icons.chat_bubble_rounded, _green, Colors.white, size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${widget.session.professional} · ${date(r.date)}', style: const TextStyle(fontSize: 12, color: _muted)),
                  const SizedBox(height: 4),
                  Text(r.body, style: const TextStyle(fontSize: 14, color: _ink, height: 1.4)),
                ],
              ),
            ),
          ],
        ),
        color: _mint,
      ),
  ];

  // ---------- Scaffold ----------

  Widget navBar() {
    const items = [
      (Icons.home_rounded, 'Inicio', -1),
      (Icons.history_rounded, 'Historial', 3),
      (Icons.notifications_none_rounded, 'Notificaciones', 4),
      (Icons.person_outline_rounded, 'Perfil', 0),
    ];
    return Container(
      decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: _line))),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            for (final (icon, label, target) in items)
              Expanded(
                child: InkWell(
                  onTap: () => setState(() {
                    section = target;
                    if (target == 3) sessionTab = 1;
                  }),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icon, color: section == target ? look.accent : _muted),
                        const SizedBox(height: 3),
                        Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 11, color: section == target ? look.accent : _muted, fontWeight: section == target ? FontWeight.w700 : FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget? appBar(List<CareRecord> photos) {
    if (section < 0) return null;
    final ids = skin && section == 2 ? lesionIds(photos) : const <String>[];
    return AppBar(
      leading: IconButton(tooltip: 'Volver', icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 19), onPressed: () => setState(() => section = -1)),
      title: Text(titles[section], style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
      actions: [
        if (ids.length > 1)
          PopupMenuButton<String>(
            tooltip: 'Elegir lesión',
            icon: Icon(Icons.filter_alt_outlined, color: look.accent),
            onSelected: (v) => setState(() {
              lesion = v;
              photoPage = 0;
            }),
            itemBuilder: (_) => [for (final id in ids) PopupMenuItem(value: id, child: Text(id))],
          ),
        if (widget.session.active)
          PopupMenuButton<String>(
            tooltip: 'Más opciones',
            onSelected: (v) => v == 'record' ? record() : setState(reload),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'record', child: Text('Actualizar mi seguimiento')),
              PopupMenuItem(value: 'reload', child: Text('Recargar')),
            ],
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: theme(context),
    child: FutureBuilder<_Content>(
      future: content,
      builder: (context, snap) {
        final data = snap.data;
        final photos = data == null ? <CareRecord>[] : data.$2.where(isPhoto).toList();
        return PopScope(
          canPop: section < 0,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) setState(() => section = -1);
          },
          child: Scaffold(
            backgroundColor: look.bg,
            appBar: appBar(photos),
            bottomNavigationBar: navBar(),
            body: SafeArea(
              top: section < 0,
              child: Builder(
                builder: (context) {
                  if (snap.hasError) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('No se pudo cargar tu seguimiento.'),
                          TextButton(onPressed: () => setState(reload), child: const Text('Reintentar')),
                        ],
                      ),
                    );
                  }
                  if (data == null) return const Center(child: CircularProgressIndicator());
                  final (allActs, records, reviews, name) = data;
                  final acts = allActs.where((a) => !a.isExercise || physio).toList();
                  final profile = <String, dynamic>{};
                  for (final r in records.reversed) {
                    profile.addAll(r.details);
                  }
                  return RefreshIndicator(
                    onRefresh: () async {
                      setState(reload);
                      await content;
                    },
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
                      children: [
                        if (widget.repository.demo)
                          const Padding(
                            padding: EdgeInsets.only(bottom: 10),
                            child: Text('Modo exploración · Datos de ejemplo', style: TextStyle(fontSize: 11, color: _muted)),
                          ),
                        if (section < 0) home(acts, records, reviews),
                        if (section == 0) ...info(profile, photos, name),
                        if (section == 1) ...plan(acts),
                        if (section == 2) ...(skin ? photosView(photos) : progressView(records)),
                        if (section == 3) ...sessions(acts, records, reviews),
                        if (section == 4) ...notes(reviews),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    ),
  );
}

/// Hero illustration: the specialty symbol seen through a magnifying glass.
class _HeroLens extends StatelessWidget {
  const _HeroLens({required this.icon, required this.accent, required this.glass});
  final IconData icon;
  final Color accent, glass;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 150,
    height: 160,
    child: Stack(
      children: [
        Positioned(
          left: 18,
          top: 20,
          child: Container(
            width: 104,
            height: 104,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [accent.withValues(alpha: .35), glass], stops: const [.25, 1]),
              border: Border.all(color: _ink, width: 7),
              boxShadow: const [BoxShadow(color: Color(0x332B2340), blurRadius: 12, offset: Offset(0, 6))],
            ),
            child: Center(child: Icon(icon, color: accent, size: 42)),
          ),
        ),
        Positioned(
          left: 104,
          top: 108,
          child: Transform.rotate(
            angle: 0.78,
            child: Container(width: 46, height: 14, decoration: BoxDecoration(color: _ink, borderRadius: BorderRadius.circular(8))),
          ),
        ),
      ],
    ),
  );
}
