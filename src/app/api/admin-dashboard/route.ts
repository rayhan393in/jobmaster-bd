import {NextRequest,NextResponse} from 'next/server';
import {cloudEnabled} from '@/lib/cloud/config';
import {cloudClient} from '@/lib/cloud/client';
export const runtime='nodejs';export const dynamic='force-dynamic';
export async function GET(req:NextRequest){try{
 if(cloudEnabled()){const c=cloudClient(req);const {data,error}=await c.client.rpc('jobmaster_admin_dashboard',{p:{}});return c.respond(error?{error:error.message}:data,error?(error.message.includes('Unauthorized')?401:error.message.includes('Admin access')?403:400):200);}
 const {user}=await import('@/lib/auth');const u=user(req);if(!u)return NextResponse.json({error:'Unauthorized'},{status:401});
 if(u.role!=='admin')return NextResponse.json({error:'Admin access required'},{status:403});
 const {localAdminDashboard}=await import('@/lib/local/admin-dashboard');return NextResponse.json(localAdminDashboard(u.id,true),{headers:{'Cache-Control':'private, no-store'}});
 }catch(e){return NextResponse.json({error:(e as Error).message},{status:400});}}
