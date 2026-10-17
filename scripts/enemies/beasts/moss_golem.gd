extends "res://scripts/enemies/beasts/alpha_boar.gd"
## The moss golem (BeastPool "moss_golem", a forest island's miniboss at its ruins): the old stones woken, a
## four-legged heap of granite boulders bound in moss and roots, toadstools on its back, a slab of a head with two
## glowing pits. The alpha boar's brain on a boulder-beast: a grinding run down a line, a swing of its head in front
## (parry it: it reels), and below half, up and down - a ring of shattered stone round it (jump it). Name and health
## over its head; back to its ruins, healed, once everyone's gone.


func _init() -> void:
	boss_name = "The Moss Golem"
	wake_r = 16.0
	leash_r = 36.0
	charge_len = 14.0
	charge_speed = 12.0
	gore_r = 3.6
	stomp_r = 5.0


func _spec() -> Dictionary:
	return {"hip_h": 1.35, "len": 1.7, "chest_r": 1.0, "hip_r": 0.82, "neck": Vector3(0, -0.05, -0.4), "head": Vector3(0.55, 0.42, 0.5),
		"snout": 0.2, "tail": 0.3, "tail_r": 0.2, "coat": Color(0.62, 0.62, 0.6), "under": Color(0.48, 0.48, 0.46), "mark": Color(0.4, 0.5, 0.26),
		"tex": "forest_rock", "ears": 0.0, "eye": Color(0.5, 1.0, 0.6)}


## Boulders on its back and shoulders, moss over them, roots binding them, toadstools.
func _extras() -> void:
	var cr: float = spec["chest_r"]
	var ln: float = spec["len"]
	var rock := PSXMat.lit("forest_rock", Color.WHITE, {"affine": 0.6})
	var moss := PSXMat.lit("leaves_late", Color(0.7, 0.9, 0.55), {"affine": 0.5})
	var root := PSXMat.lit("bark", Color(0.8, 0.68, 0.55))
	var rng := _rng_fixed()
	for k in range(6):
		var z := -ln * 0.55 + k * ln * 0.22
		var s := rng.randf_range(0.5, 0.75)
		mb("Body").add_blob(rock, Transform3D(Basis(Vector3.UP, rng.randf() * TAU), Vector3(rng.randf_range(-0.3, 0.3), cr * 0.85, z)), Vector3(s, s * 0.7, s), rng, 0.25, 3, 6, 0.5)
		mb("Body").add_blob(moss, Transform3D(Basis(), Vector3(rng.randf_range(-0.3, 0.3), cr * 0.85 + s * 0.6, z)), Vector3(s * 0.7, s * 0.25, s * 0.6), rng, 0.2, 2, 5, 0.6)
	for s in [-1.0, 1.0]:
		mb("Body").add_tube(root, MeshBuilder.curve_points(Vector3(s * cr * 0.9, cr * 0.7, -ln * 0.5), Vector3(s * cr * 1.1, 0.0, 0.0), Vector3(s * cr * 0.8, -cr * 0.5, ln * 0.5), 6), 0.08, 0.05, 5, 1.0)
	var cap := PSXMat.flat(Color(0.78, 0.14, 0.1))
	for k in range(4):
		mb("Body").add_cylinder(cap, Transform3D(Basis(), Vector3(rng.randf_range(-0.4, 0.4), cr * 1.25, rng.randf_range(-ln * 0.4, ln * 0.4))), 0.15, 0.03, 0.1, 6, 1.0)


func _hp_base() -> float:
	return 640.0


func _poise_max() -> float:
	return 150.0


func _speed() -> float:
	return 5.0


func trophy(_t: int) -> ItemData:
	return null
