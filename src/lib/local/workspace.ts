import {NextRequest,NextResponse} from 'next/server';
import {db,questionRows,Session,finish,finalizeOverdue} from '@/lib/store';
import {Question} from '@/lib/catalog';
import {user,sameOrigin,rateLimit} from '@/lib/auth';

const error=(message:string,status=400)=>NextResponse.json({error:message},{status});
function canReview(s:Session){if(!s.exam_id)return true;const e=db.prepare('SELECT publish FROM jm_exams WHERE id=?').get(s.exam_id) as {publish:number};return Date.now()>=e.publish;}
export async function GET(req:NextRequest){
 const u=user(req);if(!u)return error('লগইন করুন।',401);finalizeOverdue();
 const id=req.nextUrl.searchParams.get('attempt');
 if(id){const s=db.prepare('SELECT * FROM jm_sessions WHERE id=? AND user_id=?').get(id,u.id) as Session|undefined;if(!s)return error('পরীক্ষাটি পাওয়া যায়নি।',404);const qs=JSON.parse(s.snapshot) as Question[];return NextResponse.json({id:s.id,submitted:s.submitted,deadline:s.deadline,now:Date.now(),questions:qs.map(({q,o,id},i)=>({q,o,questionId:id,id:i})),answers:db.prepare('SELECT question,choice FROM jm_answers WHERE session_id=?').all(id),result:s.submitted&&canReview(s)?{id:s.id,score:s.score,correct:s.correct,total:qs.length,answered:s.answered}:null,review:s.submitted&&canReview(s)?qs:undefined});}
 const track=req.nextUrl.searchParams.get('track')==='EEE'?'EEE':'BCS';
 const sessions=db.prepare('SELECT * FROM jm_sessions WHERE user_id=? AND submitted=1 AND track=? ORDER BY started DESC').all(u.id,track) as Session[];
 const results=sessions.filter(canReview).map(s=>({id:s.id,score:s.score,correct:s.correct,total:JSON.parse(s.snapshot).length,answered:s.answered,created:new Date(s.started).toISOString()}));
 const weakness:Record<string,{wrong:number,total:number}>={};for(const s of sessions.filter(canReview)){const qs=JSON.parse(s.snapshot) as Question[];const rows=db.prepare('SELECT question,choice FROM jm_answers WHERE session_id=?').all(s.id) as {question:number,choice:number}[];for(const r of rows){const q=qs[r.question];const k=q.subject;weakness[k]??={wrong:0,total:0};weakness[k].total++;if(q.a!==r.choice)weakness[k].wrong++;}}
 return NextResponse.json({tasks:db.prepare('SELECT * FROM jm_tasks WHERE user_id=? AND track=?').all(u.id,track),results,weakness:Object.entries(weakness).map(([subject,v])=>({subject,...v,accuracy:Math.round((v.total-v.wrong)/v.total*100)})).sort((a,b)=>a.accuracy-b.accuracy),exams:db.prepare('SELECT id,title,track,starts,ends,publish,duration FROM jm_exams WHERE track=? ORDER BY starts DESC').all(track),active:db.prepare('SELECT id,deadline FROM jm_sessions WHERE user_id=? AND submitted=0 AND track=? ORDER BY started DESC LIMIT 1').get(u.id,track),bookmarks:db.prepare('SELECT question_id FROM jm_bookmarks WHERE user_id=?').all(u.id),questionCount:questionRows(track).length,user:u});
}
export async function POST(req:NextRequest){
 try{
 const u=user(req);if(!u)return error('লগইন করুন।',401);if(!sameOrigin(req))return error('Invalid origin',403);if(!rateLimit('workspace:'+u.id,300))return error('একটু পরে চেষ্টা করুন।',429);
 const b=await req.json();const track=b.track==='EEE'?'EEE':'BCS';finalizeOverdue();
 if(b.action==='routine'){
 const minutes=Number(b.minutes);if(!Number.isInteger(minutes)||minutes<15||minutes>240)return error('সময় ১৫–২৪০ মিনিট দিন।');
 const preferred=track==='EEE'?['Electrical Machines','Circuits','Power Systems']:['বাংলা','English','গাণিতিক যুক্তি'];
 const recent=db.prepare('SELECT * FROM jm_sessions WHERE user_id=? AND track=? AND submitted=1 ORDER BY started DESC LIMIT 10').all(u.id,track) as Session[];
 const weak:Record<string,number>={};for(const s of recent.filter(canReview)){const qs=JSON.parse(s.snapshot) as Question[];for(const r of db.prepare('SELECT question,choice FROM jm_answers WHERE session_id=?').all(s.id) as {question:number,choice:number}[]){if(qs[r.question].a!==r.choice)weak[qs[r.question].subject]=(weak[qs[r.question].subject]||0)+1;}}
 const subjects=[...Object.keys(weak).sort((a,b)=>weak[b]-weak[a]),...preferred].filter((x,i,a)=>a.indexOf(x)===i).slice(0,3);
 db.transaction(()=>{db.prepare('DELETE FROM jm_tasks WHERE user_id=? AND track=?').run(u.id,track);subjects.forEach((s,i)=>db.prepare('INSERT INTO jm_tasks VALUES(?,?,?,?,?,0,?)').run(crypto.randomUUID(),u.id,['থিওরি ও দুর্বল ধারণা ঝালাই','২০টি MCQ অনুশীলন','পূর্বের ভুল ও রিভিশন'][i],s,minutes,track));})();return NextResponse.json({ok:true});}
 if(b.action==='toggle'){db.prepare('UPDATE jm_tasks SET done=1-done WHERE id=? AND user_id=?').run(b.id,u.id);return NextResponse.json({ok:true});}
 if(b.action==='bookmark'){const q=db.prepare('SELECT id FROM jm_questions WHERE id=?').get(b.questionId);if(!q)return error('প্রশ্ন পাওয়া যায়নি।',404);const exists=db.prepare('SELECT * FROM jm_bookmarks WHERE user_id=? AND question_id=?').get(u.id,b.questionId);if(exists)db.prepare('DELETE FROM jm_bookmarks WHERE user_id=? AND question_id=?').run(u.id,b.questionId);else db.prepare('INSERT INTO jm_bookmarks VALUES(?,?)').run(u.id,b.questionId);return NextResponse.json({bookmarked:!exists});}
 if(b.action==='start'){
 let qs=questionRows(track);let duration=1800000;let examId:string|null=null;
 if(b.examId){const e=db.prepare('SELECT * FROM jm_exams WHERE id=?').get(b.examId) as {id:string,track:string,starts:number,ends:number,duration:number,question_ids:string}|undefined;if(!e||Date.now()<e.starts||Date.now()>=e.ends)return error('পরীক্ষার নির্ধারিত সময়ের বাইরে।',409);const existing=db.prepare('SELECT id FROM jm_sessions WHERE user_id=? AND exam_id=?').get(u.id,e.id) as {id:string}|undefined;if(existing)return NextResponse.json({id:existing.id});qs=questionRows(e.track).filter(q=>(JSON.parse(e.question_ids) as string[]).includes(q.id));duration=Math.min(e.duration*1000,e.ends-Date.now());examId=e.id;}
 else {
 if(b.mode==='bookmarked'){const ids=(db.prepare('SELECT question_id FROM jm_bookmarks WHERE user_id=?').all(u.id) as {question_id:string}[]).map(r=>r.question_id);qs=qs.filter(q=>ids.includes(q.id));}
 if(b.mode==='incorrect'){const ids=new Set<string>();const past=db.prepare('SELECT * FROM jm_sessions WHERE user_id=? AND submitted=1').all(u.id) as Session[];for(const s of past.filter(canReview)){const snap=JSON.parse(s.snapshot) as Question[];for(const a of db.prepare('SELECT question,choice FROM jm_answers WHERE session_id=?').all(s.id) as {question:number,choice:number}[])if(snap[a.question].a!==a.choice)ids.add(snap[a.question].id);}qs=qs.filter(q=>ids.has(q.id));}
 const count=Number(b.count)||30;if(!Number.isInteger(count)||count<1||count>100)return error('প্রশ্নসংখ্যা ১–১০০ দিন।');qs=qs.sort(()=>Math.random()-.5).slice(0,count);duration=Math.max(600000,qs.length*60000);
 }
 if(!qs.length)return error('এই মোডে এখনও কোনো প্রশ্ন নেই।');
 const id=crypto.randomUUID(),now=Date.now();db.prepare('INSERT INTO jm_sessions(id,user_id,track,started,deadline,snapshot,exam_id) VALUES(?,?,?,?,?,?,?)').run(id,u.id,qs[0].track,now,now+duration,JSON.stringify(qs),examId);return NextResponse.json({id});}
 const s=db.prepare('SELECT * FROM jm_sessions WHERE id=? AND user_id=?').get(b.id,u.id) as Session|undefined;if(!s)return error('পরীক্ষাটি পাওয়া যায়নি।',404);
 const qs=JSON.parse(s.snapshot) as Question[];
 if(b.action==='answer'){if(s.submitted||Date.now()>=s.deadline)return error('পরীক্ষার সময় শেষ।',409);if(!Number.isInteger(b.question)||b.question<0||b.question>=qs.length||!Number.isInteger(b.choice)||b.choice<0||b.choice>3)return error('উত্তর সঠিকভাবে দিন।');db.prepare('INSERT OR REPLACE INTO jm_answers VALUES(?,?,?)').run(b.id,b.question,b.choice);return NextResponse.json({ok:true});}
 if(b.action==='submit'){const result=finish(b.id);if(!canReview(result))return NextResponse.json({pending:true,result:null,review:[]});return NextResponse.json({result:{id:result.id,score:result.score,correct:result.correct,total:qs.length,answered:result.answered},review:qs});}
 return error('Unknown action');
 }catch{return error('অনুরোধটি সম্পন্ন করা যায়নি।');}
}
