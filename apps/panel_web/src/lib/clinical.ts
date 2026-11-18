import { supabase } from './supabase';
export type ClinicalNote = { id: string; section: string; fields: Record<string,string>; created_at: string };
export async function clinicalNotes(sessionId: string): Promise<ClinicalNote[]> {
 const {data,error} = await supabase.from('clinical_notes').select('id,section,fields,created_at').eq('session_id',sessionId).order('created_at',{ascending:false});
 if(error) throw new Error('No se pudo cargar el expediente. Comprueba la conexión y las migraciones clínicas 0005 y 0007.');
 return data ?? [];
}
export async function saveClinicalNote(sessionId:string,section:string,fields:Record<string,string>) {
 const {data:{user}} = await supabase.auth.getUser();
 if(!user) throw new Error('Inicia sesión de nuevo.');
 const {error} = await supabase.from('clinical_notes').insert({session_id:sessionId,author_id:user.id,section,fields});
 if(error) throw new Error(error.message);
}
export const clinicalSections: Record<string, Record<string, { title:string; fields:string[] }>> = {
 skin: {
 profile:{title:'Expediente dermatológico',fields:['Fototipo Fitzpatrick|I|II|III|IV|V|VI','Tipo de piel|Seca|Grasa|Mixta|Sensible','Alergias a medicamentos y productos','Antecedentes cutáneos','Antecedentes familiares','Exposición solar','Protector solar','Cosméticos utilizados','Tratamientos anteriores','Medicamentos actuales','Actividad laboral y sustancias químicas','Enfermedades autoinmunes','Cambios de alimentación relevantes']},
 lesion:{title:'Lesión y localización',fields:['Identificador de lesión','Región anatómica|Cabeza y rostro|Cuello|Tórax|Espalda|Abdomen|Brazos|Manos|Piernas|Pies','Motivo y fecha de inicio','Zona donde comenzó','Evolución','Tipo de lesión|Mácula|Pápula|Placa|Vesícula|Ampolla|Nódulo|Otra','Color','Tamaño (mm o cm)','Forma','Superficie','Distribución','Consistencia','Síntomas y tratamiento previo']},
 consultation:{title:'Consulta y evolución',fields:['Fecha de consulta','Identificador de lesión','Hallazgos de exploración','Diagnóstico clínico','Estado diagnóstico|Sospecha clínica|Confirmado|Resultados pendientes','Diagnósticos diferenciales','Código diagnóstico','Estudios, biopsias y dermatoscopias','Resultados de estudios','Cambios desde la última consulta','Respuesta al tratamiento','Efectos adversos','Tratamiento|Continúa|Se modifica|Se suspende','Productos, dosis, frecuencia y duración','Nuevas indicaciones','Próxima cita','Observaciones del especialista']}
 },
 physio: {
 profile:{title:'Expediente de fisioterapia',fields:['Motivo de consulta y diagnóstico médico','Zona afectada','Lado|Derecho|Izquierdo|Ambos|No aplica','Fecha de lesión o cirugía','Mecanismo de lesión','Cirugías previas','Antecedentes médicos','Medicamentos actuales','Ocupación y actividad física','Dolor inicial (0–10)','Rango de movimiento inicial','Fuerza muscular inicial','Pruebas funcionales','Objetivos del paciente','Precauciones y contraindicaciones']},
 consultation:{title:'Nota de sesión',fields:['Fecha de sesión','Dolor actual (0–10)','Evolución desde la sesión anterior','Rango de movimiento','Fuerza muscular','Técnicas y ejercicios aplicados','Respuesta del paciente','Ajustes al plan','Próxima cita']}
 },
 eyes: {
 profile:{title:'Expediente oftalmológico',fields:['Motivo de consulta','Ojo afectado|Derecho|Izquierdo|Ambos','Agudeza visual ojo derecho','Agudeza visual ojo izquierdo','Presión intraocular ojo derecho','Presión intraocular ojo izquierdo','Uso de lentes|No|Anteojos|Lentes de contacto|Ambos','Graduación actual','Antecedentes oculares','Cirugías oculares','Enfermedades sistémicas (diabetes, hipertensión)','Antecedentes familiares oculares','Alergias','Medicamentos actuales']},
 consultation:{title:'Consulta oftalmológica',fields:['Fecha de consulta','Síntomas reportados','Agudeza visual ojo derecho','Agudeza visual ojo izquierdo','Presión intraocular ojo derecho','Presión intraocular ojo izquierdo','Hallazgos de exploración','Diagnóstico clínico','Estado diagnóstico|Sospecha clínica|Confirmado|Resultados pendientes','Tratamiento indicado','Próxima cita']}
 },
 mind: {
 profile:{title:'Expediente psicológico',fields:['Nombre completo','Fecha de nacimiento','Sexo (si es relevante)','Ocupación','Escolaridad','Estado civil (si es relevante)','Teléfono y correo','Localidad','Contacto de emergencia y relación','Antecedentes médicos y psicológicos','Medicamentos actuales','Antecedentes familiares','Tratamientos anteriores','Consumo de sustancias','Red de apoyo','Referencia de consentimiento informado','Autorización de almacenamiento clínico','Autorización de videollamada','Autorización de notificaciones','Consentimiento del tutor y asentimiento (si aplica)']},
 assessment:{title:'Evaluación inicial',fields:['Motivo de consulta','Historia del problema','Síntomas reportados','Antecedentes e historia familiar','Área social','Área emocional','Examen mental','Evaluación profesional de riesgo','Objetivos del paciente','Formulación clínica','Hipótesis clínica','Diagnóstico profesional','Estado diagnóstico|Sin confirmar|Hipótesis clínica|Confirmado','Enfoque terapéutico','Frecuencia de sesiones','Estrategias de intervención','Instrumento aplicado y versión','Resultado y fecha de cuestionario']},
 consultation:{title:'Nota de sesión',fields:['Fecha de sesión','Temas abordados','Estado emocional observado','Cambios respecto a la sesión anterior','Avances y dificultades','Intervenciones realizadas','Respuesta del paciente','Evaluación de riesgo','Nuevos acuerdos y tareas','Cambios de medicamentos reportados','Plan para la siguiente sesión','Próxima cita']}
 }
};

export async function uploadClinicalPhoto(sessionId:string,patientId:string,file:File,fields:Record<string,string>){
 if(!['image/jpeg','image/png'].includes(file.type)||file.size>10*1024*1024) throw new Error('Usa JPEG o PNG de hasta 10 MB.');
 const path=`${sessionId}/${patientId}/${crypto.randomUUID()}.${file.type==='image/png'?'png':'jpg'}`;
 const {error}=await supabase.storage.from('care-evidence').upload(path,file,{contentType:file.type});
 if(error) throw new Error('No se pudo subir la fotografía. El paciente debe autorizar imágenes desde su app y la sesión debe estar activa.');
 await saveClinicalNote(sessionId,'photo',{...fields,'Archivo':path});
}
