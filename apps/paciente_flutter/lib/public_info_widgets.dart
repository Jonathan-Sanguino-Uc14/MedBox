/// Piezas de interfaz compartidas por las pantallas de información pública
/// (observatorio y farmacias).
library;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

const mutedText = Color(0xFF526C79);

/// Abre un enlace externo; si falla, avisa sin bloquear la pantalla.
Future<void> openExternal(BuildContext context, String url) async {
  final ok = await launchUrl(
    Uri.parse(url),
    mode: LaunchMode.externalApplication,
  ).catchError((_) => false);
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No pudimos abrir el enlace.')),
    );
  }
}

/// «17 de noviembre de 2026» a partir de una fecha ISO; si no se puede
/// leer, devuelve el texto original.
String formatDateEs(String iso) {
  final d = DateTime.tryParse(iso);
  if (d == null) return iso;
  const months = [
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
  final time = iso.contains('T')
      ? ', ${'${d.hour}'.padLeft(2, '0')}:${'${d.minute}'.padLeft(2, '0')} h'
      : '';
  return '${d.day} de ${months[d.month - 1]} de ${d.year}$time';
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.text, this.subtitle, {super.key});
  final String text, subtitle;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 28, bottom: 12),
    child: Semantics(
      header: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(text, style: Theme.of(context).textTheme.titleLarge),
          Text(subtitle, style: const TextStyle(color: mutedText)),
        ],
      ),
    ),
  );
}

class LoadingRow extends StatelessWidget {
  const LoadingRow(this.label, {super.key});
  final String label;
  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          const SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(label)),
        ],
      ),
    ),
  );
}

/// Aviso recuperable con botón de reintento.
class NoticeCard extends StatelessWidget {
  const NoticeCard(this.message, {super.key, this.onRetry, this.icon});
  final String message;
  final VoidCallback? onRetry;
  final IconData? icon;
  @override
  Widget build(BuildContext context) => Card(
    color: const Color(0xFFFFF4E0),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      child: Row(
        children: [
          Icon(icon ?? Icons.cloud_off_outlined),
          const SizedBox(width: 12),
          Expanded(child: Text(message)),
          if (onRetry != null)
            TextButton(onPressed: onRetry, child: const Text('Reintentar')),
        ],
      ),
    ),
  );
}
