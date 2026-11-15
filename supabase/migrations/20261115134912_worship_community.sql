-- All worship data is private. Only authenticated RPCs expose authorized rows.
create schema if not exists azan_private;
revoke all on schema azan_private from public, anon;
grant usage on schema azan_private to authenticated;

create table azan_private.profiles (
  id uuid primary key references auth.users on delete cascade,
  display_name text not null check (length(display_name) between 2 and 50),
  avatar_path text,
  friend_code text not null unique default upper(substr(replace(gen_random_uuid()::text,'-',''),1,12))
);
create table azan_private.rooms (
  id uuid primary key default gen_random_uuid(),
  name text not null check (length(name) between 2 and 80),
  owner_id uuid not null references azan_private.profiles,
  ref text not null unique default lpad((floor(random()*100000000)::bigint)::text,8,'0'),
  private boolean not null default false,
  created_at timestamptz not null default now()
);
create table azan_private.members (
  room_id uuid references azan_private.rooms on delete cascade,
  user_id uuid references azan_private.profiles on delete cascade,
  status text not null check (status in ('pending','invited','accepted','declined')),
  joined_at timestamptz not null default now(),
  primary key(room_id,user_id)
);
create index members_user on azan_private.members(user_id, status);
create table azan_private.completions (
  room_id uuid not null,
  user_id uuid not null,
  day date not null default (now() at time zone 'Africa/Cairo')::date,
  task text not null check(task in ('Fajr','Dhuhr','Asr','Maghrib','Isha','Daily Quran','Daily supplications')),
  primary key(room_id,user_id,day,task),
  foreign key(room_id,user_id) references azan_private.members on delete cascade
);
create table azan_private.reports (
  room_id uuid references azan_private.rooms on delete cascade,
  user_id uuid references azan_private.profiles on delete cascade,
  week date not null,
  summary jsonb not null,
  primary key(room_id,user_id,week)
);
create index reports_user on azan_private.reports(user_id,week desc);
alter table azan_private.profiles enable row level security;
alter table azan_private.rooms enable row level security;
alter table azan_private.members enable row level security;
alter table azan_private.completions enable row level security;
alter table azan_private.reports enable row level security;
revoke all on all tables in schema azan_private from public, anon, authenticated;

-- Points, date boundaries and permissions are calculated on the server.
create function azan_private.build_reports(for_user uuid default null) returns void
language plpgsql security definer set search_path = '' as $$
begin
  insert into azan_private.reports(room_id,user_id,week,summary)
  select r.id, recipient.user_id, weeks.week::date,
    jsonb_build_object('room_name',r.name, 'scores', (
      select coalesce(jsonb_agg(score order by (score->>'points')::int desc), '[]'::jsonb)
      from (
        select jsonb_build_object('name',p.display_name,'user_id',m.user_id,
          'points', coalesce((select sum(case c.task when 'Daily Quran' then 2 when 'Daily supplications' then 3 else 1 end)
            from azan_private.completions c where c.room_id=r.id and c.user_id=m.user_id and c.day >= weeks.week::date and c.day < weeks.week::date+7),0),
          'tasks', (select jsonb_agg(jsonb_build_object('task',t.task,'done',
            (select count(*) from azan_private.completions c where c.room_id=r.id and c.user_id=m.user_id and c.task=t.task and c.day >= weeks.week::date and c.day < weeks.week::date+7),
            'target', weeks.week::date+7-greatest(weeks.week::date,(m.joined_at at time zone 'Africa/Cairo')::date)))
            from unnest(array['Fajr','Dhuhr','Asr','Maghrib','Isha','Daily Quran','Daily supplications']) t(task))
        ) score
        from azan_private.members m join azan_private.profiles p on p.id=m.user_id
        where m.room_id=r.id and m.status='accepted' and (m.joined_at at time zone 'Africa/Cairo')::date < weeks.week::date+7
      ) scores
    ))
  from azan_private.rooms r
  cross join lateral generate_series(date_trunc('week',r.created_at at time zone 'Africa/Cairo'),
    date_trunc('week',now() at time zone 'Africa/Cairo')-interval '1 week', interval '1 week') weeks(week)
  join azan_private.members recipient on recipient.room_id=r.id and recipient.status='accepted'
    and (recipient.joined_at at time zone 'Africa/Cairo')::date < weeks.week::date+7
  where (for_user is null or recipient.user_id=for_user)
    and not exists(select 1 from azan_private.reports existing where existing.room_id=r.id and existing.user_id=recipient.user_id and existing.week=weeks.week::date)
  on conflict do nothing;
end $$;
revoke all on function azan_private.build_reports(uuid) from public, anon, authenticated;

