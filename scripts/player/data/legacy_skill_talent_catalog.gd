extends RefCounted

# Retired 108-node data retained for compatibility; this catalog grants no runtime effects.

const TALENT_DEFINITIONS := {
	"swordsman_trait": [
		{"id": "swordsman_trait_blood_battle", "stage": 1, "side": "left", "title": "血战昂扬", "description": "战意实际治疗后，剑士总伤害 +15%，持续 3 秒；刷新不叠层。定位：残血反攻。", "upgrade_note": "额外触发次数和治疗强化提高触发收益；骑士荣耀持续时间同时延长血战昂扬。"},
		{"id": "swordsman_trait_last_guard", "stage": 1, "side": "right", "title": "最后的换防", "description": "剑士在后台时，可消耗满换位能量与骑士荣耀挽救一次前台角色，救回 30% 生命并强制剑士登场；80 秒冷却。定位：后台救援。", "upgrade_note": "治疗强化提高救回比例；骑士荣耀持续时间延长强制登场后的无敌。"},
		{"id": "swordsman_trait_blood_surge", "stage": 2, "side": "left", "title": "血涌", "description": "每次战意实际治疗后，下一次剑士伤害 +20%；2 秒内未命中则失效，与血战昂扬相加、不相乘。定位：治疗转爆发。", "upgrade_note": "额外触发次数提高获得血涌的频率；治疗量只影响触发前提。"},
		{"id": "swordsman_trait_guard_stance", "stage": 2, "side": "right", "title": "守势", "description": "每次战意实际治疗后，剑士承受伤害 -15%，持续 2 秒；刷新不叠层。定位：前排续航。", "upgrade_note": "治疗与额外触发次数提高覆盖率；骑士荣耀持续时间不延长守势。"},
		{"id": "swordsman_trait_head_high", "stage": 3, "side": "left", "title": "昂首", "description": "生命低于 50% 时触发战意实际治疗，获得 25% 移速与 15% 普攻攻速，持续 2 秒；刷新不叠层。定位：低血压迫。", "upgrade_note": "先结算基础攻击速度，再叠加昂首攻速；治疗强化只提高续航。"},
		{"id": "swordsman_trait_unyielding", "stage": 3, "side": "right", "title": "不屈", "description": "生命低于 35% 时触发战意实际治疗，获得 40% 减伤 1.2 秒；每 12 秒最多触发一次。定位：濒死稳场。", "upgrade_note": "治疗强化提高脱离斩杀线的能力；骑士荣耀与该减伤独立结算。"}
	],
	"swordsman_entry": [
		{"id": "swordsman_entry_long_charge", "stage": 1, "side": "left", "title": "长驱冲阵", "description": "首次冲锋命中后再向前突进 120 距离，造成首次伤害的 70%。定位：穿透进场。", "upgrade_note": "冲锋伤害同步作用首次与追加冲锋；70% 比例固定。"},
		{"id": "swordsman_entry_return_guard", "stage": 1, "side": "right", "title": "回马护阵", "description": "首次冲锋后沿原路返回起点，造成首次伤害的 70%。定位：切入后撤。", "upgrade_note": "冲锋伤害同步作用去程与回程；70% 比例固定。"},
		{"id": "swordsman_entry_break_formation", "stage": 2, "side": "left", "title": "裂阵", "description": "每段冲锋使命中敌人减速至 70%，持续 0.8 秒。定位：留人。", "upgrade_note": "伤害构筑不改变减速；长驱或回马增加可施加减速的冲锋段。"},
		{"id": "swordsman_entry_sheathe", "stage": 2, "side": "right", "title": "收锋", "description": "最后一段冲锋结束点产生半径 84 的剑震，造成当前冲锋伤害的 45%。定位：落点清场。", "upgrade_note": "伤害构筑同步作用剑震；45% 比例固定。"},
		{"id": "swordsman_entry_through_ranks", "stage": 3, "side": "left", "title": "贯军", "description": "每段冲锋线宽 +40%；单段命中至少 3 名敌人时获得 25% 移速 1.2 秒。定位：穿群换位。", "upgrade_note": "伤害构筑只提高伤害；不提高移速或命中门槛。"},
		{"id": "swordsman_entry_hold_line", "stage": 3, "side": "right", "title": "立阵", "description": "最后一段冲锋留下 1.5 秒剑痕，每 0.5 秒造成当前冲锋伤害的 30%。定位：封路。", "upgrade_note": "伤害构筑同步作用每跳；剑痕数量固定为 1。"}
	],
	"swordsman_basic": [
		{"id": "swordsman_basic_cross", "stage": 1, "side": "left", "title": "十字剑势", "description": "每第 3 次普攻追加一道垂直剑气，造成主斩 70% 伤害。定位：正面清群。", "upgrade_note": "伤害、范围和攻速同步作用主斩与追斩；70% 比例固定。"},
		{"id": "swordsman_basic_back", "stage": 1, "side": "right", "title": "背身斩", "description": "每次主斩同时向身后追加 45% 伤害斩击。定位：周身自保。", "upgrade_note": "伤害、范围和攻速同步作用正面与背身斩；45% 比例固定。"},
		{"id": "swordsman_basic_pursuit", "stage": 2, "side": "left", "title": "追锋", "description": "所有普攻剑斩长度 +25%、宽度 +20%。定位：安全距离清线。", "upgrade_note": "普攻范围构筑与该形态相乘；伤害、攻速作用全部派生斩击。"},
		{"id": "swordsman_basic_opening", "stage": 2, "side": "right", "title": "破绽", "description": "每第 3 段连击的主斩伤害 +20%，并使命中敌人减速至 75%，持续 1 秒。定位：节奏处决。", "upgrade_note": "攻速强化加快第三段循环；伤害强化先结算，再加 20%。"},
		{"id": "swordsman_basic_sword_wheel", "stage": 3, "side": "left", "title": "剑轮", "description": "每第 3 段连击额外向左右各挥一道 35% 伤害斩击。定位：第三段清场。", "upgrade_note": "范围、伤害、攻速同步作用追加斩；每道 35% 比例固定。"},
		{"id": "swordsman_basic_cooldown_cut", "stage": 3, "side": "right", "title": "截流", "description": "普攻击杀敌人时，当前普攻间隔缩短 12%；每 0.6 秒最多触发一次。定位：高密度续攻。", "upgrade_note": "立即按新最终攻击速度换算并缩短当前剩余攻击间隔。"}
	],
	"swordsman_blade_storm": [
		{"id": "swordsman_blade_storm_retain", "stage": 1, "side": "left", "title": "随身风暴", "description": "切换角色后，风暴跟随当前角色完成剩余持续时间，伤害降为 70%。定位：后台贡献。", "upgrade_note": "伤害、范围、冷却同步作用施放与跟随阶段；70% 比例固定。"},
		{"id": "swordsman_blade_storm_stationary", "stage": 1, "side": "right", "title": "驻地风暴", "description": "风暴固定在施放地点，命中使敌人减速至 70%。定位：据点控制。", "upgrade_note": "伤害、范围、冷却继续作用固定风暴；减速固定。"},
		{"id": "swordsman_blade_storm_rending_spin", "stage": 2, "side": "left", "title": "裂旋", "description": "每第 3 次跳伤额外扩张至当前半径 135%，造成当前单跳 50% 伤害。定位：周期外圈清群。", "upgrade_note": "范围先放大基础风暴，再计算 135%；伤害同步作用外圈。"},
		{"id": "swordsman_blade_storm_recall", "stage": 2, "side": "right", "title": "卷回", "description": "敌人首次离开风暴范围时，被拉向风暴中心至当前半径 70% 的位置，单次位移最多 90；同一敌人 0.75 秒内不重复触发。定位：主动留人。", "upgrade_note": "范围构筑扩大触发边界与目标落点；伤害、冷却不改变 90 的位移上限。"},
		{"id": "swordsman_blade_storm_after_howl", "stage": 3, "side": "left", "title": "余啸", "description": "风暴结束时，每个当前风暴中心爆发一次，半径等于当前风暴半径，伤害为当前单跳 90%。定位：收束爆发。", "upgrade_note": "伤害、范围同步作用终爆；额外风暴各自只爆发一次。"},
		{"id": "swordsman_blade_storm_returning_gale", "stage": 3, "side": "right", "title": "回风", "description": "风暴结束时，当前站场角色获得 30% 减伤 1 秒；每个施放实例只触发一次。定位：用结束时机保护换人。", "upgrade_note": "持续时间强化改变保护触发时点；伤害、范围、冷却继续独立生效。"}
	],
	"swordsman_crescent_wave": [
		{"id": "swordsman_crescent_return", "stage": 1, "side": "left", "title": "月返", "description": "月牙抵达终点后返回一次，返程伤害为去程 60%。定位：双向扫线。", "upgrade_note": "伤害、速度、冷却同步作用往返；60% 比例固定。"},
		{"id": "swordsman_crescent_full_moon", "stage": 1, "side": "right", "title": "满月重刃", "description": "剑气长度由 430 变为 280、宽度由 74 变为 150、基础速度变为 500，形成近中距离横扫。定位：贴脸扇扫。", "upgrade_note": "伤害、速度、冷却继续生效；速度从满月基础 500 起算。"},
		{"id": "swordsman_crescent_twin_moons", "stage": 2, "side": "left", "title": "双月", "description": "每次施放在主方向旁额外发射一道偏转 18°、55% 伤害的月牙。定位：扇区覆盖。", "upgrade_note": "伤害、速度作用全部月牙；额外月牙 55% 比例固定。"},
		{"id": "swordsman_crescent_frost_trail", "stage": 2, "side": "right", "title": "霜痕", "description": "月牙使命中敌人减速至 80%，持续 0.6 秒。定位：远程牵制。", "upgrade_note": "往返均可刷新减速；伤害、速度、冷却不改变减速值。"},
		{"id": "swordsman_crescent_eclipse", "stage": 3, "side": "left", "title": "月蚀", "description": "每道月牙完整结束时爆发半径 86、造成当前月牙伤害 70% 的冲击；月返仅在返程结束时爆发一次。定位：终点收割。", "upgrade_note": "伤害同步作用终爆；速度只改变到达时间。"},
		{"id": "swordsman_crescent_afterimage", "stage": 3, "side": "right", "title": "照返", "description": "施放后 0.25 秒沿原主方向追加一道 60% 射程、45% 伤害的残影；残影不触发月返或照返。定位：延迟补刀。", "upgrade_note": "伤害、速度作用残影；射程与伤害比例固定，禁止递归派生。"}
	],
	"swordsman_ultimate": [
		{"id": "swordsman_ultimate_king", "stage": 1, "side": "left", "title": "擒王", "description": "存在 Boss 时优先追击最近 Boss，命中 Boss 的线斩伤害 +30%。定位：单体终结。", "upgrade_note": "伤害构筑作用全部线斩；Boss 增伤随后结算。"},
		{"id": "swordsman_ultimate_blossom", "stage": 1, "side": "right", "title": "剑华", "description": "每次线斩终点产生半径 70、线斩伤害 30% 的爆发。定位：群体收束。", "upgrade_note": "伤害构筑同步作用线斩与剑华；30% 比例固定。"},
		{"id": "swordsman_ultimate_pursuit", "stage": 2, "side": "left", "title": "追命", "description": "只统计每道基础线斩的主选目标；连续 3 道命中同一主目标后，下一道基础线斩锁定该目标，并对沿线其他敌人结算 70% 线斩伤害，随后重置。锁定目标提前死亡时依次改锁最近 Boss、精英、普通敌人；无目标则照常斩击。定位：追击中调整斩线。", "upgrade_note": "伤害构筑同步作用锁定斩与沿线伤害；70% 比例固定。"},
		{"id": "swordsman_ultimate_hold_ground", "stage": 2, "side": "right", "title": "镇场", "description": "每次线斩终点产生半径 84 的余震，使敌人减速至 50%，持续 0.75 秒，不造成伤害。定位：群控撤离。", "upgrade_note": "剑华可与余震共存；伤害构筑不改变减速。"},
		{"id": "swordsman_ultimate_final_judgement", "stage": 3, "side": "left", "title": "终决", "description": "最后一道基础线斩伤害变为 180%、线宽 +40%；不计祝福追加段。定位：尾段处决。", "upgrade_note": "伤害构筑先结算，再乘 180%；剑华读取终决后的线斩伤害。"},
		{"id": "swordsman_ultimate_triumph", "stage": 3, "side": "right", "title": "凯旋", "description": "大招结束后获得 30% 减伤与 20% 移速，持续 2 秒，随后照常进入嗜血窗口。定位：终结后接管战场。", "upgrade_note": "大招伤害构筑不影响凯旋；特性治疗强化继续作用后续嗜血。"}
	],
	"gunner_trait": [
		{"id": "gunner_trait_clear_hunt", "stage": 1, "side": "left", "title": "清场猎手", "description": "猎杀圈内无敌人时，每 1.25 秒获得 1 层瞬杀；敌人进入时暂停积累。定位：拉开安全距离。", "upgrade_note": "安全圈、圈外伤害和每层瞬杀收益照常生效。"},
		{"id": "gunner_trait_invade_hunt", "stage": 1, "side": "right", "title": "侵入猎场", "description": "猎杀圈内有敌人时，每 1.25 秒获得 1 层瞬杀；基础圈内伤害倍率由 40% 提高到 75%。定位：近身压迫。", "upgrade_note": "安全圈缩小和普通圈内伤害强化继续作用；75% 为本形态固定基础倍率。"},
		{"id": "gunner_trait_far_calibration", "stage": 2, "side": "left", "title": "远猎校准", "description": "命中安全圈外敌人时施加 6% 易伤 0.8 秒；刷新不叠层。定位：远程点杀。", "upgrade_note": "圈外伤害先结算，易伤随后作用；安全圈缩小会改变触发距离。"},
		{"id": "gunner_trait_repulse", "stage": 2, "side": "right", "title": "拒近", "description": "首次命中安全圈内敌人时，将普通敌人沿远离枪手方向击退 42 距离；同目标 1.2 秒内不重复触发，Boss 免疫。定位：贴脸脱围。", "upgrade_note": "圈内伤害和瞬杀收益照常；安全圈缩小会改变触发距离。"},
		{"id": "gunner_trait_execution", "stage": 3, "side": "left", "title": "十层处决", "description": "瞬杀达到 10 层后，下一次伤害消耗 5 层并使该次伤害 +60%；2.5 秒内置冷却。定位：保层换斩杀。", "upgrade_note": "每层瞬杀强化照常生效；本节点不改变层数上限。"},
		{"id": "gunner_trait_escape_step", "stage": 3, "side": "right", "title": "险地滑步", "description": "受伤且瞬杀至少 5 层时，仍清空瞬杀，但获得 35% 移速 1.5 秒；每次瞬杀冷却只触发一次。定位：受击撤离。", "upgrade_note": "每层伤害、移速、闪避强化照常；不改变受伤清层规则。"}
	],
	"gunner_entry": [
		{"id": "gunner_entry_focus", "stage": 1, "side": "left", "title": "聚焦礼炮", "description": "登场技改为 3 波五发前向扇射，每发造成原伤害 35%。定位：定向清线。", "upgrade_note": "登场伤害同步作用全部 15 发；35% 比例固定。"},
		{"id": "gunner_entry_denial", "stage": 1, "side": "right", "title": "封锁礼炮", "description": "登场技改为 2 波十二发环射，每发 50% 伤害并减速 40% 1.5 秒。定位：换人解围。", "upgrade_note": "登场伤害同步作用全部 24 发；伤害比例和减速固定。"},
		{"id": "gunner_entry_piercing", "stage": 2, "side": "left", "title": "穿阵", "description": "所有登场子弹穿透 +4。定位：穿透长队。", "upgrade_note": "登场伤害先结算；本节点只改变可命中数量。"},
		{"id": "gunner_entry_repulse", "stage": 2, "side": "right", "title": "制退", "description": "登场子弹首次命中时，将普通敌人沿弹道方向击退 48 距离；Boss 免疫。定位：建立射击距离。", "upgrade_note": "伤害构筑只增强子弹；聚焦与封锁礼炮均获得击退。"},
		{"id": "gunner_entry_follow_fire", "stage": 3, "side": "left", "title": "续火", "description": "最后一波结束后获得 1.4 秒换弹窗口：普攻攻速提高（等效原间隔缩短25%）、穿透 +1。定位：入场接管输出。", "upgrade_note": "普攻伤害、攻速、射程继续作用；窗口不延长登场技。"},
		{"id": "gunner_entry_hot_start", "stage": 3, "side": "right", "title": "热启动", "description": "最后一波礼炮结束后，使已解锁的散弹和无限装填当前剩余冷却各减少 25%，每项最多 4 秒。定位：换人接技能循环。", "upgrade_note": "登场伤害只强化礼炮；主动技能冷却构筑决定可缩减的实际剩余时间。"}
	],
	"gunner_basic": [
		{"id": "gunner_basic_armor", "stage": 1, "side": "left", "title": "破甲重弹", "description": "每第 4 次攻击发射 2 倍伤害、更大且高穿透的重弹。定位：节奏突破。", "upgrade_note": "伤害、射程、攻击间隔同步作用；重弹始终读取强化后的普攻伤害。"},
		{"id": "gunner_basic_burst", "stage": 1, "side": "right", "title": "三连点射", "description": "每次攻击改为三发短点射，每发 42% 伤害。定位：稳定压制。", "upgrade_note": "三发继承伤害与射程；攻击间隔作用于整组点射。"},
		{"id": "gunner_basic_mark", "stage": 2, "side": "left", "title": "定标", "description": "普攻命中施加 6% 易伤 1 秒；刷新不叠层。定位：精英集火。", "upgrade_note": "普攻伤害增强施加易伤前的首击；射程扩大标记距离。"},
		{"id": "gunner_basic_penetration", "stage": 2, "side": "right", "title": "穿排", "description": "普攻子弹穿透 +2、命中半径 +20%。定位：横排清怪。", "upgrade_note": "射程继续增加飞行距离；伤害与间隔保持完整收益。"},
		{"id": "gunner_basic_steady_aim", "stage": 3, "side": "left", "title": "稳枪", "description": "静止 0.45 秒后，持续获得普攻伤害 +18%；移动立即失效。定位：定点 DPS。", "upgrade_note": "伤害构筑先结算，再加 18%；冷却构筑提高收益频率。"},
		{"id": "gunner_basic_mobile_fire", "stage": 3, "side": "right", "title": "走射", "description": "移动时普攻射程 +70、弹速 +25%，伤害不变。定位：风筝输出。", "upgrade_note": "射程构筑先计入，再加 70；伤害与冷却完整保留。"}
	],
	"gunner_shrapnel": [
		{"id": "gunner_shrapnel_mobile", "stage": 1, "side": "left", "title": "机动弹幕", "description": "两处固定散弹场合并为跟随枪手的单一弹幕场，主场每跳伤害 ×1.5、半径 ×1.2。定位：贴身推进。", "upgrade_note": "伤害、半径先结算，再乘形态倍率；冷却强化只作用基础技能冷却。"},
		{"id": "gunner_shrapnel_delayed", "stage": 1, "side": "right", "title": "延迟引爆", "description": "基础散弹场自然结束时爆炸，伤害为当前每跳 250%，并续接减速。定位：预判封路。", "upgrade_note": "每跳伤害和半径同步作用终爆；250% 比例固定。"},
		{"id": "gunner_shrapnel_rend", "stage": 2, "side": "left", "title": "割裂", "description": "被散弹命中的敌人获得 5% 易伤 0.8 秒；刷新不叠层。定位：为其他火力铺垫。", "upgrade_note": "伤害、半径提高首段与覆盖；易伤固定。"},
		{"id": "gunner_shrapnel_snare", "stage": 2, "side": "right", "title": "陷停", "description": "敌人离开散弹场后仍保留 25% 减速 0.65 秒。定位：留人。", "upgrade_note": "半径扩大控制区；原有减速与本效果取更强值。"},
		{"id": "gunner_shrapnel_quick_throw", "stage": 3, "side": "left", "title": "速抛", "description": "冷却 ×0.78，持续时间 ×0.80，持续时间最低 2.4 秒。定位：高频抢点。", "upgrade_note": "冷却构筑先结算后再 ×0.78；持续强化先结算后再 ×0.80。"},
		{"id": "gunner_shrapnel_afterfield", "stage": 3, "side": "right", "title": "余烬", "description": "每个主散弹场自然结束时留下 1 秒余烬场，半径为当前场 60%；每 0.5 秒造成当前每跳 30% 伤害并减速 20%。定位：终场封路。", "upgrade_note": "伤害、半径同步作用余烬；持续时间固定，延迟引爆仍只爆发一次。"}
	],
	"gunner_infinite_reload": [
		{"id": "gunner_infinite_axis", "stage": 1, "side": "left", "title": "轴线贯穿", "description": "锁定初始方向，长度 ×1.25、宽度 ×0.55、每跳伤害 ×1.55。定位：直线穿透。", "upgrade_note": "伤害、长度、移速、冷却全部作用；形态倍率固定。"},
		{"id": "gunner_infinite_dual", "stage": 1, "side": "right", "title": "双轨齐射", "description": "变为两条平行光束，每条造成 60% 伤害。定位：双通道覆盖。", "upgrade_note": "两条光束分别继承伤害、长度、移速、冷却；每条 60% 固定。"},
		{"id": "gunner_infinite_sweep", "stage": 2, "side": "left", "title": "横扫", "description": "光束围绕当前瞄准轴在 ±14° 内往返扫动，周期 0.7 秒；轴线贯穿围绕锁定方向扫动。定位：横向清群。", "upgrade_note": "长度与伤害完整保留；不额外增加宽度。"},
		{"id": "gunner_infinite_sear", "stage": 2, "side": "right", "title": "灼印", "description": "光束命中施加 6% 易伤 0.45 秒；持续命中只刷新。定位：持续集火。", "upgrade_note": "伤害提高首跳；长度提高挂印距离；冷却不改变易伤。"},
		{"id": "gunner_infinite_overload", "stage": 3, "side": "left", "title": "终端过载", "description": "持续结束时沿最后朝向追加一次 600% 当前每跳伤害的终端光束，长度 ×1.15、宽度 ×0.6。定位：结束爆发。", "upgrade_note": "伤害、长度同步作用终端光束；只结算一次。"},
		{"id": "gunner_infinite_recycle", "stage": 3, "side": "right", "title": "冷却回收", "description": "本次持续至少命中一次后，结束时减少当前剩余冷却 15%，最多 3 秒。定位：命中换循环。", "upgrade_note": "冷却构筑先决定初始冷却；空放不返还。"}
	],
	"gunner_ultimate": [
		{"id": "gunner_ultimate_line", "stage": 1, "side": "left", "title": "线列轰炸", "description": "锥角 ×0.4、射程 ×1.3、每波伤害 ×1.55。定位：远程直线压制。", "upgrade_note": "新增波次继续使用线列形态；1.55 倍固定。"},
		{"id": "gunner_ultimate_fan", "stage": 1, "side": "right", "title": "广域覆盖", "description": "锥角 ×2.4、最高 140°，射程 ×0.85、每波伤害 ×0.70。定位：广域清场。", "upgrade_note": "新增波次继续使用广域形态；伤害惩罚固定。"},
		{"id": "gunner_ultimate_calibration", "stage": 2, "side": "left", "title": "校射", "description": "开始瞄准时记录固定锚点；当前方向在锚点 ±6° 内保持 0.5 秒后进入校射，后续波次伤害 +18%。偏离超过 6° 时以当前方向重设锚点并重新计时。定位：稳准操作换火力。", "upgrade_note": "波次构筑增加稳定瞄准后的收益次数。"},
		{"id": "gunner_ultimate_sweep_suppression", "stage": 2, "side": "right", "title": "扫压", "description": "保持实时瞄准；每波首次命中普通敌人时沿射线击退 24 距离，精英与 Boss 不击退。定位：移动扫场。", "upgrade_note": "波次构筑增加扫退次数；不额外提高伤害。"},
		{"id": "gunner_ultimate_terminal_guidance", "stage": 3, "side": "left", "title": "终端制导", "description": "每第 4 个伤害波，对锥形内最近精英或 Boss 额外结算 55% 当前波伤害；无目标则不触发。定位：首领路径。", "upgrade_note": "波次构筑增加触发机会；额外命中不生成新弹幕。"},
		{"id": "gunner_ultimate_delayed_fire", "stage": 3, "side": "right", "title": "延时火力", "description": "总持续时间 +1 秒；延长段伤害波为正常波 70% 伤害。定位：持续清场。", "upgrade_note": "波次构筑作用延长段；70% 比例固定。"}
	],
	"mage_trait": [
		{"id": "mage_trait_relay", "stage": 1, "side": "left", "title": "奥能接力", "description": "奥数充能转移后，可在两名非术师角色间额外接力一次。定位：轮转续航。", "upgrade_note": "概率、每层回能和同步比例继续生效；接力保留层数与剩余时间。"},
		{"id": "mage_trait_ultimate", "stage": 1, "side": "right", "title": "奥能终式", "description": "充能持有者施放终结技时，每层使最终伤害 +2%，最高 20%，随后清空。定位：换人爆发。", "upgrade_note": "概率、每层回能和同步比例在消费前继续生效。"},
		{"id": "mage_trait_flow", "stage": 2, "side": "left", "title": "延流", "description": "奥数充能转移持续时间每层额外 +0.4 秒；10 层最多额外 +4 秒。定位：长轮转窗口。", "upgrade_note": "同步比例仍按层数计算；本节点只延长有效期。"},
		{"id": "mage_trait_overflow", "stage": 2, "side": "right", "title": "满溢", "description": "奥法盈余自然结束且术师仍在场时，额外获得 2 层奥数充能，与现有 3 层相加，仍封顶 10。定位：站场蓄能。", "upgrade_note": "奥法盈余持续强化增加完成自然结束的窗口。"},
		{"id": "mage_trait_relay_chain", "stage": 3, "side": "left", "title": "复继", "description": "充能从一名非术师角色切换到另一名非术师角色时，至少允许 1 次转移，并保留剩余时间的 70%；已有奥能接力时再多允许 1 次。定位：完整三人轮转。", "upgrade_note": "每层回能与同步按保留层数继续生效；不复制层数。"},
		{"id": "mage_trait_dawn", "stage": 3, "side": "right", "title": "启明", "description": "术师离场转移充能时若至少有 8 层，则记录一次启明；下次术师登场时消费启明，使奥法盈余额外 +2 秒。定位：再入场循环。", "upgrade_note": "充能概率加快达成门槛；盈余持续强化继续相加。启明需要存档，死亡或开发者清除本节点时移除。"}
	],
	"mage_entry": [
		{"id": "mage_entry_center", "stage": 1, "side": "left", "title": "雷环归心", "description": "五道环形落雷后，中心追加一次 150% 范围、60% 伤害落雷。定位：近场清群。", "upgrade_note": "奥法盈余持续强化照常作用；中心雷比例固定。"},
		{"id": "mage_entry_mark", "stage": 1, "side": "right", "title": "雷印点名", "description": "登场落雷优先命中范围内至多 5 个不同敌人，剩余次数补回雷环。定位：精准开场。", "upgrade_note": "盈余持续强化不改变点名数量。"},
		{"id": "mage_entry_static", "stage": 2, "side": "left", "title": "滞雷", "description": "每道登场落雷使命中敌人减速 20%，持续 1.25 秒。定位：进场控场。", "upgrade_note": "中心雷和点名雷均可施加；盈余强化不放大减速。"},
		{"id": "mage_entry_echo", "stage": 2, "side": "right", "title": "续雷", "description": "雷群结束 0.45 秒后，对本次命中数最多的落点追加两道 35% 伤害落雷。定位：进场补伤。", "upgrade_note": "每道读取当前术师伤害；盈余持续强化不增加雷数。"},
		{"id": "mage_entry_canopy", "stage": 3, "side": "left", "title": "雷幕", "description": "落雷区域保留 1.5 秒电场；敌人首次进入时受到 30% 单雷伤害并减速 15%，每敌人一次。定位：封路。", "upgrade_note": "电场读取当前单雷伤害；范围固定为落雷半径。"},
		{"id": "mage_entry_surge", "stage": 3, "side": "right", "title": "盈流", "description": "本次雷群命中至少 5 个敌人时立即获得 2 层奥数充能；每次登场最多一次。定位：清群后准备下一次轮转。", "upgrade_note": "充能概率、每层回能和同步强化作用新增层数；盈余持续强化保持独立。"}
	],
	"mage_basic": [
		{"id": "mage_basic_aftershock", "stage": 1, "side": "left", "title": "奥术余震", "description": "主爆炸 0.35 秒后在原处追加一次 45% 伤害余震。定位：定点压制。", "upgrade_note": "主爆与余震同步继承伤害、范围；45% 比例固定。"},
		{"id": "mage_basic_triangle", "stage": 1, "side": "right", "title": "三角术式", "description": "主爆分裂为三角形三点，每点范围 70%、伤害 40%。定位：分散清群。", "upgrade_note": "三个节点分别继承伤害、范围；比例固定。"},
		{"id": "mage_basic_quickcast", "stage": 2, "side": "left", "title": "速决", "description": "预警时长缩短 25%，爆炸间隔不变。定位：提高走位命中率。", "upgrade_note": "范围强化继续作用更快落下的爆炸；不增加伤害。"},
		{"id": "mage_basic_frostburst", "stage": 2, "side": "right", "title": "寒爆", "description": "每次基础爆炸命中施加 20% 减速 0.8 秒；同一目标只刷新。定位：控群。", "upgrade_note": "余震和三角节点均可施加；伤害、范围不改变减速。"},
		{"id": "mage_basic_gravemark", "stage": 3, "side": "left", "title": "牵星", "description": "每次基础爆炸将中心半径内敌人向落点轻拉 0.25 秒；不作用 Boss。定位：聚怪。", "upgrade_note": "范围强化扩大牵引判定；伤害强化不放大牵引。"},
		{"id": "mage_basic_rift", "stage": 3, "side": "right", "title": "裂隙", "description": "每次主爆首次命中精英或 Boss 时，在目标位置追加一次 25% 伤害小爆炸；每次攻击最多一次。定位：精英补伤。", "upgrade_note": "伤害强化提高小爆炸基数；三角和余震不重复触发。"}
	],
	"mage_meta_field": [
		{"id": "mage_meta_transfer", "stage": 1, "side": "left", "title": "领域转移", "description": "切换角色后领域跟随下一角色 4 秒，范围 ×0.75、伤害 ×0.50、减速效果 ×0.50，且不再减伤。定位：保护轮转。", "upgrade_note": "范围、伤害、减速先结算，再按转移倍率衰减。"},
		{"id": "mage_meta_collapse", "stage": 1, "side": "right", "title": "领域坍缩", "description": "切换角色时立即结束领域并爆发 2 倍当前每跳伤害，随后进入 8 秒冷却。定位：切人爆发。", "upgrade_note": "范围、伤害、减速同步作用坍缩；2 倍比例固定。"},
		{"id": "mage_meta_expansion", "stage": 2, "side": "left", "title": "扩域", "description": "每次跳伤后领域半径向外扩张 12%，最多 3 次；领域结束后复位。定位：持续站场换覆盖。", "upgrade_note": "范围构筑决定初始半径，再逐次扩张；伤害与减伤不额外增长。"},
		{"id": "mage_meta_stasis", "stage": 2, "side": "right", "title": "凝滞", "description": "领域减速额外 +12 个百分点，上限仍为 95%。定位：保命控场。", "upgrade_note": "普通减速继续累加后封顶；转移领域按现有比例衰减。"},
		{"id": "mage_meta_inner_ring", "stage": 3, "side": "left", "title": "内环", "description": "内环半径为当前领域半径 60%；敌人每次领域开启后首次进入内环时，被向领域中心轻拉 36 距离；Boss 免疫。定位：聚怪与站位奖励。", "upgrade_note": "范围强化同步扩大内环；伤害、减速、减伤不改变拉回距离。"},
		{"id": "mage_meta_guard_pulse", "stage": 3, "side": "right", "title": "护脉", "description": "领域开启时立即回复术师最大生命 4%；每次开启一次。定位：主动防御。", "upgrade_note": "减伤、范围、持续伤害完整保留；不转化为治疗倍率。"}
	],
	"mage_surging_wave": [
		{"id": "mage_surge_four", "stage": 1, "side": "left", "title": "四向潮涌", "description": "基础波向四个正交方向发射，每道 55% 伤害、生命周期 ×0.75。定位：全向解围。", "upgrade_note": "伤害、持续、速度、冷却同步作用每道波，再结算 55% 伤害与 0.75 生命周期。"},
		{"id": "mage_surge_back", "stage": 1, "side": "right", "title": "逆潮回响", "description": "基础前向波 0.8 秒后，从当前角色位置反向追加 70% 伤害、生命周期 ×0.75 的波。定位：走位折返。", "upgrade_note": "正反两波同步继承伤害、持续、速度、冷却；反向波再结算固定比例。"},
		{"id": "mage_surge_vortex", "stage": 2, "side": "left", "title": "涡流", "description": "波宽 +30%、速度 -15%，首次命中使敌人减速 20% 1 秒。定位：守点控线。", "upgrade_note": "速度强化先加后乘 0.85；持续强化直接延长覆盖。"},
		{"id": "mage_surge_rapid", "stage": 2, "side": "right", "title": "疾潮", "description": "速度 +30%、生命周期 -15%；首次命中精英或 Boss 时额外造成 15% 伤害。定位：远距点杀。", "upgrade_note": "速度强化先加后乘 1.30；15% 额外伤害只继承伤害强化；每波每目标一次。"},
		{"id": "mage_surge_heavy", "stage": 3, "side": "left", "title": "重潮", "description": "每道波在生命周期最后 0.4 秒进入重潮：宽度 +35%、速度 -20%、伤害 +20%。定位：尾段压线。", "upgrade_note": "伤害、持续、速度先结算；重潮比例随后作用，所有路径均可触发。"},
		{"id": "mage_surge_wake", "stage": 3, "side": "right", "title": "潮痕", "description": "每次基础波经过处留下 1.2 秒潮痕，敌人首次踏入时受到当前波伤害 20%，每敌人一次。定位：封走位。", "upgrade_note": "伤害强化提高潮痕基数；持续强化不延长潮痕。"}
	],
	"mage_ultimate": [
		{"id": "mage_ultimate_lock", "stage": 1, "side": "left", "title": "星落锁定", "description": "锁定 Boss 或单一敌人追踪轰炸，范围 70%、伤害 ×1.25。定位：Boss 处决。", "upgrade_note": "新增轰炸次数继续追踪同一目标；形态比例固定。"},
		{"id": "mage_ultimate_triangle", "stage": 1, "side": "right", "title": "三星阵列", "description": "锁定敌群中心周围三个节点，轰炸依次循环落于节点，范围 80%。定位：群体覆盖。", "upgrade_note": "新增轰炸次数继续在三个节点轮转。"},
		{"id": "mage_ultimate_eclipse", "stage": 2, "side": "left", "title": "星蚀", "description": "后续基础脉冲最终伤害为 `基础脉冲最终伤害 × (1 + 0.04 × 已完成基础脉冲数)`，最多计 5 次，即最高 ×1.20；大招结束清除。定位：长轴递增。", "upgrade_note": "轰炸次数增加递增段数，但总增幅上限仍为 20%；三星阵列路径同样有效。"},
		{"id": "mage_ultimate_afterglow", "stage": 2, "side": "right", "title": "余晖", "description": "最后一次轰炸额外造成 160% 单脉冲伤害、125% 范围的一击。定位：收尾爆发。", "upgrade_note": "轰炸次数只推迟终击，不增加终击次数。"},
		{"id": "mage_ultimate_canopy", "stage": 3, "side": "left", "title": "穹顶", "description": "所有脉冲半径 +15%、单脉冲伤害 -8%。定位：大范围清场。", "upgrade_note": "轰炸次数增加覆盖次数；伤害惩罚固定。"},
		{"id": "mage_ultimate_scorch", "stage": 3, "side": "right", "title": "焦土", "description": "最后落点形成 2 秒焦土，每 0.5 秒造成 25% 单脉冲伤害。定位：留场压制。", "upgrade_note": "伤害强化提高焦土基数；轰炸次数不增加焦土数量。"}
	]
}

