-- ============================================================================
-- Part 3: rename a judge or give them a new PIN. Run after 002. Safe to re-run.
-- ============================================================================
create or replace function public.admin_update_judge(p_pin text, p_id int, p_name text, p_new_pin text)
returns void language plpgsql security definer set search_path = public, extensions as $$
declare other public.judges;
begin
  perform public._require_admin(p_pin);
  if coalesce(trim(p_name), '') <> '' then
    update public.judges set name = trim(p_name) where id = p_id;
  end if;
  if coalesce(p_new_pin, '') <> '' then
    if length(p_new_pin) < 4 then raise exception 'Judge PIN must have at least 4 characters'; end if;
    other := public._judge(p_new_pin);
    if other.id is not null and other.id <> p_id then raise exception 'This PIN is already used by another judge'; end if;
    update public.judges set pin_hash = crypt(p_new_pin, gen_salt('bf')) where id = p_id;
  end if;
end $$;

grant execute on function public.admin_update_judge(text, int, text, text) to anon, authenticated;
