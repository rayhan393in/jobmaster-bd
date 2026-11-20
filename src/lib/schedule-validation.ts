import {z} from 'zod';
import {parseQuestionSql} from './upgrade-validation';
export const routineRow=z.object({id:z.uuid().optional(),course_id:z.string().min(1).max(150),title:z.string().trim().min(3).max(200),topics:z.string().trim().min(3).max(6000),kind:z.enum(['daily','weekly']),starts:z.number().int().positive(),ends:z.number().int().positive(),minutes:z.number().int().min(1).max(240),marks:z.number().int().min(1).max(100),published:z.boolean()}).refine(v=>v.ends>v.starts&&v.ends-v.starts<=86400000&&v.minutes*60000<=v.ends-v.starts,'Invalid exam window / duration');
export const scheduleAction=z.discriminatedUnion('action',[
 z.object({action:z.literal('calendar')}),
 z.object({action:z.literal('list'),course_id:z.string().min(1).max(150)}),
 z.object({action:z.literal('save'),row:routineRow}),
 z.object({action:z.literal('import'),rows:z.array(routineRow).min(1).max(100)}),
 z.object({action:z.literal('remove'),id:z.uuid(),restore:z.boolean().optional()}),
 z.object({action:z.literal('publish_exam'),id:z.uuid(),subtopic_id:z.string().min(1).max(150).optional()}),
 z.object({action:z.literal('cancel_exam'),id:z.uuid()})
]);
export type ScheduleAction=z.infer<typeof scheduleAction>;
export function parseRoutineSql(s:string){return parseQuestionSql(s.replace(/^(\s*(?:--[^\n]*\n\s*)*)INSERT\s+INTO\s+jobmaster_routine_import/i,'$1INSERT INTO jobmaster_import')).map(r=>routineRow.parse(r));}
export function routineSql(rows:unknown[]){return '-- JobMaster routine DATA template; parsed, not executed.\nINSERT INTO jobmaster_routine_import (data) VALUES\n'+rows.map(r=>"('"+JSON.stringify(r).replace(/'/g,"''")+"'::jsonb)").join(',\n')+';\n';}