create function azan_private.dashboard() returns jsonb
language plpgsql security definer set search_path = '' as $$
declare uid uuid := auth.uid(); result jsonb;
begin
  if uid is null then raise exception 'Please log in'; end if;
  insert into azan_private.profiles(id,display_name)
    select uid,left(coalesce(nullif(trim(raw_user_meta_data->>'display_name'),''),'Worshipper'),50)
    from auth.users where id=uid on conflict do nothing;
  -- Backfill missed weekly reports when the app reconnects, as well as via cron.
  perform azan_private.build_reports(uid);
  select jsonb_build_object(
    'profile',(select to_jsonb(p) from azan_private.profiles p where id=uid),
    'today',(now() at time zone 'Africa/Cairo')::date,
    'rooms',coalesce((select jsonb_agg(jsonb_build_object(
      'id',r.id,'name',r.name,'ref',r.ref,'private',r.private,'owner_id',r.owner_id,'status',mine.status,
      'members',(select coalesce(jsonb_agg(jsonb_build_object('user_id',m.user_id,'name',p.display_name,'status',m.status)), '[]'::jsonb)
        from azan_private.members m join azan_private.profiles p on p.id=m.user_id
        where m.room_id=r.id and (mine.status='accepted' or m.user_id=uid)),
      'completed',(select coalesce(jsonb_agg(c.task),'[]'::jsonb) from azan_private.completions c
        where c.room_id=r.id and c.user_id=uid and c.day=(now() at time zone 'Africa/Cairo')::date)
    ) order by r.created_at desc) from azan_private.members mine join azan_private.rooms r on r.id=mine.room_id
      where mine.user_id=uid and mine.status <> 'declined'),'[]'::jsonb),
    'reports',coalesce((select jsonb_agg(to_jsonb(q) order by q.week desc) from
      (select * from azan_private.reports where user_id=uid order by week desc limit 100) q),'[]'::jsonb)
  ) into result;
  return result;
end $$;

create function azan_private.action(action text, args jsonb) returns void
language plpgsql security definer set search_path = '' as $$
declare uid uuid := auth.uid(); rid uuid; target uuid; today date := (now() at time zone 'Africa/Cairo')::date;
begin
  if uid is null then raise exception 'Please log in'; end if;
  if action='profile' then
    if args ? 'avatar_path' and args->>'avatar_path' not like uid::text || '/%' then raise exception 'Invalid photo'; end if;
    update azan_private.profiles set display_name=trim(args->>'name'), avatar_path=coalesce(args->>'avatar_path',avatar_path) where id=uid;
  elsif action in ('create','invite') then
    if (select count(*) from azan_private.rooms where owner_id=uid and created_at>now()-interval '1 day')>=20 then raise exception 'Daily room limit reached'; end if;
    if action='invite' then
      select id into target from azan_private.profiles where friend_code=upper(trim(args->>'friend_code')) and id<>uid;
      if target is null then raise exception 'Friend code not found'; end if;
    end if;
    insert into azan_private.rooms(name,owner_id,private) values(trim(args->>'name'),uid,action='invite') returning id into rid;
    insert into azan_private.members(room_id,user_id,status) values(rid,uid,'accepted');
    if target is not null then insert into azan_private.members(room_id,user_id,status) values(rid,target,'invited'); end if;
  elsif action='join' then
    select id into rid from azan_private.rooms where ref=trim(args->>'ref') and not private;
    if rid is null then raise exception 'Room reference not found'; end if;
    insert into azan_private.members(room_id,user_id,status) values(rid,uid,'pending')
      on conflict(room_id,user_id) do update set status='pending',joined_at=now() where members.status='declined';
  else
    rid := (args->>'room_id')::uuid;
    -- Serialize membership decisions and task completion for a room.
    perform 1 from azan_private.rooms where id=rid for update;
    if action in ('accept','decline') then
      target := coalesce((args->>'user_id')::uuid,uid);
      update azan_private.members m set status=case when action='accept' then 'accepted' else 'declined' end,joined_at=now()
      where m.room_id=rid and m.user_id=target and
        ((m.status='invited' and target=uid) or (m.status='pending' and exists(select 1 from azan_private.rooms where id=rid and owner_id=uid)));
      if not found then raise exception 'Request is no longer available'; end if;
    elsif action='complete' then
      if not exists(select 1 from azan_private.members where room_id=rid and user_id=uid and status='accepted') then raise exception 'Join this room first'; end if;
      if args->>'day' is distinct from today::text then raise exception 'The day has changed. Refresh your tasks.'; end if;
      insert into azan_private.completions(room_id,user_id,day,task) values(rid,uid,today,args->>'task') on conflict do nothing;
    else raise exception 'Unknown action'; end if;
  end if;
end $$;

revoke all on function azan_private.dashboard(), azan_private.action(text,jsonb) from public, anon;
grant execute on function azan_private.dashboard(), azan_private.action(text,jsonb) to authenticated;
create function public.azan_dashboard() returns jsonb language sql security invoker set search_path='' as $$ select azan_private.dashboard() $$;
create function public.azan_action(action text,args jsonb default '{}'::jsonb) returns void language sql security invoker set search_path='' as $$ select azan_private.action(action,args) $$;
revoke all on function public.azan_dashboard(),public.azan_action(text,jsonb) from public,anon;
grant execute on function public.azan_dashboard(),public.azan_action(text,jsonb) to authenticated;

-- A private bucket: clients use short-lived signed URLs for their own photo.
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('azan-avatars','azan-avatars',false,2097152,array['image/jpeg','image/png','image/webp']);
create policy azan_avatar_select on storage.objects for select to authenticated
using(bucket_id='azan-avatars' and (storage.foldername(name))[1]=(select auth.uid())::text);
create policy azan_avatar_insert on storage.objects for insert to authenticated
with check(bucket_id='azan-avatars' and (storage.foldername(name))[1]=(select auth.uid())::text);
create policy azan_avatar_update on storage.objects for update to authenticated
using(bucket_id='azan-avatars' and (storage.foldername(name))[1]=(select auth.uid())::text)
with check(bucket_id='azan-avatars' and (storage.foldername(name))[1]=(select auth.uid())::text);

create extension if not exists pg_cron;
-- Every hour, so Monday midnight Cairo is covered even across DST changes.
select cron.schedule('azan-weekly-reports','5 * * * *','select azan_private.build_reports()');
