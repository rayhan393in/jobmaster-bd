import {NextRequest,NextResponse} from 'next/server';
import {cloudEnabled} from '@/lib/cloud/config';
import {cloudClient,validOrigin} from '@/lib/cloud/client';
import Papa from 'papaparse';
export const runtime='nodejs';
export const dynamic='force-dynamic';
export async function POST(req:NextRequest){
 if(!validOrigin(req))return NextResponse.json({error:'Invalid origin'},{status:403});
 if(!cloudEnabled())return NextResponse.json({error:'দিনভিত্তিক Import-এর জন্য Supabase cloud mode প্রয়োজন। Local sample-এ প্রশ্ন সংরক্ষণ করা হবে না।'},{status:503});
 const c=cloudClient(req);
 try{
 const {data:{user}}=await c.client.auth.getUser();if(!user)return c.respond({error:'Unauthorized'},401);
 if(Number(req.headers.get('content-length')||0)>1_000_000)return c.respond({error:'Maximum 1 MB'},413);
 const raw=await req.text();if(new TextEncoder().encode(raw).length>1_000_000)return c.respond({error:'Maximum 1 MB'},413);
 const b=JSON.parse(raw);
 if(!['plans','list','preview','import','review','publish'].includes(b.action))return c.respond({error:'Unknown action'},400);
 const p:Record<string,unknown>={action:b.action,plan_id:b.plan_id,question_id:b.question_id,confirmed:b.confirmed};
 if(['preview','import'].includes(b.action)){
 if(typeof b.csv!=='string')throw Error('CSV required');
 const parsed=Papa.parse<Record<string,string>>(b.csv.replace(/^\uFEFF/,''),{header:true,skipEmptyLines:true,transformHeader:s=>s.trim()});
 if(parsed.errors.length||parsed.data.length>100)throw Error('CSV parse error or more than 100 rows');
 p.questions=parsed.data.map(r=>{const metadata=Object.fromEntries(['source_type','source_title','source_locator','source_url','exam_name','exam_year','author','edition','topic','difficulty'].map(k=>[k,(r[k]||'').trim()]));return {question:{track:(r.track||'').trim(),subject:(r.subject||'').trim(),q:(r.question||'').trim(),o:[r.A,r.B,r.C,r.D].map(x=>(x||'').trim()),a:'ABCD'.indexOf((r.correct||'').trim().toUpperCase()),e:(r.explanation||'').trim(),kind:r.source_type?.trim()==='previous'?'previous':'original',source:metadata.source_url+' | '+metadata.source_title+' | '+(metadata.source_type==='previous'?metadata.exam_name+' '+metadata.exam_year:metadata.author+' '+metadata.edition)+' | '+metadata.source_locator},metadata};});
 }
 const {data,error}=await c.client.rpc('jobmaster_daywise',{p});
 if(error)return c.respond({error:error.message},error.message.includes('Admin access')?403:400);
 if(data?.error)return c.respond(data,429);
 return c.respond(data);
 }catch(e){return c.respond({error:(e as Error).message},400);}
}
