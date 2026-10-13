extends QuadBeast
## The Shade: a great cat (a black panther, a jaguar or a clouded grey by the
## island's look) that hunts from the brush round its run (BeastArena, BeastPool
## "stalker"). Long, low and quick; it fights in bursts and then it's gone.
##
## Moves (each with its tell):
##   roar    woken, and at each phase: up on its haunches, a roar (a shockwave: jump it)
##   claws   three swipes in front (a dip of the shoulders before each); the third
##           is the heavy one: parry it and it reels
##   pounce  it drops flat, eyes flaring and a snarl, a ring on you, then it's in
##           the air; miss it and it skids and stumbles, wide open
##   lash    it whips round, the tail sweeping a ring about it (jump it)
##   stalk   (phase 2+, then every so often) into the brush and gone: only its eyes
##           in the leaves and the thrashing where it moves, brush to brush; enraged,
##           a second patch thrashes too (which is it?); it comes out in a pounce
## Phases at 60% and 30%.

const FILM := [["roar", 2.0], ["claws", 2.2], ["pounce", 2.4], ["lash", 1.4], ["stalk", 7.0]]
const COATS := [
	[Color(0.09, 0.09, 0.1), Color(0.17, 0.16, 0.17), Color(0.03, 0.03, 0.04)],
	[Color(0.8, 0.57, 0.24), Color(0.93, 0.87, 0.72), Color(0.11, 0.08, 0.05)],
	[Color(0.46, 0.46, 0.44), Color(0.78, 0.77, 0.72), Color(0.17, 0.17, 0.17)],
]
const POUNCE_WIND := 0.75
const POUNCE_AIR := 0.55
const POUNCE_R := 3.3
const CLAW_AT := [0.45, 0.85, 1.4]

var _from := Vector3.ZERO
var _to := Vector3.ZERO
var _n: int = 0
var _spot: int = 0
var _fx_t: float = 0.0
var _hops: int = 0
var _hidden: bool = false


func _init() -> void:
	boss_name = "The Shade"


func _spec() -> Dictionary:
	var c: Array = COATS[variant % COATS.size()]
	return {"hip_h": 1.35, "len": 2.0, "chest_r": 0.62, "hip_r": 0.52, "neck": Vector3(0, 0.3, -0.55), "head": Vector3(0.4, 0.33, 0.42),
		"snout": 0.3, "tail": 2.2, "tail_r": 0.13, "coat": c[0], "under": c[1], "mark": c[2], "tex": "fur", "ears": 0.45,
		"eye": Color(0.85, 1.0, 0.3)}


## Rosettes (or the grey's clouds) over the back and flanks, faint on the black.
func _coat_at(p: Vector3) -> Color:
	var base := super._coat_at(p)
	var q := p * (5.5 if variant != 2 else 3.0)
	var ring := absf(sin(q.x * 1.3 + sin(q.z * 0.9) * 1.7) * sin(q.z * 1.1 + q.y * 0.8 + sin(q.x * 0.7)))
	var spot := smoothstep(0.62, 0.8, ring) * (1.0 - smoothstep(0.86, 0.97, ring) * (0.0 if variant == 2 else 0.8))
	return base.lerp(spec["mark"], spot * (0.35 if variant == 0 else 0.9))


func _extras() -> void:
	var hd: Vector3 = spec["head"]
	var sn: float = spec["snout"]
	var bone := PSXMat.flat(Color(0.95, 0.92, 0.84))
	var whisker := PSXMat.flat(Color(0.85, 0.85, 0.8))
	for s in [-1.0, 1.0]:
		mb("Head").add_cylinder(bone, Transform3D(Basis(Vector3.RIGHT, PI), Vector3(s * hd.x * 0.22, -hd.y * 0.3, -hd.z * 0.9 - sn * 0.75)), 0.045, 0.0, 0.22, 4, 1.0, Color.WHITE, false, false, false)
		for k in range(3):
			var w0 := Vector3(s * hd.x * 0.3, -hd.y * 0.1 + k * 0.03, -hd.z * 0.9 - sn * 0.8)
			mb("Head").add_tube(whisker, PackedVector3Array([w0, w0 + Vector3(s * 0.3, 0.02 - k * 0.04, 0.1), w0 + Vector3(s * 0.55, -0.04 - k * 0.06, 0.25)]), 0.008, 0.004, 3, 1.0)
	for leg in ["FL", "FR"]:
		for k in range(3):
			mb("Knee" + leg).add_cylinder(bone, Transform3D(Basis(Vector3.RIGHT, -1.9), Vector3((k - 1) * 0.07, -float(spec["hip_h"]) * 0.5 + 0.06, -0.2)), 0.025, 0.0, 0.16, 3, 1.0, Color(0.85, 0.82, 0.75), false, false, false)


