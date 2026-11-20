'use client';
export async function upgradeApi(body:object){const r=await fetch('/api/upgrade',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(body)});const d=await r.json();if(!r.ok)throw Error(d.error||'Upgrade request failed');return d;}
