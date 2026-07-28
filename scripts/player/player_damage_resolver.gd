extends RefCounted

const PERFORMANCE_COUNTERS := preload("res://scripts/game/performance_counters.gd")
const PLAYER_DAMAGE_JOB_QUEUE := preload("res://scripts/player/player_damage_job_queue.gd")
const PLAYER_DAMAGE_BATCHER := preload("res://scripts/player/player_damage_batcher.gd")
const PLAYER_DAMAGE_SHAPE_FLOW := preload("res://scripts/player/player_damage_shape_flow.gd")
const PERFORMANCE_GUARD := preload("res://scripts/game/performance_guard.gd")
const ENEMY_SPATIAL_GRID := preload("res://scripts/enemies/enemy_spatial_grid.gd")

const DAMAGE_JOB_QUEUE_NAME := "PlayerDamageJobQueue"
const QUEUED_HIT_THRESHOLD := 16
const LOW_FPS_QUEUED_HIT_THRESHOLD := 8
const CRITICAL_FPS_QUEUED_HIT_THRESHOLD := 4
const DAMAGE_QUERY_BOUNDS_GROW := 260.0
const ENEMY_TOUCH_DAMAGE_RADIUS_SCALE := 0.78
const BOSS_TOUCH_DAMAGE_SHADOW_RADIUS_SCALE := 1.048808848
const BOSS_TOUCH_DAMAGE_CURRENT_SIZE_SCALE := 0.8
const BOSS_PLAYER_HIT_SHAPE_SCALE := 1.2
const BOSS_TOUCH_DAMAGE_QUERY_PADDING := 260.0
const GUNNER_NO_HUNT_SOURCE_ROLE_ID := "gunner_no_hunt"

static var cached_live_enemies: Array = []
static var cached_live_enemies_frame: int = -1
static var cached_live_enemies_source_key: int = -1
static var cached_enemy_grid: Dictionary = {}
static var cached_enemy_grid_frame: int = -1
static var cached_enemy_grid_source_key: int = -1
static var cached_enemy_grid_cell_size: float = 96.0
static var reusable_damage_batcher: RefCounted
static var reusable_candidates: Array = []
static var reusable_seen_enemy_ids: Dictionary = {}
static var reusable_bounds_list: Array[Rect2] = []

static func deal_damage_to_enemy(owner, enemy: Node, damage_amount: float, source_role_id: String, vulnerability_bonus: float = 0.0, vulnerability_duration: float = 2.0, slow_multiplier: float = 1.0, slow_duration: float = 0.0, source_position: Variant = null, suppress_status_visual: bool = false, kill_energy_bonus: float = 0.0) -> bool:
	if not _is_live_enemy(enemy):
		return false
	var final_damage := damage_amount
	var resolved_source_role_id: String = _resolve_damage_source_role_id(source_role_id)
	var was_critical := false
	if owner != null and resolved_source_role_id != "" and owner.has_method("_roll_critical_hit") and owner.has_method("_get_critical_damage_multiplier"):
		was_critical = bool(owner._roll_critical_hit(resolved_source_role_id))
		if was_critical:
			final_damage *= float(owner._get_critical_damage_multiplier(resolved_source_role_id))
	if owner != null and _should_apply_gunner_hunt_multiplier(source_role_id, resolved_source_role_id) and enemy is Node2D:
		var attack_origin: Vector2 = _get_gunner_damage_origin(owner, enemy as Node2D)
		if owner.has_method("_get_gunner_distance_damage_multiplier"):
			final_damage *= float(owner._get_gunner_distance_damage_multiplier(attack_origin.distance_to((enemy as Node2D).global_position)))
	var killed := false
	if damage_amount > 0.0 and enemy.has_method("take_damage"):
		killed = _call_enemy_take_damage(enemy, final_damage, was_critical)
		if owner != null and owner.has_method("_record_attack_result_instance"):
			owner._record_attack_result_instance(resolved_source_role_id, was_critical, killed)
		if owner != null and owner.has_method("_add_switch_energy_from_damage"):
			owner._add_switch_energy_from_damage(final_damage, resolved_source_role_id)
		if owner != null and owner.has_method("_apply_role_damage_lifesteal"):
			owner._apply_role_damage_lifesteal(resolved_source_role_id, final_damage)
		if owner != null and enemy.get("enemy_kind") != null and str(enemy.get("enemy_kind")) in ["boss", "small_boss"] and owner.has_method("_add_boss_damage_energy") and owner.has_method("_get_boss_damage_energy"):
			owner._add_boss_damage_energy(owner._get_boss_damage_energy(final_damage))
		if killed and owner != null and owner.has_method("_add_kill_energy") and owner.has_method("_get_kill_energy_from_enemy"):
			var kill_energy: float = owner._get_kill_energy_from_enemy(enemy)
			var bypass_lock_role_id: String = resolved_source_role_id if resolved_source_role_id == "mage" and kill_energy_bonus > 0.0 else ""
			owner._add_kill_energy(kill_energy, bypass_lock_role_id, resolved_source_role_id)
			if owner.has_method("_try_apply_mage_kill_energy_proc"):
				owner._try_apply_mage_kill_energy_proc(resolved_source_role_id, kill_energy, bypass_lock_role_id)
			if kill_energy_bonus > 0.0:
				var bonus_energy: float = kill_energy * kill_energy_bonus
				owner._add_kill_energy(bonus_energy, bypass_lock_role_id, resolved_source_role_id)
				if owner.has_method("_try_apply_mage_kill_energy_proc"):
					owner._try_apply_mage_kill_energy_proc(resolved_source_role_id, bonus_energy, bypass_lock_role_id)
	if vulnerability_bonus > 0.0 and enemy.has_method("apply_vulnerability"):
		enemy.apply_vulnerability(vulnerability_bonus, vulnerability_duration)
	if slow_duration > 0.0:
		if suppress_status_visual and enemy.has_method("apply_slow_silent"):
			enemy.apply_slow_silent(slow_multiplier, slow_duration)
		elif enemy.has_method("apply_slow"):
			enemy.apply_slow(slow_multiplier, slow_duration)
	return killed

static func _call_enemy_take_damage(enemy: Node, amount: float, is_critical: bool) -> bool:
	if enemy == null or not is_instance_valid(enemy) or not enemy.has_method("take_damage"):
		return false
	if _method_accepts_argument_count(enemy, "take_damage", 2):
		return bool(enemy.take_damage(amount, is_critical))
	return bool(enemy.take_damage(amount))

