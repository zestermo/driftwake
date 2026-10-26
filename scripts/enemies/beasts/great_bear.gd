extends "res://scripts/enemies/beasts/alpha_boar.gd"
## The Bear King (BeastPool "great_bear", a snow island's boss): a white bear the size of
## a cabin, a shaggy hump over its shoulders, claws like sickles. Its arena's banner calls
## it; no bar over its head (the arena's). Looks: white, cream, old grey.
## 1.23 beast pass (BeastPass, docs/v1_23_previews.md section 6): woken it rears and roars; phase 1 mauls, charges and
## swats one move at a time; phase 2 adds the Body Slam (its one knockdown) and the Fish-scoop (a chunk of snow down a
## lane), in pairs; phase 3 foams at the mouth, its eyes go red, and it adds the Frenzy (four swipes walking in) and the
## Avalanche Roar (rears roaring: icicles crash down round you and snow slides in from the arena's edge in lanes),
## in chains of three. Each phase change: it reels, rears up roaring, a ring of snow pushes everyone back. Parts: its
## front claws (Frenzy is two swipes, not four; a Bear King Claw), its hide over the haunches (a raw patch that takes
## double damage; a Bear King Hide). Its breath steams in the cold; snow is kicked up at every step.

const BEAR_COATS := [
	[Color(0.9, 0.9, 0.88), Color(0.97, 0.97, 0.95), Color(0.72, 0.72, 0.7)],
	[Color(0.88, 0.82, 0.66), Color(0.95, 0.92, 0.82), Color(0.7, 0.62, 0.48)],
	[Color(0.66, 0.67, 0.68), Color(0.84, 0.84, 0.84), Color(0.46, 0.46, 0.48)],
]
## (bossshot films these: film_list())
const BEAR_FILM := [["roar", 1.6], ["maul", 1.8], ["charge", 2.2], ["swat", 1.1], ["slam", 2.8], ["scoop", 1.6], ["frenzy", 2.4],
	["avalanche", 3.2], ["moment", 2.4]]


func film_list() -> Array:
	return BEAR_FILM


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
## black sickle claws on every pad (the front ones their own parts: "ClawsFL"/"ClawsFR"), and under the haunches' fur
## a raw patch shown once the hide is torn ("Patch").
func _extras() -> void:
	var hd: Vector3 = spec["head"]
	var sn: float = spec["snout"]
	var cr: float = spec["chest_r"]
	var hr: float = spec["hip_r"]
	var ln: float = spec["len"]
	var lift: float = float(spec["front_h"]) - float(spec["hip_h"])
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
		var on := foot_part(leg)
		if front:
			_node("Claws" + leg, Vector3.ZERO, rig[foot_part(leg)])
			on = "Claws" + leg
		for k in range(4):
			mb(on).add_cylinder(black, Transform3D(Basis(Vector3.RIGHT, -1.75), Vector3((k - 1.5) * thick * 0.42, foot_y(leg) + thick * 0.22, -thick * 1.75)), thick * (0.13 if front else 0.1), 0.0, thick * (0.95 if front else 0.75), 3, 1.0, Color.WHITE, false, false, false)
	# the raw patch under the haunches' hide
	_node("Patch", Vector3(0, hr * 0.62, ln * 0.1), rig["Hips"])
	mb("Patch").add_blob(PSXMat.flat(Color(0.62, 0.16, 0.14)), Transform3D(), Vector3(hr * 0.62, hr * 0.32, hr * 0.7), _rng_fixed(), 0.2, 3, 6, 1.0)


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
	return "roar"


func _pass_moves() -> Array:
	return [["maul", "charge", "swat"], ["slam", "scoop"], ["frenzy", "avalanche"]]


func _chain_waits() -> Array:
	return ["slam", "frenzy", "avalanche"]


func _part_name(n: String) -> String:
	return "Claws" if n == "claws" else "Hide"


