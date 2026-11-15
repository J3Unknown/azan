-- Temporary users and all test data roll back; no authentication emails are sent.
begin;
do $$
declare
  host uuid:=gen_random_uuid(); guest uuid:=gen_random_uuid(); outsider uuid:=gen_random_uuid();
  room jsonb; task jsonb; today text; denied boolean;
begin
  insert into auth.users(id,raw_user_meta_data) values
    (host,'{"display_name":"Removal test host"}'),
    (guest,'{"display_name":"Removal test guest"}'),
    (outsider,'{"display_name":"Removal test outsider"}');
  perform set_config('request.jwt.claim.sub',host::text,true);set local role authenticated;
  today:=public.azan_dashboard()->>'today';
  perform public.azan_action('create','{"name":"Temporary removal test","use_templates":false}');
  room:=public.azan_dashboard()->'rooms'->0;
  perform public.azan_action('add_task',jsonb_build_object('room_id',room->>'id','name','Test task','points',7,'repeats','daily','start_date',today));
  task:=public.azan_dashboard()->'rooms'->0->'tasks'->0;
  perform set_config('request.jwt.claim.sub',guest::text,true);perform public.azan_dashboard();
  perform public.azan_action('join',jsonb_build_object('ref',room->>'ref'));
  perform set_config('request.jwt.claim.sub',host::text,true);
  perform public.azan_action('accept',jsonb_build_object('room_id',room->>'id','user_id',guest));
  perform set_config('request.jwt.claim.sub',guest::text,true);
  perform public.azan_action('complete',jsonb_build_object('room_id',room->>'id','task_id',task->>'id','day',today));
  denied:=false;
  begin perform public.azan_action('remove_member',jsonb_build_object('room_id',room->>'id','user_id',host));
  exception when raise_exception then denied:=true;end;
  if not denied then raise exception 'Non-owner removal allowed';end if;
  perform set_config('request.jwt.claim.sub',outsider::text,true);
  denied:=false;
  begin perform public.azan_action('remove_member',jsonb_build_object('room_id',room->>'id','user_id',guest));
  exception when raise_exception then denied:=true;end;
  if not denied then raise exception 'Outsider removal allowed';end if;
  perform set_config('request.jwt.claim.sub',host::text,true);
  denied:=false;
  begin perform public.azan_action('remove_member',jsonb_build_object('room_id',room->>'id','user_id',host));
  exception when raise_exception then denied:=true;end;
  if not denied then raise exception 'Owner self-removal allowed';end if;
  perform public.azan_action('remove_member',jsonb_build_object('room_id',room->>'id','user_id',guest));
  perform set_config('request.jwt.claim.sub',guest::text,true);
  if jsonb_array_length(public.azan_dashboard()->'rooms')<>0 then raise exception 'Removed member retained room access';end if;
  denied:=false;
  begin perform public.azan_action('complete',jsonb_build_object('room_id',room->>'id','task_id',task->>'id','day',today));
  exception when raise_exception then denied:=true;end;
  if not denied then raise exception 'Removed member completed a task';end if;
  denied:=false;
  begin perform public.azan_action('uncomplete',jsonb_build_object('room_id',room->>'id','task_id',task->>'id','day',today));
  exception when raise_exception then denied:=true;end;
  if not denied then raise exception 'Removed member undid a task';end if;
  perform public.azan_action('join',jsonb_build_object('ref',room->>'ref'));
  if public.azan_dashboard()->'rooms'->0->>'status'<>'pending' then raise exception 'Rejoin bypassed approval';end if;
  reset role;
  if not exists(select 1 from azan_private.completions where room_id=(room->>'id')::uuid and user_id=guest and awarded_points=7) then
    raise exception 'Removal lost completion history';
  end if;
end $$;
rollback;
