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


func _spec() -> Dictionary:
	return {"hip_h": 2.3, "len": 3.2, "chest_r": 1.45, "hip_r": 1.25, "neck": Vector3(0, -0.1, -0.7), "head": Vector3(0.8, 0.7, 0.9),
		"snout": 0.55, "tail": 1.6, "tail_r": 0.2, "coat": Color(0.42, 0.42, 0.35), "under": Color(0.56, 0.53, 0.44), "mark": Color(0.24, 0.34, 0.16),
		"tex": "leather", "ears": 0.35, "eye": Color(1.0, 0.6, 0.2)}


func _extras() -> void:
	var hd: Vector3 = spec["head"]
	var horn := PSXMat.flat(Color(0.82, 0.76, 0.62))
	for s in [-1.0, 1.0]:
		var h0 := Vector3(s * hd.x * 0.55, hd.y * 0.45, -hd.z * 0.4)
		mb("Head").add_tube(horn, PackedVector3Array([h0, h0 + Vector3(s * 0.5, 0.35, -0.4), h0 + Vector3(s * 0.45, 0.95, -1.1)]), 0.22, 0.02, 6, 1.0)
	mb("Head").add_cylinder(horn, Transform3D(Basis(Vector3.RIGHT, -0.5), Vector3(0, hd.y * 0.2, -hd.z * 1.4)), 0.16, 0.0, 0.6, 5, 1.0)
	# thorn plates down the spine, moss between them
	var cr: float = spec["chest_r"]
	var ln: float = spec["len"]
	var plate := PSXMat.lit("rock", Color(0.8, 0.82, 0.7))
	for k in range(8):
		var z := -ln * 0.55 + k * ln * 0.16
		var y := cr * (0.95 - absf(k - 3.5) * 0.04)
		mb("Body").add_cylinder(plate, Transform3D(Basis(Vector3.RIGHT, 0.35), Vector3(0, y, z)), 0.32 - absf(k - 3.5) * 0.02, 0.0, 0.9 - absf(k - 3.5) * 0.08, 4, 1.0)
		mb("Body").add_blob(spec["coat_mat"], Transform3D(Basis(), Vector3(0.2 * (1.0 if k % 2 == 0 else -1.0), y - 0.1, z + 0.2)), Vector3(0.35, 0.18, 0.3), _rng_fixed(), 0.3, 3, 5, 1.0, Color(0.6, 0.9, 0.5))


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
