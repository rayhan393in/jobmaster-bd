import {z} from 'zod';
export const courseQuestion=z.object({q:z.string().trim().min(8).max(4000),o:z.array(z.string().trim().min(1).max(1000)).length(4),a:z.number().int().min(0).max(3),e:z.string().trim().min(8).max(6000),kind:z.enum(['original','ai_generated','previous']),source:z.string().trim().min(3).max(1000),subtopic_id:z.string().min(1).max(150),source_metadata:z.record(z.string(),z.unknown()).optional(),batch:z.string().max(150).optional(),difficulty:z.enum(['easy','standard','hard']).optional()}).refine(q=>new Set(q.o.map(x=>x.toLowerCase())).size===4,'Four distinct options required').refine(q=>q.kind!=='previous'||q.source.startsWith('https://'),'Previous question requires HTTPS source');
const id=z.string().min(1).max(150),text=z.string().trim();
export const courseAction=z.discriminatedUnion('action',[
 z.object({action:z.literal('boot')}),z.object({action:z.literal('catalog')}),
 z.object({action:z.literal('start'),course_id:id,subject_id:id.optional(),topic_id:id.optional(),subtopic_id:id.optional(),count:z.number().int().min(1).max(100),minutes:z.number().int().min(1).max(180)}),
 z.object({action:z.literal('course_save'),id:id.optional(),title:text.min(2).max(150),description:text.max(4000),circular_url:z.union([z.literal(''),z.url().startsWith('https://')]),status:z.enum(['draft','published','archived']),legacy_track:z.enum(['BCS','EEE'])}),
 z.object({action:z.literal('node_save'),id:id.optional(),course_id:id,parent_id:id.nullable(),level:z.enum(['subject','topic','subtopic']),title:text.min(1).max(150)}),
 z.object({action:z.literal('questions'),workspace_both:z.boolean().optional(),course_id:id.optional(),subject_id:id.optional(),topic_id:id.optional(),subtopic_id:id.optional(),unclassified:z.boolean().optional(),search:text.max(200).optional(),status:z.enum(['all','draft','approved']).optional(),page:z.number().int().min(1).max(100000).optional()}),
 z.object({action:z.literal('verify'),course_id:id,id,verified:z.boolean()}),
 z.object({action:z.literal('assign'),course_id:id,id,subtopic_id:id}),
 z.object({action:z.literal('link'),course_id:id,id,subtopic_id:id}),
 z.object({action:z.literal('question_save'),course_id:id,id:id.optional(),question:courseQuestion}),
 z.object({action:z.literal('import'),course_id:id,questions:z.array(courseQuestion).min(1).max(500)}),
 z.object({action:z.literal('paper_generate'),course_id:id,title:text.min(3).max(200),minutes:z.number().int().min(1).max(180),selections:z.array(z.object({subtopic_id:id,count:z.number().int().min(1).max(100)})).min(1).max(30)}),
 z.object({action:z.literal('papers'),course_id:id}),z.object({action:z.literal('paper'),course_id:id,id})
]);
export type CourseAction=z.infer<typeof courseAction>;
