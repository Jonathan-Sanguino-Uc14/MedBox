/// Farmacias y puntos de atención cercanos en Cancún.
///
/// Información pública de ubicación. No consulta inventario, no guarda la
/// ubicación del usuario y no toca expedientes clínicos.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import 'config.dart';
import 'territory.dart' show AssetLoader;

/// ¿Tiene consultorio anexo? Ninguna fuente lo declara directamente, así que
/// solo se afirma cuando hay un consultorio registrado en el mismo punto.
enum ClinicStatus {
  registrado('Consultorio registrado en el mismo domicilio'),
  noRegistrado('Sin consultorio registrado en el domicilio'),
  sinDato('Consultorio anexo: sin dato');

  const ClinicStatus(this.label);
  final String label;
}

/// Procedencia de los resultados, con la atribución que exige cada licencia.
enum PharmacyOrigin {
  osm('© colaboradores de OpenStreetMap (ODbL) · consulta en línea'),
  denue('INEGI · DENUE (consulta en línea)'),
  respaldo('© colaboradores de OpenStreetMap (ODbL) · copia local');

  const PharmacyOrigin(this.attribution);
  final String attribution;
}

class Pharmacy {
  const Pharmacy({
    required this.id,
    required this.name,
    required this.address,
    required this.location,
    this.brand = '',
    this.colonia = '',
    this.phone = '',
    this.clinic = ClinicStatus.sinDato,
    this.distanceMeters,
  });

  final String id, name, address, brand, colonia, phone;
  final LatLng location;
  final ClinicStatus clinic;
  final double? distanceMeters;

  Pharmacy copyWith({ClinicStatus? clinic, double? distanceMeters}) => Pharmacy(
    id: id,
    name: name,
    address: address,
    location: location,
    brand: brand,
    colonia: colonia,
    phone: phone,
    clinic: clinic ?? this.clinic,
    distanceMeters: distanceMeters ?? this.distanceMeters,
  );

  /// Texto para la búsqueda manual (sin acentos ni mayúsculas).
  String get searchText => normalize('$name $brand $address $colonia');

  /// Elemento de Overpass (`out center tags`). Sin nombre o sin
  /// coordenadas se descarta.
  static Pharmacy? fromOsm(Map<String, dynamic> e) {
    final tags = Map<String, dynamic>.from(e['tags'] as Map? ?? {});
    final center = e['center'] as Map?;
    final lat = ((e['lat'] ?? center?['lat']) as num?)?.toDouble();
    final lon = ((e['lon'] ?? center?['lon']) as num?)?.toDouble();
    final name = '${tags['name'] ?? tags['brand'] ?? ''}'.trim();
    if (lat == null || lon == null || name.isEmpty) return null;
    final street = [
      tags['addr:street'],
      tags['addr:housenumber'],
    ].whereType<String>().join(' ').trim();
    return Pharmacy(
      id: 'osm-${e['type']}-${e['id']}',
      name: name,
      brand: '${tags['brand'] ?? ''}',
      address: street,
      colonia: '${tags['addr:suburb'] ?? ''}',
      phone: '${tags['phone'] ?? tags['contact:phone'] ?? ''}',
      location: LatLng(lat, lon),
    );
  }

  /// Registro del DENUE: las coordenadas llegan como texto.
  static Pharmacy? fromDenue(Map<String, dynamic> r) {
    final lat = double.tryParse('${r['Latitud'] ?? ''}');
    final lon = double.tryParse('${r['Longitud'] ?? ''}');
    final name = '${r['Nombre'] ?? ''}'.trim();
    if (lat == null || lon == null || name.isEmpty) return null;
    String part(String key) => '${r[key] ?? ''}'.trim();
    final street = [
      part('Tipo_vialidad'),
      part('Calle'),
      part('Num_Exterior'),
    ].where((s) => s.isNotEmpty && s != '0').join(' ');
    final colonia = part('Colonia');
    return Pharmacy(
      id: '${r['CLEE'] ?? r['Id'] ?? name}',
      name: name,
      address: [
        street,
        if (colonia.isNotEmpty) colonia,
        if (part('CP').isNotEmpty) 'C.P. ${part('CP')}',
      ].where((s) => s.isNotEmpty).join(', '),
      colonia: colonia,
      phone: part('Telefono'),
      location: LatLng(lat, lon),
    );
  }

