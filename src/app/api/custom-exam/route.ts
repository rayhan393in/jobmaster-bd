import {NextRequest,NextResponse} from 'next/server';
import {createHash} from 'node:crypto';
import {taxonomyLeaf} from '@/lib/exam-taxonomy';
import {cloudEnabled} from '@/lib/cloud/config';
import {cloudClient,validOrigin} from '@/lib/cloud/client';
export const runtime='nodejs';export const dynamic='force-dynamic';
async function handle(req:NextRequest,start:boolean){try{
 if(start&&!validOrigin(req))return NextResponse.json({error:'Invalid origin'},{status:403});
 if(start&&Number(req.headers.get('content-length')||0)>20000)return NextResponse.json({error:'Request too large'},{status:413});
 const b=start?await req.json():{track:req.nextUrl.searchParams.get('track')||'BCS'};
 if(!['BCS','EEE'].includes(b.track))return NextResponse.json({error:'Invalid track'},{status:400});
 if(cloudEnabled()){const c=cloudClient(req);const {data,error}=await c.client.rpc('jobmaster_custom_exam',{p:{...b,action:start?'start':'catalog'}});if(error)return c.respond({error:error.code==='PGRST202'?'Custom-Topic-Exams.sql migration আগে ইনস্টল করুন।':error.message},error.message.includes('Unauthorized')?401:400);return c.respond(data);}
 const {user,rateLimit}=await import('@/lib/auth');const u=user(req);if(!u)return NextResponse.json({error:'লগইন করুন।'},{status:401});if(!rateLimit('custom:'+u.id,60))return NextResponse.json({error:'এক মিনিট পরে চেষ্টা করুন।'},{status:429});
 const {db,questionRows}=await import('@/lib/store');
 const {classificationDb}=await import('@/lib/local/classification');classificationDb();
 const reserved=new Set((db.prepare('select question_ids from jm_exams where ends>?').all(Date.now()) as {question_ids:string}[]).flatMap(e=>JSON.parse(e.question_ids) as string[]));
 const verified=new Set((db.prepare('select id from jm_questions where track=? and verified=1').all(b.track) as {id:string}[]).map(q=>q.id));
 const pool=questionRows(b.track).filter(q=>verified.has(q.id)&&!reserved.has(q.id));
 const assignments=new Map((db.prepare('select question_id,subtopic_id from jm_question_classification').all() as {question_id:string,subtopic_id:string}[]).map(r=>[r.question_id,r.subtopic_id]));
 const groups=new Map<string,typeof pool>();const metadata=new Map<string,object>();
 for(const q of pool){const leaf=taxonomyLeaf(assignments.get(q.id)||'');if(leaf&&leaf.subject.track!==b.track)continue;
  const entries=leaf?[
   {key:'topic:'+leaf.topic.id,level:'topic',subject_id:leaf.subject.id,topic_id:leaf.topic.id,subtopic_id:null,subject:leaf.subject.title,topic:leaf.topic.title,subtopic:null},
   {key:'sub:'+leaf.leaf.id,level:'subtopic',subject_id:leaf.subject.id,topic_id:leaf.topic.id,subtopic_id:leaf.leaf.id,subject:leaf.subject.title,topic:leaf.topic.title,subtopic:leaf.leaf.title}
  ]:[{key:'legacy:'+createHash('md5').update(q.subject+'\x1f'+'টপিক অনির্ধারিত').digest('hex'),level:'legacy',subject_id:null,topic_id:null,subtopic_id:null,subject:q.subject,topic:'টপিক অনির্ধারিত',subtopic:null}];
  const snapshot=leaf?{...q,subject:leaf.subject.title,topic:leaf.topic.title,subtopic:leaf.leaf.title,subject_id:leaf.subject.id,topic_id:leaf.topic.id,subtopic_id:leaf.leaf.id}:q;for(const e of entries){groups.set(e.key,[...(groups.get(e.key)||[]),snapshot]);metadata.set(e.key,e);}
 }
 if(!start)return NextResponse.json({version:2,topics:[...groups].map(([key,qs])=>({...metadata.get(key),available:qs.length})),now:Date.now()},{headers:{'Cache-Control':'private, no-store'}});
 if(!Array.isArray(b.selections)||b.selections.length<1||b.selections.length>30||!Number.isInteger(b.minutes)||b.minutes<1||b.minutes>180)throw Error('১–৩০ টপিক ও ১–১৮০ মিনিট দিন।');
 const selected:typeof pool=[];const seen=new Set<string>();const covered=new Set<string>();for(const s of b.selections){if(typeof s.key!=='string'||seen.has(s.key)||!Number.isInteger(s.count)||s.count<1||s.count>100)throw Error('টপিক ও প্রশ্নসংখ্যা সঠিকভাবে দিন।');seen.add(s.key);const qs=groups.get(s.key)||[];if(qs.length<s.count)throw Error('এই টপিকে পর্যাপ্ত যাচাইকৃত প্রশ্ন নেই।');if(qs.some(q=>covered.has(q.id)))throw Error('Parent topic এবং তার subtopic একসঙ্গে নয়।');for(const q of qs)covered.add(q.id);selected.push(...qs.map(q=>({q,r:Math.random()})).sort((a,b)=>a.r-b.r).slice(0,s.count).map(x=>x.q));if(selected.length>100)throw Error('সর্বোচ্চ ১০০ প্রশ্ন দিন।');}
 const id=crypto.randomUUID(),now=Date.now();db.prepare('INSERT INTO jm_sessions(id,user_id,track,started,deadline,snapshot) VALUES(?,?,?,?,?,?)').run(id,u.id,b.track,now,now+b.minutes*60000,JSON.stringify(selected));return NextResponse.json({id,count:selected.length,deadline:now+b.minutes*60000});
 }catch(e){return NextResponse.json({error:(e as Error).message},{status:400});}}
export const GET=(req:NextRequest)=>handle(req,false);
export const POST=(req:NextRequest)=>handle(req,true);
