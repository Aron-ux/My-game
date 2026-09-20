# 密集战斗性能证据

Godot 4.6.2 Windows；各结果标明 headless 或实际渲染方式，测试时不并行运行其他性能基准。各轮基线不同，不能将后续收益再次当成相对原始提交的收益。

## 最终 Boss 全阶段

以 `b36bec9` 为基线，统一优化所有阶段的弹丸绘制、生成与碰撞查询。OpenGL 同次对照覆盖 13 种场景，弹量、峰值和实际伤害一致；最终阶段六主题平均帧耗时下降约 60%～67%。详见 [全阶段实现、数据与验证](boss-all-phases.md)，该结果仅代表固定 Boss 测试场景。

## 第三轮

基线：完成第二轮优化的工作区。`bullet.gd`、`player_projectile_batch.gd`、`enemy_occlusion_sort.gd` 在第三轮前仍与 `32b7782` 一致；Vulkan 基线使用这三个原文件的隔离副本，其余依赖保持当前工作区，候选使用新代码。隔离副本与其基准入口保存在本机 `.omx/performance/round3_reference/`。

- [Vulkan 优化前](round3_query_render_vulkan_before.json) / [Vulkan 优化后](round3_query_render_vulkan_after.json)：Forward Mobile / RTX 4070 SUPER，固定 240 个敌人、240 次单体查询、240 次批量弹幕查询及 720 枚绘制实例，预热 3 次、采样 30 次。批量查询中位数 111.974 → 58.677 ms，单体查询 57.149 → 51.558 ms，遮挡排序 3.372 → 1.190 ms，渲染提交 1.161 → 0.351 ms。查询目标、排序和显示数校验全部相同。
- [Headless 优化前](round3_query_render_headless_before.json) / [Headless 优化后](round3_query_render_headless_after.json)：使用相同工作量与校验；此组基线在编辑第三轮生产代码前直接采集，候选为完成第三轮优化后。
- [连续敌人战斗复测](round3_frames_after.json)：沿用第二轮的 120 敌人 / 240 初始敌方弹幕场景，全部玩法与位置校验仍与第二轮相同。平均 18.237 ms、P95 21.873 ms，未显示进一步改善；它没有玩家弹幕，不能拿本轮查询微基准的降幅套用到该场景。

查询微基准只找命中目标，不结算伤害；显示提交只统计 CPU 提交时间，不能作为 GPU 时间或整局 FPS。渲染 smoke 使用同一纹理与动画帧，比较原逐实例提交和新批量提交的实际 SubViewport 像素；Vulkan 和 OpenGL 都逐像素一致，同时检查波形/移动、旋转、描边、透明度、颜色/尺寸修改、互换删除、清空复用和全部 1800 个实例。

34 项相关逻辑回归通过，旧失败项目排除在通过数之外；headless 渲染数据检查及两个实机渲染后端检查通过。日志位于 `.omx/performance/round3_regression/`。

复现命令：

```text
COMBAT_BENCHMARK_LABEL=<label>
godot --path . --rendering-method mobile --rendering-driver vulkan --audio-driver Dummy --script scripts/tests/combat_query_render_benchmark.gd
godot --path . --rendering-method mobile --rendering-driver vulkan --audio-driver Dummy --script scripts/tests/player_projectile_render_smoke.gd
godot --headless --path . --script scripts/tests/player_projectile_query_smoke.gd
```

第一行表示设置环境变量；PowerShell 使用 `$env:COMBAT_BENCHMARK_LABEL='<label>'`。查询结果写入 `.omx/performance/query_render_<label>.json`；比较历史文件时必须保留相同脚本与工作量。

## 第二轮

基线：完成第一轮优化的本地工作区；候选：加入体型缓存失效、保守避让排除、弹幕重复更新消除、Boss 闪光复用后的工作区。

