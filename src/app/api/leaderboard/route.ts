import {NextRequest} from 'next/server';
import {cloudEnabled} from '@/lib/cloud/config';
export const runtime='nodejs';
export const dynamic='force-dynamic';
export async function GET(req:NextRequest){const handler=cloudEnabled()?await import('@/lib/cloud/leaderboard'):await import('@/lib/local/leaderboard');return handler.GET(req);}
