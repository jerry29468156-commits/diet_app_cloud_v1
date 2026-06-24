-- supabase_schema_v2_2_stable.sql
-- v2.2 穩定使用版：PWA 不需資料表；此 SQL 補食材營養快照與排序欄位。

alter table public.foods
add column if not exists sort_order numeric;

alter table public.food_logs
add column if not exists food_name_snapshot text,
add column if not exists unit_snapshot text,
add column if not exists kcal_snapshot numeric,
add column if not exists protein_snapshot numeric,
add column if not exists carbs_snapshot numeric,
add column if not exists fat_snapshot numeric;

with ranked as (
  select id,
         row_number() over (
           partition by user_id
           order by coalesce(sort_order,999999), favorite desc, name, created_at
         ) rn
  from public.foods
)
update public.foods f
set sort_order = ranked.rn
from ranked
where f.id = ranked.id
  and f.sort_order is null;

update public.food_logs l
set food_name_snapshot = coalesce(l.food_name_snapshot, f.name),
    unit_snapshot = coalesce(l.unit_snapshot, f.unit),
    kcal_snapshot = coalesce(l.kcal_snapshot, f.kcal),
    protein_snapshot = coalesce(l.protein_snapshot, f.protein),
    carbs_snapshot = coalesce(l.carbs_snapshot, f.carbs),
    fat_snapshot = coalesce(l.fat_snapshot, f.fat)
from public.foods f
where l.food_id = f.id
  and l.user_id = f.user_id
  and (
    l.food_name_snapshot is null
    or l.unit_snapshot is null
    or l.kcal_snapshot is null
    or l.protein_snapshot is null
    or l.carbs_snapshot is null
    or l.fat_snapshot is null
  );
