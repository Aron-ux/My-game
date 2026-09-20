extends RefCounted

const CELL_SIZE := 96.0
const ENEMY_SPATIAL_GRID := preload("res://scripts/enemies/enemy_spatial_grid.gd")

static var cached_frame: int = -1
static var cached_snapshot_revision: int = -1
static var cached_grid: Dictionary = {}
static var cached_candidates: Dictionary = {}


static func clear_runtime_state() -> void:
	cached_frame = -1
	cached_snapshot_revision = -1
	cached_grid = {}
	cached_candidates.clear()


# The input is the existing per-physics-frame grid snapshot. Preserve its cell
# order; callers still test live positions, health and hit registries.
static func get_candidates(grid: Dictionary, center: Vector2, radius: float) -> Array:
	var frame := Engine.get_physics_frames()
	if cached_frame != frame or cached_snapshot_revision != ENEMY_SPATIAL_GRID.snapshot_revision or not is_same(cached_grid, grid):
		cached_frame = frame
		cached_snapshot_revision = ENEMY_SPATIAL_GRID.snapshot_revision
		cached_grid = grid
		cached_candidates.clear()
	var cell_radius := ceili(maxf(1.0, radius) / CELL_SIZE)
	var cell := Vector2i(floori(center.x / CELL_SIZE), floori(center.y / CELL_SIZE))
	var key := Vector3i(cell.x, cell.y, cell_radius)
	if cached_candidates.has(key):
		return cached_candidates[key]
	var candidates: Array = []
	for x in range(cell.x - cell_radius, cell.x + cell_radius + 1):
		for y in range(cell.y - cell_radius, cell.y + cell_radius + 1):
			var query_cell := Vector2i(x, y)
			if grid.has(query_cell):
				candidates.append_array(grid[query_cell])
	candidates.make_read_only()
	cached_candidates[key] = candidates
	return candidates
