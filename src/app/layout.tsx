import type { Metadata } from 'next';
import './globals.css';
import SessionGate from '@/components/SessionGate';
export const metadata: Metadata = {title:'JobMaster BD — আপনার স্বপ্নের প্রস্তুতিতে', description:'BCS ও Engineering চাকরির প্রস্তুতি, MCQ অনুশীলন ও ব্যক্তিগত স্টাডি প্ল্যানার।'};
export default function RootLayout({children}:Readonly<{children:React.ReactNode}>){return <html lang="bn"><body><SessionGate>{children}</SessionGate></body></html>}
