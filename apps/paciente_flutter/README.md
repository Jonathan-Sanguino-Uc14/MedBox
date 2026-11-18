# Med Box · App del paciente

Primera implementación móvil en Flutter para Android. Incluye el logo proporcionado y la paleta `#123A52`, `#76B8B1`, `#5EA8D6`, `#F2F7F8`, blanco.

## Ejecutar

Desde `apps/paciente_flutter`:

```powershell
flutter pub get
flutter run
```

Selecciona Android si hay varios dispositivos. Para elegirlo explícitamente, consulta `flutter devices` y ejecuta `flutter run -d ID`.

## Qué funciona

- Bienvenida y navegación en español de México.
- Registro e inicio de sesión mediante Supabase Auth. El correo puede requerir confirmación según la configuración del proyecto.
- Modo demostración independiente de Supabase: cuatro sesiones ficticias, formularios por especialidad, historial y solicitud de vinculación con `MEDBOX-DEMO`.
- Modo conectado: lectura de sesiones, inserción de registros y RPC de solicitudes, una vez aplicada la migración SQL y provisionadas las sesiones.
- Formularios de fisioterapia (cumplimiento y dolor opcional), dermatología (zona y nota), oftalmología (lateralidad y nota), psicología (emoción y nota compartida).
- Vista previa local de imagen ficticia en la demostración. No se guarda la fotografía; solo el texto del registro permanece en memoria.
- Información preventiva general con fuente visible y cierre de sesión.

## Supabase

El proyecto y la clave **publicable** proporcionados están configurados en `lib/main.dart`. La clave publicable pertenece al cliente: no reemplaza RLS ni permite administrar la base de datos. No se incluyeron claves privilegiadas. Puede cambiarse la configuración con `--dart-define=SUPABASE_URL=... --dart-define=SUPABASE_PUBLISHABLE_KEY=...`.

La comprobación HTTP de Auth respondió 200. La consulta a `care_sessions` respondió 404: el esquema de Med Box no está disponible en la API consultada. Inicializar el SDK no crea tablas.

Migración pendiente de aplicar con acceso administrativo al proyecto:

`../../supabase/migrations/202611170001_mobile_foundation.sql`

Incluye RLS, sesiones individuales, registros y solicitudes por código con expiración, correo destinatario y límite de intentos. No permite al paciente crear sesiones o aprobarse. En esta etapa, los especialistas, invitaciones y aprobaciones se provisionan administrativamente; el panel profesional se implementará después. No se probó la migración contra PostgreSQL ni se afirma que ya esté desplegada.

Para probar después de aplicar SQL: crear dos cuentas de prueba confirmadas (paciente y especialista); crear una sesión con sus UUID desde el editor autorizado; verificar que el paciente ve solo su sesión y puede enviar un registro. Repetir con otro paciente y comprobar que no accede. Para invitaciones, generar un código aleatorio fuerte en servidor y almacenar su SHA-256 en `code_hash`, con email destinatario, especialista y especialidad. La solicitud no crea una sesión ni concede acceso; la aprobación administrativa debe crear la sesión individual y marcar la solicitud aprobada en una transacción.

## Alcance de esta entrega

Todavía no incluye almacenamiento privado de fotos, panel del especialista, aprobación desde interfaz, recuperación de contraseña, notificaciones, persistencia offline, mapas/Places, resúmenes IA ni datos epidemiológicos locales. El modo demo pierde registros al salir; la interfaz lo indica. Solo utilizar datos ficticios.

## Validar

```powershell
flutter analyze
flutter test
```

Pruebas: aislamiento entre especialidades de demostración, invitaciones pendientes sin conceder acceso y recorrido móvil completo de registro/historial. Las políticas remotas requieren validación de integración tras aplicar la migración.

Los repositorios descargados en `../../references` son referencias independientes; no se importó su código ni se ejecutaron sus instaladores. Ver `../../docs/REFERENCIAS_DESCARGADAS.md`.
