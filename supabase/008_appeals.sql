-- Part 8: result appeals. A team submits an appeal with its team code + 6-digit upload code;
-- the organizers review it in admin → Appeals and reply (the team sees the reply on appeal.html).
-- Appeals are private: no public read; only PIN-checked functions can see them.
-- Run once in Supabase → SQL Editor. Safe to run again.

create table if not exists public.appeals (
  id          bigint generated always as identity primary key,
  team_id     int not null references public.teams(id) on delete cascade,
  round_id    int not null references public.rounds(id),
  name        text not null,
  contact     text not null,
  reason      text not null,
  request     text not null default '',
  status      text not null default 'received' check (status in ('received', 'reviewing', 'accepted', 'rejected')),
  reply       text not null default '',
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);
alter table public.appeals enable row level security;   -- no policies = no direct access for anon
revoke all on public.appeals from anon, authenticated;

-- Appeals are accepted until this moment (change it here if needed).
create or replace function public._appeal_deadline() returns timestamptz
language sql immutable as $$ select timestamptz '2026-11-25 23:59:59+05' $$;

create or replace function public.submit_appeal(p_code text, p_key text, p_round int, p_name text,
  p_contact text, p_reason text, p_request text) returns bigint
language plpgsql security definer set search_path = public as $$
declare t public.teams; new_id bigint;
begin
  select * into t from public.teams where upper(code) = upper(trim(p_code)) and upload_key = trim(p_key);
  if t.id is null then raise exception 'Wrong team code or upload code'; end if;
  if now() > public._appeal_deadline() then raise exception 'The appeal period has ended'; end if;
  if p_round not in (1, 2, 3) then raise exception 'Choose a round'; end if;
  if length(trim(coalesce(p_name, ''))) < 2 then raise exception 'Please enter your name'; end if;
  if length(trim(coalesce(p_contact, ''))) < 5 then raise exception 'Please enter a phone number, Telegram or email'; end if;
  if length(trim(coalesce(p_reason, ''))) < 20 then raise exception 'Please explain the reason (at least 20 characters)'; end if;
  if (select count(*) from public.appeals where team_id = t.id) >= 3 then
    raise exception 'Your team has already submitted 3 appeals. Please contact the organizers.';
  end if;
  insert into public.appeals (team_id, round_id, name, contact, reason, request)
  values (t.id, p_round, left(trim(p_name), 120), left(trim(p_contact), 160), left(trim(p_reason), 3000), left(trim(coalesce(p_request, '')), 1000))
  returning id into new_id;
  return new_id;
end $$;
grant execute on function public.submit_appeal(text, text, int, text, text, text, text) to anon, authenticated;

-- The team sees its own appeals and the organizers' reply.
create or replace function public.team_appeals(p_code text, p_key text)
returns table (id bigint, round_id int, reason text, request text, status text, reply text, created_at timestamptz, updated_at timestamptz)
language plpgsql security definer set search_path = public as $$
declare t public.teams;
begin
  select * into t from public.teams where upper(code) = upper(trim(p_code)) and upload_key = trim(p_key);
  if t.id is null then raise exception 'Wrong team code or upload code'; end if;
  return query select a.id, a.round_id, a.reason, a.request, a.status, a.reply, a.created_at, a.updated_at
    from public.appeals a where a.team_id = t.id order by a.id desc;
end $$;
grant execute on function public.team_appeals(text, text) to anon, authenticated;

create or replace function public.admin_appeals(p_pin text)
returns table (id bigint, team_id int, code text, project text, round_id int, name text, contact text, reason text,
               request text, status text, reply text, created_at timestamptz, updated_at timestamptz)
language plpgsql security definer set search_path = public as $$
begin
  perform public._require_admin(p_pin);
  return query select a.id, a.team_id, t.code, t.project, a.round_id, a.name, a.contact, a.reason, a.request,
                      a.status, a.reply, a.created_at, a.updated_at
    from public.appeals a join public.teams t on t.id = a.team_id order by a.id desc;
end $$;
grant execute on function public.admin_appeals(text) to anon, authenticated;

create or replace function public.admin_update_appeal(p_pin text, p_id bigint, p_status text, p_reply text) returns void
language plpgsql security definer set search_path = public as $$
begin
  perform public._require_admin(p_pin);
  update public.appeals set status = p_status, reply = left(coalesce(p_reply, ''), 3000), updated_at = now() where id = p_id;
end $$;
grant execute on function public.admin_update_appeal(text, bigint, text, text) to anon, authenticated;

select 'appeals ready' as result;
