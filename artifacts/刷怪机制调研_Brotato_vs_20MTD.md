# 类幸存者游戏刷怪机制调研：《土豆兄弟》(Brotato) 与《20 Minutes Till Dawn》

> 用途：给用 Godot 做割草游戏的作者做设计参考。下面尽量用大白话讲，数字都标了出处。
> 调研日期：2026-09-28。仅覆盖这两款游戏的本体机制。

---

## 一、《土豆兄弟》(Brotato)

Brotato 走的是**"波次制"**：一局被切成 20 个独立波次，波次之间有商店喘息期。这和 20MTD 的"一条 20 分钟连续时间线"是两种截然不同的设计思路。

### 1. 刷怪触发节奏

- **纯时间驱动的波次制，不是杀怪计数驱动。** 一局固定 20 波；每一波有固定时长，倒计时一到这波就结束，哪怕场上还有怪没杀完。只有第 20 波（Boss 波）例外——必须把 Boss 打死才结束。（来源：https://brotato.wiki.spellsandguns.com/Waves ）
- **每波时长**：第 1 波 20 秒，之后每波加 5 秒，到第 9 波达到 60 秒并保持；第 9～19 波都是 60 秒；第 20 波 90 秒。（来源：https://brotato.wiki.spellsandguns.com/Waves ）
  - 即：W1=20s、W2=25s、W3=30s、W4=35s、W5=40s、W6=45s、W7=50s、W8=55s、W9–W19=60s、W20=90s。
- **波次之间怎么衔接**：每波结束后自动进入商店，玩家在商店里买完东西后**手动点"出发"**才开下一波——也就是说波次间隔是玩家自己控制的，没有倒计时逼你开下一波。（来源：https://brotato.wiki.spellsandguns.com/Waves ；商店自动进入、玩家手动开下一波：https://brotato.wiki.spellsandguns.com/index.php?oldid=7487&title=Shop ）
- **一波之内的出怪节奏**：每类怪在波内按固定间隔刷新，例如追击者（Chaser）波开始后 8 秒出第一批，之后每 8 秒刷一批；树（Tree）每 10 秒刷一棵。（来源：https://gameplay.tips/guides/brotato-ultimate-guide-to-enemies-and-waves.html ）
- **无尽模式**：打完第 20 波 Boss 后继续，之后每波也是 60 秒，难度随波次暴涨。（来源：https://brotato.wiki.spellsandguns.com/Endless_Mode ）

### 2. 生成位置规则

- 怪物**在地图边缘（edge of map）生成**，从四面八方朝玩家压过来。（来源：https://gameplay.tips/guides/brotato-ultimate-guide-to-enemies-and-waves.html ）
- 同类怪生成时**彼此不能太近**（指南里写"Cannot spawn next to each other, 100 range"），避免一刷就叠成一坨。（来源：https://gameplay.tips/guides/brotato-ultimate-guide-to-enemies-and-waves.html ）
- 竞技场是一个相对封闭的小区域，玩家活动范围有限，怪从四周边缘涌入。
- 关于"是否绕开玩家视野/距离"：**未能查到官方 Wiki 的明确说明**。以上"边缘生成、彼此间隔"来自社区逐波拆解指南。

### 3. 密度与难度曲线

- **同屏敌人上限 100 个**。新怪刷出来时如果超过 100，场上随机一个非精英、非 Boss 的怪会"凭空消失"且不掉材料（这是游戏自带的限流机制）。（来源：https://brotato.wiki.spellsandguns.com/Enemies ）
- **血量随波次线性增长**：每类怪有基础血量，从第 2 波起每波再加固定值（+hp/wave）。例如树（Tree）基础 10 血，每波 +5；追击者基础 10 血，每波 +24，所以第 11 波刚登场时是 10 + 10×24 = 250 血。（来源：https://brotato.wiki.spellsandguns.com/Enemies ；示例亦见 https://gameplay.tips/guides/brotato-ultimate-guide-to-enemies-and-waves.html ）
- **伤害也随波次线性增长**（+dmg/wave）；但**敌人速度不随波次/难度变化**（官方 Wiki 原文：Speed doesn't change with Wave or Danger level）。（来源：https://brotato.wiki.spellsandguns.com/Enemies ）
- **难度档位（Danger 0～5）**：高难度会直接加血量（如 Danger 5 额外 +40%）并提前解锁更强的怪、增加精英波。（来源：https://brotato.wiki.spellsandguns.com/Enemies ）
- 体感节奏：前期波短（20～40 秒）、怪弱、种类少；中期波长稳定在 60 秒、新怪陆续登场；后期靠血量/伤害线性堆叠压人。

