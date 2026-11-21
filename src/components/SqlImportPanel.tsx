'use client';
import {useState} from 'react';
import {parseSqlImportFile,sqlImportTemplate,type SqlImportRow} from '@/lib/sql-import';
import {Download,Upload,DatabaseBackup,AlertTriangle,CheckCircle2} from 'lucide-react';
export async function sqlImportApi(body:object){const r=await fetch('/api/sql-import',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(body)});const d=await r.json();if(!r.ok)throw Error(d.error);return d;}

export default function SqlImportPanel(){
 const [sql,setSql]=useState(''),[rows,setRows]=useState<SqlImportRow[]|null>(null),[errors,setErrors]=useState<string[]>([]),[dupCount,setDupCount]=useState(0);
 const [statusOverride,setStatusOverride]=useState<''|'pending'|'approved'|'live_scheduled'>(''),[backupDone,setBackupDone]=useState(false),[busy,setBusy]=useState(false),[message,setMessage]=useState('');
 const [report,setReport]=useState<{imported:number,duplicates:number,errors:{row:unknown,error:string}[]}|null>(null);

 function download(name:string,text:string){const u=URL.createObjectURL(new Blob([text],{type:'text/plain;charset=utf-8'}));const a=document.createElement('a');a.href=u;a.download=name;a.click();URL.revokeObjectURL(u);}

 async function preview(){
  setMessage('');setReport(null);
  try{
   const parsed=parseSqlImportFile(sql);
   const errs:string[]=[];const valid:SqlImportRow[]=[];
   const {sqlImportAction}=await import('@/lib/live-exam-validation');
   parsed.forEach((raw,i)=>{const row={...raw,status:statusOverride||raw.status||'pending'};const p=sqlImportAction.safeParse({action:'commit',rows:[row]});if(!p.success)errs.push(`Row ${i+1}: `+p.error.issues.map(x=>x.message).join('; '));else if(p.data.action==='commit')valid.push(p.data.rows[0]);});
   const fpData=await sqlImportApi({action:'fingerprints'});
   const known=new Set<string>([...fpData.questions,...fpData.live]);
   async function fingerprint(text:string){const norm=text.normalize('NFKC').toLowerCase().replace(/[^\p{L}\p{N}]/gu,'');const buf=await crypto.subtle.digest('SHA-256',new TextEncoder().encode(norm));return [...new Uint8Array(buf)].map(b=>b.toString(16).padStart(2,'0')).join('');}
   const seen=new Set<string>();let dup=0;
   // Client-side pre-check against known DB fingerprints + duplicates within this file; the server
   // still performs the authoritative fingerprint dedup on commit, so this is only a time-saving preview.
   for(const r of valid){const fp=await fingerprint(r.q);if(seen.has(fp)||known.has(fp))dup++;seen.add(fp);}
   setRows(valid);setErrors(errs);setDupCount(dup);
   setMessage(`${valid.length}টি valid row, ${errs.length}টি error। Import চাপার আগে প্রথমে DB Backup সম্পন্ন করুন।`);
  }catch(e){setRows(null);setMessage((e as Error).message);}
 }

 async function commit(){
  if(!rows||!rows.length)return;
  if(!backupDone){setMessage('Import করার আগে DB Backup সম্পন্ন করার কথা নিশ্চিত করুন।');return;}
  if(!confirm(`${rows.length}টি প্রশ্ন import করতে চান? Import transaction-ভিত্তিক; প্রতিটি batch-এ সর্বোচ্চ ৫০০টি।`))return;
  setBusy(true);setMessage('');
  try{
   let imported=0,duplicates=0;const errs:{row:unknown,error:string}[]=[];
   for(let i=0;i<rows.length;i+=500){
    const batch=rows.slice(i,i+500);
    const r=await sqlImportApi({action:'commit',rows:batch});
    imported+=r.imported;duplicates+=r.duplicates;errs.push(...(r.errors||[]));
   }
   setReport({imported,duplicates,errors:errs});
   setMessage(`Import সম্পন্ন: ${imported}টি সফল, ${duplicates}টি duplicate skip, ${errs.length}টি error।`);
   setRows(null);setSql('');
  }catch(e){setMessage((e as Error).message);}finally{setBusy(false);}
 }

 return <div className="sql-import-panel" data-feature="sql-import">
  <header className="cw-heading"><div><span className="cw-eyebrow">SUPER ADMIN ONLY</span><h2><Upload size={22}/> SQL ফাইল দিয়ে Bulk Question Import</h2><p>হাজার হাজার প্রশ্ন একসাথে import করুন। Arbitrary SQL কখনো execute হয় না — শুধু নির্দিষ্ট JSON-row টেমপ্লেট client-এ parse হয়ে, validated RPC-এর মাধ্যমে লেখা হয়।</p></div></header>
  <div className="notice"><AlertTriangle size={16}/> এই ফিচার শুধু Super Admin ব্যবহার করতে পারবে। সাধারণ Admin চেষ্টা করলে সার্ভার reject করবে।</div>
  <div className="cw-toolbar"><button onClick={()=>download('jobmaster-sql-import-template.sql',sqlImportTemplate())}><Download size={16}/> SQL টেমপ্লেট ডাউনলোড</button></div>
  <label><input type="checkbox" checked={backupDone} onChange={e=>setBackupDone(e.target.checked)}/> <DatabaseBackup size={15}/> আমি Import-এর আগে ডাটাবেস Backup নিশ্চিত করেছি (বাধ্যতামূলক)</label>
  <label>Default status override (ফাইলে না থাকলে)<select value={statusOverride} onChange={e=>setStatusOverride(e.target.value as any)}><option value="">ফাইলে যা আছে তাই</option><option value="pending">Pending</option><option value="approved">Approved</option><option value="live_scheduled">Live Scheduled</option></select></label>
  <input aria-label="SQL import file" type="file" accept=".sql,text/plain" onChange={async e=>{const f=e.target.files?.[0];if(f){if(f.size>5_000_000){setMessage('ফাইল সর্বোচ্চ 5 MB');return;}setSql(await f.text());setRows(null);setReport(null);}}}/>
  <textarea aria-label="SQL import content" rows={8} value={sql} onChange={e=>{setSql(e.target.value);setRows(null);setReport(null);}} placeholder="অথবা এখানে SQL টেমপ্লেট paste করুন"/>
  <div className="cw-toolbar"><button disabled={!sql||busy} onClick={preview}>Preview ও Validate</button><button className="primary" disabled={!rows?.length||!!errors.length||busy} onClick={commit}><Upload size={16}/> Import ({rows?.length||0} rows)</button></div>
  {message?<div className="notice" role="status">{message}</div>:null}
  {errors.length?<div className="notice" role="alert">{errors.slice(0,20).map((s,i)=><p key={i}>{s}</p>)}</div>:null}
  {rows&&!errors.length?<p>{rows.length}টি valid row, আনুমানিক {dupCount}টি সম্ভাব্য duplicate (চূড়ান্ত duplicate check সার্ভারে fingerprint দিয়ে হবে)।</p>:null}
  {report?<div className="notice"><CheckCircle2 size={16}/> সফল: {report.imported} · Duplicate skip: {report.duplicates} · Error: {report.errors.length}{report.errors.slice(0,20).map((e,i)=><p key={i}>{e.error}</p>)}</div>:null}
  <p className="muted-text">Status অনুযায়ী workflow: Pending → সাধারণ Approval queue-তে যাবে। Approved → সরাসরি practice pool-এ publish হবে। Live Scheduled → আলাদা Live Exam Question Bank-এ যাবে এবং নির্ধারিত exam_date-এ approval ছাড়াই ব্যবহৃত হবে।</p>
 </div>;
}
