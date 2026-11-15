-- All fixtures and deletions roll back. No real accounts are deleted.
begin;
do $$
declare
  deleted_uid uuid:=gen_random_uuid(); other_uid uuid:=gen_random_uuid();
  owned jsonb; shared jsonb; task jsonb; today text; denied boolean;
begin
  insert into auth.users(id,raw_user_meta_data) values
    (deleted_uid,'{"display_name":"Temporary deletion test"}'),
    (other_uid,'{"display_name":"Temporary remaining account"}');
  insert into auth.sessions(id,user_id) values(gen_random_uuid(),deleted_uid);
  perform set_config('request.jwt.claim.sub',deleted_uid::text,true);set local role authenticated;
  today:=public.azan_dashboard()->>'today';
  perform public.azan_action('create','{"name":"Temporary owned room","use_templates":false}');
  owned:=public.azan_dashboard()->'rooms'->0;
  perform set_config('request.jwt.claim.sub',other_uid::text,true);perform public.azan_dashboard();
  perform public.azan_action('create','{"name":"Temporary shared room","use_templates":false}');
  shared:=public.azan_dashboard()->'rooms'->0;
  perform public.azan_action('add_task',jsonb_build_object('room_id',shared->>'id','name','Temporary task','points',7,'repeats','daily','start_date',today));
  task:=public.azan_dashboard()->'rooms'->0->'tasks'->0;
  perform set_config('request.jwt.claim.sub',deleted_uid::text,true);
  perform public.azan_action('join',jsonb_build_object('ref',shared->>'ref'));
  perform set_config('request.jwt.claim.sub',other_uid::text,true);
  perform public.azan_action('accept',jsonb_build_object('room_id',shared->>'id','user_id',deleted_uid));
  perform set_config('request.jwt.claim.sub',deleted_uid::text,true);
  perform public.azan_action('complete',jsonb_build_object('room_id',shared->>'id','task_id',task->>'id','day',today));
  denied:=false;begin perform public.azan_delete_account('wrong');exception when raise_exception then denied:=true;end;
  if not denied then raise exception 'Deletion without confirmation allowed';end if;
  reset role;
  insert into azan_private.reports(room_id,user_id,week,summary) values
    ((shared->>'id')::uuid,other_uid,'2000-01-07',jsonb_build_object('scores',jsonb_build_array(
      jsonb_build_object('user_id',deleted_uid,'name','Temporary deletion test','points',7),
      jsonb_build_object('user_id',other_uid,'name','Temporary remaining account','points',3))));
  set local role authenticated;
  perform public.azan_delete_account('DELETE');
  denied:=false;begin perform public.azan_dashboard();exception when raise_exception then denied:=true;end;
  if not denied then raise exception 'Deleted account token could access dashboard';end if;
  denied:=false;begin perform public.azan_action('create','{"name":"Stale token room"}');exception when raise_exception then denied:=true;end;
  if not denied then raise exception 'Deleted account token could mutate data';end if;
  reset role;
  if exists(select 1 from auth.users where id=deleted_uid)
    or exists(select 1 from auth.sessions where user_id=deleted_uid)
    or exists(select 1 from azan_private.profiles where id=deleted_uid)
    or exists(select 1 from azan_private.rooms where owner_id=deleted_uid)
    or exists(select 1 from azan_private.members where user_id=deleted_uid)
    or exists(select 1 from azan_private.completions where user_id=deleted_uid)
    or exists(select 1 from azan_private.reports where user_id=deleted_uid)
  then raise exception 'Account data was retained';end if;
  if not exists(select 1 from auth.users where id=other_uid)
    or not exists(select 1 from azan_private.rooms where id=(shared->>'id')::uuid)
    or not exists(select 1 from azan_private.room_tasks where id=(task->>'id')::uuid)
  then raise exception 'Other account data was deleted';end if;
  if exists(select 1 from azan_private.reports r cross join lateral jsonb_array_elements(r.summary->'scores') score where score->>'user_id'=deleted_uid::text)
  then raise exception 'Report retained deleted user data';end if;
  if not exists(select 1 from azan_private.reports r cross join lateral jsonb_array_elements(r.summary->'scores') score where r.room_id=(shared->>'id')::uuid and score->>'user_id'=other_uid::text and score->>'points'='3')
  then raise exception 'Other user report entry was lost';end if;
  perform set_config('request.jwt.claim.sub',other_uid::text,true);set local role authenticated;
  perform public.azan_dashboard();
end $$;
rollback;
