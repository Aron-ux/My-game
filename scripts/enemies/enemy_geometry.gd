extends RefCounted

static func build_circle_points(radius: float, segments: int = 20) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(segments):
		var angle: float = TAU * float(index) / float(segments)
		points.append(Vector2.RIGHT.rotated(angle) * radius)
	return points
