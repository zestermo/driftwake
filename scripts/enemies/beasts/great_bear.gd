extends "res://scripts/enemies/beasts/alpha_boar.gd"
## The Bear King (BeastPool "great_bear", a snow island's boss): a white bear the size of
## a cabin, a shaggy hump over its shoulders, claws like sickles. The alpha boar's brain
## at a boss's scale: it rears and drops into a lope down a line (the charge), swats with a
## forepaw in front (parry it: it reels), and from half health rears up tall and slams down
## both paws, a ring of snow round it (jump it). Its arena's banner calls it; no bar over
## its head (the arena's). Looks: white, cream, old grey.

const BEAR_COATS := [
	[Color(0.9, 0.9, 0.88), Color(0.97, 0.97, 0.95), Color(0.72, 0.72, 0.7)],
	[Color(0.88, 0.82, 0.66), Color(0.95, 0.92, 0.82), Color(0.7, 0.62, 0.48)],
	[Color(0.66, 0.67, 0.68), Color(0.84, 0.84, 0.84), Color(0.46, 0.46, 0.48)],
]


func _init() -> void:
	boss_name = "The Bear King"
	wake_r = 0.0
	charge_len = 16.0
	charge_speed = 13.0
	gore_r = 4.0
	stomp_r = 6.5


## (1.20: rebuilt on the quadruped rig's new keys, docs/v1_20_beasts.md 7: high humped shoulders over thick forelegs,
## broad pads, the head carried low, a stub tail, a heavy lumbering walk)
func _spec() -> Dictionary:
	var c: Array = BEAR_COATS[variant % BEAR_COATS.size()]
	return {"hip_h": 1.6, "front_h": 1.95, "len": 2.8, "chest_r": 0.95, "hip_r": 0.8, "neck": Vector3(0, -0.15, -0.7), "head": Vector3(0.55, 0.47, 0.55),
		"snout": 0.42, "tail": 0.32, "tail_r": 0.16, "coat": c[0], "under": c[1], "mark": c[2], "tex": "fur_white", "ears": 0.0,
		"eye": Color(0.3, 0.75, 1.0), "hump": 1.0, "leg_k": 1.25, "front_k": 1.15, "foot": "pad", "tail_kind": "stub", "gait": "lumber", "bend": 1.7}


## A shaggy hump and ruff, a brow, small round ears, a black nose and lip, a fringe of fur under the belly,
## black sickle claws on every pad.
func _extras() -> void:
	var hd: Vector3 = spec["head"]
	var sn: float = spec["snout"]
	var cr: float = spec["chest_r"]
	var hr: float = spec["hip_r"]
	var ln: float = spec["len"]
	var hh: float = spec["hip_h"]
	var lift: float = float(spec["front_h"]) - hh
	var coat: Material = spec["coat_mat"]
	var black := PSXMat.flat(Color(0.06, 0.05, 0.05))
	# the face: a black nose and lip, a brow ridge over the eyes, small round ears
	mb("Head").add_box(black, Transform3D(Basis(), Vector3(0, -hd.y * 0.12, -hd.z * 0.95 - sn * 0.95)), Vector3(0.26, 0.16, 0.1), 1.0)
	mb("Jaw").add_box(black, Transform3D(Basis(), Vector3(0, -hd.y * 0.1, -hd.z * 0.7 - sn * 0.7)), Vector3(0.2, 0.05, 0.08), 1.0)
	mb("Head").add_blob(coat, Transform3D(Basis(), Vector3(0, hd.y * 0.42, -hd.z * 0.45)), Vector3(hd.x * 0.85, hd.y * 0.28, hd.z * 0.4), _rng_fixed(), 0.12, 3, 6, 1.0, Color(0.92, 0.92, 0.92))
	for s in [-1.0, 1.0]:
		mb("Head").add_blob(coat, Transform3D(Basis(), Vector3(s * hd.x * 0.72, hd.y * 0.72, hd.z * 0.05)), Vector3(hd.x * 0.24, hd.x * 0.24, hd.x * 0.12), _rng_fixed(), 0.05, 3, 6, 1.0, Color(0.8, 0.8, 0.8))
	# the hump over the shoulders and the ruff round the neck
	mb("Chest").add_blob(coat, Transform3D(Basis(), Vector3(0, cr * 0.95, cr * 0.15)), Vector3(cr * 0.75, cr * 0.5, cr * 0.85), _rng_fixed(), 0.22, 3, 7, 1.0, Color(0.96, 0.96, 0.96))
	for k in range(9):
		var a := -1.2 + k * 0.3
		mb("Neck").add_blob(coat, Transform3D(Basis(), Vector3(sin(a) * cr * 0.62, cos(a) * cr * 0.48, -0.1)), Vector3(cr * 0.3, cr * 0.38, cr * 0.32), _rng_fixed(), 0.3, 3, 5, 1.0, Color(0.9, 0.9, 0.9))
	# the belly's fringe: shaggy fur hanging between the legs
	for k in range(6):
		var z := -ln * 0.42 + k * ln * 0.17
		var y := -cr * 0.85 + lift * clampf(0.5 - float(k) / 5.0, 0.0, 0.5)
		mb("Body").add_blob(coat, Transform3D(Basis(Vector3.FORWARD, (k % 2) * 0.3 - 0.15), Vector3(0, y, z)), Vector3(cr * 0.62, cr * 0.22, ln * 0.11), _rng_fixed(), 0.35, 3, 5, 1.0, Color(0.86, 0.86, 0.86))
	# sickle claws on each pad
	for leg in ["FL", "FR", "BL", "BR"]:
		var front: bool = str(leg).begins_with("F")
		var thick: float = (cr if front else hr) * 0.36 * 1.25 * (1.15 if front else 1.0)
		for k in range(4):
			mb(foot_part(leg)).add_cylinder(black, Transform3D(Basis(Vector3.RIGHT, -1.75), Vector3((k - 1.5) * thick * 0.42, foot_y(leg) + thick * 0.22, -thick * 1.75)), thick * 0.1, 0.0, thick * 0.75, 3, 1.0, Color.WHITE, false, false, false)


