import {NextRequest,NextResponse} from 'next/server';
import {cloudEnabled} from '@/lib/cloud/config';
import {cloudClient,validOrigin} from '@/lib/cloud/client';
import {sqlImportAction} from '@/lib/live-exam-validation';
export const runtime='nodejs';export const dynamic='force-dynamic';
export async function POST(req:NextRequest){try{
 if(!validOrigin(req))return NextResponse.json({error:'Invalid origin'},{status:403});
 const raw=await req.text();if(new TextEncoder().encode(raw).length>6_000_000)return NextResponse.json({error:'Maximum 6 MB per request (send large files in batches of ≤500 rows)'},{status:413});
 const p=sqlImportAction.parse(JSON.parse(raw));
 if(cloudEnabled()){const c=cloudClient(req);const {data,error}=await c.client.rpc('jobmaster_sql_import',{p});return c.respond(error?{error:error.message}:data,error?(error.message.includes('Unauthorized')?401:(error.message.includes('Admin access')||error.message.includes('Super Admin'))?403:400):200);}
 const {user,rateLimit}=await import('@/lib/auth');const u=user(req);if(!u)return NextResponse.json({error:'Unauthorized'},{status:401});
 if(u.role!=='admin')return NextResponse.json({error:'Admin access required'},{status:403});
 if(!rateLimit('sqlimport:'+u.id,40))return NextResponse.json({error:'Rate limit exceeded'},{status:429});
 const {localSqlImport}=await import('@/lib/local/sql-import');return NextResponse.json(localSqlImport(p,u.id,true),{headers:{'Cache-Control':'private, no-store'}});
 }catch(e){return NextResponse.json({error:(e as Error).message},{status:400});}}
