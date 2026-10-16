extends "res://scripts/enemies/beasts/alpha_boar.gd"
## The frost wolf alpha (BeastPool "frost_alpha", a snow island's miniboss at its lair):
## a grey-white wolf the size of a horse, its ruff rimed with ice. The alpha boar's brain
## on a wolf: a long low run at you down a line (the charge), a snapping bite in front
## (parry it: it reels), and below half, up on its hind legs and down - a ring of frost
## round it (jump it). Name and health over its head; back to its den, healed, once
## everyone's gone.


func _init() -> void:
	boss_name = "Frostfang"
	wake_r = 18.0
	leash_r = 40.0
	charge_len = 16.0
	charge_speed = 18.0
	gore_r = 3.2
	stomp_r = 4.6


func _spec() -> Dictionary:
	return {"hip_h": 1.25, "len": 1.9, "chest_r": 0.62, "hip_r": 0.48, "neck": Vector3(0, 0.25, -0.5), "head": Vector3(0.36, 0.34, 0.42),
		"snout": 0.55, "tail": 1.4, "tail_r": 0.16, "coat": Color(0.7, 0.72, 0.75), "under": Color(0.93, 0.94, 0.95), "mark": Color(0.36, 0.37, 0.4),
		"tex": "fur", "ears": 0.9, "eye": Color(0.5, 0.9, 1.0)}


## A shaggy ruff rimed with ice, a dark saddle, fangs.
func _extras() -> void:
	var hd: Vector3 = spec["head"]
	var sn: float = spec["snout"]
	var cr: float = spec["chest_r"]
	var ivory := PSXMat.flat(Color(0.95, 0.93, 0.86))
	var frost := PSXMat.lit("ice", Color(0.85, 0.95, 1.0), {"emission": Color(0.3, 0.6, 1.0), "emission_energy": 0.5, "affine": 0.3})
	var rng := _rng_fixed()
	for s in [-1.0, 1.0]:
		mb("Head").add_cylinder(ivory, Transform3D(Basis(Vector3.RIGHT, PI), Vector3(s * hd.x * 0.25, -hd.y * 0.35, -hd.z * 0.9 - sn * 0.7)), 0.04, 0.0, 0.18, 4, 1.0, Color.WHITE, false, false, false)
	for k in range(10):
		var a := -1.3 + k * 0.29
		mb("Neck").add_blob(spec["coat_mat"], Transform3D(Basis(Vector3.RIGHT, -0.5), Vector3(sin(a) * cr * 0.7, cos(a) * cr * 0.5, -0.05)), Vector3(cr * 0.25, cr * 0.4, cr * 0.25), rng, 0.3, 3, 5, 1.0, Color(0.95, 0.95, 0.97))
		if k % 3 == 0:
			mb("Neck").add_cylinder(frost, Transform3D(Basis(Vector3.RIGHT, 2.6), Vector3(sin(a) * cr * 0.8, cos(a) * cr * 0.6 - 0.1, 0.0)), 0.05, 0.0, 0.3, 4, 1.0, Color.WHITE, false, false, false)


func _coat_at(p: Vector3) -> Color:
	var base := super._coat_at(p)
	return base.lerp(spec["mark"], smoothstep(0.55, 0.9, p.y / maxf(float(spec["chest_r"]), 0.1)) * 0.6)


func _hp_base() -> float:
	return 560.0


func _speed() -> float:
	return 7.4