static func _method_accepts_argument_count(target: Object, method_name: String, argument_count: int) -> bool:
	for method in target.get_method_list():
		if method is not Dictionary:
			continue
		var method_data: Dictionary = method
		if str(method_data.get("name", "")) != method_name:
			continue
		var args: Array = method_data.get("args", [])
		var default_args: Array = method_data.get("default_args", [])
		var max_args: int = args.size()
		var min_args: int = max(0, max_args - default_args.size())
		return argument_count >= min_args and argument_count <= max_args
	return false

static func queue_damage_to_enemy(owner, enemy: Node, damage_amount: float, source_role_id: String, vulnerability_bonus: float = 0.0, vulnerability_duration: float = 2.0, slow_multiplier: float = 1.0, slow_duration: float = 0.0, source_position: Variant = null, prefer_silent_feedback: bool = false, suppress_status_visual: bool = false) -> void:
	var queue := _get_or_create_damage_job_queue(owner)
	if queue == null:
		deal_damage_to_enemy(owner, enemy, damage_amount, source_role_id, vulnerability_bonus, vulnerability_duration, slow_multiplier, slow_duration, source_position, suppress_status_visual)
		return
	queue.enqueue_values(weakref(enemy), enemy.get_instance_id(), damage_amount, 1, source_role_id, vulnerability_bonus, vulnerability_duration, slow_multiplier, slow_duration, source_position, 0.0, prefer_silent_feedback, suppress_status_visual)

static func apply_or_queue_damage_job(owner, job: Dictionary) -> void:
	var enemy_ref: WeakRef = job.get("enemy_ref", null) as WeakRef
	if enemy_ref == null:
		return
	apply_or_queue_damage_values(
		owner,
		enemy_ref,
		int(job.get("enemy_id", 0)),
		float(job.get("damage_amount", 0.0)),
		int(job.get("hit_count", 1)),
		str(job.get("source_role_id", "")),
		float(job.get("vulnerability_bonus", 0.0)),
		float(job.get("vulnerability_duration", 2.0)),
		float(job.get("slow_multiplier", 1.0)),
		float(job.get("slow_duration", 0.0)),
		job.get("source_position", null),
		float(job.get("kill_energy_bonus", 0.0)),
		bool(job.get("prefer_silent_feedback", false)),
		bool(job.get("suppress_status_visual", false))
	)

static func apply_or_queue_damage_values(owner, enemy_ref: WeakRef, enemy_id: int, damage_amount: float, hit_count: int, source_role_id: String, vulnerability_bonus: float = 0.0, vulnerability_duration: float = 2.0, slow_multiplier: float = 1.0, slow_duration: float = 0.0, source_position: Variant = null, kill_energy_bonus: float = 0.0, prefer_silent_feedback: bool = false, suppress_status_visual: bool = false) -> void:
	if enemy_ref == null:
		return
	var enemy: Node = enemy_ref.get_ref() as Node
	if enemy == null or not is_instance_valid(enemy):
		return
	var queue := _get_or_create_damage_job_queue(owner)
	if queue == null:
		deal_damage_to_enemy(
			owner,
			enemy,
			damage_amount,
			source_role_id,
			vulnerability_bonus,
			vulnerability_duration,
			slow_multiplier,
			slow_duration,
			source_position,
			suppress_status_visual,
			kill_energy_bonus
		)
		return
	queue.enqueue_values(enemy_ref, enemy_id, damage_amount, hit_count, source_role_id, vulnerability_bonus, vulnerability_duration, slow_multiplier, slow_duration, source_position, kill_energy_bonus, prefer_silent_feedback, suppress_status_visual)

static func damage_enemies_in_radius(owner, center: Vector2, radius: float, damage_amount: float, vulnerability_bonus: float, slow_multiplier: float, slow_duration: float, source_role_id: String = "") -> int:
	return damage_enemies_in_radius_with_kill_energy(owner, center, radius, damage_amount, vulnerability_bonus, slow_multiplier, slow_duration, source_role_id, 0.0)

static func damage_enemies_in_radius_with_kill_energy(owner, center: Vector2, radius: float, damage_amount: float, vulnerability_bonus: float, slow_multiplier: float, slow_duration: float, source_role_id: String = "", kill_energy_bonus: float = 0.0) -> int:
	var resolved_role_id: String = _resolve_role_id(owner, source_role_id)
	var candidates: Array = _get_candidate_enemies_for_circle(owner, center, radius)
	_record_damage_query(candidates.size())
	var batcher := _get_reusable_damage_batcher(owner)
	for enemy in candidates:
		if not _is_live_enemy(enemy) or enemy is not Node2D:
			continue
		if _enemy_hit_shape_hits_circle(owner, enemy as Node2D, center, radius):
			batcher.add_enemy(enemy, damage_amount, resolved_role_id, vulnerability_bonus, 2.0, slow_multiplier, slow_duration, center, kill_energy_bonus)
	var hit_count: int = batcher.hit_count
	PERFORMANCE_COUNTERS.add("damage_hits", hit_count)
	return batcher.flush()

static func damage_enemies_in_radius_batched(owner, center: Vector2, radius: float, damage_amount: float, vulnerability_bonus: float, slow_multiplier: float, slow_duration: float, source_role_id: String = "") -> int:
	return damage_enemies_in_radius(owner, center, radius, damage_amount, vulnerability_bonus, slow_multiplier, slow_duration, source_role_id)

static func damage_enemies_in_radius_suppressing_status_visuals(owner, center: Vector2, radius: float, damage_amount: float, vulnerability_bonus: float, slow_multiplier: float, slow_duration: float, source_role_id: String = "") -> int:
	var resolved_role_id: String = _resolve_role_id(owner, source_role_id)
	var candidates: Array = _get_candidate_enemies_for_circle(owner, center, radius)
	_record_damage_query(candidates.size())
	var batcher := _get_reusable_damage_batcher(owner)
	for enemy in candidates:
		if not _is_live_enemy(enemy) or enemy is not Node2D:
			continue
		if _enemy_hit_shape_hits_circle(owner, enemy as Node2D, center, radius):
			batcher.add_enemy(enemy, damage_amount, resolved_role_id, vulnerability_bonus, 2.0, slow_multiplier, slow_duration, center, 0.0, true)
	var hit_count: int = batcher.hit_count
	PERFORMANCE_COUNTERS.add("damage_hits", hit_count)
	return batcher.flush()

