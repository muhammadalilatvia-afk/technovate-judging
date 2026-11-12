-- ============================================================================
-- Part 5: automatic advancement.
-- When every team in Round 1 has been scored by every active judge, the top 20
-- (plus all teams that skip Round 1) are placed into Round 2 automatically.
-- When Round 2 is complete, the top 5 are placed into the Final.
-- The next round's line-up keeps updating if a judge corrects a score, until the
-- next round receives its first score. Run after 004. Safe to re-run.
-- ============================================================================

create or replace function public._round_complete(p_round int) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.round_teams where round_id = p_round)
     and (select count(*) from public.judges where active) > 0
     and not exists (
       select 1 from public.round_teams rt
       where rt.round_id = p_round
         and (select count(*) from public.scores s join public.judges j on j.id = s.judge_id and j.active
              where s.round_id = p_round and s.team_id = rt.team_id)
             < (select count(*) from public.judges where active));
$$;

-- Ordered qualifiers of a round (same ranking as the website: score, then innovation, then code).
create or replace function public._qualifiers(p_round int) returns int[]
language sql stable security definer set search_path = public as $$
  select coalesce(array_agg(team_id order by score desc, innovation desc, code), '{}')
  from (select team_id, score, innovation, code from public.leaderboard
        where round_id = p_round and judges > 0
        order by score desc, innovation desc, code
        limit (select qualify_top from public.rounds where id = p_round)) q;
$$;

create or replace function public._build_next_round(p_round int) returns int
language plpgsql security definer set search_path = public as $$
declare nxt int := p_round + 1; ids int[];
begin
  if p_round not in (1, 2) then return 0; end if;
  if exists (select 1 from public.scores where round_id = nxt) then return 0; end if;  -- next round already started
  ids := public._qualifiers(p_round);
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

create or replace function public._auto_advance() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if public._round_complete(1) then perform public._build_next_round(1); end if;
  if public._round_complete(2) then perform public._build_next_round(2); end if;
  return null;
end $$;

drop trigger if exists scores_auto_advance on public.scores;
create trigger scores_auto_advance after insert or update or delete on public.scores
  for each statement execute function public._auto_advance();

-- Public status for the screens: is each round complete, and how many are in the next round.
create or replace function public.round_status() returns json
language sql stable security definer set search_path = public as $$
  select json_agg(json_build_object(
    'round_id', r.id,
    'complete', public._round_complete(r.id),
    'teams', (select count(*) from public.round_teams where round_id = r.id),
    'scored_all', (select count(*) from public.round_teams rt where rt.round_id = r.id
                   and (select count(*) from public.scores s join public.judges j on j.id = s.judge_id and j.active
                        where s.round_id = r.id and s.team_id = rt.team_id) >= (select count(*) from public.judges where active))
  ) order by r.id) from public.rounds r;
$$;

revoke all on function public._round_complete(int), public._qualifiers(int), public._build_next_round(int), public._auto_advance() from public, anon, authenticated;
grant execute on function public.round_status() to anon, authenticated;
