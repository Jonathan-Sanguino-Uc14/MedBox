/// Observatorio territorial estacional de Cancún (Benito Juárez, Q. Roo).
///
/// Todo lo de este archivo es información pública e informativa: no lee ni
/// escribe expedientes clínicos y no necesita sesión iniciada. Los modelos
/// son Dart puro para poder probarlos sin dispositivo.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import 'data.dart' show PreventionRule;

/// Centro aproximado de Cancún.
const cancunCenter = LatLng(21.1619, -86.8515);

typedef AssetLoader = Future<String> Function(String path);

// ---------------------------------------------------------------------------
// Temporadas y padecimientos
// ---------------------------------------------------------------------------

/// Temporadas epidemiológicas de Cancún. Noviembre pertenece a ambas
/// (fin de lluvias e inicio de «nortes»).
enum Season {
  calorLluvias('Calor y lluvias', 'marzo a noviembre', {
    3,
    4,
    5,
    6,
    7,
    8,
    9,
    10,
    11,
  }),
  nortes('Frentes fríos («nortes»)', 'noviembre a febrero', {11, 12, 1, 2}),
  todoElAnio('Todo el año', 'enero a diciembre', {
    1,
    2,
    3,
    4,
    5,
    6,
    7,
    8,
    9,
    10,
    11,
    12,
  });

  const Season(this.label, this.months, this._active);
  final String label, months;
  final Set<int> _active;

  bool isActive(int month) => _active.contains(month);

  static Season parse(Object? value) => Season.values.firstWhere(
    (s) => s.name == value,
    orElse: () => Season.todoElAnio,
  );
}

/// Padecimiento estacional del catálogo editorial.
class SeasonalCondition {
  const SeasonalCondition({
    required this.id,
    required this.name,
    required this.season,
    required this.prevention,
    required this.zones,
    this.warningSigns = '',
  });

  final String id, name, prevention, warningSigns;
  final Season season;

  /// Identificadores de macro-zona donde se vigila con más atención.
  final Set<String> zones;

  factory SeasonalCondition.fromJson(Map<String, dynamic> j) =>
      SeasonalCondition(
        id: j['id'] as String,
        name: j['nombre'] as String,
        season: Season.parse(j['temporada']),
        prevention: j['prevencion'] as String,
        warningSigns: j['signos_alarma'] as String? ?? '',
        zones: {for (final z in j['zonas'] as List? ?? const []) '$z'},
      );
}

/// Una de las 4 macro-zonas con su delimitación aproximada.
class MacroZone {
  const MacroZone({
    required this.id,
    required this.name,
    required this.description,
    required this.rings,
  });

  final String id, name, description;
  final List<List<LatLng>> rings;

  /// Punto representativo (promedio de vértices) para buscar servicios
  /// en la zona sin pedir la ubicación del usuario.
  LatLng get center {
    final points = rings.expand((r) => r).toList();
    if (points.isEmpty) return cancunCenter;
    final lat = points.fold<double>(0, (a, p) => a + p.latitude);
    final lon = points.fold<double>(0, (a, p) => a + p.longitude);
    return LatLng(lat / points.length, lon / points.length);
  }

  /// Lee un `Feature` de GeoJSON; devuelve `null` si la geometría no es
  /// válida para que una zona mal formada no tumbe toda la capa.
  static MacroZone? fromFeature(Map<String, dynamic> feature) {
    final props = Map<String, dynamic>.from(
      feature['properties'] as Map? ?? {},
    );
    final geometry = feature['geometry'];
    if (geometry is! Map) return null;
    final rings = parseRings(geometry['type'], geometry['coordinates']);
    final id = '${props['id'] ?? ''}'.trim();
    if (rings.isEmpty || id.isEmpty) return null;
    return MacroZone(
      id: id,
      name: '${props['nombre'] ?? id}',
      description: '${props['descripcion'] ?? ''}',
      rings: rings,
    );
  }
}

