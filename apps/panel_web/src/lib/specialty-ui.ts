import type { Specialty } from './data';
export const specialtyUI: Record<Specialty, {plan:string;assign:string;records:string;session:string;subtitle:string;templates:string[]}> = {
 physio: {plan:'Ejercicios físicos',assign:'Asignar ejercicio físico',records:'Ejercicios y grabaciones',session:'Rehabilitación física',subtitle:'Plan de rehabilitación, repeticiones y revisión del movimiento.',templates:[]},
 mind: {plan:'Tareas terapéuticas',assign:'Asignar tarea terapéutica',records:'Diario emocional y tareas',session:'Acompañamiento psicológico',subtitle:'Diario emocional, objetivos y actividades entre sesiones.',templates:['Diario emocional','Registro de pensamientos','Respiración guiada','Atención plena','Registro de hábitos y sueño','Reflexión sobre autoestima','Exposición gradual acordada','Tarea personalizada']},
 skin: {plan:'Cuidados de la piel',assign:'Indicar cuidado dermatológico',records:'Evolución de la piel y fotografías',session:'Seguimiento dermatológico',subtitle:'Lesiones, fotografías, rutina indicada y tolerancia al tratamiento.',templates:['Rutina de cuidado de la piel','Aplicación de producto indicado','Registro de síntomas cutáneos','Fotografía de seguimiento','Cuidados posteriores a un procedimiento','Indicación personalizada']},
 eyes: {plan:'Indicaciones oculares',assign:'Indicar cuidado ocular',records:'Síntomas y seguimiento ocular',session:'Seguimiento oftalmológico',subtitle:'Síntomas por ojo, indicaciones del oftalmólogo y evolución entre consultas.',templates:['Seguimiento de molestias oculares','Aplicación de tratamiento indicado','Registro por ojo','Preparación para revisión ocular','Cuidado ocular personalizado']},
};
export function specialtyNavigation(s: Specialty) {
  const planHref = s === 'physio' ? '/ejercicios' : '/actividades';
  const base = [
    { href: '/panel',      label: 'Inicio' },
    { href: '/agenda',     label: 'Agenda' },
    { href: '/pacientes',  label: 'Pacientes' },
    { href: planHref,      label: specialtyUI[s].plan },
    { href: '/invitar',    label: 'Invitar paciente' },
  ];
  const extra: Array<{href: string; label: string}> = [];
  if (s === 'skin') extra.push({ href: '/recursos', label: 'Atlas dermatológico' });
  if (s === 'eyes') extra.push({ href: '/recursos', label: 'Recursos oculares' });
  return [...base, ...extra, { href: '/consultorio', label: 'Consultorio' }];
}
