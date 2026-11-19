import {NextRequest} from 'next/server';
import {cloudEnabled} from '@/lib/cloud/config';
export const runtime='nodejs';
export const dynamic='force-dynamic';
export async function POST(req:NextRequest){const handler=cloudEnabled()?await import('@/lib/cloud/admin-setup'):await import('@/lib/local/admin-setup');return handler.POST(req);}
