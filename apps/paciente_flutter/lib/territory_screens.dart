/// Observatorio territorial estacional: clima actual, alertas preventivas,
/// padecimientos por macro-zona y reglas editoriales. Solo información
/// pública; nada de aquí toca expedientes.
library;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'data.dart';
import 'pharmacies.dart';
import 'pharmacies_screen.dart';
import 'public_info_widgets.dart';
import 'territory.dart';
import 'theme.dart';

/// Color de identificación por zona (no representa nivel de riesgo).
const _zoneColors = [
  Color(0xFF5EA8D6),
  Color(0xFFE5A93B),
  Color(0xFF4CA88A),
  Color(0xFF9C7BC4),
];

IconData _alertIcon(AlertKind kind) => switch (kind) {
  AlertKind.calor => Icons.wb_sunny_outlined,
  AlertKind.gastro => Icons.restaurant_outlined,
  AlertKind.vectores => Icons.water_drop_outlined,
  AlertKind.humedad => Icons.air,
};

class PreventionScreen extends StatefulWidget {
  const PreventionScreen({
    super.key,
    required this.repository,
    this.territory,
    this.pharmacies,
  });
  final CareRepository repository;

  /// Inyectables para pruebas; por omisión se crean los propios.
  final TerritoryRepository? territory;
  final PharmacyRepository? pharmacies;

  @override
  State<PreventionScreen> createState() => _PreventionScreenState();
}

class _PreventionScreenState extends State<PreventionScreen> {
  late final territory = widget.territory ?? TerritoryRepository();
  late final pharmacies = widget.pharmacies ?? PharmacyRepository();
  late Future<WeatherResult> weather = territory.weather();
  late Future<TerritoryProfile> profile = territory.profile();
  late Future<List<PreventionRule>> rules = _loadRules();
  String? zoneId;

  /// Si Supabase no responde se usa la regla R01 local.
  Future<List<PreventionRule>> _loadRules() async {
    try {
      final remote = await widget.repository.preventionRules();
      if (remote.isNotEmpty) return activeRules(remote, DateTime.now());
    } catch (_) {
      /* Sin conexión: respaldo local. */
    }
    return activeRules(fallbackRules, DateTime.now());
  }

  Future<void> _refresh() async {
    setState(() {
      weather = territory.weather();
      profile = territory.profile();
      rules = _loadRules();
    });
    await Future.wait<Object>([weather, profile, rules])
        .catchError((_) => const <Object>[]);
  }

