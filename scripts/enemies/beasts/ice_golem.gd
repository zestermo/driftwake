extends GiantBeast
## The Ice Golem (BeastPool "ice_golem", a snow island's boss; rebuilt in 1.20, docs/v1_20_beasts.md 8): a walking heap
## of packed ice and black rock on two legs, blue crystals grown from its shoulders and back, a cracked core glowing in
## its chest. Slow and very heavy.
##   hammer     an arm raised, frost gathering (0.7 s): an overhead smash in front, ice shards (push); fist stuck 1.2 s
##   stomp      a leg lifted (0.6 s): a frost ring round it (push); 0.8 s
##   ice_wall   hands to the ground (0.8 s): a line of ice spikes runs at you (push); 1.0 s
##   avalanche  (phase 2+) hugs itself, the core flaring (0.9 s): bursts, a ring of ice 7 m (its one knockdown); 1.6 s
##              with the core open (hits there do double)
##   reform     (phase 3) collapses into rubble and builds itself again a few metres off, flinging ice; 1.2 s
## Looks: glacier blue, black rock, pale.

const ICE_LOOKS := [
	[Color(0.62, 0.78, 0.9), Color(0.8, 0.9, 0.97), Color(0.3, 0.42, 0.55)],
	[Color(0.32, 0.34, 0.38), Color(0.56, 0.62, 0.7), Color(0.6, 0.8, 0.95)],
	[Color(0.85, 0.9, 0.95), Color(0.95, 0.97, 1.0), Color(0.55, 0.68, 0.8)],
]
const ICE := Color(0.7, 0.9, 1.0)
const HAMMER_R := 3.6
const STOMP_R := 4.2
const WALL_LEN := 12.0
const AVALANCHE_R := 7.0
const CORE_OPEN := 1.6

var _from := Vector3.ZERO
var _to := Vector3.ZERO
var _core_until := -1.0
var _core: MeshInstance3D


func _init() -> void:
	boss_name = "The Ice Golem"
	wake_r = 0.0


func _spec() -> Dictionary:
	var c: Array = ICE_LOOKS[variant % ICE_LOOKS.size()]
	return {"hip_h": 1.9, "torso": Vector3(1.25, 1.0, 0.9), "shoulder": 1.55, "arm": Vector2(1.3, 1.35), "arm_r": 0.42, "hand_r": 0.62,
		"leg_r": 0.5, "head": Vector3(0.48, 0.42, 0.45), "coat": c[0], "under": c[1], "mark": c[2], "tex": "ice", "eye": Color(0.5, 0.9, 1.0)}


## Black rock in the ice, crystal clusters on the shoulders and back, a brow of rock, the glowing core in the chest.
func _extras() -> void:
	var to: Vector3 = spec["torso"]
	var hd: Vector3 = spec["head"]
	var rng := _rng_fixed()
	var rock := PSXMat.lit("rock", Color(0.35, 0.36, 0.4))
	var crystal := PSXMat.glow(Color(0.45, 0.8, 1.0), 1.6)
	for k in range(6):
		var a := rng.randf() * TAU
		mb("Torso").add_blob(rock, Transform3D(Basis(Vector3.UP, a), Vector3(cos(a) * to.x * 0.8, to.y * rng.randf_range(0.5, 1.6), sin(a) * to.z * 0.8)), Vector3(0.45, 0.35, 0.4), rng, 0.3, 3, 5, 1.0)
	for s in [-1.0, 1.0]:
		for k in range(4):
			var at := Vector3(s * (to.x * 0.75 + k * 0.12), to.y * 1.85 + k * 0.05, rng.randf_range(-0.3, 0.4))
			mb("Torso").add_cylinder(crystal, Transform3D(Basis(Vector3.BACK, -s * (0.3 + k * 0.15)) * Basis(Vector3.RIGHT, rng.randf_range(-0.3, 0.3)), at), 0.18, 0.0, 0.9 + rng.randf() * 0.6, 4, 1.0)
	for k in range(5):
		mb("Torso").add_cylinder(crystal, Transform3D(Basis(Vector3.RIGHT, 0.5 + rng.randf() * 0.3), Vector3(rng.randf_range(-0.5, 0.5), to.y * (1.2 + k * 0.15), to.z * 0.7)), 0.16, 0.0, 0.8, 4, 1.0)
	mb("Head").add_box(rock, Transform3D(Basis(), Vector3(0, hd.y * 0.45, -hd.z * 0.55)), Vector3(hd.x * 2.1, hd.y * 0.35, hd.z * 0.6), 1.0)
	for s in [["L", -1.0], ["R", 1.0]]:
		mb("Hand" + s[0]).add_blob(rock, Transform3D(Basis(), Vector3(0, -float(spec["hand_r"]) * 0.9, 0)), Vector3(0.45, 0.35, 0.45), rng, 0.3, 3, 5, 1.0)
	# the core: a glowing heart behind cracked ice (its own node: it flares when the core opens)
	var cm := MeshBuilder.new()
	cm.add_blob(PSXMat.glow(Color(0.55, 0.85, 1.0), 2.4), Transform3D(), Vector3(0.38, 0.38, 0.2), rng, 0.2, 3, 6, 1.0)
	_core = cm.to_instance("Core")
	_core.position = Vector3(0, to.y * 1.2, -to.z * 0.85)
	(rig["Torso"] as Node3D).add_child(_core)


