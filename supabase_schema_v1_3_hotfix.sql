-- supabase_schema_v1_3_hotfix.sql
-- 不重建資料庫，只清理孤兒資料與確認 Realtime。

delete from public.meal_template_items mti
where not exists (
  select 1 from public.foods f where f.id = mti.food_id
);

delete from public.food_logs fl
where not exists (
  select 1 from public.foods f where f.id = fl.food_id
);

delete from public.food_tags ft
where not exists (
  select 1 from public.foods f where f.id = ft.food_id
)
or not exists (
  select 1 from public.tags t where t.id = ft.tag_id
);

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
