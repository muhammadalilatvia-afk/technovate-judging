-- ============================================================================
-- Ajou Technovate Hackathon — judging database (Supabase / PostgreSQL)
-- Run this whole file once in Supabase: Dashboard → SQL Editor → New query → Run.
-- Safe to re-run: it drops and recreates everything (ALL DATA IS ERASED).
-- ============================================================================

create extension if not exists pgcrypto with schema extensions;

drop view if exists public.leaderboard cascade;
drop view if exists public.judge_progress cascade;
drop table if exists public.scores, public.round_teams, public.state, public.judges,
                     public.criteria, public.teams, public.rounds, public.settings cascade;

-- ---------------------------------------------------------------- tables ----
create table public.rounds (
  id          int primary key,
  name        text not null,
  qualify_top int  not null,          -- how many advance / win
  award_top   int  not null,          -- how many get awards in this round
  description text not null default ''
);
insert into public.rounds values
  (1, 'Round 1', 20, 3,  'IT Business 3rd-year teams · Top 20 qualify · Top 3 win Round 1 prizes'),
  (2, 'Round 2', 5,  10, 'All Ajou University teams · Top 10 get certificates · Top 5 go to the Final'),
  (3, 'Final',   3,  3,  'Top 5 teams compete for 1st, 2nd and 3rd place');

create table public.criteria (
  id          int primary key,
  name        text not null,
  description text not null default '',
  max_points  int  not null default 10,
  position    int  not null default 0
);
insert into public.criteria values
  (1, 'Innovation & Creativity',          'How new and original is the idea?',                         10, 1),
  (2, 'Problem & Real-World Value',       'Does it solve a real, important problem?',                  10, 2),
  (3, 'Feasibility & Technical Execution','Does it work? Quality of the app, website or business model',10, 3),
  (4, 'Market & Impact Potential',        'Market size, users, social or economic impact',             10, 4),
  (5, 'Presentation & Q&A',               'Clarity, confidence, teamwork and answers to judges',       10, 5);

create table public.teams (
  id         serial primary key,
  code       text not null unique,
  project    text not null,
  members    text not null default '',
  department text not null default '',
  round1     boolean not null default false,   -- competes in Round 1
  created_at timestamptz not null default now()
);

create table public.round_teams (
  round_id int not null references public.rounds(id) on delete cascade,
  team_id  int not null references public.teams(id)  on delete cascade,
  position int not null default 0,              -- presentation order
  primary key (round_id, team_id)
);

create table public.judges (
  id       serial primary key,
  name     text not null,
  pin_hash text not null,
  active   boolean not null default true
);

create table public.scores (
  round_id   int not null references public.rounds(id) on delete cascade,
  team_id    int not null references public.teams(id)  on delete cascade,
  judge_id   int not null references public.judges(id) on delete cascade,
  criteria   jsonb   not null,                  -- {"1": 8, "2": 7, ...}
  total      numeric not null,
  comment    text    not null default '',
  updated_at timestamptz not null default now(),
  primary key (round_id, team_id, judge_id)
);

create table public.settings (key text primary key, value text not null);

create table public.state (
  id              int primary key default 1 check (id = 1),
  active_round    int not null default 1 references public.rounds(id),
  current_team_id int references public.teams(id) on delete set null,
  scoring_open    boolean not null default false,
  show_scores     boolean not null default true,
  view            text not null default 'board',   -- welcome | board | podium
  message         text not null default '',
  version         bigint not null default 0,
  updated_at      timestamptz not null default now()
);
insert into public.state (id) values (1);

-- ----------------------------------------------------------------- views ----
-- Aggregated, public: average judge total scaled to 100. Individual scores stay private.
create view public.leaderboard as
select rt.round_id, t.id as team_id, t.code, t.project, t.members, t.department, rt.position,
       count(s.judge_id)::int as judges,
       round(coalesce(avg(s.total), 0) * 100.0 / (select sum(max_points) from public.criteria), 2) as score,
       round(coalesce(avg((s.criteria ->> '1')::numeric), 0), 2) as innovation
