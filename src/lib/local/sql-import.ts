import {db,fingerprint} from '@/lib/store';
import {courseDb} from '@/lib/local/courses';
import {liveDb} from '@/lib/local/live';
import type {SqlImportAction} from '@/lib/live-exam-validation';
type Row=Record<string,any>;

export function ensureSuperAdminColumn(){
 try{db.exec('alter table jm_users add column is_super_admin integer not null default 0');}catch{/* column already exists */}
 if(process.env.JOBMASTER_ADMIN_EMAIL)db.prepare("update jm_users set is_super_admin=1 where role='admin' and lower(email)=lower(?)").run(process.env.JOBMASTER_ADMIN_EMAIL);
}
export function isSuperAdmin(uid:string){ensureSuperAdminColumn();return !!(db.prepare('select is_super_admin from jm_users where id=?').get(uid) as Row|undefined)?.is_super_admin;}

export function localSqlImport(p:SqlImportAction,uid:string,admin:boolean){
 if(!admin)throw Error('Admin access required');
 ensureSuperAdminColumn();courseDb();liveDb();
 if(p.action==='fingerprints'){
  return {questions:(db.prepare('select fingerprint from jm_questions').all() as Row[]).map(r=>r.fingerprint),
   live:(db.prepare('select fingerprint from jm_live_exam_questions').all() as Row[]).map(r=>r.fingerprint)};
 }
 if(!isSuperAdmin(uid))throw Error('শুধুমাত্র Super Admin SQL Import করতে পারবে');
 if(p.action!=='commit')throw Error('Unknown action');
 if(!p.rows.length||p.rows.length>500)throw Error('প্রতি ব্যাচে ১–৫০০ row দিন; বড় file একাধিক ব্যাচে পাঠান');
 return db.transaction(()=>{
  let cnt=0,dup=0;const errs:Row[]=[];
  for(const v of p.rows){
   try{
    const fp=fingerprint(v.q);
    if(v.status==='live_scheduled'){
     const today=new Date().toISOString().slice(0,10);
     if(!v.exam_date||v.exam_date<today){errs.push({row:v,error:'live_scheduled needs a future exam_date'});continue;}
     if(db.prepare('select 1 from jm_live_exam_questions where fingerprint=?').get(fp)){dup++;continue;}
     const id='live-'+crypto.randomUUID().replace(/-/g,'');
     db.prepare('insert into jm_live_exam_questions(id,track,subject,topic,difficulty,body,options,answer,explanation,exam_date,fingerprint,created,created_by) values(?,?,?,?,?,?,?,?,?,?,?,?,?)')
      .run(id,v.track,(v.subject||'Unspecified').trim(),(v.topic||'Unspecified').trim(),v.difficulty,v.q.trim(),JSON.stringify(v.o),v.a,v.e.trim(),v.exam_date,fp,Date.now(),uid);
     cnt++;
    }else{
     if(db.prepare('select 1 from jm_questions where fingerprint=?').get(fp)){dup++;continue;}
     const id='sql-q-'+crypto.randomUUID().replace(/-/g,'');
     const subject=(v.subject||'Unspecified').trim();
     db.prepare('insert into jm_questions values(?,?,?,?,?,?,?,?,?,?,?)')
      .run(id,v.track,subject,v.q.trim(),JSON.stringify(v.o),v.a,v.e.trim(),'SQL bulk import by super admin','original',fp,v.status==='approved'?1:0);
     const leaf=db.prepare(`select l.id from jm_course_nodes l join jm_course_nodes t on t.id=l.parent_id join jm_course_nodes s on s.id=t.parent_id
      where l.level='subtopic' and l.course_id=? and lower(trim(s.title))=lower(trim(?)) and lower(trim(t.title))=lower(trim(?)) order by l.id like '%:general' desc limit 1`)
      .get(v.track,subject,(v.topic||'').trim()) as Row|undefined;
     db.prepare('insert into jm_course_questions values(?,?,?) on conflict(course_id,question_id) do nothing').run(v.track,id,leaf?.id||null);
     if(leaf)db.prepare('insert into jm_question_classification values(?,?) on conflict(question_id) do nothing').run(id,leaf.id);
     cnt++;
    }
   }catch(e){errs.push({row:v,error:(e as Error).message});}
  }
  return {ok:true,imported:cnt,duplicates:dup,errors:errs};
 })();
}
