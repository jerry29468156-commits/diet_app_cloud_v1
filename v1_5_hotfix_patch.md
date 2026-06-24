# v1.5 hotfix patch：飲食目標新增修正 + 食材清單自訂排序

## 這次修正什麼

1. 修正「飲食目標只能新增一項，新增第二項沒有反應」。
2. 新增 `foods.sort_order` 欄位，讓食材清單可以自訂排序。
3. 食材清單新增「上移 / 下移」按鈕。
4. 新增食材時會自動排在食材清單最後。

---

# 一、先執行 SQL

請到 Supabase SQL Editor 執行 `supabase_schema_v1_5_hotfix.sql`。

---

# 二、index.html 修改位置

## 1. 在全域變數附近新增

找到：

```js
let session=null,user=null,channel=null,selected=null,comboDraft=[],refreshing=false;
```

改成：

```js
let session=null,user=null,channel=null,selected=null,comboDraft=[],refreshing=false,editingNewTarget=false;
```

---

## 2. 替換 loadFoods

請將原本的 `loadFoods()` 整個替換成：

```js
async function loadFoods(){
  let f = await table('foods')
    .select('*')
    .order('sort_order', { ascending: true, nullsFirst: false })
    .order('name');

  if (f.error) throw f.error;
  state.foods = f.data || [];

  let ft = await table('food_tags').select('*');
  if (ft.error) throw ft.error;
  state.foodTags = ft.data || [];
}
```

---

## 3. 新增排序工具函式

放在 `foodTags(foodId)` 後面或 `renderFoodResults()` 前面：

```js
function sortedFoods(){
  return [...state.foods].sort((a,b)=>{
    const ao = a.sort_order ?? 999999;
    const bo = b.sort_order ?? 999999;
    if (ao !== bo) return ao - bo;
    return String(a.name || '').localeCompare(String(b.name || ''), 'zh-Hant');
  });
}

async function moveFood(id, dir){
  const arr = sortedFoods();
  const i = arr.findIndex(x => x.id === id);
  const j = i + dir;

  if (i < 0 || j < 0 || j >= arr.length) return;

  const a = arr[i];
  const b = arr[j];
  const ao = a.sort_order ?? (i + 1);
  const bo = b.sort_order ?? (j + 1);

  setSync('排序中');

  const r1 = await table('foods')
    .update({ sort_order: bo })
    .eq('id', a.id)
    .eq('user_id', uid());
  if (r1.error) return err(r1.error);

  const r2 = await table('foods')
    .update({ sort_order: ao })
    .eq('id', b.id)
    .eq('user_id', uid());
  if (r2.error) return err(r2.error);

  a.sort_order = bo;
  b.sort_order = ao;
  renderAll();
  await afterMutation();
}

function nextFoodSortOrder(){
  const nums = state.foods
    .map(f => Number(f.sort_order))
    .filter(n => Number.isFinite(n));
  return nums.length ? Math.max(...nums) + 1 : 1;
}
```

---

## 4. 替換 renderFoodList

請將原本的 `renderFoodList()` 整個替換成：

```js
function renderFoodList(){
  let q = $('foodManageSearch').value.trim();
  let arr = sortedFoods().filter(f =>
    !q ||
    f.name.includes(q) ||
    f.unit.includes(q) ||
    foodTags(f.id).some(t => t.includes(q))
  );

  $('foodCount').textContent = arr.length + ' 筆';

  $('foodList').innerHTML = arr.map((f, idx) => `
    <div class="item">
      <div class="info">
        <div class="name">${f.favorite ? '★ ' : ''}${f.name}</div>
        <div class="meta">${f.unit}｜${f.kcal} kcal｜P ${f.protein} / C ${f.carbs} / F ${f.fat}</div>
        <div class="tagline">${foodTags(f.id).map(t => `<span class="pill green">${t}</span>`).join('')}</div>
      </div>
      <div class="row wrap">
        <button class="sec" onclick="moveFood('${f.id}',-1)" ${idx===0?'disabled':''}>上移</button>
        <button class="sec" onclick="moveFood('${f.id}',1)" ${idx===arr.length-1?'disabled':''}>下移</button>
        <button class="sec" onclick="editFood('${f.id}')">編輯</button>
        <button class="dan" onclick="deleteFood('${f.id}')">刪除</button>
      </div>
    </div>
  `).join('');
}
```

---

## 5. 替換 renderFoodResults

請將原本的 `renderFoodResults()` 裡面的：

```js
let arr=state.foods.filter(...)
```

