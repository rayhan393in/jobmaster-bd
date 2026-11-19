import {NextRequest} from 'next/server';
import {cloudEnabled} from '@/lib/cloud/config';
export const runtime='nodejs';
export const dynamic='force-dynamic';
export const maxDuration=60;
export async function GET(req:NextRequest){const handler=cloudEnabled()?await import('@/lib/cloud/pdf'):await import('@/lib/local/pdf');return handler.GET(req);}
