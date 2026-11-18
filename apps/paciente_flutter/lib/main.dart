import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config.dart';
import 'theme.dart';
import 'screens.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SupabaseClient? client;
  try {
    await Supabase.initialize(
      url: supabaseUrl,
      publishableKey: supabasePublishableKey,
    );
    client = Supabase.instance.client;
  } catch (_) {
    /* Welcome screen remains available when initialization fails. */
  }
  runApp(MedBoxApp(client: client));
}

class MedBoxApp extends StatelessWidget {
  const MedBoxApp({super.key, this.client});
  final SupabaseClient? client;
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Med Box',
    debugShowCheckedModeBanner: false,
    theme: medTheme(),
    locale: const Locale('es', 'MX'),
    supportedLocales: const [Locale('es', 'MX')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    home: WelcomeScreen(client: client),
  );
}
