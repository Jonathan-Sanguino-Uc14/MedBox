import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:med_box/data.dart';
import 'package:med_box/pharmacies.dart';
import 'package:med_box/pharmacies_screen.dart';
import 'package:med_box/territory.dart';

String _asset(String path) => File(path).readAsStringSync();
Future<String> _localAsset(String path) async => _asset(path);

WeatherNow _weather({
  double t = 28,
  double feels = 30,
  double rh = 70,
  double now = 0,
  double week = 0,
}) => WeatherNow(
  temperature: t,
  apparentTemperature: feels,
  humidity: rh,
  precipitation: now,
  rainLast7Days: week,
  observedAt: '2026-11-17T19:00',
);

Map<String, dynamic> _osm(
  String type,
  int id,
  String amenity,
  double lat,
  double lon, {
  String? name,
}) => {
  'type': type,
  'id': id,
  if (type == 'node') 'lat': lat,
  if (type == 'node') 'lon': lon,
  if (type != 'node') 'center': {'lat': lat, 'lon': lon},
  'tags': {'amenity': amenity, 'name': ?name},
};

void main() {
  group('Perfil territorial', () {
    late TerritoryProfile profile;
    setUp(() {
      profile = TerritoryProfile.parse(
        geoJson: _asset('assets/geo/cancun_macrozonas.geojson'),
        catalogJson: _asset('assets/geo/perfil_estacional.json'),
      );
    });

    test('Incluye las 4 macro-zonas dentro de Benito Juárez', () {
      expect(profile.zones.map((z) => z.id), [
        'hotel_centro',
        'regiones_densas',
        'periferia_selva',
        'sur_huayacan',
      ]);
      for (final p in profile.zones.expand((z) => z.rings).expand((r) => r)) {
        expect(p.latitude, inInclusiveRange(20.9, 21.3));
        expect(p.longitude, inInclusiveRange(-87.1, -86.7));
      }
      expect(profile.sourceUrl, startsWith('https://'));
    });

    test('Cada padecimiento apunta a zonas existentes', () {
      final ids = profile.zones.map((z) => z.id).toSet();
      for (final c in profile.conditions) {
        expect(c.zones, isNotEmpty, reason: c.id);
        expect(ids.containsAll(c.zones), isTrue, reason: c.id);
      }
    });

    test('Noviembre combina lluvias y nortes; enero solo nortes', () {
      expect(TerritoryProfile.activeSeasons(11), [
        Season.calorLluvias,
        Season.nortes,
      ]);
      expect(TerritoryProfile.activeSeasons(1), [Season.nortes]);
      expect(TerritoryProfile.activeSeasons(6), [Season.calorLluvias]);
    });

    test('Borde de selva incluye leishmaniasis todo el año', () {
      final enero = profile.forZone('periferia_selva', 1);
      expect(enero.now.map((c) => c.id), contains('leishmaniasis'));
      expect(enero.later.map((c) => c.id), contains('dengue_zika'));
      final centro = profile.forZone('hotel_centro', 1);
      expect(
        [...centro.now, ...centro.later].map((c) => c.id),
        isNot(contains('leishmaniasis')),
      );
    });

    test('Geometrías inválidas se descartan sin romper la capa', () {
      final p = TerritoryProfile.parse(
        geoJson: jsonEncode({
          'type': 'FeatureCollection',
          'features': [
            {
              'type': 'Feature',
              'properties': {'id': 'a', 'nombre': 'A'},
              'geometry': {
                'type': 'Polygon',
                'coordinates': [
                  [
                    [0, 200],
                    [1, 1],
                    [2, 2],
                    [0, 200],
                  ],
                ],
              },
            },
            {
              'type': 'Feature',
              'properties': {'id': 'b'},
            },
          ],
        }),
        catalogJson: '{}',
      );
      expect(p.zones, isEmpty);
      expect(
        () => TerritoryProfile.parse(geoJson: '{}', catalogJson: '{}'),
        throwsFormatException,
      );
    });
  });

  group('Alertas por clima', () {
    test('Calor extremo usa la sensación térmica', () {
      final codes = evaluateAlerts(
        _weather(t: 34, feels: 38.5, week: 30),
        7,
      ).map((a) => a.code);
      expect(codes, contains('C01'));
    });

    test('Calor con semana seca dispara riesgo gastrointestinal', () {
      final codes = evaluateAlerts(
        _weather(t: 33, week: 1),
        5,
      ).map((a) => a.code);
      expect(codes, contains('C02'));
      expect(codes, isNot(contains('C03')));
    });

    test('Lluvia acumulada dispara vectores; humedad >85 % la C04', () {
      final alerts = evaluateAlerts(_weather(t: 24, rh: 98, week: 70.9), 11);
      expect(alerts.map((a) => a.code), ['C03', 'C04']);
      expect(alerts.last.title, contains('frentes fríos'));
      expect(evaluateAlerts(_weather(rh: 85), 6), isEmpty);
    });

    test('Lee la respuesta de Open-Meteo y suma 7 días de lluvia', () {
      final w = WeatherNow.fromOpenMeteo({
        'current': {
          'time': '2026-11-17T19:00',
          'temperature_2m': 24.4,
          'relative_humidity_2m': 98,
          'precipitation': 0.0,
          'apparent_temperature': 30.5,
        },
        'daily': {
          'precipitation_sum': [5.0, 8.0, 29.5, 4.2, 14.8, 1.7, 4.0, 3.7],
        },
      });
      expect(w.humidity, 98);
      expect(w.rainLast7Days, closeTo(65.9, .001));
      expect(
        () => WeatherNow.fromOpenMeteo({'current': {}}),
        throwsFormatException,
      );
    });

    test('Sin red: aviso, y luego la última lectura de la sesión', () async {
      var online = true;
      final repo = TerritoryRepository(
        httpClient: MockClient((_) async {
          if (!online) throw const SocketException('sin red');
          return http.Response(
            jsonEncode({
              'current': {
                'time': '2026-11-17T19:00',
                'temperature_2m': 30,
                'relative_humidity_2m': 60,
                'precipitation': 0,
                'apparent_temperature': 33,
              },
            }),
            200,
          );
        }),
      );
      expect((await repo.weather()).weather?.temperature, 30);
      online = false;
      final cached = await repo.weather();
      expect(cached.fromCache, isTrue);
      expect(cached.notice, isNotNull);
      final fresh = await TerritoryRepository(
        httpClient: MockClient((_) async => http.Response('error', 503)),
      ).weather();
      expect(fresh.weather, isNull);
      expect(fresh.notice, contains('temporada'));
    });
  });

  test('Las reglas caducadas no se muestran', () {
    const old = PreventionRule(
      't',
      'b',
      's',
      'u',
      '2026-01-01',
      code: 'R09',
      expiresOn: '2026-02-01',
    );
    expect(
      activeRules([
        ...fallbackRules,
        old,
      ], DateTime(2026, 11, 17)).map((r) => r.code),
      ['R01'],
    );
  });

  group('Farmacias', () {
    test('La copia local trae cadenas reales con coordenadas', () {
      final json = jsonDecode(_asset(PharmacyRepository.backupAsset)) as Map;
      final items = [
        for (final r in json['items'] as List)
          ?Pharmacy.fromBackup(Map<String, dynamic>.from(r as Map)),
      ];
      expect(items.length, greaterThan(20));
      final text = items.map((p) => p.searchText).join(' ');
      for (final chain in ['ahorro', 'similares', 'yza', 'guadalajara']) {
        expect(text, contains(chain));
      }
      expect((json['metadata'] as Map)['licencia'], contains('ODbL'));
    });

    test('Elementos de Overpass: nodo y vía con centro', () {
      final node = Pharmacy.fromOsm(
        _osm('node', 1, 'pharmacy', 21.16, -86.83, name: 'Farmacia Yza'),
      )!;
      final way = Pharmacy.fromOsm(
        _osm('way', 2, 'pharmacy', 21.17, -86.84, name: 'Similares'),
      )!;
      expect(node.id, 'osm-node-1');
      expect(way.location.latitude, 21.17);
      expect(Pharmacy.fromOsm(_osm('node', 3, 'pharmacy', 21, -86)), isNull);
    });

    test('Consultorio solo se marca si coincide el domicilio', () {
      final near = Pharmacy.fromOsm(
        _osm('node', 1, 'pharmacy', 21.16, -86.83, name: 'A'),
      )!;
      final far = Pharmacy.fromOsm(
        _osm('node', 2, 'pharmacy', 21.17, -86.83, name: 'B'),
      )!;
      final matched = matchClinics(
        [near, far],
        [const LatLng(21.1601, -86.83)],
      );
      expect(matched.map((p) => p.clinic), [
        ClinicStatus.registrado,
        ClinicStatus.noRegistrado,
      ]);
    });

    test('Búsqueda ignora acentos y ordena por distancia', () {
      final items = [
        Pharmacy.fromOsm(
          _osm('node', 1, 'pharmacy', 21.20, -86.83, name: 'Lejana'),
        )!,
        Pharmacy.fromOsm(
          _osm('node', 2, 'pharmacy', 21.161, -86.851, name: 'Cercána'),
        )!,
      ];
      expect(rankPharmacies(items, origin: cancunCenter).first.name, 'Cercána');
      expect(
        rankPharmacies(items, origin: cancunCenter, query: 'cercana'),
        hasLength(1),
      );
      expect(formatDistance(1530), '1.5 km');
    });

    test('Overpass responde: cruza farmacias con consultorios', () async {
      final repo = PharmacyRepository(
        denueToken: '',
        httpClient: MockClient((request) async {
          expect(request.method, 'POST');
          return http.Response.bytes(
            utf8.encode(
              jsonEncode({
                'elements': [
                  _osm(
                    'node',
                    1,
                    'pharmacy',
                    21.162,
                    -86.8515,
                    name: 'Farmacias Similares',
                  ),
                  _osm(
                    'node',
                    2,
                    'doctors',
                    21.1621,
                    -86.8515,
                    name: 'Consultorio',
                  ),
                ],
              }),
            ),
            200,
          );
        }),
        loadAsset: (_) async => throw StateError('no debe usarse'),
      );
      final result = await repo.search(origin: cancunCenter);
      expect(result.origin, PharmacyOrigin.osm);
      expect(result.items.single.clinic, ClinicStatus.registrado);
      expect(result.notice, isNull);
    });

    test('Overpass saturado (502) cae a la copia local con aviso', () async {
      final repo = PharmacyRepository(
        denueToken: '',
        httpClient: MockClient((_) async => http.Response('at capacity', 502)),
        loadAsset: _localAsset,
      );
      final result = await repo.search(origin: cancunCenter, query: 'yza');
      expect(result.origin, PharmacyOrigin.respaldo);
      expect(result.notice, contains('copia local'));
      expect(result.items, isNotEmpty);
      expect(result.items.every((p) => p.searchText.contains('yza')), isTrue);
    });

    test('DENUE con token se intenta primero', () async {
      final repo = PharmacyRepository(
        denueToken: 'tok',
        httpClient: MockClient((request) async {
          final isClinic = request.url.path.contains('/consultorio/');
          return http.Response.bytes(
            utf8.encode(
              jsonEncode([
                {
                  'Nombre': isClinic ? 'CONSULTORIO' : 'FARMACIA DOS',
                  'Calle': 'TULUM',
                  'Latitud': '21.1620',
                  'Longitud': '-86.8515',
                },
              ]),
            ),
            200,
          );
        }),
      );
      final result = await repo.search(origin: cancunCenter);
      expect(result.origin, PharmacyOrigin.denue);
      expect(result.items.single.clinic, ClinicStatus.registrado);
    });
  });

  testWidgets('Pantalla de farmacias sin red muestra la copia local', (
    tester,
  ) async {
    final offline = MockClient((_) async => throw const SocketException('x'));
    await tester.pumpWidget(
      MaterialApp(
        home: PharmacyScreen(
          pharmacies: PharmacyRepository(
            denueToken: '',
            httpClient: offline,
            loadAsset: _localAsset,
          ),
          territory: TerritoryRepository(
            httpClient: offline,
            loadAsset: _localAsset,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('insumos generales'), findsOneWidget);
    expect(find.textContaining('copia local'), findsWidgets);
    await tester.enterText(find.byType(TextField), 'similares');
    await tester.tap(find.byTooltip('Buscar'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.textContaining('establecimientos cerca'), findsOneWidget);
  });
}
