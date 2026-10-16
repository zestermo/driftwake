extends "res://scripts/enemies/beasts/stalker.gd"
## The Sand Lion (BeastPool "sand_lion", a desert island's boss): the stalker's hunt in a
## maned desert lion - tawny, a dark shaggy mane, a tufted tail - that melts into the scrub and
## the heat round its ground and comes out of it at a run. Looks: tawny, pale gold, dusk.

const LION_COATS := [
	[Color(0.82, 0.62, 0.36), Color(0.94, 0.84, 0.64), Color(0.32, 0.18, 0.1)],
	[Color(0.92, 0.82, 0.6), Color(0.98, 0.94, 0.84), Color(0.62, 0.44, 0.22)],
	[Color(0.62, 0.42, 0.28), Color(0.82, 0.68, 0.52), Color(0.16, 0.1, 0.08)],
]


func _init() -> void:
	boss_name = "The Sand Lion"


func _spec() -> Dictionary:
	var c: Array = LION_COATS[variant % LION_COATS.size()]
	return {"hip_h": 1.45, "len": 2.1, "chest_r": 0.72, "hip_r": 0.56, "neck": Vector3(0, 0.3, -0.55), "head": Vector3(0.46, 0.42, 0.46),
		"snout": 0.32, "tail": 2.2, "tail_r": 0.12, "coat": c[0], "under": c[1], "mark": c[2], "tex": "fur", "ears": 0.3,
		"eye": Color(1.0, 0.8, 0.25)}


## The mane heaped round the head and down the chest, the tuft at the tail's end.
func _extras() -> void:
	var cr: float = spec["chest_r"]
	var rng := _rng_fixed()
	for k in range(16):
		var a := TAU * k / 16.0
		mb("Neck").add_blob(spec["coat_mat"], Transform3D(Basis(Vector3.RIGHT, -0.3), Vector3(sin(a) * cr * 0.75, cos(a) * cr * 0.7 + 0.15, 0.1 + absf(cos(a)) * 0.1)),
			Vector3(cr * 0.32, cr * 0.42, cr * 0.38), rng, 0.3, 3, 5, 1.0, Color(0.95, 0.95, 0.95))
	mb("Tail3").add_blob(spec["coat_mat"], Transform3D(Basis(), Vector3(0, 0, float(spec["tail"]) * 0.25)), Vector3(0.16, 0.16, 0.22), rng, 0.3, 3, 5, 1.0, Color(0.95, 0.95, 0.95))


## The mane and the tuft dark; tawny elsewhere.
func _coat_at(p: Vector3) -> Color:
	var base := (spec["coat"] as Color).lerp(spec["under"], smoothstep(-0.2, -0.6, p.y / maxf(float(spec["chest_r"]), 0.1)))
	return base


func _paint(part: MeshBuilder, coat: Material) -> void:
	super._paint(part, coat)
	if part._surfaces.has(coat) and (part == mb("Neck") or part == mb("Tail3")):
		var c: PackedColorArray = part._surfaces[coat]["c"]
		for i in range(c.size()):
			c[i] = (spec["mark"] as Color) * c[i].r
		part._surfaces[coat]["c"] = c


func trophy(t: int) -> ItemData:
	return Gear.make("accessory", "cape", {"cape": true, "cape_color": spec["coat"]}, "Sand Lion's Mane", t)