func _hp_base() -> float:
	return 1250.0


func _poise_max() -> float:
	return 170.0


func _speed() -> float:
	return 7.2 if phase < 3 else 8.6


func _hit_point() -> Vector3:
	return global_position + Vector3(0, 1.3, 0)


func trophy(t: int) -> ItemData:
	return Gear.make("accessory", "cape", {"cape": true, "cape_color": spec["coat"]}, "Shade Pelt" if variant == 0 else "Hunter's Pelt", t)


func _wake_move() -> String:
	return "roar"


func _ready() -> void:
	_cd = {"claws": 0.5, "pounce": 3.0, "lash": 5.0, "stalk": 99.0}
	super._ready()
	hurt_ball(0.9, Vector3(0, 1.3, -0.7))
	hurt_ball(0.8, Vector3(0, 1.25, 0.8))


func _process(delta: float) -> void:
	super._process(delta)
	# (the hurtbox turns with the body)
	for i in range(hurtbox.get_child_count()):
		var cs := hurtbox.get_child(i) as CollisionShape3D
		cs.position = model.basis * Vector3(0, 1.3, -0.7 if i == 0 else 0.8)


func _pose_for(delta: float) -> void:
	super._pose_for(delta)
	if state != S.FIGHT:
		return
	match move:
		"roar":
			pose = {"rear": 0.5 if mv_t < 1.6 else 0.0, "head": 0.45, "jaw": 1.0 if mv_t > 0.3 else 0.3, "tail": 1.0}
		"claws":
			var k := 0.0
			for at in CLAW_AT:
				k = maxf(k, 1.0 - absf(mv_t - float(at) + 0.12) / 0.2)
			pose = {"crouch": 0.25, "rear": maxf(k, 0.0) * 0.35, "jaw": 0.7, "head": -0.1}
		"pounce":
			if mv_t < POUNCE_WIND:
				pose = {"crouch": 0.95, "head": -0.05, "jaw": 0.5, "tail": 1.0}
			elif mv_t < POUNCE_WIND + POUNCE_AIR:
				pose = {"stretch": 1.0, "rear": 0.15, "jaw": 1.0}
			else:
				pose = {"crouch": 0.5, "jaw": 0.3}
		"lash":
			pose = {"crouch": 0.35, "tail": 1.0}
		"stalk":
			pose = {"crouch": 0.75, "head": -0.1}


func _brain(delta: float, p: Node3D, to: Vector3, dist: float) -> Vector3:
	_face(to)
	if phase >= 2 and _cd["stalk"] <= 0.0 and not (arena.brush as Array).is_empty():
		begin("stalk")
	elif dist < 4.6 and _cd["claws"] <= 0.0:
		begin("claws")
	elif dist < 4.5 and _cd["lash"] <= 0.0:
		begin("lash")
	elif dist > 6.0 and dist < 15.0 and _cd["pounce"] <= 0.0:
		begin("pounce")
	elif dist > 4.0:
		var nd := _nav_dir(p.global_position, delta)
		_face(nd)
		return nd * _speed()
	else:
		return to.normalized().cross(Vector3.UP) * 3.0 - to.normalized() * 1.5
	return Vector3.ZERO


func _on_phase(_k: int) -> void:
	_cd["stalk"] = 0.0
	if not _hidden:
		begin("roar")


func _parry_ok() -> bool:
	return move == "claws" and mv_t > CLAW_AT[2] - 0.2 and mv_t < CLAW_AT[2] + 0.15


func _armoured() -> bool:
	return move in ["pounce", "stalk", "roar"]


