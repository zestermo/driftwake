extends "res://scripts/enemies/beasts/alpha_boar.gd"
## The roaming beast (BeastPool "behemoth", one per island): a moss-backed grazer
## the size of a hut, thorny plates down its spine and two horns forward. It
## wanders the island's floor from one place to the next (sites, its range's
## middle) and can be met anywhere; come close or strike it and it turns on you:
## the boar's charge, horn toss and stomp, slower and far heavier, a bellow
## before each. Leave it be (or get far enough away) and it goes back to grazing.

var waypoints: Array = []
var _wp: int = 0
var _graze_t: float = 0.0
var _stuck: float = 0.0


func _init() -> void:
	boss_name = "The Thornback"
	wake_r = 18.0
	leash_r = 46.0
	charge_len = 18.0
	charge_speed = 14.0
	gore_r = 4.2
	stomp_r = 6.0


## (1.20: rebuilt on the quadruped rig, docs/v1_20_beasts.md 5: low and wide on short pillar legs, the head carried
## low with its horns forward, armour plates down the back each with a thorn, a pale soft belly, a club on its tail)
func _spec() -> Dictionary:
	return {"hip_h": 1.95, "front_h": 1.8, "len": 3.6, "chest_r": 1.4, "hip_r": 1.35, "neck": Vector3(0, -0.25, -0.65), "head": Vector3(0.8, 0.62, 0.95),
		"snout": 0.6, "tail": 2.2, "tail_r": 0.3, "coat": Color(0.42, 0.42, 0.35), "under": Color(0.72, 0.66, 0.54), "mark": Color(0.24, 0.34, 0.16),
		"tex": "leather", "ears": 0.25, "eye": Color(1.0, 0.6, 0.2), "leg_k": 1.6, "front_k": 1.1, "foot": "pad", "bend": 0.6, "gait": "lumber"}


## Horns forward (two sweeping and one on the nose), a bony brow; armour plates overlapping down the back and flanks,
## each with a thorn, moss between them; a spiked club at the tail's end.
func _extras() -> void:
	var hd: Vector3 = spec["head"]
	var cr: float = spec["chest_r"]
	var hr: float = spec["hip_r"]
	var ln: float = spec["len"]
	var lift: float = float(spec["front_h"]) - float(spec["hip_h"])
	var rng := _rng_fixed()
	var horn := PSXMat.flat(Color(0.82, 0.76, 0.62))
	var plate := PSXMat.lit("rock", Color(0.8, 0.82, 0.7))
	for s in [-1.0, 1.0]:
		var h0 := Vector3(s * hd.x * 0.55, hd.y * 0.45, -hd.z * 0.4)
		mb("Head").add_tube(horn, PackedVector3Array([h0, h0 + Vector3(s * 0.5, 0.2, -0.5), h0 + Vector3(s * 0.4, 0.55, -1.3)]), 0.22, 0.02, 6, 1.0)
	mb("Head").add_cylinder(horn, Transform3D(Basis(Vector3.RIGHT, -0.5), Vector3(0, hd.y * 0.2, -hd.z * 1.4)), 0.2, 0.0, 0.8, 5, 1.0)
	mb("Head").add_blob(plate, Transform3D(Basis(), Vector3(0, hd.y * 0.55, -hd.z * 0.2)), Vector3(hd.x * 0.9, hd.y * 0.3, hd.z * 0.6), rng, 0.15, 3, 6, 1.0)
	# the plates: three rows down the back (the middle over the spine, two lower on the flanks), each with a thorn
	for row in [0.0, -1.0, 1.0]:
		for k in range(7):
			var f := float(k) / 6.0
			var z: float = lerpf(-ln * 0.55, ln * 0.5, f)
			var w: float = lerpf(cr, hr, f)
			var top: float = lerpf(lift + cr * 0.95, hr * 0.95, f)
			var at := Vector3(row * w * 0.62, top - absf(row) * w * 0.3, z)
			var tilt := Basis(Vector3.FORWARD, -row * 0.6) * Basis(Vector3.RIGHT, 0.2)
			mb("Body").add_blob(plate, Transform3D(tilt, at), Vector3(w * 0.42, 0.16, ln * 0.09), rng, 0.15, 3, 6, 1.0)
			var spike: float = (0.75 if row == 0.0 else 0.45) * (1.0 - absf(f - 0.4) * 0.6)
			mb("Body").add_cylinder(horn, Transform3D(tilt * Basis(Vector3.RIGHT, 0.3), at + tilt * Vector3(0, 0.1, 0)), 0.18, 0.0, spike, 4, 1.0, Color(0.9, 0.9, 0.85))
			if row == 0.0 and k < 6:
				mb("Body").add_blob(spec["coat_mat"], Transform3D(Basis(), at + Vector3(0.3, -0.08, ln * 0.07)), Vector3(0.3, 0.15, 0.25), rng, 0.3, 3, 5, 1.0, Color(0.6, 0.9, 0.5))
	# the tail's club: a knot of plate with spikes
	var tl: float = float(spec["tail"]) / 4.0
	mb("Tail3").add_blob(plate, Transform3D(Basis(), Vector3(0, 0, tl * 0.9)), Vector3(0.55, 0.42, 0.6), rng, 0.2, 3, 6, 1.0)
	for k in range(5):
		var a := TAU * k / 5.0
		mb("Tail3").add_cylinder(horn, Transform3D(Basis(Vector3.BACK, a) * Basis(Vector3.RIGHT, 0.0), Vector3(0, 0, tl * 0.9) + Vector3(cos(a), sin(a), 0) * 0.35), 0.1, 0.0, 0.4, 4, 1.0)