const TALENT_BUILD_PROJECTIONS := {
	"swordsman_trait_blood_battle": {
		"trait_extra_roll": "额外战意检定使3秒+15%总伤更频繁刷新",
		"trait_heal_bonus": "治疗强化仅提高战意实际治疗覆盖，不改变+15%与3秒",
		"knight_glory_duration": "骑士荣耀持续加成同时延长血战昂扬持续时间"
	},
	"swordsman_trait_last_guard": {
		"trait_extra_roll": "不影响换防救援",
		"trait_heal_bonus": "提高救回生命比例（基础30%按治疗强化结算）",
		"knight_glory_duration": "延长强制登场后的无敌窗口；80秒冷却不变"
	},
	"swordsman_trait_blood_surge": {
		"trait_extra_roll": "提高治疗触发频率，因而更频繁获得下一次伤害+20%",
		"trait_heal_bonus": "只提高治疗量/触发前提，不改变+20%与2秒",
		"knight_glory_duration": "不影响血涌持续或+20%倍率"
	},
	"swordsman_trait_guard_stance": {
		"trait_extra_roll": "提高治疗触发频率，增加-15%减伤覆盖率（每次2秒）",
		"trait_heal_bonus": "提高实际治疗与触发覆盖，不改变-15%与2秒",
		"knight_glory_duration": "明确不影响守势持续时间"
	},
	"swordsman_trait_head_high": {
		"trait_extra_roll": "提高低于50%时治疗触发频率，增加昂首2秒窗口覆盖",
		"trait_heal_bonus": "只提高续航治疗，不改变25%移速/15%攻速/2秒",
		"knight_glory_duration": "不影响昂首2秒窗口"
	},
	"swordsman_trait_unyielding": {
		"trait_extra_roll": "不改变不屈每12秒一次限制",
		"trait_heal_bonus": "提高濒危触发后的实际治疗；40%减伤/1.2秒不变",
		"knight_glory_duration": "与不屈40%减伤独立，不延长1.2秒"
	},
	"swordsman_entry_long_charge": {
		"entry_damage": "冲锋伤害先强化，追加突进读取首次伤害70%。"
	},
	"swordsman_entry_return_guard": {
		"entry_damage": "冲锋伤害先强化，去程与回程均读取去程伤害70%。"
	},
	"swordsman_entry_break_formation": {
		"entry_damage": "仅提高每段冲锋伤害；减速至70%与0.8秒不变。"
	},
	"swordsman_entry_sheathe": {
		"entry_damage": "冲锋伤害先强化，末段剑震读取当前冲锋伤害45%。"
	},
	"swordsman_entry_through_ranks": {
		"entry_damage": "仅提高每段冲锋伤害；线宽+40%、3人门槛和25%移速1.2秒不变。"
	},
	"swordsman_entry_hold_line": {
		"entry_damage": "冲锋伤害先强化，剑痕每跳读取当前冲锋伤害30%；持续1.5秒、每0.5秒一跳。"
	},
	"swordsman_basic_cross": {
		"basic_attack_cooldown": "降低主斩攻击间隔，使每第3次十字追加斩更快；70%比例不变",
		"basic_attack_damage": "主斩伤害先强化，十字追斩读取主斩伤害70%",
		"basic_attack_range": "扩大主斩并同步扩大垂直追斩判定；70%不变"
	},
	"swordsman_basic_back": {
		"basic_attack_cooldown": "降低普攻间隔，使背身斩触发更频繁；45%不变",
		"basic_attack_damage": "主斩伤害先强化，背身斩读取主斩伤害45%",
		"basic_attack_range": "扩大主斩与背身斩判定；45%不变"
	},
	"swordsman_basic_pursuit": {
		"basic_attack_cooldown": "降低普攻间隔，所有派生斩循环更快",
		"basic_attack_damage": "所有普攻斩继承伤害强化",
		"basic_attack_range": "范围强化与追锋形态相乘"
	},
	"swordsman_basic_opening": {
		"basic_attack_cooldown": "降低普攻间隔，加快第三段连击；减速不变",
		"basic_attack_damage": "先应用普攻伤害强化，再对第三段主斩乘+20%",
		"basic_attack_range": "仅扩大主斩命中范围；不改变第三段+20%与减速"
	},
	"swordsman_basic_sword_wheel": {
		"basic_attack_cooldown": "降低主斩攻击间隔，使第三段左右追加斩更快；每侧35%不变",
		"basic_attack_damage": "第三段主斩与左右剑轮均继承伤害强化；每侧35%固定",
		"basic_attack_range": "扩大主斩与左右追加斩判定；每侧35%不变"
	},
	"swordsman_basic_cooldown_cut": {
		"basic_attack_cooldown": "先降低普攻基础间隔，再对击杀后的剩余冷却执行12%缩短",
		"basic_attack_damage": "提高普攻击杀概率，间接提高截流触发机会；12%不变",
		"basic_attack_range": "仅扩大击杀判定距离，不改变12%冷却缩短"
	},
	"swordsman_blade_storm_retain": {
		"blade_storm_damage": "施放与跟随阶段继承伤害强化，跟随阶段最后乘70%伤害。",
		"blade_storm_area": "施放与跟随阶段继承范围强化。",
		"blade_storm_cooldown": "仅降低风暴冷却，不改变已施放实例持续时间。"
	},
	"swordsman_blade_storm_stationary": {
		"blade_storm_damage": "固定风暴每跳继承伤害强化；命中减速至70%不变。",
		"blade_storm_area": "固定风暴范围继承强化，扩大命中覆盖。",
		"blade_storm_cooldown": "仅降低下一次冷却，不改变固定实例持续时间。"
	},
	"swordsman_blade_storm_rending_spin": {
		"blade_storm_damage": "当前单跳伤害先强化，裂旋外圈再取当前单跳50%。",
		"blade_storm_area": "基础半径先结算范围强化，再对第3跳外圈乘135%。",
		"blade_storm_cooldown": "仅降低冷却，不改变第3跳周期。"
	},
	"swordsman_blade_storm_recall": {
		"blade_storm_damage": "仅强化风暴伤害，不影响拉回。",
		"blade_storm_area": "扩大离开触发边界与落点；落点仍为当前半径70%。",
		"blade_storm_cooldown": "仅降低冷却，不改变位移上限90与0.75秒间隔。"
	},
	"swordsman_blade_storm_after_howl": {
		"blade_storm_damage": "终爆读取强化后的当前单跳伤害90%。",
		"blade_storm_area": "终爆半径读取强化后的当前风暴半径。",
		"blade_storm_cooldown": "仅降低冷却；每个中心仍只爆发一次。"
	},
	"swordsman_blade_storm_returning_gale": {
		"blade_storm_damage": "不影响结束时30%减伤1秒；仅强化风暴伤害。",
		"blade_storm_area": "不影响结束时30%减伤1秒；仅扩大风暴范围。",
		"blade_storm_cooldown": "仅降低冷却；不影响结束时30%减伤1秒，每实例仍只触发一次。"
	},
	"swordsman_crescent_return": {
		"crescent_wave_cooldown": "降低冷却，往返更频繁；返程伤害60%不变。",
		"crescent_wave_damage": "去程伤害先强化，返程读取去程伤害60%。",
		"crescent_wave_speed": "去程与返程继承速度强化，只改变到达时间。"
	},
	"swordsman_crescent_full_moon": {
		"crescent_wave_cooldown": "降低满月冷却；长度280、宽度150、基础速度500不变。",
		"crescent_wave_damage": "满月主月牙继承伤害强化。",
		"crescent_wave_speed": "在满月基础速度500上叠加速度加成。"
	},
	"swordsman_crescent_twin_moons": {
		"crescent_wave_cooldown": "降低冷却，主月牙与额外月牙组更频繁；额外月牙55%不变。",
		"crescent_wave_damage": "主月牙伤害先强化，额外月牙读取主月牙伤害55%。",
		"crescent_wave_speed": "主月牙与额外月牙继承速度；偏转18°不变。"
	},
	"swordsman_crescent_frost_trail": {
		"crescent_wave_cooldown": "降低冷却；减速80%持续0.6秒不变。",
		"crescent_wave_damage": "提高月牙及返程伤害，不改变减速值。",
		"crescent_wave_speed": "往返到达更快；不改变减速80%/0.6秒。"
	},
	"swordsman_crescent_eclipse": {
		"crescent_wave_cooldown": "降低冷却；每道月牙完整结束时仅爆发一次。",
		"crescent_wave_damage": "月牙伤害先强化，终点爆发读取当前月牙伤害70%；月返只在返程结束爆发。",
		"crescent_wave_speed": "仅改变终点爆发到达时机，不改变70%伤害。"
	},
	"swordsman_crescent_afterimage": {
		"crescent_wave_cooldown": "降低冷却，残影施放组更频繁；残影不递归。",
		"crescent_wave_damage": "主月牙伤害强化同步作用残影，残影固定为当前伤害45%。",
		"crescent_wave_speed": "主月牙与残影继承速度；残影射程60%、伤害45%固定。"
	},
	"swordsman_ultimate_king": {
		"ultimate_damage": "所有线斩先继承无敌斩伤害强化，再对Boss目标追加+30%。"
	},
	"swordsman_ultimate_blossom": {
		"ultimate_damage": "线斩伤害强化先结算，剑华读取强化后线斩伤害30%。"
	},
	"swordsman_ultimate_pursuit": {
		"ultimate_damage": "锁定斩与沿线其他目标继承伤害强化；沿线结算70%线斩伤害。"
	},
	"swordsman_ultimate_hold_ground": {
		"ultimate_damage": "不影响余震减速至50%/0.75秒且不造成伤害；线斩伤害照常强化。"
	},
	"swordsman_ultimate_final_judgement": {
		"ultimate_damage": "伤害强化先结算，最后一道基础线斩再乘180%；剑华读取终决后的线斩伤害。"
	},
	"swordsman_ultimate_triumph": {
		"ultimate_damage": "不影响凯旋30%减伤、20%移速、2秒；仅强化线斩伤害。"
	},
	"gunner_trait_clear_hunt": {
		"hunt_safe_radius": "安全圈半径减少继续生效：更容易维持圈外安全距离",
		"hunt_inside_damage": "不影响：圈内伤害不变",
		"hunt_outside_damage": "圈外伤害强化继续生效",
		"flash_stack_bonus": "每层瞬杀伤害、移速、闪避收益继续生效"
	},
	"gunner_trait_invade_hunt": {
		"hunt_safe_radius": "安全圈缩小继续生效：更容易触发侵入猎场",
		"hunt_inside_damage": "圈内伤害增幅叠加：75%形态基础后再吃构筑",
		"hunt_outside_damage": "不影响：圈外伤害不变",
		"flash_stack_bonus": "每层瞬杀收益继续生效"
	},
	"gunner_trait_far_calibration": {
		"hunt_safe_radius": "安全圈缩小改变圈外判定距离；校准易伤仍在命中后施加",
		"hunt_inside_damage": "不影响：圈内伤害强化不变",
		"hunt_outside_damage": "圈外伤害先结算，再施加6%易伤",
		"flash_stack_bonus": "瞬杀层数收益继续生效"
	},
	"gunner_trait_repulse": {
		"hunt_safe_radius": "安全圈缩小改变圈内首次命中判定",
		"hunt_inside_damage": "圈内伤害先结算，制退随后触发",
		"hunt_outside_damage": "不影响：圈外命中不触发制退",
		"flash_stack_bonus": "瞬杀层数收益继续生效"
	},
	"gunner_trait_execution": {
		"hunt_safe_radius": "不影响：只改变安全圈尺寸",
		"hunt_inside_damage": "处决+60%与圈内伤害乘区叠加",
		"hunt_outside_damage": "处决+60%与圈外伤害乘区叠加",
		"flash_stack_bonus": "本次强化提高瞬杀每层常规收益；处决首次真实命中仍只消耗5层，+60%独立锁定"
	},
	"gunner_trait_escape_step": {
		"hunt_safe_radius": "不影响：只改变安全圈尺寸",
		"hunt_inside_damage": "不影响：受伤触发不改圈内伤害",
		"hunt_outside_damage": "不影响：受伤触发不改圈外伤害",
		"flash_stack_bonus": "受伤前每层收益提高；受伤仍清层，滑步固定+35%/1.5秒"
	},
	"gunner_entry_focus": {
		"entry_damage": "登场15发均继承entry_damage"
	},
	"gunner_entry_denial": {
		"entry_damage": "登场24发均继承entry_damage"
	},
	"gunner_entry_piercing": {
		"entry_damage": "伤害先结算；entry_damage只提高每发伤害，不改变穿透数"
	},
	"gunner_entry_repulse": {
		"entry_damage": "伤害先结算，首次命中制退随后触发"
	},
	"gunner_entry_follow_fire": {
		"entry_damage": "本次伤害强化只提高礼炮；续火窗口仅改普攻间隔/穿透，不变"
	},
	"gunner_entry_hot_start": {
		"entry_damage": "本次伤害强化只提高礼炮；热启动仅缩减散弹/无限装填剩余CD，不变"
	},
	"gunner_basic_armor": {
		"basic_attack_damage": "重弹读取强化后普攻伤害，伤害构筑直接放大基础与2倍重弹",
		"basic_attack_cooldown": "攻击间隔作用于第4次节奏",
		"basic_attack_range": "重弹射程继承普攻距离"
	},
	"gunner_basic_burst": {
		"basic_attack_damage": "三发各42%继承强化后伤害",
		"basic_attack_cooldown": "攻击间隔作用于整组三连点射，不变成每发独立CD",
		"basic_attack_range": "三发继承普攻射程"
	},
	"gunner_basic_mark": {
		"basic_attack_damage": "首击先吃普攻伤害，再施加6%易伤",
		"basic_attack_cooldown": "仅提高标记刷新频率",
		"basic_attack_range": "扩大标记命中距离"
	},
	"gunner_basic_penetration": {
		"basic_attack_damage": "伤害完整保留",
		"basic_attack_cooldown": "冷却强化完整作用普攻间隔",
		"basic_attack_range": "射程提高飞行距离；穿透+2与半径不被射程重复放大"
	},
	"gunner_basic_steady_aim": {
		"basic_attack_damage": "静止增伤在普攻伤害构筑后再加18%",
		"basic_attack_cooldown": "冷却降低使稳枪期间攻击频率提高",
		"basic_attack_range": "不影响：稳枪不改射程"
	},
	"gunner_basic_mobile_fire": {
		"basic_attack_damage": "伤害不变；伤害构筑仍完整生效",
		"basic_attack_cooldown": "攻击间隔完整保留",
		"basic_attack_range": "移动时射程构筑后再加70"
	},
	"gunner_shrapnel_mobile": {
		"shrapnel_cooldown": "本次CD构筑只缩基础冷却；机动形态倍率不作用冷却",
		"shrapnel_damage": "每跳伤害构筑先结算，再乘1.5",
		"shrapnel_radius": "半径构筑先结算，再乘1.2"
	},
	"gunner_shrapnel_delayed": {
		"shrapnel_cooldown": "本次CD构筑只缩基础冷却；延迟引爆终爆不改基础CD",
		"shrapnel_damage": "当前每跳伤害继承并乘250%终爆",
		"shrapnel_radius": "扩大覆盖范围，也扩大终爆触发区域"
	},
	"gunner_shrapnel_rend": {
		"shrapnel_cooldown": "本次CD构筑只缩基础冷却；割裂易伤数值固定，CD只影响再次施放频率",
		"shrapnel_damage": "伤害构筑提高施加易伤前首段伤害",
		"shrapnel_radius": "扩大命中覆盖，从而扩大挂易伤范围"
	},
	"gunner_shrapnel_snare": {
		"shrapnel_cooldown": "本次CD构筑只缩基础冷却；陷停离场减速时长固定",
		"shrapnel_damage": "不影响：减速不是伤害",
		"shrapnel_radius": "扩大控制区；离场25%减速仍固定"
	},
	"gunner_shrapnel_quick_throw": {
		"shrapnel_cooldown": "本次CD构筑只缩基础冷却；速抛的0.78冷却倍率另行乘算",
		"shrapnel_damage": "本次伤害构筑仍强化基础场与余烬实际伤害；速抛只改CD/持续",
		"shrapnel_radius": "本次半径构筑仍强化基础场与余烬实际范围；速抛只改CD/持续"
	},
	"gunner_shrapnel_afterfield": {
		"shrapnel_cooldown": "不影响余烬持续/伤害",
		"shrapnel_damage": "余烬每跳继承当前伤害后乘30%",
		"shrapnel_radius": "余烬半径为当前主场60%，随半径构筑同步扩大"
	},
	"gunner_infinite_axis": {
		"infinite_reload_speed": "无限装填期间角色移速继续提高；不改变锁定轴线",
		"infinite_reload_damage": "每跳伤害构筑后再乘1.55",
		"infinite_reload_range": "长度构筑后再乘1.25",
		"infinite_reload_cooldown": "基础CD构筑完整生效"
	},
	"gunner_infinite_dual": {
		"infinite_reload_speed": "无限装填期间角色移速继续提高；不改变双轨数量或60%倍率",
		"infinite_reload_damage": "两条各60%并继承伤害构筑",
		"infinite_reload_range": "两条均继承长度构筑",
		"infinite_reload_cooldown": "基础CD完整生效"
	},
	"gunner_infinite_sweep": {
		"infinite_reload_speed": "无限装填期间角色移速继续提高；不改变光束扫动周期",
		"infinite_reload_damage": "伤害完整保留",
		"infinite_reload_range": "长度完整保留",
		"infinite_reload_cooldown": "不影响扫动周期"
	},
	"gunner_infinite_sear": {
		"infinite_reload_speed": "无限装填期间角色移速继续提高；不改变易伤6%或0.45秒",
		"infinite_reload_damage": "首跳先吃伤害构筑，再施加6%易伤",
		"infinite_reload_range": "扩大挂印距离",
		"infinite_reload_cooldown": "不改变易伤0.45秒；仅提高施放频率"
	},
	"gunner_infinite_overload": {
		"infinite_reload_speed": "无限装填期间角色移速继续提高；不改变终端光束600%或长度1.15倍率",
		"infinite_reload_damage": "终端伤害继承每跳伤害构筑后乘600%",
		"infinite_reload_range": "终端长度继承构筑后再乘1.15",
		"infinite_reload_cooldown": "不影响终端倍率，仅影响再施放"
	},
	"gunner_infinite_recycle": {
		"infinite_reload_speed": "无限装填期间角色移速继续提高；不改变命中返还15%或3秒上限",
		"infinite_reload_damage": "不影响返还比例",
		"infinite_reload_range": "不影响返还条件",
		"infinite_reload_cooldown": "初始CD先按构筑计算，命中后剩余CD再减15%（最多3秒）"
	},
	"gunner_ultimate_line": {
		"ultimate_wave_count": "新增波次继续使用线列形态并继承1.55倍"
	},
	"gunner_ultimate_fan": {
		"ultimate_wave_count": "新增波次继续广域形态并继承0.70倍"
	},
	"gunner_ultimate_calibration": {
		"ultimate_wave_count": "波次+2增加校射状态下可获得+18%伤害的波次数"
	},
	"gunner_ultimate_sweep_suppression": {
		"ultimate_wave_count": "波次+2增加最多2次首次命中击退机会"
	},
	"gunner_ultimate_terminal_guidance": {
		"ultimate_wave_count": "波次+2增加第4波计数，可能增加终端制导触发机会"
	},
	"gunner_ultimate_delayed_fire": {
		"ultimate_wave_count": "波次构筑作用全部正常波；延长段仍按70%正常波伤害"
	},
	"mage_trait_relay": {
		"arcane_charge_chance": "本节点固定不改变获取概率；接力新增转移保留每次获得的层数",
		"arcane_charge_energy": "接力后的每层回能效率继续生效",
		"arcane_charge_share": "接力后的每层同步比例继续生效"
	},
	"mage_trait_ultimate": {
		"arcane_charge_chance": "本节点固定不改变获取概率；终式仍按实际持有层数消费",
		"arcane_charge_energy": "提高每层回能效率，终式消费前继续生效",
		"arcane_charge_share": "提高每层同步比例，终式消费前继续生效"
	},
	"mage_trait_flow": {
		"arcane_charge_chance": "本节点固定延长值；更快获得的层数仍按层计时",
		"arcane_charge_energy": "每层回能继续生效；延流只延长充能有效期",
		"arcane_charge_share": "延长有效期，本节点固定不改变每层同步比例"
	},
	"mage_trait_overflow": {
		"arcane_charge_chance": "本节点固定不改变自然结束条件；更快获取本节点固定不改变额外层数",
		"arcane_charge_energy": "盈余结束获得的额外层数按当前回能效率生效",
		"arcane_charge_share": "盈余结束获得的额外层数按当前同步比例生效"
	},
	"mage_trait_relay_chain": {
		"arcane_charge_chance": "本节点固定不改变接力次数；获得的层数继续按概率规则产生",
		"arcane_charge_energy": "跨非术师接力保留层数，每层回能效率继续生效",
		"arcane_charge_share": "跨非术师接力保留层数，每层同步比例继续生效"
	},
	"mage_trait_dawn": {
		"arcane_charge_chance": "更快达到8层启明门槛；本节点固定不改变启明额外2秒",
		"arcane_charge_energy": "本节点固定不改变启明额外2秒；回能效率作用于启明前后持有层数",
		"arcane_charge_share": "本节点固定不改变启明额外2秒；同步比例作用于记录前的转移"
	},
	"mage_entry_center": {
		"arcane_surplus_duration": "奥法盈余持续时间再加该普通升级秒数；中心雷150%比例固定"
	},
	"mage_entry_mark": {
		"arcane_surplus_duration": "奥法盈余持续时间增加；点名数量与补回雷数不变"
	},
	"mage_entry_static": {
		"arcane_surplus_duration": "奥法盈余持续时间增加；减速20%与1.25秒固定"
	},
	"mage_entry_echo": {
		"arcane_surplus_duration": "奥法盈余持续时间增加；追加雷读取当前登场单雷伤害，35%与两道固定"
	},
	"mage_entry_canopy": {
		"arcane_surplus_duration": "奥法盈余持续时间增加；电场1.5秒、30%单雷伤害与每敌一次固定"
	},
	"mage_entry_surge": {
		"arcane_surplus_duration": "奥法盈余持续时间增加；新增2层充能仍按每层普通回能/同步规则"
	},
	"mage_basic_aftershock": {
		"basic_attack_damage": "主爆与余震共同继承普攻伤害倍率；余震45%比例固定",
		"basic_attack_range": "主爆与余震共同继承普攻范围；余震范围随主爆范围继承"
	},
	"mage_basic_triangle": {
		"basic_attack_damage": "三角三点共同继承普攻伤害；每点40%比例固定",
		"basic_attack_range": "三角三点共同继承普攻范围；每点70%范围比例固定"
	},
	"mage_basic_quickcast": {
		"basic_attack_damage": "速决固定只缩短预警25%；本次伤害构筑仍强化爆炸伤害",
		"basic_attack_range": "本次范围构筑仍作用更快落下的爆炸；速决固定不改变范围"
	},
	"mage_basic_frostburst": {
		"basic_attack_damage": "余震/三角伤害随普攻伤害强化；减速20%与0.8秒固定",
		"basic_attack_range": "余震/三角范围随普攻范围强化；减速不变"
	},
	"mage_basic_gravemark": {
		"basic_attack_damage": "牵引不随伤害增长；爆炸伤害继承普攻伤害",
		"basic_attack_range": "范围强化扩大牵引判定半径"
	},
	"mage_basic_rift": {
		"basic_attack_damage": "主爆精英/Boss触发的小爆炸继承普攻伤害；25%比例固定",
		"basic_attack_range": "主爆范围随普攻范围强化；小爆炸范围不因范围升级额外放大"
	},
	"mage_meta_transfer": {
		"meta_field_slow": "先按普通减速结算，再乘转移减速×0.50",
		"meta_field_radius": "先扩大领域范围，再乘跟随范围×0.75",
		"meta_field_damage": "先结算领域伤害，再乘跟随伤害×0.50"
	},
	"mage_meta_collapse": {
		"meta_field_slow": "坍缩爆发读取当前减速构筑；减速为控制效果，不改变本节点爆发伤害",
		"meta_field_radius": "坍缩范围继承当前领域范围",
		"meta_field_damage": "坍缩读取当前每跳伤害并乘2倍；普通伤害升级先结算"
	},
	"mage_meta_expansion": {
		"meta_field_slow": "扩张不提高减速；减速按每跳普通值结算",
		"meta_field_radius": "范围升级决定初始半径，之后每跳再扩张12%最多3次",
		"meta_field_damage": "扩张不提高伤害；每跳伤害继承普通伤害升级"
	},
	"mage_meta_stasis": {
		"meta_field_slow": "减速普通强化与凝滞+12个百分点相加，最高95%；转移后再×0.50",
		"meta_field_radius": "本节点固定不改变范围；本次范围构筑仍作用领域，凝滞只强化减速",
		"meta_field_damage": "本节点固定不改变伤害；本次伤害构筑仍作用领域每跳"
	},
	"mage_meta_inner_ring": {
		"meta_field_slow": "本节点固定不改变拉回距离；本次减速构筑仍作用领域",
		"meta_field_radius": "范围升级同步扩大领域与内环（内环=当前领域60%）",
		"meta_field_damage": "内环不造成独立伤害；本次伤害构筑强化领域每跳，拉回距离固定"
	},
	"mage_meta_guard_pulse": {
		"meta_field_slow": "回复4%为本节点固定值；本次减速构筑仍作用领域",
		"meta_field_radius": "回复4%固定值不随范围增长；本次范围构筑仍扩大领域覆盖",
		"meta_field_damage": "回复4%固定值不随伤害增长；本次伤害构筑仍强化领域每跳"
	},
	"mage_surge_four": {
		"surging_wave_cooldown": "冷却强化作用整次四向施放；四道波共享一次冷却",
		"surging_wave_damage": "伤害强化先结算，再乘每道55%",
		"surging_wave_duration": "持续强化先结算，再乘每道生命周期×0.75",
		"surging_wave_speed": "速度强化作用四道波；本节点固定不改变生命周期×0.75"
	},
	"mage_surge_back": {
		"surging_wave_cooldown": "冷却强化作用正向波与0.8秒后的反向追加，共享施放冷却",
		"surging_wave_damage": "正反两波继承伤害强化；反向波70%比例固定",
		"surging_wave_duration": "正反两波继承持续强化；反向波生命周期×0.75固定",
		"surging_wave_speed": "正反两波继承速度强化；0.8秒追加延迟固定"
	},
	"mage_surge_vortex": {
		"surging_wave_cooldown": "冷却强化照常作用；涡流不改冷却",
		"surging_wave_damage": "伤害强化照常作用；减速20%与1秒固定",
		"surging_wave_duration": "持续强化延长控线覆盖；减速持续1秒固定",
		"surging_wave_speed": "速度先加普通强化，再乘涡流×0.85"
	},
	"mage_surge_rapid": {
		"surging_wave_cooldown": "冷却强化照常作用；疾潮不改冷却",
		"surging_wave_damage": "速度波命中精英/Boss的额外15%继承伤害强化；每波每目标一次",
		"surging_wave_duration": "生命周期先按普通强化，再乘×0.85；额外伤害不变",
		"surging_wave_speed": "速度先加普通强化，再乘疾潮×1.30"
	},
	"mage_surge_heavy": {
		"surging_wave_cooldown": "冷却强化照常作用；重潮不改冷却",
		"surging_wave_damage": "伤害先按普通强化，再于末0.4秒乘重潮×1.20",
		"surging_wave_duration": "持续强化决定重潮开始前后的时间窗；重潮仍末0.4秒",
		"surging_wave_speed": "速度先按普通强化，再于重潮阶段乘×0.80"
	},
	"mage_surge_wake": {
		"surging_wave_cooldown": "冷却强化照常作用；潮痕不改冷却",
		"surging_wave_damage": "潮痕伤害继承当前波伤害后乘20%；比例固定",
		"surging_wave_duration": "不延长潮痕1.2秒；只延长基础波经过覆盖",
		"surging_wave_speed": "速度只改变波经过时间；潮痕持续1.2秒固定"
	},
	"mage_ultimate_lock": {
		"ultimate_bombard_count": "新增轰炸次数继续锁定同一目标；范围70%、伤害×1.25固定"
	},
	"mage_ultimate_triangle": {
		"ultimate_bombard_count": "新增轰炸次数继续在三个节点轮转；范围80%固定"
	},
	"mage_ultimate_eclipse": {
		"ultimate_bombard_count": "新增次数增加递增段数，但星蚀总增幅仍封顶20%"
	},
	"mage_ultimate_afterglow": {
		"ultimate_bombard_count": "新增次数只推迟最后一击；余晖终击仍仅一次"
	},
	"mage_ultimate_canopy": {
		"ultimate_bombard_count": "新增次数增加覆盖次数；每脉冲范围+15%、伤害-8%固定"
	},
	"mage_ultimate_scorch": {
		"ultimate_bombard_count": "新增次数增加轰炸次数，不增加焦土数量；焦土仍2秒每0.5秒一次"
	}
}

const EVOLVED_BUILD_TEXT_OVERRIDES := {
	"swordsman_trait_blood_battle:knight_glory_duration": {
		"title": "骑士荣耀与血战昂扬持续时间均增加0.2s"
	},
	"swordsman_trait_last_guard:trait_heal_bonus": {
		"title": "战意治疗增强，换防救回生命+1%"
	},
	"swordsman_trait_last_guard:knight_glory_duration": {
		"title": "骑士荣耀与换防后无敌均增加0.2s"
	}
}
