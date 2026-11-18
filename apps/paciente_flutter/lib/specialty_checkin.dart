import 'package:flutter/material.dart';

import 'data.dart';

/// Patient-reported data only. Optional values stay absent until answered.
class SpecialtyCheckIn extends StatelessWidget {
  const SpecialtyCheckIn({
    super.key,
    required this.specialty,
    required this.values,
    required this.onChanged,
  });
  final Specialty specialty;
  final Map<String, dynamic> values;
  final void Function(String, dynamic) onChanged;
  @override
  Widget build(BuildContext context) {
    final skin = specialty == Specialty.skin;
    if (!skin && specialty != Specialty.mind) return const SizedBox.shrink();
    final scales = skin
        ? ['Comezón', 'Dolor de piel', 'Ardor', 'Inflamación']
        : ['Ansiedad', 'Estrés', 'Calidad del sueño'];
    final texts = skin
        ? [
            'Fototipo de piel',
            'Tipo de piel',
            'Alergias conocidas',
            'Antecedentes cutáneos',
            'Medicamentos actuales',
            'Identificador de lesión',
            'Etapa del tratamiento',
            'Cambios en la apariencia',
            'Aplicaciones omitidas',
            'Reacciones adversas',
            'Dificultades con el tratamiento',
            'Medicamentos nuevos',
          ]
        : [
            'Emociones predominantes',
            'Situaciones de malestar',
            'Pensamientos y emociones',
            'Cambios importantes',
            'Medicamentos y cambios reportados',
          ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        Text(
          skin ? 'Mi piel, paso a paso' : 'Mi diario emocional',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Text(
          skin
              ? 'Usa el mismo identificador para seguir una lesión. Para las fotos, conserva iluminación, distancia y orientación similares.'
              : 'Registra cómo estuvo tu día. Solo tu profesional de esta sesión podrá leer lo que compartas.',
        ),
        for (final label in scales) ...[
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('Registrar ${label.toLowerCase()}'),
            value: values.containsKey(label),
            onChanged: (v) => onChanged(label, v == true ? 5 : null),
          ),
          if (values.containsKey(label)) ...[
            Text('$label: ${values[label]}/10'),
            Slider(
              value: (values[label] as num).toDouble(),
              max: 10,
              divisions: 10,
              label: '${values[label]}',
              onChanged: (v) => onChanged(label, v.round()),
            ),
            Text(
              label == 'Calidad del sueño'
                  ? '0: muy mala · 10: muy buena'
                  : '0: ninguna · 10: máxima',
            ),
          ],
        ],
        if (skin)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: '¿Aparecieron nuevas lesiones?',
              ),
              items: [
                'No',
                'Sí',
                'No estoy seguro',
              ].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
              onChanged: (v) => onChanged('Nuevas lesiones', v),
            ),
          ),
        for (final label in texts)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: TextFormField(
              initialValue: values[label] as String?,
              maxLength: 300,
              decoration: InputDecoration(labelText: label),
              onChanged: (v) => onChanged(label, v.trim().isEmpty ? null : v),
            ),
          ),
      ],
    );
  }
}