func _on_begin(m: String) -> void:
	_n = 0
	_hops = 0
	var p := _target()
	match m:
		"roar":
			say("catroar", global_position, 6.0, 1.0)
		"claws":
			_cd["claws"] = _rng.randf_range(2.2, 3.2)
			say("snarl", global_position, 2.0, 1.1)
		"pounce":
			_cd["pounce"] = _rng.randf_range(5.0, 7.0)
			_pounce_at(p.global_position if p else global_position + _fwd() * 8.0)
		"lash":
			_cd["lash"] = _rng.randf_range(6.0, 8.0)
			warn_ring(global_position, 4.3, 0.55)
		"stalk":
			_cd["stalk"] = _rng.randf_range(22.0, 28.0)
			_spot = _near_brush()
			_to = arena.brush[_spot]
			_fly = true
			say("snarl", global_position, 0.0, 0.8)


func _pounce_at(at: Vector3) -> void:
	_from = global_position
	_to = ground_at(at)
	_face(_flat(_to - _from))
	warn_ring(_to, POUNCE_R, POUNCE_WIND + POUNCE_AIR)
	say("snarl", global_position, 5.0, 0.9)
	Net.fx("sparkle", [_eyes(), 10, Color(0.9, 1.0, 0.4)])


func _eyes() -> Vector3:
	return (rig["Head"] as Node3D).global_position + Vector3(0, 0.1, 0)


func _move_tick(delta: float, p: Node3D) -> Vector3:
	match move:
		"roar":
			if mv_t > 1.0 and not _hit:
				_hit = true
				strike("ring", [global_position, 6.5], 8.0, true, false, 1.1)
				Net.fx("dust_ring", [global_position, 24, 1.8])
			if mv_t > 1.8:
				end_move(0.2)
		"claws":
			if p and mv_t < CLAW_AT[_n if _n < 3 else 2] - 0.1:
				_face(_flat(p.global_position - global_position))
			if _n < 3 and mv_t > CLAW_AT[_n]:
				var heavy := _n == 2
				strike("cone", [global_position, _fwd(), 4.2, 70.0], 20.0 if heavy else 13.0, heavy, heavy)
				Net.fx("sfx", ["whoosh_big" if heavy else "whoosh", global_position + _fwd() * 2.0, 0.0, 0.05, 0.85])
				var side := _fwd().cross(Vector3.UP) * (1.0 if _n % 2 == 0 else -1.0)
				Net.fx("streak", [global_position + _fwd() * 2.2 + side * 1.4 + Vector3(0, 1.8, 0), global_position + _fwd() * 2.4 - side * 1.4 + Vector3(0, 0.6, 0),
					Color(1.0, 0.9, 0.8) if not heavy else Color(1.0, 0.35, 0.25), 0.12, 0.2])
				_n += 1
				return _fwd() * 6.0
			if mv_t > CLAW_AT[2] + 0.6:
				end_move(0.7)
			return _fwd() * 1.5 if _n < 3 else Vector3.ZERO
		"pounce":
			return _pounce_tick(p)
		"lash":
			if mv_t > 0.55 and mv_t < 1.0:
				_yaw += delta * TAU / 0.45
				model.rotation.y = _yaw
				if not _hit:
					_hit = true
					strike("ring", [global_position, 4.3], 17.0, true, false, 1.0)
					Net.fx("sfx", ["whoosh_big", global_position, 2.0, 0.05, 0.7])
					Net.fx("dust_ring", [global_position, 14, 1.0])
			if mv_t > 1.2:
				end_move(0.5)
		"stalk":
			return _stalk_tick(delta, p)
	return Vector3.ZERO


