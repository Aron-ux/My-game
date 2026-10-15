# 营地整备升级实机记录

2026-10-15；基准 91fd75c 加当前工作区。Godot 4.6.2，OpenGL Compatibility，NVIDIA RTX 5080；测试存档完全隔离。

- `01-camp.png`：档案概览、功能分区、机械师驻营。
- `02-shop-save-error.png`：模拟写盘失败，交易未发布且存量保持。
- `03-shop-details.png`：分类列表、可见选中项、当前与下一份累计效果，独立购买/退还。
- `04-mechanic-resident.png`：机械师定位、基础属性、主动技能与大招。
- `05-departure.png`：N 层选择与阵容/携带确认。
- `07-mechanic-leading.png`：重排后机械师成为操作形象。
- `08-shop-960x540.png`、`09-team-960x540.png`：小窗口滚动与固定操作区。

重现：

```bash
env DISPLAY=:0 XDG_DATA_HOME=/tmp/my-game-camp-upgrade-20261015/render-userdata \
  /home/weathour/.local/bin/godot-4.6.2 --path . \
  --rendering-method gl_compatibility --audio-driver Dummy \
  --script scripts/tests/endless_camp_smoke.gd -- \
  --capture=/tmp/my-game-camp-upgrade-20261015/captures
```

脚本验证交易写盘失败、重复购买、退款、满携带、驻营/形象同步、队伍重排回滚、面板移动锁、F/Esc 和真实返营保留。画面不能证明长期平衡或主观体验。

完整检查：4 项 Python 检查、Godot import/headless parse、3 个场景和 141 个独立 smoke 全部通过；Godot 无脚本错误/对象泄漏。最终选层保存失败提示调整后，实机营地 smoke 再次通过；Graphify 更新现有索引，Godot 覆盖仍受已知本机扩展缺失限制。
