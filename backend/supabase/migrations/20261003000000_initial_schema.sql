create extension if not exists pgcrypto;

create table if not exists public.user_preferences (
  user_id uuid primary key references auth.users(id) on delete cascade,
  meal_type text,
  dietary_goal text,
  meal_time text,
  amount_people text,
  restrict_diet text,
  preferred_region text,
  skill_level text,
  kitchen_tools text[] not null default '{}',
  height_cm integer,
  weight_kg integer,
  age integer,
  gender text,
  fitness_goal text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.history (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  image_url text,
  recipe_html text not null,
  recipe_title text,
  main_image_url text,
  video_url text,
  meal_type text,
  dietary_goal text,
  meal_time text,
  amount_people text,
  restrict_diet text,
  detected_items jsonb not null default '[]'::jsonb,
  tags text[] not null default '{}',
  preferred_region text,
  skill_level text,
  kitchen_tools text[] not null default '{}',
  nutrition_info jsonb,
  other_note text,
  created_at timestamptz not null default now()
);

create index if not exists history_user_created_at_idx
  on public.history (user_id, created_at desc);

create table if not exists public.saved_recipes (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  recipe_title text,
  recipe_content text not null,
  image_url text,
  main_image_url text,
  meal_type text,
  dietary_goal text,
  meal_time text,
  amount_people text,
  restrict_diet text,
  is_fitness_mode boolean not null default false,
  nutrition_info jsonb,
  created_at timestamptz not null default now()
);

create index if not exists saved_recipes_user_created_at_idx
  on public.saved_recipes (user_id, created_at desc);

alter table public.user_preferences enable row level security;
alter table public.history enable row level security;
alter table public.saved_recipes enable row level security;

create policy "Users can read their preferences"
  on public.user_preferences for select
  using (auth.uid() = user_id);
create policy "Users can insert their preferences"
  on public.user_preferences for insert
  with check (auth.uid() = user_id);
create policy "Users can update their preferences"
  on public.user_preferences for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "Users can read their history"
  on public.history for select
  using (auth.uid() = user_id);
create policy "Users can delete their history"
  on public.history for delete
  using (auth.uid() = user_id);

create policy "Users can read their saved recipes"
  on public.saved_recipes for select
  using (auth.uid() = user_id);
create policy "Users can save recipes"
  on public.saved_recipes for insert
  with check (auth.uid() = user_id);
create policy "Users can delete their saved recipes"
  on public.saved_recipes for delete
  using (auth.uid() = user_id);

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'food-images',
  'food-images',
  true,
  5242880,
  array['image/jpeg', 'image/png', 'image/webp', 'image/gif']
)
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

create policy "Anyone can view food images"
  on storage.objects for select
  using (bucket_id = 'food-images');
create policy "Anyone can upload food images"
  on storage.objects for insert
  to anon, authenticated
  with check (bucket_id = 'food-images');