static func damage_enemies_in_multiple_radii_batched(owner, centers: Array[Vector2], radius: float, damage_amount: float, vulnerability_bonus: float, slow_multiplier: float, slow_duration: float, source_role_id: String = "") -> int:
	if centers.is_empty():
		return 0
	if centers.size() == 1:
		return damage_enemies_in_radius_batched(owner, centers[0], radius, damage_amount, vulnerability_bonus, slow_multiplier, slow_duration, source_role_id)
	var resolved_role_id: String = _resolve_role_id(owner, source_role_id)
	var batcher := _get_reusable_damage_batcher(owner)
	var candidates: Array = _get_candidate_enemies_for_multiple_circles(owner, centers, radius)
	var total_candidates := candidates.size()
	for enemy in candidates:
		if not _is_live_enemy(enemy) or enemy is not Node2D:
			continue
		for center_index in range(centers.size()):
			if _enemy_hit_shape_hits_circle(owner, enemy as Node2D, centers[center_index], radius):
				batcher.add_enemy(enemy, damage_amount, resolved_role_id, vulnerability_bonus, 2.0, slow_multiplier, slow_duration, centers[center_index])
	_record_damage_query(total_candidates)
	PERFORMANCE_COUNTERS.add("damage_hits", batcher.hit_count)
	return batcher.flush()

static func damage_enemies_in_shapes_batched(owner, shapes: Array[Dictionary]) -> int:
	if shapes.is_empty():
		return 0
	var batcher := _get_reusable_damage_batcher(owner)
	var candidates: Array = _get_candidate_enemies_for_shapes(owner, shapes)
	var total_candidates := candidates.size()
	for enemy in candidates:
		if not _is_live_enemy(enemy) or enemy is not Node2D:
			continue
		var enemy_id: int = enemy.get_instance_id()
		for shape in shapes:
			var hit_registry: Dictionary = shape.get("hit_registry", {})
			if not hit_registry.is_empty() and hit_registry.has(enemy_id):
				continue
			if not _shape_hits_enemy_node(owner, shape, enemy as Node2D):
				continue
			if shape.has("hit_registry"):
				hit_registry[enemy_id] = true
			batcher.add_enemy(
				enemy,
				float(shape.get("damage_amount", 0.0)),
				_resolve_role_id(owner, str(shape.get("source_role_id", ""))),
				float(shape.get("vulnerability_bonus", 0.0)),
				float(shape.get("vulnerability_duration", 2.0)),
				float(shape.get("slow_multiplier", 1.0)),
				float(shape.get("slow_duration", 0.0)),
				shape.get("source_position", null),
				float(shape.get("kill_energy_bonus", 0.0))
			)
	_record_damage_query(total_candidates)
	PERFORMANCE_COUNTERS.add("damage_hits", batcher.hit_count)
	return batcher.flush()

static func damage_enemies_in_radius_count_kills(owner, center: Vector2, radius: float, damage_amount: float, vulnerability_bonus: float, slow_multiplier: float, slow_duration: float, source_role_id: String = "") -> Dictionary:
	var hit_count := 0
	var kill_count := 0
	var resolved_role_id: String = _resolve_role_id(owner, source_role_id)
	var candidates: Array = _get_candidate_enemies_for_circle(owner, center, radius)
	_record_damage_query(candidates.size())
	var matched_enemies: Array = []
	for enemy in candidates:
		if not _is_live_enemy(enemy):
			continue
		if enemy is Node2D and _enemy_hit_shape_hits_circle(owner, enemy as Node2D, center, radius):
			matched_enemies.append(enemy)
	hit_count = matched_enemies.size()
	if _should_queue_hits(hit_count):
		for enemy in matched_enemies:
			queue_damage_to_enemy(owner, enemy, damage_amount, resolved_role_id, vulnerability_bonus, 2.0, slow_multiplier, slow_duration, center)
	else:
		for enemy in matched_enemies:
			if deal_damage_to_enemy(owner, enemy, damage_amount, resolved_role_id, vulnerability_bonus, 2.0, slow_multiplier, slow_duration, center):
				kill_count += 1
	PERFORMANCE_COUNTERS.add("damage_hits", hit_count)
	return {"hits": hit_count, "kills": kill_count}

static func pull_enemies_toward(owner, center: Vector2, radius: float, pull_strength: float) -> void:
	for enemy in _get_candidate_enemies_for_circle(owner, center, radius):
		var offset: Vector2 = center - enemy.global_position
		var distance := offset.length()
		if distance > 0.001 and distance <= radius:
			enemy.global_position += offset.normalized() * min(pull_strength, distance)

static func count_enemies_in_radius(owner, center: Vector2, radius: float) -> int:
	var count := 0
	var radius_squared := radius * radius
	for enemy in _get_candidate_enemies_for_circle(owner, center, radius):
		if not _is_live_enemy(enemy):
			continue
		if center.distance_squared_to(enemy.global_position) <= radius_squared:
			count += 1
	return count

static func get_touching_enemy_damage(owner, center: Vector2, radius: float, query_padding: float = 36.0) -> float:
	var candidates: Array = _get_candidate_enemies_for_circle(owner, center, radius + max(query_padding, BOSS_TOUCH_DAMAGE_QUERY_PADDING))
	for enemy in candidates:
		if not _is_live_enemy(enemy) or enemy is not Node2D:
			continue
		var contact_radius: float = 36.0
		var touch_damage: float = 10.0
		var enemy_contact_radius: Variant = enemy.get("contact_radius")
		var enemy_touch_damage: Variant = enemy.get("touch_damage")
		if enemy_contact_radius != null:
			contact_radius = float(enemy_contact_radius)
		if enemy_touch_damage != null:
			touch_damage = float(enemy_touch_damage)
		if _uses_shadow_touch_damage_shape(enemy):
			var touch_shape: Dictionary = get_enemy_touch_damage_shape(enemy)
			if touch_shape.is_empty():
				touch_shape = _get_fallback_touch_damage_shape(enemy as Node2D, contact_radius)
			if _is_center_inside_enemy_touch_shape(center, radius, touch_shape):
				return touch_damage
			continue
		contact_radius *= ENEMY_TOUCH_DAMAGE_RADIUS_SCALE
		var combined_radius: float = contact_radius + radius
		if center.distance_squared_to((enemy as Node2D).global_position) <= combined_radius * combined_radius:
			return touch_damage
	return 0.0

static func _uses_shadow_touch_damage_shape(enemy: Node) -> bool:
	if enemy == null:
		return false
	var kind: String = str(enemy.get("enemy_kind"))
	return kind == "small_boss" or kind == "boss"

