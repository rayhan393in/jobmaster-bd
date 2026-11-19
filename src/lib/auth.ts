import {NextRequest} from 'next/server';
import {db} from './store';
import {createHash,randomBytes,scryptSync,timingSafeEqual} from 'crypto';
export type User={id:string,email:string,name:string,role:string};
export function hashPassword(p:string){const salt=randomBytes(16).toString('hex');return salt+':'+scryptSync(p,salt,64).toString('hex');}
export function checkPassword(p:string,h:string){const [salt,key]=h.split(':');return timingSafeEqual(Buffer.from(key,'hex'),scryptSync(p,salt,64));}
export function tokenHash(t:string){return createHash('sha256').update(t).digest('hex');}
export function user(req:NextRequest):User|undefined{const t=req.cookies.get('jm_session')?.value;if(!t)return;return db.prepare('SELECT u.id,u.email,u.name,u.role FROM jm_auth a JOIN jm_users u ON u.id=a.user_id WHERE a.token=? AND a.expires>?').get(tokenHash(t),Date.now()) as User|undefined;}
export function sameOrigin(req:NextRequest){const o=req.headers.get('origin');return !o||o===req.nextUrl.origin||new URL(o).host===req.headers.get('x-forwarded-host')||new URL(o).host===req.headers.get('host');}
export function rateLimit(key:string,max=100,window=60000){const now=Date.now();db.prepare('DELETE FROM jm_limits WHERE reset<?').run(now);const row=db.prepare('SELECT count FROM jm_limits WHERE key=?').get(key) as {count:number}|undefined;if(row&&row.count>=max)return false;db.prepare('INSERT INTO jm_limits VALUES(?,1,?) ON CONFLICT(key) DO UPDATE SET count=count+1').run(key,now+window);return true;}
