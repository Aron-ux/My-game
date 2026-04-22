# Graph Report - C:\Users\Aron\Desktop\git  (2026-04-23)

## Corpus Check
- Corpus is ~2,069 words - fits in a single context window. You may not need a graph.

## Summary
- 26 nodes · 53 edges · 5 communities detected
- Extraction: 83% EXTRACTED · 17% INFERRED · 0% AMBIGUOUS · INFERRED: 9 edges (avg confidence: 0.81)
- Token cost: 0 input · 0 output

## Community Hubs (Navigation)
- [[_COMMUNITY_战斗定位与关卡压力|战斗定位与关卡压力]]
- [[_COMMUNITY_构筑表现与版本路线|构筑表现与版本路线]]
- [[_COMMUNITY_架构数据与技术风险|架构数据与技术风险]]
- [[_COMMUNITY_系统入口与文档导航|系统入口与文档导航]]
- [[_COMMUNITY_菜单存档与音频系统|菜单存档与音频系统]]

## God Nodes (most connected - your core abstractions)
1. `文档索引` - 11 edges
2. `主题构筑` - 7 edges
3. `战斗系统与角色机制` - 6 edges
4. `战斗循环` - 6 edges
5. `当前实现状态与后续重点` - 5 edges
6. `关键数据流` - 5 edges
7. `构筑系统与文案交互规范` - 4 edges
8. `资源_美术_特效规范` - 4 edges
9. `脚本职责树与关键数据流` - 4 edges
10. `主线流程与数据结构现状` - 4 edges

## Surprising Connections (you probably didn't know these)
- `菜单存档与音频` --shares_data_with--> `关键数据流`  [INFERRED]
  06_UI_菜单_存档_音频.md → 09_脚本职责树与关键数据流.md
- `文档索引` --references--> `项目定位与核心理念`  [EXTRACTED]
  README_文档索引.md → 01_项目定位与核心理念.md
- `UI_菜单_存档_音频` --references--> `主线流程与数据结构现状`  [INFERRED]
  06_UI_菜单_存档_音频.md → 10_主线流程与数据结构现状.md
- `项目核心定位` --rationale_for--> `主题构筑`  [INFERRED]
  01_项目定位与核心理念.md → 04_构筑系统与文案交互规范.md
- `三角色切换` --conceptually_related_to--> `主题构筑`  [INFERRED]
  03_战斗系统与角色机制.md → 04_构筑系统与文案交互规范.md

## Hyperedges (group relationships)
- **战斗体验闭环** — concept_role_switch, concept_combat_loop, concept_build_theme, concept_fx_hitbox, concept_stage_pressure [INFERRED 0.88]
- **工程维护风险** — concept_architecture, concept_data_flow, concept_data_model, concept_refactor_risk, concept_roadmap [EXTRACTED 1.00]

## Communities

### Community 0 - "战斗定位与关卡压力"
Cohesion: 0.39
Nodes (8): 战斗循环, 开发者模式, 项目核心定位, 三角色切换, 关卡压力与Boss演出, 项目定位与核心理念, 战斗系统与角色机制, 敌人_Boss_关卡_难度

### Community 1 - "构筑表现与版本路线"
Cohesion: 0.48
Nodes (7): 主题构筑, 特效与判定贴合, 当前版本状态, 下一阶段路线, 构筑系统与文案交互规范, 资源_美术_特效规范, 当前实现状态与后续重点

### Community 2 - "架构数据与技术风险"
Cohesion: 0.6
Nodes (5): 工程架构, 关键数据流, 数据结构现状, 技术债与重构风险, 技术债_风险点_重构建议

### Community 3 - "系统入口与文档导航"
Cohesion: 0.83
Nodes (4): 工程架构与代码入口, 脚本职责树与关键数据流, 主线流程与数据结构现状, 文档索引

### Community 4 - "菜单存档与音频系统"
Cohesion: 1.0
Nodes (2): 菜单存档与音频, UI_菜单_存档_音频

## Knowledge Gaps
- **Thin community `菜单存档与音频系统`** (2 nodes): `菜单存档与音频`, `UI_菜单_存档_音频`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `文档索引` connect `系统入口与文档导航` to `战斗定位与关卡压力`, `构筑表现与版本路线`, `架构数据与技术风险`, `菜单存档与音频系统`?**
  _High betweenness centrality (0.488) - this node is a cross-community bridge._
- **Why does `战斗系统与角色机制` connect `战斗定位与关卡压力` to `构筑表现与版本路线`, `系统入口与文档导航`?**
  _High betweenness centrality (0.127) - this node is a cross-community bridge._
- **Why does `主题构筑` connect `构筑表现与版本路线` to `战斗定位与关卡压力`?**
  _High betweenness centrality (0.125) - this node is a cross-community bridge._
- **Are the 3 inferred relationships involving `主题构筑` (e.g. with `项目核心定位` and `三角色切换`) actually correct?**
  _`主题构筑` has 3 INFERRED edges - model-reasoned connections that need verification._
- **Are the 2 inferred relationships involving `战斗循环` (e.g. with `项目核心定位` and `特效与判定贴合`) actually correct?**
  _`战斗循环` has 2 INFERRED edges - model-reasoned connections that need verification._