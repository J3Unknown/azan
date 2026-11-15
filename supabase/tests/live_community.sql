-- Rollback-only live integration test. No emails are sent and no data persists.
begin;
do $$
declare
  owner_uid uuid := gen_random_uuid();
  member_uid uuid := gen_random_uuid();
  outsider_uid uuid := gen_random_uuid();
  dashboard jsonb; room jsonb; private_room jsonb; report jsonb; friend_code text;
  today text; week_start date; rejected boolean;
begin
  insert into auth.users(id,raw_user_meta_data) values
    (owner_uid,'{"display_name":"Integration owner"}'),
    (member_uid,'{"display_name":"Integration member"}'),
    (outsider_uid,'{"display_name":"Integration outsider"}');
  perform set_config('request.jwt.claim.sub',owner_uid::text,true);
  set local role authenticated;
  dashboard := public.azan_dashboard();
  today := dashboard->>'today';
  perform public.azan_action('create','{"name":"Rollback-only integration room"}');
  room := public.azan_dashboard()->'rooms'->0;
  if room->>'status' <> 'accepted' then raise exception 'Owner membership failed'; end if;
  rejected := false;
  begin perform 1 from azan_private.rooms; exception when insufficient_privilege then rejected:=true; end;
  if not rejected then raise exception 'Direct table access was allowed'; end if;

  perform set_config('request.jwt.claim.sub',member_uid::text,true);
  dashboard := public.azan_dashboard();
  friend_code := dashboard->'profile'->>'friend_code';
  if jsonb_array_length(dashboard->'rooms') <> 0 then raise exception 'Room privacy failed'; end if;
  perform public.azan_action('join',jsonb_build_object('ref',room->>'ref'));
  rejected:=false;
  begin
    perform public.azan_action('complete',jsonb_build_object('room_id',room->>'id','day',today,'task','Fajr'));
  exception when raise_exception then rejected:=true; end;
  if not rejected then raise exception 'Pending member earned points'; end if;
  perform set_config('request.jwt.claim.sub',outsider_uid::text,true);
  perform public.azan_dashboard();
  rejected:=false;
  begin
    perform public.azan_action('accept',jsonb_build_object('room_id',room->>'id','user_id',member_uid));
  exception when raise_exception then rejected:=true; end;
  if not rejected then raise exception 'Outsider approved a request'; end if;

  perform set_config('request.jwt.claim.sub',owner_uid::text,true);
  perform public.azan_action('accept',jsonb_build_object('room_id',room->>'id','user_id',member_uid));
  perform public.azan_action('invite',jsonb_build_object('name','Rollback private challenge','friend_code',friend_code));
  select value into private_room from jsonb_array_elements(public.azan_dashboard()->'rooms') where (value->>'private')::boolean;
  if not (private_room->>'private')::boolean then raise exception 'Private room not created'; end if;
  perform set_config('request.jwt.claim.sub',outsider_uid::text,true);
  rejected:=false;
  begin perform public.azan_action('join',jsonb_build_object('ref',private_room->>'ref'));
  exception when raise_exception then rejected:=true; end;
  if not rejected then raise exception 'Private room allowed reference joining'; end if;
  perform set_config('request.jwt.claim.sub',member_uid::text,true);
  perform public.azan_action('accept',jsonb_build_object('room_id',private_room->>'id'));
  perform public.azan_action('complete',jsonb_build_object('room_id',room->>'id','day',today,'task','Fajr'));
  perform public.azan_action('complete',jsonb_build_object('room_id',room->>'id','day',today,'task','Fajr'));
  select value into dashboard from jsonb_array_elements(public.azan_dashboard()->'rooms') where value->>'id'=room->>'id';
  if jsonb_array_length(dashboard->'completed')<>1 then raise exception 'Duplicate completion earned extra points'; end if;
  rejected:=false;
  begin perform public.azan_action('complete',jsonb_build_object('room_id',room->>'id','day','2000-01-01','task','Isha'));
  exception when raise_exception then rejected:=true; end;
  if not rejected then raise exception 'Backdated completion allowed'; end if;
  rejected:=false;
  begin perform public.azan_action('profile',jsonb_build_object('name','Integration member','avatar_path',owner_uid::text||'/avatar.png'));
  exception when raise_exception then rejected:=true; end;
  if not rejected then raise exception 'Cross-account avatar reference allowed'; end if;
  rejected:=false;
  begin perform azan_private.build_reports(); exception when insufficient_privilege then rejected:=true; end;
  if not rejected then raise exception 'Unrestricted report generator allowed'; end if;

  reset role;
  week_start := (date_trunc('week',now() at time zone 'Africa/Cairo')-interval '1 week')::date;
  update azan_private.rooms set created_at=week_start where id=(room->>'id')::uuid;
  update azan_private.members set joined_at=week_start where room_id=(room->>'id')::uuid;
  update azan_private.members set joined_at=week_start+interval '3 days' where room_id=(room->>'id')::uuid and user_id=member_uid;
  insert into azan_private.completions(room_id,user_id,day,task)
    select (room->>'id')::uuid,owner_uid,week_start+day,task
    from generate_series(0,6) day cross join unnest(array['Fajr','Dhuhr','Asr','Maghrib','Isha','Daily Quran','Daily supplications']) task;
  insert into azan_private.completions(room_id,user_id,day,task)
    select (room->>'id')::uuid,member_uid,week_start+day,'Daily Quran' from generate_series(3,5) day;
  perform azan_private.build_reports(owner_uid);
  perform azan_private.build_reports(owner_uid);
  set local role authenticated;
  perform set_config('request.jwt.claim.sub',owner_uid::text,true);
  dashboard := public.azan_dashboard();
  if jsonb_array_length(dashboard->'reports')<>1 then raise exception 'Report deduplication failed'; end if;
  report:=dashboard->'reports'->0;
  if (report->'summary'->'scores'->0->>'points')::int<>70 then raise exception 'Weekly points calculation failed'; end if;
  if (report->'summary'->'scores'->1->>'points')::int<>6 then raise exception 'Member points calculation failed'; end if;
  select value into dashboard from jsonb_array_elements(report->'summary'->'scores'->1->'tasks') where value->>'task'='Daily Quran';
  if (dashboard->>'done')::int<>3 or (dashboard->>'target')::int<>4 then raise exception 'Partial week calculation failed'; end if;
  perform set_config('request.jwt.claim.sub',outsider_uid::text,true);
  if jsonb_array_length(public.azan_dashboard()->'reports')<>0 then raise exception 'Reports leaked to outsider'; end if;
  perform set_config('request.jwt.claim.sub','',true);
  rejected:=false;
  begin perform public.azan_dashboard(); exception when raise_exception then rejected:=true; end;
  if not rejected then raise exception 'Unauthenticated dashboard access allowed'; end if;
  reset role;
end $$;
rollback;
select 'PASS: live role permissions, join approval, private challenges, daily completion, duplicate/date enforcement, photo ownership, weekly points, partial weeks and report privacy; test data rolled back.' as result;
