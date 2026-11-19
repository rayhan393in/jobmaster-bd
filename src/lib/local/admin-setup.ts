import {NextRequest,NextResponse} from 'next/server';
import {db} from '@/lib/store';
import {sameOrigin,rateLimit,hashPassword,checkPassword,tokenHash} from '@/lib/auth';
import {randomBytes} from 'crypto';
import {z} from 'zod';
db.exec('CREATE TABLE IF NOT EXISTS jm_admin_setup(token_hash TEXT PRIMARY KEY,expires INTEGER NOT NULL,used INTEGER NOT NULL DEFAULT 0)');
export async function POST(req:NextRequest){try{
 if(!sameOrigin(req))return NextResponse.json({error:'Invalid origin'},{status:403});
 if(!rateLimit('admin-setup:'+(req.headers.get('x-forwarded-for')||'local'),8,900000))return NextResponse.json({error:'অনেকবার চেষ্টা হয়েছে। পরে চেষ্টা করুন।'},{status:429});
 const b=z.object({code:z.string().min(20).max(128),name:z.string().trim().min(2).max(80),email:z.string().email().max(254).transform(v=>v.toLowerCase()),password:z.string().min(10).max(128)}).parse(await req.json());
 const result=db.transaction(()=>{const key=tokenHash(b.code.trim());const setup=db.prepare('SELECT * FROM jm_admin_setup WHERE token_hash=? AND used=0 AND expires>?').get(key,Date.now());if(!setup)throw Error('Setup code ভুল, মেয়াদোত্তীর্ণ অথবা ইতোমধ্যে ব্যবহৃত হয়েছে।');
 const existing=db.prepare('SELECT id,password FROM jm_users WHERE email=?').get(b.email) as {id:string,password:string}|undefined;
 if(existing&&!checkPassword(b.password,existing.password))throw Error('এই ইমেইলের অ্যাকাউন্ট আগে থেকে আছে। তার সঠিক পাসওয়ার্ড দিন।');
 const id=existing?.id||crypto.randomUUID();if(existing)db.prepare("UPDATE jm_users SET role='admin' WHERE id=?").run(id);else db.prepare('INSERT INTO jm_users VALUES(?,?,?,?,?,?)').run(id,b.email,b.name,hashPassword(b.password),'admin',Date.now());
 db.prepare('UPDATE jm_admin_setup SET used=1 WHERE token_hash=?').run(key);const token=randomBytes(32).toString('hex');db.prepare('INSERT INTO jm_auth VALUES(?,?,?)').run(tokenHash(token),id,Date.now()+7*86400000);return token;})();
 const res=NextResponse.json({ok:true});res.cookies.set('jm_session',result,{httpOnly:true,secure:req.nextUrl.protocol==='https:'||req.headers.get('x-forwarded-proto')==='https',sameSite:'lax',path:'/',maxAge:7*86400});return res;
 }catch(e){return NextResponse.json({error:e instanceof z.ZodError?'নাম, সঠিক ইমেইল, setup code ও অন্তত ১০ অক্ষরের পাসওয়ার্ড দিন।':e instanceof Error?e.message:'Setup failed'},{status:400});}}
