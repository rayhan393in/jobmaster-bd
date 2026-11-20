import {db} from '@/lib/store';
export function classificationDb(){db.exec('create table if not exists jm_question_classification(question_id text primary key references jm_questions(id) on delete cascade,subtopic_id text not null)');return db;}