from public.round_teams rt
join public.teams t on t.id = rt.team_id
left join public.scores s on s.round_id = rt.round_id and s.team_id = rt.team_id
group by rt.round_id, t.id, rt.position;

create view public.judge_progress as
select j.id as judge_id, j.name, st.active_round as round_id,
       (select count(*) from public.scores s where s.judge_id = j.id and s.round_id = st.active_round)::int as scored,
       exists (select 1 from public.scores s where s.judge_id = j.id and s.round_id = st.active_round
                and s.team_id = st.current_team_id) as scored_current
from public.judges j cross join public.state st
where j.active;

-- ------------------------------------------------------------------ RLS -----
alter table public.rounds      enable row level security;
alter table public.criteria    enable row level security;
alter table public.teams       enable row level security;
alter table public.round_teams enable row level security;
alter table public.state       enable row level security;
alter table public.judges      enable row level security;   -- no policies: private
alter table public.scores      enable row level security;   -- no policies: private
alter table public.settings    enable row level security;   -- no policies: private

create policy "public read" on public.rounds      for select using (true);
create policy "public read" on public.criteria    for select using (true);
create policy "public read" on public.teams       for select using (true);
create policy "public read" on public.round_teams for select using (true);
create policy "public read" on public.state       for select using (true);

grant select on public.leaderboard, public.judge_progress to anon, authenticated;

-- --------------------------------------------- live updates (realtime) ------
create or replace function public._bump() returns trigger language plpgsql security definer
set search_path = public as $$
begin
  update public.state set version = version + 1, updated_at = now() where id = 1;
  return null;
end $$;

create trigger scores_bump      after insert or update or delete on public.scores      for each statement execute function public._bump();
create trigger round_teams_bump after insert or update or delete on public.round_teams for each statement execute function public._bump();
create trigger teams_bump       after insert or update or delete on public.teams       for each statement execute function public._bump();
create trigger judges_bump      after insert or update or delete on public.judges      for each statement execute function public._bump();

do $$ begin
  alter publication supabase_realtime add table public.state;
exception when others then null; end $$;

-- ------------------------------------------------------------- helpers ------
create or replace function public._is_admin(p_pin text) returns boolean
language sql stable security definer set search_path = public, extensions as $$
  select exists (select 1 from public.settings where key = 'admin_pin' and value = crypt(p_pin, value));
$$;

create or replace function public._judge(p_pin text) returns public.judges
language sql stable security definer set search_path = public, extensions as $$
  select * from public.judges where active and pin_hash = crypt(p_pin, pin_hash) limit 1;
$$;

create or replace function public._require_admin(p_pin text) returns void
language plpgsql stable security definer set search_path = public as $$
begin
  if not public._is_admin(p_pin) then raise exception 'Wrong admin PIN'; end if;
end $$;

-- -------------------------------------------------------------- admin -------
create or replace function public.admin_setup(p_pin text) returns boolean
language plpgsql security definer set search_path = public, extensions as $$
begin
  if exists (select 1 from public.settings where key = 'admin_pin') then return false; end if;
  if length(coalesce(p_pin, '')) < 4 then raise exception 'PIN must have at least 4 characters'; end if;
  insert into public.settings values ('admin_pin', crypt(p_pin, gen_salt('bf')));
  return true;
end $$;

create or replace function public.admin_status() returns json
language sql stable security definer set search_path = public as $$
  select json_build_object('configured', exists (select 1 from public.settings where key = 'admin_pin'));
$$;

create or replace function public.admin_check(p_pin text) returns boolean
language sql stable security definer set search_path = public as $$ select public._is_admin(p_pin); $$;

create or replace function public.admin_change_pin(p_pin text, p_new text) returns boolean
language plpgsql security definer set search_path = public, extensions as $$
begin
  perform public._require_admin(p_pin);
  if length(coalesce(p_new, '')) < 4 then raise exception 'PIN must have at least 4 characters'; end if;
  update public.settings set value = crypt(p_new, gen_salt('bf')) where key = 'admin_pin';
  return true;
end $$;