func _moment_color() -> Color:
	return SNOW


## A blow on its torn hide: double.
func _taken_k(attacker: Node) -> float:
	if bp.parts.broken("hide") and attacker is Node3D and BeastParts.blow_at(attacker, global_position).distance_to((rig["Patch"] as Node3D).global_position) < 2.6:
		return 2.0
	return 1.0


## How many of its parts are broken (IslandArcs' hidden finish: "break both its parts").
func parts_broken() -> int:
	return bp.parts.count_broken()


var _breath: CPUParticles3D
var _foam: CPUParticles3D
var _step_s := 1.0


func _ready() -> void:
	super._ready()
	_cd = {"maul": 0.5, "slam": 4.0, "charge": 2.0, "swat": 0.0, "scoop": 99.0, "frenzy": 99.0, "avalanche": 99.0}
	_overhead.queue_free()
	_overhead = null
	bp.parts.add("claws", _hp_base() * 0.08, [rig["AnkleFL"], rig["AnkleFR"]], 1.7, "bear_claw", Color(0.2, 0.18, 0.16))
	bp.parts.add("hide", _hp_base() * 0.1, [rig["Patch"]], 2.3, "bear_hide", BEAR_COATS[variant % BEAR_COATS.size()][0])
	# its breath steaming in the cold, every few seconds a cloud
	_breath = FX.flip_emitter(rig["Head"], "mist", 3, 0.55, 1.3, {"direction": Vector3(0, -0.3, -1), "spread": 18.0, "vel_min": 0.5,
		"vel_max": 0.9, "radius": 0.08, "gravity": Vector3(0, 0.15, 0), "color": Color(1, 1, 1, 0.4), "fade": 0.6, "range": 90.0})
	_breath.name = "Breath"
	_breath.position = Vector3(0, -0.1, -float(spec["head"].z) - float(spec["snout"]))
	_on_look()


func trophy(t: int) -> ItemData:
	return Gear.make("accessory", "cape", {"cape": true, "cape_color": spec["coat"]}, "Bear King's Mantle", t)


# ==========================================================================
# 1.20's moves (docs/v1_20_beasts.md 7), the 1.23 pass's on top
#   roar      (woken) rears and roars, the breath steaming
#   maul      rears on its hind legs (0.6 s): two downward swipes in front (push); 0.8 s
#   charge    head down (0.7 s): a short charge (push); 1.0 s
#   swat      a glance sideways (0.35 s): a fast side paw (stops you flanking it); 0.5 s
#   slam      (phase 2) stands tall, roaring (0.9 s): falls forward onto you, 4 m (its one knockdown); 1.6 s getting up
#   scoop     (phase 2) digs at the snow (0.6 s): flings a chunk down a lane; 0.8 s
#   frenzy    (phase 3) foaming: four swipes (two with its claws broken), a step forward each; 1.6 s winded
#   avalanche (phase 3) rears roaring (1.0 s): icicles crash down round each captain, snow slides in from the arena's
#             edge in lanes (each warned on the ground); 1.2 s
# ==========================================================================
const SNOW := Color(0.92, 0.96, 1.0)
const MAUL_R := 3.6
const SLAM_R := 4.0
const SCOOP_LEN := 14.0
const AVALANCHE_LANES := 4
const AVALANCHE_R := 19.0
const ICICLES := 3


func _on_phase(n: int) -> void:
	if n >= 2:
		_cd["scoop"] = 1.0
		_cd["slam"] = 2.0
	if n >= 3:
		_cd["frenzy"] = 1.0
		_cd["avalanche"] = 4.0


