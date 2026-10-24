extends "res://scripts/enemies/beasts/behemoth.gd"
## The Dune Strider (BeastPool "dune_strider", a desert island's roamer): a grazer the height of a house on long thin
## legs, lean and fast (docs/v1_20_beasts.md 14: rebuilt on the quadruped rig in 1.20, a camel before) - a long upright
## neck with a short dark crest, a long narrow head with tall ears, dun hide striped dark down the legs, a thin tufted
## tail, rags of an old caravan's tack still hanging off it. It wanders from one place to the next; crowd it or strike
## it and it turns on you.


func _init() -> void:
	boss_name = "The Dune Strider"


func _spec() -> Dictionary:
	return {"hip_h": 2.9, "front_h": 3.15, "len": 2.6, "chest_r": 0.95, "hip_r": 0.78, "neck": Vector3(0, 1.55, -0.85), "head": Vector3(0.34, 0.4, 0.6),
		"snout": 0.7, "tail": 1.4, "tail_r": 0.07, "coat": Color(0.88, 0.6, 0.3), "under": Color(0.96, 0.84, 0.62), "mark": Color(0.36, 0.24, 0.14),
		"tex": "fur", "ears": 1.0, "eye": Color(1.0, 0.65, 0.25), "leg_k": 0.72, "foot": "hoof", "tail_kind": "tuft", "gait": "trot"}


## A short dark crest down the neck, a pale muzzle, a ragged old saddle cloth and a rope hanging off it.
func _extras() -> void:
	var cr: float = spec["chest_r"]
	var ln: float = spec["len"]
	var hd: Vector3 = spec["head"]
	var sn: float = spec["snout"]
	var nk: Vector3 = spec["neck"]
	var lift: float = float(spec["front_h"]) - float(spec["hip_h"])
	var rng := _rng_fixed()
	var dark := PSXMat.lit("fur", spec["mark"])
	for k in range(9):
		var f := float(k) / 8.0
		var at: Vector3 = Vector3(0, -cr * 0.1, cr * 0.25).lerp(nk, f) + Vector3(0, 0.22, 0.12)
		mb("Neck").add_blob(dark, Transform3D(Basis(), at), Vector3(0.08, 0.2, 0.18), rng, 0.3, 3, 5, 1.0)
	mb("Head").add_blob(spec["coat_mat"], Transform3D(Basis(), Vector3(0, -hd.y * 0.2, -hd.z * 0.9 - sn * 0.75)), Vector3(hd.x * 0.62, hd.y * 0.38, sn * 0.35), rng, 0.06, 3, 6, 1.0, Color(1.12, 1.12, 1.12))
	var cloth := PSXMat.lit("rug_kilim", Color(0.85, 0.8, 0.75))
	mb("Body").add_box(cloth, Transform3D(Basis(), Vector3(0, cr * 0.95 + lift * 0.3, -ln * 0.05)), Vector3(cr * 2.2, 0.05, ln * 0.32), 1.0, Color.WHITE, false)
	for s in [-1.0, 1.0]:
		mb("Body").add_box(cloth, Transform3D(Basis(Vector3.BACK, s * 1.35), Vector3(s * cr * 1.02, cr * 0.42 + lift * 0.3, -ln * 0.05)), Vector3(cr * 0.85, 0.05, ln * 0.32), 1.0, Color(0.85, 0.85, 0.85), false)
	mb("Body").add_tube(PSXMat.lit("rope"), MeshBuilder.curve_points(Vector3(cr * 1.0, cr * 0.4, -ln * 0.1), Vector3(cr * 1.2, -cr * 0.5, 0.0), Vector3(cr * 1.0, -cr * 0.9, ln * 0.15), 5), 0.05, 0.05, 4, 1.0)


## Dun over a pale belly; dark stripes across the legs (low down: their parts' own space runs downward).
func _coat_at(p: Vector3) -> Color:
	var base := (spec["coat"] as Color).lerp(spec["under"], smoothstep(-0.2, -0.7, p.y / maxf(float(spec["chest_r"]), 0.1)))
	if p.y < -0.25:
		var band := smoothstep(0.55, 0.75, sin(p.y * 9.0) * 0.5 + 0.5)
		base = base.lerp(spec["mark"], band * 0.8)
	return base


# 1.20's moves (docs/v1_20_beasts.md 14), as a table: a kicker, its one knockdown the kick behind.
func _table() -> Dictionary:
	return {
		"kick": {"max": 4.5, "cd": [3.0, 4.0], "tell": 0.6, "shape": "behind", "r": 4.5, "deg": 90.0, "dmg": 24.0, "knock": true, "rec": 1.2,
			"pose": [{"crouch": 0.3, "head": -0.3}, {"rear": -0.4, "head": 0.2}, {"crouch": 0.2}]},
		"stamp": {"max": 4.5, "cd": [2.0, 3.0], "tell": 0.6, "shape": "ring", "at": 2.0, "r": 2.8, "dmg": 18.0, "kb": 7.0, "parry": true, "rec": 0.8,
			"pose": [{"rear": 1.0, "head": 0.4}, {"rear": 0.0, "head": -0.2}, {}]},
		"spit": {"min": 5.0, "max": 14.0, "cd": [6.0, 8.0], "tell": 0.5, "shape": "lane", "len": 14.0, "w": 0.6, "dmg": 8.0, "kb": 2.0, "stun": 1.0, "rec": 0.6,
			"fx": "sparkle", "col": Color(0.85, 0.8, 0.5), "pose": [{"head": 0.5, "jaw": 0.4}, {"head": -0.2, "jaw": 1.0}, {}]},
		"sprint": {"min": 0.0, "max": 24.0, "cd": [7.0, 9.0], "tell": 1.7, "shape": "charge", "len": 22.0, "w": 1.4, "speed": 18.0, "dmg": 18.0, "kb": 11.0,
			"rec": 1.2, "pose": [{"crouch": 0.3, "head": -0.2}, {"head": -0.2, "stretch": 0.6}, {"crouch": 0.3}]},
	}


func _wake_move() -> String:
	return "stamp"


## The sprint: it turns away and runs off (1 s), then wheels round and comes back at you down a fresh lane.
func _table_tick(m: String, _e: Dictionary, p: Node3D) -> Vector3:
	if m != "sprint" or p == null:
		return Vector3.INF
	if mv_t < 1.0:
		var away := _flat(global_position - p.global_position).normalized()
		if away.length() < 0.1:
			away = -_fwd()
		_face(away)
		return away * 14.0
	if _n == 0:
		_n = -1
		_from = global_position
		var d := _flat(p.global_position - global_position).normalized()
		_face(d)
		_to = ground_at(global_position + d * 22.0)
		warn_lane(_from, _to, 2.8, 0.7)
	if _n == -1 and mv_t >= 1.7:
		_n = 0
	return Vector3.INF
