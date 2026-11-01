extends "res://scripts/enemies/beasts/moss_golem.gd"
## The obsidian golem (BeastPool "obsidian_golem", a volcanic island's miniboss at its ruins): the old town's stones
## woken under the ash, a four-legged heap of basalt bound together by black glass, shards of obsidian jutting from its
## back, lava glowing in its joints and its two eye-pits. Name and health over its head; back to its ruins, healed,
## once everyone's gone.
##   slam     a swing of its slab of a head in front (parry it: it reels)
##   shards   obsidian bursts up out of the ground under you, in spots
##   roll     it tucks in and grinds down a line at you
##   rupture  (below half) it drives its forelegs down: a ring of shattered glass round it (jump it; its one knockdown)


func _init() -> void:
	boss_name = "The Obsidian Golem"
	wake_r = 16.0
	leash_r = 36.0


func _spec() -> Dictionary:
	return {"hip_h": 1.35, "len": 1.8, "chest_r": 1.0, "hip_r": 0.84, "neck": Vector3(0, -0.05, -0.4), "head": Vector3(0.58, 0.44, 0.52),
		"snout": 0.2, "tail": 0.3, "tail_r": 0.2, "coat": Color(0.3, 0.29, 0.3), "under": Color(0.2, 0.19, 0.2), "mark": Color(0.1, 0.08, 0.12),
		"tex": "volcanic_basalt", "ears": 0.0, "eye": Color(1.0, 0.5, 0.12)}


## Basalt boulders on its back, black glass shards jutting from them, lava in the seams.
func _extras() -> void:
	var cr: float = spec["chest_r"]
	var ln: float = spec["len"]
	var rock := PSXMat.lit("volcanic_basalt", Color.WHITE, {"affine": 0.6})
	var glass := PSXMat.lit("metal", Color(0.14, 0.1, 0.18))
	var lava := PSXMat.glow(Color(1.0, 0.42, 0.1), 2.4)
	var rng := _rng_fixed()
	for k in range(6):
		var z := -ln * 0.55 + k * ln * 0.22
		var s := rng.randf_range(0.5, 0.75)
		mb("Body").add_blob(rock, Transform3D(Basis(Vector3.UP, rng.randf() * TAU), Vector3(rng.randf_range(-0.3, 0.3), cr * 0.85, z)), Vector3(s, s * 0.7, s), rng, 0.25, 3, 6, 0.5)
		mb("Body").add_box(lava, Transform3D(Basis(Vector3.UP, rng.randf() * TAU), Vector3(0, cr * 0.8, z + s * 0.5)), Vector3(s * 0.9, 0.08, 0.08))
		for j in range(rng.randi_range(1, 3)):
			var tilt := Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, rng.randf_range(0.1, 0.7))
			mb("Body").add_cylinder(glass, Transform3D(tilt, Vector3(rng.randf_range(-0.4, 0.4), cr * 0.85 + s * 0.5, z)), rng.randf_range(0.1, 0.2), 0.0, rng.randf_range(0.6, 1.2), 4, 1.0)
	for s in [-1.0, 1.0]:
		mb("Body").add_box(lava, Transform3D(Basis(), Vector3(s * cr * 0.95, cr * 0.1, 0)), Vector3(0.06, 0.08, ln * 0.7))


func _hp_base() -> float:
	return 680.0


func _table() -> Dictionary:
	var fire := Color(1.0, 0.45, 0.12)
	return {
		"slam": {"max": 4.0, "cd": [2.0, 3.0], "tell": 0.7, "shape": "cone", "r": 4.0, "deg": 80.0, "dmg": 18.0, "kb": 8.0, "parry": true, "rec": 0.9,
			"pose": [{"head": 0.5, "crouch": 0.1}, {"head": -0.6}, {"head": -0.2}]},
		"shards": {"min": 3.0, "max": 13.0, "cd": [5.0, 7.0], "tell": 0.9, "shape": "spots", "n": 3, "r": 1.8, "dmg": 16.0, "kb": 7.0, "rec": 0.9,
			"fx": "sparkle", "col": Color(0.7, 0.5, 1.0), "say": ["bellow", 1.2], "pose": [{"crouch": 0.4, "head": -0.3}, {"rear": 0.3}, {}]},
		"roll": {"min": 5.0, "max": 16.0, "cd": [6.0, 8.0], "tell": 0.8, "shape": "charge", "len": 14.0, "w": 1.6, "speed": 11.0, "dmg": 20.0, "kb": 9.0,
			"rec": 1.2, "pose": [{"crouch": 0.5, "head": -0.5}, {"head": -0.4, "stretch": 0.3}, {"crouch": 0.3}]},
		"rupture": {"phase": 2, "max": 6.0, "cd": [8.0, 10.0], "tell": 1.0, "shape": "ring", "r": 5.2, "dmg": 22.0, "knock": true, "rec": 1.3,
			"fx": "quake", "col": fire, "say": ["bellow", 0.8], "pose": [{"rear": 0.9, "head": 0.3}, {"head": -0.3}, {}]},
	}


func _on_table_hit(m: String, _e: Dictionary, at: Vector3) -> void:
	if m == "rupture":
		Net.fx("embers", [at, Vector3.UP, 14])


func _wake_move() -> String:
	return "slam"
