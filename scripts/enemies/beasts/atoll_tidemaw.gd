extends "res://scripts/enemies/beasts/behemoth.gd"
## The Tidemaw (BeastPool "tidemaw", a coral atoll's roamer): the behemoth's wandering and temper in a sea turtle grown
## to the size of a boat, gone to land in its old age. A domed shell crusted with barnacles and coral, a hooked beak that
## can take a canoe in half, thick scaled legs. It wades the sandbars from islet to islet grazing turtle grass; crowd it
## and it warns you off, then turns on you.
##   snap     a lunge of the beak in front (parry it: it reels)
##   wash     it stamps and the shallows burst up round it (jump it)
##   bash     it tucks in and drives its shell down a line at you (its one knockdown)
##   spouts   (below half) it rears and slams down: the water bursts in spots round you


func _init() -> void:
	boss_name = "The Tidemaw"
	wake_r = 16.0
	leash_r = 46.0


func _spec() -> Dictionary:
	return {"hip_h": 1.25, "front_h": 1.3, "len": 3.0, "chest_r": 1.05, "hip_r": 1.0, "neck": Vector3(0, -0.15, -0.7), "head": Vector3(0.55, 0.45, 0.62),
		"snout": 0.32, "tail": 0.9, "tail_r": 0.28, "tail_kind": "stub", "coat": Color(0.4, 0.46, 0.34), "under": Color(0.82, 0.78, 0.6), "mark": Color(0.22, 0.26, 0.2),
		"tex": "scales", "ears": 0.0, "eye": Color(0.2, 0.14, 0.08), "leg_k": 1.6, "front_k": 1.15, "foot": "pad", "sprawl": 0.55, "bend": 0.6, "gait": "lumber"}


## The shell: a great dome over the back in scutes, barnacles and coral growing on it; a hooked beak.
func _extras() -> void:
	var hd: Vector3 = spec["head"]
	# (the dome's own size, over a body kept slimmer so the shell covers it: half widths cr * 1.25 across, ln * 0.62 long)
	var cr := 1.5
	var ln := 3.9
	var lift: float = float(spec["front_h"]) - float(spec["hip_h"])
	var rng := _rng_fixed()
	var shell := PSXMat.lit("leather", Color(0.62, 0.52, 0.34))
	var scute := PSXMat.lit("leather", Color(0.4, 0.31, 0.2))
	var coral := PSXMat.lit("atoll_coral", Color(1.1, 0.9, 0.86))
	var beak := PSXMat.flat(Color(0.32, 0.28, 0.22))
	mb("Body").add_blob(shell, Transform3D(Basis(), Vector3(0, lift * 0.5 + cr * 0.45, 0.05)), Vector3(cr * 1.25, cr * 0.85, ln * 0.62), rng, 0.08, 4, 10, 1.0, Color.WHITE, -0.2)
	for k in range(5):
		var z := lerpf(-ln * 0.42, ln * 0.42, k / 4.0)
		var u := z / (ln * 0.62)
		var top := lift * 0.5 + cr * 0.45 + cr * 0.85 * sqrt(maxf(1.0 - u * u, 0.0))
		mb("Body").add_blob(scute, Transform3D(Basis(Vector3.RIGHT, -u * 0.8), Vector3(0, top - 0.04, z)), Vector3(cr * 0.36, 0.08, ln * 0.09), rng, 0.1, 2, 6, 1.0, Color.WHITE.darkened(0.08 * (k % 2)))
		for s in [-1.0, 1.0]:
			var x := cr * 0.72
			var side := lift * 0.5 + cr * 0.45 + cr * 0.85 * sqrt(maxf(1.0 - u * u - (x / (cr * 1.25)) * (x / (cr * 1.25)), 0.0))
			mb("Body").add_blob(scute, Transform3D(Basis(Vector3.FORWARD, s * 0.7) * Basis(Vector3.RIGHT, -u * 0.6), Vector3(s * x, side - 0.04, z)), Vector3(cr * 0.3, 0.07, ln * 0.08), rng, 0.1, 2, 6)
	for k in range(14):
		var a := rng.randf() * TAU
		var at := Vector3(cos(a) * cr * rng.randf_range(0.3, 1.05), lift * 0.5 + cr * rng.randf_range(0.9, 1.25), sin(a) * ln * 0.5)
		if rng.randf() < 0.5:
			mb("Body").add_cylinder(coral, Transform3D(Basis(), at), 0.12, 0.07, 0.18, 5, 1.0, Color(0.95, 0.92, 0.85))
		else:
			mb("Body").add_blob(coral, Transform3D(Basis(Vector3.UP, rng.randf() * TAU), at), Vector3(0.22, 0.14, 0.18), rng, 0.3, 2, 6, 1.0, Color(1.0, 0.62, 0.6).lerp(Color.WHITE, rng.randf() * 0.5))
	mb("Head").add_cone(beak, Transform3D(Basis(Vector3.RIGHT, -PI * 0.5 - 0.5), Vector3(0, -hd.y * 0.1, -hd.z * 0.95)), hd.x * 0.45, 0.42, 5)


func _hp_base() -> float:
	return 1700.0


func _speed() -> float:
	return 3.8


func trophy(_t: int) -> ItemData:
	return null


func _table() -> Dictionary:
	var sea := Color(0.55, 0.85, 0.95)
	return {
		"spouts": {"phase": 2, "max": 14.0, "cd": [9.0, 12.0], "tell": 1.0, "shape": "spots", "n": 5, "r": 2.4, "dmg": 18.0, "kb": 8.0, "rec": 1.2,
			"fx": "sparkle", "col": sea, "say": ["bellow", 0.7], "pose": [{"rear": 0.9, "head": 0.5, "jaw": 1.0}, {"head": -0.2, "crouch": 0.5}, {}]},
		"wash": {"max": 5.0, "cd": [6.0, 8.0], "tell": 0.7, "shape": "ring", "r": 5.0, "dmg": 16.0, "kb": 10.0, "rec": 1.0,
			"fx": "sparkle", "col": sea, "say": ["bellow", 1.0], "pose": [{"crouch": 0.4, "head": -0.2}, {"rear": 0.25}, {"crouch": 0.2}]},
		"snap": {"max": 4.4, "cd": [1.8, 2.6], "tell": 0.55, "shape": "cone", "r": 4.2, "deg": 55.0, "dmg": 22.0, "kb": 7.0, "parry": true, "rec": 0.8,
			"pose": [{"head": 0.3, "jaw": 0.4, "crouch": 0.2}, {"head": -0.3, "jaw": 1.0, "stretch": 0.4}, {"head": -0.1}]},
		"bash": {"min": 6.0, "max": 18.0, "cd": [7.0, 9.0], "tell": 0.9, "shape": "charge", "len": 16.0, "w": 2.0, "speed": 12.0, "dmg": 28.0, "knock": true,
			"rec": 1.6, "say": ["bellow", 0.85], "pose": [{"crouch": 0.6, "head": -0.5}, {"crouch": 0.7, "head": -0.6, "stretch": 0.3}, {"crouch": 0.3}]},
	}


func _on_table_hit(m: String, _e: Dictionary, at: Vector3) -> void:
	if m in ["wash", "spouts"]:
		Net.fx("splash", [at, 10, 1.4])


func _wake_move() -> String:
	return "wash"
