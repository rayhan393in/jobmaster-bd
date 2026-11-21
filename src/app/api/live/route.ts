import {NextRequest,NextResponse} from 'next/server';
import {cloudEnabled} from '@/lib/cloud/config';
import {cloudClient,validOrigin} from '@/lib/cloud/client';
import {liveExamAction} from '@/lib/live-exam-validation';
export const runtime='nodejs';export const dynamic='force-dynamic';
export async function POST(req:NextRequest){try{
 if(!validOrigin(req))return NextResponse.json({error:'Invalid origin'},{status:403});
 const raw=await req.text();if(new TextEncoder().encode(raw).length>2_000_000)return NextResponse.json({error:'Maximum 2 MB per request'},{status:413});
 const p=liveExamAction.parse(JSON.parse(raw));
 if(cloudEnabled()){const c=cloudClient(req);const {data,error}=await c.client.rpc('jobmaster_live',{p});return c.respond(error?{error:error.message}:data,error?(error.message.includes('Unauthorized')?401:error.message.includes('Admin access')?403:400):200);}
 const {user,rateLimit}=await import('@/lib/auth');const u=user(req);if(!u)return NextResponse.json({error:'Unauthorized'},{status:401});
 if(!rateLimit('live:'+u.id,300))return NextResponse.json({error:'Rate limit exceeded'},{status:429});
 const {localLive}=await import('@/lib/local/live');return NextResponse.json(localLive(p,u.id,u.role==='admin'),{headers:{'Cache-Control':'private, no-store'}});
 }catch(e){return NextResponse.json({error:(e as Error).message},{status:400});}}
