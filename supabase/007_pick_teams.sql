-- Part 7: organizer can PICK any team into Round 2 (or the Final), in addition to the qualifiers.
-- Picked teams stay in the line-up even when the round is rebuilt automatically.
-- Also sets Round 1 → top 15 qualify (same as 006). Run once in Supabase → SQL Editor. Safe to run again.

update public.rounds
   set qualify_top = 15,
       description = 'IT Business 3rd-year teams · Top 15 qualify · Top 3 win Round 1 prizes'
 where id = 1;

create table if not exists public.round_picks (
  round_id int not null references public.rounds(id) on delete cascade,
  team_id  int not null references public.teams(id)  on delete cascade,
  primary key (round_id, team_id)
);
alter table public.round_picks enable row level security;
drop policy if exists "public read" on public.round_picks;
create policy "public read" on public.round_picks for select using (true);
grant select on public.round_picks to anon, authenticated;

-- Replace the picked teams of a round; picked teams are added to the end of its line-up,
-- un-picked teams are removed from it.
create or replace function public.admin_set_picks(p_pin text, p_round int, p_team_ids int[]) returns int
language plpgsql security definer set search_path = public as $$
declare old int[];
begin
  perform public._require_admin(p_pin);
  if p_round not in (2, 3) then raise exception 'Teams can only be picked for Round 2 or the Final'; end if;
  p_team_ids := coalesce(p_team_ids, '{}');
  select coalesce(array_agg(team_id), '{}') into old from public.round_picks where round_id = p_round;
  delete from public.round_teams where round_id = p_round and team_id = any(old) and not (team_id = any(p_team_ids));
  delete from public.round_picks where round_id = p_round;
  insert into public.round_picks (round_id, team_id) select p_round, unnest(p_team_ids) on conflict do nothing;
  insert into public.round_teams (round_id, team_id, position)
  select p_round, t.id, (select coalesce(max(position), 0) from public.round_teams where round_id = p_round) + t.ord
  from unnest(p_team_ids) with ordinality as t(id, ord)
  where not exists (select 1 from public.round_teams x where x.round_id = p_round and x.team_id = t.id);
  return array_length(p_team_ids, 1);
end $$;
grant execute on function public.admin_set_picks(text, int, int[]) to anon, authenticated;

-- Automatic build of the next round now keeps the picked teams.
create or replace function public._build_next_round(p_round int) returns int
language plpgsql security definer set search_path = public as $$
declare nxt int := p_round + 1; ids int[];
begin
  if p_round not in (1, 2) then return 0; end if;
  if exists (select 1 from public.scores where round_id = nxt) then return 0; end if;  -- next round already started
  ids := public._qualifiers(p_round);
  ids := ids || coalesce((select array_agg(team_id order by team_id) from public.round_picks
                          where round_id = nxt and not (team_id = any(ids))), '{}');
  if p_round = 1 then
    ids := ids || coalesce((select array_agg(id order by code) from public.teams
                            where not round1 and not (id = any(ids))), '{}');
  end if;
  if ids = coalesce((select array_agg(team_id order by position) from public.round_teams where round_id = nxt), '{}') then
    return 0;  -- unchanged
  end if;
  delete from public.round_teams where round_id = nxt;
  insert into public.round_teams (round_id, team_id, position)
  select nxt, t.id, t.ord from unnest(ids) with ordinality as t(id, ord);
  return coalesce(array_length(ids, 1), 0);
end $$;
revoke all on function public._build_next_round(int) from public, anon, authenticated;

select id, name, qualify_top from public.rounds order by id;
