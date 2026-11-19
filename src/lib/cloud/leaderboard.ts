import {NextRequest,NextResponse} from 'next/server';import {rpc} from './client';
export async function GET(req:NextRequest){try{const exam=req.nextUrl.searchParams.get('exam');if(!exam)return NextResponse.json({rows:[]});return await rpc(req,{action:'leaderboard',exam});}catch(e){return NextResponse.json({error:(e as Error).message},{status:503});}}
