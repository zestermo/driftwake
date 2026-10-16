extends "res://scripts/enemies/beasts/behemoth.gd"
## The Dune Strider (BeastPool "dune_strider", a desert island's roamer): the behemoth's
## wandering and temper in a camel the height of a house - long legs, a long neck, two great
## shaggy humps, tack and rags of an old caravan still hanging off it. It wanders from one
## place to the next; crowd it or strike it and it charges, butts and stomps, a bellow before each.


func _init() -> void:
	boss_name = "The Dune Strider"


func _spec() -> Dictionary:
	return {"hip_h": 3.0, "len": 3.0, "chest_r": 1.2, "hip_r": 1.05, "neck": Vector3(0, 1.6, -1.3), "head": Vector3(0.5, 0.48, 0.72),
		"snout": 0.65, "tail": 1.0, "tail_r": 0.12, "coat": Color(0.82, 0.66, 0.44), "under": Color(0.9, 0.8, 0.62), "mark": Color(0.5, 0.36, 0.22),
		"tex": "fur", "ears": 0.3, "eye": Color(1.0, 0.65, 0.25)}


## Two humps shagged with darker hair, a ragged old saddle cloth and a rope hanging off it.
func _extras() -> void:
	var cr: float = spec["chest_r"]
	var ln: float = spec["len"]
	var rng := _rng_fixed()
	for z in [-ln * 0.3, ln * 0.25]:
		mb("Body").add_blob(spec["coat_mat"], Transform3D(Basis(), Vector3(0, cr * 1.1, z)), Vector3(cr * 0.75, cr * 0.85, cr * 0.8), rng, 0.15, 4, 8, 1.0, Color(0.85, 0.85, 0.85))
		for k in range(5):
			var a := TAU * k / 5.0
			mb("Body").add_blob(spec["coat_mat"], Transform3D(Basis(), Vector3(cos(a) * cr * 0.5, cr * 1.65, z + sin(a) * cr * 0.4)), Vector3(cr * 0.25, cr * 0.2, cr * 0.25), rng, 0.3, 3, 5, 1.0, Color(0.6, 0.6, 0.6))
	var cloth := PSXMat.lit("rug_kilim", Color(0.85, 0.8, 0.75))
	mb("Body").add_box(cloth, Transform3D(Basis(), Vector3(0, cr * 0.95, -ln * 0.02)), Vector3(cr * 2.3, 0.05, ln * 0.35), 1.0, Color.WHITE, false)
	for s in [-1.0, 1.0]:
		mb("Body").add_box(cloth, Transform3D(Basis(Vector3.BACK, s * 1.35), Vector3(s * cr * 1.05, cr * 0.45, -ln * 0.02)), Vector3(cr * 0.9, 0.05, ln * 0.35), 1.0, Color(0.85, 0.85, 0.85), false)
	mb("Body").add_tube(PSXMat.lit("rope"), MeshBuilder.curve_points(Vector3(cr * 1.0, cr * 0.4, -ln * 0.1), Vector3(cr * 1.2, -cr * 0.5, 0.0), Vector3(cr * 1.0, -cr * 0.9, ln * 0.15), 5), 0.05, 0.05, 4, 1.0)


func _coat_at(p: Vector3) -> Color:
	return (spec["coat"] as Color).lerp(spec["under"], smoothstep(-0.2, -0.7, p.y / maxf(float(spec["chest_r"]), 0.1)))
