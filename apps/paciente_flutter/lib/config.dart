/// Public Supabase settings (publishable key only; privileged keys never ship in the app).
const supabaseUrl = String.fromEnvironment(
  'SUPABASE_URL',
  defaultValue: 'https://vdfqadtohwlolwuwgeki.supabase.co',
);
const supabasePublishableKey = String.fromEnvironment(
  'SUPABASE_PUBLISHABLE_KEY',
  defaultValue: 'sb_publishable_qAuNWUI3XXNN4nJp6GBIww_fF4G7vHg',
);

/// Token de la API del DENUE (INEGI). Vacío = se usa la copia local.
/// Se inyecta al compilar: `--dart-define=INEGI_DENUE_TOKEN=...`.
/// Recomendado a futuro: proxy en una Edge Function para no distribuirlo.
const inegiDenueToken = String.fromEnvironment('INEGI_DENUE_TOKEN');
