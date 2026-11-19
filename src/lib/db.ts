import Database from 'better-sqlite3';
import path from 'path';
// Local/persistent-host adapter. Vercel deployments must use the Supabase adapter.
const db=new Database(path.join(process.cwd(),'jobmaster.sqlite'));
db.pragma('journal_mode = WAL');
db.pragma('busy_timeout = 5000');
export default db;
