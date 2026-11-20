import {NextRequest,NextResponse} from 'next/server';
import {cloudEnabled} from '@/lib/cloud/config';
import {cloudClient} from '@/lib/cloud/client';
export const runtime='nodejs';export const dynamic='force-dynamic';
export async function GET(req:NextRequest){try{
 const track=req.nextUrl.searchParams.get('track')==='EEE'?'EEE':'BCS';const requested=req.nextUrl.searchParams.get('exam');
 if(cloudEnabled()){
  const c=cloudClient(req);let id=requested;
  if(!id){const w=await c.client.rpc('jobmaster_action',{p:{action:'workspace',track}});if(w.error)return c.respond({error:w.error.message},w.error.message.includes('Unauthorized')?401:400);id=(w.data.exams||[]).filter((e:{publish:number})=>e.publish<=Date.now()).sort((a:{publish:number},b:{publish:number})=>b.publish-a.publish)[0]?.id;}
  if(!id)return c.respond({rows:[],now:Date.now()});
  const r=await c.client.rpc('jobmaster_action',{p:{action:'leaderboard',exam:id}});if(r.error)return c.respond({error:r.error.message},r.error.message.includes('Unauthorized')?401:400);
  return c.respond({...r.data,examId:id,now:Date.now(),rows:(r.data.rows||[]).slice(0,5).map((x:object,i:number)=>({...x,rank:i+1}))});
 }
 const {user}=await import('@/lib/auth');if(!user(req))return NextResponse.json({error:'Unauthorized'},{status:401});const {db,finalizeOverdue}=await import('@/lib/store');finalizeOverdue();
 const exam=(requested?db.prepare('SELECT id,title,publish FROM jm_exams WHERE id=?').get(requested):db.prepare('SELECT id,title,publish FROM jm_exams WHERE track=? AND publish<=? ORDER BY publish DESC LIMIT 1').get(track,Date.now())) as {id:string,title:string,publish:number}|undefined;
 if(!exam)return NextResponse.json({rows:[],now:Date.now()});if(Date.now()<exam.publish)return NextResponse.json({rows:[],pending:true,now:Date.now()});
 const rows=(db.prepare('SELECT u.name,s.score,s.correct,s.started FROM jm_sessions s JOIN jm_users u ON u.id=s.user_id WHERE s.exam_id=? AND s.submitted=1 ORDER BY s.score DESC,s.started ASC,s.id ASC LIMIT 5').all(exam.id) as object[]).map((x,i)=>({...x,rank:i+1}));
 return NextResponse.json({title:exam.title,examId:exam.id,rows,now:Date.now()},{headers:{'Cache-Control':'private, no-store'}});
 }catch(e){return NextResponse.json({error:(e as Error).message},{status:503});}}
