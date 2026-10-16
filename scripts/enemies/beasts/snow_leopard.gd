extends "res://scripts/enemies/beasts/stalker.gd"
## The White Shade (BeastPool "snow_leopard", a snow island's boss): the stalker's
## hunt in a snow leopard's coat - smoke-white with dark open rosettes, a heavy tail -
## that vanishes into the snow-laden firs round its run. Looks: white, smoke, pale gold.

const SNOW_COATS := [
	[Color(0.88, 0.88, 0.86), Color(0.97, 0.97, 0.96), Color(0.22, 0.22, 0.24)],
	[Color(0.62, 0.63, 0.66), Color(0.86, 0.86, 0.86), Color(0.16, 0.16, 0.18)],
	[Color(0.86, 0.8, 0.66), Color(0.96, 0.94, 0.88), Color(0.3, 0.24, 0.18)],
]


func _init() -> void:
	boss_name = "The White Shade"


func _spec() -> Dictionary:
	var c: Array = SNOW_COATS[variant % SNOW_COATS.size()]
	return {"hip_h": 1.3, "len": 2.0, "chest_r": 0.64, "hip_r": 0.54, "neck": Vector3(0, 0.3, -0.55), "head": Vector3(0.4, 0.33, 0.4),
		"snout": 0.26, "tail": 2.6, "tail_r": 0.2, "coat": c[0], "under": c[1], "mark": c[2], "tex": "fur", "ears": 0.35,
		"eye": Color(0.6, 0.95, 1.0)}


## Open rosettes, larger and sparser than a jungle cat's.
func _coat_at(p: Vector3) -> Color:
	var base := (spec["coat"] as Color).lerp(spec["under"], smoothstep(-0.2, -0.6, p.y / maxf(float(spec["chest_r"]), 0.1)))
	var q := p * 3.6
	var ring := absf(sin(q.x * 1.3 + sin(q.z * 0.9) * 1.7) * sin(q.z * 1.1 + q.y * 0.8 + sin(q.x * 0.7)))
	var rim := smoothstep(0.66, 0.8, ring) * (1.0 - smoothstep(0.84, 0.95, ring))
	return base.lerp(spec["mark"], rim * 0.85)


func trophy(t: int) -> ItemData:
	return Gear.make("accessory", "cape", {"cape": true, "cape_color": spec["coat"]}, "White Shade Pelt", t)
