/// Pantalla de búsqueda de farmacias y puntos de atención en Cancún.
/// Solo ubicación: sin inventario, sin diagnóstico y sin guardar ubicación.
library;

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import 'pharmacies.dart';
import 'public_info_widgets.dart';
import 'territory.dart';
import 'theme.dart';

/// Desde dónde se busca: una zona (sin permisos) o el teléfono (con permiso).
class _SearchOrigin {
  const _SearchOrigin(this.label, this.point, {this.fromDevice = false});
  final String label;
  final LatLng point;
  final bool fromDevice;
}

class PharmacyScreen extends StatefulWidget {
  const PharmacyScreen({
    super.key,
    required this.pharmacies,
    required this.territory,
    this.initialZone,
  });
  final PharmacyRepository pharmacies;
  final TerritoryRepository territory;

  /// Macro-zona elegida en el observatorio, para buscar ahí de entrada.
  final MacroZone? initialZone;

  @override
  State<PharmacyScreen> createState() => _PharmacyScreenState();
}

class _PharmacyScreenState extends State<PharmacyScreen> {
  final query = TextEditingController();
  late List<_SearchOrigin> origins = [
    const _SearchOrigin('Centro de Cancún', cancunCenter),
    if (widget.initialZone != null)
      _SearchOrigin(widget.initialZone!.name, widget.initialZone!.center),
  ];
  late _SearchOrigin origin = origins.last;
  late Future<PharmacyResult> result = _query();
  bool locating = false;
  String? locationMessage;
  bool locationBlocked = false;

  @override
  void initState() {
    super.initState();
    // Las macro-zonas sirven como origen sin pedir la ubicación.
    widget.territory
        .profile()
        .then((profile) {
          if (!mounted) return;
          setState(() {
            origins = [
              origins.first,
              for (final z in profile.zones) _SearchOrigin(z.name, z.center),
            ];
          });
        })
        .catchError((_) {});
  }

  @override
  void dispose() {
    query.dispose();
    super.dispose();
  }

  Future<PharmacyResult> _query() =>
      widget.pharmacies.search(origin: origin.point, query: query.text);

  void _search() {
    setState(() {
      result = _query();
    });
  }

