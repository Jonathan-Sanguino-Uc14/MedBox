# Med Box

- **App del paciente (Flutter, Android):** [apps/paciente_flutter](apps/paciente_flutter/README.md). Solo pacientes: sesiones privadas, ejercicios asignados, grabación con análisis de movimiento, historial y revisiones.
- **Panel web del profesional (Next.js):** [apps/panel_web](apps/panel_web). Registro del fisioterapeuta, invitaciones, aprobación de vínculos, asignación de ejercicios y revisión de grabaciones. Base de UI adaptada de fisio-app (MIT).
- Plan maestro: [docs/MED_BOX_PLAN_MAESTRO.md](docs/MED_BOX_PLAN_MAESTRO.md).
- Base de datos (Supabase, ya aplicada el 17/11/2026): [0001](supabase/migrations/202611170001_mobile_foundation.sql), [0002](supabase/migrations/202611170002_care_platform.sql), [0003](supabase/migrations/202611170003_physio_exercises.sql), [0004](supabase/migrations/202611170004_custom_exercises.sql) (ejercicios propios del fisio con video de demostración).
- Pruebas SQL (rollback, no dejan datos): [rls_smoke.sql](supabase/tests/rls_smoke.sql) → `RLS OK`; [physio_smoke.sql](supabase/tests/physio_smoke.sql) → `FISIO OK`.
- Código reutilizado y licencias: [docs/REFERENCIAS_DESCARGADAS.md](docs/REFERENCIAS_DESCARGADAS.md).

## Panel web

```bash
npm --prefix apps/panel_web install
```

```bash
npm --prefix apps/panel_web run dev
```

Abre http://localhost:3000. `npm --prefix apps/panel_web run build` genera un sitio estático en `apps/panel_web/out` (se puede publicar en cualquier hosting estático). Toda la autorización la aplica Supabase (RLS y funciones), no el frontend.

El servidor de desarrollo usa `.next-dev` y la compilación de producción usa `.next`, para que ejecutar `build` no reemplace los módulos de una sesión de desarrollo abierta. Después de cambiar esta configuración, reinicia `npm --prefix apps/panel_web run dev` y recarga el navegador con Ctrl+Shift+R.

## Flujo fisioterapeuta → paciente

1. **Web:** el fisioterapeuta se registra en `/registro` (cédula, formación, clínica). Queda como **no verificada** hasta que el operador ejecute `update public.specialists set verified = true where user_id = '<id>';`. El autorregistro se puede cerrar en `public.app_settings`.
2. **Web → Invitar paciente:** código de un solo uso (48 h, ligado al correo) y envío por WhatsApp o correo.
3. **App:** el paciente crea su cuenta con ese correo → «Vincular con un código».
4. **Web → Inicio:** el fisio aprueba y se crea la sesión privada.
5. **Web → Ejercicios:** crea ejercicios propios (instrucciones, video de demostración y, si aplica, patrón de conteo automático).
6. **Web → Pacientes → ficha:** asigna ejercicios base o propios (repeticiones, series, fecha, indicaciones). Aparecen en la sesión del paciente en la app.
7. **App:** «Ver demostración y grabar» (animación del movimiento y/o video del fisio) → cuenta repeticiones y evalúa el patrón en el teléfono → envía video y métricas.
8. **Web:** el fisio ve métricas y video, y deja su revisión; el paciente la lee en la app.

Android es la plataforma principal del paciente; iOS sin validar.

## Dermatología y psicología

Pantallas de seguimiento del paciente y expediente del profesional: [alcance y validación](docs/PANTALLAS_DERMA_PSICO.md). Vista de demostración del doctor: `/vista-clinica`. Para guardar expedientes reales, aplicar primero la migración `202611180005_clinical_notes.sql` (preparada, pendiente de aplicar).
