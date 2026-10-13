extends QuadBeast
## An alpha boar (miniboss, BeastPool "boar"): a bristling old tusker the size of
## a pony that keeps the island's ruins as its wallow (BeastDens). Wakes when a
## captain comes near, its name and health over its head; back to its wallow,
## healed, once everyone's gone.
##   charge  it paws the ground, squealing, a red strip down the line, then runs it
##   gore    a toss of the tusks in front (parry it: it reels)
##   stomp   (below half) up on its hind legs and down: a ring round it (jump it)
## The roaming behemoth runs on this brain with bigger numbers (behemoth.gd).

const FILM := [["charge", 2.4], ["gore", 1.2], ["stomp", 1.6]]
const PAW := 0.9

var charge_len := 14.0
var charge_speed := 17.0
var gore_r := 3.4
var stomp_r := 4.2
var _from := Vector3.ZERO
var _to := Vector3.ZERO
var _n: int = 0


func _init() -> void:
	boss_name = "Tuskmaw"
	wake_r = 16.0
	leash_r = 38.0


func _spec() -> Dictionary:
	return {"hip_h": 1.05, "len": 1.45, "chest_r": 0.78, "hip_r": 0.6, "neck": Vector3(0, 0.0, -0.4), "head": Vector3(0.42, 0.4, 0.5),
		"snout": 0.5, "tail": 0.5, "tail_r": 0.06, "coat": Color(0.3, 0.22, 0.16), "under": Color(0.38, 0.3, 0.22), "mark": Color(0.12, 0.08, 0.06),
		"tex": "fur", "ears": 0.5, "eye": Color(1.0, 0.35, 0.15)}


func _extras() -> void:
	var hd: Vector3 = spec["head"]
	var sn: float = spec["snout"]
	var ivory := PSXMat.flat(Color(0.93, 0.88, 0.74))
	for s in [-1.0, 1.0]:
		var t0 := Vector3(s * hd.x * 0.45, -hd.y * 0.3, -hd.z * 0.9 - sn * 0.5)
		mb("Head").add_tube(ivory, PackedVector3Array([t0, t0 + Vector3(s * 0.18, 0.05, -0.2) * hd.x * 2.5, t0 + Vector3(s * 0.2, 0.45, -0.12) * hd.x * 2.5]),
			0.07 * hd.x * 2.5, 0.01, 5, 1.0)
	# the bristling ridge down the spine
	var cr: float = spec["chest_r"]
	var ln: float = spec["len"]
	for k in range(7):
		var z := -ln * 0.55 + k * ln * 0.18
		mb("Body").add_blob(spec["coat_mat"], Transform3D(Basis(), Vector3(0, cr * 0.95 - k * 0.03, z)), Vector3(cr * 0.18, cr * 0.32, ln * 0.12), _rng_fixed(), 0.3, 3, 5, 1.0, Color(0.5, 0.5, 0.5))


func _coat_at(p: Vector3) -> Color:
	var base := super._coat_at(p)
	return base.lerp(spec["mark"], smoothstep(0.6, 0.95, p.y / maxf(float(spec["chest_r"]), 0.1)) * 0.8)


func _hp_base() -> float:
	return 520.0


func _poise_max() -> float:
	return 120.0


func _phase_at() -> Array:
	return [0.5]


func _xp_base() -> int:
	return 220


func _coins_base() -> int:
	return 14


func _speed() -> float:
	return 6.0


func _hit_point() -> Vector3:
	return global_position + Vector3(0, float(spec["hip_h"]), 0)


func _ready() -> void:
	_cd = {"charge": 1.5, "gore": 0.5, "stomp": 99.0}
	super._ready()
	var hh: float = spec["hip_h"]
	hurt_ball(float(spec["chest_r"]) * 1.25, Vector3(0, hh, -float(spec["len"]) * 0.3))
	hurt_ball(float(spec["hip_r"]) * 1.25, Vector3(0, hh, float(spec["len"]) * 0.4))
	overhead(boss_name, hh + float(spec["chest_r"]) + 1.0)


func _process(delta: float) -> void:
	super._process(delta)
	var hh: float = spec["hip_h"]
	(hurtbox.get_child(0) as CollisionShape3D).position = model.basis * Vector3(0, hh, -float(spec["len"]) * 0.3)
	(hurtbox.get_child(1) as CollisionShape3D).position = model.basis * Vector3(0, hh, float(spec["len"]) * 0.4)


