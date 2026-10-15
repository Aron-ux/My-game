# 机械师重做 · 2026-10-13

机械师采用独立的人物与动作资源，参考玛利亚的蓝发、圆眼镜、红发带和工具外套。设备统一为象牙装甲、黄铜机械件与郁金香标记。

可先看 [动态预览](preview.gif) 或 [Godot 截图](preview.png)。预览为便于检查细节分别放大，各格的显示比例不代表战斗中的相对大小。

体型校准后，战斗和营地的机械师缩放为 1.1，待机约 86–88、奔跑约 86–89 场景像素高；剑士约 89–93、枪手约 76–82、法师约 83–90。战斗基准位置调整为 `(0,-4)`。实际比例与落脚位置见 [四英雄并排对比](hero-size-comparison.png)，其中全部角色按相同的 2 倍查看倍率展示。

## 来源与制作分工

- 人物参考：[AliceSoft《兰斯 IX》官方角色页](https://www.alicesoft.com/rance9/character/outlaw.html)，其中玛利亚的官方设定图。官方图片不打包进游戏。
- 使用内置 `image_gen` 生成原图，未调用外部图像 API 或其他 agent。`source/` 保留选用的原始输出，每张动作/设备/头像图对应同名 `-prompt.txt`；最初角色参考板提示词在 [prompts.txt](prompts.txt)。
- `character-master.png` 是带背景的造型参考板；实际透明运行素材由 `character-animations.png`、`portrait.png` 和各设备图导出。
- [Aseprite 导入脚本](../../scripts/tools/import_mechanic_art.lua) 负责机械加工：裁区、统一原生像素尺寸、锚点、二值 alpha、每组最多 64 色、PNG 与可编辑 Aseprite 导出。它不绘制人物或设备轮廓。
- 本次人物有 16 帧：待机 4、奔跑 8、操作 4；实际使用的 8 组设备/特效共 35 帧。具体尺寸与运行时接入见 [美术规范](../../docs/07_资源_美术_特效规范.md)。

## 复现与预览

在仓库根目录执行。导入命令会覆盖本次列出的机械师资源；若手工修改了 Aseprite 源文件，先保存改稿，不要用原始生成图重新覆盖。

```bash
/home/weathour/programs/aseprite-src/build/bin/aseprite --batch --script scripts/tools/import_mechanic_art.lua
/home/weathour/.local/bin/godot-4.6.2 --headless --path . --editor --import --quit
/home/weathour/.local/bin/godot-4.6.2 --path . --rendering-method gl_compatibility --script res://scripts/tests/mechanic_art_preview.gd
```

预览命令末尾加 `-- --capture` 会保存 48 帧 Godot 渲染与 `preview.png`，并自动退出。生成循环 GIF：

```bash
ffmpeg -y -framerate 12 -i design/mechanic-rework-20261013/preview-frames/%03d.png -filter_complex '[0:v]split[a][b];[a]palettegen=stats_mode=full[p];[b][p]paletteuse=dither=none' -loop 0 design/mechanic-rework-20261013/preview.gif
```

验证命令：

```bash
/home/weathour/.local/bin/godot-4.6.2 --headless --path . --quit
/home/weathour/.local/bin/godot-4.6.2 --headless --path . --script res://scripts/tests/mechanic_visual_smoke.gd
/home/weathour/.local/bin/godot-4.6.2 --headless --path . --script res://scripts/tests/mechanic_roster_smoke.gd
graphify update .
```

## 当前验证范围

- 已检查切帧完整性、人物脚底基线、透明边界、调色板和原生尺寸；Godot 实际渲染可见所有动画。
- 已检查移动与操作动作恢复、朝向一致、炮台直立、开火回静止帧和存档恢复；机械师原有队伍/技能/存档回归通过。
- 技能伤害、冷却与队伍规则未调整。未使用的旧 `emp_burst` / `missile_volley` 图组保留；未增加当前运行时没有的独立受击或死亡状态。
- 本轮是已接入工程的首版美术。仍需在完整实玩中判断跑步节奏、衣摆/工具的帧间细节和整体战场观感；造型参考来源记录见 [素材来源](../../THIRD_PARTY_NOTICES.md)。
