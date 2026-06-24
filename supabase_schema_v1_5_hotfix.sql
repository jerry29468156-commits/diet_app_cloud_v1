-- supabase_schema_v1_5_hotfix.sql
-- v1.5 hotfix：飲食目標新增修正 + 食材清單自訂排序欄位
-- 不重建資料庫；只新增欄位與初始化既有食材排序。

alter table public.foods
add column if not exists sort_order numeric;

with ranked as (
  select
    id,
    row_number() over (
      partition by user_id
      order by coalesce(sort_order, 999999), favorite desc, name, created_at
    ) as rn
  from public.foods
)
update public.foods f
set sort_order = ranked.rn
from ranked
where f.id = ranked.id
  and f.sort_order is null;

-- 確認 foods 在 Realtime publication 中；已加入則跳過。
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'foods'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.foods;
  END IF;
END $$;
