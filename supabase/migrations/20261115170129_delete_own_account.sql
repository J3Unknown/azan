-- Coordinate snapshot generation with deletion so erased scores cannot reappear.
alter function azan_private.build_reports(uuid) rename to build_reports_before_account_deletion;
create function azan_private.build_reports(for_user uuid default null) returns void
language plpgsql security definer set search_path='' as $$
begin
  lock table azan_private.reports in share row exclusive mode;
  perform azan_private.build_reports_before_account_deletion(for_user);
end $$;
revoke all on function azan_private.build_reports(uuid) from public,anon,authenticated;

-- Hold this lock through each RPC so deletion cannot race an account operation.
create function azan_private.require_active_account() returns void
language plpgsql security definer set search_path='' as $$
begin
  perform 1 from auth.users where id=auth.uid() for key share;
  if not found then raise exception 'Please log in';end if;
end $$;
revoke all on function azan_private.require_active_account() from public,anon;
grant execute on function azan_private.require_active_account() to authenticated;

create or replace function public.azan_dashboard() returns jsonb
language plpgsql security invoker set search_path='' as $$
begin
  perform azan_private.require_active_account();
  return azan_private.dashboard_v2();
end $$;
create or replace function public.azan_action(action text,args jsonb default '{}'::jsonb) returns void
language plpgsql security invoker set search_path='' as $$
begin
  perform azan_private.require_active_account();
  perform azan_private.action_v5(action,args);
end $$;

-- No target-user parameter: the authenticated caller can only delete themselves.
create function azan_private.delete_own_account(confirmation text) returns void
language plpgsql security definer set search_path='' as $$
declare uid uuid:=auth.uid();
begin
  if confirmation is distinct from 'DELETE' then raise exception 'Type DELETE to confirm';end if;
  if uid is null then raise exception 'Please log in';end if;
  perform 1 from auth.users where id=uid for update;
  if not found then raise exception 'Please log in';end if;
  lock table azan_private.reports in share row exclusive mode;
  -- Lock shared rooms in a stable order, coordinating with room/task mutations.
  perform 1 from azan_private.rooms r where r.owner_id=uid or exists(
    select 1 from azan_private.members m where m.room_id=r.id and m.user_id=uid
  ) order by r.id for update;
  delete from azan_private.rooms where owner_id=uid;
  -- Other recipients' report snapshots embed names, IDs and worship history.
  update azan_private.reports r set summary=jsonb_set(r.summary,'{scores}',
    coalesce((select jsonb_agg(score order by ordinal)
      from jsonb_array_elements(r.summary->'scores') with ordinality s(score,ordinal)
      where score->>'user_id' is distinct from uid::text),'[]'::jsonb))
    where exists(select 1 from jsonb_array_elements(r.summary->'scores') s where s->>'user_id'=uid::text);
  -- Cascades to profile, memberships, completions, own reports, identities and
  -- auth sessions/refresh tokens. All operations commit or roll back together.
  delete from auth.users where id=uid;
end $$;
revoke all on function azan_private.delete_own_account(text) from public,anon;
grant execute on function azan_private.delete_own_account(text) to authenticated;
create function public.azan_delete_account(confirmation text) returns void
language sql security invoker set search_path='' as $$
  select azan_private.delete_own_account(confirmation)
$$;
revoke all on function public.azan_delete_account(text) from public,anon;
grant execute on function public.azan_delete_account(text) to authenticated;
