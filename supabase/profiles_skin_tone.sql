-- Fitcheck — add skin tone to profiles. Run ONCE in Supabase SQL Editor. Safe to re-run.
alter table public.profiles add column if not exists skin_tone text;
