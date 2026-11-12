-- ============================================================================
-- Part 2: presentation uploads + organizer dashboard.
-- Run AFTER schema.sql (SQL Editor → New query → paste → Run). Safe to re-run.
-- ============================================================================

-- Each team gets a private 6-digit upload code (organizer exports and shares them).
alter table public.teams add column if not exists upload_key text not null
  default lpad((floor(random() * 1000000))::int::text, 6, '0');

alter table public.state add column if not exists uploads_open boolean not null default true;

create table if not exists public.presentations (
  team_id     int primary key references public.teams(id) on delete cascade,
  file_path   text not null,
  file_name   text not null,
  file_size   bigint not null default 0,
  uploads     int not null default 1,
  uploaded_at timestamptz not null default now()
);
alter table public.presentations enable row level security;   -- private: no policies

drop trigger if exists presentations_bump on public.presentations;
create trigger presentations_bump after insert or update or delete on public.presentations
  for each statement execute function public._bump();

-- Public team list must not reveal upload codes.
revoke select on public.teams from anon, authenticated;
grant select (id, code, project, members, department, round1, created_at) on public.teams to anon, authenticated;

-- ------------------------------------------------------------ storage -------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('presentations', 'presentations', true, 52428800, array[
  'application/vnd.openxmlformats-officedocument.presentationml.presentation',
  'application/vnd.ms-powerpoint',
  'application/pdf'])
on conflict (id) do update set public = excluded.public, file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "presentations upload" on storage.objects;
create policy "presentations upload" on storage.objects for insert to anon, authenticated
  with check (bucket_id = 'presentations');

-- ------------------------------------------------------------- teams --------
create or replace function public.team_check(p_code text, p_key text) returns json
language plpgsql stable security definer set search_path = public as $$
declare t public.teams; p public.presentations; st public.state;
begin
  select * into t from public.teams where upper(code) = upper(trim(p_code)) and upload_key = trim(p_key);
  if t.id is null then return null; end if;
  select * into p from public.presentations where team_id = t.id;
  select * into st from public.state where id = 1;
  return json_build_object('id', t.id, 'code', t.code, 'project', t.project, 'members', t.members,
    'uploads_open', st.uploads_open, 'file_name', p.file_name, 'file_size', p.file_size,
    'uploaded_at', p.uploaded_at, 'uploads', coalesce(p.uploads, 0));
end $$;

create or replace function public.register_presentation(p_code text, p_key text, p_path text, p_name text, p_size bigint)
returns void language plpgsql security definer set search_path = public as $$
declare t public.teams;
begin
  select * into t from public.teams where upper(code) = upper(trim(p_code)) and upload_key = trim(p_key);
  if t.id is null then raise exception 'Wrong team code or upload code'; end if;
  if not (select uploads_open from public.state where id = 1) then raise exception 'Uploads are closed by the organizer'; end if;
  if p_path not like t.code || '/%' then raise exception 'Invalid file path'; end if;
  insert into public.presentations (team_id, file_path, file_name, file_size)
  values (t.id, p_path, p_name, p_size)
  on conflict (team_id) do update set file_path = excluded.file_path, file_name = excluded.file_name,
    file_size = excluded.file_size, uploads = public.presentations.uploads + 1, uploaded_at = now();
end $$;

-- ------------------------------------------------------------- admin --------
create or replace function public.admin_set_state(p_pin text, p_patch jsonb) returns void
language plpgsql security definer set search_path = public as $$
begin
  perform public._require_admin(p_pin);
  update public.state set
    active_round    = coalesce((p_patch ->> 'active_round')::int, active_round),
    current_team_id = case when p_patch ? 'current_team_id' then (p_patch ->> 'current_team_id')::int else current_team_id end,
    scoring_open    = coalesce((p_patch ->> 'scoring_open')::boolean, scoring_open),
    show_scores     = coalesce((p_patch ->> 'show_scores')::boolean, show_scores),
    uploads_open    = coalesce((p_patch ->> 'uploads_open')::boolean, uploads_open),
    view            = coalesce(p_patch ->> 'view', view),
    message         = coalesce(p_patch ->> 'message', message),
    version         = version + 1,
    updated_at      = now()
  where id = 1;
end $$;

create or replace function public.admin_presentations(p_pin text)
returns table (team_id int, code text, project text, members text, upload_key text,
               file_path text, file_name text, file_size bigint, uploads int, uploaded_at timestamptz)
language plpgsql stable security definer set search_path = public as $$
begin
  perform public._require_admin(p_pin);
  return query select t.id, t.code, t.project, t.members, t.upload_key, p.file_path, p.file_name, p.file_size,
                      coalesce(p.uploads, 0), p.uploaded_at
               from public.teams t left join public.presentations p on p.team_id = t.id order by t.code;
end $$;

create or replace function public.admin_activity(p_pin text, p_limit int default 25)
returns table (at timestamptz, kind text, detail text)
language plpgsql stable security definer set search_path = public as $$
begin
  perform public._require_admin(p_pin);
  return query
    (select s.updated_at, 'score'::text,
            r.name || ' · ' || j.name || ' scored ' || t.code || ' (' || t.project || '): ' || s.total::text
     from public.scores s join public.teams t on t.id = s.team_id join public.judges j on j.id = s.judge_id
     join public.rounds r on r.id = s.round_id)
    union all
    (select p.uploaded_at, 'upload'::text, t.code || ' (' || t.project || ') uploaded ' || p.file_name
     from public.presentations p join public.teams t on t.id = p.team_id)
    order by 1 desc limit p_limit;
end $$;

grant execute on function public.team_check(text, text), public.register_presentation(text, text, text, text, bigint),
  public.admin_presentations(text), public.admin_activity(text, int) to anon, authenticated;
