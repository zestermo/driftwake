extends "res://scripts/enemies/beasts/alpha_boar.gd"
## The Stag King (BeastPool "stag_king", a forest island's boss): the antlered spirit of the wood, a stag the
## size of a cottage, its antlers a crown of branches hung with moss and autumn leaves, eyes green fire. The
## alpha boar's brain at a boss's scale: it lowers its crown and charges down a line, sweeps its antlers in front
## (parry it: it reels), and from the start rears and drives its forehooves down, a ring of leaves and earth round
## it (jump it). No bar over its head (the arena's). Looks: ghost-white, gold, old russet.

const STAG_COATS := [
	[Color(0.88, 0.88, 0.84), Color(0.96, 0.95, 0.9), Color(0.55, 0.62, 0.48)],
	[Color(0.85, 0.66, 0.36), Color(0.95, 0.86, 0.66), Color(0.6, 0.4, 0.2)],
	[Color(0.5, 0.3, 0.18), Color(0.78, 0.66, 0.52), Color(0.3, 0.2, 0.12)],
]


func _init() -> void:
	boss_name = "The Stag King"
	wake_r = 0.0
	charge_len = 20.0
	charge_speed = 17.0
	gore_r = 4.6
	stomp_r = 7.0


func _spec() -> Dictionary:
	var c: Array = STAG_COATS[variant % STAG_COATS.size()]
	return {"hip_h": 2.7, "len": 2.7, "chest_r": 0.74, "hip_r": 0.64, "neck": Vector3(0, 0.95, -0.6), "head": Vector3(0.34, 0.38, 0.6),
		"snout": 0.7, "tail": 0.35, "tail_r": 0.12, "coat": c[0], "under": c[1], "mark": c[2], "tex": "fur_white", "ears": 0.9,
		"eye": Color(0.45, 1.0, 0.55)}


## Antlers of branches (tines off two great beams, a crown at the top), moss hung from them, leaves caught in
## them; a mane of leaves down the neck; pale hooves.
func _extras() -> void:
	var hd: Vector3 = spec["head"]
	var bone := PSXMat.flat(Color(0.92, 0.86, 0.72))
	var moss := PSXMat.lit("leaves_late", Color(0.75, 0.95, 0.6), {"emission": Color(0.3, 0.8, 0.3), "emission_energy": 0.35})
	var leaves := [PSXMat.lit("leaves_maple", Color.WHITE, {"affine": 0.5}), PSXMat.lit("leaves_birch", Color.WHITE, {"affine": 0.5})]
	var rng := _rng_fixed()
	for s in [-1.0, 1.0]:
		var root := Vector3(s * hd.x * 0.45, hd.y * 0.75, hd.z * 0.1)
		var beam := MeshBuilder.curve_points(root, root + Vector3(s * 1.9, 1.2, 0.7), root + Vector3(s * 2.3, 3.4, -0.3), 7)
		mb("Head").add_tube(bone, beam, 0.17, 0.06, 6, 1.0)
		for t in [1, 3, 4, 6]:
			var at: Vector3 = beam[t]
			var tine := at + Vector3(s * rng.randf_range(0.1, 0.4), rng.randf_range(0.5, 0.9), -rng.randf_range(0.3, 0.7))
			mb("Head").add_tube(bone, PackedVector3Array([at, at.lerp(tine, 0.5) + Vector3(0, 0.15, 0), tine]), 0.09, 0.025, 5, 1.0)
			if t >= 3:
				mb("Head").add_blob(leaves[t % 2], Transform3D(Basis(Vector3.UP, rng.randf() * TAU), tine + Vector3(0, -0.1, 0.1)), Vector3(0.35, 0.22, 0.3), rng, 0.25, 2, 5, 0.6)
			mb("Head").add_tube(moss, PackedVector3Array([at, at + Vector3(0, -0.5, 0.05), at + Vector3(s * 0.05, -0.9, 0.1)]), 0.05, 0.02, 4, 1.0)
	for k in range(8):
		var y := 0.1 + k * 0.08
		mb("Neck").add_blob(leaves[k % 2], Transform3D(Basis(Vector3.UP, rng.randf() * TAU), Vector3(0, float(spec["chest_r"]) * 0.4 + y, 0.2 - k * 0.1)), Vector3(0.28, 0.16, 0.24), rng, 0.3, 2, 5, 0.6)
	var hoof := PSXMat.flat(Color(0.8, 0.76, 0.68))
	for leg in ["FL", "FR", "BL", "BR"]:
		mb(foot_part(leg)).add_cylinder(hoof, Transform3D(Basis(), Vector3(0, foot_y(leg) + 0.02, -0.05)), 0.16, 0.13, 0.18, 6, 1.0)


func _coat_at(p: Vector3) -> Color:
	var base := super._coat_at(p)
	return base.lerp(spec["mark"], smoothstep(0.7, 1.0, p.y / maxf(float(spec["chest_r"]), 0.1)) * 0.35)


func _hp_base() -> float:
	return 1600.0


func _poise_max() -> float:
	return 240.0


func _phase_at() -> Array:
	return [0.6, 0.3]


func _xp_base() -> int:
	return 750


func _coins_base() -> int:
	return 44


func _speed() -> float:
	return 6.2 if phase < 3 else 7.6


func _wake_move() -> String:
	return "stomp"


func _ready() -> void:
	super._ready()
	_cd["stomp"] = 3.5
	_overhead.queue_free()
	_overhead = null


func trophy(t: int) -> ItemData:
	return Gear.make("accessory", "cape", {"cape": true, "cape_color": spec["coat"]}, "Stag King's Mantle", t)
