extends "res://scripts/enemies/beasts/frost_alpha.gd"
## The ash hound alpha (BeastPool "ash_alpha", a volcanic island's miniboss at its lair): the leader of the island's
## ash hounds, a lean grey wolf-thing the size of a horse, soot-black about the muzzle, a mane of embers smouldering
## down its neck and back, eyes like coals. Name and health over its head; back to its den, healed, once everyone's gone.
##   bite     a snap of the jaws in front (parry it: it reels)
##   pounce   a leap onto where you stand
##   breath   a gout of cinders down a line at you
##   flare    (below half) its mane flares: a burning ring round it (jump it; its one knockdown)


func _init() -> void:
	boss_name = "Cinderfang"
	wake_r = 18.0
	leash_r = 40.0


func _spec() -> Dictionary:
	return {"hip_h": 1.25, "len": 1.9, "chest_r": 0.6, "hip_r": 0.46, "neck": Vector3(0, 0.25, -0.5), "head": Vector3(0.36, 0.34, 0.44),
		"snout": 0.6, "tail": 1.4, "tail_r": 0.14, "coat": Color(0.4, 0.38, 0.37), "under": Color(0.6, 0.57, 0.54), "mark": Color(0.1, 0.09, 0.09),
		"tex": "fur", "ears": 0.9, "eye": Color(1.0, 0.5, 0.1)}


## Fangs, a mane of smouldering embers down the neck and back.
func _extras() -> void:
	var hd: Vector3 = spec["head"]
	var sn: float = spec["snout"]
	var cr: float = spec["chest_r"]
	var ln: float = spec["len"]
	var ivory := PSXMat.flat(Color(0.95, 0.93, 0.86))
	var ember := PSXMat.glow(Color(1.0, 0.4, 0.08), 2.4)
	var rng := _rng_fixed()
	for s in [-1.0, 1.0]:
		mb("Head").add_cylinder(ivory, Transform3D(Basis(Vector3.RIGHT, PI), Vector3(s * hd.x * 0.25, -hd.y * 0.35, -hd.z * 0.9 - sn * 0.7)), 0.04, 0.0, 0.18, 4, 1.0, Color.WHITE, false, false, false)
	for k in range(10):
		var a := -1.3 + k * 0.29
		mb("Neck").add_blob(spec["coat_mat"], Transform3D(Basis(Vector3.RIGHT, -0.5), Vector3(sin(a) * cr * 0.7, cos(a) * cr * 0.5, -0.05)), Vector3(cr * 0.25, cr * 0.4, cr * 0.25), rng, 0.3, 3, 5, 1.0, Color(0.35, 0.33, 0.32))
		if k % 2 == 0:
			mb("Neck").add_cylinder(ember, Transform3D(Basis(Vector3.RIGHT, 2.6), Vector3(sin(a) * cr * 0.6, cos(a) * cr * 0.6, 0.0)), 0.06, 0.0, 0.35, 4, 1.0, Color.WHITE, false, false, false)
	for k in range(6):
		var z := -ln * 0.45 + k * ln * 0.17
		mb("Body").add_cylinder(ember, Transform3D(Basis(Vector3.RIGHT, 2.3), Vector3(0, cr * 0.9, z)), 0.05, 0.0, 0.3, 4, 1.0, Color.WHITE, false, false, false)


func _table() -> Dictionary:
	var fire := Color(1.0, 0.45, 0.12)
	return {
		"bite": {"max": 3.6, "cd": [1.6, 2.4], "tell": 0.5, "shape": "cone", "r": 3.4, "deg": 60.0, "dmg": 16.0, "kb": 6.0, "parry": true, "rec": 0.6,
			"pose": [{"head": -0.4, "crouch": 0.3, "jaw": 0.4}, {"head": 0.2, "jaw": 1.0, "stretch": 0.3}, {"jaw": 0.0}]},
		"pounce": {"min": 5.0, "max": 13.0, "cd": [5.0, 7.0], "tell": 0.6, "shape": "leap", "r": 3.0, "air": 0.55, "arc": 3.0, "dmg": 18.0, "kb": 8.0, "rec": 0.9,
			"pose": [{"crouch": 0.6, "head": -0.3}, {"stretch": 0.6}, {"crouch": 0.3}]},
		"breath": {"min": 3.0, "max": 12.0, "cd": [6.0, 8.0], "tell": 0.7, "shape": "lane", "len": 12.0, "w": 1.1, "dmg": 14.0, "kb": 4.0, "rec": 0.8,
			"fx": "sparkle", "col": fire, "say": ["snarl", 1.2], "pose": [{"head": 0.4, "jaw": 0.3}, {"head": -0.1, "jaw": 1.0}, {}]},
		"flare": {"phase": 2, "max": 6.0, "cd": [8.0, 10.0], "tell": 0.9, "shape": "ring", "r": 4.6, "dmg": 20.0, "knock": true, "rec": 1.1,
			"fx": "sparkle", "col": fire, "say": ["snarl", 0.8], "pose": [{"rear": 0.8, "head": 0.6, "jaw": 1.0}, {"head": -0.2}, {}]},
	}


func _on_table_hit(m: String, _e: Dictionary, at: Vector3) -> void:
	if m in ["breath", "flare"]:
		Net.fx("embers", [at, Vector3.UP, 12])


func _wake_move() -> String:
	return "pounce"