static func get_enemy_touch_damage_shape(enemy: Node2D) -> Dictionary:
	if enemy == null or not is_instance_valid(enemy) or not _uses_shadow_touch_damage_shape(enemy):
		return {}
	if str(enemy.get("archetype_id")) == "smallboss_glutton":
		var active_glutton_shape: Dictionary = {}
		if enemy.has_method("get_glutton_player_touch_shape"):
			active_glutton_shape = enemy.call("get_glutton_player_touch_shape")
		if not active_glutton_shape.is_empty():
			return active_glutton_shape
		if enemy.has_method("get_glutton_passive_player_touch_shape"):
			var passive_glutton_shape: Dictionary = enemy.call("get_glutton_passive_player_touch_shape")
			if not passive_glutton_shape.is_empty():
				return passive_glutton_shape
	var visual: Node = enemy.get_node_or_null("ProfileVisual")
	if visual == null:
		visual = enemy.get_node_or_null("BossVisual")
	if visual != null and visual.has_method("get_shadow_world_ellipse"):
		var ellipse: Variant = visual.call("get_shadow_world_ellipse")
		if ellipse is Dictionary and not (ellipse as Dictionary).is_empty():
			var scale: float = BOSS_TOUCH_DAMAGE_SHADOW_RADIUS_SCALE * BOSS_TOUCH_DAMAGE_CURRENT_SIZE_SCALE * _get_enemy_touch_damage_shape_multiplier(enemy)
			return _scale_touch_damage_shape(ellipse as Dictionary, scale)
	return {}

static func get_enemy_player_hit_shape(enemy: Node2D) -> Dictionary:
	var touch_shape: Dictionary = get_enemy_touch_damage_shape(enemy)
	if touch_shape.is_empty():
		return {}
	return _scale_touch_damage_shape(touch_shape, BOSS_PLAYER_HIT_SHAPE_SCALE)

static func _get_fallback_touch_damage_shape(enemy: Node2D, contact_radius: float) -> Dictionary:
	var radius: float = max(1.0, contact_radius) * BOSS_TOUCH_DAMAGE_CURRENT_SIZE_SCALE
	return {
		"center": enemy.global_position,
		"horizontal_radius": radius,
		"vertical_radius": radius
	}

static func _scale_touch_damage_shape(shape: Dictionary, radius_scale: float) -> Dictionary:
	return {
		"center": shape.get("center", Vector2.ZERO),
		"horizontal_radius": float(shape.get("horizontal_radius", 0.0)) * radius_scale,
		"vertical_radius": float(shape.get("vertical_radius", 0.0)) * radius_scale
	}

static func _get_enemy_touch_damage_shape_multiplier(enemy: Node) -> float:
	match str(enemy.get("archetype_id")):
		"smallboss_glutton":
			return 0.5
		"smallboss_rebirth":
			return 0.6
		"boss_spellcore":
			return 0.5
	return 1.0

static func collect_enemies_in_radius(owner, center: Vector2, radius: float) -> Array:
	var matched_enemies: Array = []
	var candidates: Array = _get_candidate_enemies_for_circle(owner, center, radius)
	_record_damage_query(candidates.size())
	for enemy in candidates:
		if not _is_live_enemy(enemy):
			continue
		if enemy is Node2D and _enemy_hit_shape_hits_circle(owner, enemy as Node2D, center, radius):
			matched_enemies.append(enemy)
	PERFORMANCE_COUNTERS.add("damage_hits", matched_enemies.size())
	return matched_enemies

static func damage_enemies_in_line(owner, start_position: Vector2, end_position: Vector2, width: float, damage_amount: float, vulnerability_bonus: float, slow_multiplier: float, slow_duration: float, source_role_id: String = "") -> int:
	var axis := end_position - start_position
	var length := axis.length()
	if length <= 0.001:
		return damage_enemies_in_radius(owner, start_position, width, damage_amount, vulnerability_bonus, slow_multiplier, slow_duration, source_role_id)
	var direction := axis / length
	var resolved_role_id: String = _resolve_role_id(owner, source_role_id)
	var candidates: Array = _get_candidate_enemies_for_rect(owner, start_position + axis * 0.5, abs(axis.x) + width * 2.0, abs(axis.y) + width * 2.0)
	_record_damage_query(candidates.size())
	var batcher := _get_reusable_damage_batcher(owner)
	for enemy in candidates:
		if not _is_live_enemy(enemy):
			continue
		if enemy is Node2D and _enemy_hit_shape_hits_line(owner, enemy as Node2D, start_position, end_position, width):
			batcher.add_enemy(enemy, damage_amount, resolved_role_id, vulnerability_bonus, 2.0, slow_multiplier, slow_duration, start_position)
	var hit_count: int = batcher.hit_count
	PERFORMANCE_COUNTERS.add("damage_hits", hit_count)
	return batcher.flush()

static func damage_enemies_in_oriented_rect(owner, center: Vector2, axis_direction: Vector2, rect_length: float, rect_width: float, damage_amount: float, vulnerability_bonus: float, slow_multiplier: float, slow_duration: float, source_role_id: String = "") -> int:
	return damage_enemies_in_oriented_rect_unique(owner, center, axis_direction, rect_length, rect_width, damage_amount, vulnerability_bonus, slow_multiplier, slow_duration, {}, source_role_id)

static func damage_enemies_in_oriented_rect_unique(owner, center: Vector2, axis_direction: Vector2, rect_length: float, rect_width: float, damage_amount: float, vulnerability_bonus: float, slow_multiplier: float, slow_duration: float, hit_registry: Dictionary, source_role_id: String = "") -> int:
	var direction := axis_direction.normalized()
	if direction.length_squared() <= 0.001:
		direction = Vector2.RIGHT
	var perpendicular := direction.orthogonal()
	var half_length := rect_length * 0.5
	var half_width := rect_width * 0.5
	var resolved_role_id: String = _resolve_role_id(owner, source_role_id)
	var broad_size := rect_length + rect_width + 80.0
	var candidates: Array = _get_candidate_enemies_for_rect(owner, center, broad_size, broad_size)
	_record_damage_query(candidates.size())
	var batcher := _get_reusable_damage_batcher(owner)
	for enemy in candidates:
		if not _is_live_enemy(enemy):
			continue
		var id: int = enemy.get_instance_id()
		if hit_registry.has(id):
			continue
		if enemy is Node2D and _enemy_hit_shape_hits_oriented_rect(owner, enemy as Node2D, center, direction, perpendicular, half_length, half_width):
			hit_registry[id] = true
			batcher.add_enemy(enemy, damage_amount, resolved_role_id, vulnerability_bonus, 2.0, slow_multiplier, slow_duration, center)
	var hit_count: int = batcher.hit_count
	PERFORMANCE_COUNTERS.add("damage_hits", hit_count)
	return batcher.flush()

