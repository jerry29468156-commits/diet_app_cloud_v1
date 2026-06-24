# v1.3 hotfix：刪除功能修正補丁

## 問題原因
目前 v1.2 的刪除功能大多只送出 Supabase delete，然後等待 Realtime 回推畫面。若 Realtime 延遲、瀏覽器快取、或資料有關聯 FK，畫面就會出現「要重新整理才消失」、「時而顯示時而不顯示」。

v1.3 修正方向：
1. 刪除成功後立即更新前端 state。
2. 再重新讀取 Supabase。
3. 刪除父資料前先清理依賴資料。
4. 避免刪除所有食材後又被 seedIfEmpty 補回預設食材。

---

## 1. 在 bootstrapLite 後面新增這個 helper

請在 `async function bootstrapLite(){...}` 後面加入：

```js
async function afterMutation(){
  setSync('同步中');
  await reloadAll();
  renderAll();
  loadBodyForm();
  setSync('已同步');
}
```

---

## 2. 替換刪除飲食紀錄 delLog

```js
async function delLog(id){
  const { error } = await table('food_logs')
    .delete()
    .eq('id', id)
    .eq('user_id', uid());

  if (error) return err(error);

  state.logs = state.logs.filter(x => x.id !== id);
  renderAll();
  await afterMutation();
}
```

---

## 3. 替換刪除食材 deleteFood

```js
async function deleteFood(id){
  if (!confirm('確定刪除食材？此動作會一併刪除相關飲食紀錄與常用組合項目。')) return;

  setSync('刪除中');

  const r1 = await table('food_tags')
    .delete()
    .eq('food_id', id)
    .eq('user_id', uid());
  if (r1.error) return err(r1.error);

  const r2 = await table('meal_template_items')
    .delete()
    .eq('food_id', id)
    .eq('user_id', uid());
  if (r2.error) return err(r2.error);

  const r3 = await table('food_logs')
    .delete()
    .eq('food_id', id)
    .eq('user_id', uid());
  if (r3.error) return err(r3.error);

  const r4 = await table('foods')
    .delete()
    .eq('id', id)
    .eq('user_id', uid());
  if (r4.error) return err(r4.error);

  state.foods = state.foods.filter(x => x.id !== id);
  state.foodTags = state.foodTags.filter(x => x.food_id !== id);
  state.logs = state.logs.filter(x => x.food_id !== id);
  state.templateItems = state.templateItems.filter(x => x.food_id !== id);

  renderAll();
  await afterMutation();
}
```

---

## 4. 替換刪除標籤 deleteTag

```js
async function deleteTag(id){
  if (!confirm('確定刪除標籤？食材不會被刪除，只會移除此標籤關聯。')) return;

  setSync('刪除中');

  const r1 = await table('food_tags')
    .delete()
    .eq('tag_id', id)
    .eq('user_id', uid());
  if (r1.error) return err(r1.error);

  const r2 = await table('tags')
    .delete()
    .eq('id', id)
    .eq('user_id', uid());
  if (r2.error) return err(r2.error);

  state.tags = state.tags.filter(x => x.id !== id);
  state.foodTags = state.foodTags.filter(x => x.tag_id !== id);

  renderAll();
  await afterMutation();
}
```

---

## 5. 替換刪除訓練類型 deleteTraining

```js
async function deleteTraining(id){
  if (!confirm('確定刪除訓練類型？既有每日紀錄會改為未指定訓練類型。')) return;

  setSync('刪除中');

  const u = await table('daily_metrics')
    .update({ training_type_id: null })
    .eq('training_type_id', id)
    .eq('user_id', uid());
  if (u.error) return err(u.error);

  const d = await table('training_types')
    .delete()
    .eq('id', id)
    .eq('user_id', uid());
  if (d.error) return err(d.error);

  state.trainingTypes = state.trainingTypes.filter(x => x.id !== id);
  Object.values(state.metrics).forEach(m => {
    if (m.training_type_id === id) m.training_type_id = null;
  });

  renderAll();
  await afterMutation();
}
```

---

## 6. 替換刪除飲食目標 deleteTarget

```js
async function deleteTarget(){
  const id = $('targetEdit').value;
  if (!id) return;
  if (state.targets.length <= 1) return alert('至少需要保留一個飲食目標');
  if (!confirm('確定刪除？使用此目標的每日紀錄會改為未指定目標。')) return;

  setSync('刪除中');

  const u = await table('daily_metrics')
    .update({ target_id: null })
    .eq('target_id', id)
    .eq('user_id', uid());
  if (u.error) return err(u.error);

  const d = await table('diet_targets')
    .delete()
    .eq('id', id)
    .eq('user_id', uid());
  if (d.error) return err(d.error);

  state.targets = state.targets.filter(x => x.id !== id);
  Object.values(state.metrics).forEach(m => {
    if (m.target_id === id) m.target_id = null;
  });

  renderAll();
  await afterMutation();
}
```

---

## 7. 替換刪除常用組合 deleteTemplate

```js
async function deleteTemplate(id){
  if (!confirm('確定刪除此常用組合？')) return;

  setSync('刪除中');

  const r1 = await table('meal_template_items')
    .delete()
    .eq('template_id', id)
    .eq('user_id', uid());
  if (r1.error) return err(r1.error);

  const r2 = await table('meal_templates')
    .delete()
    .eq('id', id)
    .eq('user_id', uid());
  if (r2.error) return err(r2.error);

  state.templates = state.templates.filter(x => x.id !== id);
  state.templateItems = state.templateItems.filter(x => x.template_id !== id);

  renderAll();
  await afterMutation();
}
```

---

## 8. 替換清空今日 clearToday

```js
async function clearToday(){
  const d = currentDate();
  if (!confirm('清空今日紀錄？')) return;

  const { error } = await table('food_logs')
    .delete()
    .eq('log_date', d)
    .eq('user_id', uid());

  if (error) return err(error);

  state.logs = state.logs.filter(x => x.log_date !== d);
  renderAll();
  await afterMutation();
}
```

---

## 9. 修正 seedIfEmpty 避免刪光後又補回預設食材

請先把 state 增加：

```js
hasSettings:false
```

並把 loadSettings 改成：

```js
async function loadSettings(){
  const { data, error } = await table('user_settings').select('*').maybeSingle();
  if (error) throw error;
  state.hasSettings = !!data;
  if (data) {
    state.rules = {
      kcalAbs: data.kcal_abs,
      kcalPct: data.kcal_pct,
      proteinPct: data.protein_pct,
      carbsPct: data.carbs_pct,
      fatPct: data.fat_pct
    };
  }
}
```

然後把 seedIfEmpty 第一行改成：

```js
async function seedIfEmpty(){
  if (state.hasSettings) return;
  // 原本的建立預設資料放在這下面
}
```

---

## 10. GitHub Pages 快取

建議把 title 和顯示文字改為 v1.3，並把：

```html
<script src="./app_config.js?v=1.2.0"></script>
```

改成：

```html
<script src="./app_config.js?v=1.3.0"></script>
```
