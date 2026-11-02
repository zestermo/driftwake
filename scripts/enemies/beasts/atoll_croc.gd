extends "res://scripts/enemies/beasts/alpha_boar.gd"
## The saltwater croc (BeastPool "salt_croc", a coral atoll's miniboss at its lair): an old crocodile as long as a canoe
## that hauls out on the far islet, armoured in ridged scutes, a jaw full of teeth and a tail that could fell a palm.
## Name and health over its head; back to its wallow, healed, once everyone's gone.
##   bite     a snap of the jaws in front (parry it: it reels)
##   tail     a sweep of the tail behind it
##   lunge    it explodes forward down a line at you (its one knockdown)
##   roll     (below half) it thrashes in a death roll: a ring round it


func _init() -> void:
	boss_name = "Old Saltjaw"
	wake_r = 18.0
	leash_r = 40.0


func _spec() -> Dictionary:
	return {"hip_h": 0.72, "front_h": 0.68, "len": 3.4, "chest_r": 0.72, "hip_r": 0.66, "neck": Vector3(0, 0.05, -0.55), "head": Vector3(0.42, 0.28, 0.6),
		"snout": 1.25, "tail": 3.8, "tail_r": 0.48, "coat": Color(0.3, 0.33, 0.22), "under": Color(0.82, 0.78, 0.6), "mark": Color(0.16, 0.18, 0.12),
		"tex": "scales", "ears": 0.0, "eye": Color(0.95, 0.8, 0.2), "leg_k": 1.1, "foot": "claw", "sprawl": 1.0, "bend": 1.2}


## Ridged scutes down the back and tail, teeth along the jaw.
func _extras() -> void:
	var hd: Vector3 = spec["head"]
	var sn: float = spec["snout"]
	var cr: float = spec["chest_r"]
	var ln: float = spec["len"]
	var scute := PSXMat.lit("scales", Color(0.24, 0.26, 0.18))
	var ivory := PSXMat.flat(Color(0.95, 0.93, 0.84))
	for k in range(9):
		var z := -ln * 0.5 + k * ln * 0.12
		for s in [-1.0, 1.0]:
			mb("Body").add_box(scute, Transform3D(Basis(), Vector3(s * cr * 0.28, cr * 0.92, z)), Vector3(0.12, 0.16, 0.22))
	for i in range(4):
		mb("Tail%d" % i).add_box(scute, Transform3D(Basis(), Vector3(0, float(spec["tail_r"]) * (0.95 - i * 0.15), 0.3)), Vector3(0.1, 0.16, 0.5))
	for s in [-1.0, 1.0]:
		for k in range(6):
			var z := -hd.z * 0.4 - sn * (0.1 + k * 0.14)
			mb("Head").add_cylinder(ivory, Transform3D(Basis(Vector3.RIGHT, PI), Vector3(s * hd.x * 0.42, -hd.y * 0.2, z)), 0.03, 0.0, 0.12, 4, 1.0, Color.WHITE, false, false, false)


func _hp_base() -> float:
	return 1100.0


func _speed() -> float:
	return 5.0


func _table() -> Dictionary:
	var sea := Color(0.55, 0.85, 0.95)
	return {
		"roll": {"phase": 2, "max": 4.5, "cd": [8.0, 10.0], "tell": 0.8, "shape": "ring", "r": 4.2, "dmg": 20.0, "kb": 9.0, "rec": 1.2, "fx": "sparkle", "col": sea,
			"say": ["hiss", 0.6], "pose": [{"crouch": 0.6, "head": -0.3}, {"crouch": 0.8, "spin": 1.0}, {"crouch": 0.3}]},
		"bite": {"max": 3.8, "cd": [1.6, 2.4], "tell": 0.5, "shape": "cone", "r": 3.6, "deg": 50.0, "dmg": 18.0, "kb": 6.0, "parry": true, "rec": 0.6,
			"pose": [{"head": 0.35, "jaw": 0.8, "crouch": 0.2}, {"head": -0.2, "jaw": 0.0, "stretch": 0.4}, {}]},
		"tail": {"max": 5.0, "cd": [3.0, 4.0], "tell": 0.5, "shape": "behind", "r": 5.0, "deg": 140.0, "dmg": 16.0, "kb": 9.0, "rec": 0.7,
			"pose": [{"tail": 1.0, "crouch": 0.3}, {"tail": 0.0}, {}]},
		"lunge": {"min": 4.0, "max": 12.0, "cd": [5.0, 7.0], "tell": 0.7, "shape": "charge", "len": 10.0, "w": 1.4, "speed": 16.0, "dmg": 24.0, "knock": true,
			"rec": 1.3, "say": ["hiss", 0.8], "pose": [{"crouch": 0.7, "head": 0.2, "jaw": 0.6}, {"stretch": 0.6, "jaw": 1.0}, {"crouch": 0.3}]},
	}


func _wake_move() -> String:
	return "lunge"