func _coat_at(p: Vector3) -> Color:
	return (spec["coat"] as Color).lerp(spec["under"], smoothstep(-0.2, -0.6, p.y / maxf(float(spec["chest_r"]), 0.1))).lerp(spec["mark"], smoothstep(0.75, 1.0, p.y / maxf(float(spec["chest_r"]), 0.1)) * 0.3)


func _hp_base() -> float:
	return 1500.0


func _poise_max() -> float:
	return 220.0


func _phase_at() -> Array:
	return [0.6, 0.3]


func _xp_base() -> int:
	return 700


func _coins_base() -> int:
	return 40


func _speed() -> float:
	return 5.4 if phase < 3 else 6.6


func _wake_move() -> String:
	return "slam"


func _ready() -> void:
	super._ready()
	_cd = {"maul": 0.5, "slam": 4.0, "charge": 2.0, "swat": 0.0, "scoop": 99.0, "frenzy": 99.0}
	_overhead.queue_free()
	_overhead = null


func trophy(t: int) -> ItemData:
	return Gear.make("accessory", "cape", {"cape": true, "cape_color": spec["coat"]}, "Bear King's Mantle", t)


# ==========================================================================
# 1.20's moves (docs/v1_20_beasts.md 7), in place of the boar's
#   maul    rears (0.6 s): two downward swipes in front (push); 0.8 s
#   slam    stands tall, roaring (0.9 s): falls forward onto you, 4 m (its one knockdown); 1.6 s getting up
#   charge  head down (0.7 s): a short charge (push); 1.0 s
#   swat    a glance sideways (0.35 s): a fast side paw (stops you flanking it); 0.5 s
#   scoop   (phase 2+) digs at the snow (0.6 s): flings a chunk down a lane; 0.8 s
#   frenzy  (phase 3) foaming: four swipes, a step forward each; 1.6 s winded
# ==========================================================================
const SNOW := Color(0.92, 0.96, 1.0)
const MAUL_R := 3.6
const SLAM_R := 4.0
const SCOOP_LEN := 14.0


func _on_phase(n: int) -> void:
	if n >= 2:
		_cd["scoop"] = 1.0
	if n >= 3:
		_cd["frenzy"] = 1.0
	say("bellow", global_position, 6.0, 0.7)


func _brain(delta: float, p: Node3D, to: Vector3, dist: float) -> Vector3:
	var flank := absf(_fwd().signed_angle_to(to.normalized(), Vector3.UP)) > 1.0
	if dist < MAUL_R and flank:
		var m := pick(["swat"])
		if m != "":
			begin(m)
			return Vector3.ZERO
	_face(to)
	var wants: Array = []
	if phase >= 3 and dist < MAUL_R + 1.0:
		wants.append("frenzy")
	if dist < SLAM_R + 0.5:
		wants.append_array(["slam", "maul"])
	elif dist < SCOOP_LEN:
		if phase >= 2:
			wants.append("scoop")
		if dist > 5.0 and dist < charge_len:
			wants.append("charge")
	var m := pick(wants)
	if m != "":
		begin(m)
		return Vector3.ZERO
	if dist > MAUL_R - 0.5:
		var nd := _nav_dir(p.global_position, delta)
		_face(nd)
		return nd * _speed()
	return Vector3.ZERO


func _parry_ok() -> bool:
	return (move == "maul" and mv_t > 0.45 and mv_t < 0.75) or (move == "swat" and mv_t > 0.2 and mv_t < 0.4)


func _armoured() -> bool:
	return move == "slam" and mv_t < 0.9


