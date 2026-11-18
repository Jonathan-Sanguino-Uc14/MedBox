# Pantallas de dermatología y psicología

Implementación basada en `derma.odt` y `psicologia.odt` aportados por el usuario. Los documentos se interpretaron como referencias de requisitos y ejemplos, no como instrucciones operativas. Las seis imágenes extraídas están en `document-reference/` y no se publican como fotografías clínicas.

## Cómo revisar

- Panel real: Pacientes → ficha de una sesión de Dermatología o Psicología.
- Demostración sin autenticación: `/vista-clinica` en Next.js o `/vista-clinica.html` en el export estático. Datos ficticios; notas solo en memoria.
- App Flutter: sesión de Dermatología/Psicología → Registrar seguimiento. Las tareas tienen su propio botón de registro.
- Biblioteca del profesional: `/recursos`.

## Implementado

| Documento | Paciente | Profesional |
|---|---|---|
| Dermatología | Identificador de lesión, zona, foto original JPEG/PNG hasta 10 MB, consentimiento, comezón/dolor/ardor/inflamación opcionales, cambios, omisiones, reacciones, medicamentos, comparación primera/última foto por lesión | Expediente cutáneo, antecedentes, fototipo, morfología y localización, notas de consulta, estado diagnóstico, indicaciones, estudios/resultados, historial, selección de dos fotos, carga de foto de consulta con fecha de toma y consentimiento previo del paciente |
| Psicología | Estado emocional, ansiedad/estrés/sueño opcionales, emociones, situaciones, pensamientos, cambios y tareas vinculadas | Expediente, referencias de consentimiento, evaluación inicial, objetivos, formulación, hipótesis/diagnóstico, valoración de riesgo escrita por el profesional, plan, notas de sesión e historial |

Los campos no respondidos permanecen ausentes: no se convierten en síntomas de intensidad cero. Las escalas son autorreportes de seguimiento, sin interpretación diagnóstica automática. Las actividades las asigna el profesional mediante el flujo existente. Las notas clínicas son privadas del profesional; las indicaciones se comparten mediante actividades o revisiones.

## Base de datos y despliegue

**Migración nueva preparada, no aplicada:** `supabase/migrations/202611180005_clinical_notes.sql`.

Debe ejecutarse después de 0001–0004 antes de utilizar el expediente real. Crea `clinical_notes` con RLS de sesión activa y autor especialista, inserciones históricas sin actualización/borrado por clientes; permite carga profesional de imágenes únicamente en sesiones dermatológicas con consentimiento de imágenes del paciente. No concede lectura de notas clínicas al paciente ni a especialistas ajenos. No se realizaron pruebas SQL contra la base remota ni un despliegue de producción.

Los registros móviles adicionales usan `care_records.details`, ya existente. El profesional lee esos datos en la ficha. Si falta la migración, el panel muestra un error y bloquea el formulario clínico; no simula guardados exitosos.

## Referencias y alcance

- `references/fisio-app`: se conserva la base de componentes MIT ya adaptada por el proyecto.
- `references/skin-care-connect`: consulta conceptual del flujo paciente/dermatólogo e historial. Sin copiar su código ni integrar su clasificador.
- `references/COPE`: referencia conceptual de diario, sueño y revisión clínica. Sin copiar código GPL.
- DermNet: https://dermnetnz.org/images. Se enlaza desde la biblioteca. Condiciones revisadas en https://dermnetnz.org/image-licence: imágenes con marca bajo CC BY-NC-ND 4.0; uso comercial requiere licencia; no se importaron imágenes ni datos de entrenamiento.
- Kaggle: https://www.kaggle.com/datasets/manan1717/ocular-disease-dataset. Página sin contenido legible en la consulta; licencia y contenido no verificados. Se ofrece enlace externo, sin importar datos ni incorporar un modelo ocular.

## Límites explícitos

La captura estructurada de referencias de consentimiento no sustituye el flujo de firma de consentimiento informado. No se incorporaron formularios licenciados BAI/BDI, puntuación automática de cuestionarios, alertas automáticas de crisis, videollamadas, recordatorios programados ni agenda sincronizada. Los resultados de cuestionarios pueden documentarse manualmente por el profesional. Los campos de tratamiento y próxima cita son registros clínicos, no envíos automáticos. Las fotos profesionales se guardan en el expediente privado; las comparaciones móviles usan fotos compartidas por el propio paciente. En móvil la fecha del registro es la del envío, no la fecha EXIF de la captura.

## Validación

- Compilación Next.js y export estático: correctos.
- Análisis estático Dart: sin problemas.
- Seis pruebas de datos y formularios: correctas (valores omitidos frente a cero, persistencia de observaciones e independencia entre sesiones).
- Navegador: formulario dermatológico, guardado de nota ficticia, consulta de historial y diseño de resumen psicológico comprobados.
- Falta validación con cuentas reales y migración aplicada, pruebas RLS en base de datos y recorrido Android en dispositivo.

## Separación por profesión

El menú, pacientes, solicitudes, invitaciones, biblioteca, asignaciones y textos se filtran por la especialidad activa de la cuenta. Si el profesional tiene varias especialidades autorizadas, puede cambiar entre ellas en la barra superior. Cambiar de especialidad descarta la vista anterior y abre su inicio.

- Psicología: tareas terapéuticas (diario, pensamientos, respiración, hábitos, reflexión), evaluación y notas psicológicas.
- Dermatología: cuidados indicados, síntomas cutáneos, fotografías y atlas dermatológico.
- Oftalmología: indicaciones oculares, reporte por ojo y recursos oculares.
- Fisioterapia: catálogo de ejercicios físicos, series, repeticiones y grabaciones.

La ruta de ejercicios físicos bloquea otras especialidades. El paciente solo puede abrir captura de movimiento desde fisioterapia. La migración adicional `202611180006_specialty_activities.sql` impide en base de datos asignar ejercicios físicos, series o repeticiones a otra especialidad. Está preparada, **pendiente de aplicar**, al igual que 0005. No se modificaron datos reales existentes.
