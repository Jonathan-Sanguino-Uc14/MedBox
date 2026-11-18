# Verificación de la primera versión móvil

Fecha: 17 noviembre 2026.

- `flutter analyze --no-pub`: sin incidencias.
- `flutter test --no-pub`: 3 pruebas aprobadas.
- Android: APK debug compilado e instalado en CPH2689, Android 16.
- Apertura en dispositivo confirmada; Supabase SDK inicializado.
- Pantallas de bienvenida e inicio de demostración revisadas visualmente en el dispositivo; capturas en `docs/screenshots`.
- Supabase Auth `/auth/v1/settings`: HTTP 200 con la clave publicable.
- API `care_sessions`: HTTP 404; migración pendiente de aplicar.
- No se crearon cuentas remotas ni se enviaron registros clínicos durante esta comprobación.
- No se ejecutaron pruebas de RLS remoto ni se validó iOS.

APK de desarrollo: `apps/paciente_flutter/build/app/outputs/flutter-apk/app-debug.apk`.
