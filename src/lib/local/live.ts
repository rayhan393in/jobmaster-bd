import {db,fingerprint} from '@/lib/store';
import type {LiveExamAction} from '@/lib/live-exam-validation';
type Row=Record<string,any>;

export function liveDb(){
 db.exec(`create table if not exists jm_live_exam_settings(id integer primary key check(id=1),start_minute integer not null default 600,end_minute integer not null default 1320,duration_seconds integer not null default 3000,total_questions integer not null default 100,negative_mark real not null default 0.25,track text not null default 'BCS',updated_by text,updated integer not null);
create table if not exists jm_live_exam_questions(id text primary key,track text not null default 'BCS',subject text not null,topic text not null,difficulty text not null default 'standard',body text not null,options text not null,answer integer not null,explanation text not null,exam_date text not null,fingerprint text not null unique,created integer not null,created_by text);
create index if not exists jm_live_q_date on jm_live_exam_questions(exam_date,track);
create table if not exists jm_live_exam_attempts(id text primary key,user_id text not null,exam_date text not null,track text not null,question_ids text not null,started integer not null,deadline integer not null,total_marks real not null,negative_mark real not null,submitted integer not null default 0,score real,correct integer,wrong integer,answered integer,unique(user_id,exam_date));
create index if not exists jm_live_a_due on jm_live_exam_attempts(deadline) where submitted=0;
create table if not exists jm_live_exam_answers(attempt_id text not null,question integer not null,choice integer not null,primary key(attempt_id,question));`);
 db.prepare('insert or ignore into jm_live_exam_settings(id,start_minute,end_minute,duration_seconds,total_questions,negative_mark,track,updated) values(1,600,1320,3000,100,0.25,\'BCS\',?)').run(Date.now());
 return db;
}

// Bangladesh is a fixed UTC+6 offset (no DST) — mirrors `at time zone 'Asia/Dhaka'` in the cloud RPC.
function dhaka(){
 const now=Date.now();
 const parts=new Intl.DateTimeFormat('en-CA',{timeZone:'Asia/Dhaka',year:'numeric',month:'2-digit',day:'2-digit',hour:'2-digit',minute:'2-digit',hour12:false}).formatToParts(now);
 const o:Record<string,string>={};for(const p of parts)o[p.type]=p.value;
 const dateStr=`${o.year}-${o.month}-${o.day}`;
 const midnightUtc=Date.UTC(+o.year,+o.month-1,+o.day,0,0,0)-6*3600000;
 return {now,dateStr,midnightUtc};
}

function settings(){return db.prepare('select * from jm_live_exam_settings where id=1').get() as Row;}
function finishAttempt(id:string){
 const att=db.prepare('select * from jm_live_exam_attempts where id=?').get(id) as Row|undefined;
 if(!att||att.submitted)return;
 const ids=JSON.parse(att.question_ids) as string[];
 const answers=db.prepare('select question,choice from jm_live_exam_answers where attempt_id=?').all(id) as Row[];
 let correct=0;for(const a of answers){const q=db.prepare('select answer from jm_live_exam_questions where id=?').get(ids[a.question]) as Row|undefined;if(q&&q.answer===a.choice)correct++;}
 const n=answers.length,wrong=n-correct,score=correct-wrong*att.negative_mark;
 db.prepare('update jm_live_exam_attempts set submitted=1,answered=?,correct=?,wrong=?,score=? where id=?').run(n,correct,wrong,score,id);
}
export function expireOverdueLive(){liveDb();const rows=db.prepare('select id from jm_live_exam_attempts where submitted=0 and deadline<=?').all(Date.now()) as Row[];for(const r of rows)finishAttempt(r.id);}

function questionView(id:string,ord:number,withAnswer:boolean){
 const q=db.prepare('select * from jm_live_exam_questions where id=?').get(id) as Row;
 const base:Row={id:ord,q:q.body,o:JSON.parse(q.options),subject:q.subject,topic:q.topic};
 if(withAnswer){base.a=q.answer;base.e=q.explanation;}
 return base;
}

