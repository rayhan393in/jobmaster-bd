import db from './db';
import {seedQuestions,Question} from './catalog';
import {createHash} from 'crypto';
db.pragma('foreign_keys = ON');
db.exec(`
CREATE TABLE IF NOT EXISTS jm_users(id TEXT PRIMARY KEY,email TEXT UNIQUE NOT NULL,name TEXT NOT NULL,password TEXT NOT NULL,role TEXT NOT NULL DEFAULT 'student',created INTEGER NOT NULL);
CREATE TABLE IF NOT EXISTS jm_auth(token TEXT PRIMARY KEY,user_id TEXT NOT NULL REFERENCES jm_users(id),expires INTEGER NOT NULL);
CREATE TABLE IF NOT EXISTS jm_tasks(id TEXT PRIMARY KEY,user_id TEXT NOT NULL REFERENCES jm_users(id),title TEXT NOT NULL,subject TEXT NOT NULL,minutes INTEGER NOT NULL,done INTEGER DEFAULT 0,track TEXT NOT NULL);
CREATE TABLE IF NOT EXISTS jm_questions(id TEXT PRIMARY KEY,track TEXT NOT NULL,subject TEXT NOT NULL,body TEXT NOT NULL,options TEXT NOT NULL,answer INTEGER NOT NULL,explanation TEXT NOT NULL,source TEXT NOT NULL,kind TEXT NOT NULL,fingerprint TEXT UNIQUE NOT NULL,verified INTEGER DEFAULT 0);
CREATE TABLE IF NOT EXISTS jm_question_deleted(id TEXT PRIMARY KEY REFERENCES jm_questions(id),actor TEXT,created INTEGER);
CREATE INDEX IF NOT EXISTS jm_q_track ON jm_questions(track,subject,verified);
CREATE TABLE IF NOT EXISTS jm_sessions(id TEXT PRIMARY KEY,user_id TEXT NOT NULL REFERENCES jm_users(id),track TEXT NOT NULL,started INTEGER NOT NULL,deadline INTEGER NOT NULL,submitted INTEGER DEFAULT 0,snapshot TEXT NOT NULL,score REAL,correct INTEGER,answered INTEGER,exam_id TEXT);
CREATE INDEX IF NOT EXISTS jm_s_user ON jm_sessions(user_id,submitted);
CREATE TABLE IF NOT EXISTS jm_answers(session_id TEXT REFERENCES jm_sessions(id),question INTEGER,choice INTEGER,PRIMARY KEY(session_id,question));
CREATE TABLE IF NOT EXISTS jm_exams(id TEXT PRIMARY KEY,title TEXT NOT NULL,track TEXT NOT NULL,starts INTEGER NOT NULL,ends INTEGER NOT NULL,publish INTEGER NOT NULL,duration INTEGER NOT NULL,question_ids TEXT NOT NULL);
CREATE UNIQUE INDEX IF NOT EXISTS jm_unique_exam ON jm_sessions(user_id,exam_id) WHERE exam_id IS NOT NULL;
CREATE TABLE IF NOT EXISTS jm_bookmarks(user_id TEXT REFERENCES jm_users(id),question_id TEXT REFERENCES jm_questions(id),PRIMARY KEY(user_id,question_id));
CREATE TABLE IF NOT EXISTS jm_limits(key TEXT PRIMARY KEY,count INTEGER,reset INTEGER);
`);
export const fingerprint=(q:string)=>createHash('sha256').update(q.normalize('NFKC').toLowerCase().replace(/[^\p{L}\p{N}]/gu,'')).digest('hex');
const insert=db.prepare('INSERT OR IGNORE INTO jm_questions VALUES(?,?,?,?,?,?,?,?,?,?,0)');
for(const q of seedQuestions)insert.run(q.id,q.track,q.subject,q.q,JSON.stringify(q.o),q.a,q.e,q.source,q.kind,fingerprint(q.q));
export function questionRows(track:string):Question[]{return (db.prepare('SELECT * FROM jm_questions WHERE track=? AND NOT EXISTS(SELECT 1 FROM jm_question_deleted d WHERE d.id=jm_questions.id) ORDER BY id').all(track) as {id:string,track:string,subject:string,body:string,options:string,answer:number,explanation:string,source:string,kind:string}[]).map(r=>({id:r.id,q:r.body,o:JSON.parse(r.options),a:r.answer,e:r.explanation,track:r.track,subject:r.subject,source:r.source,kind:r.kind}));}
export type Session={id:string,user_id:string,track:string,started:number,deadline:number,submitted:number,snapshot:string,score:number,correct:number,answered:number,exam_id:string|null};
export function finish(id:string){return db.transaction(()=>{const s=db.prepare('SELECT * FROM jm_sessions WHERE id=?').get(id) as Session;if(s.submitted)return s;const qs=JSON.parse(s.snapshot) as Question[];const rows=db.prepare('SELECT question,choice FROM jm_answers WHERE session_id=?').all(id) as {question:number,choice:number}[];const correct=rows.filter(r=>qs[r.question]?.a===r.choice).length;db.prepare('UPDATE jm_sessions SET submitted=1,score=?,correct=?,answered=? WHERE id=?').run(correct-(rows.length-correct)*.5,correct,rows.length,id);return db.prepare('SELECT * FROM jm_sessions WHERE id=?').get(id) as Session;})();}
export function finalizeOverdue(){const rows=db.prepare('SELECT id FROM jm_sessions WHERE submitted=0 AND deadline<=?').all(Date.now()) as {id:string}[];for(const r of rows)finish(r.id);}
export {db};
