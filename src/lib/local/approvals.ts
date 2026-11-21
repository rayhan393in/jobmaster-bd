import {db} from '@/lib/store';
import {courseDb} from '@/lib/local/courses';
import type {ApprovalsAction} from '@/lib/live-exam-validation';
type Row=Record<string,any>;

export function localApprovals(p:ApprovalsAction,uid:string,admin:boolean){
 if(!admin)throw Error('Admin access required');
 courseDb();
 const c=p.course_id;
 if(!db.prepare('select 1 from jm_courses where id=?').get(c))throw Error('Valid course_id required');

 if(p.action==='pending_summary'){
  const pending=(db.prepare(`select count(*) n from jm_course_questions m join jm_questions q on q.id=m.question_id
   where m.course_id=? and q.verified=0 and m.subtopic_id is not null and not exists(select 1 from jm_question_deleted d where d.id=q.id)`).get(c) as Row).n;
  const unclassified=(db.prepare(`select count(*) n from jm_course_questions m join jm_questions q on q.id=m.question_id
   where m.course_id=? and q.verified=0 and m.subtopic_id is null and not exists(select 1 from jm_question_deleted d where d.id=q.id)`).get(c) as Row).n;
  const subjects=db.prepare(`select s.id subject_id,s.title subject_title,count(*) pending
   from jm_course_questions m
   join jm_questions q on q.id=m.question_id and q.verified=0 and not exists(select 1 from jm_question_deleted d where d.id=q.id)
   join jm_course_nodes l on l.id=m.subtopic_id
   join jm_course_nodes t on t.id=l.parent_id
   join jm_course_nodes s on s.id=t.parent_id
   where m.course_id=? group by s.id,s.title order by s.title`).all(c) as Row[];
  const topics=db.prepare(`select s.id subject_id,s.title subject_title,t.id topic_id,t.title topic_title,count(*) pending
   from jm_course_questions m
   join jm_questions q on q.id=m.question_id and q.verified=0 and not exists(select 1 from jm_question_deleted d where d.id=q.id)
   join jm_course_nodes l on l.id=m.subtopic_id
   join jm_course_nodes t on t.id=l.parent_id
   join jm_course_nodes s on s.id=t.parent_id
   where m.course_id=? group by s.id,s.title,t.id,t.title order by s.title,t.title`).all(c) as Row[];
  return {course_pending:pending,course_unclassified_pending:unclassified,subjects,topics};
 }

 if(p.action==='approve_many'){
  if(!p.ids.length||p.ids.length>500)throw Error('১–৫০০টি প্রশ্ন নির্বাচন করুন');
  const placeholders=p.ids.map(()=>'?').join(',');
  const info=db.prepare(`update jm_questions set verified=1 where id in(
   select m.question_id from jm_course_questions m join jm_questions q on q.id=m.question_id
   where m.course_id=? and m.question_id in(${placeholders}) and q.verified=0 and m.subtopic_id is not null)`).run(c,...p.ids);
  return {ok:true,approved:info.changes};
 }

 if(p.action==='approve_all'){
  let where='m.course_id=? and m.subtopic_id is not null';const args:unknown[]=[c];
  if(p.subtopic_id){where+=' and m.subtopic_id=?';args.push(p.subtopic_id);}
  if(p.topic_id){where+=' and l.parent_id=?';args.push(p.topic_id);}
  if(p.subject_id){where+=' and t.parent_id=?';args.push(p.subject_id);}
  const info=db.prepare(`update jm_questions set verified=1 where id in(
   select m.question_id from jm_course_questions m
   join jm_questions q on q.id=m.question_id and q.verified=0 and not exists(select 1 from jm_question_deleted d where d.id=q.id)
   left join jm_course_nodes l on l.id=m.subtopic_id
   left join jm_course_nodes t on t.id=l.parent_id
   where ${where})`).run(...args);
  return {ok:true,approved:info.changes};
 }
 throw Error('Unknown action');
}
