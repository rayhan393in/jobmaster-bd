import {z} from 'zod';
const id=z.string().min(1).max(150),time=z.number().int().positive().max(8e15);
export const upgradeAction=z.discriminatedUnion('action',[
 z.object({action:z.literal('boot')}),z.object({action:z.literal('catalog')}),
 z.object({action:z.literal('category_save'),id:id.optional(),title:z.string().trim().min(2).max(100)}),
 z.object({action:z.literal('course_meta'),course_id:id,parent_id:id.nullable(),category_id:id.nullable()}),
 z.object({action:z.literal('question_delete'),course_id:id,id,restore:z.boolean().optional()}),
 z.object({action:z.literal('exams'),course_id:id.optional()}),
 z.object({action:z.literal('exam_save'),id:z.uuid().optional(),course_id:id,title:z.string().trim().min(3).max(200),kind:z.enum(['daily','weekly','mock']),starts:time,ends:time,minutes:z.number().int().min(1).max(240),marks:z.number().int().min(1).max(100),subtopic_id:id.optional(),occurrences:z.number().int().min(1).max(31).default(1)}),
 z.object({action:z.literal('exam_cancel'),id:z.uuid()}),
 z.object({action:z.literal('live_start'),id:z.uuid()}),
 z.object({action:z.literal('ai_authorize')})
]);
export type UpgradeAction=z.infer<typeof upgradeAction>;
/** Deliberately NOT a SQL executor. Only the documented JSON row INSERT format is accepted. */
export function parseQuestionSql(sql:string):Record<string,unknown>[] {
 if(new TextEncoder().encode(sql).length>3_000_000)throw Error('SQL maximum 3 MB');
 const clean=sql.replace(/^\s*--[^\n]*(?:\n|$)/gm,'').trim();
 const head=/^INSERT\s+INTO\s+jobmaster_import\s*\(\s*data\s*\)\s*VALUES\s*/i.exec(clean);
 if(!head)throw Error('Only INSERT INTO jobmaster_import (data) VALUES (\'JSON\'::jsonb); template is supported. Arbitrary SQL is never executed.');
 let rest=clean.slice(head[0].length),rows:Record<string,unknown>[]=[];
 while(true){const m=/^\(\s*'((?:[^']|'')*)'\s*::\s*jsonb\s*\)\s*/i.exec(rest);if(!m)throw Error('Invalid SQL JSON row');let q;try{q=JSON.parse(m[1].replace(/''/g,"'"));}catch{throw Error('Invalid JSON inside SQL row');}if(!q||typeof q!=='object'||Array.isArray(q))throw Error('SQL row must contain a question object');rows.push(q);if(rows.length>500)throw Error('Maximum 500 rows');rest=rest.slice(m[0].length);if(rest===';'||rest==='')break;if(!rest.startsWith(','))throw Error('Multiple statements / arbitrary SQL are not allowed');rest=rest.slice(1).trimStart();}
 return rows;
}
export const sqlTemplate=(row:unknown)=>`-- JobMaster V4 safe import. Parsed as data; never executed as SQL.\nINSERT INTO jobmaster_import (data) VALUES\n('${JSON.stringify(row).replace(/'/g,"''")} '::jsonb);\n`;
