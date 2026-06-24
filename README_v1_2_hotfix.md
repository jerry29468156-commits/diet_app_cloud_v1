# 飲食紀錄 App｜正式雲端版 v1.2 hotfix

## 修正內容

1. 修正 `food_logs_food_id_fkey`：新增飲食、複製昨日、常用組合加入今日時，都會先檢查 `food_id` 是否仍存在於 `foods`。
2. 修正 `Cannot coerce the result to a single JSON object`：移除 `.single()`，改用安全的 `select()` + `data[0]`。
3. 常用組合會過濾已刪除食材，避免把孤兒 `food_id` 寫入 `food_logs`。
4. SQL 改成 Realtime 安全加入，不會因 already member 報錯。
5. SQL 內含孤兒資料清理：`meal_template_items` 與 `food_logs`。
6. `index.html` 引用 `app_config.js?v=1.2.0`，降低 GitHub Pages 快取問題。

## 升級步驟

1. 在 Supabase SQL Editor 執行 `supabase_schema_v1_2_hotfix.sql`。
2. 將 GitHub repo 的 `index.html` 替換成此版。
3. 保留或更新 `app_config.js`。
4. GitHub Pages 上線後，瀏覽器使用 Ctrl+F5 強制重新整理。

## 注意

- 不需要重建資料庫。
- 不需要刪除既有資料。
- `service_role key` 不可放到前端。
