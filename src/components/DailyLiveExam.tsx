'use client';
import {useCallback,useEffect,useRef,useState} from 'react';
import {Radio,Clock,CalendarDays,Trophy} from 'lucide-react';
import ExamPaper,{PaperQuestion,PaperResult} from './ExamPaper';
export async function liveApi(body:object){const r=await fetch('/api/live',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(body)});const d=await r.json();if(!r.ok)throw Error(d.error);return d;}
type Status={now:number,exam_date:string,window_starts:number,window_ends:number,duration_seconds:number,total_questions:number,negative_mark:number,track:string,available_questions:number,attempt_id:string|null,submitted:number,deadline:number|null,can_start:boolean};

export default function DailyLiveExam({track}:{track:string}){
 const [status,setStatus]=useState<Status|null>(null),[error,setError]=useState(''),[offset,setOffset]=useState(0),[now,setNow]=useState(Date.now());
 const [attempt,setAttempt]=useState(''),[qs,setQs]=useState<PaperQuestion[]>([]),[answers,setAnswers]=useState<Record<number,number>>({}),[marked,setMarked]=useState<number[]>([]);
 const [deadline,setDeadline]=useState(0),[result,setResult]=useState<PaperResult|null>(null),[busy,setBusy]=useState(false),[saving,setSaving]=useState(0),[starting,setStarting]=useState(false);
 const submitting=useRef(false),savingRef=useRef(0);

 const loadStatus=useCallback(async()=>{try{const d=await liveApi({action:'status'});setStatus(d);setOffset(d.now-Date.now());setError('');return d as Status;}catch(e){setError((e as Error).message);return null;}},[]);
 const loadState=useCallback(async(id:string)=>{const d=await liveApi({action:'state',id});setAttempt(id);setDeadline(d.deadline);const a:Record<number,number>={};for(const x of d.answers)a[x.question]=x.choice;setAnswers(a);
  if(d.submitted&&d.result){setQs(d.review.map((q:any)=>({id:q.id,q:q.q,o:q.o,a:q.a,e:q.e,subject:q.subject})));setResult(d.result);}
  else{setQs(d.questions.map((q:any)=>({id:q.id,q:q.q,o:q.o,subject:q.subject})));setResult(null);}
 },[]);

 useEffect(()=>{loadStatus().then(d=>{if(d?.attempt_id)loadState(d.attempt_id).catch(e=>setError((e as Error).message));});const t=setInterval(()=>{if(!attempt)loadStatus();},20000);return()=>clearInterval(t);},[loadStatus,loadState,attempt]);
 useEffect(()=>{const t=setInterval(()=>setNow(Date.now()+offset),1000);return()=>clearInterval(t);},[offset]);

 async function submit(){if(submitting.current||savingRef.current>0||!attempt)return;submitting.current=true;setBusy(true);try{const d=await liveApi({action:'submit',id:attempt});setQs(d.review.map((q:any)=>({id:q.id,q:q.q,o:q.o,a:q.a,e:q.e,subject:q.subject})));setResult(d.result);}catch(e){setError((e as Error).message);}finally{setBusy(false);submitting.current=false;}}
 useEffect(()=>{if(!attempt||result)return;const t=setInterval(()=>{if(deadline&&Date.now()+offset>=deadline)submit();},1000);return()=>clearInterval(t);},[attempt,deadline,result,offset]);

 async function start(){setStarting(true);try{const d=await liveApi({action:'start'});await loadState(d.id);}catch(e){setError((e as Error).message);}finally{setStarting(false);}}
 async function saveAnswer(i:number,c:number){setAnswers(a=>({...a,[i]:c}));savingRef.current++;setSaving(savingRef.current);try{await liveApi({action:'answer',id:attempt,question:i,choice:c});}catch(e){setError((e as Error).message);}finally{savingRef.current--;setSaving(savingRef.current);}}

 const remaining=deadline?Math.max(0,Math.ceil((deadline-now)/1000)):0;
 const time=(n:number)=>new Date(n).toLocaleTimeString('bn-BD',{timeZone:'Asia/Dhaka',hour:'numeric',minute:'2-digit'});

 if(attempt&&qs.length){
  return <div className="live-page" data-daily-live="v6">
   <section className="live-page-heading"><div><span className="hub-kicker">DAILY LIVE EXAM · {status?.track||track}</span><h2>{result?'আজকের লাইভ পরীক্ষার ফলাফল':'আজকের লাইভ পরীক্ষা চলছে'}</h2><p>{status?.total_questions||qs.length} প্রশ্ন · {result?result.total:status?Math.round(status.duration_seconds/60):50} মিনিট · ভুলে −{status?.negative_mark??0.25}</p></div>{!result?<span className="timer"><Clock size={17}/>{Math.floor(remaining/60)}:{String(remaining%60).padStart(2,'0')}</span>:null}</section>
   {error?<div className="notice" role="alert">{error}</div>:null}
   <ExamPaper questions={qs} answers={answers} marked={marked} onMark={i=>setMarked(m=>m.includes(i)?m.filter(n=>n!==i):[...m,i])} onAnswer={saveAnswer} onSubmit={submit} onPause={()=>loadStatus()} onPdf={()=>{}} busy={busy} saving={saving} result={result}/>
  </div>;
 }

 const s=status;
 const live=s&&now>=s.window_starts&&now<s.window_ends;
 return <div className="live-page" data-daily-live="v6">
  <section className="live-page-heading"><div><span className="hub-kicker">DAILY LIVE EXAM · ASIA/DHAKA</span><h2>আজকের লাইভ পরীক্ষা</h2><p>প্রতিদিন একটি লাইভ পরীক্ষা — {s?`${s.total_questions} প্রশ্ন, ${Math.round(s.duration_seconds/60)} মিনিট, ভুলে −${s.negative_mark}`:'লোড হচ্ছে…'}</p></div></section>
  {error?<div className="notice" role="alert">{error}</div>:null}
  {s?<article className="daily-paper card">
   <div className="daily-paper-top"><span className="badge">{s.track} · DAILY LIVE</span><span className={'daily-status '+(live?'is-live':'')}>{live?'● চলমান উইন্ডো':now>=s.window_ends?'আজকের উইন্ডো শেষ':'উইন্ডো শুরু হয়নি'}</span></div>
   <h2>{s.exam_date} তারিখের লাইভ পরীক্ষা</h2>
   <div className="daily-meta"><span><CalendarDays size={16}/>{time(s.window_starts)}–{time(s.window_ends)}</span><span>{Math.round(s.duration_seconds/60)} মিনিট</span><span>{s.total_questions} নম্বর</span></div>
   <p>{s.available_questions} টি প্রশ্ন আজকের জন্য প্রস্তুত আছে। শুরু করলে সময় শুরু হয়ে যাবে — সার্ভার সময় অনুযায়ী, একবার শুরু করলে বন্ধ করা যাবে না। একদিনে একবারই অংশ নেওয়া যাবে।</p>
   <div className="daily-action"><button className="primary" disabled={!s.can_start||starting} onClick={start}><Radio size={17}/>{starting?'শুরু হচ্ছে…':s.can_start?'লাইভ পরীক্ষা শুরু করুন':s.available_questions===0?'আজকের প্রশ্ন এখনো যুক্ত হয়নি':now<s.window_starts?'উইন্ডো শুরু হয়নি':'উইন্ডো বন্ধ হয়ে গেছে'}</button></div>
  </article>:null}
  <div className="notice"><Trophy size={16}/> ফলাফল জমা দেওয়ার সাথে সাথেই দেখা যাবে — স্কোর, সঠিক ও ভুল উত্তরের সংখ্যাসহ।</div>
 </div>;
}
