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
	# (a table kind: each move ready a moment after it wakes, a phase move once its phase comes: pick() checks the phase)
	var tb := _tbl()
	if not tb.is_empty():
		_cd = {}
		for m in tb.keys():
			_cd[m] = float((tb[m] as Dictionary).get("cd0", 0.5))
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
	var tb := _tbl()
	if not tb.is_empty():
		var e: Dictionary = tb.get(move if move != "" else _last_move, {})
		var ps: Array = e.get("pose", [])
		if ps.size() >= 3:
			if move != "":
				pose = (ps[0] if mv_t < float(e.get("tell", 0.6)) else ps[1]).duplicate()
			elif mv_t < 0.0:
				pose = (ps[2] as Dictionary).duplicate()
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


# ==========================================================================
# 1.20 (docs/v1_20_beasts.md): a kind's moves as a table, run by one brain (the beasts built on the boar each have
# their own list; an empty table keeps the boar's charge, gore and stomp). Each entry, keyed by the move's name:
#   min, max   the distance it's started from        phase  from which phase (1)       cd  [a, b] its cooldown after
#   tell       the wind-up (s)                       rec    the opening after it (s)
#   shape      "cone" in front (r, deg) | "behind" a cone back (r, deg) | "ring" round it (r; `at` m ahead of it) |
#              "lane" a line at you (len, w) | "charge" runs that line (len, w, speed) | "leap" onto your spot (r, air) |
#              "spots" n rings round you (n, r) | "lanes" n lines across you (n, len, w) | "none" (a hook does it)
#   dmg, knock (its one knockdown), parry (in the tell's last moment), kb (the push), stun (the stagger), hits and
#   every (repeats), warn (show where: the area moves always do), armour (no stagger in the tell)
#   pose       [tell, blow, recovery] pose dicts      say  [sound, pitch]      fx  "dust" | "sparkle" | "leaves" | "quake"
#   col        the warning's and the sparkle's colour
# Hooks: _table_tick(m, e, p) for a move's own extras (a return Vector3 other than INF overrides the velocity),
# _on_table_hit(m, e, at) after each blow.
# ==========================================================================
func _table() -> Dictionary:
	return {}


## The table, made once (_table() builds it fresh).
var _tb_cache = null
func _tbl() -> Dictionary:
	if _tb_cache == null:
		_tb_cache = _table()
	return _tb_cache


var _spots: Array = []


func _table_tick(_m: String, _e: Dictionary, _p: Node3D) -> Vector3:
	return Vector3.INF


func _on_table_hit(_m: String, _e: Dictionary, _at: Vector3) -> void:
	pass


func _table_brain(delta: float, p: Node3D, to: Vector3, dist: float, t: Dictionary) -> Vector3:
	_face(to)
	var wants: Array = []
	var reach := INF
	for m in t.keys():
		var e: Dictionary = t[m]
		reach = minf(reach, float(e.get("max", 4.0)))
		if phase >= int(e.get("phase", 1)) and dist >= float(e.get("min", 0.0)) and dist <= float(e.get("max", 4.0)):
			wants.append(m)
	var m := pick(wants)
	if m != "":
		begin(m)
		return Vector3.ZERO
	if dist > reach * 0.8:
		var nd := _nav_dir(p.global_position, delta)
		_face(nd)
		return nd * _speed()
	return Vector3.ZERO


func _table_begin(m: String, e: Dictionary) -> void:
	var cd: Array = e.get("cd", [4.0, 6.0])
	_cd[m] = _rng.randf_range(float(cd[0]), float(cd[1]))
	_n = 0
	var p := _target()
	var at: Vector3 = p.global_position if p else global_position + _fwd() * 6.0
	var tell := float(e.get("tell", 0.6))
	var col: Color = e.get("col", Color(1.0, 0.18, 0.12))
	var shape := str(e.get("shape", "cone"))
	_face(_flat(at - global_position))
	var d := _flat(at - global_position).normalized()
	if d.length() < 0.1:
		d = _fwd()
	match shape:
		"ring":
			if bool(e.get("warn", true)):
				warn_ring(global_position + _fwd() * float(e.get("at", 0.0)), float(e.get("r", 4.0)), tell, col)
		"lane", "charge":
			_from = global_position
			_to = ground_at(global_position + d * float(e.get("len", 12.0)))
			warn_lane(_from, _to, float(e.get("w", 1.6)) * 2.0, tell, col)
		"leap":
			_from = global_position
			_to = ground_at(at)
			warn_ring(_to, float(e.get("r", 3.5)), tell + float(e.get("air", 0.6)), col)
		"spots":
			_spots = []
			for k in range(int(e.get("n", 4))):
				var a := TAU * k / float(e.get("n", 4)) + _rng.randf() * 0.6
				var s := ground_at(at + Vector3(cos(a), 0, sin(a)) * _rng.randf_range(1.0, 3.5))
				_spots.append(s)
				warn_ring(s, float(e.get("r", 1.6)), tell, col)
		"lanes":
			_spots = []
			for k in range(int(e.get("n", 3))):
				var a := _rng.randf() * TAU
				var dir := Vector3(cos(a), 0, sin(a)) * float(e.get("len", 16.0)) * 0.5
				_spots.append([ground_at(at + dir + Vector3(0, 0, (k - 1) * 2.5)), ground_at(at - dir + Vector3(0, 0, (k - 1) * 2.5))])
				warn_lane(_spots[k][0], _spots[k][1], float(e.get("w", 1.6)) * 2.0, tell, col)
	var s: Array = e.get("say", [])
	if not s.is_empty():
		say(str(s[0]), global_position, 4.0, float(s[1]))


