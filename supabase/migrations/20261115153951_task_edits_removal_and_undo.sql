-- Versions preserve past schedules and points. A logical task can score only once per day.
alter table azan_private.room_tasks add column series_id uuid not null default gen_random_uuid(),
  add column version integer not null default 1 check(version>0), add column retired_on date;
update azan_private.room_tasks set series_id=id;
alter table azan_private.room_tasks add constraint task_versions unique(series_id,version);
drop index azan_private.room_task_names;
create unique index active_room_task_names on azan_private.room_tasks(room_id,lower(name)) where retired_on is null;
alter table azan_private.completions add column series_id uuid;
update azan_private.completions c set series_id=t.series_id from azan_private.room_tasks t where t.id=c.task_id;
alter table azan_private.completions alter column series_id set not null,
  drop constraint completions_pkey,add constraint completions_pkey primary key(room_id,user_id,day,series_id);

-- Keep the dashboard payload compatible; completion IDs now identify logical tasks.
do $$ declare definition text; begin
  definition:=pg_get_functiondef('azan_private.dashboard_v2()'::regprocedure);
  if position('jsonb_agg(c.task_id)' in definition)=0 or position('from azan_private.room_tasks t where t.room_id=r.id)' in definition)=0 then
    raise exception 'Unexpected dashboard definition: review the migration';
  end if;
  definition:=replace(definition,'jsonb_agg(c.task_id)','jsonb_agg(c.series_id)');
  definition:=replace(definition,'azan_private.task_due(t.repeats,t.weekdays,t.start_date,today)',
    '(t.retired_on is null and azan_private.task_due(t.repeats,t.weekdays,t.start_date,today))');
  definition:=replace(definition,'from azan_private.room_tasks t where t.room_id=r.id)',
    'from azan_private.room_tasks t where t.room_id=r.id and (t.retired_on is null or
      (not exists(select 1 from azan_private.room_tasks active where active.series_id=t.series_id and active.retired_on is null)
       and t.version=(select max(h.version) from azan_private.room_tasks h where h.series_id=t.series_id)
       and exists(select 1 from azan_private.completions c where c.room_id=r.id and c.series_id=t.series_id and c.day=today))))');
  execute definition;
end $$;

create function azan_private.action_v3(action text,args jsonb) returns void
language plpgsql security definer set search_path='' as $$
declare uid uuid:=auth.uid(); rid uuid; today date:=(now() at time zone 'Africa/Cairo')::date; t azan_private.room_tasks; starts date;
begin
  if uid is null then raise exception 'Please log in';end if;
  if action in ('update_task','remove_task','add_task','complete','uncomplete') then
    rid:=(args->>'room_id')::uuid;
    if action in ('update_task','remove_task','add_task') then
      perform 1 from azan_private.rooms where id=rid and owner_id=uid for update;
      if not found then raise exception 'Only the room owner can do this';end if;
    else
      perform 1 from azan_private.rooms where id=rid for update;
      if not exists(select 1 from azan_private.members where room_id=rid and user_id=uid and status='accepted') then raise exception 'Join this room first';end if;
      if args->>'day' is distinct from today::text then raise exception 'The day has changed. Refresh your tasks.';end if;
    end if;
    if action<>'add_task' then
      select * into t from azan_private.room_tasks where room_id=rid and
        (id=nullif(args->>'task_id','')::uuid or (not args ? 'task_id' and name=args->>'task' and retired_on is null));
      if not found then raise exception 'Task not found';end if;
    end if;
    if action='uncomplete' then
      delete from azan_private.completions where room_id=rid and user_id=uid and day=today and series_id=t.series_id;
    elsif action='complete' then
      if t.retired_on is not null or not azan_private.task_due(t.repeats,t.weekdays,t.start_date,today) then raise exception 'This task is not scheduled today';end if;
      insert into azan_private.completions(room_id,user_id,day,task,task_id,series_id,awarded_points)
        values(rid,uid,today,t.name,t.id,t.series_id,t.points) on conflict do nothing;
    elsif action='remove_task' then
      if t.retired_on is not null then raise exception 'Task changed. Refresh the room.';end if;
      update azan_private.room_tasks set retired_on=today where id=t.id;
    else
      starts:=coalesce((args->>'start_date')::date,today);
      if starts<today then raise exception 'Task start date cannot be in the past';end if;
      if action='add_task' then
        if (select count(*) from azan_private.room_tasks where room_id=rid and retired_on is null)>=50 then raise exception 'A room can have up to 50 tasks';end if;
        insert into azan_private.room_tasks(room_id,name,description,points,repeats,weekdays,start_date)
          values(rid,trim(args->>'name'),trim(coalesce(args->>'description','')),(args->>'points')::int,args->>'repeats',array(select jsonb_array_elements_text(coalesce(args->'weekdays','[]'::jsonb))::int),starts);
      else
        if t.retired_on is not null then raise exception 'Task changed. Refresh the room.';end if;
        update azan_private.room_tasks set retired_on=today where id=t.id;
        insert into azan_private.room_tasks(room_id,name,description,points,repeats,weekdays,start_date,series_id,version)
          values(rid,trim(args->>'name'),trim(coalesce(args->>'description','')),(args->>'points')::int,args->>'repeats',array(select jsonb_array_elements_text(coalesce(args->'weekdays','[]'::jsonb))::int),starts,t.series_id,t.version+1);
      end if;
    end if;
  else perform azan_private.action_v2(action,args);
  end if;
