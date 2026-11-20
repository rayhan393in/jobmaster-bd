import {NextRequest,NextResponse} from 'next/server';
import {cloudEnabled} from '@/lib/cloud/config';
import {cloudClient,validOrigin} from '@/lib/cloud/client';
import {courseAction} from '@/lib/course-validation';
export const runtime='nodejs';export const dynamic='force-dynamic';
export async function POST(req:NextRequest){try{
 if(!validOrigin(req))return NextResponse.json({error:'Invalid origin'},{status:403});
 const raw=await req.text();if(new TextEncoder().encode(raw).length>3_000_000)return NextResponse.json({error:'Maximum 3 MB per request'},{status:413});
 const p=courseAction.parse(JSON.parse(raw));
 if(cloudEnabled()){const c=cloudClient(req);const {data,error}=await c.client.rpc('jobmaster_courses',{p});return c.respond(error?{error:error.message}:data,error?(error.message.includes('Unauthorized')?401:error.message.includes('Admin access')?403:400):200);}
 const {user,rateLimit}=await import('@/lib/auth');const u=user(req);if(!u)return NextResponse.json({error:'Unauthorized'},{status:401});
 if(!['catalog','start'].includes(p.action)&&u.role!=='admin')return NextResponse.json({error:'Admin access required'},{status:403});
 if(!rateLimit('courses:'+u.id,150))return NextResponse.json({error:'Rate limit exceeded'},{status:429});
 const {localCourses}=await import('@/lib/local/courses');return NextResponse.json(localCourses(p,u.id,u.role==='admin'),{headers:{'Cache-Control':'private, no-store'}});
 }catch(e){return NextResponse.json({error:(e as Error).message},{status:400});}}
