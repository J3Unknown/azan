-- Preserve existing rooms and completion history while introducing room tasks.
create table azan_private.room_tasks (
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null references azan_private.rooms on delete cascade,
  name text not null check(length(trim(name)) between 2 and 80),
  description text not null default '' check(length(description)<=500),
  points integer not null check(points between 1 and 1000),
  repeats text not null check(repeats in ('daily','weekly','once')),
  weekdays integer[] not null default array[5]
    check(weekdays <@ array[1,2,3,4,5,6,7]),
  start_date date not null,
  created_at timestamptz not null default now(),
  unique(room_id,id),
  check(repeats<>'weekly' or cardinality(weekdays)>0)
);
create unique index room_task_names on azan_private.room_tasks(room_id,lower(name));
alter table azan_private.room_tasks enable row level security;
create policy rpc_only on azan_private.room_tasks for all to authenticated using(false) with check(false);
revoke all on azan_private.room_tasks from public,anon,authenticated;

create function azan_private.seed_tasks(rid uuid, starts date) returns void
language sql security invoker set search_path='' as $$
  insert into azan_private.room_tasks(room_id,name,points,repeats,start_date)
  select rid,name,points,'daily',starts from (values
    ('Fajr',1),('Dhuhr',1),('Asr',1),('Maghrib',1),('Isha',1),('Daily Quran',2),('Daily supplications',3)
  ) t(name,points);
$$;
revoke all on function azan_private.seed_tasks(uuid,date) from public,anon,authenticated;
do $$ declare r record; begin
  for r in select id,created_at from azan_private.rooms loop
    perform azan_private.seed_tasks(r.id,(r.created_at at time zone 'Africa/Cairo')::date);
  end loop;
end $$;

alter table azan_private.completions add column task_id uuid, add column awarded_points integer;
update azan_private.completions c set task_id=t.id,awarded_points=t.points
from azan_private.room_tasks t where t.room_id=c.room_id and t.name=c.task;
alter table azan_private.completions
  drop constraint completions_task_check,
  drop constraint completions_pkey,
  alter column task_id set not null,
  alter column awarded_points set not null,
  add constraint completions_pkey primary key(room_id,user_id,day,task_id),
  add constraint completion_task foreign key(room_id,task_id) references azan_private.room_tasks(room_id,id) on delete cascade,
  add constraint completion_points check(awarded_points between 1 and 1000);
create index completions_task on azan_private.completions(room_id,task_id);

create function azan_private.task_due(repeats text,weekdays integer[],starts date,day date) returns boolean
language sql immutable security invoker set search_path='' as $$
  select day>=starts and case repeats when 'daily' then true when 'weekly' then extract(isodow from day)::int=any(weekdays) when 'once' then day=starts else false end;
$$;
create function azan_private.friday_start(day date) returns date
language sql immutable security invoker set search_path='' as $$
  select day-((extract(isodow from day)::int+2)%7);
$$;
revoke all on function azan_private.task_due(text,integer[],date,date),azan_private.friday_start(date) from public,anon,authenticated;

