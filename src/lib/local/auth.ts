import {NextRequest,NextResponse} from 'next/server';
import {db} from '@/lib/store';
import {user,sameOrigin,rateLimit,hashPassword,checkPassword,tokenHash} from '@/lib/auth';
import {randomBytes} from 'crypto';
import {z} from 'zod';
export async function GET(req:NextRequest){return NextResponse.json({user:user(req)||null});}
export async function POST(req:NextRequest){
 try{
 if(!sameOrigin(req))return NextResponse.json({error:'Invalid origin'},{status:403});
 if(!rateLimit('auth:'+ (req.headers.get('x-forwarded-for')||'local'),20,900000))return NextResponse.json({error:'অনেক চেষ্টা হয়েছে। ১৫ মিনিট পরে চেষ্টা করুন।'},{status:429});
 const body=await req.json();if(body.action==='logout'){const token=req.cookies.get('jm_session')?.value;if(token)db.prepare('DELETE FROM jm_auth WHERE token=?').run(tokenHash(token));const res=NextResponse.json({ok:true});res.cookies.delete('jm_session');return res;}
 const parsed=z.object({action:z.enum(['login','register']),email:z.string().email().max(254).transform(s=>s.toLowerCase()),password:z.string().min(10).max(128),name:z.string().trim().min(2).max(80).optional()}).safeParse(body);
 if(!parsed.success)return NextResponse.json({error:'সঠিক ইমেইল ও অন্তত ১০ অক্ষরের পাসওয়ার্ড দিন।'},{status:400});const b=parsed.data;
 let found=db.prepare('SELECT * FROM jm_users WHERE email=?').get(b.email) as {id:string,password:string}|undefined;
 if(b.action==='register'){if(found)return NextResponse.json({error:'এই ইমেইলটি ইতোমধ্যে ব্যবহৃত হয়েছে।'},{status:409});if(!b.name)return NextResponse.json({error:'আপনার নাম দিন।'},{status:400});const id=crypto.randomUUID();db.prepare('INSERT INTO jm_users VALUES(?,?,?,?,?,?)').run(id,b.email,b.name,hashPassword(b.password),process.env.JOBMASTER_ADMIN_EMAIL?.toLowerCase()===b.email?'admin':'student',Date.now());found={id,password:''};}
 else if(!found||!checkPassword(b.password,found.password))return NextResponse.json({error:'ইমেইল অথবা পাসওয়ার্ড সঠিক নয়।'},{status:401});
 const token=randomBytes(32).toString('hex');db.prepare('INSERT INTO jm_auth VALUES(?,?,?)').run(tokenHash(token),found!.id,Date.now()+7*86400000);const res=NextResponse.json({ok:true});res.cookies.set('jm_session',token,{httpOnly:true,secure:req.nextUrl.protocol==='https:'||req.headers.get('x-forwarded-proto')==='https',sameSite:'lax',path:'/',maxAge:7*86400});return res;
 }catch{return NextResponse.json({error:'অনুরোধটি প্রক্রিয়া করা যায়নি।'},{status:400});}
}
