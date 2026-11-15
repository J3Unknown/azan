-- Run against the upgraded project. All test users, rooms and points roll back.
begin;
do $$
declare
  owner_uid uuid:=gen_random_uuid(); member_uid uuid:=gen_random_uuid(); outsider_uid uuid:=gen_random_uuid();
  d jsonb; room jsonb; private_room jsonb; task jsonb; report jsonb; friend_code text; other_code text;
  today text; week_start date; rejected boolean; rid uuid;
begin
  insert into auth.users(id,raw_user_meta_data) values
    (owner_uid,'{"display_name":"Temporary test owner"}'),(member_uid,'{"display_name":"Temporary test member"}'),(outsider_uid,'{"display_name":"Temporary outsider"}');
  perform set_config('request.jwt.claim.sub',owner_uid::text,true);set local role authenticated;
  d:=public.azan_dashboard();today:=d->>'today';
  perform public.azan_action('create','{"name":"Temporary flexible room","use_templates":false}');
  room:=public.azan_dashboard()->'rooms'->0;
  perform public.azan_action('add_task',jsonb_build_object('room_id',room->>'id','name','Custom daily task','description','Temporary test','points',7,'repeats','daily','start_date',today));
  task:=public.azan_dashboard()->'rooms'->0->'tasks'->0;
  if task->>'points'<>'7' then raise exception 'Custom task points failed';end if;
  perform set_config('request.jwt.claim.sub',member_uid::text,true);d:=public.azan_dashboard();friend_code:=d->'profile'->>'friend_code';
  perform public.azan_action('join',jsonb_build_object('ref',room->>'ref'));
  if jsonb_array_length(public.azan_dashboard()->'rooms'->0->'tasks')<>0 then raise exception 'Pending member saw room tasks';end if;
  rejected:=false;begin perform public.azan_action('add_task',jsonb_build_object('room_id',room->>'id','name','Unauthorized','points',99,'repeats','daily'));exception when raise_exception then rejected:=true;end;
  if not rejected then raise exception 'Non-owner added task';end if;
  rejected:=false;begin perform public.azan_action('delete_room',jsonb_build_object('room_id',room->>'id'));exception when raise_exception then rejected:=true;end;
  if not rejected then raise exception 'Non-owner deleted room';end if;
  perform set_config('request.jwt.claim.sub',owner_uid::text,true);
  perform public.azan_action('accept',jsonb_build_object('room_id',room->>'id','user_id',member_uid));
  perform public.azan_action('invite',jsonb_build_object('name','Temporary private challenge','friend_code',friend_code,'use_templates',false));
  select value into private_room from jsonb_array_elements(public.azan_dashboard()->'rooms') where (value->>'private')::boolean;
  if private_room->>'ref' is not null then raise exception 'Private reference exposed';end if;
  perform set_config('request.jwt.claim.sub',outsider_uid::text,true);d:=public.azan_dashboard();other_code:=d->'profile'->>'friend_code';
  if jsonb_array_length(d->'rooms')<>0 then raise exception 'Room privacy failed';end if;
  perform set_config('request.jwt.claim.sub',owner_uid::text,true);
  perform public.azan_action('invite_member',jsonb_build_object('room_id',private_room->>'id','friend_code',other_code));
  perform set_config('request.jwt.claim.sub',outsider_uid::text,true);
  perform public.azan_action('accept',jsonb_build_object('room_id',private_room->>'id'));
  rejected:=false;begin perform 1 from azan_private.room_tasks;exception when insufficient_privilege then rejected:=true;end;
  if not rejected then raise exception 'Direct table access allowed';end if;
  perform set_config('request.jwt.claim.sub',member_uid::text,true);
  perform public.azan_action('complete',jsonb_build_object('room_id',room->>'id','task_id',task->>'id','day',today,'points',999));
  perform public.azan_action('complete',jsonb_build_object('room_id',room->>'id','task_id',task->>'id','day',today));
  perform set_config('request.jwt.claim.sub',owner_uid::text,true);
  -- The public/private ordering can tie within a transaction, so find the room by ID.
  select value into d from jsonb_array_elements(public.azan_dashboard()->'rooms') where value->>'id'=room->>'id';
  select value into d from jsonb_array_elements(d->'members') where value->>'user_id'=member_uid::text;
  if d->>'points_today'<>'7' or jsonb_array_length(d->'completed')<>1 then raise exception 'Member progress, server points or duplicate enforcement failed';end if;
  perform public.azan_action('update_task',jsonb_build_object('room_id',room->>'id','task_id',task->>'id','name','Revised daily task','points',9,'repeats','daily','start_date',today));
  select value into d from jsonb_array_elements(public.azan_dashboard()->'rooms') where value->>'id'=room->>'id';
  select value into task from jsonb_array_elements(d->'tasks') where value->>'name'='Revised daily task';
  perform set_config('request.jwt.claim.sub',member_uid::text,true);
  perform public.azan_action('complete',jsonb_build_object('room_id',room->>'id','task_id',task->>'id','day',today));
  select value into d from jsonb_array_elements(public.azan_dashboard()->'rooms') where value->>'id'=room->>'id';
  select value into d from jsonb_array_elements(d->'members') where value->>'user_id'=member_uid::text;
  if d->>'points_today'<>'7' then raise exception 'Task edit changed previously earned points or allowed duplicate scoring';end if;
  rejected:=false;begin perform public.azan_action('remove_task',jsonb_build_object('room_id',room->>'id','task_id',task->>'id'));exception when raise_exception then rejected:=true;end;
  if not rejected then raise exception 'Non-owner removed a task';end if;
  perform public.azan_action('uncomplete',jsonb_build_object('room_id',room->>'id','task_id',task->>'id','day',today));
  select value into d from jsonb_array_elements(public.azan_dashboard()->'rooms') where value->>'id'=room->>'id';
  if jsonb_array_length(d->'completed')<>0 then raise exception 'Undo did not remove today completion';end if;
  perform public.azan_action('complete',jsonb_build_object('room_id',room->>'id','task_id',task->>'id','day',today));
  perform set_config('request.jwt.claim.sub',owner_uid::text,true);
  perform public.azan_action('remove_task',jsonb_build_object('room_id',room->>'id','task_id',task->>'id'));
  perform set_config('request.jwt.claim.sub',member_uid::text,true);
  perform public.azan_action('uncomplete',jsonb_build_object('room_id',room->>'id','task_id',task->>'id','day',today));
  rejected:=false;begin perform public.azan_action('complete',jsonb_build_object('room_id',room->>'id','task_id',task->>'id','day',today));exception when raise_exception then rejected:=true;end;
  if not rejected then raise exception 'Removed task could be completed';end if;
  perform set_config('request.jwt.claim.sub',owner_uid::text,true);
  perform public.azan_action('add_task',jsonb_build_object('room_id',room->>'id','name','Future task','points',8,'repeats','once','start_date',(today::date+1)::text));
  select value into d from jsonb_array_elements(public.azan_dashboard()->'rooms') where value->>'id'=room->>'id';
  select value into task from jsonb_array_elements(d->'tasks') where value->>'name'='Future task';
  rejected:=false;begin perform public.azan_action('complete',jsonb_build_object('room_id',room->>'id','task_id',task->>'id','day',today));exception when raise_exception then rejected:=true;end;
  if not rejected then raise exception 'Future task completed early';end if;
  reset role;
  week_start:=azan_private.friday_start((now() at time zone 'Africa/Cairo')::date)-7;
  if extract(isodow from week_start)<>5 then raise exception 'Friday anchor failed';end if;
  insert into azan_private.rooms(name,owner_id,created_at) values('Temporary Friday report',owner_uid,week_start) returning id into rid;
  insert into azan_private.members(room_id,user_id,status,joined_at) values(rid,owner_uid,'accepted',week_start),(rid,member_uid,'accepted',week_start+2);
  insert into azan_private.room_tasks(room_id,name,points,repeats,weekdays,start_date) values
    (rid,'Daily test',1,'daily','{}',week_start),(rid,'Friday test',3,'weekly','{5}',week_start),(rid,'Once test',5,'once','{}',week_start+2);
  insert into azan_private.completions(room_id,user_id,day,task,task_id,series_id,awarded_points)
    select rid,owner_uid,d.day::date,t.name,t.id,t.series_id,t.points from azan_private.room_tasks t cross join generate_series(week_start,week_start+6,interval '1 day') d(day)
    where t.room_id=rid and azan_private.task_due(t.repeats,t.weekdays,t.start_date,d.day::date);
  perform azan_private.build_reports(owner_uid);perform azan_private.build_reports(owner_uid);
  set local role authenticated;perform set_config('request.jwt.claim.sub',owner_uid::text,true);
  select value into report from jsonb_array_elements(public.azan_dashboard()->'reports') where value->>'room_id'=rid::text;
  if report->'summary'->>'anchor'<>'friday' or report->'summary'->'scores'->0->>'points'<>'15' then raise exception 'Friday report calculation failed';end if;
  select value into task from jsonb_array_elements(report->'summary'->'scores'->1->'tasks') where value->>'task'='Daily test';
  if task->>'target'<>'5' then raise exception 'Partial week target failed';end if;
  perform public.azan_action('delete_room',jsonb_build_object('room_id',rid));
  perform public.azan_action('delete_room',jsonb_build_object('room_id',room->>'id'));
  reset role;
  if exists(select 1 from azan_private.completions where room_id in (rid,(room->>'id')::uuid)) then raise exception 'Room deletion left orphaned completions';end if;
end $$;
rollback;
select 'PASS: live custom tasks, task edits/removal/undo, preserved points, owner authorization, member progress, invitations, schedules, Friday reports, partial weeks and deletion; test data rolled back.' as result;