create or replace function azan_private.build_reports(for_user uuid default null) returns void
language plpgsql security definer set search_path='' as $$
begin
  insert into azan_private.reports(room_id,user_id,week,summary)
  select r.id,recipient.user_id,w.week::date,jsonb_build_object(
    'room_name',r.name,'anchor','friday','ends_on',w.week::date+6,
    'scores',(select coalesce(jsonb_agg(score order by (score->>'points')::int desc),'[]'::jsonb)
      from (select jsonb_build_object('name',p.display_name,'user_id',m.user_id,
        'points',coalesce((select sum(c.awarded_points) from azan_private.completions c
          where c.room_id=r.id and c.user_id=m.user_id and c.day>=w.week::date and c.day<w.week::date+7),0),
        'tasks',(select coalesce(jsonb_agg(jsonb_build_object('task',name,'done',done,'target',target,'points',points)) filter(where target>0),'[]'::jsonb)
          from (select t.name,t.points,
            (select count(*) from azan_private.completions c where c.room_id=r.id and c.user_id=m.user_id and c.task_id=t.id and c.day>=w.week::date and c.day<w.week::date+7) done,
            (select count(*) from generate_series(greatest(w.week::date,(m.joined_at at time zone 'Africa/Cairo')::date,t.start_date),w.week::date+6,interval '1 day') d(day)
              where azan_private.task_due(t.repeats,t.weekdays,t.start_date,d.day::date)) target
            from azan_private.room_tasks t where t.room_id=r.id and t.start_date<w.week::date+7
          ) tasks)
        ) score from azan_private.members m join azan_private.profiles p on p.id=m.user_id
        where m.room_id=r.id and m.status='accepted' and (m.joined_at at time zone 'Africa/Cairo')::date<w.week::date+7
      ) scores)
    )
  from azan_private.rooms r
  cross join lateral generate_series(azan_private.friday_start((r.created_at at time zone 'Africa/Cairo')::date),
    azan_private.friday_start((now() at time zone 'Africa/Cairo')::date)-7,interval '7 days') w(week)
  join azan_private.members recipient on recipient.room_id=r.id and recipient.status='accepted'
    and (recipient.joined_at at time zone 'Africa/Cairo')::date<w.week::date+7
  where (for_user is null or recipient.user_id=for_user)
    and not exists(select 1 from azan_private.reports existing where existing.room_id=r.id and existing.user_id=recipient.user_id and existing.week=w.week::date)
  on conflict do nothing;
end $$;

create function azan_private.dashboard_v2() returns jsonb
language plpgsql security definer set search_path='' as $$
declare uid uuid:=auth.uid(); today date:=(now() at time zone 'Africa/Cairo')::date;
begin
  if uid is null then raise exception 'Please log in'; end if;
  insert into azan_private.profiles(id,display_name)
    select uid,case when length(trim(coalesce(raw_user_meta_data->>'display_name','')))<2 then 'Worshipper' else left(trim(raw_user_meta_data->>'display_name'),50) end
    from auth.users where id=uid on conflict do nothing;
  perform azan_private.build_reports(uid);
  return jsonb_build_object('profile',(select to_jsonb(p) from azan_private.profiles p where id=uid),'today',today,
    'rooms',coalesce((select jsonb_agg(jsonb_build_object(
      'id',r.id,'name',r.name,'ref',case when r.private then null else r.ref end,'private',r.private,'owner_id',r.owner_id,'status',mine.status,
      'tasks',case when mine.status='accepted' then (select coalesce(jsonb_agg(to_jsonb(t)||jsonb_build_object('due_today',azan_private.task_due(t.repeats,t.weekdays,t.start_date,today)) order by t.created_at,t.id),'[]'::jsonb) from azan_private.room_tasks t where t.room_id=r.id) else '[]'::jsonb end,
      'completed',(select coalesce(jsonb_agg(c.task_id),'[]'::jsonb) from azan_private.completions c where c.room_id=r.id and c.user_id=uid and c.day=today),
      'members',(select coalesce(jsonb_agg(jsonb_build_object('user_id',m.user_id,'name',p.display_name,'status',m.status,
        'completed',(select coalesce(jsonb_agg(c.task_id),'[]'::jsonb) from azan_private.completions c where c.room_id=r.id and c.user_id=m.user_id and c.day=today),
        'points_today',coalesce((select sum(c.awarded_points) from azan_private.completions c where c.room_id=r.id and c.user_id=m.user_id and c.day=today),0)
        ) order by m.joined_at),'[]'::jsonb)
        from azan_private.members m join azan_private.profiles p on p.id=m.user_id where m.room_id=r.id
        and (mine.status='accepted' or m.user_id=uid) and (m.status='accepted' or m.user_id=uid or r.owner_id=uid))
      ) order by r.created_at desc,r.id) from azan_private.members mine join azan_private.rooms r on r.id=mine.room_id where mine.user_id=uid and mine.status<>'declined'),'[]'::jsonb),
    'reports',coalesce((select jsonb_agg(to_jsonb(q) order by q.week desc) from (select * from azan_private.reports where user_id=uid order by week desc limit 100) q),'[]'::jsonb));
end $$;
revoke all on function azan_private.dashboard_v2() from public,anon;
grant execute on function azan_private.dashboard_v2() to authenticated;
revoke execute on function azan_private.dashboard() from authenticated;
create or replace function public.azan_dashboard() returns jsonb language sql security invoker set search_path='' as $$ select azan_private.dashboard_v2() $$;