/// Anillos exteriores de un Polygon o MultiPolygon; descarta coordenadas
/// fuera de rango. Los huecos no aportan a esta escala.
List<List<LatLng>> parseRings(Object? type, Object? coordinates) {
  List<LatLng>? ring(Object? raw) {
    if (raw is! List || raw.length < 4) return null;
    final points = <LatLng>[];
    for (final p in raw) {
      if (p is! List || p.length < 2) return null;
      final lon = (p[0] as num?)?.toDouble();
      final lat = (p[1] as num?)?.toDouble();
      if (lat == null || lon == null || lat.abs() > 90 || lon.abs() > 180) {
        return null;
      }
      points.add(LatLng(lat, lon));
    }
    return points;
  }

  if (coordinates is! List) return const [];
  return switch (type) {
    'Polygon' => [?ring(coordinates.firstOrNull)],
    'MultiPolygon' => [
      for (final polygon in coordinates)
        if (polygon is List) ?ring(polygon.firstOrNull),
    ],
    _ => const [],
  };
}

/// Perfil territorial completo: zonas + catálogo de padecimientos + fuente.
class TerritoryProfile {
  const TerritoryProfile({
    required this.zones,
    required this.conditions,
    required this.source,
    required this.sourceUrl,
    required this.consultedOn,
    required this.version,
    required this.method,
  });

  final List<MacroZone> zones;
  final List<SeasonalCondition> conditions;
  final String source, sourceUrl, consultedOn, version, method;

  /// Padecimientos de una zona: primero los de temporada vigente.
  ({List<SeasonalCondition> now, List<SeasonalCondition> later}) forZone(
    String zoneId,
    int month,
  ) {
    final inZone = conditions.where((c) => c.zones.contains(zoneId));
    return (
      now: inZone.where((c) => c.season.isActive(month)).toList(),
      later: inZone.where((c) => !c.season.isActive(month)).toList(),
    );
  }

  /// Temporadas vigentes (sin «todo el año», que no es una temporada).
  static List<Season> activeSeasons(int month) => [
    for (final s in Season.values)
      if (s != Season.todoElAnio && s.isActive(month)) s,
  ];

  static TerritoryProfile parse({
    required String geoJson,
    required String catalogJson,
  }) {
    final geo = jsonDecode(geoJson);
    if (geo is! Map || geo['type'] != 'FeatureCollection') {
      throw const FormatException('La capa de zonas no es un GeoJSON válido.');
    }
    final catalog = Map<String, dynamic>.from(jsonDecode(catalogJson) as Map);
    final meta = Map<String, dynamic>.from(catalog['metadata'] as Map? ?? {});
    return TerritoryProfile(
      zones: [
        for (final f in geo['features'] as List? ?? const [])
          if (f is Map) ?MacroZone.fromFeature(Map<String, dynamic>.from(f)),
      ],
      conditions: [
        for (final c in catalog['padecimientos'] as List? ?? const [])
          if (c is Map)
            SeasonalCondition.fromJson(Map<String, dynamic>.from(c)),
      ],
      source: '${meta['fuente'] ?? 'Sin fuente'}',
      sourceUrl: '${meta['url'] ?? ''}',
      consultedOn: '${meta['fecha_consulta'] ?? ''}',
      version: '${meta['version'] ?? ''}',
      method: '${meta['metodo'] ?? ''}',
    );
  }
}

// ---------------------------------------------------------------------------
// Clima y alertas preventivas
// ---------------------------------------------------------------------------

/// Clima actual de Cancún según Open-Meteo.
class WeatherNow {
  const WeatherNow({
    required this.temperature,
    required this.apparentTemperature,
    required this.humidity,
    required this.precipitation,
    required this.rainLast7Days,
    required this.observedAt,
  });

  final double temperature, apparentTemperature, humidity, precipitation;

  /// Lluvia acumulada (mm) de los últimos 7 días, incluido hoy.
  final double rainLast7Days;
  final String observedAt;