create or replace function public.admin_set_state(p_pin text, p_patch jsonb) returns void
language plpgsql security definer set search_path = public as $$
begin
  perform public._require_admin(p_pin);
  update public.state set
    active_round    = coalesce((p_patch ->> 'active_round')::int, active_round),
    current_team_id = case when p_patch ? 'current_team_id' then (p_patch ->> 'current_team_id')::int else current_team_id end,
    scoring_open    = coalesce((p_patch ->> 'scoring_open')::boolean, scoring_open),
    show_scores     = coalesce((p_patch ->> 'show_scores')::boolean, show_scores),
    view            = coalesce(p_patch ->> 'view', view),
    message         = coalesce(p_patch ->> 'message', message),
    version         = version + 1,
    updated_at      = now()
  where id = 1;
end $$;

-- rows: [{"code","project","members","department","round1"}]
create or replace function public.admin_import_teams(p_pin text, p_rows jsonb, p_replace boolean) returns int
language plpgsql security definer set search_path = public as $$
declare r jsonb; n int := 0;
begin
  perform public._require_admin(p_pin);
  if p_replace then
    update public.state set current_team_id = null where id = 1;
    delete from public.teams;
  end if;
  for r in select * from jsonb_array_elements(p_rows) loop
    insert into public.teams (code, project, members, department, round1)
    values (r ->> 'code', coalesce(r ->> 'project', ''), coalesce(r ->> 'members', ''),
            coalesce(r ->> 'department', ''), coalesce((r ->> 'round1')::boolean, false))
    on conflict (code) do update set project = excluded.project, members = excluded.members,
      department = excluded.department, round1 = excluded.round1;
    n := n + 1;
  end loop;
  return n;
end $$;

create or replace function public.admin_update_team(p_pin text, p_id int, p_patch jsonb) returns void
language plpgsql security definer set search_path = public as $$
begin
  perform public._require_admin(p_pin);
  update public.teams set
    code       = coalesce(p_patch ->> 'code', code),
    project    = coalesce(p_patch ->> 'project', project),
    members    = coalesce(p_patch ->> 'members', members),
    department = coalesce(p_patch ->> 'department', department),
    round1     = coalesce((p_patch ->> 'round1')::boolean, round1)
  where id = p_id;
end $$;

create or replace function public.admin_delete_team(p_pin text, p_id int) returns void
language plpgsql security definer set search_path = public as $$
begin
  perform public._require_admin(p_pin);
  delete from public.teams where id = p_id;
end $$;

-- Replace a round's line-up; array order = presentation order. Existing scores are kept.
create or replace function public.admin_set_round_teams(p_pin text, p_round int, p_team_ids int[]) returns int
language plpgsql security definer set search_path = public as $$
begin
  perform public._require_admin(p_pin);
  delete from public.round_teams where round_id = p_round;
  insert into public.round_teams (round_id, team_id, position)
  select p_round, t.id, t.ord from unnest(p_team_ids) with ordinality as t(id, ord);
  return coalesce(array_length(p_team_ids, 1), 0);
end $$;

create or replace function public.admin_add_judge(p_pin text, p_name text, p_judge_pin text) returns int
language plpgsql security definer set search_path = public, extensions as $$
declare new_id int;
begin
  perform public._require_admin(p_pin);
  if length(coalesce(p_judge_pin, '')) < 4 then raise exception 'Judge PIN must have at least 4 characters'; end if;
  if (public._judge(p_judge_pin)).id is not null then
    raise exception 'This PIN is already used by another judge';
  end if;
  insert into public.judges (name, pin_hash) values (p_name, crypt(p_judge_pin, gen_salt('bf'))) returning id into new_id;
  return new_id;
end $$;

create or replace function public.admin_set_judge_active(p_pin text, p_id int, p_active boolean) returns void
language plpgsql security definer set search_path = public as $$
begin
  perform public._require_admin(p_pin);
  update public.judges set active = p_active where id = p_id;
end $$;

create or replace function public.admin_list_judges(p_pin text)
returns table (id int, name text, active boolean, scores int)
language plpgsql stable security definer set search_path = public as $$
begin
  perform public._require_admin(p_pin);
  return query select j.id, j.name, j.active, (select count(*)::int from public.scores s where s.judge_id = j.id)
               from public.judges j order by j.id;
end $$;