create function azan_private.action_v2(action text,args jsonb) returns void
language plpgsql security definer set search_path='' as $$
declare uid uuid:=auth.uid(); rid uuid; target uuid; today date:=(now() at time zone 'Africa/Cairo')::date; t azan_private.room_tasks; starts date;
begin
  if uid is null then raise exception 'Please log in'; end if;
  if action in ('create','invite') then
    perform 1 from azan_private.profiles where id=uid for update;
    if (select count(*) from azan_private.rooms where owner_id=uid and created_at>now()-interval '1 day')>=20 then raise exception 'Daily room limit reached'; end if;
    if action='invite' then
      select id into target from azan_private.profiles where friend_code=upper(trim(args->>'friend_code')) and id<>uid;
      if target is null then raise exception 'Friend code not found'; end if;
    end if;
    insert into azan_private.rooms(name,owner_id,private) values(trim(args->>'name'),uid,action='invite') returning id into rid;
    insert into azan_private.members(room_id,user_id,status) values(rid,uid,'accepted');
    if coalesce((args->>'use_templates')::boolean,true) then perform azan_private.seed_tasks(rid,today); end if;
    if target is not null then insert into azan_private.members(room_id,user_id,status) values(rid,target,'invited'); end if;
  elsif action in ('delete_room','add_task','invite_member') then
    rid:=(args->>'room_id')::uuid;
    perform 1 from azan_private.rooms where id=rid and owner_id=uid for update;
    if not found then raise exception 'Only the room owner can do this'; end if;
    if action='delete_room' then
      delete from azan_private.rooms where id=rid and owner_id=uid;
    elsif action='add_task' then
      if (select count(*) from azan_private.room_tasks where room_id=rid)>=50 then raise exception 'A room can have up to 50 tasks'; end if;
      starts:=coalesce((args->>'start_date')::date,today);
      if starts<today then raise exception 'Task start date cannot be in the past'; end if;
      insert into azan_private.room_tasks(room_id,name,description,points,repeats,weekdays,start_date)
        values(rid,trim(args->>'name'),trim(coalesce(args->>'description','')),(args->>'points')::int,args->>'repeats',
          array(select jsonb_array_elements_text(coalesce(args->'weekdays','[]'::jsonb))::int),starts);
    else
      if not (select private from azan_private.rooms where id=rid) then raise exception 'Friend invitations are for private rooms'; end if;
      select id into target from azan_private.profiles where friend_code=upper(trim(args->>'friend_code')) and id<>uid;
      if target is null then raise exception 'Friend code not found'; end if;
      insert into azan_private.members(room_id,user_id,status) values(rid,target,'invited')
        on conflict(room_id,user_id) do update set status='invited',joined_at=now() where members.status in ('pending','declined');
    end if;
  elsif action='complete' then
    rid:=(args->>'room_id')::uuid;
    perform 1 from azan_private.rooms where id=rid for update;
    if not exists(select 1 from azan_private.members where room_id=rid and user_id=uid and status='accepted') then raise exception 'Join this room first'; end if;
    if args->>'day' is distinct from today::text then raise exception 'The day has changed. Refresh your tasks.'; end if;
    select * into t from azan_private.room_tasks where room_id=rid and
      (id=nullif(args->>'task_id','')::uuid or (not args ? 'task_id' and name=args->>'task'));
    if not found then raise exception 'Task not found'; end if;
    if not azan_private.task_due(t.repeats,t.weekdays,t.start_date,today) then raise exception 'This task is not scheduled today'; end if;
    insert into azan_private.completions(room_id,user_id,day,task,task_id,awarded_points) values(rid,uid,today,t.name,t.id,t.points) on conflict do nothing;
  else
    perform azan_private.action(action,args);
  end if;
end $$;
revoke all on function azan_private.action_v2(text,jsonb) from public,anon;
grant execute on function azan_private.action_v2(text,jsonb) to authenticated;
revoke execute on function azan_private.action(text,jsonb) from authenticated;
create or replace function public.azan_action(action text,args jsonb default '{}'::jsonb) returns void language sql security invoker set search_path='' as $$ select azan_private.action_v2(action,args) $$;
-- The existing hourly cron job automatically uses the replaced Friday report builder.