  /// Formato de la copia local (`assets/geo/farmacias_respaldo.json`).
  static Pharmacy? fromBackup(Map<String, dynamic> r) {
    final lat = (r['lat'] as num?)?.toDouble();
    final lon = (r['lon'] as num?)?.toDouble();
    final name = '${r['nombre'] ?? ''}'.trim();
    if (lat == null || lon == null || name.isEmpty) return null;
    return Pharmacy(
      id: '${r['id'] ?? name}',
      name: name,
      brand: '${r['marca'] ?? ''}',
      address: '${r['direccion'] ?? ''}',
      colonia: '${r['colonia'] ?? ''}',
      phone: '${r['telefono'] ?? ''}',
      location: LatLng(lat, lon),
      clinic: switch (r['consultorio_anexo']) {
        true => ClinicStatus.registrado,
        false => ClinicStatus.noRegistrado,
        _ => ClinicStatus.sinDato,
      },
    );
  }
}

/// Resultado de búsqueda con procedencia y aviso recuperable.
class PharmacyResult {
  const PharmacyResult({
    required this.items,
    required this.origin,
    this.notice,
    this.consultedOn,
  });
  final List<Pharmacy> items;
  final PharmacyOrigin origin;
  final String? notice, consultedOn;
}

/// Quita acentos y mayúsculas para comparar textos en español.
String normalize(String text) {
  const from = 'áéíóúüñÁÉÍÓÚÜÑ';
  const to = 'aeiouunaeiouun';
  final buffer = StringBuffer();
  for (final ch in text.split('')) {
    final i = from.indexOf(ch);
    buffer.write(i >= 0 ? to[i] : ch);
  }
  return buffer.toString().toLowerCase().trim();
}

/// Distancia en metros (fórmula del semiverseno).
double distanceMeters(LatLng a, LatLng b) {
  const earth = 6371000.0;
  double rad(double d) => d * math.pi / 180;
  final dLat = rad(b.latitude - a.latitude);
  final dLon = rad(b.longitude - a.longitude);
  final h =
      math.pow(math.sin(dLat / 2), 2) +
      math.cos(rad(a.latitude)) *
          math.cos(rad(b.latitude)) *
          math.pow(math.sin(dLon / 2), 2);
  return 2 * earth * math.asin(math.sqrt(h));
}

String formatDistance(double meters) => meters < 1000
    ? '${meters.round()} m'
    : '${(meters / 1000).toStringAsFixed(1)} km';

/// Marca «registrado» si hay un consultorio a [toleranceMeters] o menos.
List<Pharmacy> matchClinics(
  List<Pharmacy> pharmacies,
  List<LatLng> clinics, {
  double toleranceMeters = 30,
}) => [
  for (final p in pharmacies)
    p.copyWith(
      clinic:
          clinics.any((c) => distanceMeters(p.location, c) <= toleranceMeters)
          ? ClinicStatus.registrado
          : ClinicStatus.noRegistrado,
    ),
];

/// Filtra por texto y ordena por cercanía al origen.
List<Pharmacy> rankPharmacies(
  List<Pharmacy> items, {
  required LatLng origin,
  String query = '',
  double? maxMeters,
}) {
  final q = normalize(query);
  final ranked = [
    for (final p in items)
      if (q.isEmpty || p.searchText.contains(q))
        p.copyWith(distanceMeters: distanceMeters(origin, p.location)),
  ]..sort((a, b) => a.distanceMeters!.compareTo(b.distanceMeters!));
  return maxMeters == null
      ? ranked
      : ranked.where((p) => p.distanceMeters! <= maxMeters).toList();
}

/// Consulta de farmacias con cadena de respaldo:
/// DENUE (si hay token) → OpenStreetMap → última respuesta → copia local.
class PharmacyRepository {
  PharmacyRepository({
    http.Client? httpClient,
    AssetLoader? loadAsset,
    this.denueToken = inegiDenueToken,
    // Overpass puede saturarse; más de 10 s se siente bloqueado.
    this.timeout = const Duration(seconds: 10),
  }) : _http = httpClient ?? http.Client(),
       _loadAsset = loadAsset ?? rootBundle.loadString;

  static const backupAsset = 'assets/geo/farmacias_respaldo.json';
  static final overpassUri = Uri.parse(
    'https://overpass-api.de/api/interpreter',
  );
  static const _denueBase =
      'https://www.inegi.org.mx/app/api/denue/v1/consulta/Buscar';
  static const maxRadiusMeters = 5000;

  final http.Client _http;
  final AssetLoader _loadAsset;
  final String denueToken;
  final Duration timeout;
  ({List<Pharmacy> items, PharmacyOrigin origin})? _lastOnline;