### 4. 敌人类型构成

- **普通怪**：按波次逐步解锁登场，例如追击者（Chaser）要到第 11 波才出现；难度越高的怪登场越早。（来源：https://brotato.wiki.spellsandguns.com/Enemies ）
- **精英波 / 潮怪波（Elite / Horde Wave）**：属于"挑战波"，只在高难度出现——
  - Danger 0、1：没有；
  - Danger 2、3：整局出现 1 次（在第 11 或 12 波）；
  - Danger 4、5：出现 3 次，分别落在第 11–12 波、第 14–15 波、第 17–18 波，且第三次**必定是精英波**；前两次随机（40% 概率是潮怪波、60% 是精英波）。
  （来源：https://brotato.wiki.spellsandguns.com/Waves ）
- **Boss 波**：固定第 20 波（最后一波）出 1 个 Boss；Danger 5 难度出 2 个。打死即通关。（来源：https://brotato.wiki.spellsandguns.com/Waves 、https://brotato.wiki.spellsandguns.com/index.php?diff=7899&oldid=5283&title=Structures ）

### 5. 波次喘息期与奖励

- **每波结束 = 固定喘息 + 商店期**，且不限时：波一结束，地上材料自动吸进背包、消耗品和宝箱自动拾取，然后进入商店，玩家慢慢买武器/道具、升级、重随，最后手动开下一波。（来源：https://brotato.wiki.spellsandguns.com/Waves 、https://brotato.wiki.spellsandguns.com/index.php?oldid=7487&title=Shop ）
- **奖励与刷怪强绑定**：波内杀怪掉"材料（Materials）"，波结束后这些材料就是下一波商店的货币；杀得多 = 商店能买得更好 = 下一波更稳。也就是说"刷怪数量"直接兑换成"波间成长"。（来源：https://brotato.wiki.spellsandguns.com/Waves ）
- 商店每波自动进入、最多刷 4 个随机道具，可锁定。（来源：https://brotato.wiki.spellsandguns.com/index.php?oldid=7487&title=Shop ）

### Brotato 来源列表

| URL | 提供了什么 |
|---|---|
| https://brotato.wiki.spellsandguns.com/Waves | 官方 Wiki：20 波结构、每波时长表、精英/潮怪波出现波次与概率、第 20 波 Boss、波末商店流程 |
| https://brotato.wiki.spellsandguns.com/Enemies | 官方 Wiki：同屏 100 敌上限、血量/伤害随波线性增长、速度不随波变化、新怪登场波次 |
| https://brotato.wiki.spellsandguns.com/Endless_Mode | 官方 Wiki：无尽模式波次与难度变化 |
| https://brotato.wiki.spellsandguns.com/index.php?oldid=7487&title=Shop | 官方 Wiki：每波后自动进商店、玩家手动开下一波、商店道具数量 |
| https://gameplay.tips/guides/brotato-ultimate-guide-to-enemies-and-waves.html | 社区逐波拆解：怪在地图边缘生成、彼此 100 距离间隔、波内刷新间隔（8s/10s）、各类怪血量公式 |
| https://brotato.wiki.spellsandguns.com/index.php?diff=7899&oldid=5283&title=Structures | 官方 Wiki 历史版本：第 20 波必出 Boss（Danger 5 出两个） |

---

## 二、《20 Minutes Till Dawn》（20 分钟直到黎明，简称 20MTD）

20MTD 走的是**"一条连续时间线"**：一局就是 20 分钟倒计时，怪物持续不断地涌进来，没有 Brotato 那种一波一波切商店的断点。它更像《吸血鬼幸存者》。

### 1. 刷怪触发节奏