static func damage_enemies_in_ellipse(owner, center: Vector2, horizontal_radius: float, vertical_radius: float, damage_amount: float, vulnerability_bonus: float, slow_multiplier: float, slow_duration: float, source_role_id: String = "") -> int:
	var safe_horizontal: float = max(1.0, horizontal_radius)
	var safe_vertical: float = max(1.0, vertical_radius)
	var resolved_role_id: String = _resolve_role_id(owner, source_role_id)
	var candidates: Array = _get_candidate_enemies_for_rect(owner, center, safe_horizontal * 2.0, safe_vertical * 2.0)
	_record_damage_query(candidates.size())
	var batcher := _get_reusable_damage_batcher(owner)
	for enemy in candidates:
		if not _is_live_enemy(enemy) or enemy is not Node2D:
			continue
		if _enemy_hit_shape_hits_ellipse(owner, enemy as Node2D, center, safe_horizontal, safe_vertical):
			batcher.add_enemy(enemy, damage_amount, resolved_role_id, vulnerability_bonus, 2.0, slow_multiplier, slow_duration, center)
	var hit_count: int = batcher.hit_count
	PERFORMANCE_COUNTERS.add("damage_hits", hit_count)
	return batcher.flush()

static func damage_enemies_in_cone(owner, origin: Vector2, direction: Vector2, cone_range: float, cone_angle_radians: float, damage_amount: float, vulnerability_bonus: float, slow_multiplier: float, slow_duration: float, source_role_id: String = "") -> int:
	var forward := direction.normalized()
	if forward.length_squared() <= 0.001:
		forward = Vector2.RIGHT
	var safe_range: float = max(1.0, cone_range)
	var half_angle: float = max(0.0, cone_angle_radians * 0.5)
	var cos_half_angle: float = cos(half_angle)
	var center: Vector2 = origin + forward * (safe_range * 0.5)
	var broad_size: float = safe_range * 2.0
	var resolved_role_id: String = _resolve_role_id(owner, source_role_id)
	var candidates: Array = _get_candidate_enemies_for_rect(owner, center, broad_size, broad_size)
	_record_damage_query(candidates.size())
	var batcher := _get_reusable_damage_batcher(owner)
	for enemy in candidates:
		if not _is_live_enemy(enemy) or enemy is not Node2D:
			continue
		if _enemy_hit_shape_hits_cone(owner, enemy as Node2D, origin, forward, safe_range, half_angle, cos_half_angle):
			batcher.add_enemy(enemy, damage_amount, resolved_role_id, vulnerability_bonus, 2.0, slow_multiplier, slow_duration, origin)
	var hit_count: int = batcher.hit_count
	PERFORMANCE_COUNTERS.add("damage_hits", hit_count)
	return batcher.flush()

static func _record_damage_query(candidate_count: int) -> void:
	PERFORMANCE_COUNTERS.add("damage_queries", 1)
	PERFORMANCE_COUNTERS.add("damage_candidates", candidate_count)

static func _apply_or_queue_hits(owner, enemies: Array, damage_amount: float, source_role_id: String, vulnerability_bonus: float, vulnerability_duration: float, slow_multiplier: float, slow_duration: float, source_position: Variant) -> void:
	if _should_queue_hits(enemies.size()):
		var batcher := _get_reusable_damage_batcher(owner)
		for enemy in enemies:
			batcher.add_enemy(enemy, damage_amount, source_role_id, vulnerability_bonus, vulnerability_duration, slow_multiplier, slow_duration, source_position)
		batcher.flush()
		return
	for enemy in enemies:
		deal_damage_to_enemy(owner, enemy, damage_amount, source_role_id, vulnerability_bonus, vulnerability_duration, slow_multiplier, slow_duration, source_position)

static func _should_queue_hits(hit_count: int) -> bool:
	return hit_count >= _get_queued_hit_threshold()

static func _get_queued_hit_threshold() -> int:
	var fps := Engine.get_frames_per_second()
	if fps > 0 and fps < PERFORMANCE_GUARD.CRITICAL_FPS_THRESHOLD:
		return CRITICAL_FPS_QUEUED_HIT_THRESHOLD
	if fps > 0 and fps < PERFORMANCE_GUARD.LOW_FPS_THRESHOLD:
		return LOW_FPS_QUEUED_HIT_THRESHOLD
	return QUEUED_HIT_THRESHOLD

static func _get_reusable_damage_batcher(owner) -> RefCounted:
	if reusable_damage_batcher == null:
		reusable_damage_batcher = PLAYER_DAMAGE_BATCHER.new(owner)
	elif reusable_damage_batcher.has_method("reset"):
		reusable_damage_batcher.reset(owner)
	return reusable_damage_batcher

static func _get_or_create_damage_job_queue(owner) -> Node:
	if owner == null or owner.get_tree() == null:
		return null
	var current_scene: Node = owner.get_tree().current_scene
	if current_scene == null:
		return null
	var queue: Node = current_scene.get_node_or_null(DAMAGE_JOB_QUEUE_NAME)
	if queue != null:
		return queue
	queue = PLAYER_DAMAGE_JOB_QUEUE.new()
	queue.name = DAMAGE_JOB_QUEUE_NAME
	current_scene.add_child(queue)
	if queue.has_method("configure"):
		queue.configure(owner)
	return queue

static func _is_enemy_inside_cone_edge(offset: Vector2, forward: Vector2, cone_range: float, half_angle: float, hit_radius: float) -> bool:
	return PLAYER_DAMAGE_SHAPE_FLOW.is_enemy_inside_cone_edge(offset, forward, cone_range, half_angle, hit_radius)

static func _get_shape_bounds(shape: Dictionary) -> Rect2:
	return PLAYER_DAMAGE_SHAPE_FLOW.get_shape_bounds(shape)

static func _shape_hits_enemy(shape: Dictionary, enemy_position: Vector2, hit_radius: float) -> bool:
	return PLAYER_DAMAGE_SHAPE_FLOW.shape_hits_enemy(shape, enemy_position, hit_radius)

