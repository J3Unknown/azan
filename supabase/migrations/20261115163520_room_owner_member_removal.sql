-- Keep membership records so removing access does not cascade-delete history.
create function azan_private.action_v5(action text,args jsonb) returns void
language plpgsql security definer set search_path='' as $$
declare uid uuid:=auth.uid(); rid uuid; target uuid;
begin
  if uid is null then raise exception 'Please log in';end if;
  if action='remove_member' then
    rid:=(args->>'room_id')::uuid;
    target:=(args->>'user_id')::uuid;
    -- Serialize removal with completions and other membership changes.
    perform 1 from azan_private.rooms where id=rid and owner_id=uid for update;
    if not found then raise exception 'Only the room owner can remove members';end if;
    if target=uid then raise exception 'The room owner cannot be removed';end if;
    update azan_private.members set status='declined'
      where room_id=rid and user_id=target and status='accepted';
    if not found then raise exception 'Member is no longer in this room';end if;
  else
    perform azan_private.action_v4(action,args);
  end if;
end $$;
revoke all on function azan_private.action_v5(text,jsonb) from public,anon;
grant execute on function azan_private.action_v5(text,jsonb) to authenticated;
revoke execute on function azan_private.action_v4(text,jsonb) from authenticated;
create or replace function public.azan_action(action text,args jsonb default '{}'::jsonb)
returns void language sql security invoker set search_path='' as $$
  select azan_private.action_v5(action,args)
$$;