- **纯时间驱动，没有离散"波次"概念。** 标准模式就是一条 20 分钟倒计时，普通怪随时间持续涌入、越到后面越密；玩家要做的就是活满 20 分钟熬到天亮。（来源：https://handwiki.org/wiki/Software:20_Minutes_Till_Dawn ）
- **Boss 和精英是按固定时钟时间点刷的**（不是随机、也不是杀够数量）：
  - **精英怪**：在剩余时间 **17:00、8:45、4:00** 各出一波，击杀掉宝箱 + 36 经验。
  - **Boss**：在剩余时间 **15:00、5:00** 各出一只，击杀掉魔法书（Tome）。
  （来源：https://thewiki.kr/w/20%20Minutes%20Till%20Dawn ）
- **快速模式（Quickplay）**：一局缩成 10 分钟，但怪的出场**时间点和标准模式一致**（相当于把 20 分钟节奏压进 10 分钟里走）。（来源：https://thewiki.kr/w/20%20Minutes%20Till%20Dawn ）
- **无尽模式**：Boss 改为每 10 分钟循环一次，且整体出场时间点比标准模式**提前将近一倍**。（来源：https://thewiki.kr/w/20%20Minutes%20Till%20Dawn ）
- 另一社区攻略也佐证"Boss 是按时间点到点刷、而非随机"（来源：https://oyunclubnet.com/20-minutes-till-dawn-premium/ ，该来源为第三方攻略站，可信度中等，作为旁证）。

### 2. 生成位置规则

- 怪物从**黑暗里、玩家视野范围外**生成并靠近玩家。游戏特色就是"视野受限"——开局时周围一片漆黑，只能先看到黑暗中一对对发光的眼睛，等怪进入玩家视野/光圈后才看清全貌。（来源：https://handwiki.org/wiki/Software:20_Minutes_Till_Dawn ；中文侧同样描述"范围外是一双双紧盯着你的眼睛"：https://www.18183.com/xiazai/yx_400446.html ）
- 怪物从四面八方包围玩家（"close in from every direction"）。（来源：https://granny-games.com/20-minutes-till-dawn ；Steam 商店页描述"endless hordes... lurk from the dark"：https://store.steampowered.com/app/1966900/20/ ）
- 关于"具体在离玩家多远的圈外刷、是否有最小安全距离"：**未能查到官方给出的精确数值**（开发者 flanne 未公开此类参数）。

### 3. 密度与难度曲线

- **随时间推移，怪物数量持续增多、压迫感不断叠加**；越往后越密。（来源：https://dtf.ru/games/2373762-20-minutes-till-dawn-2023 ；https://gamediscoveryengine.com/game/20-minutes-till-dawn ）
- 社区普遍体感：**5～12 分钟是真正的考验**——此时怪潮开始重叠、精英混入人群，伤害不够就被淹没；很多新手死在这个窗口；到 15 分钟后成型的 build 反而能清屏。（来源：https://oyunclubnet.com/20-minutes-till-dawn-premium/ ，第三方攻略，作为体感参考）
- **难度由"黑暗等级（Darkness 0～15）"叠加修饰**，每提升一级就给怪物加一项数值，例如：
  - Darkness 1：小怪刷新频率 +25%；
  - Darkness 2：小怪血量 +25%；
  - Darkness 3：精英怪提前 25% 时间刷出；
  - Darkness 4：Boss 血量 +50%；
  - ……一直累加到 Darkness 15（Boss 攻击频率 +80%）。
  （来源：https://store.epicgames.com/news/20-minutes-till-dawn-guide-how-to-survive-and-thrive-at-the-highest-difficulties ）
- **无尽模式的血量随时间翻倍**：官方更新日志写明"无尽模式敌人血量随跑局时钟和刷新率一起缩放，每 20 分钟血量翻倍，之后每 20 分钟变三倍，80 分钟封顶"——这条来自 1.0.2 版本更新说明，可作为"时间驱动血量曲线"的直接证据。（来源：https://www.updatemonitor.com/app/3620890/news/1844115010495351 ）

### 4. 敌人类型构成

