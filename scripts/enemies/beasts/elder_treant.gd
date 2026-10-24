extends GiantBeast
## The Elder Treant (BeastPool "elder_treant", a forest island's boss; rebuilt in 1.20, docs/v1_20_beasts.md 16): an oak
## grown old enough to walk, on two great root-legs, long branch arms ending in twig fingers, a crown of autumn leaves
## on its shoulders, a face in its bark with ember eyes, roots trailing. Slow and very heavy.
##   sweep      an arm drawn back, leaves rustling (0.6 s): a long low branch sweep in front (push); 1.0 s
##   root_slam  both arms up (0.9 s): slams them down, roots erupting in a line (its one knockdown); 1.6 s arms stuck
##   grasp      its feet glow (0.7 s): roots burst under you and hold you a moment (a long stagger); 0.8 s
##   pods       (phase 2+) shakes its crown: seed pods drop round you and burst (markers); 1.0 s
##   saplings   (phase 3) plants a root: roots erupt round it in a ring, three times
## Burning, it takes double damage; its bark turns half of every blow from the front unless it's getting over a move
## (hit it from behind, or in an opening). No bar over its head (the arena's). Looks: oak, birch-pale, burnt.

const BARKS := [
	[Color(1.0, 0.86, 0.7), Color(0.85, 0.72, 0.58), Color(0.6, 0.78, 0.36)],
	[Color(1.0, 1.0, 1.0), Color(0.9, 0.9, 0.88), Color(0.62, 0.74, 0.42)],
	[Color(0.45, 0.4, 0.38), Color(0.35, 0.32, 0.3), Color(1.0, 0.45, 0.15)],
]
const ROOT := Color(0.45, 0.32, 0.18)
const SWEEP_R := 4.5
const SLAM_LEN := 12.0
const GRASP_R := 2.5
const POD_R := 1.6

var _from := Vector3.ZERO
var _to := Vector3.ZERO
var _spots: Array = []
var _n := 0


func _init() -> void:
	boss_name = "The Elder Treant"
	wake_r = 0.0


func _spec() -> Dictionary:
	var c: Array = BARKS[variant % BARKS.size()]
	return {"hip_h": 2.1, "torso": Vector3(1.0, 1.25, 0.85), "shoulder": 1.25, "arm": Vector2(1.6, 1.7), "arm_r": 0.3, "hand_r": 0.35,
		"leg_r": 0.48, "head": Vector3(0.55, 0.6, 0.5), "coat": c[0], "under": c[1], "mark": c[2], "tex": "bark", "eye": Color(1.0, 0.6, 0.15)}


## The crown of leaves and boughs over the shoulders, twig fingers, a bark brow and a mouth, roots off the feet,
## moss on the shoulders.
func _extras() -> void:
	var to: Vector3 = spec["torso"]
	var hd: Vector3 = spec["head"]
	var rng := _rng_fixed()
	var bark: Material = spec["coat_mat"]
	var leaves := [PSXMat.lit("leaves", Color(0.92, 0.42, 0.12)), PSXMat.lit("leaves", Color(0.85, 0.62, 0.15))]
	var dark := PSXMat.flat(Color(0.08, 0.05, 0.03))
	# boughs up from the shoulders, the crown heaped on them
	for k in range(5):
		var a := -1.1 + k * 0.55
		var b0 := Vector3(sin(a) * to.x * 0.8, to.y * 1.9, cos(a) * 0.1 + 0.2)
		var b1 := b0 + Vector3(sin(a) * 1.0, 1.1, 0.3)
		mb("Torso").add_tube(bark, PackedVector3Array([b0, b0.lerp(b1, 0.5) + Vector3(0, 0.15, 0), b1]), 0.2, 0.08, 5, 1.0)
		mb("Torso").add_blob(leaves[k % 2], Transform3D(Basis(Vector3.UP, rng.randf() * TAU), b1 + Vector3(0, 0.35, 0)), Vector3(1.0, 0.75, 0.9), rng, 0.35, 3, 6, 0.8)
	mb("Torso").add_blob(leaves[0], Transform3D(Basis(), Vector3(0, to.y * 2.35, 0.4)), Vector3(1.6, 0.8, 1.2), rng, 0.35, 3, 6, 0.8)
	# twig fingers
	for s in ["L", "R"]:
		for k in range(4):
			var a := -0.6 + k * 0.4
			var f0 := Vector3(0, -float(spec["hand_r"]) * 0.8, 0)
			mb("Hand" + s).add_tube(bark, PackedVector3Array([f0, f0 + Vector3(sin(a) * 0.3, -0.45, -0.15), f0 + Vector3(sin(a) * 0.45, -0.9, -0.05)]), 0.07, 0.02, 4, 1.0)
	# the face: a heavy brow, a dark mouth
	mb("Head").add_box(bark, Transform3D(Basis(), Vector3(0, hd.y * 0.45, -hd.z * 0.7)), Vector3(hd.x * 1.9, hd.y * 0.3, hd.z * 0.5), 1.0)
	mb("Head").add_box(dark, Transform3D(Basis(), Vector3(0, -hd.y * 0.45, -hd.z * 0.92)), Vector3(hd.x * 0.9, hd.y * 0.18, 0.05), 1.0)
	# roots trailing off the feet
	for s in ["L", "R"]:
		for k in range(4):
			var a := TAU * (k + 0.5) / 4.0
			var r0 := Vector3(cos(a) * 0.35, 0.05, sin(a) * 0.35)
			mb("Foot" + s).add_tube(bark, PackedVector3Array([r0, r0 + Vector3(cos(a) * 0.5, -0.1, sin(a) * 0.5), r0 + Vector3(cos(a) * 0.9, -0.15, sin(a) * 0.9)]), 0.14, 0.03, 4, 1.0)
	# moss on the shoulders
	for s in [-1.0, 1.0]:
		mb("Torso").add_blob(PSXMat.lit("leaves", Color(0.42, 0.62, 0.26)), Transform3D(Basis(), Vector3(s * to.x * 0.85, to.y * 1.85, -0.1)), Vector3(0.45, 0.18, 0.4), rng, 0.3, 3, 5, 0.8)


