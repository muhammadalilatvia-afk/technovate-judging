-- Part 6: Round 1 → top 15 teams qualify for Round 2 (was 20).
-- Run once in Supabase → SQL Editor. Safe to run again.
update public.rounds
   set qualify_top = 15,
       description = 'IT Business 3rd-year teams · Top 15 qualify · Top 3 win Round 1 prizes'
 where id = 1;
select id, name, qualify_top, description from public.rounds order by id;
