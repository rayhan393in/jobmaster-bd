import {NextRequest,NextResponse} from 'next/server';
import {cloudEnabled} from '@/lib/cloud/config';
import {cloudClient} from '@/lib/cloud/client';
export const runtime='nodejs';
export const dynamic='force-dynamic';
export async function GET(req:NextRequest){
 try{
  if(!cloudEnabled()){
   const {user}=await import('@/lib/auth');if(!user(req))return NextResponse.json({error:'লগইন করুন।'},{status:401});
   const {default:plans}=await import('@/lib/month-plan-preview.json');
   return NextResponse.json({now:Date.now(),timezone:'Asia/Dhaka',plans,mode:'local-preview'},{headers:{'Cache-Control':'private, no-store'}});
  }
  const c=cloudClient(req);const {data:{user}}=await c.client.auth.getUser();if(!user)return c.respond({error:'লগইন করুন।'},401);
  const {data,error}=await c.client.rpc('jobmaster_calendar');
  if(error){console.error('Monthly calendar RPC',error.code);return c.respond({error:'মাসিক routine feed পাওয়া যায়নি। Supabase SQL Editor-এ BCS-Auto-Routine-Setup.sql পুরোটা চালিয়ে আবার Refresh চাপুন।'},503);}
  return c.respond({...data,mode:'supabase'});
 }catch(e){console.error('Month plan API failed',e);return NextResponse.json({error:'রুটিন লোড হয়নি। Backend configuration পরীক্ষা করে আবার চেষ্টা করুন।'},{status:503});}
}
