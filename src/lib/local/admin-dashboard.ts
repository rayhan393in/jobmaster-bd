import {db} from '@/lib/store';
import {courseDb} from '@/lib/local/courses';
import {liveDb,expireOverdueLive} from '@/lib/local/live';
import {isSuperAdmin} from '@/lib/local/sql-import';
type Row=Record<string,any>;

export function localAdminDashboard(uid:string,admin:boolean){
 if(!admin)throw Error('Admin access required');
 courseDb();liveDb();expireOverdueLive();
 const today=new Intl.DateTimeFormat('en-CA',{timeZone:'Asia/Dhaka',year:'numeric',month:'2-digit',day:'2-digit'}).format(Date.now());
 return {
  total_questions:(db.prepare('select count(*) n from jm_questions q where not exists(select 1 from jm_question_deleted d where d.id=q.id)').get() as Row).n,
  pending_questions:(db.prepare('select count(*) n from jm_questions q where q.verified=0 and not exists(select 1 from jm_question_deleted d where d.id=q.id)').get() as Row).n,
  approved_questions:(db.prepare('select count(*) n from jm_questions q where q.verified=1 and not exists(select 1 from jm_question_deleted d where d.id=q.id)').get() as Row).n,
  live_exam_questions:(db.prepare('select count(*) n from jm_live_exam_questions').get() as Row).n,
  scheduled_questions:(db.prepare('select count(*) n from jm_live_exam_questions where exam_date>=?').get(today) as Row).n,
  total_subjects:(db.prepare("select count(*) n from jm_course_nodes where level='subject'").get() as Row).n,
  total_topics:(db.prepare("select count(*) n from jm_course_nodes where level='topic'").get() as Row).n,
  today_participants:(db.prepare('select count(*) n from jm_live_exam_attempts where exam_date=?').get(today) as Row).n,
  today_results:(db.prepare('select count(*) n from jm_live_exam_attempts where exam_date=? and submitted=1').get(today) as Row).n,
  is_super_admin:isSuperAdmin(uid)
 };
}
