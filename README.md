# Modular Six-Link Skill System V1 — 14-Core Shadow VFX

這是 Godot 4 的固定六格模組技能原型。Build 依 Slot 由左至右解析；Component 先綁定最近的 Core，再依共通 Pipeline 執行。專案不含 Legacy Graph、父節點、舊 Build 相容層或存檔遷移。

## 操作

- `WASD`／方向鍵或滑鼠左鍵：移動
- 滑鼠右鍵：施放；點在術法射程外時會先自動移動，進入射程後才施放；Channel Core 需持續按住
- `Shift + 左鍵`：原地連續施放
- `Space`：Dash，並中止 Channel
- `Q`：模擬玩家受傷，用於 On Damage Taken
- `R`：重置訓練木樁

畫面頂部固定顯示六個空槽，從 Slot 1 的 Core 開始逐格組合。點擊可用槽位會開啟緊湊的「Category → Component」雙下拉選擇器；分類順序與正式 V1 文件一致，不相容候選會灰化並提供原因。編輯器容許保留無效草稿，戰鬥 Runtime 只在 `compile_build()` 成功後才採用新 Build。首次進入沒有啟用中的技能，選入第一個合法 Core 後才可施放。

`LOAD FROST PRESET` 可載入範例 Build：

```text
Frost Lance → Multishot → Hold → Freeze → On Freeze → Shockwave
```

## 六連語法

- Build 是最多六格的連續非空前綴，Slot 1 必須是 Core。
- 支援 Component 綁定左側最近的 Core；同一 Build 的非 Core Component 不得重複。
- 最多兩個 Core、一個 Trigger，`MaxTriggerDepth = 1`。
- Trigger 必須緊接第二個 Core；禁止 Core → Core、Trigger 無目標、中間空格與第二層 Trigger。
- 每個 Core 最多一個 Shape；其餘疊加仍須通過 Requirements、Exclusions 與互斥群組。
- On Return 要求來源 Core 已套用 Return；Channel Trigger 要求 Channel Core。
- On Damage Taken 監聽玩家受傷累積，仍占用 Trigger 與目標 Core 兩格。
- 綁定完成後依 Core → Pattern → Shape → Transform → Trajectory → Effect 的固定編譯階段處理；同階段維持 Slot 順序。

## V1 Catalog

- 14 Core：Slash、Whirlblade、Dash Strike、Shockwave、Ground Burst、Arrow Shot、Frost Lance、Flame Orb、Frost Nova、Chain Lightning、Meteor、Void Beam、Void Rift、Summon。
- 10 Trigger：On Hit、On Crit、On Kill、On Stun、On Freeze、On Ignite、On Shock、On Damage Taken、Channel Trigger、On Return。
- 5 Trajectory：Pierce、Fork、Chain、Return、Homing。
- 4 Shape：Nova、Cone、Line、Orbit。
- 5 Pattern：Phantom、Repeat、Multishot、Hold、Remnant。
- 8 Effect：Ignite、Freeze、Shock、Bleed、Poison、Knockback、Pull、Stun。
- 3 Transform：Giant、Expanded、Compressed。

Catalog 共 49 個 Component。Shockwave 的 Core ID 為 `core_shockwave`；Shock ailment 的 Runtime 狀態為 `electrified`。Chain Lightning 與 Trajectory Chain 共用同一套 Chain 跳躍機制。

### Core 收斂盤點

六個同質性較高的 Core 已收斂回六連語法，不保留舊 ID 或相容層：

| 收斂項目 | 正式組合 |
|---|---|
| Rapid Slash | Slash + Repeat |
| Earthbreaker | Slash + Giant + Expanded |
| Explosion | Ground Burst 或 Frost Nova 作為 Trigger payload |
| Blade Burst | Arrow Shot + Nova + Multishot |
| Returning Blade | Arrow Shot + Giant + Return |
| Blood Burst | Slash／Ground Burst + Bleed |

保留項目的玩法邊界亦已加強：Shockwave 是寬型 `wave`，沿路每個目標只命中一次且不在首個命中消失；Pierce 僅適用一般 projectile。Flame Orb 具有資料驅動的 `impact_radius`，碰撞或期限結束時爆裂，直接命中目標不會再次承受 splash。所有術法 Core 都有 Catalog 集中管理的 `target_range`；Chain Lightning 的第一段由施法者連到首個目標，再沿用通用 Chain 機制向後跳躍；手動施放 Frost Nova 固定以玩家為中心擴散。

## 黑影 VFX 規範

- `ShadowVfxStyle` 集中管理近黑本體、炭灰煙影、中灰殘像、灰白輪廓與短暫銀白閃光；所有色票保持 R＝G＝B。
- Mesh Shader 提供邊緣晃動、透明消散與 Fresnel 灰邊；Sprite Shader 依原圖亮度映射黑影、灰邊及噪聲晃動。兩者均不取樣螢幕或深度紋理，可供 GL Compatibility／Web 使用。
- 黑色本體不發光；只有中性輪廓與瞬間閃光使用 emission。Fire／Cold／Lightning 等名稱只保留機制意義，不再決定視覺色相。
- Slash 的基礎視覺是明確的水平橫斬：武器劃過後會在原刀路留下單一漆黑掃弧，陰影煙霧只從弧線後緣散開，不會沿攻擊方向飛行；每次施放會受控地改變掃出順序、弧寬、厚度、彎曲與煙霧分布，輪廓參考專案內 Kenney CC0 劍氣的尖端收束與柔邊，不使用亮前緣、放射線、地裂、火花或第二道斬痕。
- 14 個 Core 均有 Cast 與命中／結束識別；Projectile、Wave、Channel、Persistent、Remnant 與 Minion 另有飛行或持續生命週期效果。
- 現有 CC0 圖檔不離線改色，僅在 Runtime 經 Shader 重映；通用 Trigger、Effect 與 fallback 也使用相同灰階語意。

