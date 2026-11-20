'use client';
import CourseWorkbench from '@/components/CourseWorkbench';
/** A single admin shell. No legacy/new toggles or duplicate question/schedule forms. */
export default function AdminCenter(){return <section className="card standalone admin-center" data-admin-system="single-v5.1"><CourseWorkbench/></section>;}