func _run_table(delta: float, p: Node3D, m: String, e: Dictionary) -> Vector3:
	var over := _table_tick(m, e, p)
	if over != Vector3.INF:
		return over
	var tell := float(e.get("tell", 0.6))
	var rec := float(e.get("rec", 1.0))
	var shape := str(e.get("shape", "cone"))
	if p and mv_t < tell * 0.6 and not shape in ["charge", "leap", "lane", "lanes", "spots"]:
		_face(_flat(p.global_position - global_position))
	if shape == "charge":
		if mv_t < tell:
			return Vector3.ZERO
		var d := _flat(_to - _from).normalized()
		if not _hit:
			_hit = true
			_blow(m, e, shape)
		if _n < int((mv_t - tell) / 0.15) + 1:
			_n += 1
			Net.fx("dust", [global_position, 3, 0.8])
		var speed := float(e.get("speed", 15.0))
		if _flat(_to - global_position).dot(d) < 0.5 or mv_t > tell + float(e.get("len", 12.0)) / speed + 0.4:
			end_move(rec)
			return Vector3.ZERO
		return d * speed
	if shape == "leap":
		if mv_t < tell:
			return Vector3.ZERO
		var air := float(e.get("air", 0.6))
		var u := clampf((mv_t - tell) / air, 0.0, 1.0)
		if u < 1.0:
			_fly = true
			var flat := _from.lerp(_to, u)
			global_position = Vector3(flat.x, lerpf(_from.y, _to.y, u) + sin(u * PI) * float(e.get("arc", 3.0)), flat.z)
			return Vector3.ZERO
		if not _hit:
			_hit = true
			_fly = false
			_blow(m, e, shape)
		if mv_t > tell + air + 0.3:
			end_move(rec)
		return Vector3.ZERO
	var hits := int(e.get("hits", 1))
	var every := float(e.get("every", 0.3))
	if _n < hits and mv_t > tell + _n * every:
		_n += 1
		_blow(m, e, shape)
	if mv_t > tell + (hits - 1) * every + 0.25:
		end_move(rec)
	return _fwd() * float(e.get("step", 0.0)) if _n > 0 and _n <= hits else Vector3.ZERO


## One blow of a table move, its fx and its hook.
func _blow(m: String, e: Dictionary, shape: String) -> void:
	var dmg := float(e.get("dmg", 16.0))
	var knock := bool(e.get("knock", false))
	var parry := bool(e.get("parry", false))
	var kb := float(e.get("kb", 7.0))
	var stun := float(e.get("stun", 0.4))
	var r := float(e.get("r", 4.0))
	var at := global_position
	match shape:
		"cone":
			strike("cone", [global_position, _fwd(), r, float(e.get("deg", 70.0))], dmg, knock, parry, 1.1, kb, stun)
			at = global_position + _fwd() * r * 0.6
		"behind":
			strike("cone", [global_position, -_fwd(), r, float(e.get("deg", 90.0))], dmg, knock, parry, 1.1, kb, stun)
			at = global_position - _fwd() * r * 0.6
		"ring":
			at = global_position + _fwd() * float(e.get("at", 0.0))
			strike("ring", [at, r], dmg, knock, parry, 1.1, kb, stun)
		"lane", "charge":
			strike("lane", [_from, _to, float(e.get("w", 1.6))], dmg, knock, parry, 1.1, kb, stun)
			at = _from.lerp(_to, 0.5)
		"leap":
			at = _to
			strike("ring", [_to, r], dmg, knock, parry, 1.1, kb, stun)
		"spots":
			for s in _spots:
				strike("ring", [s, r], dmg, knock, parry, 1.0, kb, stun)
				_fx(e, s, r)
		"lanes":
			for l in _spots:
				strike("lane", [l[0], l[1], float(e.get("w", 1.6))], dmg, knock, parry, 1.0, kb, stun)
				_fx(e, (l[0] as Vector3).lerp(l[1], 0.5), 2.0)
	if not shape in ["spots", "lanes"]:
		_fx(e, at, r)
	_on_table_hit(m, e, at)


func _fx(e: Dictionary, at: Vector3, r: float) -> void:
	match str(e.get("fx", "dust")):
		"dust":
			Net.fx("dust", [at, 8, 0.9])
		"sparkle":
			Net.fx("sparkle", [at + Vector3.UP * 0.5, 16, e.get("col", Color.WHITE)])
		"leaves":
			shower(at + Vector3.UP * 2.0, 14, r * 0.6)
		"quake":
			quake(at, clampf(r / 5.0, 0.4, 1.4))


func _brain(delta: float, p: Node3D, to: Vector3, dist: float) -> Vector3:
	var tb := _tbl()
	if not tb.is_empty():
		return _table_brain(delta, p, to, dist, tb)
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
	if not _tbl().is_empty():
		say("bellow", global_position, 6.0, 0.8)
		return
	_cd["stomp"] = 0.0
	say("squeal", global_position, 4.0, 0.9)


func _parry_ok() -> bool:
	var e: Dictionary = _tbl().get(move, {})
	if not e.is_empty():
		var tell := float(e.get("tell", 0.6))
		return bool(e.get("parry", false)) and mv_t > tell - 0.15 and mv_t < tell + 0.15
	return move == "gore" and mv_t > 0.2 and mv_t < 0.5


func _armoured() -> bool:
	var e: Dictionary = _tbl().get(move, {})
	if not e.is_empty():
		return bool(e.get("armour", false)) or (str(e.get("shape", "")) == "charge" and mv_t > float(e.get("tell", 0.6)))
	return move == "charge" and mv_t > PAW


func _wake_move() -> String:
	return "charge"


func _on_begin(m: String) -> void:
	var tb := _tbl()
	if tb.has(m):
		_table_begin(m, tb[m])
		return
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
	var tb := _tbl()
	if tb.has(move):
		return _run_table(_delta, p, move, tb[move])
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
