import {z} from 'zod';
export const liveExamAction=z.discriminatedUnion('action',[
 z.object({action:z.literal('status')}),
 z.object({action:z.literal('start')}),
 z.object({action:z.literal('state'),id:z.uuid()}),
 z.object({action:z.literal('answer'),id:z.uuid(),question:z.number().int().min(0).max(199),choice:z.number().int().min(0).max(3)}),
 z.object({action:z.literal('submit'),id:z.uuid()}),
 z.object({action:z.literal('config_get')}),
 z.object({action:z.literal('config_save'),start_minute:z.number().int().min(0).max(1439),end_minute:z.number().int().min(1).max(1440),duration_seconds:z.number().int().min(60).max(7200),total_questions:z.number().int().min(1).max(200),negative_mark:z.number().min(0).max(1),track:z.enum(['BCS','EEE'])}),
 z.object({action:z.literal('bank_list'),exam_date:z.string().optional()}),
 z.object({action:z.literal('bank_delete'),id:z.string().min(1).max(150)}),
 z.object({action:z.literal('bank_import'),rows:z.array(z.object({track:z.enum(['BCS','EEE']).optional(),subject:z.string().trim().min(1).max(150),topic:z.string().trim().min(1).max(150),difficulty:z.enum(['easy','standard','hard']).optional(),q:z.string().trim().min(8).max(4000),o:z.array(z.string().trim().min(1).max(1000)).length(4),a:z.number().int().min(0).max(3),e:z.string().trim().min(8).max(6000),exam_date:z.string().min(8).max(10)})).min(1).max(1000)}),
 z.object({action:z.literal('today_summary')})
]);
export type LiveExamAction=z.infer<typeof liveExamAction>;

export const approvalsAction=z.discriminatedUnion('action',[
 z.object({action:z.literal('pending_summary'),course_id:z.string().min(1).max(150)}),
 z.object({action:z.literal('approve_many'),course_id:z.string().min(1).max(150),ids:z.array(z.string().min(1).max(150)).min(1).max(500)}),
 z.object({action:z.literal('approve_all'),course_id:z.string().min(1).max(150),subject_id:z.string().max(150).optional(),topic_id:z.string().max(150).optional(),subtopic_id:z.string().max(150).optional()})
]);
export type ApprovalsAction=z.infer<typeof approvalsAction>;

const sqlImportRow=z.object({
 status:z.enum(['pending','approved','live_scheduled']).default('pending'),
 track:z.enum(['BCS','EEE']).default('BCS'),
 subject:z.string().trim().max(150).optional(),
 topic:z.string().trim().max(150).optional(),
 difficulty:z.enum(['easy','standard','hard']).default('standard'),
 q:z.string().trim().min(8).max(4000),
 o:z.array(z.string().trim().min(1).max(1000)).length(4),
 a:z.number().int().min(0).max(3),
 e:z.string().trim().min(8).max(6000),
 exam_date:z.string().min(8).max(10).optional()
}).refine(r=>r.status!=='live_scheduled'||!!r.exam_date,'live_scheduled status requires exam_date');
export const sqlImportAction=z.discriminatedUnion('action',[
 z.object({action:z.literal('fingerprints')}),
 z.object({action:z.literal('commit'),rows:z.array(sqlImportRow).min(1).max(500)})
]);
export type SqlImportAction=z.infer<typeof sqlImportAction>;
export type SqlImportRow=z.infer<typeof sqlImportRow>;
