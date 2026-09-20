extends Node2D

# Keep the original four polygon layers and their world z order. Instances
# share the exact 20-sided geometry; no texture baking or lower detail.
const META_KEY := &"_boss_projectile_renderer"
const PARTS := ["Glow", "Outline", "Polygon2D", "BossCore"]
const LAYER_Z := [10, 11, 12, 13]
const LAYER_SCALE := [1.8, 1.2, 1.0, 0.42]
const LAYER_SHADER := preload("res://scripts/enemies/boss_projectile_layer.gdshader")
const BUDGET := preload("res://scripts/enemies/boss_danmaku_budget.gd")
const CAPACITY := BUDGET.LIMIT + BUDGET.POOL_LIMIT
var dirty := true
var members: Dictionary = {}
var slots: Array = []
var slot_by_id: Dictionary = {}
var meshes: Array[MultiMesh] = []


static func get_or_create(scene: Node) -> Node2D:
	var existing = scene.get_meta(META_KEY) if scene.has_meta(META_KEY) else null
	if is_instance_valid(existing):
		return existing
	var renderer := load("res://scripts/enemies/boss_projectile_renderer.gd").new() as Node2D
	renderer.name = "BossProjectileBatch"
	scene.add_child(renderer)
	scene.set_meta(META_KEY, renderer)
	return renderer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	var points := preload("res://scripts/enemies/enemy_geometry.gd").build_circle_points(8.0, 20)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = points
	arrays[Mesh.ARRAY_INDEX] = Geometry2D.triangulate_polygon(points)
	var circle := ArrayMesh.new()
	circle.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, Mesh.ARRAY_FLAG_USE_2D_VERTICES)
	# The glow expands vertices in the shader, so include it in culling.
	circle.custom_aabb = AABB(Vector3(-14.4, -14.4, -0.5), Vector3(28.8, 28.8, 1.0))
	var mesh := MultiMesh.new()
	mesh.transform_format = MultiMesh.TRANSFORM_2D
	mesh.use_colors = true
	mesh.use_custom_data = true
	mesh.mesh = circle
	mesh.instance_count = CAPACITY
	mesh.visible_instance_count = 0
	for layer in range(4):
		var item := MultiMeshInstance2D.new()
		item.name = PARTS[layer]
		item.z_index = LAYER_Z[layer]
		item.multimesh = mesh
		var material := ShaderMaterial.new()
		material.shader = LAYER_SHADER
		material.set_shader_parameter("layer", layer)
		material.set_shader_parameter("layer_scale", LAYER_SCALE[layer])
		item.material = material
		add_child(item)
		meshes.append(mesh)


func add_projectile(bullet: Node2D) -> void:
	for part in PARTS:
		var polygon := bullet.get_node_or_null(part) as Polygon2D
		if polygon != null:
			polygon.hide()
	var id := bullet.get_instance_id()
	if not slot_by_id.has(id):
		if slots.size() >= CAPACITY:
			_compact_slots()
		# New nodes normally append in scene order. A late conversion of an
		# older pooled node needs a one-time reorder to retain alpha blending.
		if not slots.is_empty() and is_instance_valid(slots.back()) and bullet.get_index() < slots.back().get_index():
			dirty = true
		slot_by_id[id] = slots.size()
		slots.append(bullet)
	members[id] = bullet
	bullet.boss_render_owner = self
	bullet.boss_render_slot = int(slot_by_id[id])
	update_transform(bullet)
	update_color(bullet)
	meshes[0].visible_instance_count = slots.size()


func remove_projectile(bullet: Node2D) -> void:
	members.erase(bullet.get_instance_id())
	var slot: int = bullet.boss_render_slot
	if slot >= 0:
		# Keep a pooled node's slot/order. Empty slots use zero-area geometry,
		# so they don't shade pixels or require shifting every live instance.
		meshes[0].set_instance_transform_2d(slot, Transform2D(Vector2.ZERO, Vector2.ZERO, Vector2.ZERO))
	bullet.boss_render_owner = null
	bullet.boss_render_slot = -1
	for part in PARTS:
		var polygon := bullet.get_node_or_null(part) as Polygon2D
		if polygon != null:
			polygon.show()
	if members.is_empty():
		meshes[0].visible_instance_count = 0


func update_transform(bullet: Node2D) -> void:
	var shape := bullet.transform.scaled_local(Vector2.ONE * float(bullet.size_scale))
	meshes[0].set_instance_transform_2d(bullet.boss_render_slot, shape)


func update_color(bullet: Node2D) -> void:
	var base: Color = bullet.visual_color
	var tint := bullet.modulate if bullet.visible else Color.TRANSPARENT
	var slot: int = bullet.boss_render_slot
	meshes[0].set_instance_color(slot, Color(base.r, base.g, base.b, tint.a))
	meshes[0].set_instance_custom_data(slot, Color(tint.r, tint.g, tint.b, 1.0 if bullet.visual_style == "boss_danmaku_shadow_orb" else 0.0))


func _process(_delta: float) -> void:
	sync()


func sync(force_refresh: bool = false) -> void:
	if dirty:
		_compact_slots()
	elif force_refresh:
		for bullet in members.values():
			update_transform(bullet)
			update_color(bullet)


func _compact_slots() -> void:
	for id in members.keys():
		var bullet = members[id]
		if not is_instance_valid(bullet) or bullet.is_queued_for_deletion():
			members.erase(id)
			if is_instance_valid(bullet):
				bullet.boss_render_owner = null
				bullet.boss_render_slot = -1
	var valid: Array = []
	for bullet in slots:
		if is_instance_valid(bullet) and not bullet.is_queued_for_deletion() and (bullet.boss_render_owner == self or bullet.pooled):
			valid.append(bullet)
	valid.sort_custom(func(a, b): return a.get_index() < b.get_index())
	slots = valid
	slot_by_id.clear()
	for index in range(slots.size()):
		var bullet: Node2D = slots[index]
		slot_by_id[bullet.get_instance_id()] = index
		if bullet.boss_render_owner == self:
			bullet.boss_render_slot = index
			update_transform(bullet)
			update_color(bullet)
		else:
			meshes[0].set_instance_transform_2d(index, Transform2D(Vector2.ZERO, Vector2.ZERO, Vector2.ZERO))
	meshes[0].visible_instance_count = slots.size() if not members.is_empty() else 0
	dirty = false
