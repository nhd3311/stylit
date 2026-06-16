-- Fitcheck — Wardrobe setup. Run ONCE in Supabase → SQL Editor.
-- Safe to re-run (idempotent).

-- 1) Table: wardrobe_items
create table if not exists public.wardrobe_items (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  name text not null,
  category text not null,
  image_path text,
  created_at timestamptz not null default now()
);

alter table public.wardrobe_items enable row level security;

drop policy if exists "wardrobe_select_own" on public.wardrobe_items;
create policy "wardrobe_select_own" on public.wardrobe_items
  for select using (auth.uid() = user_id);

drop policy if exists "wardrobe_insert_own" on public.wardrobe_items;
create policy "wardrobe_insert_own" on public.wardrobe_items
  for insert with check (auth.uid() = user_id);

drop policy if exists "wardrobe_update_own" on public.wardrobe_items;
create policy "wardrobe_update_own" on public.wardrobe_items
  for update using (auth.uid() = user_id);

drop policy if exists "wardrobe_delete_own" on public.wardrobe_items;
create policy "wardrobe_delete_own" on public.wardrobe_items
  for delete using (auth.uid() = user_id);

-- 2) Storage bucket: wardrobe (public read)
insert into storage.buckets (id, name, public)
values ('wardrobe', 'wardrobe', true)
on conflict (id) do nothing;

-- 3) Storage policies: anyone reads; users write/delete only inside their own folder
drop policy if exists "wardrobe_obj_read" on storage.objects;
create policy "wardrobe_obj_read" on storage.objects
  for select using (bucket_id = 'wardrobe');

drop policy if exists "wardrobe_obj_insert_own" on storage.objects;
create policy "wardrobe_obj_insert_own" on storage.objects
  for insert with check (
    bucket_id = 'wardrobe'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "wardrobe_obj_delete_own" on storage.objects;
create policy "wardrobe_obj_delete_own" on storage.objects
  for delete using (
    bucket_id = 'wardrobe'
    and (storage.foldername(name))[1] = auth.uid()::text
  );
