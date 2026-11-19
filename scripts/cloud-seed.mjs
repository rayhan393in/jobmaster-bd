import ts from 'typescript';import fs from 'node:fs';import vm from 'node:vm';
function load(p){const code=ts.transpileModule(fs.readFileSync(p,'utf8'),{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2020}}).outputText;const box={exports:{}};vm.runInNewContext(code,box);return box.exports;}
const {seedQuestions}=load('src/lib/catalog.ts'),{studySyllabus}=load('src/lib/syllabus.ts');const sql=v=>"'"+v.replaceAll("'","''")+"'";
let out='-- 60 AI-assisted practice questions; NOT verified previous papers.\nbegin;\n';
for(const q of seedQuestions)out+=`insert into jobmaster_private.questions(id,data,fingerprint) values(${sql(q.id)},${sql(JSON.stringify(q))}::jsonb,jobmaster_private.fingerprint(${sql(q.q)})) on conflict do nothing;\n`;
for(const [track,ss] of Object.entries(studySyllabus))for(const s of ss)for(const [ci,c] of s.chapters.entries())for(const [ti] of c.topics.entries())out+=`insert into jobmaster_private.topics values(${sql(`${track}:${s.id}:${ci}:${ti}`)}) on conflict do nothing;\n`;
out+='commit;\n';fs.writeFileSync('supabase/migrations/002_practice_seed.sql',out);
// Single copy/paste file for a new project. Separate files retained for versioning.
fs.mkdirSync('deployment',{recursive:true});fs.writeFileSync('deployment/STEP-5-SUPABASE.sql',fs.readFileSync('supabase/migrations/001_cloud_backend.sql','utf8')+'\n'+out);
console.log('Generated schema + 60 labeled questions + topic IDs. No user data included.');