end $$;
revoke all on function azan_private.action_v3(text,jsonb) from public,anon;
grant execute on function azan_private.action_v3(text,jsonb) to authenticated;
revoke execute on function azan_private.action_v2(text,jsonb) from authenticated;
create or replace function public.azan_action(action text,args jsonb default '{}'::jsonb) returns void language sql security invoker set search_path='' as $$ select azan_private.action_v3(action,args) $$;

create or replace function azan_private.build_reports(for_user uuid default null) returns void
language plpgsql security definer set search_path='' as $$
begin
  insert into azan_private.reports(room_id,user_id,week,summary)
  select r.id,recipient.user_id,w.week::date,jsonb_build_object('room_name',r.name,'anchor','friday','ends_on',w.week::date+6,
    'scores',(select coalesce(jsonb_agg(score order by (score->>'points')::int desc),'[]'::jsonb) from (
      select jsonb_build_object('name',p.display_name,'user_id',m.user_id,
        'points',coalesce((select sum(c.awarded_points) from azan_private.completions c where c.room_id=r.id and c.user_id=m.user_id and c.day>=w.week::date and c.day<w.week::date+7),0),
        'tasks',(select coalesce(jsonb_agg(jsonb_build_object('task',name,'done',done,'target',target,'points',points)) filter(where target>0),'[]'::jsonb) from (
          select title.name,title.points,
            (select count(*) from azan_private.completions c where c.room_id=r.id and c.user_id=m.user_id and c.series_id=s.series_id and c.day>=w.week::date and c.day<w.week::date+7) done,
            (select count(*) from generate_series(greatest(w.week::date,(m.joined_at at time zone 'Africa/Cairo')::date),w.week::date+6,interval '1 day') d(day)
              where exists(select 1 from azan_private.room_tasks t where t.room_id=r.id and t.series_id=s.series_id
                and azan_private.task_due(t.repeats,t.weekdays,t.start_date,d.day::date) and (t.retired_on is null or d.day::date<t.retired_on))
                or exists(select 1 from azan_private.completions c where c.room_id=r.id and c.user_id=m.user_id and c.series_id=s.series_id and c.day=d.day::date)) target
          from (select distinct series_id from azan_private.room_tasks where room_id=r.id) s
          cross join lateral(select name,points from azan_private.room_tasks t where t.series_id=s.series_id order by version desc limit 1) title
        ) tasks)) score
      from azan_private.members m join azan_private.profiles p on p.id=m.user_id where m.room_id=r.id and m.status='accepted' and (m.joined_at at time zone 'Africa/Cairo')::date<w.week::date+7
    ) scores))
  from azan_private.rooms r
  cross join lateral generate_series(azan_private.friday_start((r.created_at at time zone 'Africa/Cairo')::date),azan_private.friday_start((now() at time zone 'Africa/Cairo')::date)-7,interval '7 days') w(week)
  join azan_private.members recipient on recipient.room_id=r.id and recipient.status='accepted' and (recipient.joined_at at time zone 'Africa/Cairo')::date<w.week::date+7
  where (for_user is null or recipient.user_id=for_user) and not exists(select 1 from azan_private.reports existing where existing.room_id=r.id and existing.user_id=recipient.user_id and existing.week=w.week::date)
  on conflict do nothing;
end $$;
