# 飲食紀錄 App｜正式雲端版 v1.1

本版已將測試版 v7.3 的主要 UI 與流程移植到 Supabase 架構：

- 多使用者登入 / 註冊
- RLS 使用者資料隔離
- Supabase Realtime 即時同步
- 今日儀表板
- 飲食紀錄
- 食材庫
- 標籤管理與標籤篩選
- 常用食材
- 常用組合
- 用今日紀錄建立組合
- 複製昨日飲食
- 清空今日
- 身體紀錄：體重 / 訓練類型 / 飢餓感 1～5 / 備註
- 長期追蹤
- 趨勢圖
- 每日摘要
- 達標追蹤
- 達標規則雲端儲存

## 安裝
1. 在 Supabase SQL Editor 執行 `supabase_schema_v1_1.sql`。
2. 到 Project Settings > API 複製 Project URL 與 anon public key。
3. 編輯 `app_config.js`。
4. 將 `index.html` 與 `app_config.js` 放同一資料夾，或上傳到 GitHub Pages / Netlify / Vercel。

## 注意
`service_role key` 絕對不要放前端。
