-- ============================================================================
-- Part 4: team photos (shown on the live screen, judge pages and organizer panel).
-- Run after 003. Safe to re-run.
-- ============================================================================
alter table public.teams add column if not exists photo_path text;
alter table public.teams add column if not exists photo_at timestamptz;
grant select (photo_path) on public.teams to anon, authenticated;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('team-photos', 'team-photos', true, 8388608, array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do update set public = excluded.public, file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "team photos upload" on storage.objects;
create policy "team photos upload" on storage.objects for insert to anon, authenticated
  with check (bucket_id = 'team-photos');

-- Leaderboard now also carries the team photo (column appended at the end).
create or replace view public.leaderboard as
select rt.round_id, t.id as team_id, t.code, t.project, t.members, t.department, rt.position,
       count(s.judge_id)::int as judges,
       round(coalesce(avg(s.total), 0) * 100.0 / (select sum(max_points) from public.criteria), 2) as score,
       round(coalesce(avg((s.criteria ->> '1')::numeric), 0), 2) as innovation,
       t.photo_path
from public.round_teams rt
join public.teams t on t.id = rt.team_id
left join public.scores s on s.round_id = rt.round_id and s.team_id = rt.team_id
group by rt.round_id, t.id, rt.position;
grant select on public.leaderboard to anon, authenticated;

create or replace function public.register_photo(p_code text, p_key text, p_path text)
returns void language plpgsql security definer set search_path = public as $$
declare t public.teams;
begin
  select * into t from public.teams where upper(code) = upper(trim(p_code)) and upload_key = trim(p_key);
  if t.id is null then raise exception 'Wrong team code or upload code'; end if;
  if not (select uploads_open from public.state where id = 1) then raise exception 'Uploads are closed by the organizer'; end if;
  if p_path not like t.code || '/%' then raise exception 'Invalid file path'; end if;
  update public.teams set photo_path = p_path, photo_at = now() where id = t.id;
end $$;

-- Organizer can remove an unsuitable photo.
create or replace function public.admin_clear_photo(p_pin text, p_team int) returns void
language plpgsql security definer set search_path = public as $$
begin
  perform public._require_admin(p_pin);
  update public.teams set photo_path = null, photo_at = null where id = p_team;
end $$;

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
    'uploaded_at', p.uploaded_at, 'uploads', coalesce(p.uploads, 0),
    'photo_path', t.photo_path, 'photo_at', t.photo_at);
end $$;

drop function if exists public.admin_presentations(text);
create function public.admin_presentations(p_pin text)
returns table (team_id int, code text, project text, members text, upload_key text,
               file_path text, file_name text, file_size bigint, uploads int, uploaded_at timestamptz,
               photo_path text, photo_at timestamptz)
language plpgsql stable security definer set search_path = public as $$
begin
  perform public._require_admin(p_pin);
  return query select t.id, t.code, t.project, t.members, t.upload_key, p.file_path, p.file_name, p.file_size,
                      coalesce(p.uploads, 0), p.uploaded_at, t.photo_path, t.photo_at
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
    union all
    (select t.photo_at, 'photo'::text, t.code || ' (' || t.project || ') uploaded a team photo'
     from public.teams t where t.photo_at is not null)
    order by 1 desc limit p_limit;
end $$;

grant execute on function public.register_photo(text, text, text), public.admin_clear_photo(text, int),
  public.team_check(text, text), public.admin_presentations(text), public.admin_activity(text, int) to anon, authenticated;