func _coat_at(p: Vector3) -> Color:
	var base := (spec["coat"] as Color).lerp(spec["under"], smoothstep(0.2, -0.6, p.y))
	var vein := smoothstep(0.7, 0.9, absf(sin(p.x * 4.0 + p.z * 2.3 + sin(p.y * 3.0))))
	return base.lerp(spec["mark"], vein * 0.6)


func _hp_base() -> float:
	return 1700.0


func _poise_max() -> float:
	return 280.0


func _phase_at() -> Array:
	return [0.6, 0.3]


func _xp_base() -> int:
	return 720


func _coins_base() -> int:
	return 42


func _speed() -> float:
	return 3.4 if phase < 3 else 4.4


func _wake_move() -> String:
	return "stomp"


func _ready() -> void:
	_cd = {"hammer": 0.5, "stomp": 2.0, "ice_wall": 3.0, "avalanche": 99.0, "reform": 99.0}
	super._ready()
	var to: Vector3 = spec["torso"]
	var hh: float = spec["hip_h"]
	hurt_ball(to.x * 1.1, Vector3(0, hh + to.y, 0))
	hurt_ball(to.x * 0.7, Vector3(0, hh * 0.5, 0))


func trophy(t: int) -> ItemData:
	return Gear.make("accessory", "cape", {"cape": true, "cape_color": spec["under"]}, "Rimeheart Mantle", t)


func _on_phase(n: int) -> void:
	if n >= 2:
		_cd["avalanche"] = 1.0
	if n >= 3:
		_cd["reform"] = 2.0
	say("bellow", global_position, 6.0, 0.55)


func _brain(delta: float, p: Node3D, to: Vector3, dist: float) -> Vector3:
	_face(to)
	var wants: Array = []
	if phase >= 3 and dist < 5.0:
		wants.append("reform")
	if phase >= 2 and dist < AVALANCHE_R - 1.0:
		wants.append("avalanche")
	if dist < HAMMER_R + 0.6:
		wants.append_array(["hammer", "stomp"])
	elif dist < WALL_LEN - 1.0:
		wants.append("ice_wall")
	var m := pick(wants)
	if m != "":
		begin(m)
		return Vector3.ZERO
	if dist > HAMMER_R - 0.5:
		var nd := _nav_dir(p.global_position, delta)
		_face(nd)
		return nd * _speed()
	return Vector3.ZERO


func _armoured() -> bool:
	return move == "avalanche"


func _parry_ok() -> bool:
	return move == "hammer" and mv_t > 0.55 and mv_t < 0.8


func _on_begin(m: String) -> void:
	super._on_begin(m)
	var p := _target()
	match m:
		"hammer":
			_cd["hammer"] = _rng.randf_range(2.0, 3.0)
			say("grunt", global_position, 0.0, 0.8)
		"stomp":
			_cd["stomp"] = _rng.randf_range(5.0, 7.0)
			warn_ring(global_position, STOMP_R, 0.6)
		"ice_wall":
			_cd["ice_wall"] = _rng.randf_range(6.0, 8.0)
			_from = global_position
			var d := _flat((p.global_position if p else global_position + _fwd()) - global_position).normalized()
			_face(d)
			_to = ground_at(global_position + d * WALL_LEN)
			warn_lane(_from, _to, 1.8, 0.8, ICE)
		"avalanche":
			_cd["avalanche"] = _rng.randf_range(10.0, 13.0)
			warn_ring(global_position, AVALANCHE_R, 0.9)
			say("bellow", global_position, 4.0, 0.6)
		"reform":
			_cd["reform"] = _rng.randf_range(12.0, 15.0)