  void _openPharmacies(MacroZone? zone) => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => PharmacyScreen(
        pharmacies: pharmacies,
        territory: territory,
        initialZone: zone,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final month = DateTime.now().month;
    return RefreshIndicator(
      onRefresh: _refresh,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            children: [
              Text(
                'Cuidarte también\nes prevenir.',
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              const SizedBox(height: 16),
              const Chip(
                avatar: Icon(Icons.location_on_outlined, size: 18),
                label: Text('Cancún, Benito Juárez, Quintana Roo'),
              ),
              const SectionHeader(
                'Clima ahora',
                'Las alertas se activan con el clima real de Cancún.',
              ),
              FutureBuilder<WeatherResult>(
                future: weather,
                builder: (context, snap) {
                  if (snap.connectionState != ConnectionState.done) {
                    return const LoadingRow('Consultando el clima…');
                  }
                  return _WeatherSection(
                    result: snap.data ?? const WeatherResult(null),
                    month: month,
                    onRetry: _refresh,
                  );
                },
              ),
              const SectionHeader(
                'Temporada actual',
                'Padecimientos que aumentan en esta época en Quintana Roo.',
              ),
              FutureBuilder<TerritoryProfile>(
                future: profile,
                builder: (context, snap) {
                  if (snap.hasError) {
                    return NoticeCard(
                      'No pudimos cargar el perfil territorial.',
                      onRetry: _refresh,
                    );
                  }
                  if (!snap.hasData) {
                    return const LoadingRow('Cargando temporadas…');
                  }
                  return _SeasonSection(profile: snap.data!, month: month);
                },
              ),
              const SectionHeader(
                'Tu zona',
                'Elige tu macro-zona para ver qué vigilar ahí.',
              ),
              FutureBuilder<TerritoryProfile>(
                future: profile,
                builder: (context, snap) {
                  if (!snap.hasData) return const SizedBox.shrink();
                  final p = snap.data!;
                  final selected = p.zones
                      .where((z) => z.id == zoneId)
                      .firstOrNull;
                  return _ZoneSection(
                    profile: p,
                    month: month,
                    selected: selected,
                    onSelect: (z) => setState(() => zoneId = z.id),
                    onPharmacies: () => _openPharmacies(selected),
                  );
                },
              ),
              const SectionHeader(
                'Información para tu bienestar',
                'Contenido general revisado; no es una alerta local.',
              ),
              FutureBuilder<List<PreventionRule>>(
                future: rules,
                builder: (context, snap) {
                  if (snap.connectionState != ConnectionState.done) {
                    return const LoadingRow('Cargando recomendaciones…');
                  }
                  return Column(
                    children: [
                      for (final r in snap.data ?? const <PreventionRule>[])
                        _RuleCard(rule: r),
                    ],
                  );
                },
              ),
              const SectionHeader(
                'Farmacias y puntos de atención',
                'Ubicación para conseguir insumos; no consulta inventario.',
              ),
              Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  leading: const Icon(
                    Icons.local_pharmacy_outlined,
                    color: MedColors.primary,
                  ),
                  title: const Text('Buscar farmacias cercanas'),
                  subtitle: const Text(
                    'Por zona, por cadena o con tu ubicación si la autorizas.',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _openPharmacies(null),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Clima y alertas
// ---------------------------------------------------------------------------

class _WeatherSection extends StatelessWidget {
  const _WeatherSection({
    required this.result,
    required this.month,
    required this.onRetry,
  });
  final WeatherResult result;
  final int month;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final w = result.weather;
    final alerts = w == null
        ? const <ClimateAlert>[]
        : evaluateAlerts(w, month);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (result.notice != null) NoticeCard(result.notice!, onRetry: onRetry),
        if (w != null) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 20,
                    runSpacing: 12,
                    children: [
                      _Metric(
                        Icons.thermostat,
                        '${w.temperature.toStringAsFixed(1)} °C',
                        'Temperatura',
                      ),
                      _Metric(
                        Icons.device_thermostat,
                        '${w.apparentTemperature.toStringAsFixed(1)} °C',
                        'Sensación',
                      ),
                      _Metric(
                        Icons.water_drop_outlined,
                        '${w.humidity.round()} %',
                        'Humedad',
                      ),
                      _Metric(
                        Icons.umbrella_outlined,
                        '${w.rainLast7Days.toStringAsFixed(1)} mm',
                        'Lluvia 7 días',
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Lectura: ${formatDateEs(w.observedAt)} · '
                    'Datos del clima: Open-Meteo.com (CC BY 4.0)',
                    style: const TextStyle(fontSize: 12, color: mutedText),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (alerts.isEmpty)
            const Card(
              child: ListTile(
                leading: Icon(Icons.check_circle_outline),
                title: Text('Sin alertas por clima en este momento.'),
              ),
            ),
          for (final a in alerts) _AlertCard(alert: a),
          const Text(
            'Alertas preventivas por condiciones del clima; no son alertas '
            'epidemiológicas oficiales ni un diagnóstico.',
            style: TextStyle(fontSize: 12, color: mutedText),
          ),
        ],
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric(this.icon, this.value, this.label);
  final IconData icon;
  final String value, label;
  @override
  Widget build(BuildContext context) => MergeSemantics(
    child: SizedBox(
      width: 120,
      child: Row(
        children: [
          Icon(icon, color: MedColors.primary),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: Theme.of(context).textTheme.titleMedium),
                Text(
                  label,
                  style: const TextStyle(fontSize: 12, color: mutedText),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _AlertCard extends StatelessWidget {
  const _AlertCard({required this.alert});
  final ClimateAlert alert;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Card(
      color: const Color(0xFFFFF7EC),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_alertIcon(alert.kind), color: const Color(0xFFB4651E)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    alert.title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Text(alert.code, style: const TextStyle(color: mutedText)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              alert.reason,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(alert.advice),
          ],
        ),
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Temporada y zonas
// ---------------------------------------------------------------------------

class _SeasonSection extends StatelessWidget {
  const _SeasonSection({required this.profile, required this.month});
  final TerritoryProfile profile;
  final int month;

  @override
  Widget build(BuildContext context) {
    final seasons = TerritoryProfile.activeSeasons(month);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final season in seasons) ...[
          Chip(
            avatar: const Icon(Icons.event_outlined, size: 18),
            label: Text('${season.label} · ${season.months}'),
          ),
          const SizedBox(height: 8),
          for (final c in profile.conditions.where((c) => c.season == season))
            _ConditionTile(condition: c),
          const SizedBox(height: 8),
        ],
        _SourceNote(profile: profile),
      ],
    );
  }
}

class _ConditionTile extends StatelessWidget {
  const _ConditionTile({required this.condition, this.dimmed = false});
  final SeasonalCondition condition;
  final bool dimmed;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Card(
      color: dimmed ? const Color(0xFFF7FAFB) : null,
      child: ExpansionTile(
        shape: const Border(),
        title: Text(
          condition.name,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: dimmed ? mutedText : MedColors.primary,
          ),
        ),
        subtitle: Text(
          condition.season.label,
          style: const TextStyle(fontSize: 12, color: mutedText),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(condition.prevention),
          if (condition.warningSigns.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Acude a valoración si: ${condition.warningSigns}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ],
      ),
    ),
  );
}

class _SourceNote extends StatelessWidget {
  const _SourceNote({required this.profile});
  final TerritoryProfile profile;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Fuente: ${profile.source}\n'
        'Fecha de consulta: ${formatDateEs(profile.consultedOn)} · versión ${profile.version}\n'
        '${profile.method}',
        style: const TextStyle(fontSize: 12, color: mutedText),
      ),
      if (profile.sourceUrl.isNotEmpty)
        TextButton.icon(
          style: TextButton.styleFrom(padding: EdgeInsets.zero),
          onPressed: () => openExternal(context, profile.sourceUrl),
          icon: const Icon(Icons.open_in_new, size: 16),
          label: const Text('Consultar los anuarios'),
        ),
    ],
  );
}

class _ZoneSection extends StatelessWidget {
  const _ZoneSection({
    required this.profile,
    required this.month,
    required this.selected,
    required this.onSelect,
    required this.onPharmacies,
  });
  final TerritoryProfile profile;
  final int month;
  final MacroZone? selected;
  final ValueChanged<MacroZone> onSelect;
  final VoidCallback onPharmacies;

  @override
  Widget build(BuildContext context) {
    final zones = profile.zones;
    final colorOf = {
      for (var i = 0; i < zones.length; i++)
        zones[i].id: _zoneColors[i % _zoneColors.length],
    };
    final list = selected == null ? null : profile.forZone(selected!.id, month);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ZoneMap(zones: zones, colorOf: colorOf, selected: selected),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final z in zones)
                      ChoiceChip(
                        avatar: CircleAvatar(backgroundColor: colorOf[z.id]),
                        label: Text(z.name),
                        selected: z.id == selected?.id,
                        onSelected: (_) => onSelect(z),
                      ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Text(
                  'Delimitación aproximada para orientación. Los colores identifican '
                  'la zona; no indican nivel de riesgo.',
                  style: TextStyle(fontSize: 12, color: mutedText),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (selected == null)
          const Text('Selecciona una zona para ver su perfil.'),
        if (selected != null && list != null) ...[
          Text(selected!.name, style: Theme.of(context).textTheme.titleMedium),
          Text(selected!.description, style: const TextStyle(color: mutedText)),
          const SizedBox(height: 8),
          const Text(
            'A vigilar ahora',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          if (list.now.isEmpty) const Text('Sin padecimientos de temporada.'),
          for (final c in list.now) _ConditionTile(condition: c),
          if (list.later.isNotEmpty) ...[
            const SizedBox(height: 6),
            const Text(
              'En otras temporadas',
              style: TextStyle(fontWeight: FontWeight.w700, color: mutedText),
            ),
            const SizedBox(height: 6),
            for (final c in list.later)
              _ConditionTile(condition: c, dimmed: true),
          ],
          OutlinedButton.icon(
            onPressed: onPharmacies,
            icon: const Icon(Icons.local_pharmacy_outlined),
            label: const Text('Farmacias en esta zona'),
          ),
        ],
      ],
    );
  }
}

/// Mapa de las macro-zonas; la selección se hace con los chips de abajo,
/// que también sirven como alternativa accesible.
class _ZoneMap extends StatefulWidget {
  const _ZoneMap({
    required this.zones,
    required this.colorOf,
    required this.selected,
  });
  final List<MacroZone> zones;
  final Map<String, Color> colorOf;
  final MacroZone? selected;
  @override
  State<_ZoneMap> createState() => _ZoneMapState();
}

class _ZoneMapState extends State<_ZoneMap> {
  final map = MapController();

  @override
  void didUpdateWidget(covariant _ZoneMap old) {
    super.didUpdateWidget(old);
    final zone = widget.selected;
    if (zone != null && zone.id != old.selected?.id) {
      map.move(zone.center, 12.3);
    }
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 280,
    child: Semantics(
      label: 'Mapa de macro-zonas de Cancún. Selecciónalas con los botones debajo del mapa.',
      child: FlutterMap(
        mapController: map,
        options: const MapOptions(
          initialCenter: LatLng(21.135, -86.85),
          initialZoom: 11.2,
          minZoom: 9,
          maxZoom: 17,
          interactionOptions: InteractionOptions(
            flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
          ),
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'mx.medbox.med_box',
          ),
          PolygonLayer(
            polygons: [
              for (final z in widget.zones)
                for (final ring in z.rings)
                  Polygon(
                    points: ring,
                    color: widget.colorOf[z.id]!.withValues(
                      alpha: z.id == widget.selected?.id ? .55 : .3,
                    ),
                    borderColor: z.id == widget.selected?.id
                        ? MedColors.primary
                        : widget.colorOf[z.id]!,
                    borderStrokeWidth: z.id == widget.selected?.id ? 3 : 1.5,
                  ),
            ],
          ),
          RichAttributionWidget(
            attributions: [
              TextSourceAttribution(
                'Colaboradores de OpenStreetMap',
                onTap: () => openExternal(
                  context,
                  'https://www.openstreetmap.org/copyright',
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Reglas editoriales
// ---------------------------------------------------------------------------

class _RuleCard extends StatelessWidget {
  const _RuleCard({required this.rule});
  final PreventionRule rule;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.shield_outlined,
                  color: MedColors.secondary,
                  size: 40,
                ),
                const Spacer(),
                if (rule.code.isNotEmpty)
                  Chip(
                    visualDensity: VisualDensity.compact,
                    label: Text('${rule.code} · ${rule.scope}'),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Text(rule.title, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 10),
            Text(rule.body),
            const SizedBox(height: 16),
            Text(
              'Fuente: ${rule.source}\n'
              'Fecha de consulta y revisión: ${formatDateEs(rule.reviewed)}\n'
              '${rule.isLocalAlert ? 'Publicación sanitaria para esta zona.' : 'Información general; no es una alerta local.'}',
              style: const TextStyle(fontSize: 12, color: mutedText),
            ),
            if (rule.url.isNotEmpty)
              TextButton.icon(
                style: TextButton.styleFrom(padding: EdgeInsets.zero),
                onPressed: () => openExternal(context, rule.url),
                icon: const Icon(Icons.open_in_new, size: 16),
                label: const Text('Consultar la fuente'),
              ),
          ],
        ),
      ),
    ),
  );
}
