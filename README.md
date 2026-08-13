# Six-Node Skill Graph Prototype

這是一個參考《夢境迴響 DreamEcho》與動作 RPG 模組化技能觀念的 Godot 4 原型。它不複製遊戲內容或美術，重點是驗證「每個 Concept 都有明確語意」的六節點自由技能分支圖、2.5D 固定視角戰鬥與一致事件處理。

## 操作

- `WASD` 或方向鍵：以鏡頭方向移動
- 滑鼠：地面瞄準
- 滑鼠左鍵或 `Space`：施放手動根技能
- `Shift`：Dash
- `Q`：模擬玩家受傷，測試「受傷時」Trigger
- `R`：重置全部木樁

畫面頂部平常只有六格單列。每格顯示節點編號、Concept 與父節點，例如 `4 冰環 ↳3`；點擊格子才展開短編輯器，可選 Concept、父節點及 Trigger 條件。正常清單只提供當下能完整編譯的候選；開啟「顯示全部」後，不相容項目會變灰並顯示原因。

預設圖：

```text
1 火球（手動根）
├─ 2 命中分裂
├─ 3 暴擊時
│  └─ 4 冰環
└─ 5 擊殺時
   └─ 6 召喚核心
```

## 編譯規則

- 全圖固定六格，恰好一個由攻擊鍵施放的 Skill 根節點。
- 每個非空節點只有一個父節點，允許同一 Skill 一對多分支，禁止循環與孤立節點。
- Emitter、Action、Pattern、Modifier、Effect 直接指定所屬 Skill。
- 命中／暴擊／擊殺 Trigger 指定來源 Skill，後續 Skill 指定 Trigger 為父節點。
- 受傷與 Dash Trigger 接玩家事件根，不占額外畫面節點。
- Action、Emitter、Pattern 依固定階段先編譯，再套用 Modifier、Effect 與數值 Clamp。
- Pattern 透過 Projectile、Damage、Melee、Summon Adapter 解譯；缺少 Adapter 的配對不會出現在正常清單。
- 同一技能不能重複裝備同一 Concept；未知欄位、型別、operation 或無 Runtime operation ID 會讓整圖編譯失敗。
- Effect 是附加狀態，不改寫技能原始元素。物理重斬附加中毒或爆炸後仍然是物理技能。
- 清空節點允許產生暫時無效的草稿；孤立節點會標紅，Runtime 維持上一個有效版本，直到圖重新有效。

Trigger 條件內建 `every-N`、機率、0.08 秒預設內置冷卻、玩家血量上限與目標燃燒／中毒／凍結狀態，不另占節點。

## Runtime

所有傷害共用同一套 Hit 回報。直接傷害、投射物、連射、連擊、分裂、穿透、反彈、連鎖、擴散與爆炸都能產生 Hit、Critical、Kill；次級命中也可觸發其他分支。分裂、連鎖、擴散與爆炸會在事件內容記錄已執行 operation，避免同一 operation 自我遞迴。

燃燒與中毒 Tick 不算 Hit；DoT 擊殺仍會把 Kill 歸屬到原始技能節點。吸血只依實際 Hit 傷害回血。

安全預算：

- 每次手動施放鏈最多 128 個圖事件。
- 每個 physics frame 最多處理 48 個事件，其餘 FIFO 延後。
- 場上最多 384 個投射物，第 385 個請求被拒絕並計數。
- 投射物由物件池回收；換圖會提高 revision、取消舊事件並回收舊投射物。

## 主要檔案

- `scripts/skill_graph_node.gd`、`scripts/skill_graph.gd`：六節點 DAG 資料。
- `scripts/trigger_config.gd`：不占節點的 Trigger 條件。
- `scripts/skill_concept.gd`：能力需求、Adapter、編譯階段與 operation schema。
- `scripts/concept_library.gd`：Concept Catalog、`compile_graph()` 與 `preview_edit()`。
- `scripts/skill_graph_executor.gd`：事件 FIFO、Trigger 判定與安全預算。
- `scripts/skill_runtime.gd`：Action、Pattern、命中與次級 operation。
- `scripts/projectile_manager.gd`、`scripts/projectile.gd`：384 上限與物件池。
- `scripts/hud.gd`：頂部六格與展開式圖編輯器。

## 執行與驗證

```powershell
& 'D:\funny\Godot_v4.6.2-stable_win64\Godot_v4.6.2-stable_win64.exe' --path 'D:\funny\side-scroller'

& 'D:\funny\Godot_v4.6.2-stable_win64\Godot_v4.6.2-stable_win64_console.exe' --headless --check-only --quit --path 'D:\funny\side-scroller' --log-file 'D:\funny\side-scroller\artifacts\check.log'
& 'D:\funny\Godot_v4.6.2-stable_win64\Godot_v4.6.2-stable_win64_console.exe' --headless --path 'D:\funny\side-scroller' --script res://tests/test_skill_compiler.gd
& 'D:\funny\Godot_v4.6.2-stable_win64\Godot_v4.6.2-stable_win64_console.exe' --headless --path 'D:\funny\side-scroller' --script res://tests/test_runtime_smoke.gd
& 'D:\funny\Godot_v4.6.2-stable_win64\Godot_v4.6.2-stable_win64_console.exe' --headless --path 'D:\funny\side-scroller' --script res://tests/test_runtime_budget.gd
& 'D:\funny\Godot_v4.6.2-stable_win64\Godot_v4.6.2-stable_win64_console.exe' --headless --path 'D:\funny\side-scroller' --script res://tests/test_vfx_coverage.gd
& 'D:\funny\Godot_v4.6.2-stable_win64\Godot_v4.6.2-stable_win64_console.exe' --headless --path 'D:\funny\side-scroller' --script res://tests/test_vfx_cleanup.gd
& 'D:\funny\Godot_v4.6.2-stable_win64\Godot_v4.6.2-stable_win64_console.exe' --headless --path 'D:\funny\side-scroller' --script res://tests/test_hud_layout.gd
& 'D:\funny\Godot_v4.6.2-stable_win64\Godot_v4.6.2-stable_win64_console.exe' --headless --path 'D:\funny\side-scroller' --script res://tests/test_stress_30s.gd
```

Windows 沙盒環境若無法寫入 Godot 的 `user://logs`，請保留 `--log-file` 並指定到專案內的 `artifacts`。

## Web 與 GitHub Pages

Web 匯出使用單執行緒 Compatibility renderer 設定，輸出入口為 `docs/index.html`：

```powershell
./tools/export_web.ps1
```

- Repository：https://github.com/odincyliu/demo-arpg
- Web：https://odincyliu.github.io/demo-arpg/

GitHub Pages 的發布來源設定為 `main` branch 的 `/docs`。`docs/.nojekyll` 會停用 Jekyll 處理，讓 Godot 產生的 WASM、PCK 與 JavaScript 檔案保持原樣。
