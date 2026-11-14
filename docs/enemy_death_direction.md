# 怪物死亡击飞

怪物最终死亡时生成独立视觉副本，在 0.32 秒内沿致命攻击方向飞出 48 像素，同时旋转一圈、缩小并移除。位移逐渐减速，旋转与缩小保留原有加速曲线。距离、时长和圈数位于 `scripts/enemies/enemy_death_effects.gd`。

## 方向规则

- 普通伤害默认取命中时角色的攻击朝向；手动瞄准使用实时鼠标瞄准方向，自动攻击使用已记录的攻击朝向，避免结算阶段重新选敌。
- 有独立方向的攻击优先使用自身方向，包括子弹、反弹子弹、月牙剑气（含回程）、光束、爆破弹、魔法榴弹、火球和黑暗球。
- 无独立方向的范围伤害和持续伤害使用当次命中的角色攻击朝向。
- 方向作为可选末尾参数沿伤害链传递，在批量收集或入队时保存。不同方向不会合并为一笔伤害，避免致命一击方向被覆盖。
- 敌人节点不保存上次命中方向，避免非致命命中、流血和对象池复用继承旧方向。
- Boss 阶段切换、护盾转场和复活不触发最终死亡副本；波末清理不传攻击方向，保留原地旋转缩小效果。

## 验证

`--headless --path . --script res://scripts/tests/enemy_death_direction_smoke.gd` 使用真实敌人和子弹，验证入队后角色转身、独立弹道、不同方向不合并、队列压缩、低反馈批量伤害、旧方向不残留、投射技能爆炸方向、旋转缩小及动画清理。Tween 手动步进验证，无需打开窗口。

本次未进行游戏窗口内的肉眼观感检查。部分旧技能测试仍引用已移除接口或旧等级规则，不能算作通过项。Graphify 更新已执行，但当前提取器没有 GDScript 覆盖，详见 `docs/GRAPHIFY.md`。

通过的检查：Godot 无窗口启动、enemy_death_direction_smoke、player_damage_resolver_smoke、damage_dead_target_smoke、gunner_authored_event_projectile_smoke、swordsman_basic_build_smoke、gunner_infinite_reload_build_smoke，以及此前难度成长的 enemy_tier_wave_scaling_smoke（带现有视觉 owner 警告）。

未通过的已有检查：两份 skill_talents 测试调用不存在的方法；三份 skill_level_effect 测试包含旧数值预期；combat_wave_flow_smoke 有类型推断解析错误；combat_performance_regression_smoke 的碰撞半径断言失败；player_projectile_query_smoke 第 55 行断言失败（用 HEAD 原版 projectile batch 复测仍失败）。这些检查未作为通过项。