func _coat_at(p: Vector3) -> Color:
	var base := (spec["coat"] as Color).lerp(spec["under"], smoothstep(0.0, -0.6, p.y))
	var moss := smoothstep(0.6, 0.9, sin(p.x * 2.4 + p.z * 1.3) * 0.5 + 0.5) * smoothstep(0.5, 1.5, p.y)
	# (bark: grain running up it in ridges, darker in the furrows)
	var grain := absf(sin(p.x * 9.0 + p.z * 5.0 + sin(p.y * 2.0) * 1.5))
	return base.lerp(spec["mark"], moss * 0.7).darkened(0.35 * smoothstep(0.6, 1.0, grain))


func _hp_base() -> float:
	return 2000.0


func _poise_max() -> float:
	return 340.0


func _phase_at() -> Array:
	return [0.6, 0.3]


func _xp_base() -> int:
	return 780


func _coins_base() -> int:
	return 46


func _speed() -> float:
	return 3.2 if phase < 3 else 4.2


func _wake_move() -> String:
	return "root_slam"


func _ready() -> void:
	_cd = {"sweep": 0.5, "root_slam": 3.0, "grasp": 2.0, "pods": 99.0, "saplings": 99.0}
	super._ready()
	var to: Vector3 = spec["torso"]
	var hh: float = spec["hip_h"]
	hurt_ball(to.x * 1.15, Vector3(0, hh + to.y, 0))
	hurt_ball(to.x * 0.7, Vector3(0, hh * 0.5, 0))


func trophy(t: int) -> ItemData:
	return Gear.make("accessory", "cape", {"cape": true, "cape_color": Color(0.62, 0.22, 0.1)}, "Mantle of Fallen Leaves", t)


func _on_phase(n: int) -> void:
	if n >= 2:
		_cd["pods"] = 1.0
	if n >= 3:
		_cd["saplings"] = 1.5
	say("branch", global_position, 6.0, 0.6)


func _brain(delta: float, p: Node3D, to: Vector3, dist: float) -> Vector3:
	_face(to)
	var wants: Array = []
	if phase >= 3 and dist < 8.0:
		wants.append("saplings")
	if phase >= 2 and dist < 12.0:
		wants.append("pods")
	if dist < SWEEP_R + 0.4:
		wants.append_array(["sweep", "grasp"])
	elif dist < SLAM_LEN - 1.0:
		wants.append_array(["root_slam", "grasp"])
	var m := pick(wants)
	if m != "":
		begin(m)
		return Vector3.ZERO
	if dist > SWEEP_R - 0.5:
		var nd := _nav_dir(p.global_position, delta)
		_face(nd)
		return nd * _speed()
	return Vector3.ZERO


func _parry_ok() -> bool:
	return move == "sweep" and mv_t > 0.45 and mv_t < 0.7


