# Modular Six-Link Skill System V1

這是 Godot 4 的固定六格模組技能原型。Build 依 Slot 由左至右解析；Component 先綁定最近的 Core，再依共通 Pipeline 執行。專案不含 Legacy Graph、父節點、舊 Build 相容層或存檔遷移。

## 操作

- `WASD`／方向鍵或滑鼠左鍵：移動
- 滑鼠右鍵：施放；Channel Core 需持續按住
- `Shift + 左鍵`：原地連續施放
- `Space`：Dash，並中止 Channel
- `Q`：模擬玩家受傷，用於 On Damage Taken
- `R`：重置訓練木樁

畫面頂部維持六格單列。Slot 1 鎖定 Core；每格候選會依完整草稿的語法與相容性顯示原因。編輯器容許保留無效草稿，戰鬥 Runtime 只在 `compile_build()` 成功後才採用新 Build。

預設 Build：

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

- 20 Core：Slash、Rapid Slash、Whirlblade、Earthbreaker、Dash Strike、Shockwave、Ground Burst、Explosion、Blade Burst、Arrow Shot、Returning Blade、Frost Lance、Flame Orb、Frost Nova、Chain Lightning、Meteor、Void Beam、Blood Burst、Void Rift、Summon。
- 10 Trigger：On Hit、On Crit、On Kill、On Stun、On Freeze、On Ignite、On Shock、On Damage Taken、Channel Trigger、On Return。
- 5 Trajectory：Pierce、Fork、Chain、Return、Homing。
- 4 Shape：Nova、Cone、Line、Orbit。
- 5 Pattern：Phantom、Repeat、Multishot、Hold、Remnant。
- 8 Effect：Ignite、Freeze、Shock、Bleed、Poison、Knockback、Pull、Stun。
- 3 Transform：Giant、Expanded、Compressed。

Catalog 共 55 個 Component。Shockwave 的 Core ID 為 `core_shockwave`；Shock ailment 的 Runtime 狀態為 `electrified`。Chain Lightning 與 Trajectory Chain 共用同一套 Chain 跳躍機制。

## Runtime

共通流程為：

```text
Cast → Pattern → Shape → Spawn/Hold → Trajectory → Collision
     → Hit/Damage → Effect → Trigger Evaluation → Cleanup
```

- `CombatEvent` 傳遞 cast ID、build revision、generation、Core Slot、位置、目標、方向與已執行 operation。
- Generation 1 可以造成傷害與狀態，但不再觸發下一代 Core。
- Hold 最多儲存 5 個，1.5 秒自動釋放，並保留排列後重新朝向目前游標。
- Whirlblade 可移動 Channel；Void Beam 鎖定移動。放開、Dash 或換 Build 後才開始冷卻。
- Ignite／Bleed 是來源可追蹤的 DoT；Poison 最多 10 層；Freeze／Stun 使用 100 buildup 與衰減；Electrified 預設 3 秒、增加 20% 承受傷害。
- Summon 是限時跟隨的遠程單位，會自動鎖定最近敵人。
- Core、Trigger、元素、狀態、Hold、Remnant、Channel 與 Minion 使用既有 CC0／程序化 VFX，沒有專屬素材時採通用 fallback。

安全預算：每次 Cast 128 事件、每 Physics Frame 48 事件、384 個移動投射物；Held、Persistent Effect、Remnant 與 Minion 另有集中上限。切換 Build 會提高 revision 並回收舊事件與 Instance。

## 主要檔案

- `scripts/six_link_build.gd`、`scripts/skill_slot.gd`：固定六格 Build。
- `scripts/skill_component.gd`、`scripts/skill_catalog.gd`：55 項 Component schema 與集中調校值。
- `scripts/skill_compiler.gd`、`scripts/compiled_skill_build.gd`：六連語法、最近 Core 綁定與草稿預覽。
- `scripts/skill_executor.gd`、`scripts/combat_event.gd`：事件 FIFO、Trigger 條件、generation 與預算。
- `scripts/skill_runtime.gd`：共通 Cast Pipeline、狀態、Hold、Remnant、Persistent 與 Summon。
- `scripts/projectile_manager.gd`、`scripts/projectile.gd`：384 上限、Trajectory 與物件池。
- `scripts/hud.gd`：六格編輯 UI 與 Trigger 專用控制。

## 驗證與 Web 匯出

```powershell
& 'D:\funny\Godot_v4.6.2-stable_win64\Godot_v4.6.2-stable_win64_console.exe' --headless --path 'D:\funny\side-scroller' --check-only
& 'D:\funny\Godot_v4.6.2-stable_win64\Godot_v4.6.2-stable_win64_console.exe' --headless --path 'D:\funny\side-scroller' --script res://tests/test_skill_compiler.gd
& 'D:\funny\Godot_v4.6.2-stable_win64\Godot_v4.6.2-stable_win64_console.exe' --headless --path 'D:\funny\side-scroller' --script res://tests/test_runtime_smoke.gd
& 'D:\funny\Godot_v4.6.2-stable_win64\Godot_v4.6.2-stable_win64_console.exe' --headless --path 'D:\funny\side-scroller' --script res://tests/test_trigger_status.gd
& 'D:\funny\Godot_v4.6.2-stable_win64\Godot_v4.6.2-stable_win64_console.exe' --headless --path 'D:\funny\side-scroller' --script res://tests/test_runtime_budget.gd
& 'D:\funny\Godot_v4.6.2-stable_win64\Godot_v4.6.2-stable_win64_console.exe' --headless --path 'D:\funny\side-scroller' --script res://tests/test_hud_layout.gd
& 'D:\funny\Godot_v4.6.2-stable_win64\Godot_v4.6.2-stable_win64_console.exe' --headless --path 'D:\funny\side-scroller' --script res://tests/test_vfx_coverage.gd
& 'D:\funny\Godot_v4.6.2-stable_win64\Godot_v4.6.2-stable_win64_console.exe' --headless --path 'D:\funny\side-scroller' --script res://tests/test_vfx_cleanup.gd
& 'D:\funny\Godot_v4.6.2-stable_win64\Godot_v4.6.2-stable_win64_console.exe' --headless --path 'D:\funny\side-scroller' --script res://tests/test_stress_30s.gd
```

Web 匯出入口為 `docs/index.html`：

```powershell
./tools/export_web.ps1
```
