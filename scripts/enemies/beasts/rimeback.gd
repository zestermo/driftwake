extends "res://scripts/enemies/beasts/behemoth.gd"
## The Rimeback (BeastPool "rimeback", a snow island's roamer): the behemoth's wandering
## and temper in a woolly giant - a shaggy white coat hanging to its knees, a domed head,
## two long tusks curling up and out, ice caked along its back. It wanders the snowfields
## from one place to the next; crowd it or strike it and it charges, tosses its tusks and
## stomps, a bellow before each.


func _init() -> void:
	boss_name = "The Rimeback"


func _spec() -> Dictionary:
	return {"hip_h": 2.4, "len": 3.2, "chest_r": 1.6, "hip_r": 1.35, "neck": Vector3(0, -0.15, -0.6), "head": Vector3(0.85, 0.85, 0.85),
		"snout": 0.5, "tail": 1.0, "tail_r": 0.15, "coat": Color(0.86, 0.85, 0.82), "under": Color(0.72, 0.7, 0.66), "mark": Color(0.55, 0.52, 0.48),
		"tex": "fur", "ears": 0.3, "eye": Color(0.4, 0.8, 1.0)}


## Tusks curling up and out, a trunk, the coat hanging in hanks, ice along its back.
func _extras() -> void:
	var hd: Vector3 = spec["head"]
	var cr: float = spec["chest_r"]
	var ln: float = spec["len"]
	var ivory := PSXMat.flat(Color(0.93, 0.9, 0.8))
	var ice := PSXMat.lit("ice", Color(0.88, 0.95, 1.0), {"affine": 0.4})
	var rng := _rng_fixed()
	for s in [-1.0, 1.0]:
		var t0 := Vector3(s * hd.x * 0.35, -hd.y * 0.45, -hd.z * 0.8)
		mb("Head").add_tube(ivory, PackedVector3Array([t0, t0 + Vector3(s * 0.3, -0.7, -0.9), t0 + Vector3(s * 0.8, -0.2, -1.9), t0 + Vector3(s * 0.5, 0.6, -2.2)]), 0.2, 0.04, 6, 1.0)
	mb("Head").add_tube(spec["coat_mat"], PackedVector3Array([Vector3(0, -hd.y * 0.2, -hd.z * 1.1), Vector3(0, -hd.y * 1.2, -hd.z * 1.4), Vector3(0, -hd.y * 2.0, -hd.z * 1.2)]), 0.25, 0.1, 6, 1.0, Color(0.7, 0.68, 0.64))
	for k in range(18):
		var a := TAU * k / 18.0
		var z := sin(a) * ln * 0.55
		var x := cos(a) * cr * 0.95
		mb("Body").add_tube(spec["coat_mat"], PackedVector3Array([Vector3(x, -cr * 0.2, z), Vector3(x * 1.1, -cr * 0.8, z), Vector3(x * 1.05, -cr * 1.3 - rng.randf() * 0.2, z)]), 0.3, 0.12, 5, 1.0, Color(0.85, 0.85, 0.85))
	for k in range(7):
		var z := -ln * 0.5 + k * ln * 0.17
		mb("Body").add_blob(ice, Transform3D(Basis(Vector3.UP, rng.randf() * TAU), Vector3(rng.randf_range(-0.3, 0.3), cr * 0.92, z)), Vector3(0.45, 0.2, 0.4), rng, 0.3, 3, 5, 0.6)


func _coat_at(p: Vector3) -> Color:
	return (spec["coat"] as Color).lerp(spec["under"], smoothstep(-0.2, -0.7, p.y / maxf(float(spec["chest_r"]), 0.1)))
