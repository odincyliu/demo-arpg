# CC0 八方向 Godot 2D ARPG 戰鬥 Vertical Slice

這是一個可直接執行的 Godot 4.7.1 俯視角戰鬥測試。玩家與敵人已全面改用可追溯的 CC0 素材；專案不再包含先前的自製／生成角色、使用者照片或來源不明圖片。

## 執行與操作

在 Godot 4.7.1 開啟 `project.godot` 後按 F6／F5，或在 PowerShell 執行：

```powershell
./tools/run_game.ps1
```

- `WASD`：八方向移動，對角輸入會 normalize。
- `滑鼠左鍵`：朝游標方向攻擊。
- `J` 或 `Space`：朝角色目前面向攻擊。
- `F3`：顯示方向、動畫格、Hitbox／Hurtbox 與戰鬥狀態。

## 角色與動畫

玩家使用 OpenGameArt 的 **Super Clone Cyborg (Armored)** 完整 atlas：

- 128×128 原生格，不額外放大。
- E、NE、N、NW、W、SW、S、SE 八條獨立方向列，不使用水平鏡像。
- Idle 4 格、Walk 8 格、Attack_01 8 格／14 FPS。
- 手、身體與 gunblade 已整合在同一逐格動畫，避免手掌與武器分離。
- 角色設定集中於 `assets/characters/super_clone_cyborg/character_profile.json`；替換 atlas、方向列或動畫欄位不需要改玩家戰鬥程式。

敵人使用 Kenney Monster Builder Pack 的 body、arm、leg、eye、mouth、horn 圖層即時組裝。`TrainingDummy.monster_variant` 可切換六種顏色／五官預設，這部分採用 LPC 角色生成器的「圖層＋設定」概念。

## LPC 生成器概念

架構支援以設定檔替換完整角色，也保留了敵人逐層組裝的做法。但目前沒有直接打包 pflat／Universal LPC 圖片，因為其常用 body、服裝與武器圖層混合 GPL、CC-BY-SA、CC-BY、OGA-BY 等授權，不能一概視為 CC0。

若之後要加入 LPC 角色，可新增角色 profile，並把該次匯出的 PNG、JSON 與 Credits TXT／CSV 一起保存，且在遊戲內提供可找到的 Credits 頁面。

## 戰鬥功能

- 8 向攻擊 Hitbox 與一次 25 傷害。
- active frame 2–4、impact frame 3、單次 swing 命中去重。
- 群體命中、擊退、hit stop 彙整、attack lunge、hit spark 與 Camera impulse 上限。
- 7 隻模組化怪物可作為群體命中測試目標。

## 素材授權

- 玩家：[OpenGameArt — Super Clone Cyborg](https://opengameart.org/node/101322)，作者 Metapixelatron，CC0 1.0。
- 敵人：[Kenney — Monster Builder Pack](https://kenney.nl/assets/monster-builder-pack)，CC0 1.0。
- 完整本地紀錄：`THIRD_PARTY_NOTICES.md`。
- Kenney 原始授權文字：`assets/third_party/kenney/monster_builder_pack/LICENSE.txt`。

CC0 不強制署名，專案仍保留來源與作者以便稽核。

## 自動測試與 QA

```powershell
./tools/run_tests.ps1
```

測試涵蓋八方向量化、八條獨立 atlas 列、24 組動畫、原生格尺寸、Attack_01 接觸格、CC0 來源檔、九層怪物組裝、群體單次命中、擊退、hit stop 與戰鬥狀態回復。

八方向攻擊 contact sheet：`artifacts/cc0-eight-direction-attack.png`。

## Web 與 GitHub Pages

```powershell
./tools/export_web.ps1
```

輸出位於 `docs/index.html`，GitHub Pages 使用 `main` branch 的 `/docs`：

- Repository: https://github.com/odincyliu/demo-arpg
- Web: https://odincyliu.github.io/demo-arpg/

## 目前取捨

- 玩家武器是 atlas 的整合部分；要換武器需替換另一份相容 profile／atlas。這是為了保證手、身體與武器動作完全連續。
- Kenney 怪物目前有待機浮動與受擊動作，沒有八方向走路 spritesheet。
- 音效節點已保留，但沒有加入來源不明的音效檔。
