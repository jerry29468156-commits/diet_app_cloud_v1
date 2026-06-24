-- supabase_schema_v1_2_hotfix.sql
-- 飲食紀錄 App 正式雲端版 v1.2 hotfix
-- 目的：修正 Realtime 重複加入錯誤、補齊表結構、清理孤兒資料。

create extension if not exists pgcrypto;

create table if not exists public.user_settings (
  user_id uuid primary key references auth.users(id) on delete cascade,
  kcal_abs numeric not null default 100,
  kcal_pct numeric not null default 5,
  protein_pct numeric not null default 90,
  carbs_pct numeric not null default 15,
  fat_pct numeric not null default 110,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.diet_targets (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  protein numeric not null default 0,
  carbs numeric not null default 0,
  fat numeric not null default 0,
  kcal numeric generated always as ((protein * 4) + (carbs * 4) + (fat * 9)) stored,
  is_default boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.training_types (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  created_at timestamptz not null default now(),
  unique(user_id, name)
);

create table if not exists public.tags (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  created_at timestamptz not null default now(),
  unique(user_id, name)
);

create table if not exists public.foods (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  unit text not null default '一份',
  kcal numeric not null default 0,
  protein numeric not null default 0,
  carbs numeric not null default 0,
  fat numeric not null default 0,
  favorite boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.food_tags (
  food_id uuid not null references public.foods(id) on delete cascade,
  tag_id uuid not null references public.tags(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  primary key(food_id, tag_id)
);

create table if not exists public.daily_metrics (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  log_date date not null,
  target_id uuid references public.diet_targets(id) on delete set null,
  training_type_id uuid references public.training_types(id) on delete set null,
  weight numeric,
  hunger integer check (hunger is null or hunger between 1 and 5),
  note text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(user_id, log_date)
);

create table if not exists public.food_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  log_date date not null,
  food_id uuid not null references public.foods(id) on delete cascade,
  qty numeric not null default 1 check (qty > 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.meal_templates (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.meal_template_items (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  template_id uuid not null references public.meal_templates(id) on delete cascade,
  food_id uuid not null references public.foods(id) on delete cascade,
  qty numeric not null default 1 check (qty > 0)
);

alter table public.user_settings enable row level security;
alter table public.diet_targets enable row level security;
alter table public.training_types enable row level security;
alter table public.tags enable row level security;
alter table public.foods enable row level security;
alter table public.food_tags enable row level security;
alter table public.daily_metrics enable row level security;
alter table public.food_logs enable row level security;
alter table public.meal_templates enable row level security;
alter table public.meal_template_items enable row level security;

DO $$
DECLARE r record;
BEGIN
  FOR r IN SELECT schemaname, tablename, policyname FROM pg_policies WHERE schemaname='public'
  LOOP
    EXECUTE format('drop policy if exists %I on %I.%I', r.policyname, r.schemaname, r.tablename);
  END LOOP;
END $$;

create policy "settings_own" on public.user_settings for all using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "targets_own" on public.diet_targets for all using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "training_own" on public.training_types for all using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "tags_own" on public.tags for all using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "foods_own" on public.foods for all using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "food_tags_own" on public.food_tags for all using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "daily_own" on public.daily_metrics for all using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "logs_own" on public.food_logs for all using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "templates_own" on public.meal_templates for all using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "template_items_own" on public.meal_template_items for all using (user_id = auth.uid()) with check (user_id = auth.uid());

create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end $$;

drop trigger if exists set_updated_at_user_settings on public.user_settings;
create trigger set_updated_at_user_settings before update on public.user_settings for each row execute function public.set_updated_at();
drop trigger if exists set_updated_at_targets on public.diet_targets;
create trigger set_updated_at_targets before update on public.diet_targets for each row execute function public.set_updated_at();
drop trigger if exists set_updated_at_foods on public.foods;
create trigger set_updated_at_foods before update on public.foods for each row execute function public.set_updated_at();
drop trigger if exists set_updated_at_daily on public.daily_metrics;
create trigger set_updated_at_daily before update on public.daily_metrics for each row execute function public.set_updated_at();
drop trigger if exists set_updated_at_logs on public.food_logs;
create trigger set_updated_at_logs before update on public.food_logs for each row execute function public.set_updated_at();
drop trigger if exists set_updated_at_templates on public.meal_templates;
create trigger set_updated_at_templates before update on public.meal_templates for each row execute function public.set_updated_at();

-- 清理孤兒資料：避免 food_logs / meal_template_items 指向不存在的 foods。
delete from public.meal_template_items mti
where not exists (
  select 1 from public.foods f where f.id = mti.food_id
);

delete from public.food_logs fl
where not exists (
  select 1 from public.foods f where f.id = fl.food_id
);

-- Realtime 安全加入：已存在就跳過，不會再出現 already member。
DO $$
DECLARE
  table_name text;
  table_names text[] := ARRAY[
    'user_settings',
    'diet_targets',
    'training_types',
    'tags',
    'foods',
    'food_tags',
    'daily_metrics',
    'food_logs',
    'meal_templates',
    'meal_template_items'
  ];
BEGIN
  FOREACH table_name IN ARRAY table_names
  LOOP
    IF NOT EXISTS (
      SELECT 1
      FROM pg_publication_tables
      WHERE pubname = 'supabase_realtime'
        AND schemaname = 'public'
        AND tablename = table_name
    ) THEN
      EXECUTE format('ALTER PUBLICATION supabase_realtime ADD TABLE public.%I', table_name);
    END IF;
  END LOOP;
END $$;
