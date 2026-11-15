-- Retire photo storage. Do not delete Storage metadata directly: objects must
-- be deleted through the Storage API. This project's bucket was verified empty.
drop policy if exists azan_avatar_select on storage.objects;
drop policy if exists azan_avatar_insert on storage.objects;
drop policy if exists azan_avatar_update on storage.objects;
create policy azan_photos_retired on storage.objects as restrictive for all to anon,authenticated
  using(bucket_id<>'azan-avatars') with check(bucket_id<>'azan-avatars');

create function azan_private.action_v4(action text,args jsonb) returns void
language plpgsql security definer set search_path='' as $$
declare uid uuid:=auth.uid();
begin
  if uid is null then raise exception 'Please log in';end if;
  if action='profile' then
    if args ? 'avatar_path' then raise exception 'Profile photos are no longer supported';end if;
    update azan_private.profiles set display_name=trim(args->>'name') where id=uid;
  else perform azan_private.action_v3(action,args);
  end if;
end $$;
revoke all on function azan_private.action_v4(text,jsonb) from public,anon;
grant execute on function azan_private.action_v4(text,jsonb) to authenticated;
revoke execute on function azan_private.action_v3(text,jsonb) from authenticated;
create or replace function public.azan_action(action text,args jsonb default '{}'::jsonb) returns void language sql security invoker set search_path='' as $$ select azan_private.action_v4(action,args) $$;
alter table azan_private.profiles drop column avatar_path;
