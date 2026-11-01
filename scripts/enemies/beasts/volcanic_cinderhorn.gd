extends "res://scripts/enemies/beasts/behemoth.gd"
## The Cinderhorn (BeastPool "cinderhorn", a volcanic island's roamer): the behemoth's wandering and temper in a
## great horned lizard-ox, low on thick sprawled legs, its hide black basalt plates with lava glowing in the seams,
## two heavy horns forward and a third on its snout, a spiked club of a tail. It grazes the ash from place to place;
## crowd it or strike it and it turns on you with a bellow.
##   gore      a sweep of the horns in front (parry it: it reels)
##   spit      a gout of magma down a line at you
##   trample   it lowers its horns and runs you down (its one knockdown)
##   eruption  (below half) it rears and slams down: a ring round it and the ground bursting in spots round you


func _init() -> void:
	boss_name = "The Cinderhorn"


func _spec() -> Dictionary:
	return {"hip_h": 1.7, "front_h": 1.75, "len": 3.6, "chest_r": 1.3, "hip_r": 1.2, "neck": Vector3(0, -0.15, -0.65), "head": Vector3(0.78, 0.55, 0.95),
		"snout": 0.55, "tail": 2.6, "tail_r": 0.36, "coat": Color(0.2, 0.18, 0.18), "under": Color(0.5, 0.36, 0.24), "mark": Color(0.08, 0.07, 0.07),
		"tex": "scales", "ears": 0.0, "eye": Color(1.0, 0.55, 0.12), "leg_k": 1.4, "front_k": 1.0, "foot": "claw", "sprawl": 0.4, "bend": 0.7, "gait": "lumber"}


## Horns forward (two heavy and curving, one on the snout), a bony brow; basalt plates down the back with lava glowing
## between them; a spiked club at the tail's end.
func _extras() -> void:
	var hd: Vector3 = spec["head"]
	var cr: float = spec["chest_r"]
	var hr: float = spec["hip_r"]
	var ln: float = spec["len"]
	var lift: float = float(spec["front_h"]) - float(spec["hip_h"])
	var horn := PSXMat.lit("metal", Color(0.16, 0.13, 0.15))
	var plate := PSXMat.lit("volcanic_basalt", Color(0.85, 0.8, 0.78), {"affine": 0.6})
	var lava := PSXMat.glow(Color(1.0, 0.45, 0.12), 2.6)
	var rng := _rng_fixed()
	for s in [-1.0, 1.0]:
		var h0 := Vector3(s * hd.x * 0.55, hd.y * 0.45, -hd.z * 0.2)
		mb("Head").add_tube(horn, PackedVector3Array([h0, h0 + Vector3(s * 0.5, 0.25, -0.5), h0 + Vector3(s * 0.55, 0.15, -1.3), h0 + Vector3(s * 0.25, 0.4, -1.9)]), 0.22, 0.03, 6, 1.0)
	mb("Head").add_cone(horn, Transform3D(Basis(Vector3.RIGHT, -0.5), Vector3(0, hd.y * 0.2, -hd.z * 1.15)), 0.14, 0.55, 5)
	mb("Head").add_blob(plate, Transform3D(Basis(), Vector3(0, hd.y * 0.62, -hd.z * 0.1)), Vector3(hd.x * 0.85, hd.y * 0.25, hd.z * 0.5), rng, 0.2, 3, 6, 0.6)
	for k in range(9):
		var f := float(k) / 8.0
		var z: float = lerpf(-ln * 0.55, ln * 0.5, f)
		var y: float = lerpf(lift + cr * 0.95, hr * 0.92, f)
		var s := lerpf(0.7, 0.5, f)
		mb("Body").add_blob(plate, Transform3D(Basis(Vector3.RIGHT, 0.3), Vector3(rng.randf_range(-0.15, 0.15), y, z)), Vector3(s, 0.22, s * 0.6), rng, 0.25, 3, 6, 0.6)
		mb("Body").add_box(lava, Transform3D(Basis(), Vector3(0, y - 0.05, z + s * 0.45)), Vector3(s * 1.1, 0.08, 0.1))
		for side in [-1.0, 1.0]:
			if k % 2 == 0:
				mb("Body").add_blob(plate, Transform3D(Basis(Vector3.FORWARD, side * 0.6), Vector3(side * lerpf(cr, hr, f) * 0.85, y - 0.45, z)), Vector3(0.4, 0.3, 0.35), rng, 0.25, 3, 5, 0.6)
	var tail_end := Vector3(0, -0.2, ln * 0.5 + float(spec["tail"]))
	mb("Body").add_blob(plate, Transform3D(Basis(), tail_end), Vector3(0.45, 0.35, 0.5), rng, 0.3, 3, 6, 0.6)
	for k in range(5):
		var a := TAU * k / 5.0
		mb("Body").add_cone(horn, Transform3D(Basis(Vector3.FORWARD, a) * Basis(Vector3.RIGHT, PI * 0.5), tail_end + Vector3(cos(a), sin(a), 0) * 0.35), 0.08, 0.35, 4)


func _coat_at(p: Vector3) -> Color:
	return (spec["coat"] as Color).lerp(spec["under"], smoothstep(-0.2, -0.75, p.y / maxf(float(spec["chest_r"]), 0.1)))


func _table() -> Dictionary:
	var fire := Color(1.0, 0.45, 0.12)
	return {
		"gore": {"max": 5.0, "cd": [2.0, 3.0], "tell": 0.6, "shape": "cone", "r": 5.2, "deg": 100.0, "dmg": 20.0, "kb": 9.0, "parry": true, "rec": 0.8,
			"pose": [{"head": -0.45, "crouch": 0.15}, {"head": 0.45}, {"head": -0.1}]},
		"spit": {"min": 4.0, "max": 15.0, "cd": [5.0, 7.0], "tell": 0.7, "shape": "lane", "len": 15.0, "w": 1.0, "dmg": 16.0, "kb": 5.0, "rec": 0.9,
			"fx": "sparkle", "col": fire, "say": ["bellow", 1.1], "pose": [{"head": 0.35, "jaw": 0.3}, {"head": -0.2, "jaw": 1.0}, {}]},
		"trample": {"min": 6.0, "max": 20.0, "cd": [7.0, 9.0], "tell": 0.9, "shape": "charge", "len": 18.0, "w": 2.0, "speed": 12.5, "dmg": 30.0, "knock": true,
			"rec": 1.6, "say": ["bellow", 0.8], "pose": [{"rear": 0.6, "head": 0.4}, {"head": -0.3, "stretch": 0.4}, {"crouch": 0.4, "head": -0.3}]},
		"eruption": {"phase": 2, "max": 12.0, "cd": [10.0, 13.0], "tell": 1.1, "shape": "spots", "n": 5, "r": 2.2, "dmg": 18.0, "kb": 8.0, "rec": 1.2,
			"fx": "quake", "col": fire, "say": ["bellow", 0.7], "pose": [{"rear": 0.9, "head": 0.5, "jaw": 1.0}, {"head": -0.2}, {}]},
	}


func _on_table_hit(m: String, _e: Dictionary, at: Vector3) -> void:
	if m in ["spit", "eruption"]:
		Net.fx("embers", [at, Vector3.UP, 16])
		Net.fx("sfx", ["fire_burst", at, -2.0, 0.1])


func _wake_move() -> String:
	return "gore"
