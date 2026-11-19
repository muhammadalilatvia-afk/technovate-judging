-- Part 9: certificate downloads. Each team logs in on certificates.html with its team code + 6-digit upload code
-- and gets download links for its members' certificates (participation + place).
-- Files live in the public "certificates" bucket under random folder names; the list of files is in the
-- private table public.certificates, readable only through team_certificates() with the right codes.
-- Run once in Supabase → SQL Editor. Safe to run again.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('certificates', 'certificates', true, 5242880, array['application/pdf'])
on conflict (id) do update set public = true, file_size_limit = 5242880, allowed_mime_types = array['application/pdf'];

create table if not exists public.certificates (
  id         bigint generated always as identity primary key,
  team_id    int not null references public.teams(id) on delete cascade,
  person     text not null,
  kind       text not null,          -- 'participation' | 'place'
  title      text not null,
  file_path  text not null,          -- path inside the "certificates" bucket
  sort       int not null default 0
);
alter table public.certificates enable row level security;   -- no policies: not readable directly
revoke all on public.certificates from anon, authenticated;

create or replace function public.team_certificates(p_code text, p_key text)
returns table (person text, kind text, title text, file_path text)
language plpgsql security definer set search_path = public as $$
declare t public.teams;
begin
  select * into t from public.teams where upper(code) = upper(trim(p_code)) and upload_key = trim(p_key);
  if t.id is null then raise exception 'Wrong team code or upload code'; end if;
  return query select c.person, c.kind, c.title, c.file_path from public.certificates c
    where c.team_id = t.id order by c.person, c.sort, c.id;
end $$;
grant execute on function public.team_certificates(text, text) to anon, authenticated;

-- Uploads: only files whose path is already registered in public.certificates can be uploaded
-- (registered by the organizer through the SQL Editor), so the bucket is not open to anyone else.
create or replace function public._certificate_expected(p_name text) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.certificates where file_path = p_name);
$$;
grant execute on function public._certificate_expected(text) to anon, authenticated;
drop policy if exists "certificates upload (registered paths only)" on storage.objects;
create policy "certificates upload (registered paths only)" on storage.objects for insert to anon, authenticated
  with check (bucket_id = 'certificates' and public._certificate_expected(name));

select 'certificates ready' as result;