static func _shape_hits_enemy_node(owner, shape: Dictionary, enemy: Node2D) -> bool:
	var target_shape: Dictionary = get_enemy_player_hit_shape(enemy)
	if target_shape.is_empty():
		return _shape_hits_enemy(shape, enemy.global_position, _get_enemy_hit_radius(owner, enemy))
	var shape_type: String = str(shape.get("type", "circle"))
	if shape_type == "line":
		var start_position: Vector2 = shape.get("start", Vector2.ZERO)
		var end_position: Vector2 = shape.get("end", start_position)
		return _enemy_shape_hits_line(target_shape, start_position, end_position, float(shape.get("width", 1.0)))
	if shape_type == "oriented_rect":
		var rect_direction: Vector2 = shape.get("axis", Vector2.RIGHT)
		rect_direction = rect_direction.normalized()
		if rect_direction.length_squared() <= 0.001:
			rect_direction = Vector2.RIGHT
		return _enemy_shape_hits_oriented_rect(
			target_shape,
			shape.get("center", Vector2.ZERO),
			rect_direction,
			rect_direction.orthogonal(),
			float(shape.get("length", 1.0)) * 0.5,
			float(shape.get("width", 1.0)) * 0.5
		)
	if shape_type == "cone":
		var forward: Vector2 = shape.get("direction", Vector2.RIGHT)
		forward = forward.normalized()
		if forward.length_squared() <= 0.001:
			forward = Vector2.RIGHT
		var cone_angle: float = max(0.0, float(shape.get("angle", 0.0)) * 0.5)
		return _enemy_shape_hits_cone(target_shape, shape.get("origin", Vector2.ZERO), forward, max(1.0, float(shape.get("range", 1.0))), cone_angle, cos(cone_angle))
	if shape_type == "ellipse":
		return _enemy_shape_hits_ellipse(
			target_shape,
			shape.get("center", Vector2.ZERO),
			max(1.0, float(shape.get("horizontal_radius", 1.0))),
			max(1.0, float(shape.get("vertical_radius", 1.0)))
		)
	return _enemy_shape_hits_circle(target_shape, shape.get("center", Vector2.ZERO), float(shape.get("radius", 1.0)))

static func _enemy_hit_shape_hits_circle(owner, enemy: Node2D, center: Vector2, radius: float) -> bool:
	var target_shape: Dictionary = get_enemy_player_hit_shape(enemy)
	if not target_shape.is_empty():
		return _enemy_shape_hits_circle(target_shape, center, radius)
	var hit_radius: float = _get_enemy_hit_radius(owner, enemy)
	var total_radius: float = radius + hit_radius
	return center.distance_squared_to(enemy.global_position) <= total_radius * total_radius

static func _enemy_hit_shape_hits_line(owner, enemy: Node2D, start_position: Vector2, end_position: Vector2, width: float) -> bool:
	var target_shape: Dictionary = get_enemy_player_hit_shape(enemy)
	if not target_shape.is_empty():
		return _enemy_shape_hits_line(target_shape, start_position, end_position, width)
	var relative: Vector2 = enemy.global_position - start_position
	var axis: Vector2 = end_position - start_position
	var length: float = axis.length()
	if length <= 0.001:
		var fallback_radius: float = width + _get_enemy_hit_radius(owner, enemy)
		return start_position.distance_squared_to(enemy.global_position) <= fallback_radius * fallback_radius
	var direction: Vector2 = axis / length
	var along: float = clamp(relative.dot(direction), 0.0, length)
	var closest: Vector2 = start_position + direction * along
	var total_width: float = width + _get_enemy_hit_radius(owner, enemy)
	return enemy.global_position.distance_squared_to(closest) <= total_width * total_width

static func _enemy_hit_shape_hits_oriented_rect(owner, enemy: Node2D, center: Vector2, direction: Vector2, perpendicular: Vector2, half_length: float, half_width: float) -> bool:
	var target_shape: Dictionary = get_enemy_player_hit_shape(enemy)
	if not target_shape.is_empty():
		return _enemy_shape_hits_oriented_rect(target_shape, center, direction, perpendicular, half_length, half_width)
	var relative: Vector2 = enemy.global_position - center
	var hit_radius: float = _get_enemy_hit_radius(owner, enemy)
	return abs(relative.dot(direction)) <= half_length + hit_radius and abs(relative.dot(perpendicular)) <= half_width + hit_radius

static func _enemy_hit_shape_hits_ellipse(owner, enemy: Node2D, center: Vector2, horizontal_radius: float, vertical_radius: float) -> bool:
	var target_shape: Dictionary = get_enemy_player_hit_shape(enemy)
	if not target_shape.is_empty():
		return _enemy_shape_hits_ellipse(target_shape, center, horizontal_radius, vertical_radius)
	var relative: Vector2 = enemy.global_position - center
	var hit_radius: float = _get_enemy_hit_radius(owner, enemy)
	var safe_horizontal: float = max(1.0, horizontal_radius + hit_radius)
	var safe_vertical: float = max(1.0, vertical_radius + hit_radius)
	return pow(relative.x / safe_horizontal, 2.0) + pow(relative.y / safe_vertical, 2.0) <= 1.0

static func _enemy_hit_shape_hits_cone(owner, enemy: Node2D, origin: Vector2, forward: Vector2, cone_range: float, half_angle: float, cos_half_angle: float) -> bool:
	var target_shape: Dictionary = get_enemy_player_hit_shape(enemy)
	if not target_shape.is_empty():
		return _enemy_shape_hits_cone(target_shape, origin, forward, cone_range, half_angle, cos_half_angle)
	var enemy_offset: Vector2 = enemy.global_position - origin
	var distance: float = enemy_offset.length()
	var hit_radius: float = _get_enemy_hit_radius(owner, enemy)
	if distance > cone_range + hit_radius:
		return false
	if distance <= hit_radius:
		return true
	var enemy_direction: Vector2 = enemy_offset / distance
	return enemy_direction.dot(forward) >= cos_half_angle or _is_enemy_inside_cone_edge(enemy_offset, forward, cone_range, half_angle, hit_radius)

static func _enemy_shape_hits_circle(target_shape: Dictionary, center: Vector2, radius: float) -> bool:
	return _is_center_inside_enemy_touch_shape(center, max(0.0, radius), target_shape)

static func _enemy_shape_hits_line(target_shape: Dictionary, start_position: Vector2, end_position: Vector2, width: float) -> bool:
	var shape_center: Vector2 = _get_shape_center(target_shape)
	if start_position.distance_squared_to(end_position) <= 0.001:
		return _enemy_shape_hits_circle(target_shape, start_position, width)
	var closest_point: Vector2 = Geometry2D.get_closest_point_to_segment(shape_center, start_position, end_position)
	return _enemy_shape_hits_circle(target_shape, closest_point, width)

