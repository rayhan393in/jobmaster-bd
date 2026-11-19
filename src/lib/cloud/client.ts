import {createServerClient} from '@supabase/ssr';
import {NextRequest,NextResponse} from 'next/server';
export function cloudClient(req:NextRequest){const url=process.env.NEXT_PUBLIC_SUPABASE_URL;const key=process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY||process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;if(!url||!key)throw Error('Supabase URL ও publishable key Environment Variables-এ দিন।');
 type Patch={name:string,value:string,options:Parameters<NextResponse['cookies']['set']>[2]};const patches:Patch[]=[];
 const client=createServerClient(url,key,{cookieOptions:{httpOnly:true,secure:req.nextUrl.protocol==='https:'||req.headers.get('x-forwarded-proto')==='https',sameSite:'lax',path:'/'},cookies:{getAll:()=>req.cookies.getAll(),setAll:cs=>{for(const c of cs){req.cookies.set(c.name,c.value);patches.push(c as Patch);}}}});
 return {client,respond:(body:unknown,status=200)=>{const r=NextResponse.json(body,{status,headers:{'Cache-Control':'private, no-store'}});for(const p of patches)r.cookies.set(p.name,p.value,p.options);return r;},apply:(r:NextResponse)=>{for(const p of patches)r.cookies.set(p.name,p.value,p.options);return r;}};
}
export function validOrigin(req:NextRequest){const o=req.headers.get('origin');if(!o)return true;try{const h=new URL(o).host;return o===req.nextUrl.origin||h===req.headers.get('host')||h===req.headers.get('x-forwarded-host');}catch{return false;}}
export async function rpc(req:NextRequest,body:Record<string,unknown>){const ctx=cloudClient(req);const {data,error}=await ctx.client.rpc('jobmaster_action',{p:body});if(error){const status=error.message.includes('Unauthorized')?401:error.message.includes('Admin access')?403:400;return ctx.respond({error:error.message},status);}return ctx.respond(data);}
