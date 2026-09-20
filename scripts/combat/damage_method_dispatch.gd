extends RefCounted

# Damage is called many times per frame. Reflect once per script/method, not hit.
# Keep Script references as keys so a freed object's ID cannot alias another type.
static var method_ranges: Dictionary = {}


static func accepts_arguments(target: Object, method_name: StringName, count: int) -> bool:
	var script: Script = target.get_script() as Script
	var type_key: Variant = script if script != null else target.get_class()
	var methods: Dictionary = method_ranges.get(type_key, {})
	if not methods.has(method_name):
		var argument_range := Vector2i(-1, -1)
		for method: Dictionary in target.get_method_list():
			if StringName(method.get("name", "")) != method_name:
				continue
			var args: Array = method.get("args", [])
			var defaults: Array = method.get("default_args", [])
			argument_range = Vector2i(maxi(0, args.size() - defaults.size()), args.size())
			break
		methods[method_name] = argument_range
		method_ranges[type_key] = methods
	var limits: Vector2i = methods[method_name]
	return count >= limits.x and count <= limits.y
