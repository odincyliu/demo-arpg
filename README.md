# Student Dual-Blade Godot 2D ARPG Vertical Slice

這是一個可直接執行的 Godot 4.7.1 2D Pixel ARPG 戰鬥測試。主角為原創的學生雙刀角色；身體與武器採獨立節點，之後可替換短劍、匕首或其他相容武器，而不必重畫待機與移動身體圖。

## 直接執行

- 在 Godot 4.7.1 開啟本資料夾的 `project.godot`，按 F6/F5。
- 或在 PowerShell 執行 `./tools/run_game.ps1`。

操作：

- `WASD`：八方向移動；對角輸入會 normalize。
- 滑鼠：決定攻擊方向。
- `Left Mouse`、`J` 或 `Space`：雙刀 Attack_01。
- `F3`：切換碰撞、Hitbox、Hurtbox、方向、動畫格與戰鬥狀態資訊。

## 模組化角色與武器

- Body：64×64 px 無武器透明角色圖。
- Weapon：32×32 px 獨立短劍，以 grip 對齊手部 socket。
- 原生方向：S、SE、E、NE、N。
- Runtime 鏡像：SW ← SE、W ← E、NW ← NE。
- 正背面規則：N 與 NE 不含眼睛、胸前圖案、前腰帶或抽繩；S 與 SE 才顯示正面細節。
- Idle：4 格／5 FPS；Walk：6 格／10 FPS；Attack_01：8 格／14 FPS。
- 身體錨點做輕量 bob／lean；兩個武器節點獨立旋轉，因此武器像素不會烘焙進 Body。

重要輸出：

- 角色定義：`assets/characters/student_dualblade/modular_character.json`
- 無武器 Body：`assets/characters/student_dualblade/body/`
- 武器定義：`assets/weapons/short_sword/weapon.json`
- 獨立短劍：`assets/weapons/short_sword/short_sword.png`
- 生成來源、prompt、QA 與 manifest：`assets/characters/student_dualblade/run/`

若要替換相容的單手輕武器，可建立新的 `weapon.json` 與透明貼圖，保留 `grip`、`tip` landmark，再改 `WEAPON_METADATA_PATH`。長槍、弓或重武器需要不同的身體動作 profile。

## 美術來源與公開說明

- 正式角色和短劍使用 OpenAI 內建圖像生成製作，再以固定格、色鍵與限色流程處理。
- 使用者提供的照片只做一般外觀參考，照片本身沒有放進專案或 Git 儲存庫。
- 衣服改為原創抽象青綠閃電圖案；未保留照片上的角色圖、品牌或商標。
- 先前來源不明的鳥頭角色與相關預覽已從公開分支及重寫後的初始提交移除。

## Godot 結構

- `scenes/CombatTest.tscn`：場地、Player、7 隻 TrainingDummy、Camera、Debug HUD、VFX 容器。
- `scenes/Player.tscn`：`VisualRig/Body`、`WeaponLeft`、`WeaponRight`、body collision、旋轉式 AttackPivot/Hitbox、Hurtbox 與 Audio hooks。
- `resources/player_attack_01.tres`：damage、startup、active、recovery、hit stop、knockback、lunge、camera impulse 與 impact frame。
- `scripts/sprite_frames_builder.gd`：由模組化 JSON 建立 24 組邏輯動畫，不需在 Inspector 手工切片。

## 已實作戰鬥回饋

- 攻擊 active frame 同步的獨立 Area2D Hitbox。
- 每次 swing 對同一敵人只命中一次。
- 群體傷害、白閃、受擊縮放、擊退、死亡停用。
- 0.055 秒 hit stop；同一物理幀的群體命中只觸發一次並設上限。
- 程序式 hit spark、輕微且封頂的 Camera impulse。
- 第 4 格 impact frame 的小幅 attack lunge。
- Attack/HitConfirm AudioStreamPlayer2D hooks；未放入來源不明音效。

## 自動測試

```powershell
./tools/run_tests.ps1
```

測試涵蓋 8 向量化、模組化 metadata、五個原生 Body 方向、兩個獨立 Weapon Sprite、左右鏡像、前後圖層、24 組邏輯動畫、7 隻敵人、三目標同時命中、單次 swing 去重、擊退、hit stop 彙整、camera cap 與攻擊狀態回復。

## Web / GitHub Pages

```powershell
./tools/export_web.ps1
```

成品會輸出至 `docs/index.html`，並建立 `docs/.nojekyll`。本儲存庫使用 `main` branch 的 `/docs` 發布：

- Repository: https://github.com/odincyliu/demo-arpg
- Web: https://odincyliu.github.io/demo-arpg/

## 已知限制

- 目前 Body 動作用單一方向錨點搭配程序式 bob／lean；若要更細緻的步伐與揮砍肢體變化，可在不更改武器節點介面的前提下替換成逐格 Body 動畫。
- W／NW／SW 使用水平鏡像，因此非對稱服裝細節會換邊。
- 敵人與 hit spark 是程序式測試圖形，尚非正式美術。
- 音效只有掛點，未包含正式音檔。
