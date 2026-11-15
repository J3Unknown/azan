-- Cover ownership lookups and make the RPC-only table access model explicit.
create index rooms_owner_created on azan_private.rooms(owner_id,created_at);
create policy rpc_only on azan_private.profiles for all to authenticated using(false) with check(false);
create policy rpc_only on azan_private.rooms for all to authenticated using(false) with check(false);
create policy rpc_only on azan_private.members for all to authenticated using(false) with check(false);
create policy rpc_only on azan_private.completions for all to authenticated using(false) with check(false);
create policy rpc_only on azan_private.reports for all to authenticated using(false) with check(false);
