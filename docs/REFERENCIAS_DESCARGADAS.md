# Repositorios de referencia descargados

Descarga superficial con Git el 17 de noviembre de 2026. No se incorporó código ajeno a Med Box ni se ejecutaron instaladores de estos proyectos. Las copias conservan sus licencias y están excluidas del repositorio principal mediante `.gitignore`.

| Repositorio | Carpeta | Revisión descargada |
|---|---|---|
| https://github.com/ADG1411/MedAssist-AI | references/MedAssist-AI | cb5094c |
| https://github.com/onkar0127/PhysioBuddy | references/PhysioBuddy | 637512b |
| https://github.com/Mrcipo/fisio-app | references/fisio-app | e03da0c |
| https://github.com/Andrewkimutai/skin-care-connect | references/skin-care-connect | a15aa64 |
| https://github.com/sudoshi/COPE | references/COPE | bf14884 |
| https://github.com/Concordia-Biomedical-Engineering-Club/smart-sleeve-app | references/smart-sleeve-app | 92a656f |

Estas copias permiten ampliar la auditoría documental anterior. Su descarga no significa que estén instaladas sus dependencias, que se hayan ejecutado pruebas o que sean aptas para producción. El desarrollo móvil de Med Box usa implementación propia y `supabase_flutter`.

## Código adaptado en Med Box

| Origen (licencia) | Qué se adaptó | Dónde |
|---|---|---|
| PhysioBuddy `backend/physioapp/consumers.py` (MIT, © 2026 Onkar Gite) | Umbrales, verificación de orientación y máquinas de estado de 5 ejercicios (curl de bíceps, cuádriceps, hombros, sentadilla, elevación de rodilla), portados a Dart. Se añadieron lado más visible, repeticiones incompletas, rango de movimiento, tempo y mensajes en español | `apps/paciente_flutter/lib/exercise_analysis.dart` |
| PhysioBuddy `models.py`, `seed_data.py`, `NewAssignmentForm.jsx` (MIT) | Catálogo de ejercicios, asignación con repeticiones objetivo, campos del perfil profesional | `supabase/migrations/202611170003_physio_exercises.sql`, `lib/specialist_forms.dart` |
| fisio-app `auth.schemas.ts`, `schema.prisma` (MIT, © 2026 Matias Riffo) | Registro del clínico; región corporal, series/repeticiones por defecto, precauciones y dolor posterior | Migración 0003, `apps/panel_web/src/app/(auth)/registro` |
| fisio-app `apps/frontend` (MIT, © 2026 Matias Riffo) | Configuración Next.js/Tailwind, componentes UI (`button`, `card`, `input`, `label`, `select`, `textarea`), `app-shell`, `sidebar`, `navbar`, estilos globales; colores y navegación adaptados a Med Box y datos vía Supabase | `apps/panel_web` |

MedAssist-AI (propietario), COPE (GPL-3.0) y smart-sleeve-app (AGPL-3.0) solo se usaron como referencia conceptual; no se copió código.