func _brain(delta: float, p: Node3D, to: Vector3, dist: float) -> Vector3:
	var flank := absf(_fwd().signed_angle_to(to.normalized(), Vector3.UP)) > 1.0
	if dist < MAUL_R and flank:
		var m := pick(["swat"])
		if m != "":
			begin(m)
			return Vector3.ZERO
	_face(to)
	var wants: Array = []
	if dist > 4.0:
		wants.append("avalanche")
	if dist < MAUL_R + 1.0:
		wants.append("frenzy")
	if dist < SLAM_R + 0.5:
		wants.append_array(["slam", "maul"])
	elif dist < SCOOP_LEN:
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
	return (move == "slam" and mv_t < 0.9) or move in ["roar", "avalanche"]


## How hard its head fixes on you: locked in a wind-up, looser in a blow.
func _look_lock() -> float:
	match move:
		"maul", "charge":
			return 1.0 if mv_t < 0.7 else 0.4
		"slam", "avalanche":
			return 1.0 if mv_t < 0.9 else 0.3
		"swat", "frenzy":
			return 0.7
		"scoop":
			return 0.5
		"roar", "moment":
			return 0.2
	return 0.8


func _on_begin(m: String) -> void:
	_n = 0
	var p := _target()
	var at: Vector3 = p.global_position if p else global_position + _fwd() * 4.0
	match m:
		"roar":
			say("bellow", global_position, 8.0, 0.6, 140.0)
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
		"avalanche":
			_cd["avalanche"] = _rng.randf_range(16.0, 20.0)
			say("bellow", global_position, 9.0, 0.5, 160.0)
			_avalanche_warn()


## Where the avalanche will come: icicles over each captain's spot, and lanes of snow sliding in from the arena's edge
## across it (one through the nearest captain, the rest round the ring), each warned on the ground.
func _avalanche_warn() -> void:
	_spots = []
	var c: Vector3 = arena.global_position if arena else post
	var p := _target()
	var a0 := atan2((p.global_position - c).z, (p.global_position - c).x) if p else _rng.randf() * TAU
	for k in range(AVALANCHE_LANES):
		var a := a0 + TAU * k / AVALANCHE_LANES + _rng.randf_range(-0.25, 0.25)
		var from := ground_at(c + Vector3(cos(a), 0, sin(a)) * AVALANCHE_R)
		var to := ground_at(c - Vector3(cos(a), 0, sin(a)) * AVALANCHE_R * 0.3)
		warn_lane(from, to, 3.0, 1.8)
		_spots.append([from, to])
	for pl in Net.all_players():
		var pp := (pl as Node3D).global_position
		if pp.distance_to(c) > AVALANCHE_R + 6.0:
			continue
		for k in range(ICICLES):
			var q := ground_at(pp + Vector3(_rng.randf_range(-3.0, 3.0), 0, _rng.randf_range(-3.0, 3.0)) * (0.0 if k == 0 else 1.0))
			warn_ring(q, 1.5, 1.2 + k * 0.25)
			_spots.append([q, k])