  Future<PharmacyResult> search({
    required LatLng origin,
    String query = '',
    int radiusMeters = 3000,
  }) async {
    final radius = radiusMeters.clamp(200, maxRadiusMeters);
    final online = <(PharmacyOrigin, Future<List<Pharmacy>> Function())>[
      if (denueToken.isNotEmpty)
        (PharmacyOrigin.denue, () => _denueWithClinics(origin, radius)),
      (PharmacyOrigin.osm, () => _overpass(origin, radius)),
    ];
    for (final (source, fetch) in online) {
      try {
        final items = await fetch();
        _lastOnline = (items: items, origin: source);
        return PharmacyResult(
          items: rankPharmacies(items, origin: origin, query: query),
          origin: source,
          consultedOn: _today(),
        );
      } catch (_) {
        // Se intenta la siguiente fuente.
      }
    }
    const offline = 'No pudimos consultar el directorio en línea.';
    final last = _lastOnline;
    if (last != null) {
      return PharmacyResult(
        items: rankPharmacies(
          last.items,
          origin: origin,
          query: query,
          maxMeters: radius.toDouble(),
        ),
        origin: last.origin,
        notice: '$offline Mostramos la última consulta de esta sesión.',
      );
    }
    final backup = await _backup();
    return PharmacyResult(
      // La copia local es pequeña: se muestra lo más cercano hasta 5 km.
      items: rankPharmacies(
        backup.items,
        origin: origin,
        query: query,
        maxMeters: maxRadiusMeters.toDouble(),
      ),
      origin: PharmacyOrigin.respaldo,
      consultedOn: backup.consultedOn,
      notice: '$offline Mostramos la copia local guardada en la app.',
    );
  }

  /// Farmacias y consultorios en una sola consulta a Overpass.
  Future<List<Pharmacy>> _overpass(LatLng at, int radius) async {
    final around = 'around:$radius,${at.latitude},${at.longitude}';
    final query =
        '[out:json][timeout:20];('
        'nwr["amenity"="pharmacy"]($around);'
        'nwr["amenity"~"^(doctors|clinic)\$"]($around););'
        'out center tags;';
    final response = await _http
        .post(
          overpassUri,
          headers: {'User-Agent': 'MedBox-paciente/0.1'},
          body: {'data': query},
        )
        .timeout(timeout);
    // 429/502/504: servidor saturado → se usa el respaldo.
    if (response.statusCode != 200) {
      throw http.ClientException('Overpass ${response.statusCode}');
    }
    final elements =
        (jsonDecode(utf8.decode(response.bodyBytes)) as Map)['elements']
            as List? ??
        const [];
    final pharmacies = <Pharmacy>[];
    final clinics = <LatLng>[];
    for (final raw in elements.whereType<Map>()) {
      final e = Map<String, dynamic>.from(raw);
      final amenity = (e['tags'] as Map?)?['amenity'];
      final p = Pharmacy.fromOsm(e);
      if (p == null) continue;
      amenity == 'pharmacy' ? pharmacies.add(p) : clinics.add(p.location);
    }
    return matchClinics(pharmacies, clinics);
  }

  Future<List<Pharmacy>> _denueWithClinics(LatLng at, int radius) async {
    final found = await _denue('farmacia', at, radius);
    try {
      final clinics = await _denue('consultorio', at, radius);
      return matchClinics(found, [for (final c in clinics) c.location]);
    } catch (_) {
      return found; // El consultorio queda «sin dato».
    }
  }

  Future<List<Pharmacy>> _denue(String term, LatLng at, int radius) async {
    final uri = Uri.parse(
      '$_denueBase/${Uri.encodeComponent(term)}/'
      '${at.latitude.toStringAsFixed(6)},${at.longitude.toStringAsFixed(6)}/'
      '$radius/$denueToken',
    );
    final response = await _http.get(uri).timeout(timeout);
    if (response.statusCode != 200) {
      throw http.ClientException('DENUE ${response.statusCode}');
    }
    final body = jsonDecode(utf8.decode(response.bodyBytes));
    if (body is! List) return const []; // Sin resultados llega un mensaje.
    return [
      for (final row in body.whereType<Map>())
        ?Pharmacy.fromDenue(Map<String, dynamic>.from(row)),
    ];
  }

  Future<({List<Pharmacy> items, String? consultedOn})> _backup() async {
    try {
      final json = jsonDecode(await _loadAsset(backupAsset)) as Map;
      final meta = Map<String, dynamic>.from(json['metadata'] as Map? ?? {});
      return (
        items: [
          for (final row
              in (json['items'] as List? ?? const []).whereType<Map>())
            ?Pharmacy.fromBackup(Map<String, dynamic>.from(row)),
        ],
        consultedOn: meta['fecha_consulta'] as String?,
      );
    } catch (_) {
      return (items: <Pharmacy>[], consultedOn: null);
    }
  }

  static String _today() {
    final d = DateTime.now();
    return '${d.year}-${'${d.month}'.padLeft(2, '0')}-${'${d.day}'.padLeft(2, '0')}';
  }
}
