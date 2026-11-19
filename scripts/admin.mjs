import Database from 'better-sqlite3';
const email=process.argv[2]?.toLowerCase();if(!email){console.error('Usage: node scripts/admin.mjs your-registered-email');process.exit(1);}
const db=new Database('jobmaster.sqlite');const r=db.prepare("UPDATE jm_users SET role='admin' WHERE email=?").run(email);if(!r.changes){console.error('Register the account first.');process.exit(1);}console.log('Admin role granted to',email);