func _move_tick(_delta: float, p: Node3D) -> Vector3:
	match move:
		"roar":
			if mv_t > 0.8 and not _hit:
				_hit = true
				Net.fx("puff_ring", [global_position, "snow", 10, 1.5, 2.4, 1.2, Color.WHITE, 7.0])
			if mv_t > 1.6:
				end_move(0.3)
		"maul":
			if p and mv_t < 0.3:
				_face(_flat(p.global_position - global_position))
			for k in range(2):
				if _n == k and mv_t > 0.6 + k * 0.25:
					_n += 1
					strike("cone", [global_position, _fwd(), MAUL_R, 80.0], 16.0, false, true, 1.1, 7.0)
					Net.fx("sfx", ["whoosh_big", global_position + _fwd(), 0.0, 0.05, 0.85])
					Net.fx("puff", [global_position + _fwd() * 2.5, "snow", 4, 1.4, 0.8, Color.WHITE, 1.0, Vector3.UP])
			if mv_t > 1.0:
				end_move(0.8)
		"slam":
			if mv_t > 0.9 and not _hit:
				_hit = true
				var at := global_position + _fwd() * 2.2
				strike("ring", [at, SLAM_R], 28.0, true)
				quake(at, 1.1)
				Net.fx("puff_ring", [at, "snow", 10, 1.2, 2.2, 1.1, Color.WHITE, 7.0])
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
					Net.fx("puff", [_from.lerp(_to, (k + 1) / 5.0) + Vector3.UP * 0.6, "snow", 3, 1.2, 0.9, Color.WHITE, 0.8, Vector3.UP])
			if mv_t > 0.8:
				end_move(0.8)
		"frenzy":
			# (its claws broken: two swipes, not four)
			var swipes := 2 if bp.parts.broken("claws") else 4
			if _n < swipes and mv_t > 0.4 + _n * 0.38:
				_n += 1
				strike("cone", [global_position, _fwd(), MAUL_R, 90.0], 13.0, false, false, 1.0, 6.0)
				Net.fx("sfx", ["whoosh_big", global_position + _fwd(), -2.0, 0.08, 0.95])
				Net.fx("puff", [global_position + _fwd() * 2.0, "snow", 3, 1.2, 0.7, Color.WHITE, 0.8, Vector3.UP])
			if p and mv_t < 0.4 + swipes * 0.38:
				_face(_flat(p.global_position - global_position))
			if mv_t > 0.6 + swipes * 0.38:
				end_move(1.6)
			return _fwd() * (2.2 if mv_t < 0.5 + swipes * 0.38 else 0.0)
		"avalanche":
			_avalanche_tick()
	return Vector3.ZERO


## The roar's icicles and the snow's lanes, each when its warning runs out.
func _avalanche_tick() -> void:
	if mv_t > 1.0 and _n == 0:
		_n = 1
		Net.fx("puff_ring", [global_position, "snow", 12, 1.5, 2.6, 1.3, Color.WHITE, 9.0])
		get_node("/root/CombatManager").apply_camera_shake(0.3)
	for s in _spots:
		var e: Array = s
		if e.size() > 2:
			continue
		if e[1] is Vector3:
			if mv_t > 1.8:
				e.append(true)
				strike("lane", [e[0], e[1], 1.5], 20.0, false, false, 1.4, 13.0, 0.6)
				for k in range(4):
					Net.fx("plume", [(e[0] as Vector3).lerp(e[1], k / 3.0), Vector3.UP, "snow", 3, 2.4, 1.2, Color.WHITE, 4.0, 25.0])
				Net.fx("sfx", ["rock_crash", e[0], 4.0, 0.1, 0.7])
		elif mv_t > 1.2 + float(e[1]) * 0.25:
			e.append(true)
			var q: Vector3 = e[0]
			Net.fx("streak", [q + Vector3(0.3, 9.0, 0.2), q, Color(0.8, 0.92, 1.0), 0.16, 0.18])
			Net.fx("rock_spikes", [q, 0.5, 3, _rng.randi() % 1000, 1.1, 1.4, true])
			Net.fx("sparkle", [q + Vector3.UP * 0.4, 10, SNOW])
			strike("ring", [q, 1.5], 14.0, false, false, 1.2, 4.0)
	if mv_t > 2.4:
		end_move(1.2)


## The phase change's roar: icicles drop round it.
func _on_moment() -> void:
	for k in range(5):
		var a := TAU * k / 5.0 + _rng.randf() * 0.5
		var q := ground_at(global_position + Vector3(cos(a), 0, sin(a)) * _rng.randf_range(4.0, 8.0))
		Net.fx("streak", [q + Vector3(0.3, 9.0, 0.2), q, Color(0.8, 0.92, 1.0), 0.16, 0.18])
		Net.fx("rock_spikes", [q, 0.5, 3, _rng.randi() % 1000, 1.0, 1.4, true])


