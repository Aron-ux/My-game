extends RefCounted

# Authored in world space. Each pattern uses the same fixed wave budget;
# variation comes from emitters, paths, silhouettes and timing, not FPS caps.
const PATTERN_COUNT := 12
const PATTERN_NAMES := [
	"六瓣旋樱", "双向螺旋", "幽光波纹", "冥蝶展翅",
	"层樱折扇", "交织绫网", "亡灵漂流", "停驻再绽",
	"红蓝蝶潮", "垂樱流瀑", "双生花庭", "蝶羽穿针"
]


static func fire_wave(enemy) -> void:
	var count: int = enemy.boss_danmaku_count
	var wave: int = enemy.boss_danmaku_wave
	var pattern: int = enemy.boss_danmaku_pattern
	var spin: float = enemy.boss_danmaku_spin
	var base: float = enemy.boss_danmaku_rotation
	for index in range(count):
		var spoke := TAU * float(index) / float(count)
		var side := -1.0 if index % 2 == 0 else 1.0
		var angle := base + spoke
		var speed := 156.0
		var angular := 0.0
		var sway := 0.0
		var frequency := 0.0
		var hue := 0.0
		var origin: Vector2 = enemy.global_position
		var style := "boss_danmaku_orb"
		var mode := "danmaku"
		var config: Dictionary = {}
		match pattern:
			0:
				angle += wave * 0.105 * spin
				speed += 40.0 * cos(spoke * 6.0)
				angular = 0.13
				hue = 0.78 + wave * 0.026
				style = "boss_danmaku_petal"
			1:
				angle += side * wave * 0.30 * spin
				speed += 16.0
				angular = side * 0.20
				hue = 0.50 if side < 0.0 else 0.07
			2:
				angle += wave * 0.075 * spin
				speed += 24.0 * sin(spoke * 4.0 + wave * 0.7)
				angular = -0.055
				sway = 0.14
				frequency = 0.42
				hue = 0.30 + wave * 0.046
			3:
				# A full butterfly outline, with successive contours opening
				# into larger wings instead of another circular spiral.
				var radius := exp(cos(spoke)) - 2.0 * cos(4.0 * spoke) + pow(sin(spoke / 12.0), 5.0)
				var wing := Vector2(sin(spoke), cos(spoke)) * radius
				angle = base + wing.angle() + wave * 0.035 * spin
				speed = 65.0 + wing.length() * (33.0 + wave * 3.0)
				angular = side * 0.025
				hue = 0.78 + wave * 0.035
				style = "boss_danmaku_butterfly"
			4:
				# Four layered fans with wide seams between them. Each cast
				# snapshots its orientation; subsequent waves do not home.
				var fan := index % 4
				var lane := index / 4
				var lanes := maxi(1, (count + 3 - fan) / 4)
				var offset := float(lane) / float(maxi(1, lanes - 1)) - 0.5
				angle = base + fan * TAU / 4.0 + offset * 0.93 + wave * 0.065 * spin
				speed = 116.0 + wave * 17.0
				angular = 0.035
				hue = 0.91 - fan * 0.035
				style = "boss_danmaku_petal"
			5:
				# Opposed emitters weave straight diagonal lanes. No curved
				# orbit here; the crossings migrate as the fans sweep.
				var lane := index / 2
				var lanes := maxi(2, (count + 1) / 2)
				var offset := float(lane) / float(lanes - 1) - 0.5
				origin += Vector2(0, side * 115.0).rotated(base)
				angle = base - side * 0.48 + offset * 2.0 + wave * 0.075 * spin
				speed = 150.0 + wave * 9.0
				hue = 0.53 if side < 0 else 0.90
				style = "boss_danmaku_rice"
			6:
				# Long lateral S-curves from a compact row, with alternating
				# flight directions, rather than radial sine rings.
				origin += Vector2(0, (float(index) / float(maxi(1, count - 1)) - 0.5) * 230.0).rotated(base)
				angle = base + (PI if wave % 2 else 0.0) + side * 0.18
				speed = 112.0 + absf(sin(spoke)) * 70.0
				hue = 0.56 + wave * 0.04
				style = "boss_danmaku_butterfly"
				mode = "danmaku_drift"
				config = {"sine_amplitude": 80.0 + wave * 8.0, "sine_frequency": 0.24, "sine_phase": spoke}
			7:
				# Decelerate into a flower, visibly turn while hovering,
				# then accelerate out along tangents. Analytic save-safe path.
				angle += wave * 0.09 * spin
				speed = 180.0 + 35.0 * cos(spoke * 5.0)
				hue = 0.87 + wave * 0.018
				style = "boss_danmaku_petal"
				mode = "danmaku_bloom"
				config = {
					"danmaku_brake_time": 2.4, "danmaku_hold_time": 0.65,
					"danmaku_release_angle": side * 1.15 * spin,
					"danmaku_release_speed": 175.0 + wave * 8.0
				}
			8:
				# Alternating red/blue butterfly curtains: staggered broad
				# fans and speed layers produce moving gaps across each wave.
				var fan := index % 3
				var lane := index / 3
				var lanes := maxi(2, (count + 2 - fan) / 3)
				var offset := float(lane) / float(lanes - 1) - 0.5
				angle = base + fan * TAU / 3.0 + offset * 1.5 + (0.13 if wave % 2 else -0.13)
				speed = 120.0 + wave * 19.0
				angular = 0.045 if wave % 2 else -0.045
				hue = 0.96 if wave % 2 else 0.60
				style = "boss_danmaku_butterfly"
			9:
				# Petals pour from two sides of the core in bent fans.
				var lane := index / 2
				var lanes := maxi(2, (count + 1) / 2)
				var offset := float(lane) / float(lanes - 1) - 0.5
				origin += Vector2(0, side * 95.0).rotated(base)
				angle = base + side * 0.65 + offset * 1.8
				speed = 110.0 + wave * 19.0
				angular = -side * 0.16
				hue = 0.86 + wave * 0.022
				style = "boss_danmaku_petal"
			10:
				# Two offset five-lobed flowers turn against each other.
				origin += Vector2(0, side * 110.0).rotated(base)
				angle += side * wave * 0.16
				speed = 145.0 + 46.0 * cos(spoke * 5.0)
				angular = side * 0.16
				hue = 0.48 if side < 0 else 0.83
				style = "boss_danmaku_petal"
			11:
				# Thin paired needle fans alternate with broad butterfly
				# curtains. Aim is captured once when the cast begins.
				var fan := index % 2
				var lane := index / 2
				var lanes := maxi(2, (count + 1 - fan) / 2)
				var offset := float(lane) / float(lanes - 1) - 0.5
				var needle := wave % 3 == 0
				angle = base + fan * PI + offset * (0.55 if needle else 2.4) + wave * 0.055 * spin
				speed = 225.0 if needle else 135.0 + wave * 9.0
				angular = 0.0 if needle else side * 0.06
				hue = 0.12 if needle else 0.72 + fan * 0.2
				style = "boss_danmaku_rice" if needle else "boss_danmaku_butterfly"
		speed += float(enemy.boss_phase - 1) * 6.0
		var direction := Vector2.RIGHT.rotated(angle)
		var defaults := {
			"danmaku_angular_speed": angular * spin,
			"danmaku_sway": sway,
			"sine_frequency": frequency,
			"sine_phase": spoke * 3.0 + wave * 0.5,
			"hit_radius": 6.8, "size_scale": 0.85, "visual_style": style
		}
		defaults.merge(config, true)
		enemy._spawn_projectile(
			origin + direction * (28.0 + enemy.scale.x * 4.0),
			direction, speed, enemy.attack * 0.8, 10.0,
			Color.from_hsv(fposmod(hue, 1.0), 0.65, 1.0), mode, defaults
		)