static func _enemy_shape_hits_oriented_rect(target_shape: Dictionary, center: Vector2, direction: Vector2, perpendicular: Vector2, half_length: float, half_width: float) -> bool:
	var shape_center: Vector2 = _get_shape_center(target_shape)
	var relative: Vector2 = shape_center - center
	var closest_local_x: float = clamp(relative.dot(direction), -half_length, half_length)
	var closest_local_y: float = clamp(relative.dot(perpendicular), -half_width, half_width)
	var closest_point: Vector2 = center + direction * closest_local_x + perpendicular * closest_local_y
	return _enemy_shape_hits_circle(target_shape, closest_point, 0.0)

static func _enemy_shape_hits_ellipse(target_shape: Dictionary, center: Vector2, horizontal_radius: float, vertical_radius: float) -> bool:
	var shape_center: Vector2 = _get_shape_center(target_shape)
	var relative: Vector2 = shape_center - center
	var target_horizontal: float = max(0.0, float(target_shape.get("horizontal_radius", 0.0)))
	var target_vertical: float = max(0.0, float(target_shape.get("vertical_radius", 0.0)))
	var safe_horizontal: float = max(1.0, horizontal_radius + target_horizontal)
	var safe_vertical: float = max(1.0, vertical_radius + target_vertical)
	return pow(relative.x / safe_horizontal, 2.0) + pow(relative.y / safe_vertical, 2.0) <= 1.0

static func _enemy_shape_hits_cone(target_shape: Dictionary, origin: Vector2, forward: Vector2, cone_range: float, half_angle: float, cos_half_angle: float) -> bool:
	var shape_center: Vector2 = _get_shape_center(target_shape)
	var enemy_offset: Vector2 = shape_center - origin
	var distance: float = enemy_offset.length()
	var target_radius: float = max(float(target_shape.get("horizontal_radius", 0.0)), float(target_shape.get("vertical_radius", 0.0)))
	if distance > cone_range + target_radius:
		return false
	if distance <= target_radius:
		return true
	var enemy_direction: Vector2 = enemy_offset / distance
	return enemy_direction.dot(forward) >= cos_half_angle or _is_enemy_inside_cone_edge(enemy_offset, forward, cone_range, half_angle, target_radius)

static func _get_shape_center(shape: Dictionary) -> Vector2:
	var center_value: Variant = shape.get("center", Vector2.ZERO)
	return center_value if center_value is Vector2 else Vector2.ZERO

static func schedule_swordsman_slash_followthrough(owner, center: Vector2, axis_direction: Vector2, rect_length: float, rect_width: float, damage_amount: float, vulnerability_bonus: float, slow_multiplier: float, slow_duration: float, animation_duration: float, source_role_id: String, hit_registry: Dictionary) -> void:
	var pulse_count: int = max(0, int(owner.SWORD_SLASH_DAMAGE_FOLLOW_PULSES))
	if pulse_count <= 0:
		return
	var pulse_interval: float = animation_duration / float(pulse_count + 1)
	if owner != null and owner.has_method("_schedule_repeating_sequence"):
		owner._schedule_repeating_sequence(pulse_interval, pulse_count, func(_index: int) -> void:
			if is_instance_valid(owner):
				damage_enemies_in_oriented_rect_unique(owner, center, axis_direction, rect_length, rect_width, damage_amount, vulnerability_bonus, slow_multiplier, slow_duration, hit_registry, source_role_id)
		, pulse_interval)

static func apply_gunner_lock(owner, target_enemy: Node2D, lock_level: int) -> void:
	if target_enemy == null or not is_instance_valid(target_enemy):
		owner.gunner_lock_target = null
		owner.gunner_lock_stacks = 0
		return
	if owner.gunner_lock_target != target_enemy:
		owner.gunner_lock_target = target_enemy
		owner.gunner_lock_stacks = 0
	owner.gunner_lock_stacks = min(max(1, lock_level), owner.gunner_lock_stacks + 1)

static func _get_live_enemies(owner) -> Array:
	var tree: SceneTree = owner.get_tree()
	if tree == null:
		return []
	var current_frame := Engine.get_physics_frames()
	var source_key := _get_enemy_source_cache_key(owner, tree)
	if cached_live_enemies_frame == current_frame and cached_live_enemies_source_key == source_key:
		return cached_live_enemies
	cached_live_enemies = []
	var enemy_nodes: Array = _get_runtime_enemies(owner, tree)
	for enemy in enemy_nodes:
		if _is_live_enemy(enemy):
			cached_live_enemies.append(enemy)
	cached_live_enemies_frame = current_frame
	cached_live_enemies_source_key = source_key
	return cached_live_enemies

static func _get_runtime_enemies(owner, tree: SceneTree) -> Array:
	if tree == null:
		return []
	var scene: Node = tree.current_scene
	if scene != null and scene.has_method("get_runtime_enemies"):
		return scene.get_runtime_enemies()
	if owner != null and owner.has_method("get_tree"):
		var owner_tree: SceneTree = owner.get_tree()
		if owner_tree != null:
			return owner_tree.get_nodes_in_group("enemies")
	return tree.get_nodes_in_group("enemies")

static func _get_candidate_enemies_for_circle(owner, center: Vector2, radius: float) -> Array:
	return _get_candidate_enemies_for_rect(owner, center, radius * 2.0, radius * 2.0)

static func _get_candidate_enemies_for_multiple_circles(owner, centers: Array[Vector2], radius: float) -> Array:
	var safe_radius: float = max(1.0, radius)
	reusable_bounds_list.clear()
	for center in centers:
		reusable_bounds_list.append(Rect2(center - Vector2.ONE * safe_radius, Vector2.ONE * safe_radius * 2.0))
	return _get_candidate_enemies_for_bounds_list(owner, reusable_bounds_list)

static func _get_candidate_enemies_for_shapes(owner, shapes: Array[Dictionary]) -> Array:
	reusable_bounds_list.clear()
	for shape in shapes:
		reusable_bounds_list.append(_get_shape_bounds(shape))
	return _get_candidate_enemies_for_bounds_list(owner, reusable_bounds_list)

static func _get_candidate_enemies_for_rect(owner, center: Vector2, width: float, height: float) -> Array:
	var half_width: float = max(1.0, width * 0.5)
	var half_height: float = max(1.0, height * 0.5)
	return _get_candidate_enemies_for_bounds(owner, Rect2(center - Vector2(half_width, half_height), Vector2(half_width * 2.0, half_height * 2.0)))