## Phase 3: foaming at the mouth, its eyes red; torn claws gone, torn hide raw.
func _on_look() -> void:
	(rig["ClawsFL"] as Node3D).visible = not bp.parts.broken("claws")
	(rig["ClawsFR"] as Node3D).visible = not bp.parts.broken("claws")
	(rig["Patch"] as Node3D).visible = bp.parts.broken("hide")
	_eye_mi.material_override = PSXMat.glow(Color(1.0, 0.12, 0.08), 3.2) if phase >= 3 else null
	if phase >= 3 and _foam == null and state != S.DEAD:
		_foam = FX.flip_emitter(rig["Jaw"], "splash", 5, 0.18, 0.7, {"direction": Vector3(0, -1, -0.3), "spread": 30.0, "vel_min": 0.3,
			"vel_max": 0.8, "radius": 0.15, "gravity": Vector3(0, -4.0, 0), "color": Color(1, 1, 1, 0.85), "fade": 0.4, "range": 70.0})
		_foam.name = "Foam"
		_foam.position =Vector3(0, -0.1, -float(spec["head"].z) - float(spec["snout"]) * 0.6)
	elif phase < 3 and _foam:
		_foam.queue_free()
		_foam = null


func _on_die() -> void:
	super._on_die()
	if _breath:
		_breath.emitting = false
	if _foam:
		_foam.emitting = false


## Snow kicked up under each heavy step (every screen, from its own gait).
func _animate(delta: float) -> void:
	super._animate(delta)
	var s := signf(sin(_gait))
	if s != _step_s and _spd > 1.5 and state != S.DEAD:
		var leg := "FL" if s > 0.0 else "FR"
		var at := (rig["Ankle" + leg] as Node3D).global_position
		FX.puff(Vector3(at.x, global_position.y + 0.1, at.z), "snow", 2, 1.1 if _spd < 6.0 else 1.6, 0.8, Color.WHITE, 0.6, Vector3.UP)
	_step_s = s


func _pose_for(delta: float) -> void:
	super._pose_for(delta)
	if state != S.FIGHT:
		return
	match move:
		"roar":
			pose = {"rear": 1.5 if mv_t < 1.3 else 0.4, "head": 0.6, "jaw": 1.0 if mv_t > 0.5 else 0.4}
		"moment":
			if mv_t < BeastPass.MOMENT_REAR:
				pose = {"crouch": 0.55, "head": -0.45, "jaw": 0.4}
			else:
				pose = {"rear": 1.6, "head": 0.65, "jaw": 1.0}
		"maul":
			# (rears on its hind legs, then each swipe brings it down a little: the follow-through)
			pose = {"rear": 1.25 if mv_t < 0.6 else maxf(1.0 - (mv_t - 0.6) * 1.6, 0.1), "head": 0.25 if mv_t < 0.6 else -0.2, "jaw": 0.5}
		"slam":
			pose = {"rear": 1.7, "head": 0.4, "jaw": 0.8} if mv_t < 0.9 else {"crouch": 0.65, "head": -0.35, "stretch": 0.3}
		"charge":
			pose = {"crouch": 0.35, "head": -0.4, "rear": sin(mv_t * 14.0) * 0.06} if mv_t < 0.7 else {"head": -0.3, "stretch": 0.45}
		"swat":
			pose = {"rear": 0.35 if mv_t < 0.35 else 0.15, "head": 0.1}
		"scoop":
			pose = {"crouch": 0.55, "head": -0.65, "jaw": 0.3} if mv_t < 0.6 else {"rear": 0.4, "head": 0.2}
		"frenzy":
			pose = {"rear": 0.5 + sin(mv_t * 16.0) * 0.3, "jaw": 0.9}
		"avalanche":
			pose = {"rear": 1.7 if mv_t < 1.6 else 0.6, "head": 0.7, "jaw": 1.0 if mv_t > 0.6 else 0.5}
	if move == "" and mv_t < 0.0 and _last_move in ["slam", "frenzy"]:
		pose = {"crouch": 0.7, "head": -0.4, "jaw": 0.4}