## Runtime

共通流程為：

```text
Cast → Pattern → Shape → Spawn/Hold → Trajectory → Collision
     → Hit/Damage → Effect → Trigger Evaluation → Cleanup
```

- `CombatEvent` 傳遞 cast ID、build revision、generation、Core Slot、位置、目標、方向與已執行 operation。
- Generation 1 可以造成傷害與狀態，但不再觸發下一代 Core。
- Hold 最多儲存 5 個，1.5 秒自動釋放，並保留排列後重新朝向目前游標。
- Whirlblade 是附著玩家的大型持續旋轉 Channel，期間可像旋風般移動；Void Beam 鎖定移動。放開、Dash 或換 Build 後才開始冷卻。
- Frost Lance 與 Slash 依實際世界方向投影其模型／劍弧；Meteor 由高空落下黑色本體，抵達目標點後才觸發範圍撞擊。
- Ignite／Bleed 是來源可追蹤的 DoT；Poison 最多 10 層；Freeze／Stun 使用 100 buildup 與衰減；Electrified 預設 3 秒、增加 20% 承受傷害。
- Summon 是限時跟隨的遠程單位，會自動鎖定最近敵人。
- Core、Trigger、元素、狀態、Hold、Remnant、Channel 與 Minion 使用共用黑影 Shader、既有 CC0 與程序化 VFX；沒有專屬編排時採灰階 fallback。

安全預算：每次 Cast 128 事件、每 Physics Frame 48 事件、384 個移動投射物；Held、Persistent Effect、Remnant 與 Minion 另有集中上限。切換 Build 會提高 revision 並回收舊事件與 Instance。

## 主要檔案

- `scripts/six_link_build.gd`、`scripts/skill_slot.gd`：固定六格 Build。
- `scripts/skill_component.gd`、`scripts/skill_catalog.gd`：49 項 Component schema 與集中調校值。
- `scripts/skill_compiler.gd`、`scripts/compiled_skill_build.gd`：六連語法、最近 Core 綁定與草稿預覽。
- `scripts/skill_executor.gd`、`scripts/combat_event.gd`：事件 FIFO、Trigger 條件、generation 與預算。
- `scripts/skill_runtime.gd`：共通 Cast Pipeline、狀態、Hold、Remnant、Persistent 與 Summon。
- `scripts/projectile_manager.gd`、`scripts/projectile.gd`：384 上限、Trajectory 與物件池。
- `scripts/shadow_vfx_style.gd`、`assets/vfx/shadow_*.gdshader`：WebGL 相容的共用灰階材質與色票。
- `scripts/combat_vfx.gd`：14 Core 的 Cast、命中、飛行與持續效果編排。
- `scripts/hud.gd`：六格編輯 UI 與 Trigger 專用控制。

## 驗證與 Web 匯出

```powershell
$godot = 'D:\funny\Godot_latest_version\Godot_console.exe'
& $godot --headless --path 'D:\funny\side-scroller' --editor --quit
& $godot --headless --path 'D:\funny\side-scroller' --log-file 'D:\funny\side-scroller\artifacts\compiler.log' --script res://tests/test_skill_compiler.gd
& $godot --headless --path 'D:\funny\side-scroller' --log-file 'D:\funny\side-scroller\artifacts\runtime.log' --script res://tests/test_runtime_smoke.gd
& $godot --headless --path 'D:\funny\side-scroller' --log-file 'D:\funny\side-scroller\artifacts\trigger.log' --script res://tests/test_trigger_status.gd
& $godot --headless --path 'D:\funny\side-scroller' --log-file 'D:\funny\side-scroller\artifacts\budget.log' --script res://tests/test_runtime_budget.gd
& $godot --headless --path 'D:\funny\side-scroller' --log-file 'D:\funny\side-scroller\artifacts\hud.log' --script res://tests/test_hud_layout.gd
& $godot --headless --path 'D:\funny\side-scroller' --log-file 'D:\funny\side-scroller\artifacts\vfx.log' --script res://tests/test_vfx_coverage.gd
& $godot --headless --path 'D:\funny\side-scroller' --log-file 'D:\funny\side-scroller\artifacts\cleanup.log' --script res://tests/test_vfx_cleanup.gd
& $godot --headless --path 'D:\funny\side-scroller' --log-file 'D:\funny\side-scroller\artifacts\stress.log' --script res://tests/test_stress_30s.gd
```

專案固定使用 Godot 4.7.1 stable；Headless 驗證與 Web export 必須使用相同版本，匯出腳本會拒絕其他引擎或 template。Web 匯出入口為 `docs/index.html`：

```powershell
./tools/export_web.ps1
```