- **普通怪**：从开局持续刷出，种类随时间解锁（例如约 10 分钟后开始刷飞行怪）。（来源：https://www.cyberly.org/game-cheats/pc/20-minutes-till-dawn.html ）
- **精英怪**：固定时间点（17:00 / 8:45 / 4:00）出现的大型怪，打死掉宝箱（宝箱给三选一强力增益）。（来源：https://thewiki.kr/w/20%20Minutes%20Till_Dawn ；精英掉宝箱三选一：https://www.jetsonplaysgames.com/post/20-minutes-till-dawn-review ）
- **Boss**：固定时间点（15:00 / 5:00）出现，打死掉魔法书（Tome，一种带取舍的强化）。（来源：https://thewiki.kr/w/20%20Minutes%20Till_Dawn ）
- 另有隐藏 Boss（如森林图的树 Boss）需特殊条件触发，不属于常规刷怪节奏，此处不展开。

### 5. 波次喘息期与奖励

- **没有 Brotato 那种商店喘息期**，整局 20 分钟连续进行、不切场景。（来源：https://handwiki.org/wiki/Software:20_Minutes_Till_Dawn ）
- **唯一的"暂停喘息"来自升级**：杀怪掉经验宝石，升级时游戏暂停，弹出三选一升级让玩家选——这是把"成长"嵌在连续战斗里，而不是放在波间。（来源：https://handwiki.org/wiki/Software:20_Minutes_Till_Dawn ）
- **奖励与刷怪的关系**：刷怪 → 掉经验 → 升级三选一；精英掉宝箱、Boss 掉魔法书。成长节奏完全由"杀怪攒经验"驱动，和 20MTD 的时间线绑定。（来源：https://www.jetsonplaysgames.com/post/20-minutes-till-dawn-review ；https://thewiki.kr/w/20%20Minutes%20Till_Dawn ）

### 20MTD 来源列表

| URL | 提供了什么 |
|---|---|
| https://thewiki.kr/w/20%20Minutes%20Till%20Dawn | 韩国 Wiki：精英刷出时间点（17:00/8:45/4:00）与 Boss 时间点（15:00/5:00）、快速模式同节奏、无尽模式 Boss 每 10 分钟循环且提前约一倍、黑暗等级效果列表 |
| https://handwiki.org/wiki/Software:20_Minutes_Till_Dawn | 百科条目：20 分钟连续生存、无波次、视野受限只见怪眼、升级三选一、黑暗难度 0–15 |
| https://store.epicgames.com/news/20-minutes-till-dawn-guide-how-to-survive-and-thrive-at-the-highest-difficulties | Epic 官方指南：黑暗等级 1–15 具体修饰（刷新频率/血量/精英提前/Boss 血量等百分比） |
| https://www.updatemonitor.com/app/3620890/news/1844115010495351 | 官方 1.0.2 更新日志：无尽模式血量随时间每 20 分钟翻倍、离屏敌人优化 |
| https://www.jetsonplaysgames.com/post/20-minutes-till-dawn-review | 评测：精英/Boss 视觉区分、精英掉宝箱三选一、随时间怪越来越多 |
| https://store.steampowered.com/app/1966900/20/ | Steam 商店页：怪物从黑暗中四面八方涌来 |
| https://www.18183.com/xiazai/yx_400446.html | 中文站点：视野受限、黑暗中只见眼睛、包围偷袭 |
| https://www.cyberly.org/game-cheats/pc/20-minutes-till-dawn.html | 攻略：约 10 分钟后开始刷飞行怪等时间节点体感 |
| https://dtf.ru/games/2373762-20-minutes-till-dawn-2023 | 评测：随分钟推移敌人越来越多、无尽头 |
| https://oyunclubnet.com/20-minutes-till-dawn-premium/ | 第三方攻略（可信度中等，仅作体感旁证）：Boss 按时间到点刷、5–12 分钟为难度窗口 |

---

## 三、给 Godot 作者的一句话对比（速查）

- **Brotato = 切段式**：20 个独立波次，波内计时、波间不限时商店；怪从边缘刷、同屏上限 100、血量每波线性加。适合"打一波 → 逛商店强化 → 再打"的循环。
- **20MTD = 连续式**：一条 20 分钟时间线不断流，普通怪持续涌入，Boss/精英按固定分钟点砸下来；升级靠杀怪掉经验、升级时才暂停选牌。适合"压力随时间单调上升"的体验。
- 两款共同的关键做法：**都限制同屏数量 / 都把高难单位放在固定时间点而不是随机刷 / 都让"杀怪产出"直接兑换成"成长资源"**。