func _coat_at(p: Vector3) -> Color:
	var base := (spec["coat"] as Color).lerp(spec["under"], smoothstep(-0.2, -0.6, p.y / maxf(float(spec["chest_r"]), 0.1)))
	var moss := smoothstep(0.55, 0.85, sin(p.x * 3.0 + p.z * 1.7) * 0.5 + 0.5) * smoothstep(0.3, 0.8, p.y / maxf(float(spec["chest_r"]), 0.1))
	return base.lerp(spec["mark"], moss)


func _hp_base() -> float:
	return 1800.0


func _poise_max() -> float:
	return 300.0


func _xp_base() -> int:
	return 500


func _coins_base() -> int:
	return 30


func _speed() -> float:
	return 4.4


func _charge_dmg() -> float:
	return 30.0


func _gore_dmg() -> float:
	return 22.0


func _stomp_dmg() -> float:
	return 24.0


func _wake_move() -> String:
	return "stomp"


func _on_begin(m: String) -> void:
	super._on_begin(m)
	say("bellow", global_position, 6.0, 1.0 if m != "charge" else 0.9, 110.0)


func trophy(_t: int) -> ItemData:
	return null


## Grazing its way round the island: walk to a waypoint, browse a while, on to the next.
func _idle(delta: float) -> Vector3:
	if waypoints.is_empty():
		return super._idle(delta)
	if _graze_t > 0.0:
		_graze_t -= delta
		return Vector3.ZERO
	var goal: Vector3 = waypoints[_wp]
	var to := _flat(goal - global_position)
	if to.length() < 3.0:
		_wp = (_wp + 1 + _rng.randi() % maxi(waypoints.size() - 1, 1)) % waypoints.size()
		_graze_t = _rng.randf_range(6.0, 14.0)
		return Vector3.ZERO
	var nd := _nav_dir(goal, delta)
	_face(nd)
	# (walked into a trunk off the navmesh: on to another place)
	_stuck = _stuck + delta if _flat(get_real_velocity()).length() < 0.4 else 0.0
	if _stuck > 2.5:
		_stuck = 0.0
		_wp = (_wp + 1) % waypoints.size()
	# (where it settles after a fight is wherever it was grazing)
	post = global_position
	post_yaw = _yaw
	return nd * 1.6


func _pose_for(delta: float) -> void:
	super._pose_for(delta)
	if state == S.SLEEP:
		pose = {"head": -0.6 if _graze_t > 0.0 else -0.15}
