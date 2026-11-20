import {NextRequest,NextResponse} from 'next/server';
import {cloudEnabled} from '@/lib/cloud/config';
import {cloudClient} from '@/lib/cloud/client';
import {makePdf,PdfSection} from '@/lib/pdf-document';
export const runtime='nodejs';export const dynamic='force-dynamic';export const maxDuration=60;
type Q={q:string,o:string[],a?:number,e?:string};
export async function GET(req:NextRequest){try{
 const id=req.nextUrl.searchParams.get('attempt');if(!id||id.length>100)return NextResponse.json({error:'Attempt ID required'},{status:400});
 const includeAnswers=req.nextUrl.searchParams.get('answers')==='1';let data;let apply=(r:NextResponse)=>r;
 if(cloudEnabled()){const c=cloudClient(req);apply=c.apply;const check=await c.client.rpc('jobmaster_action',{p:{action:'pdf',track:'BCS'}});if(check.error)return c.respond({error:check.error.message},check.error.message.includes('Unauthorized')?401:429);const r=await c.client.rpc('jobmaster_action',{p:{action:'attempt',id}});if(r.error)return c.respond({error:r.error.message},404);data=r.data;}
 else{const {user,rateLimit}=await import('@/lib/auth');const u=user(req);if(!u)return NextResponse.json({error:'Unauthorized'},{status:401});if(!rateLimit('pdf:'+u.id,8))return NextResponse.json({error:'Please wait before creating another PDF'},{status:429});const {GET}=await import('@/lib/local/workspace');const url=new URL(req.url);url.searchParams.set('attempt',id);const r=await GET(new NextRequest(url,{headers:req.headers}));if(!r.ok)return r;data=await r.json();}
 if(includeAnswers&&(!data.submitted||!data.review||!data.result))return apply(NextResponse.json({error:'ফলাফল প্রকাশের আগে উত্তরপত্র পাওয়া যাবে না।'},{status:403}));
 const qs:Q[]=includeAnswers?data.review:data.questions;const answers:Record<number,number>={};for(const a of data.answers||[])answers[a.question]=a.choice;
 const result=data.result;const sections:PdfSection[]=[];
 if(includeAnswers)sections.push({title:'ফলাফলের সারাংশ',lines:[`নম্বর ${result.score}/${result.total} · সঠিক ${result.correct} · ভুল ${result.answered-result.correct} · অনুত্তরিত ${result.total-result.answered}`,'সঠিক × ১ − ভুল × ০.৫']});
 qs.forEach((q,i)=>sections.push({title:`${i+1}. ${q.q}`,lines:[...q.o.map((o,c)=>`${'ABCD'[c]}. ${o}`),...(includeAnswers?[`আপনার উত্তর: ${answers[i]===undefined?'অনুত্তরিত':q.o[answers[i]]}`,`সঠিক উত্তর: ${q.o[q.a!]}`,`ব্যাখ্যা: ${q.e||''}`]:[])]}));
 const pdf=await makePdf(includeAnswers?'ফলাফল, উত্তরপত্র ও ব্যাখ্যা':'পরীক্ষার প্রশ্নপত্র',`Attempt: ${id} · ${qs.length} প্রশ্ন`,sections);
 return apply(new NextResponse(new Uint8Array(pdf),{headers:{'Content-Type':'application/pdf','Content-Disposition':`attachment; filename="JobMaster-${includeAnswers?'Answers':'Questions'}.pdf"`,'Cache-Control':'private, no-store'}}));
 }catch(e){console.error('Exam PDF failed',e);return NextResponse.json({error:'PDF তৈরি হয়নি। Server font/package configuration পরীক্ষা করুন।'},{status:500});}}
