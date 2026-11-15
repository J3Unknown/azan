// Run with: node community_database.mjs <path-to-pglite-module> <migration.sql>
// Uses embedded PostgreSQL; stubs only Supabase auth/storage and pg_cron plumbing.
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { pathToFileURL } from 'node:url';
const { PGlite } = await import(pathToFileURL(process.argv[2]).href);
const db = new PGlite();
await db.exec(`
  create role anon; create role authenticated;
  create schema auth; create schema storage; create schema cron;
  create table auth.users(id uuid primary key, raw_user_meta_data jsonb);
  create function auth.uid() returns uuid language sql stable as
    $$ select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid $$;
  grant usage on schema auth to authenticated;
  grant execute on function auth.uid() to authenticated;
  create table storage.buckets(id text primary key,name text,public boolean,file_size_limit bigint,allowed_mime_types text[]);
  create table storage.objects(id uuid primary key default gen_random_uuid(), bucket_id text,name text);
  alter table storage.objects enable row level security;
  grant usage on schema storage to authenticated;
  grant select,insert,update on storage.objects to authenticated;
  create function storage.foldername(text) returns text[] language sql immutable as $$ select string_to_array($1,'/') $$;
  create function cron.schedule(text,text,text) returns bigint language sql as $$ select 1::bigint $$;
`);
const migration = (await readFile(process.argv[3], 'utf8')).replace('create extension if not exists pg_cron;', '');
await db.exec(migration);
const ids = ['10000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000002', '10000000-0000-0000-0000-000000000003'];
for (let i=0; i<ids.length; i++) await db.query(`insert into auth.users values ($1,$2)`,[ids[i],JSON.stringify({display_name:['Omar','Ali','Sara'][i]})]);
const asUser = async i => {
  await db.exec('reset role');
  await db.query(`select set_config('request.jwt.claim.sub',$1,false)`,[i === null ? '' : ids[i]]);
  await db.exec('set role authenticated');
};
const dash = async () => (await db.query('select public.azan_dashboard() as data')).rows[0].data;
const action = async (type,args={}) => db.query('select public.azan_action($1,$2::jsonb)',[type,JSON.stringify(args)]);
const denied = async fn => { await assert.rejects(fn); };
await asUser(null); await denied(dash);
await db.exec('set role anon'); await denied(dash);
for(let i=0;i<3;i++){await asUser(i); await dash();}
await asUser(0); await action('create',{name:'Our daily worship'});
let d = await dash(); const room = d.rooms[0];
assert.match(room.ref,/^\d{8}$/);
await denied(() => db.query('select * from azan_private.rooms'));
await asUser(1); assert.equal((await dash()).rooms.length,0);
await action('join',{ref:room.ref});
assert.equal((await dash()).rooms[0].status,'pending');
await denied(()=>action('complete',{room_id:room.id,task:'Fajr',day:d.today}));
await denied(()=>action('accept',{room_id:room.id}));
await asUser(2); await denied(()=>action('accept',{room_id:room.id,user_id:ids[1]}));
await asUser(0); await action('accept',{room_id:room.id,user_id:ids[1]});
await asUser(1); d=await dash(); assert.equal(d.rooms[0].status,'accepted');
await action('complete',{room_id:room.id,task:'Fajr',day:d.today});
await action('complete',{room_id:room.id,task:'Fajr',day:d.today});
await action('complete',{room_id:room.id,task:'Daily Quran',day:d.today});
await action('complete',{room_id:room.id,task:'Daily supplications',day:d.today});
assert.equal((await dash()).rooms[0].completed.length,3);
await denied(()=>action('complete',{room_id:room.id,task:'Fake points',day:d.today}));
await denied(()=>action('complete',{room_id:room.id,task:'Isha',day:'2000-01-01'}));
const friendCode=(await dash()).profile.friend_code;
await asUser(0); await action('invite',{name:'Together this week',friend_code:friendCode});
const privateRoom=(await dash()).rooms.find(r=>r.private);
await asUser(2); await denied(()=>action('join',{ref:privateRoom.ref}));
assert.equal((await dash()).rooms.length,0);
await asUser(1); assert.equal((await dash()).rooms.find(r=>r.private).status,'invited');
await action('accept',{room_id:privateRoom.id});
assert.equal((await dash()).rooms.find(r=>r.private).status,'accepted');
await denied(()=>action('profile',{name:'Ali',avatar_path:ids[0]+'/avatar.png'}));
await denied(()=>db.query('select azan_private.build_reports()'));
await denied(()=>db.query(`insert into storage.objects(bucket_id,name) values ('azan-avatars',$1)`,[ids[0]+'/avatar.png']));
await db.query(`insert into storage.objects(bucket_id,name) values ('azan-avatars',$1)`,[ids[1]+'/avatar.png']);
assert.equal((await db.query('select * from storage.objects')).rows.length,1);
await asUser(0); assert.equal((await db.query('select * from storage.objects')).rows.length,0);

// Seed a full completed week, plus a member who joined in the middle of it.
await db.exec('reset role');
const week=(await db.query(`select (date_trunc('week',now() at time zone 'Africa/Cairo')-interval '1 week')::date::text as week`)).rows[0].week;
await db.query(`update azan_private.rooms set created_at=$1::date where id=$2`,[week,room.id]);
await db.query(`update azan_private.members set joined_at=$1::date where room_id=$2`,[week,room.id]);
await db.query(`update azan_private.members set joined_at=$1::date+interval '3 days' where room_id=$2 and user_id=$3`,[week,room.id,ids[1]]);
await db.query(`insert into azan_private.completions(room_id,user_id,day,task)
  select $1,$2,$3::date + day,task from generate_series(0,6) day cross join unnest(array['Fajr','Dhuhr','Asr','Maghrib','Isha','Daily Quran','Daily supplications']) task`,[room.id,ids[0],week]);
await db.query(`insert into azan_private.completions(room_id,user_id,day,task)
  select $1,$2,$3::date+day,'Daily Quran' from generate_series(3,5) day`,[room.id,ids[1],week]);
await db.query('select azan_private.build_reports()');
await db.query('select azan_private.build_reports()');
await asUser(0); const report=(await dash()).reports[0];
assert.equal(report.week,week);
const scores=report.summary.scores;
assert.equal(scores[0].points,70);
assert.equal(scores[1].points,6);
const quran=scores[1].tasks.find(t=>t.task==='Daily Quran');
assert.deepEqual(quran,{task:'Daily Quran',done:3,target:4});
assert.equal((await dash()).reports.length,1);
await asUser(2); assert.equal((await dash()).reports.length,0);
await db.exec('reset role');
const bucket=(await db.query(`select * from storage.buckets where id='azan-avatars'`)).rows[0];
assert.equal(Number(bucket.file_size_limit),2097152);
assert.equal(bucket.public,false);
console.log('PASS: auth, room approval, private invitations, idempotent completion, server dates, privacy, weekly scoring, partial weeks, report deduplication, avatar ownership and bucket limits.');
await db.close();
