import {sqlImportAction,type SqlImportRow} from './live-exam-validation';
/**
 * Deliberately NOT a SQL executor. The uploaded .sql file is parsed as a constrained,
 * documented "JSON row per INSERT value" template and never sent to Postgres as SQL text.
 * Only `INSERT INTO jobmaster_sql_import (row) VALUES ('<json>'::jsonb), (...);` is accepted.
 * Any other statement (DROP/UPDATE/DELETE/multiple statements/functions/etc.) is rejected.
 */
export function parseSqlImportFile(sql:string):Record<string,unknown>[]{
 if(new TextEncoder().encode(sql).length>5_000_000)throw Error('SQL ফাইল সর্বোচ্চ 5 MB');
 const clean=sql.replace(/^\s*--[^\n]*(?:\n|$)/gm,'').trim();
 const head=/^INSERT\s+INTO\s+jobmaster_sql_import\s*\(\s*row\s*\)\s*VALUES\s*/i.exec(clean);
 if(!head)throw Error("শুধুমাত্র INSERT INTO jobmaster_sql_import (row) VALUES ('JSON'::jsonb); টেমপ্লেট গ্রহণযোগ্য। Arbitrary SQL কখনো execute করা হয় না।");
 let rest=clean.slice(head[0].length);const rows:Record<string,unknown>[]=[];
 while(true){
  const m=/^\(\s*'((?:[^']|'')*)'\s*::\s*jsonb\s*\)\s*/i.exec(rest);
  if(!m)throw Error('Invalid row syntax। প্রতিটি row অবশ্যই (\'JSON\'::jsonb) আকারে হতে হবে।');
  let row:unknown;
  try{row=JSON.parse(m[1].replace(/''/g,"'"));}catch{throw Error('Invalid JSON ভেতরে row-এ');}
  if(!row||typeof row!=='object'||Array.isArray(row))throw Error('প্রতিটি row একটি question object হতে হবে');
  rows.push(row as Record<string,unknown>);
  if(rows.length>20000)throw Error('একটি file-এ সর্বোচ্চ ২০,০০০ row');
  rest=rest.slice(m[0].length);
  if(rest===';'||rest==='')break;
  if(!rest.startsWith(','))throw Error('একাধিক statement / arbitrary SQL গ্রহণযোগ্য নয়');
  rest=rest.slice(1).trimStart();
 }
 return rows;
}
export const sqlImportTemplate=()=>`-- JobMaster BD Super Admin SQL Import. Parsed as JSON rows; never executed as SQL.
-- status: pending | approved | live_scheduled (live_scheduled needs exam_date, format YYYY-MM-DD)
INSERT INTO jobmaster_sql_import (row) VALUES
('${JSON.stringify({status:'pending',track:'BCS',subject:'বাংলা ব্যাকরণ',topic:'সন্ধি',difficulty:'standard',q:'এখানে প্রশ্ন লিখুন?',o:['প্রথম বিকল্প','দ্বিতীয় বিকল্প','তৃতীয় বিকল্প','চতুর্থ বিকল্প'],a:0,e:'সম্পূর্ণ ব্যাখ্যা এখানে লিখুন'}).replace(/'/g,"''")}'::jsonb),
('${JSON.stringify({status:'live_scheduled',track:'BCS',subject:'বাংলাদেশ বিষয়াবলি',topic:'মুক্তিযুদ্ধ',difficulty:'standard',q:'এখানে আরেকটি প্রশ্ন লিখুন?',o:['ক','খ','গ','ঘ'],a:1,e:'ব্যাখ্যা লিখুন',exam_date:'2026-12-01'}).replace(/'/g,"''")}'::jsonb);
`;
export type {SqlImportRow};
export {sqlImportAction};
