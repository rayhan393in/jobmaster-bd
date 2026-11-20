import {NextRequest,NextResponse} from 'next/server';
import {cloudEnabled} from '@/lib/cloud/config';
import {cloudClient} from '@/lib/cloud/client';
import {makePdf,PdfSection} from '@/lib/pdf-document';
export const runtime='nodejs';export const dynamic='force-dynamic';export const maxDuration=60;
export async function GET(req:NextRequest){let apply=(r:NextResponse)=>r;try{
 const type=req.nextUrl.searchParams.get('type')||'routine',track=req.nextUrl.searchParams.get('track')==='EEE'?'EEE':'BCS';
 if(!['routine','result','smart-routine'].includes(type))return NextResponse.json({error:'Unknown PDF type'},{status:400});
 let data;
 if(cloudEnabled()){const c=cloudClient(req);apply=c.apply;const r=await c.client.rpc('jobmaster_action',{p:{action:'pdf',track}});if(r.error)return c.respond({error:r.error.message},r.error.message.includes('Unauthorized')?401:429);data=r.data;}
 else{const {user,rateLimit}=await import('@/lib/auth');const u=user(req);if(!u)return NextResponse.json({error:'লগইন করুন।'},{status:401});if(!rateLimit('pdf:'+u.id,8))return NextResponse.json({error:'কিছুক্ষণ পরে আবার PDF তৈরি করুন।'},{status:429});const {GET}=await import('@/lib/local/workspace');const r=await GET(req);if(!r.ok)return r;data=await r.json();}
 let title='',sections:PdfSection[]=[];
 if(type==='smart-routine'){
  const {GET}=await import('@/app/api/month-plan/route');const r=await GET(req);if(!r.ok)return r;const calendar=await r.json();
  title='BCS Smart Routine · ৩০ দিনের পরিকল্পনা';sections.push({title:'প্রস্তুতির নিয়ম',lines:['প্রতিদিন ৫ ঘণ্টা: মূল বিষয় ১২০ মিনিট + দ্বিতীয় বিষয় ১২০ মিনিট + revision ও ভুলের খাতা ৬০ মিনিট।','Daily পরীক্ষার প্রবেশসময় সন্ধ্যা ৭টা–রাত ১০টা; সর্বোচ্চ ৪০ মিনিট, রাত ১০টায় hard close। ফল প্রকাশ রাত ১০টায়। Weekly পরীক্ষার নিজস্ব সময় নিচে দেখুন।','এটি নিজস্ব প্রস্তুতি পরিকল্পনা, official BPSC syllabus নয়। প্রশ্ন review ও publish না হলে অংশ নেওয়া যাবে না।']});
  const time=(ms:number)=>new Date(ms).toLocaleTimeString('bn-BD',{timeZone:'Asia/Dhaka',hour:'numeric',minute:'2-digit'});
  for(const p of calendar.plans||[])sections.push({title:`${p.date} · ${p.title}`,lines:[`বিষয় ও টপিক: ${p.topics}`,`প্রবেশসময়: ${time(p.starts)}–${time(p.ends)} · সময়: ${p.duration/60} মিনিট · নম্বর: ${p.marks}`,`ফল প্রকাশ: ${time(p.publish)} · ${p.exam_id?'প্রকাশিত প্রশ্নপত্র':'প্রশ্ন প্রস্তুতি / প্রকাশ বাকি'}`,'গাইডলাইন: তালিকার প্রতিটি টপিকের ধারণা পড়ুন → উদাহরণ সমাধান করুন → আগের ভুলগুলো revision দিন → পরীক্ষার পরে ব্যাখ্যা মিলিয়ে ভুলের খাতা আপডেট করুন।']});
 }else if(type==='result'){
  title='পরীক্ষার ফলাফল প্রতিবেদন';sections=(data.results||[]).map((r:{created:string,score:number,total:number,correct:number,answered:number})=>({title:new Date(r.created).toLocaleString('bn-BD',{timeZone:'Asia/Dhaka'}),lines:[`নম্বর ${r.score}/${r.total} · সঠিক ${r.correct} · ভুল ${r.answered-r.correct} · অনুত্তরিত ${r.total-r.answered}`]}));
 }else{title='আপনার ব্যক্তিগত স্টাডি রুটিন';sections=(data.tasks||[]).map((t:{subject:string,title:string,minutes:number,done:number})=>({title:t.subject,lines:[t.title,`${t.minutes} মিনিট · ${t.done?'সম্পন্ন':'বাকি'}`]}));}
 if(!sections.length)sections=[{title:'এখনও কোনো তথ্য নেই',lines:['আপনার সংরক্ষিত তথ্য পাওয়া গেলে এই প্রতিবেদনে দেখানো হবে।']}];
 const pdf=await makePdf(title,`${data.user?.name||'শিক্ষার্থী'} · ${track} · বাংলাদেশ সময় ${new Date().toLocaleString('bn-BD',{timeZone:'Asia/Dhaka'})}`,sections);
 return apply(new NextResponse(new Uint8Array(pdf),{headers:{'Content-Type':'application/pdf','Content-Disposition':`attachment; filename="JobMaster-${type}-${track}.pdf"`,'Cache-Control':'private, no-store'}}));
 }catch(e){console.error('PDF generation failed',e);return apply(NextResponse.json({error:'PDF তৈরি হয়নি। Server log-এ font/package configuration পরীক্ষা করুন।'},{status:500}));}}
