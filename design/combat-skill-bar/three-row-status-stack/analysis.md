# 三行队伍状态栈设计解析

> 说明：`three-row-status-stack-mockup.png` 是本地按设计规格绘制的可打开 PNG 样板；不是上一轮 `image_gen` 调用真实落盘的结果。上一轮 `image_gen` 没有在本地生成可检索文件。

## 布局

- 左下角替代旧三头像轮换盘。
- 三行固定语义：上行 `Q` 上一位，中行 `当前` 站场，下行 `E` 下一位。
- 每行从左到右：切换标签、角色正式头像与圆形切换进度、角色名、HP、MP/大招能量、技能冷却小格。

## 当前角色强调四层

1. **大小**：中行更高，技能格更大。
2. **颜色**：中行暗金边框 + 蓝色能量高光；待命行深蓝灰低透明。
3. **结构**：中行右移 6–8px，左侧发光竖线，右侧尖角提示当前操控槽。
4. **动效预期**：切换时三行上下滑动，新当前行落到中间后金边闪一下。

## 实现建议

- `combat_skill_bar.gd` 的三行 RoleStatusStack 复用旧 `SwitchPortraitDisplay` 的正式头像、切换能量圆环和冷却遮罩，不再另画占位徽记。
- `player_stat_payload.gd` 增加三角色 status payload：`role_id/name/current_hp/max_hp/current_mana/max_mana/cooldown_slots/is_active/switch_key`。
- 悬停复用 `survivors_hover_detail.gd`：角色行显示角色状态，技能格显示技能说明和剩余冷却。
