'use client';
import {useEffect,useState} from 'react';
import {BookOpen,Clock9,CheckCircle2,Radio,CalendarClock,Layers,BookMarked,Users,Trophy,ShieldCheck,Upload,Database} from 'lucide-react';
type Stats={total_questions:number,pending_questions:number,approved_questions:number,live_exam_questions:number,scheduled_questions:number,total_subjects:number,total_topics:number,today_participants:number,today_results:number,is_super_admin:boolean};

export default function AdminDashboardPanel({onNavigate}:{onNavigate:(tab:string)=>void}){
 const [stats,setStats]=useState<Stats|null>(null),[error,setError]=useState('');
 useEffect(()=>{fetch('/api/admin-dashboard').then(async r=>{const d=await r.json();if(!r.ok)throw Error(d.error);setStats(d);}).catch(e=>setError((e as Error).message));},[]);
 const cards=stats?[
  {label:'Total Questions',value:stats.total_questions,icon:BookOpen},
  {label:'Pending Questions',value:stats.pending_questions,icon:Clock9},
  {label:'Approved Questions',value:stats.approved_questions,icon:CheckCircle2},
  {label:'Live Exam Questions',value:stats.live_exam_questions,icon:Radio},
  {label:'Scheduled Questions',value:stats.scheduled_questions,icon:CalendarClock},
  {label:'Total Subjects',value:stats.total_subjects,icon:Layers},
  {label:'Total Topics',value:stats.total_topics,icon:BookMarked},
  {label:"Today's Participants",value:stats.today_participants,icon:Users},
  {label:"Today's Results",value:stats.today_results,icon:Trophy}
 ]:[];
 const actions=[
  {label:'Approve All',tab:'approvals',icon:CheckCircle2},
  {label:'Subject-wise Approval',tab:'approvals',icon:Layers},
  {label:'Topic-wise Approval',tab:'approvals',icon:BookMarked},
  {label:'Bulk Question Upload',tab:'csv',icon:Upload},
  {label:'SQL Import',tab:'sql-import',icon:Database},
  {label:'Schedule Live Exam',tab:'live-admin',icon:Radio},
  {label:'Manage Daily Routine',tab:'live',icon:CalendarClock}
 ];
 return <div className="admin-dashboard-panel" data-feature="admin-dashboard">
  <header className="cw-heading"><div><span className="cw-eyebrow">ADMIN DASHBOARD</span><h2><ShieldCheck size={22}/> প্ল্যাটফর্ম পরিসংখ্যান</h2><p>{stats?.is_super_admin?'আপনি Super Admin — SQL Import ব্যবহার করতে পারবেন।':'আপনি Admin। SQL Import শুধুমাত্র Super Admin-এর জন্য।'}</p></div></header>
  {error?<div className="notice" role="alert">{error}</div>:null}
  <div className="dashboard-stat-grid">{cards.map(c=><div className="stat card" key={c.label}><div className="stat-top"><span className="stat-icon"><c.icon size={18}/></span><span>{c.label}</span></div><div className="stat-value">{c.value}</div></div>)}</div>
  <h3>Quick Actions</h3>
  <div className="cw-toolbar">{actions.map(a=><button key={a.label} onClick={()=>onNavigate(a.tab)}><a.icon size={16}/> {a.label}</button>)}</div>
 </div>;
}