- [连续战斗优化前](round2_frames_before.json) / [连续战斗优化后](round2_frames_after.json)：相同的 120 敌人 / 240 初始弹幕场景；平均逻辑步 29.257 → 16.721 ms，P95 33.040 → 20.801 ms。所有 `checks` 与 `workload` 字段一致，包括位置总和。
- [热点优化前](round2_hotpaths_before.json) / [热点优化后](round2_hotpaths_after.json)：避让中位数 62.618 → 26.148 ms；伤害、HUD、存档此次未进一步修改，其耗时波动也原样保留。此组后测在避让改动完成后采集，后续弹幕和闪光改动不在该脚本工作量内。
- [弹幕与闪光优化前](round2_projectile_feedback_before.json) / [弹幕与闪光优化后](round2_projectile_feedback_after.json)：512 发直线弹幕预热后测量 90 步，再对同一 Boss 叠层刷新 512 次。弹幕中位数 1.837 → 1.756 ms、P95 2.214 → 2.437 ms，不认定尾部耗时改善；待处理 Tween 512 → 1。位置、透明度与命中校验一致；此微基准的命中为零，真实命中由连续战斗及批处理基准覆盖。
- [批处理关闭](round2_batch_off.json) / [批处理开启](round2_batch_on.json)：两者都是第二轮优化后的代码，用于验证批处理等价性，不是历史代码性能对照。玩法计数全部相同：40 只怪物、120 个拾取物、8 次弹幕命中、64 点受伤、0 次重复 tick。

本轮 32 项相关逻辑 smoke、实际 OpenGL Boss 闪光渲染 smoke、密集战斗基准及 headless 启动通过。日志保存在本机 `.omx/performance/round2_regression/`。原先 8 项测试失败与项目配置缺失仍保留为已知问题，未计入本轮通过项。

复现沿用 `COMBAT_BENCHMARK_LABEL` 和 `godot --headless --path . --script <脚本>`；三个基准脚本为 `combat_frame_benchmark.gd`、`combat_hotpath_benchmark.gd`、`projectile_feedback_benchmark.gd`，位于 `scripts/tests/`。实际闪光渲染验证使用 `godot --path . --rendering-method gl_compatibility --rendering-driver opengl3 --audio-driver Dummy --script scripts/tests/enemy_boss_flash_render_smoke.gd`。

## 第一轮

基线：`32b7782`；候选：2026-09-20 第一轮本地性能优化工作区。

- [热点基线](hotpaths_before.json) / [热点候选](hotpaths_after.json)：每个热点预热一次、采样24次。
- [连续战斗基线](frames_before.json) / [连续战斗候选](frames_after.json)：120个敌人、240发初始敌方弹幕、每6步60次命中；预热30步，统计180步。
- 运行命令、优化范围和解释见 [性能记录](../../12_性能优化与验证记录.md)。

基线在独立 checkout 运行相同基准脚本。伤害计数、生命值总量和热点避让校验量相同；连续战斗位置校验量受实例 ID 错峰及重叠分离方向影响，不作严格相等断言。CPU 逻辑耗时改善不能直接推断所有机器的实际显示帧数；连续基准也未模拟完整玩家技能树和自动存档尖峰。

106项逻辑 smoke 和2项渲染 smoke 通过。以下8项逻辑测试的报错在基线与候选均出现，未算作通过：

- `ability_talent_snapshot_save_smoke`：测试桩缺少 `blessing_skill_state`。
- `enemy_rebirth_smoke`：旧测试的伤害量不再满足引渡人的致死断言。
- `gunner_basic_level_talents_smoke`：测试桩缺少 `glutton_war_stomp_remaining`。
- `mage_meta_field_level_talents_smoke`：测试调用已不存在的旧接口。
- `mage_stage_two_three_talents_smoke`：测试桩缺少祝福状态、弹道视觉字段。
- `swordsman_advanced_talents_smoke`：测试桩缺少 `blessing_skill_state`。
- `swordsman_skill_talents_smoke`：测试桩缺少 `blessing_skill_state`。
- `swordsman_trait_runtime_flow_smoke`：测试桩缺少 `blessing_skill_state`。

另有基线与候选相同的项目配置检查失败：未显式设置 `window/size/resizable=true` 和 `window/stretch/aspect="keep"`。文档、成就、架构检查通过。详细日志保存在本机 `.omx/performance/regression/`。