  /// Lee la respuesta de `/v1/forecast`. Lanza `FormatException` si faltan
  /// las variables actuales; la lluvia diaria es opcional.
  factory WeatherNow.fromOpenMeteo(Map<String, dynamic> json) {
    final current = json['current'];
    if (current is! Map) {
      throw const FormatException('Respuesta de clima incompleta.');
    }
    double read(String key) {
      final v = current[key];
      if (v is! num) throw FormatException('Falta $key en el clima.');
      return v.toDouble();
    }

    final daily = (json['daily'] as Map?)?['precipitation_sum'] as List?;
    final rains = [
      for (final v in daily ?? const [])
        if (v is num) v.toDouble(),
    ];
    final last7 = rains.length > 7 ? rains.sublist(rains.length - 7) : rains;
    return WeatherNow(
      temperature: read('temperature_2m'),
      apparentTemperature: read('apparent_temperature'),
      humidity: read('relative_humidity_2m'),
      precipitation: read('precipitation'),
      rainLast7Days: last7.fold(0, (a, b) => a + b),
      observedAt: '${current['time'] ?? ''}',
    );
  }
}

/// Umbrales de las alertas (versionados junto con los códigos C0x).
abstract final class ClimateThresholds {
  static const heatC = 36.0;
  static const warmC = 32.0;
  static const humidityPct = 85.0;
  static const rainyWeekMm = 20.0;
  static const dryWeekMm = 5.0;
  static const version = '2026.11-1';
}

enum AlertKind { calor, gastro, vectores, humedad }

/// Alerta preventiva derivada del clima. No es una alerta epidemiológica:
/// indica condiciones que favorecen ciertos padecimientos.
class ClimateAlert {
  const ClimateAlert({
    required this.code,
    required this.kind,
    required this.title,
    required this.reason,
    required this.advice,
  });
  final String code, title, reason, advice;
  final AlertKind kind;
}

String _n(double v) => v.toStringAsFixed(v.truncateToDouble() == v ? 0 : 1);

/// Reglas C01–C04. Puras: mismo clima y mes → mismas alertas.
List<ClimateAlert> evaluateAlerts(WeatherNow w, int month) {
  final hottest = w.temperature > w.apparentTemperature
      ? w.temperature
      : w.apparentTemperature;
  return [
    if (hottest > ClimateThresholds.heatC)
      ClimateAlert(
        code: 'C01',
        kind: AlertKind.calor,
        title: 'Calor extremo',
        reason: 'Sensación térmica de ${_n(hottest)} °C.',
        advice:
            'Toma agua seguido aunque no tengas sed, busca sombra entre 11:00 y 16:00 '
            'y vigila a niñas, niños y personas mayores. Mareo, confusión o piel '
            'caliente y seca requieren atención inmediata.',
      ),
    if (w.temperature >= ClimateThresholds.warmC &&
        w.rainLast7Days < ClimateThresholds.dryWeekMm)
      ClimateAlert(
        code: 'C02',
        kind: AlertKind.gastro,
        title: 'Riesgo de infecciones intestinales',
        reason:
            'Calor de ${_n(w.temperature)} °C con semana seca '
            '(${_n(w.rainLast7Days)} mm).',
        advice:
            'Los alimentos se descomponen más rápido: refrigera, lava frutas y '
            'verduras, toma agua purificada y lávate las manos. Ten suero oral a la mano.',
      ),
    if (w.rainLast7Days >= ClimateThresholds.rainyWeekMm ||
        w.precipitation >= 1)
      ClimateAlert(
        code: 'C03',
        kind: AlertKind.vectores,
        title: 'Agua acumulada: mosquitos y leptospirosis',
        reason: '${_n(w.rainLast7Days)} mm de lluvia en los últimos 7 días.',
        advice:
            'Voltea o tapa recipientes con agua, usa repelente y evita caminar '
            'descalzo en charcos o zonas inundadas. Fiebre alta con dolor de '
            'cuerpo requiere valoración médica.',
      ),
    if (w.humidity > ClimateThresholds.humidityPct)
      ClimateAlert(
        code: 'C04',
        kind: AlertKind.humedad,
        title: Season.nortes.isActive(month)
            ? 'Humedad alta y frentes fríos'
            : 'Humedad alta',
        reason: 'Humedad relativa de ${_n(w.humidity)} %.',
        advice: Season.nortes.isActive(month)
            ? 'Favorece moho, alergias e infecciones respiratorias. Ventila tu casa, '
                  'abrígate en los cambios de temperatura y cubre nariz y boca al toser.'
            : 'Favorece moho y alergias. Ventila tu casa y seca bien la ropa.',
      ),
  ];
}