static func _get_candidate_enemies_for_bounds_list(owner, bounds_list: Array[Rect2]) -> Array:
	var grid: Dictionary = _get_enemy_grid(owner)
	if grid.is_empty() or bounds_list.is_empty():
		reusable_candidates.clear()
		return []
	reusable_candidates.clear()
	reusable_seen_enemy_ids.clear()
	for bounds in bounds_list:
		var expanded_bounds: Rect2 = bounds.grow(DAMAGE_QUERY_BOUNDS_GROW)
		var min_cell: Vector2i = _grid_cell(expanded_bounds.position)
		var max_cell: Vector2i = _grid_cell(expanded_bounds.position + expanded_bounds.size)
		for x in range(min_cell.x, max_cell.x + 1):
			for y in range(min_cell.y, max_cell.y + 1):
				var cell := Vector2i(x, y)
				if not grid.has(cell):
					continue
				for enemy in grid[cell] as Array:
					if not _is_live_enemy(enemy):
						continue
					var enemy_id: int = enemy.get_instance_id()
					if reusable_seen_enemy_ids.has(enemy_id):
						continue
					reusable_seen_enemy_ids[enemy_id] = true
					reusable_candidates.append(enemy)
	return reusable_candidates

static func _get_candidate_enemies_for_bounds(owner, bounds: Rect2) -> Array:
	var grid: Dictionary = _get_enemy_grid(owner)
	if grid.is_empty():
		reusable_candidates.clear()
		return []
	reusable_candidates.clear()
	reusable_seen_enemy_ids.clear()
	var expanded_bounds: Rect2 = bounds.grow(DAMAGE_QUERY_BOUNDS_GROW)
	var min_cell: Vector2i = _grid_cell(expanded_bounds.position)
	var max_cell: Vector2i = _grid_cell(expanded_bounds.position + expanded_bounds.size)
	for x in range(min_cell.x, max_cell.x + 1):
		for y in range(min_cell.y, max_cell.y + 1):
			var cell := Vector2i(x, y)
			if not grid.has(cell):
				continue
			for enemy in grid[cell] as Array:
				if not _is_live_enemy(enemy):
					continue
				var enemy_id: int = enemy.get_instance_id()
				if reusable_seen_enemy_ids.has(enemy_id):
					continue
				reusable_seen_enemy_ids[enemy_id] = true
				reusable_candidates.append(enemy)
	return reusable_candidates

static func _get_enemy_grid(owner) -> Dictionary:
	var current_frame := Engine.get_physics_frames()
	var tree: SceneTree = owner.get_tree() if owner != null and owner.has_method("get_tree") else null
	var scene: Node = tree.current_scene if tree != null else null
	if scene != null:
		return ENEMY_SPATIAL_GRID.get_grid(scene)
	var source_key := _get_enemy_source_cache_key(owner, tree)
	if cached_enemy_grid_frame == current_frame and cached_enemy_grid_source_key == source_key:
		return cached_enemy_grid
	cached_enemy_grid = {}
	for enemy in _get_live_enemies(owner):
		if not _is_live_enemy(enemy) or enemy is not Node2D:
			continue
		var cell: Vector2i = _grid_cell((enemy as Node2D).global_position)
		if not cached_enemy_grid.has(cell):
			cached_enemy_grid[cell] = []
		(cached_enemy_grid[cell] as Array).append(enemy)
	cached_enemy_grid_frame = current_frame
	cached_enemy_grid_source_key = source_key
	return cached_enemy_grid

static func _get_enemy_source_cache_key(owner, tree: SceneTree) -> int:
	if tree != null:
		var scene: Node = tree.current_scene
		if scene != null:
			return scene.get_instance_id()
	if owner != null and owner is Object:
		return (owner as Object).get_instance_id()
	return 0

static func _grid_cell(position: Vector2) -> Vector2i:
	return Vector2i(floori(position.x / cached_enemy_grid_cell_size), floori(position.y / cached_enemy_grid_cell_size))

static func _get_enemy_hit_radius(owner, enemy: Node) -> float:
	if not _is_live_enemy(enemy):
		return 12.0
	if owner.has_method("_get_enemy_hit_radius"):
		return float(owner._get_enemy_hit_radius(enemy))
	return 12.0

static func _is_center_inside_enemy_touch_shape(center: Vector2, player_radius: float, shape: Dictionary) -> bool:
	if shape.is_empty():
		return false
	var shape_center: Vector2 = shape.get("center", Vector2.ZERO)
	var horizontal_radius: float = max(1.0, float(shape.get("horizontal_radius", 0.0)) + player_radius)
	var vertical_radius: float = max(1.0, float(shape.get("vertical_radius", 0.0)) + player_radius)
	var relative: Vector2 = center - shape_center
	var ellipse_value: float = pow(relative.x / horizontal_radius, 2.0) + pow(relative.y / vertical_radius, 2.0)
	return ellipse_value <= 1.0

static func _resolve_role_id(owner, source_role_id: String) -> String:
	if source_role_id != "":
		return source_role_id
	if owner != null and owner.has_method("_get_active_role"):
		return str(owner._get_active_role().get("id", ""))
	return ""

static func _resolve_damage_source_role_id(source_role_id: String) -> String:
	if source_role_id == GUNNER_NO_HUNT_SOURCE_ROLE_ID:
		return "gunner"
	return source_role_id

static func _should_apply_gunner_hunt_multiplier(source_role_id: String, resolved_source_role_id: String) -> bool:
	return resolved_source_role_id == "gunner" and source_role_id != GUNNER_NO_HUNT_SOURCE_ROLE_ID

static func _get_gunner_damage_origin(owner, enemy: Node2D) -> Vector2:
	if owner != null and owner is Node2D:
		return (owner as Node2D).global_position
	return enemy.global_position if enemy != null else Vector2.ZERO

static func _is_live_enemy(enemy) -> bool:
	if enemy == null or not is_instance_valid(enemy):
		return false
	if enemy is Node and (enemy as Node).is_queued_for_deletion():
		return false
	var pooled_inactive_value: Variant = enemy.get("pooled_inactive")
	if pooled_inactive_value != null and bool(pooled_inactive_value):
		return false
	var rebirth_timer_value: Variant = enemy.get("rebirth_timer")
	if rebirth_timer_value != null and float(rebirth_timer_value) > 0.0:
		return false
	var current_health_value: Variant = enemy.get("current_health")
	if current_health_value != null and float(current_health_value) <= 0.0:
		return false
	return true
