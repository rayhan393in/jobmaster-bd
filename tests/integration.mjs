import assert from 'node:assert/strict';
import Database from 'better-sqlite3';
import fs from 'node:fs';
const base='http://127.0.0.1:3000';const db=new Database('jobmaster.sqlite');let checks=0;const check=(v,m)=>{assert.ok(v,m);checks++;console.log('PASS',m);};
function client(){let cookie='';return async(path,b)=>{const r=await fetch(base+path,{method:b?'POST':'GET',headers:{...(b?{'Content-Type':'application/json'}:{}),...(cookie?{cookie}:{})},body:b?JSON.stringify(b):undefined});const c=r.headers.get('set-cookie');if(c)cookie=c.split(';')[0];return {status:r.status,data:r.headers.get('content-type')?.includes('application/json')?await r.json():Buffer.from(await r.arrayBuffer()),headers:r.headers};};}
const a=client(),b=client(),anon=client();const suffix=Date.now();const emails=[`test-a-${suffix}@example.test`,`test-b-${suffix}@example.test`];
try{
check((await anon('/api/workspace')).status===401,'Anonymous workspace rejected');check((await anon('/api/admin')).status===403,'Anonymous admin rejected');
for(const [i,c] of [a,b].entries()){const r=await c('/api/auth',{action:'register',name:'Test Student '+i,email:emails[i],password:'Strong-pass-2026!'});check(r.status===200,'Registration '+i);}
check((await a('/api/auth')).data.user.email===emails[0],'Authenticated profile');
check((await b('/api/admin')).status===403,'Student admin API rejected');
check((await a('/api/workspace',{action:'routine',track:'BCS',minutes:45})).status===200,'Routine generation');
const wa=(await a('/api/workspace?track=BCS')).data,wb=(await b('/api/workspace?track=BCS')).data;check(wa.tasks.length===3&&wb.tasks.length===0,'User routine isolation');
await b('/api/workspace',{action:'toggle',id:wa.tasks[0].id});check(!(await a('/api/workspace?track=BCS')).data.tasks[0].done,'Foreign task mutation prevented');
check((await a('/api/workspace?track=EEE')).data.tasks.length===0,'Track routine isolation');
const outline=(await a('/api/syllabus?track=BCS')).data;check(outline.subjects.length===10&&outline.status==='editorial-study-outline-not-official','BCS editorial outline labeled honestly');check((await a('/api/syllabus?track=EEE')).data.subjects.length===15,'EEE fifteen-subject outline');await a('/api/syllabus',{topicId:'BCS:bangla:0:0',done:true});check((await a('/api/syllabus')).data.progress.some(p=>p.done),'Topic completion saved');check((await b('/api/syllabus')).data.progress.length===0,'Topic progress user isolation');check((await a('/api/syllabus',{topicId:'invalid',done:true})).status===400,'Unknown topic rejected');
const id=(await a('/api/workspace',{action:'start',track:'BCS',count:30})).data.id;
const s=(await a('/api/workspace?attempt='+id)).data;check(s.questions.length===30,'Thirty BCS questions');check(s.questions.every(q=>q.a===undefined&&q.e===undefined),'Answer keys hidden');
check((await b('/api/workspace?attempt='+id)).status===404,'Foreign attempt read prevented');check((await b('/api/workspace',{action:'submit',id})).status===404,'Foreign submission prevented');
const snap=JSON.parse(db.prepare('SELECT snapshot FROM jm_sessions WHERE id=?').get(id).snapshot);
await a('/api/workspace',{action:'answer',id,question:0,choice:snap[0].a});await a('/api/workspace',{action:'answer',id,question:1,choice:(snap[1].a+1)%4});
check((await a('/api/workspace?attempt='+id)).data.answers.length===2,'Answer persistence / resume');
const r=(await a('/api/workspace',{action:'submit',id})).data;check(r.result.score===.5&&r.result.correct===1,'Correct scoring and negative mark');
check(JSON.stringify((await a('/api/workspace',{action:'submit',id})).data.result)===JSON.stringify(r.result),'Idempotent submission');
check((await a('/api/workspace',{action:'answer',id,question:2,choice:0})).status===409,'Post-submission lock');
const eid=(await a('/api/workspace',{action:'start',track:'EEE'})).data.id;const es=(await a('/api/workspace?attempt='+eid)).data;check(es.questions.length===30,'Thirty EEE questions');
const eSnap=JSON.parse(db.prepare('SELECT snapshot FROM jm_sessions WHERE id=?').get(eid).snapshot);check(eSnap.every(q=>q.track==='EEE'),'EEE content isolated');
db.prepare('UPDATE jm_sessions SET deadline=? WHERE id=?').run(Date.now()-100,eid);await new Promise(resolve=>setTimeout(resolve,1600));check(db.prepare('SELECT submitted FROM jm_sessions WHERE id=?').get(eid).submitted===1,'Expired attempt finalized without browser request');
await a('/api/workspace',{action:'bookmark',questionId:snap[0].id});const bm=(await a('/api/workspace',{action:'start',track:'BCS',mode:'bookmarked'})).data.id;check((await a('/api/workspace?attempt='+bm)).data.questions.length===1,'Bookmark practice');
const wrong=(await a('/api/workspace',{action:'start',track:'BCS',mode:'incorrect'})).data.id;check((await a('/api/workspace?attempt='+wrong)).data.questions.length===1,'Incorrect question revision');
const pdf=await a('/api/pdf?type=routine&track=BCS');check(pdf.status===200&&pdf.data.subarray(0,4).toString()==='%PDF','Real downloadable routine PDF');fs.mkdirSync('tests/artifacts',{recursive:true});fs.writeFileSync('tests/artifacts/routine.pdf',pdf.data);
const rp=await a('/api/pdf?type=result&track=BCS');check(rp.status===200&&rp.data.subarray(0,4).toString()==='%PDF','Real downloadable result PDF');
db.prepare("UPDATE jm_users SET role='admin' WHERE email=?").run(emails[0]);check((await a('/api/admin')).status===200,'Explicitly provisioned admin allowed');
const csv=fs.readFileSync('public/question-import-template.csv','utf8');const preview=(await a('/api/admin',{action:'preview',csv})).data;check(preview.rows.length===1&&!preview.rows[0].errors.length,'CSV preview validates');
const dup=await a('/api/admin',{action:'preview',csv:csv+csv.split('\n')[1]+'\n'});check(dup.data.rows[1].errors.includes('Duplicate question'),'In-file duplicate detection');
const badCsv=csv.replace('৯ গুণ ৯ সমান ৮১ বর্গমিটার।','৯ গুণ ৯ সমান ৮১ বর্গমিটার।').replace(',C,',',Z,');check((await a('/api/admin',{action:'import',csv:badCsv})).status===400,'Invalid import blocked');
const qids=db.prepare("SELECT id FROM jm_questions WHERE track='BCS' LIMIT 30").all().map(q=>q.id);for(const qid of qids)await a('/api/admin',{action:'verify',id:qid,verified:true});
let now=Date.now();const schedule=await a('/api/admin',{action:'schedule',title:'TEST ONLY scheduled exam',track:'BCS',starts:now+60000,ends:now+120000,publish:now+180000,duration:60,count:30});check(schedule.status===200,'Verified question exam scheduling');
const exam=db.prepare("SELECT id FROM jm_exams WHERE title='TEST ONLY scheduled exam'").get();check((await b('/api/workspace',{action:'start',track:'BCS',examId:exam.id})).status===409,'Early exam start blocked');
db.prepare('UPDATE jm_exams SET starts=? WHERE id=?').run(Date.now()-100,exam.id);const live=(await b('/api/workspace',{action:'start',track:'BCS',examId:exam.id})).data.id;check(!!live,'Exam starts within server window');
check((await b('/api/workspace',{action:'start',track:'BCS',examId:exam.id})).data.id===live,'One scheduled attempt per student');
const hidden=(await b('/api/workspace',{action:'submit',id:live})).data;check(hidden.pending&&!hidden.result&&!hidden.review.length,'Result embargo enforced');
check((await b('/api/workspace?attempt='+live)).data.review===undefined,'Review embargo enforced on GET');
check((await b('/api/leaderboard?exam='+exam.id)).data.pending,'Leaderboard embargo');
db.prepare('UPDATE jm_exams SET publish=? WHERE id=?').run(Date.now()-100,exam.id);check((await b('/api/leaderboard?exam='+exam.id)).data.rows.length===1,'Real published leaderboard');
await b('/api/auth',{action:'logout'});check((await b('/api/workspace')).status===401,'Logout invalidates session');
console.log(`\n${checks} integration checks passed.`);
fs.writeFileSync('tests/latest-results.json',JSON.stringify({date:new Date().toISOString(),passed:checks},null,2));
}finally{
// Remove only test accounts and their associated records, never actual student data.
for(const email of emails){const u=db.prepare('SELECT id FROM jm_users WHERE email=?').get(email);if(!u)continue;const ids=db.prepare('SELECT id FROM jm_sessions WHERE user_id=?').all(u.id);for(const s of ids)db.prepare('DELETE FROM jm_answers WHERE session_id=?').run(s.id);db.prepare('DELETE FROM jm_sessions WHERE user_id=?').run(u.id);for(const table of ['jm_tasks','jm_auth','jm_bookmarks','jm_progress'])db.prepare(`DELETE FROM ${table} WHERE user_id=?`).run(u.id);db.prepare('DELETE FROM jm_users WHERE id=?').run(u.id);}db.prepare("DELETE FROM jm_exams WHERE title='TEST ONLY scheduled exam'").run();db.prepare("UPDATE jm_questions SET verified=0 WHERE id LIKE 'original-%'").run();
}