  /// Pide permiso solo al tocar el botón y explica cada negativa; la
  /// búsqueda manual siempre sigue disponible.
  Future<void> _useLocation() async {
    setState(() {
      locating = true;
      locationMessage = null;
      locationBlocked = false;
    });
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        locationMessage = 'La ubicación del teléfono está apagada. Actívala o elige una zona.';
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        locationMessage =
            'No autorizaste la ubicación. Puedes buscar eligiendo una zona.';
        return;
      }
      if (permission == LocationPermission.deniedForever) {
        locationBlocked = true;
        locationMessage = 'La ubicación está bloqueada para Med Box. Puedes habilitarla en los ajustes del teléfono o elegir una zona.';
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 15),
        ),
      );
      // Se redondea a ~100 m antes de enviarla a un servicio externo.
      double round(double v) => (v * 1000).round() / 1000;
      origin = _SearchOrigin(
        'Tu ubicación aproximada',
        LatLng(round(position.latitude), round(position.longitude)),
        fromDevice: true,
      );
      _search();
    } catch (_) {
      locationMessage =
          'No pudimos obtener tu ubicación. Elige una zona para continuar.';
    } finally {
      if (mounted) setState(() => locating = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Farmacias cercanas')),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
            children: [
              Semantics(
                container: true,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: MedColors.secondary.withValues(alpha: .15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline, color: MedColors.primary),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Sección de ubicación para conseguir insumos generales '
                          '(suero oral, repelente, analgésicos). No confirmamos '
                          'existencias ni horarios y no damos diagnósticos. '
                          'En una emergencia llama al 911.',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: query,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _search(),
                decoration: InputDecoration(
                  labelText: 'Nombre, cadena o calle',
                  hintText: 'Ej. Similares, Yza, Del Ahorro',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: IconButton(
                    tooltip: 'Buscar',
                    icon: const Icon(Icons.arrow_forward),
                    onPressed: _search,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                // La clave fuerza a reflejar cambios de origen y de lista.
                key: ValueKey('${origin.label}-${origins.length}'),
                initialValue: origins.any((o) => o.label == origin.label)
                    ? origin.label
                    : null,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Buscar cerca de'),
                items: [
                  for (final o in origins)
                    DropdownMenuItem(value: o.label, child: Text(o.label)),
                ],
                onChanged: (label) {
                  origin = origins.firstWhere((o) => o.label == label);
                  _search();
                },
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: locating ? null : _useLocation,
                icon: locating
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.my_location),
                label: Text(
                  origin.fromDevice
                      ? 'Usando tu ubicación aproximada'
                      : 'Usar mi ubicación',
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text(
                  'Solo para esta búsqueda: se redondea a unos 100 m y se envía al '
                  'directorio de establecimientos. Med Box no la guarda.',
                  style: TextStyle(fontSize: 12, color: mutedText),
                ),
              ),
              if (locationMessage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      Expanded(child: Text(locationMessage!)),
                      if (locationBlocked)
                        TextButton(
                          onPressed: Geolocator.openAppSettings,
                          child: const Text('Ajustes'),
                        ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              FutureBuilder<PharmacyResult>(
                future: result,
                builder: (context, snap) {
                  if (snap.connectionState != ConnectionState.done) {
                    return const LoadingRow('Buscando establecimientos…');
                  }
                  if (snap.hasError || snap.data == null) {
                    return NoticeCard(
                      'No pudimos completar la búsqueda.',
                      onRetry: _search,
                    );
                  }
                  return _Results(
                    result: snap.data!,
                    origin: origin,
                    onRetry: _search,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _Results extends StatelessWidget {
  const _Results({
    required this.result,
    required this.origin,
    required this.onRetry,
  });
  final PharmacyResult result;
  final _SearchOrigin origin;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (result.notice != null) NoticeCard(result.notice!, onRetry: onRetry),
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Semantics(
          liveRegion: true,
          child: Text(
            result.items.isEmpty
                ? 'Sin resultados cerca de ${origin.label}.'
                : '${result.items.length} establecimientos cerca de ${origin.label}',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ),
      if (result.items.isEmpty)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Prueba con otra zona u otro nombre, o abre la búsqueda en un mapa externo.',
                ),
                TextButton.icon(
                  style: TextButton.styleFrom(padding: EdgeInsets.zero),
                  onPressed: () => openExternal(
                    context,
                    'https://www.openstreetmap.org/search?query='
                    '${Uri.encodeComponent('farmacia Cancún')}'
                    '#map=15/${origin.point.latitude}/${origin.point.longitude}',
                  ),
                  icon: const Icon(Icons.map_outlined),
                  label: const Text('Abrir en mapa externo'),
                ),
              ],
            ),
          ),
        ),
      for (final p in result.items.take(40)) _PharmacyTile(pharmacy: p),
      const SizedBox(height: 12),
      Text(
        'Fuente: ${result.origin.attribution}'
        '${result.consultedOn == null ? '' : ' · consulta: ${formatDateEs(result.consultedOn!)}'}',
        style: const TextStyle(fontSize: 12, color: mutedText),
      ),
    ],
  );
}

class _PharmacyTile extends StatelessWidget {
  const _PharmacyTile({required this.pharmacy});
  final Pharmacy pharmacy;
  @override
  Widget build(BuildContext context) {
    final p = pharmacy;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.local_pharmacy_outlined),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      p.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  if (p.distanceMeters != null)
                    Text(formatDistance(p.distanceMeters!)),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                p.address.isEmpty
                    ? 'Dirección no registrada en la fuente; usa «Cómo llegar».'
                    : p.address,
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(
                    p.clinic == ClinicStatus.registrado
                        ? Icons.medical_services_outlined
                        : Icons.help_outline,
                    size: 16,
                    color: mutedText,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      p.clinic.label,
                      style: const TextStyle(fontSize: 12, color: mutedText),
                    ),
                  ),
                ],
              ),
              Wrap(
                spacing: 4,
                children: [
                  TextButton.icon(
                    onPressed: () => openExternal(
                      context,
                      'https://www.openstreetmap.org/directions?to='
                      '${p.location.latitude},${p.location.longitude}',
                    ),
                    icon: const Icon(Icons.directions_outlined),
                    label: const Text('Cómo llegar'),
                  ),
                  if (p.phone.isNotEmpty)
                    TextButton.icon(
                      onPressed: () => openExternal(context, 'tel:${p.phone}'),
                      icon: const Icon(Icons.call_outlined),
                      label: const Text('Llamar'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
