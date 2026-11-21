'use client';
import {useCallback,useEffect,useState} from 'react';
import {courseApi} from '@/lib/courses-client';
import {CheckCircle2,ShieldCheck,ChevronRight} from 'lucide-react';
export async function approvalsApi(body:object){const r=await fetch('/api/approvals',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(body)});const d=await r.json();if(!r.ok)throw Error(d.error);return d;}
type Subject={subject_id:string,subject_title:string,pending:number};
type Topic={subject_id:string,subject_title:string,topic_id:string,topic_title:string,pending:number};
type Summary={course_pending:number,course_unclassified_pending:number,subjects:Subject[],topics:Topic[]};
type Item={id:string,course_id:string,subtopic_id:string|null,verified:boolean,data:{q:string}};

export default function SmartApprovals({course,courseTitle}:{course:string,courseTitle:string}){
 const [summary,setSummary]=useState<Summary|null>(null),[subject,setSubject]=useState(''),[topic,setTopic]=useState('');
 const [items,setItems]=useState<Item[]>([]),[checked,setChecked]=useState<Set<string>>(new Set()),[busy,setBusy]=useState(false),[message,setMessage]=useState('');

 const load=useCallback(async()=>{try{setSummary(await approvalsApi({action:'pending_summary',course_id:course}));}catch(e){setMessage((e as Error).message);}},[course]);
 useEffect(()=>{setSubject('');setTopic('');setChecked(new Set());load();},[course,load]);

 useEffect(()=>{if(!subject&&!topic){setItems([]);return;}
  courseApi({action:'questions',course_id:course,status:'draft',...(topic?{topic_id:topic}:{}),...(!topic&&subject?{subject_id:subject}:{}),page:1}).then(d=>{setItems(d.questions);setChecked(new Set());}).catch(e=>setMessage((e as Error).message));
 },[course,subject,topic]);

 const topicsOfSubject=summary?.topics.filter(t=>t.subject_id===subject)||[];
 const toggle=(id:string)=>setChecked(s=>{const n=new Set(s);n.has(id)?n.delete(id):n.add(id);return n;});
 const allChecked=items.length>0&&items.every(i=>checked.has(i.id));

 async function approveMany(){if(!checked.size)return;setBusy(true);setMessage('');try{const r=await approvalsApi({action:'approve_many',course_id:course,ids:[...checked]});setMessage(`${r.approved}টি প্রশ্ন approve হয়েছে।`);setChecked(new Set());await load();if(subject||topic)courseApi({action:'questions',course_id:course,status:'draft',...(topic?{topic_id:topic}:{}),...(!topic&&subject?{subject_id:subject}:{}),page:1}).then(d=>setItems(d.questions));}catch(e){setMessage((e as Error).message);}finally{setBusy(false);}}

 async function approveAll(scope:'subject'|'topic'){
  const pending=scope==='topic'?topicsOfSubject.find(t=>t.topic_id===topic)?.pending:summary?.subjects.find(s=>s.subject_id===subject)?.pending;
  const label=scope==='topic'?topicsOfSubject.find(t=>t.topic_id===topic)?.topic_title:summary?.subjects.find(s=>s.subject_id===subject)?.subject_title;
  if(!pending){setMessage('এই স্কোপে কোনো pending প্রশ্ন নেই।');return;}
  if(!confirm(`"${label}" ${scope==='topic'?'topic':'subject'}-এর সবগুলো pending প্রশ্ন (${pending}টি) Approve করতে চান? এই কাজ বাতিল করা যাবে না।`))return;
  setBusy(true);setMessage('');
  try{const r=await approvalsApi({action:'approve_all',course_id:course,...(scope==='topic'?{topic_id:topic}:{subject_id:subject})});setMessage(`${r.approved}টি প্রশ্ন approve হয়েছে।`);setChecked(new Set());await load();}
  catch(e){setMessage((e as Error).message);}finally{setBusy(false);}
 }

 return <div className="smart-approvals" data-feature="smart-approval">
  <header className="cw-heading"><div><span className="cw-eyebrow">SMART BULK APPROVAL</span><h2><ShieldCheck size={22}/> {courseTitle} — দ্রুত Bulk Approve</h2><p>Subject → Topic বাছুন, pending প্রশ্ন দেখুন, এক ক্লিকে Approve All অথবা নির্বাচিত প্রশ্নগুলো Approve করুন।</p></div></header>
  {message?<div className="notice" role="status">{message}</div>:null}
  {summary?<div className="cw-stat-grid"><div><span>এই course-এ মোট pending</span><strong>{summary.course_pending}</strong></div><div><span>Unclassified pending</span><strong>{summary.course_unclassified_pending}</strong></div></div>:null}

  <div className="cw-scope" role="group" aria-label="Subject pending list"><button className={!subject?'selected':''} onClick={()=>{setSubject('');setTopic('');}}>সব Subject</button>
   {summary?.subjects.map(s=><button key={s.subject_id} className={subject===s.subject_id?'selected':''} onClick={()=>{setSubject(s.subject_id);setTopic('');}}>{s.subject_title}<small> {s.pending} pending</small></button>)}
  </div>

  {subject?<><div className="cw-toolbar"><button className="primary" disabled={busy} onClick={()=>approveAll('subject')}><CheckCircle2 size={16}/> এই Subject-এর সব Approve করুন ({summary?.subjects.find(s=>s.subject_id===subject)?.pending||0})</button></div>
  <div className="cw-leaf-bar" aria-label="Topic pending list"><button className={!topic?'selected':''} onClick={()=>setTopic('')}>সব Topic</button>{topicsOfSubject.map(t=><button key={t.topic_id} className={topic===t.topic_id?'selected':''} onClick={()=>setTopic(t.topic_id)}><ChevronRight size={14}/>{t.topic_title}<small>{t.pending}</small></button>)}</div></>:null}

  {topic?<div className="cw-toolbar"><button className="primary" disabled={busy} onClick={()=>approveAll('topic')}><CheckCircle2 size={16}/> এই Topic-এর সব Approve করুন ({topicsOfSubject.find(t=>t.topic_id===topic)?.pending||0})</button></div>:null}

  {(subject||topic)?<><div className="cw-list-status">{items.length} pending প্রশ্ন {topic?'এই topic-এ':'এই subject-এ'}</div>
   <label><input type="checkbox" checked={allChecked} onChange={e=>setChecked(e.target.checked?new Set(items.map(i=>i.id)):new Set())}/> সব নির্বাচন করুন (Select All)</label>
   <div className="cw-review-list">{items.map(r=><article className="cw-question" key={r.id}><label><input type="checkbox" checked={checked.has(r.id)} onChange={()=>toggle(r.id)}/> <h3>{r.data.q}</h3></label></article>)}</div>
   {!items.length?<p>এই স্কোপে কোনো pending প্রশ্ন নেই।</p>:null}
   <div className="cw-toolbar"><button className="primary" disabled={busy||!checked.size} onClick={approveMany}><CheckCircle2 size={16}/> নির্বাচিত {checked.size}টি Approve করুন</button></div>
  </>:<p>উপরে একটি Subject বাছুন pending প্রশ্ন দেখতে।</p>}
 </div>;
}
