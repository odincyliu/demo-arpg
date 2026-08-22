# CC0 VFX 素材來源

本目錄只收錄實際用於遊戲的精選檔案。所有下列素材均由來源頁標示為
CC0 1.0；雖然不強制署名，仍保留作者、原始網址與下載檔雜湊，方便日後稽核。

原始像素內容維持不變。遊戲執行時由 `shadow_sprite.gdshader` 依亮度重映為
近黑本體、灰色細節與灰白輪廓；這項 Runtime 灰階處理不會覆寫來源圖檔。

存取日期：2026-08-12；Procedural Cyclic Slash、Weapon Slash Erosion Texture、
3D Lightning Shader、Lightning Arc：2026-08-19

## Cethiel — Fireball Effect

- 來源：https://opengameart.org/content/fireball-effect
- 授權：CC0 1.0
- 原始檔：`Fireball - Effect.zip`
- SHA-256：`87019874DD86A3E933EFB73E1C0B44E898EE5898407289C2B247F634DBC573BC`
- 專案檔案：`cc0/cethiel_fireball/frame_01.png` 至 `frame_28.png`
- 處理：只重新命名，像素內容未修改。
- Runtime 用途：Flame Orb 與 Meteor 的逐格黑焰；Meteor 另疊加程序化隕核、尾流與撞擊 Mesh。

## Grahhhhh — Animated Blue Ring Explosion

- 來源：https://opengameart.org/content/animated-blue-ring-explosion
- 授權：CC0 1.0
- 原始檔：`Blue Ring Explosion.zip`
- SHA-256：`5A5C17EDF92EE50F49629B0E1F39CCCEE85200E7A59677106B62199D2E1B5222`
- 專案檔案：`cc0/grahhhhh_blue_ring/frame_01.png` 至 `frame_19.png`
- 處理：只重新命名，像素內容未修改。

## 13rice — Radial Lightning Effect

- 來源：https://opengameart.org/content/radial-lightning-effect
- 授權：CC0 1.0
- 原始檔：`spark_radial_spritesheet_13rice.png`
- SHA-256：`070D7244C6450EB92F3BFCE773D5D5BF871A275DE73F7DBBFB718EF856FA3D99`
- 專案檔案：`cc0/13rice_radial_lightning/radial_lightning_atlas.png`
- 處理：只重新命名，像素內容未修改。

## Cethiel — Weapon Slash Effect

- 來源：https://opengameart.org/content/weapon-slash-effect
- 授權：CC0 1.0
- 原始檔：`Alternative 2 Blue.zip`
- SHA-256：`93CFB6F86F5F64AF4C6653DFEC83917528B3647763691D06714C2C529499729D`
- 專案檔案：`cc0/cethiel_blade_wave/frame_01.png` 至 `frame_06.png`
- 原始檔：`Classic.zip`
- SHA-256：`605DFF92B8A405A4810AA88B7F8544C6EB7B08B0668816F958ABB44CC70CB620`
- 專案檔案：`cc0/cethiel_heavy_slash/frame_01.png` 至 `frame_06.png`
- 處理：各自從原套件選出一組六幀動畫並重新命名，像素內容未修改。

## Kenney — Particle Pack

- 來源：https://kenney.nl/assets/particle-pack
- 授權：CC0 1.0
- 原始檔：`kenney_particle-pack.zip`
- SHA-256：`B631D4B07F7002549FDCF155F01141AD482F79F3440E4E301EED49CE5F1D8958`
- 專案檔案：`cc0/kenney_particle_pack/` 內的光圈、魔法陣、火焰、閃電、
  刀光、星芒與閃光遮罩。
- 處理：只挑選與重新命名；遊戲執行時由共用 Sprite Shader 進行灰階亮度重映。
- 原始授權文字：`cc0/kenney_particle_pack/LICENSE.txt`

## Alkaliii — Procedural Cyclic Slash

- 來源：https://godotshaders.com/shader/procedural-cyclic-slash/
- 授權：頁面明示 shader code 與 code snippets 為 CC0；頁面預覽圖片、影片與其中
  展示的其他資產不包含在此授權內，本專案未匯入那些預覽資產。
- 專案檔案：`shadow_cyclic_slash.gdshader`
- 處理：保留原作的極座標、噪聲、寬度／長度漸層遮罩與循環顯現概念；改為
  固定鏡頭可讀的 3D billboard quad、確定性的外部進度控制、安全的 alpha 臨界值，
  並使用本專案的黑、灰、灰白色階。噪聲與漸層資源由專案自行建立。

## Arnklit — Weapon Slash Erosion Texture

- 來源：https://www.materialmaker.org/material?id=376
- 授權：CC0（來源頁明示）
- 原始格式：Material Maker 0.98 可編輯節點圖；本專案未匯入預覽圖片。
- 專案檔案：`shadow_cyclic_slash.gdshader`、`../../scripts/shadow_vfx_style.gd`
- 處理：將原作的環形映射 FBM、外緣強化、徑向 slope blur 與閾值侵蝕概念
  改寫成 Godot 4 即時 Shader；使用固定 seed 的五層 FBM，侵蝕進度由技能動畫控制。

## Loop_Box — 3D Lightning Shader

- 來源：https://godotshaders.com/shader/3d-lightning-shader/
- 授權：頁面明示 shader code 與 code snippets 為 CC0；頁面預覽圖片、影片與其中
  展示的其他資產不包含在此授權內，本專案未匯入那些預覽資產。
- 專案檔案：`shadow_chain_lightning.gdshader`、`../../scripts/combat_vfx.gd`
- 處理：採用五層 FBM／噪聲塑造電弧細部的概念；主輪廓改由 Godot 以遞迴中點
  位移產生，Shader 僅控制細微裂動、粗細與 alpha 侵蝕。色彩改為近純黑本體與
  極細暗灰邊，不使用原作的高亮 emission。

## lordnull — Lightning Arc

- 來源：https://godotshaders.com/shader/lightnight-arc/
- 授權：頁面明示 shader code 與 code snippets 為 CC0；頁面預覽圖片、影片與其中
  展示的其他資產不包含在此授權內，本專案未匯入那些預覽資產。
- 專案檔案：`../../scripts/combat_vfx.gd`
- 處理：採用兩端固定、偏移在中段最大化的概念；改寫為即時 3D 端點、seed 控制的
  遞迴中點位移、相機朝向 ArrayMesh Ribbon，以及每脈衝 2–4 條漸細分叉。

CC0 1.0 全文：https://creativecommons.org/publicdomain/zero/1.0/
