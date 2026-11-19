import Database from 'better-sqlite3';
import {randomBytes,createHash} from 'node:crypto';
const db=new Database('jobmaster.sqlite');
db.exec('CREATE TABLE IF NOT EXISTS jm_admin_setup(token_hash TEXT PRIMARY KEY,expires INTEGER NOT NULL,used INTEGER NOT NULL DEFAULT 0)');
const code=randomBytes(18).toString('base64url');
// Supersede previous unused setup codes; only the most recently issued code works.
db.prepare('UPDATE jm_admin_setup SET used=1 WHERE used=0').run();
db.prepare('INSERT INTO jm_admin_setup VALUES(?,?,0)').run(createHash('sha256').update(code).digest('hex'),Date.now()+24*3600000);
console.log('One-time admin setup code (24 hours): '+code);
console.log('Open /admin/setup in the running website. Keep this code private.');