改成使用 `sortedFoods()`：

```js
let arr = sortedFoods().filter(f =>
  (!q || f.name.includes(q) || f.unit.includes(q)) &&
  (!fav || f.favorite) &&
  (!tag || foodHasTag(f.id, tag))
);
```

如果你想整個函式替換，使用這版：

```js
function renderFoodResults(){
  let q = $('foodSearch').value.trim();
  let fav = $('favoriteFilter').value;
  let tag = $('tagFilter').value;

  let arr = sortedFoods().filter(f =>
    (!q || f.name.includes(q) || f.unit.includes(q)) &&
    (!fav || f.favorite) &&
    (!tag || foodHasTag(f.id, tag))
  );

  $('foodResults').innerHTML = arr.length ? arr.map(f => `
    <div class="item">
      <div class="info">
        <div class="name">${f.favorite ? '★ ' : ''}${f.name}</div>
        <div class="meta">${f.unit}｜${f.kcal} kcal｜P ${f.protein} / C ${f.carbs} / F ${f.fat}</div>
        <div class="tagline">${foodTags(f.id).map(t => `<span class="pill green">${t}</span>`).join('')}</div>
      </div>
      <div class="row">
        <button class="sec" onclick="toggleFav('${f.id}',${!f.favorite})">${f.favorite ? '取消' : '常用'}</button>
        <button onclick="selectFood('${f.id}')">選</button>
      </div>
    </div>
  `).join('') : '<div class="empty">找不到食材</div>';
}
```

---

## 6. 替換 saveFood

請將原本的 `saveFood()` 整個替換成：

```js
async function saveFood(){
  let id = $('editingFoodId').value;
  let existing = state.foods.find(x => x.id === id);

  let row = {
    user_id: uid(),
    name: $('fName').value.trim(),
    unit: $('fUnit').value.trim() || '一份',
    kcal: num($('fKcal').value),
    protein: num($('fProtein').value),
    carbs: num($('fCarbs').value),
    fat: num($('fFat').value),
    favorite: $('fFavorite').checked,
    sort_order: existing?.sort_order ?? nextFoodSortOrder()
  };

  if (!row.name) return alert('請輸入食物名稱');

  let q = id
    ? table('foods').update(row).eq('id', id).eq('user_id', uid()).select()
    : table('foods').insert(row).select();

  let { data, error } = await q;
  if (error) return err(error);

  let saved = first(data);
  if (!saved) return alert('食材儲存失敗，資料庫沒有回傳結果，請確認 RLS 權限');

  await table('food_tags').delete().eq('food_id', saved.id).eq('user_id', uid());

  let tids = checkedTagIds();
  if (tids.length) {
    let r = await table('food_tags').insert(tids.map(tag_id => ({
      user_id: uid(),
      food_id: saved.id,
      tag_id
    })));
    if (r.error) return err(r.error);
  }

  clearFoodForm();
  await afterMutation();
}
```

---

## 7. 修正飲食目標新增第二項無反應

### 7-1. 替換 newTarget

```js
function newTarget(){
  editingNewTarget = true;
  $('targetEdit').value = '';
  $('tName').value = '自訂日';
  $('tProtein').value = 170;
  $('tCarbs').value = 180;
  $('tFat').value = 55;
  $('tKcal').value = targetKcal(170,180,55);
}
```

### 7-2. 替換 saveTarget

```js
async function saveTarget(){
  let id = editingNewTarget ? '' : $('targetEdit').value;

  let row = {
    user_id: uid(),
    name: $('tName').value.trim() || '自訂日',
    protein: num($('tProtein').value),
    carbs: num($('tCarbs').value),
    fat: num($('tFat').value)
  };

  let q = id
    ? table('diet_targets').update(row).eq('id', id).eq('user_id', uid())
    : table('diet_targets').insert(row);

  let { error } = await q;
  if (error) return err(error);

  editingNewTarget = false;
  await afterMutation();
}
```

### 7-3. 在 loadTargetForm 最前面加一行

```js
function loadTargetForm(){
  editingNewTarget = false;
  // 原本內容繼續...
}
```

完整：

```js
function loadTargetForm(){
  editingNewTarget = false;
  let t = state.targets.find(x => x.id === $('targetEdit').value);
  if (!t) return;
  $('tName').value = t.name;
  $('tProtein').value = t.protein;
  $('tCarbs').value = t.carbs;
  $('tFat').value = t.fat;
  $('tKcal').value = t.kcal;
}
```