// ---------------------------------------------------------------------------
// Reglas editoriales (R01…) de respaldo
// ---------------------------------------------------------------------------

/// Regla R01 local, idéntica a la publicada en Supabase. Se usa sin conexión
/// para que la pantalla nunca quede vacía.
const fallbackRules = [
  PreventionRule(
    'Menos criaderos, más prevención',
    'Reduce los recipientes con agua acumulada y protege tu hogar de los mosquitos. Consulta la fuente para conocer medidas de prevención.',
    'OMS · Dengue y dengue grave',
    'https://www.who.int/es/news-room/fact-sheets/detail/dengue-and-severe-dengue',
    '2026-11-17',
    code: 'R01',
    scope: 'Educación general',
    expiresOn: '2027-02-15',
  ),
];

/// Deja solo reglas vigentes; la RLS ya lo hace en el servidor, pero el
/// respaldo local también caduca.
List<PreventionRule> activeRules(List<PreventionRule> rules, DateTime today) {
  final day = DateTime(today.year, today.month, today.day);
  return rules.where((r) {
    final expires = DateTime.tryParse(r.expiresOn ?? '');
    return expires == null || !expires.isBefore(day);
  }).toList();
}

// ---------------------------------------------------------------------------
// Repositorio
// ---------------------------------------------------------------------------

/// Resultado del clima: valor (o `null`) más aviso recuperable.
class WeatherResult {
  const WeatherResult(this.weather, {this.notice, this.fromCache = false});
  final WeatherNow? weather;
  final String? notice;
  final bool fromCache;
}

/// Acceso a datos territoriales y de clima. La UI nunca habla con HTTP ni
/// con archivos directamente (mismo criterio que `CareRepository`).
class TerritoryRepository {
  TerritoryRepository({
    http.Client? httpClient,
    AssetLoader? loadAsset,
    this.timeout = const Duration(seconds: 10),
  }) : _http = httpClient ?? http.Client(),
       _loadAsset = loadAsset ?? rootBundle.loadString;

  static const zonesAsset = 'assets/geo/cancun_macrozonas.geojson';
  static const catalogAsset = 'assets/geo/perfil_estacional.json';
  static final weatherUri = Uri.https('api.open-meteo.com', '/v1/forecast', {
    'latitude': '${cancunCenter.latitude}',
    'longitude': '${cancunCenter.longitude}',
    'current': 'temperature_2m,relative_humidity_2m,precipitation,apparent_temperature',
    'daily': 'precipitation_sum',
    'past_days': '7',
    'forecast_days': '1',
    'timezone': 'America/Cancun',
  });

  final http.Client _http;
  final AssetLoader _loadAsset;
  final Duration timeout;
  WeatherNow? _lastWeather;
  TerritoryProfile? _profile;

  /// Perfil local (siempre empaquetado en la app; se lee una vez).
  Future<TerritoryProfile> profile() async =>
      _profile ??= TerritoryProfile.parse(
        geoJson: await _loadAsset(zonesAsset),
        catalogJson: await _loadAsset(catalogAsset),
      );

  /// Clima actual. Nunca lanza: si falla devuelve la última lectura de la
  /// sesión o `null` con un aviso para el usuario.
  Future<WeatherResult> weather() async {
    try {
      final response = await _http.get(weatherUri).timeout(timeout);
      if (response.statusCode != 200) {
        throw http.ClientException('Open-Meteo ${response.statusCode}');
      }
      final json = jsonDecode(utf8.decode(response.bodyBytes));
      final weather = WeatherNow.fromOpenMeteo(
        Map<String, dynamic>.from(json as Map),
      );
      _lastWeather = weather;
      return WeatherResult(weather);
    } catch (_) {
      if (_lastWeather != null) {
        return WeatherResult(
          _lastWeather,
          fromCache: true,
          notice: 'Sin conexión: mostramos la última lectura de clima.',
        );
      }
      return const WeatherResult(
        null,
        notice: 'No pudimos consultar el clima ahora. Te mostramos las recomendaciones de temporada.',
      );
    }
  }
}
