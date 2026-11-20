from pathlib import Path
import zipfile,hashlib,json
root=Path(__file__).resolve().parents[1]
out=root.parent/'JobMaster-Unified-V5.zip'
# Refresh the exact installer shipped to the user.
header='''-- JobMaster Unified V5 installer for an EXISTING Admin-Courses-V3 database.
-- Back up first. Run this WHOLE file in the Supabase project used by Vercel.
-- Includes V4 prerequisites + Unified V5 + schema-cache reload.
-- Do NOT rerun STEP-5 / seed / old routine setup on the hosted database.
begin;
do $$begin if to_regclass('jobmaster_private.course_questions') is null then raise exception 'Admin-Courses-V3 must be installed first';end if;end $$;
commit;

'''
(root/'UPDATE-SUPABASE.sql').write_text(header+(root/'deployment/updates/Platform-V4.sql').read_text()+'\n\n'+(root/'deployment/updates/Unified-V5.sql').read_text())
skiproots={'Platform-V4.sql','V4-SHA256-MANIFEST.json','V4-CHANGED-FILES.json','V5-SHA256-MANIFEST.json','V5-CHANGED-FILES.json'}
def included(p):
 rel=p.relative_to(root);parts=rel.parts
 if not p.is_file() or any(x in parts for x in ['node_modules','.next','.git','__pycache__','.cache']):return False
 if p.name in skiproots and len(parts)==1:return False
 if '.sqlite' in str(rel) or p.suffix=='.zip' or p.name.endswith('.tsbuildinfo'):return False
 if p.name.startswith('.env') and p.name!='.env.example':return False
 if 'artifacts' in parts and p.name not in ['unified-v5-admin.png','unified-v5-admin-mobile.png','unified-v5-student-mobile.png']:return False
 if len(parts)==1 and ('results.txt' in p.name or 'regression.txt' in p.name) and not p.name.startswith('unified-v5'):return False
 return True
entries=sorted((p for p in root.rglob('*') if included(p)),key=lambda p:p.relative_to(root).as_posix())
base=root.parent/'backups/jobmaster-before-v5.zip'
if base.exists():
 with zipfile.ZipFile(base) as z:
  old=set(z.namelist());changes=[p.relative_to(root).as_posix() for p in entries if p.relative_to(root).as_posix() not in old or p.read_bytes()!=z.read(p.relative_to(root).as_posix())]
 (root/'V5-CHANGED-FILES.json').write_text(json.dumps(changes,indent=2));entries.append(root/'V5-CHANGED-FILES.json')
manifest={p.relative_to(root).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in entries}
(root/'V5-SHA256-MANIFEST.json').write_text(json.dumps(manifest,indent=2));entries.append(root/'V5-SHA256-MANIFEST.json')
with zipfile.ZipFile(out,'w',zipfile.ZIP_DEFLATED,compresslevel=9) as z:
 for p in entries:z.write(p,p.relative_to(root).as_posix())
with zipfile.ZipFile(out) as z:
 assert z.testzip() is None
 for name in ['src/app/page.tsx','src/components/LiveExamCenter.tsx','src/components/RoutineManager.tsx','src/lib/local/schedule.ts','src/app/api/schedule/route.ts','UPDATE-SUPABASE.sql','START-HERE-V5-BN.md']:
  assert z.read(name)==(root/name).read_bytes(),name
 for name in z.namelist():
  assert not any(x in name for x in ['node_modules/','.next/','.env.local','jobmaster.sqlite']),name
 print('Verified',len(z.namelist()),'files')
print(out,'bytes',out.stat().st_size,'SHA256',hashlib.sha256(out.read_bytes()).hexdigest())
(root.parent/'UPDATE-SUPABASE.sql').write_bytes((root/'UPDATE-SUPABASE.sql').read_bytes())
