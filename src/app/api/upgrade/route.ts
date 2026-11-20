import {NextRequest,NextResponse} from 'next/server';
import {cloudEnabled} from '@/lib/cloud/config';
import {cloudClient,validOrigin} from '@/lib/cloud/client';
import {upgradeAction} from '@/lib/upgrade-validation';
export const runtime='nodejs';export const dynamic='force-dynamic';
export async function POST(req:NextRequest){try{
 if(!validOrigin(req))return NextResponse.json({error:'Invalid origin'},{status:403});
 const text=await req.text();if(text.length>20000)return NextResponse.json({error:'Request too large'},{status:413});const p=upgradeAction.parse(JSON.parse(text));
 if(cloudEnabled()){const c=cloudClient(req);const {data,error}=await c.client.rpc('jobmaster_upgrade',{p});return c.respond(error?{error:error.message}:data,error?(error.message.includes('Unauthorized')?401:error.message.includes('Admin access')?403:400):200);}
 const {user,rateLimit}=await import('@/lib/auth');const u=user(req);if(!u)return NextResponse.json({error:'Unauthorized'},{status:401});if(!['catalog','exams','live_start'].includes(p.action)&&u.role!=='admin')return NextResponse.json({error:'Admin access required'},{status:403});if(!rateLimit('upgrade:'+u.id,100))return NextResponse.json({error:'Rate limit exceeded'},{status:429});if(p.action==='ai_authorize'&&!rateLimit('ai:'+u.id,10))return NextResponse.json({error:'AI rate limit exceeded'},{status:429});const {localUpgrade}=await import('@/lib/local/upgrade');return NextResponse.json(localUpgrade(p,u.id,u.role==='admin'),{headers:{'Cache-Control':'private, no-store'}});
 }catch(e){return NextResponse.json({error:(e as Error).message},{status:400});}}