func _on_begin(m: String) -> void:
	super._on_begin(m)
	var p := _target()
	var at: Vector3 = p.global_position if p else global_position + _fwd() * 4.0
	_n = 0
	match m:
		"sweep":
			_cd["sweep"] = _rng.randf_range(1.8, 2.6)
			say("leaves", global_position, 0.0, 0.8)
		"root_slam":
			_cd["root_slam"] = _rng.randf_range(6.0, 8.0)
			_from = global_position
			var d := _flat(at - global_position).normalized()
			_face(d)
			_to = ground_at(global_position + d * SLAM_LEN)
			warn_lane(_from, _to, 2.2, 0.9, ROOT)
			say("branch", global_position, 2.0, 0.7)
		"grasp":
			_cd["grasp"] = _rng.randf_range(5.0, 7.0)
			_to = ground_at(at)
			warn_ring(_to, GRASP_R, 0.7, ROOT)
		"pods":
			_cd["pods"] = _rng.randf_range(9.0, 11.0)
			shower(global_position + Vector3.UP * 5.0, 24, 2.5)
			_spots = []
			for k in range(5):
				var a := TAU * k / 5.0 + _rng.randf() * 0.6
				var s := ground_at(at + Vector3(cos(a), 0, sin(a)) * _rng.randf_range(1.0, 3.5))
				_spots.append(s)
				warn_ring(s, POD_R, 1.0, Color(0.9, 0.55, 0.15))
		"saplings":
			_cd["saplings"] = _rng.randf_range(12.0, 15.0)
			say("branch", global_position, 4.0, 0.5)


func _move_tick(_delta: float, p: Node3D) -> Vector3:
	match move:
		"sweep":
			if p and mv_t < 0.35:
				_face(_flat(p.global_position - global_position))
			if mv_t > 0.6 and not _hit:
				_hit = true
				strike("cone", [global_position, _fwd(), SWEEP_R, 120.0], 18.0, false, true, 1.1, 8.0)
				shower(global_position + _fwd() * 2.0 + Vector3.UP * 2.0, 10, 2.0)
			if mv_t > 0.8:
				end_move(1.0)
		"root_slam":
			if mv_t > 0.9 and not _hit:
				_hit = true
				strike("lane", [_from, _to, 1.1], 28.0, true)
				for k in range(6):
					Net.fx("dust", [_from.lerp(_to, (k + 1) / 6.0), 6, 0.9])
				quake(global_position + _fwd() * 2.0, 1.0)
			if mv_t > 1.1:
				end_move(1.6)
		"grasp":
			if mv_t > 0.7 and not _hit:
				_hit = true
				strike("ring", [_to, GRASP_R], 10.0, false, false, 1.0, 1.0)
				Net.fx("dust_ring", [_to, 12, 0.8])
				get_node("/root/CombatManager").apply_camera_shake(0.15)
			if mv_t > 0.9:
				end_move(0.8)
		"pods":
			if mv_t > 1.0 and not _hit:
				_hit = true
				for s in _spots:
					strike("ring", [s, POD_R], 14.0, false, false, 1.0, 5.0)
					Net.fx("dust", [s + Vector3.UP * 0.3, 8, 1.0])
					Net.fx("sparkle", [s + Vector3.UP * 0.5, 8, Color(0.95, 0.7, 0.2)])
			if mv_t > 1.2:
				end_move(1.0)
		"saplings":
			# three rings of roots erupting round it, wider each time
			if _n < 3 and mv_t > 0.6 + _n * 0.7:
				var r := 3.0 + _n * 2.5
				if _n < 2:
					warn_ring(global_position, r + 2.5, 0.7, ROOT)
				strike("ring", [global_position, r], 14.0, false, false, 1.0, 6.0)
				Net.fx("dust_ring", [global_position, 18, r * 0.35])
				_n += 1
			if mv_t > 2.4:
				end_move(1.2)
	return Vector3.ZERO


func _pose_for(delta: float) -> void:
	super._pose_for(delta)
	if state != S.FIGHT:
		return
	match move:
		"sweep":
			pose = {"wind": 1.0, "twist": 0.4} if mv_t < 0.6 else {"swing": 1.0, "twist": -0.5, "lean": 0.2}
		"root_slam":
			pose = {"arms_up": 1.0, "lean": -0.2} if mv_t < 0.9 else {"reach": 1.0, "lean": 0.6, "crouch": 0.5}
		"grasp":
			pose = {"spread": 0.8, "crouch": 0.3}
		"pods":
			pose = {"lean": -0.2 + sin(mv_t * 18.0) * 0.1, "spread": 0.6}
		"saplings":
			pose = {"reach": 1.0, "crouch": 0.6, "lean": 0.4}
	if move == "" and mv_t < 0.0 and _last_move == "root_slam":
		pose = {"reach": 1.0, "lean": 0.6, "crouch": 0.5}


## Burning, it takes double; its bark turns half of a blow from the front, unless it's getting over a move.
func _on_hit(hit: HitData, attacker: Node) -> void:
	var k := 1.0
	for c in get_children():
		if c is BurnStatus:
			k = 2.0
	if not hit.dot and attacker is Node3D and not (move == "" and mv_t < 0.0):
		var from := _flat((attacker as Node3D).global_position - global_position).normalized()
		if from.dot(_fwd()) > 0.5:
			k *= 0.5
	hit.damage *= k
	super._on_hit(hit, attacker)