func _pose_for(delta: float) -> void:
	super._pose_for(delta)
	if state != S.FIGHT:
		return
	match move:
		"charge":
			if mv_t < PAW:
				pose = {"crouch": 0.3, "head": -0.35, "rear": sin(mv_t * 14.0) * 0.08}
			else:
				pose = {"head": -0.3, "stretch": 0.5}
		"gore":
			pose = {"head": -0.5 if mv_t < 0.35 else 0.55, "crouch": 0.2}
		"stomp":
			pose = {"rear": 0.9 if mv_t < 0.7 else 0.0, "head": 0.3, "jaw": 0.6}


func _brain(delta: float, p: Node3D, to: Vector3, dist: float) -> Vector3:
	_face(to)
	if phase >= 2 and dist < stomp_r + 0.5 and _cd["stomp"] <= 0.0:
		begin("stomp")
	elif dist < gore_r + 0.4 and _cd["gore"] <= 0.0:
		begin("gore")
	elif dist > 5.0 and dist < charge_len and _cd["charge"] <= 0.0:
		begin("charge")
	elif dist > gore_r - 0.5:
		var nd := _nav_dir(p.global_position, delta)
		_face(nd)
		return nd * _speed()
	return Vector3.ZERO


func _on_phase(_k: int) -> void:
	_cd["stomp"] = 0.0
	say("squeal", global_position, 4.0, 0.9)


func _parry_ok() -> bool:
	return move == "gore" and mv_t > 0.2 and mv_t < 0.5


func _armoured() -> bool:
	return move == "charge" and mv_t > PAW


func _wake_move() -> String:
	return "charge"


func _on_begin(m: String) -> void:
	_n = 0
	var p := _target()
	match m:
		"charge":
			_cd["charge"] = _rng.randf_range(4.5, 6.5)
			_from = global_position
			var d := _flat((p.global_position if p else global_position + _fwd()) - global_position).normalized()
			_face(d)
			_to = ground_at(global_position + d * charge_len)
			warn_lane(_from, _to, 2.4 * float(spec["chest_r"]) + 0.6, PAW)
			say("squeal", global_position, 2.0, 1.0)
		"gore":
			_cd["gore"] = _rng.randf_range(1.6, 2.4)
			say("squeal", global_position, -2.0, 1.25)
		"stomp":
			_cd["stomp"] = _rng.randf_range(6.0, 8.0)
			warn_ring(global_position, stomp_r, 0.9)


func _move_tick(_delta: float, p: Node3D) -> Vector3:
	match move:
		"charge":
			if mv_t < PAW:
				if _n == 0 and mv_t > 0.3:
					_n = 1
					Net.fx("dust", [global_position + _fwd() * 0.8, 6, 0.8])
				return Vector3.ZERO
			var d := _flat(_to - _from).normalized()
			if not _hit:
				_hit = true
				strike("lane", [_from, _to, float(spec["chest_r"]) * 1.2 + 0.3], _charge_dmg(), true)
			if _n < int((mv_t - PAW) / 0.15) + 1:
				_n += 1
				Net.fx("dust", [global_position, 3, 0.8])
			if _flat(_to - global_position).dot(d) < 0.5 or mv_t > PAW + charge_len / charge_speed + 0.4:
				end_move(1.2)
				say("squeal", global_position, -4.0, 0.8)
				return Vector3.ZERO
			return d * charge_speed
		"gore":
			if p and mv_t < 0.2:
				_face(_flat(p.global_position - global_position))
			if mv_t > 0.3 and not _hit:
				_hit = true
				strike("cone", [global_position, _fwd(), gore_r + float(spec["chest_r"]), 60.0], _gore_dmg(), true, true)
				Net.fx("sfx", ["whoosh_big", global_position + _fwd(), 0.0, 0.05, 0.9])
			if mv_t > 0.9:
				end_move(0.5)
		"stomp":
			if mv_t > 0.9 and not _hit:
				_hit = true
				strike("ring", [global_position, stomp_r], _stomp_dmg(), true, false, 1.0)
				quake(global_position, stomp_r / 5.0)
			if mv_t > 1.5:
				end_move(0.6)
	return Vector3.ZERO


func _charge_dmg() -> float:
	return 22.0


func _gore_dmg() -> float:
	return 16.0


func _stomp_dmg() -> float:
	return 14.0


func _on_stagger() -> void:
	say("squeal", global_position, 0.0, 1.4)


func _on_die() -> void:
	say("squeal", global_position, 2.0, 0.7)