create or replace function public.admin_scores(p_pin text, p_round int)
returns table (team_id int, code text, project text, judge_id int, judge_name text,
               criteria jsonb, total numeric, comment text, updated_at timestamptz)
language plpgsql stable security definer set search_path = public as $$
begin
  perform public._require_admin(p_pin);
  return query select s.team_id, t.code, t.project, s.judge_id, j.name, s.criteria, s.total, s.comment, s.updated_at
               from public.scores s join public.teams t on t.id = s.team_id join public.judges j on j.id = s.judge_id
               where s.round_id = p_round order by t.code, j.id;
end $$;

create or replace function public.admin_reset_round(p_pin text, p_round int) returns int
language plpgsql security definer set search_path = public as $$
declare n int;
begin
  perform public._require_admin(p_pin);
  delete from public.scores where round_id = p_round;
  get diagnostics n = row_count;
  return n;
end $$;

-- -------------------------------------------------------------- judges ------
create or replace function public.judge_login(p_pin text) returns json
language plpgsql stable security definer set search_path = public as $$
declare j public.judges;
begin
  j := public._judge(p_pin);
  if j.id is null then return null; end if;
  return json_build_object('id', j.id, 'name', j.name);
end $$;

create or replace function public.judge_scores(p_pin text, p_round int)
returns table (team_id int, criteria jsonb, total numeric, comment text, updated_at timestamptz)
language plpgsql stable security definer set search_path = public as $$
declare j public.judges;
begin
  j := public._judge(p_pin);
  if j.id is null then raise exception 'Wrong judge PIN'; end if;
  return query select s.team_id, s.criteria, s.total, s.comment, s.updated_at
               from public.scores s where s.judge_id = j.id and s.round_id = p_round;
end $$;

create or replace function public.submit_score(p_pin text, p_round int, p_team int, p_criteria jsonb, p_comment text)
returns numeric language plpgsql security definer set search_path = public as $$
declare j public.judges; st public.state; c record; v numeric; tot numeric := 0; clean jsonb := '{}'::jsonb;
begin
  j := public._judge(p_pin);
  if j.id is null then raise exception 'Wrong judge PIN'; end if;
  select * into st from public.state where id = 1;
  if not st.scoring_open then raise exception 'Scoring is closed by the organizer'; end if;
  if p_round <> st.active_round then raise exception 'This round is not active'; end if;
  if not exists (select 1 from public.round_teams where round_id = p_round and team_id = p_team) then
    raise exception 'Team is not in this round';
  end if;
  for c in select * from public.criteria order by position loop
    v := (p_criteria ->> c.id::text)::numeric;
    if v is null then raise exception 'Missing score for "%"', c.name; end if;
    if v < 0 or v > c.max_points then raise exception 'Score for "%" must be 0–%', c.name, c.max_points; end if;
    clean := clean || jsonb_build_object(c.id::text, v);
    tot := tot + v;
  end loop;
  insert into public.scores (round_id, team_id, judge_id, criteria, total, comment, updated_at)
  values (p_round, p_team, j.id, clean, tot, coalesce(p_comment, ''), now())
  on conflict (round_id, team_id, judge_id) do update
    set criteria = excluded.criteria, total = excluded.total, comment = excluded.comment, updated_at = now();
  return tot;
end $$;

-- ------------------------------------------------------------- grants -------
revoke all on function public._is_admin(text), public._judge(text), public._require_admin(text), public._bump() from public, anon, authenticated;
grant execute on function
  public.admin_setup(text), public.admin_status(), public.admin_check(text), public.admin_change_pin(text, text),
  public.admin_set_state(text, jsonb), public.admin_import_teams(text, jsonb, boolean),
  public.admin_update_team(text, int, jsonb), public.admin_delete_team(text, int),
  public.admin_set_round_teams(text, int, int[]), public.admin_add_judge(text, text, text),
  public.admin_set_judge_active(text, int, boolean), public.admin_list_judges(text),
  public.admin_scores(text, int), public.admin_reset_round(text, int),
  public.judge_login(text), public.judge_scores(text, int),
  public.submit_score(text, int, int, jsonb, text)
to anon, authenticated;
