import {NextRequest} from 'next/server';
import {cloudEnabled} from '@/lib/cloud/config';
export const runtime='nodejs';
export const dynamic='force-dynamic';
export async function GET(req:NextRequest){const handler=cloudEnabled()?await import('@/lib/cloud/syllabus'):await import('@/lib/local/syllabus');return handler.GET(req);}
export async function POST(req:NextRequest){const handler=cloudEnabled()?await import('@/lib/cloud/syllabus'):await import('@/lib/local/syllabus');return handler.POST(req);}