export function localLive(p:LiveExamAction,uid:string,admin:boolean){
 liveDb();expireOverdueLive();
 const cfg=settings();
 const {now,dateStr,midnightUtc}=dhaka();
 const winStart=midnightUtc+cfg.start_minute*60000, winEnd=midnightUtc+cfg.end_minute*60000;

 if(p.action==='status'){
  const att=db.prepare('select * from jm_live_exam_attempts where user_id=? and exam_date=?').get(uid,dateStr) as Row|undefined;
  const n=(db.prepare('select count(*) n from jm_live_exam_questions where exam_date=? and track=?').get(dateStr,cfg.track) as Row).n;
  return {now,exam_date:dateStr,window_starts:winStart,window_ends:winEnd,duration_seconds:cfg.duration_seconds,total_questions:cfg.total_questions,
   negative_mark:cfg.negative_mark,track:cfg.track,available_questions:n,attempt_id:att?.id||null,submitted:att?.submitted||0,deadline:att?.deadline||null,
   can_start:!att&&now>=winStart&&now<winEnd&&n>0};
 }
 if(p.action==='start')return db.transaction(()=>{
  const existing=db.prepare('select * from jm_live_exam_attempts where user_id=? and exam_date=?').get(uid,dateStr) as Row|undefined;
  if(existing)return {id:existing.id};
  if(now<winStart)throw Error('আজকের লাইভ পরীক্ষা এখনো শুরু হয়নি');
  if(now>=winEnd)throw Error('আজকের লাইভ পরীক্ষা শুরুর সময় শেষ হয়ে গেছে');
  const pool=(db.prepare('select id from jm_live_exam_questions where exam_date=? and track=? order by random() limit ?').all(dateStr,cfg.track,cfg.total_questions) as Row[]).map(r=>r.id);
  if(!pool.length)throw Error('আজকের জন্য কোনো লাইভ প্রশ্ন নির্ধারিত নেই');
  const id=crypto.randomUUID();
  db.prepare('insert into jm_live_exam_attempts(id,user_id,exam_date,track,question_ids,started,deadline,total_marks,negative_mark) values(?,?,?,?,?,?,?,?,?)')
   .run(id,uid,dateStr,cfg.track,JSON.stringify(pool),now,now+cfg.duration_seconds*1000,pool.length,cfg.negative_mark);
  return {id};
 })();
 if(['state','answer','submit'].includes(p.action)){
  const id=(p as {id:string}).id;
  const att=db.prepare('select * from jm_live_exam_attempts where id=? and user_id=?').get(id,uid) as Row|undefined;
  if(!att)throw Error('Attempt not found');
  const ids=JSON.parse(att.question_ids) as string[];
  if(p.action==='answer'){
   if(att.submitted||now>=att.deadline)throw Error('পরীক্ষার সময় শেষ');
   const {question,choice}=p as {question:number,choice:number};
   if(question<0||question>=ids.length||choice<0||choice>3)throw Error('Invalid answer');
   db.prepare('insert into jm_live_exam_answers(attempt_id,question,choice) values(?,?,?) on conflict(attempt_id,question) do update set choice=excluded.choice').run(id,question,choice);
   return {ok:true};
  }
  if(p.action==='submit'){
   finishAttempt(id);
   const fin=db.prepare('select * from jm_live_exam_attempts where id=?').get(id) as Row;
   return {result:{score:fin.score,correct:fin.correct,wrong:fin.wrong,answered:fin.answered,total:ids.length},
    review:ids.map((qid,i)=>questionView(qid,i,true))};
  }
  return {id:att.id,submitted:att.submitted,deadline:att.deadline,now,negative_mark:att.negative_mark,
   questions:ids.map((qid,i)=>questionView(qid,i,false)),
   answers:(db.prepare('select question,choice from jm_live_exam_answers where attempt_id=?').all(id) as Row[]),
   result:att.submitted?{score:att.score,correct:att.correct,wrong:att.wrong,answered:att.answered,total:ids.length}:null,
   review:att.submitted?ids.map((qid,i)=>questionView(qid,i,true)):null};
 }
 if(!admin)throw Error('Admin access required');
 if(p.action==='config_get')return cfg;
 if(p.action==='config_save'){
  db.prepare('update jm_live_exam_settings set start_minute=?,end_minute=?,duration_seconds=?,total_questions=?,negative_mark=?,track=?,updated_by=?,updated=? where id=1')
   .run(p.start_minute,p.end_minute,p.duration_seconds,p.total_questions,p.negative_mark,p.track,uid,Date.now());
  return {ok:true};
 }
 if(p.action==='bank_list'){
  const rows=p.exam_date?db.prepare('select id,track,subject,topic,difficulty,body q,exam_date,created from jm_live_exam_questions where exam_date=? order by exam_date desc,id').all(p.exam_date)
   :db.prepare('select id,track,subject,topic,difficulty,body q,exam_date,created from jm_live_exam_questions order by exam_date desc,id limit 500').all();
  return {rows};
 }
 if(p.action==='bank_delete'){
  const used=db.prepare("select 1 from jm_live_exam_attempts where question_ids like '%\"'||?||'\"%'").get(p.id);
  if(used)throw Error('ব্যবহৃত প্রশ্ন মোছা যাবে না');
  db.prepare('delete from jm_live_exam_questions where id=?').run(p.id);
  return {ok:true};
 }
 if(p.action==='bank_import')return db.transaction(()=>{
  let cnt=0,dup=0;const errs:Row[]=[];
  for(const v of p.rows){
   if(!v.exam_date||v.exam_date<dateStr){errs.push({row:v,error:'ভুল subject/topic/q/o/a/e অথবা exam_date অতীতের'});continue;}
   const fp=fingerprint(v.q);
   if(db.prepare('select 1 from jm_live_exam_questions where fingerprint=?').get(fp)){dup++;continue;}
   try{
    const id='live-'+crypto.randomUUID().replace(/-/g,'');
    db.prepare('insert into jm_live_exam_questions(id,track,subject,topic,difficulty,body,options,answer,explanation,exam_date,fingerprint,created,created_by) values(?,?,?,?,?,?,?,?,?,?,?,?,?)')
     .run(id,v.track||'BCS',v.subject.trim(),v.topic.trim(),v.difficulty||'standard',v.q.trim(),JSON.stringify(v.o),v.a,v.e.trim(),v.exam_date,fp,Date.now(),uid);
    cnt++;
   }catch(e){errs.push({row:v,error:(e as Error).message});}
  }
  return {ok:true,imported:cnt,duplicates:dup,errors:errs};
 })();
 if(p.action==='today_summary'){
  return {exam_date:dateStr,
   available_questions:(db.prepare('select count(*) n from jm_live_exam_questions where exam_date=? and track=?').get(dateStr,cfg.track) as Row).n,
   participants:(db.prepare('select count(*) n from jm_live_exam_attempts where exam_date=?').get(dateStr) as Row).n,
   submitted:(db.prepare('select count(*) n from jm_live_exam_attempts where exam_date=? and submitted=1').get(dateStr) as Row).n};
 }
 throw Error('Unknown action');
}