func _move_tick(_delta: float, p: Node3D) -> Vector3:
	match move:
		"hammer":
			if p and mv_t < 0.4:
				_face(_flat(p.global_position - global_position))
			if mv_t > 0.7 and not _hit:
				_hit = true
				var at := global_position + _fwd() * 2.6
				strike("ring", [at, HAMMER_R * 0.6], 26.0, false, true)
				Net.fx("sparkle", [at + Vector3.UP * 0.5, 18, ICE])
				Net.fx("dust_ring", [at, 14, 1.0])
				quake(at, 0.6)
			if mv_t > 0.9:
				end_move(1.2)
		"stomp":
			if mv_t > 0.6 and not _hit:
				_hit = true
				strike("ring", [global_position, STOMP_R], 16.0, false, false, 1.0, 6.0)
				Net.fx("ring", [global_position + Vector3.UP * 0.1, Vector3.UP, STOMP_R, ICE, 0.4, 0.2])
				quake(global_position, 0.7)
			if mv_t > 0.8:
				end_move(0.8)
		"ice_wall":
			if mv_t > 0.8 and not _hit:
				_hit = true
				strike("lane", [_from, _to, 1.0], 20.0, false, false, 1.0, 7.0)
				for k in range(6):
					var at: Vector3 = _from.lerp(_to, (k + 1) / 6.0)
					Net.fx("sparkle", [at + Vector3.UP * 0.6, 8, ICE])
					Net.fx("dust", [at, 4, 0.6])
			if mv_t > 1.0:
				end_move(1.0)
		"avalanche":
			if mv_t > 0.9 and not _hit:
				_hit = true
				strike("ring", [global_position, AVALANCHE_R], 30.0, true)
				Net.fx("ring", [global_position + Vector3.UP * 0.2, Vector3.UP, AVALANCHE_R, ICE, 0.5, 0.3])
				Net.fx("sparkle", [global_position + Vector3.UP * 2.0, 40, ICE])
				quake(global_position, 1.4)
				_core_until = CORE_OPEN
				Net.event(self, "core", [CORE_OPEN])
			if mv_t > 1.1:
				end_move(CORE_OPEN)
		"reform":
			if mv_t > 0.6 and not _hit:
				_hit = true
				var side := _fwd().cross(Vector3.UP) * (1.0 if _rng.randf() < 0.5 else -1.0)
				var to := ground_at(global_position + side * 3.0)
				Net.fx("dust", [global_position + Vector3.UP, 12, 1.4])
				global_position = to
				reset_physics_interpolation()
			if mv_t > 1.2 and _hit and move == "reform":
				strike("ring", [global_position, 3.0], 14.0, false, false, 1.0, 6.0)
				Net.fx("sparkle", [global_position + Vector3.UP * 1.5, 24, ICE])
				end_move(1.2)
	return Vector3.ZERO


func _pose_for(delta: float) -> void:
	super._pose_for(delta)
	if _core:
		_core.scale = Vector3.ONE * (1.6 if _core_until > 0.0 else 1.0)
	if state != S.FIGHT:
		return
	match move:
		"hammer":
			pose = {"wind": 1.0, "lean": -0.1} if mv_t < 0.7 else {"swing": 1.0, "lean": 0.4, "crouch": 0.3}
		"stomp":
			pose = {"crouch": 0.0 if mv_t < 0.6 else 0.4, "spread": 0.5, "lean": -0.15 if mv_t < 0.6 else 0.2}
		"ice_wall":
			pose = {"reach": 1.0, "crouch": 0.6, "lean": 0.5}
		"avalanche":
			pose = {"hug": 1.0, "crouch": 0.3} if mv_t < 0.9 else {"spread": 1.0, "arms_up": 0.5, "lean": -0.3}
		"reform":
			pose = {"slump": 1.0} if mv_t < 0.9 else {"slump": clampf(1.0 - (mv_t - 0.9) / 0.3, 0.0, 1.0)}
	if move == "" and mv_t < 0.0 and _last_move == "hammer":
		pose = {"reach": 0.8, "lean": 0.4, "crouch": 0.3}


func _process(delta: float) -> void:
	super._process(delta)
	_core_until -= delta


## The core open after the avalanche: hits there do double.
func _on_hit(hit: HitData, attacker: Node) -> void:
	if _core_until > 0.0 and not hit.dot:
		hit.damage *= 2.0
	super._on_hit(hit, attacker)


func _event(what: String, args: Array) -> void:
	if what == "core":
		_core_until = float(args[0])