func _on_begin(m: String) -> void:
	_n = 0
	var p := _target()
	var at: Vector3 = p.global_position if p else global_position + _fwd() * 4.0
	match m:
		"maul":
			_cd["maul"] = _rng.randf_range(1.6, 2.4)
			say("snarl", global_position, 0.0, 0.7)
		"slam":
			_cd["slam"] = _rng.randf_range(7.0, 9.0)
			warn_ring(global_position + _fwd() * 2.2, SLAM_R, 0.9)
			say("bellow", global_position, 6.0, 0.65)
		"charge":
			_cd["charge"] = _rng.randf_range(5.0, 7.0)
			_from = global_position
			var d := _flat(at - global_position).normalized()
			_face(d)
			_to = ground_at(global_position + d * minf(charge_len, _flat(at - global_position).length() + 3.0))
			warn_lane(_from, _to, 2.6, 0.7)
		"swat":
			_cd["swat"] = _rng.randf_range(1.5, 2.2)
			_face(_flat(at - global_position))
		"scoop":
			_cd["scoop"] = _rng.randf_range(6.0, 8.0)
			_from = global_position
			_to = ground_at(global_position + _flat(at - global_position).normalized() * SCOOP_LEN)
			warn_lane(_from, _to, 1.4, 0.6, SNOW)
		"frenzy":
			_cd["frenzy"] = _rng.randf_range(10.0, 12.0)
			say("bellow", global_position, 6.0, 0.8)


func _move_tick(_delta: float, p: Node3D) -> Vector3:
	match move:
		"maul":
			if p and mv_t < 0.3:
				_face(_flat(p.global_position - global_position))
			for k in range(2):
				if _n == k and mv_t > 0.6 + k * 0.25:
					_n += 1
					strike("cone", [global_position, _fwd(), MAUL_R, 80.0], 16.0, false, true, 1.1, 7.0)
					Net.fx("sfx", ["whoosh_big", global_position + _fwd(), 0.0, 0.05, 0.85])
			if mv_t > 1.0:
				end_move(0.8)
		"slam":
			if mv_t > 0.9 and not _hit:
				_hit = true
				var at := global_position + _fwd() * 2.2
				strike("ring", [at, SLAM_R], 28.0, true)
				quake(at, 1.1)
				Net.fx("sparkle", [at + Vector3.UP * 0.4, 20, SNOW])
			if mv_t > 1.2:
				end_move(1.6)
			return _fwd() * (3.0 if mv_t > 0.75 and mv_t < 0.95 else 0.0)
		"charge":
			if mv_t < 0.7:
				return Vector3.ZERO
			var d := _flat(_to - _from).normalized()
			if not _hit:
				_hit = true
				strike("lane", [_from, _to, float(spec["chest_r"]) * 1.1 + 0.3], 18.0, false, false, 1.1, 10.0)
			if _flat(_to - global_position).dot(d) < 0.5 or mv_t > 0.7 + charge_len / charge_speed + 0.3:
				end_move(1.0)
				return Vector3.ZERO
			return d * charge_speed
		"swat":
			if mv_t > 0.35 and not _hit:
				_hit = true
				strike("ring", [global_position, MAUL_R * 0.9], 12.0, false, true, 1.0, 9.0)
			if mv_t > 0.55:
				end_move(0.5)
		"scoop":
			if mv_t > 0.6 and not _hit:
				_hit = true
				strike("lane", [_from, _to, 0.8], 14.0, false, false, 1.0, 6.0)
				for k in range(5):
					Net.fx("sparkle", [_from.lerp(_to, (k + 1) / 5.0) + Vector3.UP * 0.8, 6, SNOW])
			if mv_t > 0.8:
				end_move(0.8)
		"frenzy":
			if _n < 4 and mv_t > 0.4 + _n * 0.38:
				_n += 1
				strike("cone", [global_position, _fwd(), MAUL_R, 90.0], 13.0, false, false, 1.0, 6.0)
				Net.fx("sfx", ["whoosh_big", global_position + _fwd(), -2.0, 0.08, 0.95])
			if p and mv_t < 1.8:
				_face(_flat(p.global_position - global_position))
			if mv_t > 2.0:
				end_move(1.6)
			return _fwd() * (2.2 if mv_t < 1.9 else 0.0)
	return Vector3.ZERO


func _pose_for(delta: float) -> void:
	super._pose_for(delta)
	if state != S.FIGHT:
		return
	match move:
		"maul":
			pose = {"rear": 0.9 if mv_t < 0.6 else 0.3 - (mv_t - 0.6), "head": 0.2, "jaw": 0.5}
		"slam":
			pose = {"rear": 1.7, "head": 0.4, "jaw": 0.8} if mv_t < 0.9 else {"crouch": 0.6, "head": -0.3}
		"charge":
			pose = {"crouch": 0.3, "head": -0.35} if mv_t < 0.7 else {"head": -0.3, "stretch": 0.4}
		"swat":
			pose = {"rear": 0.35, "head": 0.1}
		"scoop":
			pose = {"crouch": 0.5, "head": -0.6}
		"frenzy":
			pose = {"rear": 0.5 + sin(mv_t * 16.0) * 0.3, "jaw": 0.9}
	if move == "" and mv_t < 0.0 and _last_move == "slam":
		pose = {"crouch": 0.7, "head": -0.4}
