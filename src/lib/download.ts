import {readJson} from './http';
export async function downloadFile(url:string,filename:string){
 const r=await fetch(url,{cache:'no-store'});if(!r.ok){const d=await readJson(r);throw Error(d.error||'ডাউনলোড করা যায়নি।');}
 if(!r.headers.get('content-type')?.includes('application/pdf'))throw Error('Server PDF ফেরত দেয়নি।');
 const blob=await r.blob();const objectUrl=URL.createObjectURL(blob);const link=document.createElement('a');link.href=objectUrl;link.download=filename;document.body.appendChild(link);link.click();link.remove();setTimeout(()=>URL.revokeObjectURL(objectUrl),10000);
}
