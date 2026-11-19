import {NextResponse} from 'next/server';
export async function POST(){return NextResponse.json({error:'Cloud mode-এ setup code ব্যবহার হয় না। আগে email verify করে account খুলুন। Project owner Supabase SQL Editor থেকে নির্দিষ্ট user UUID-কে admin করবেন। পুরোনো preview code cloud-এ অকার্যকর।'},{status:403});}