func _pounce_tick(p: Node3D) -> Vector3:
	if mv_t < POUNCE_WIND:
		_face(_flat(_to - global_position))
		return Vector3.ZERO
	var u := clampf((mv_t - POUNCE_WIND) / POUNCE_AIR, 0.0, 1.0)
	if u < 1.0:
		_fly = true
		if _n == 0:
			_n = 1
			Net.fx("dust", [global_position, 8, 1.0])
			Net.fx("sfx", ["whoosh_big", global_position, 3.0, 0.05, 0.75])
		var flat := _from.lerp(_to, u)
		global_position = Vector3(flat.x, lerpf(_from.y, _to.y, u) + sin(u * PI) * 2.6, flat.z)
		return Vector3.ZERO
	if not _hit:
		_hit = true
		_fly = false
		var me_hit := false
		for c in Net.all_players():
			if BeastShapes.inside("ring", [_to, POUNCE_R], (c as Node3D).global_position, 1.1):
				me_hit = true
		strike("ring", [_to, POUNCE_R], 28.0, true, false, 1.1)
		quake(_to, 0.6)
		_n = 3 if me_hit else 2
		if _n == 2:
			say("snarl", global_position, 0.0, 1.3)
	# a miss: it skids and stumbles, open
	if _n == 2:
		if mv_t < POUNCE_WIND + POUNCE_AIR + 0.4:
			return _fwd() * 5.0
		if mv_t > POUNCE_WIND + POUNCE_AIR + 1.5:
			end_move(0.4)
	elif mv_t > POUNCE_WIND + POUNCE_AIR + 0.6:
		end_move(0.5)
	return Vector3.ZERO


## Into the brush, eyes in the leaves, brush to brush; out in a pounce.
func _stalk_tick(delta: float, p: Node3D) -> Vector3:
	_fx_t -= delta
	if _n == 0:
		var to := _flat(_to - global_position)
		_face(to)
		global_position = global_position.move_toward(Vector3(_to.x, ground_at(_to).y, _to.z), delta * _speed() * 1.3)
		if to.length() < 0.8:
			_n = 1
			mv_t = 0.0
			_hide(true)
		return Vector3.ZERO
	if _n == 1:
		var n: int = (arena.brush as Array).size()
		global_position = global_position.lerp(Vector3(_to.x, ground_at(_to).y, _to.z), minf(delta * 3.5, 1.0))
		_face(_flat(arena.centre() - global_position))
		if _fx_t <= 0.0:
			_fx_t = 0.4
			BeastFX.brush(global_position, 5)
			Net.event(self, "brush", [global_position])
			if phase >= 3:
				var decoy: Vector3 = arena.brush[posmod(_spot + n / 2, n)]
				BeastFX.brush(decoy, 5)
				Net.event(self, "brush", [decoy])
		if mv_t > 1.0:
			mv_t = 0.0
			_hops += 1
			if _rng.randf() < 0.5:
				Net.fx("sparkle", [_eyes(), 4, Color(0.9, 1.0, 0.4)])
				say("snarl", global_position, -4.0, 0.7)
			if _hops >= 3 + _rng.randi() % 2 and p:
				_hide(false)
				move = "pounce"
				mv_t = 0.0
				_n = 0
				_hit = false
				_pounce_at(p.global_position)
				return Vector3.ZERO
			_spot = posmod(_spot + (1 if _rng.randf() < 0.65 else -1), n)
			_to = arena.brush[_spot]
	return Vector3.ZERO


func _hide(on: bool) -> void:
	_hidden = on
	eyes_only(on)
	hurtbox.monitorable = not on
	Net.event(self, "hide", [on])


func _near_brush() -> int:
	var best := 0
	var bd := INF
	for i in range((arena.brush as Array).size()):
		var d := _flat((arena.brush[i] as Vector3) - global_position).length()
		if d < bd:
			bd = d
			best = i
	return best


func _on_stagger() -> void:
	if _hidden:
		_hide(false)
	say("snarl", global_position, 0.0, 1.4)


func _on_die() -> void:
	if _hidden:
		eyes_only(false)
	say("catroar", global_position, 2.0, 0.7)


func reset_fight() -> void:
	super.reset_fight()
	if _hidden:
		_hide(false)


func _pack_extra() -> Array:
	return [_hidden]


func _unpack_extra(a: Array, _b: Array, _f: float) -> void:
	if bool(a[0]) != _hidden:
		_hidden = bool(a[0])
		eyes_only(_hidden)
		hurtbox.monitorable = not _hidden


func _event(what: String, args: Array) -> void:
	match what:
		"brush":
			BeastFX.brush(args[0], 5)
		"hide":
			_hidden = bool(args[0])
			eyes_only(_hidden)
