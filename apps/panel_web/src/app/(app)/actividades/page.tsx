"use client";
import { useEffect, useState } from 'react';
import Link from 'next/link';
import { useSpecialist } from '@/lib/use-specialist';
import { specialtyUI } from '@/lib/specialty-ui';
import { sessions, patientNames, assignActivity, CareSession } from '@/lib/data';
import { PageHeader, ErrorText } from '@/components/care';
import { Card } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
export default function ActivitiesPage(){
 const {specialty}=useSpecialist();
 const ui=specialtyUI[specialty];
 const [list,setList]=useState<CareSession[]>([]);
 const [names,setNames]=useState<Record<string,string>>({});
 const [id,setId]=useState('');
 const [title,setTitle]=useState('');
 const [instructions,setInstructions]=useState('');
 const [error,setError]=useState<string|null>(null);
 const [busy,setBusy]=useState(false);
 const [saved,setSaved]=useState(false);
 useEffect(()=>{let alive=true; sessions().then(async rows=>{const own=rows.filter(s=>s.active&&s.specialty===specialty);const n=await patientNames(own.map(s=>s.patient_id));if(alive){setList(own);setNames(n);}}).catch(e=>{if(alive)setError(e.message)});return()=>{alive=false};},[specialty]);
 if(specialty==='physio')return <Link className="underline" href="/ejercicios">Abrir ejercicios de fisioterapia</Link>;
 return <><PageHeader title={ui.plan} subtitle={ui.subtitle}/><div className="grid gap-5 lg:grid-cols-2"><Card><h2 className="font-semibold">Actividades de esta especialidad</h2><p className="my-3 text-sm text-slate-500">Selecciona una actividad y escribe las indicaciones que has acordado con el paciente.</p><div className="grid gap-2">{ui.templates.map(t=><Button key={t} variant="outline" onClick={()=>{setTitle(t);setSaved(false);}}>{t}</Button>)}</div></Card><Card><form className="grid gap-4" onSubmit={async e=>{e.preventDefault();setBusy(true);setSaved(false);setError(null);try{if(!list.some(s=>s.id===id))throw new Error('Selecciona un paciente de esta especialidad.');await assignActivity(id,title,instructions);setSaved(true);setTitle('');setInstructions('');}catch(e){setError((e as Error).message);}finally{setBusy(false);}}}><h2 className="font-semibold">{ui.assign}</h2><fieldset disabled={busy} className="grid gap-4"><label className="grid gap-1 text-sm">Paciente<select required className="rounded border p-3" value={id} onChange={e=>setId(e.target.value)}><option value="">Selecciona una sesión</option>{list.map(s=><option key={s.id} value={s.id}>{names[s.patient_id]||'Paciente sin nombre'} · {s.title}</option>)}</select></label><label className="grid gap-1 text-sm">Actividad<input required maxLength={160} className="rounded border p-3" value={title} onChange={e=>setTitle(e.target.value)}/></label><label className="grid gap-1 text-sm">Indicaciones, frecuencia y duración<textarea required maxLength={4000} className="min-h-36 rounded border p-3" value={instructions} onChange={e=>setInstructions(e.target.value)}/></label></fieldset><ErrorText error={error}/>{saved&&<p role="status">Actividad asignada. El paciente puede verla en su sesión.</p>}<Button type="submit" disabled={busy||!id||!title.trim()||!instructions.trim()}>{busy?'Asignando…':ui.assign}</Button></form></Card></div></>;
}
