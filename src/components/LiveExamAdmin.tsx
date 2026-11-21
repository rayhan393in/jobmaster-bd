'use client';
import {useCallback,useEffect,useState} from 'react';
import {liveApi} from '@/components/DailyLiveExam';
import {Settings,Upload,Trash2,Radio,Download} from 'lucide-react';
type Cfg={start_minute:number,end_minute:number,duration_seconds:number,total_questions:number,negative_mark:number,track:string};
type BankRow={id:string,track:string,subject:string,topic:string,difficulty:string,q:string,exam_date:string,created:string};
const toHHMM=(m:number)=>String(Math.floor(m/60)).padStart(2,'0')+':'+String(m%60).padStart(2,'0');
const toMinutes=(s:string)=>{const [h,m]=s.split(':').map(Number);return h*60+m;};

export default function LiveExamAdmin(){
 const [cfg,setCfg]=useState<Cfg|null>(null),[busy,setBusy]=useState(false),[message,setMessage]=useState('');
 const [rows,setRows]=useState<BankRow[]>([]),[filterDate,setFilterDate]=useState(''),[summary,setSummary]=useState<{exam_date:string,available_questions:number,participants:number,submitted:number}|null>(null);
 const [sqlText,setSqlText]=useState(''),[importReport,setImportReport]=useState<{imported:number,duplicates:number,errors:unknown[]}|null>(null);

 const load=useCallback(async()=>{try{setCfg(await liveApi({action:'config_get'}));setSummary(await liveApi({action:'today_summary'}));const b=await liveApi({action:'bank_list',...(filterDate?{exam_date:filterDate}:{})});setRows(b.rows);}catch(e){setMessage((e as Error).message);}},[filterDate]);
 useEffect(()=>{load();},[load]);

 async function saveCfg(e:React.FormEvent){e.preventDefault();if(!cfg)return;setBusy(true);setMessage('');try{await liveApi({action:'config_save',...cfg});setMessage('Live Exam সেটিংস সংরক্ষিত হয়েছে।');await load();}catch(e){setMessage((e as Error).message);}finally{setBusy(false);}}

 function parseBankCsvLines(text:string){
  // Simple pipe-delimited bulk entry format: subject|topic|difficulty|question|optA|optB|optC|optD|correct(A-D)|explanation|exam_date
  return text.split('\n').map(l=>l.trim()).filter(Boolean).map(line=>{
   const parts=line.split('|').map(s=>s.trim());
   if(parts.length<11)throw Error('প্রতিটি লাইনে ১১টি অংশ দিন: subject|topic|difficulty|question|A|B|C|D|correct|explanation|exam_date');
   const [subject,topic,difficulty,q,a0,a1,a2,a3,correct,e,exam_date]=parts;
   return {track:cfg?.track||'BCS',subject,topic,difficulty:(difficulty||'standard') as 'easy'|'standard'|'hard',q,o:[a0,a1,a2,a3],a:'ABCD'.indexOf(correct.toUpperCase()),e,exam_date};
  });
 }

 async function importBank(){setBusy(true);setMessage('');setImportReport(null);try{const rowsToImport=parseBankCsvLines(sqlText);const r=await liveApi({action:'bank_import',rows:rowsToImport});setImportReport(r);setMessage(`${r.imported}টি প্রশ্ন bank-এ যোগ হয়েছে।`);setSqlText('');await load();}catch(e){setMessage((e as Error).message);}finally{setBusy(false);}}

 async function del(id:string){if(!confirm('এই লাইভ প্রশ্নটি মুছে ফেলতে চান?'))return;try{await liveApi({action:'bank_delete',id});await load();}catch(e){setMessage((e as Error).message);}}

 function downloadTemplate(){const day=new Date(Date.now()+86400000).toISOString().slice(0,10);const text=`বাংলা ব্যাকরণ|সন্ধি|standard|প্রশ্ন এখানে লিখুন|প্রথম|দ্বিতীয়|তৃতীয়|চতুর্থ|A|ব্যাখ্যা এখানে লিখুন|${day}\n`;const u=URL.createObjectURL(new Blob([text],{type:'text/plain'}));const a=document.createElement('a');a.href=u;a.download='live-exam-bank-template.txt';a.click();URL.revokeObjectURL(u);}

 return <div className="live-exam-admin" data-feature="live-exam-admin">
  <header className="cw-heading"><div><span className="cw-eyebrow">DAILY LIVE EXAM</span><h2><Radio size={22}/> Live Exam নিয়ন্ত্রণ ও Question Bank</h2><p>এই bank-এর প্রশ্ন কখনো সাধারণ Pending Approval queue-তে যায় না — নির্ধারিত exam_date-এ সরাসরি publish হয়।</p></div></header>
  {message?<div className="notice" role="status">{message}</div>:null}
  {summary?<div className="cw-stat-grid"><div><span>আজকের তারিখ</span><strong>{summary.exam_date}</strong></div><div><span>আজকের প্রশ্ন প্রস্তুত</span><strong>{summary.available_questions}</strong></div><div><span>আজকে অংশগ্রহণকারী</span><strong>{summary.participants}</strong></div><div><span>আজকে ফলাফল প্রকাশিত</span><strong>{summary.submitted}</strong></div></div>:null}

  {cfg?<form className="admin-form" onSubmit={saveCfg}><h3><Settings size={18}/> Exam সেটিংস</h3><div className="form-grid">
   <label>শুরু সময়<input type="time" value={toHHMM(cfg.start_minute)} onChange={e=>setCfg({...cfg,start_minute:toMinutes(e.target.value)})}/></label>
   <label>শেষ সময় (নতুন শুরু বন্ধ)<input type="time" value={toHHMM(cfg.end_minute)} onChange={e=>setCfg({...cfg,end_minute:toMinutes(e.target.value)})}/></label>
   <label>সময়কাল (মিনিট)<input type="number" min={1} max={120} value={Math.round(cfg.duration_seconds/60)} onChange={e=>setCfg({...cfg,duration_seconds:Number(e.target.value)*60})}/></label>
   <label>মোট প্রশ্ন সংখ্যা<input type="number" min={1} max={200} value={cfg.total_questions} onChange={e=>setCfg({...cfg,total_questions:Number(e.target.value)})}/></label>
   <label>নেগেটিভ মার্কিং (০–১)<input type="number" step="0.05" min={0} max={1} value={cfg.negative_mark} onChange={e=>setCfg({...cfg,negative_mark:Number(e.target.value)})}/></label>
   <label>Track<select value={cfg.track} onChange={e=>setCfg({...cfg,track:e.target.value})}><option>BCS</option><option>EEE</option></select></label>
  </div><p className="muted-text">চলমান attempt-এ এই পরিবর্তন প্রভাব ফেলবে না; পরবর্তী শুরুর সময় থেকে কার্যকর হবে। একবার শুরু করা exam ৫০ মিনিট (বা সেট করা সময়) চলবে, উইন্ডো বন্ধ হলেও।</p><button className="primary" disabled={busy}>সংরক্ষণ করুন</button></form>:null}

  <div className="admin-form"><h3><Upload size={18}/> Live Exam Question Bank-এ প্রশ্ন যোগ করুন</h3><p>প্রতি লাইনে একটি প্রশ্ন, pipe (|) দিয়ে আলাদা: <code>subject|topic|difficulty|question|A|B|C|D|correct|explanation|exam_date(YYYY-MM-DD)</code>। শুধু ভবিষ্যতের তারিখ গ্রহণযোগ্য। Approval লাগবে না — নির্ধারিত তারিখে সরাসরি প্রকাশিত হবে।</p>
  <div className="cw-toolbar"><button onClick={downloadTemplate}><Download size={16}/> Template ডাউনলোড</button></div>
  <textarea aria-label="Live exam bank rows" rows={8} value={sqlText} onChange={e=>setSqlText(e.target.value)}/>
  <div className="cw-toolbar"><button className="primary" disabled={!sqlText||busy} onClick={importBank}><Upload size={16}/> Bank-এ Import করুন</button></div>
  {importReport?<div className="notice">সফল: {importReport.imported} · Duplicate: {importReport.duplicates} · Error: {importReport.errors.length}</div>:null}
  </div>

  <div className="admin-form"><h3>Question Bank তালিকা</h3><label>তারিখ ফিল্টার<input type="date" value={filterDate} onChange={e=>setFilterDate(e.target.value)}/></label>
  <div className="cw-review-list">{rows.map(r=><article className="cw-question" key={r.id}><div className="cw-question-meta"><span className="badge">{r.exam_date}</span><span className="badge">{r.subject} · {r.topic}</span><span className="badge">{r.difficulty}</span></div><h3>{r.q}</h3><footer><button disabled={busy} onClick={()=>del(r.id)}><Trash2 size={15}/> মুছুন</button></footer></article>)}</div>{!rows.length?<p>কোনো প্রশ্ন নেই এই ফিল্টারে।</p>:null}</div>
 </div>;
}
