extends "res://scripts/enemies/beasts/basilisk.gd"
## The magma salamander (BeastPool "salamander", the volcanic isle's boss, in the caldera: docs/volcanic_island_plan.md):
## a salamander the length of a ship's boat, low and supple, black crust plates over a body that glows orange in every
## seam, frilled gills of fire at its jaw, a flat paddle of a tail. On the beast pass (1.23): its fight erupts in phases,
## each roaring in new moves (a moment: it rears and a ring pushes everyone back):
##   phase 1  bite (a snap in front: parry it), spit (a gout of magma down a line), tail (a sweep behind)
##   phase 2  dive: it sinks into the molten floor and swims under it, only a burning wake to show where, then bursts
##            up under where you stood (a red ring first: its one knockdown); eruption: the caldera's vents burst,
##            magma bombs in red rings round you
##   phase 3  firestorm: rivers of magma split the floor in lanes
## Under the floor it can't be struck. Looks: ember orange, white-hot, blue-flame.

const LOOKS_S := [
	[Color(0.16, 0.13, 0.12), Color(1.0, 0.45, 0.1), Color(0.05, 0.04, 0.04)],
	[Color(0.22, 0.2, 0.2), Color(1.0, 0.85, 0.5), Color(0.08, 0.07, 0.07)],
	[Color(0.12, 0.13, 0.17), Color(0.4, 0.7, 1.0), Color(0.04, 0.04, 0.06)],
]
## The dive: sinking, swimming under the floor toward its quarry, the ring before it bursts up, the burst's reach.
const SINK := 0.35
const SWIM := 2.4
const SWIM_SPEED := 9.0
const RISE_WARN := 0.9
const RISE_R := 3.8

var _under := false
var _rise := Vector3.ZERO
var _wake_t := 0.0


func _init() -> void:
	boss_name = "The Magma Salamander"
	wake_r = 0.0
	charge_len = 16.0
	charge_speed = 13.0
	gore_r = 4.0
	stomp_r = 6.0


func _glow_col() -> Color:
	return (LOOKS_S[variant % LOOKS_S.size()][1] as Color)


func _spec() -> Dictionary:
	var c: Array = LOOKS_S[variant % LOOKS_S.size()]
	return {"hip_h": 0.85, "len": 3.8, "chest_r": 0.8, "hip_r": 0.74, "neck": Vector3(0, 0.25, -0.8), "head": Vector3(0.62, 0.32, 0.8),
		"snout": 0.55, "tail": 4.4, "tail_r": 0.5, "coat": c[0], "under": c[1].darkened(0.3), "mark": c[2], "tex": "volcanic_basalt", "ears": 0.0,
		"eye": c[1], "sprawl": 0.9, "foot": "claw", "leg_k": 1.0, "bend": 1.3}


## Crust plates down its back with fire in the seams, frilled gills of flame at the jaw, a glowing belly line, a
## flattened paddle at the tail's end.
func _extras() -> void:
	var hd: Vector3 = spec["head"]
	var cr: float = spec["chest_r"]
	var ln: float = spec["len"]
	var glow_c := _glow_col()
	var fire := PSXMat.glow(glow_c, 2.6)
	var crust := PSXMat.lit("volcanic_basalt", Color(0.7, 0.66, 0.66), {"affine": 0.6})
	var rng := _rng_fixed()
	for k in range(9):
		var z := -ln * 0.55 + k * ln * 0.135
		var s := 0.55 - absf(k - 4) * 0.04
		mb("Body").add_blob(crust, Transform3D(Basis(Vector3.RIGHT, 0.2), Vector3(rng.randf_range(-0.1, 0.1), cr * 0.9, z)), Vector3(s, 0.16, s * 0.7), rng, 0.25, 3, 6, 0.6)
		mb("Body").add_box(fire, Transform3D(Basis(), Vector3(0, cr * 0.84, z + s * 0.55)), Vector3(s * 1.3, 0.06, 0.08))
		for side in [-1.0, 1.0]:
			mb("Body").add_box(fire, Transform3D(Basis(Vector3.FORWARD, side * 0.5), Vector3(side * cr * 0.8, cr * 0.35, z)), Vector3(0.05, 0.3, 0.22))
	mb("Body").add_box(fire, Transform3D(Basis(), Vector3(0, -cr * 0.85, 0)), Vector3(0.3, 0.04, ln * 0.9))
	for s in [-1.0, 1.0]:
		for j in range(3):
			var at := Vector3(s * hd.x * 0.85, hd.y * (0.1 - j * 0.25), hd.z * 0.35)
			mb("Head").add_cylinder(fire, Transform3D(Basis(Vector3.FORWARD, s * (1.2 + j * 0.25)) * Basis(Vector3.RIGHT, 0.6), at), 0.08, 0.0, 0.7 - j * 0.1, 4, 1.0, Color.WHITE, false, false, false)
		mb("Head").add_box(fire, Transform3D(Basis(), Vector3(s * hd.x * 0.5, hd.y * 0.45, -hd.z * 0.4)), Vector3(0.12, 0.06, 0.12))
	for i in range(4):
		mb("Tail%d" % i).add_box(fire, Transform3D(Basis(), Vector3(0, float(spec["tail_r"]) * (0.7 - i * 0.12), 0.3)), Vector3(0.06, 0.05, 0.6))
	mb("Tail3").add_box(crust, Transform3D(Basis(), Vector3(0, 0, float(spec["tail"]) * 0.25)), Vector3(0.9, 0.08, 0.7), 1.0, Color.WHITE, false)


func _coat_at(p: Vector3) -> Color:
	return (spec["coat"] as Color).lerp(spec["under"], smoothstep(-0.25, -0.65, p.y / maxf(float(spec["chest_r"]), 0.1)))


func _hp_base() -> float:
	return 1900.0


func _phase_at() -> Array:
	return [0.66, 0.33]


func _xp_base() -> int:
	return 820


func _coins_base() -> int:
	return 48


func _speed() -> float:
	return 5.2 if phase < 3 else 6.4


func _pass_moves() -> Array:
	return [["bite", "spit", "tail"], ["dive", "eruption"], ["firestorm"]]


func _chain_waits() -> Array:
	return ["dive", "eruption", "firestorm"]


func _moment_color() -> Color:
	return _glow_col()


func trophy(t: int) -> ItemData:
	return Gear.make("accessory", "cape", {"cape": true, "cape_color": _glow_col().darkened(0.3)}, "Salamander's Mantle", t)


func _table() -> Dictionary:
	var fire := Color(1.0, 0.4, 0.1)
	# (the big ones first: the pick takes the first ready, and in a chain the small ones are always ready)
	return {
		"firestorm": {"phase": 3, "max": 22.0, "cd": [10.0, 13.0], "tell": 1.2, "shape": "lanes", "n": 3, "len": 24.0, "w": 1.4, "dmg": 20.0, "kb": 6.0, "rec": 1.2,
			"fx": "sparkle", "col": fire, "say": ["hiss", 0.45], "pose": [{"rear": 0.7, "head": 0.6, "jaw": 1.0}, {"head": -0.3, "jaw": 0.6}, {}]},
		"eruption": {"phase": 2, "max": 20.0, "cd": [9.0, 12.0], "tell": 1.4, "shape": "spots", "n": 6, "r": 2.6, "dmg": 22.0, "kb": 8.0, "rec": 1.1,
			"fx": "quake", "col": fire, "say": ["hiss", 0.5], "pose": [{"rear": 0.9, "head": 0.6, "jaw": 1.0}, {"head": -0.2}, {}]},
		"dive": {"phase": 2, "min": 5.0, "max": 26.0, "cd": [8.0, 10.0], "tell": 0.6, "shape": "none", "dmg": 28.0, "knock": true, "rec": 1.3, "fx": "none",
			"col": fire, "say": ["hiss", 0.6], "pose": [{"crouch": 0.8, "head": -0.5}, {"crouch": 0.9}, {"rear": 0.6, "head": 0.5, "jaw": 1.0}]},
		"bite": {"max": 4.2, "cd": [1.6, 2.4], "tell": 0.45, "shape": "cone", "r": 3.8, "deg": 55.0, "dmg": 22.0, "kb": 7.0, "parry": true, "rec": 0.6,
			"pose": [{"head": 0.3, "jaw": 0.3}, {"head": -0.3, "jaw": 1.0}, {"head": -0.2}]},
		"spit": {"min": 4.0, "max": 16.0, "cd": [4.0, 6.0], "tell": 0.6, "shape": "lane", "len": 16.0, "w": 1.2, "dmg": 18.0, "kb": 5.0, "rec": 0.8,
			"fx": "sparkle", "col": fire, "say": ["hiss", 0.8], "pose": [{"head": 0.45, "jaw": 0.4}, {"head": -0.1, "jaw": 1.0}, {}]},
		"tail": {"max": 5.5, "cd": [3.0, 4.0], "tell": 0.5, "shape": "behind", "r": 5.5, "deg": 150.0, "dmg": 20.0, "kb": 9.0, "rec": 0.8,
			"pose": [{"tail": 1.0, "crouch": 0.3}, {"tail": 0.0}, {}]},
	}


func _wake_move() -> String:
	return "bite"


func _pose_for(delta: float) -> void:
	super._pose_for(delta)
	if move == "moment":
		pose = {"rear": 1.0 if mv_t < BeastPass.MOMENT_RING else 0.3, "head": 0.6, "jaw": 1.0}


## The dive: down into the molten floor after its tell, swimming at its quarry under a burning wake; a red ring where
## they stood; up through it.
func _table_tick(m: String, e: Dictionary, p: Node3D) -> Vector3:
	if m != "dive":
		return Vector3.INF
	var tell := float(e.get("tell", 0.6))
	if mv_t < tell:
		return Vector3.ZERO
	if not _under and _rise == Vector3.ZERO:
		_set_under(true)
		Net.fx("embers", [global_position + Vector3.UP * 0.5, Vector3.UP, 24])
		Net.fx("sfx", ["fire_burst", global_position, 2.0, 0.1])
	var swim_end := tell + SINK + SWIM
	if mv_t < swim_end:
		_wake_t -= 1.0 / float(Engine.physics_ticks_per_second)
		if _wake_t <= 0.0:
			_wake_t = 0.15
			Net.fx("embers", [global_position + Vector3.UP * 0.2, Vector3.UP, 6])
			Net.fx("dust", [global_position, 3, 0.9])
		if p == null or mv_t < tell + SINK:
			return Vector3.ZERO
		var to := _flat(p.global_position - global_position)
		if to.length() < 3.0:
			return Vector3.ZERO
		_face(to.normalized())
		return to.normalized() * SWIM_SPEED
	if _rise == Vector3.ZERO:
		_rise = p.global_position if p else global_position
		warn_ring(_rise, RISE_R, RISE_WARN, e.get("col", Color(1.0, 0.4, 0.1)))
		return Vector3.ZERO
	if mv_t < swim_end + RISE_WARN:
		return Vector3.ZERO
	if _under:
		global_position = _rise
		_set_under(false)
		strike("ring", [_rise, RISE_R], float(e.get("dmg", 28.0)), true, false, 1.1, 10.0, 0.5)
		quake(_rise, 1.0)
		Net.fx("embers", [_rise + Vector3.UP * 0.5, Vector3.UP, 30])
		Net.fx("sfx", ["fire_blast", _rise, 4.0, 0.1])
	if mv_t > swim_end + RISE_WARN + 0.4:
		_rise = Vector3.ZERO
		end_move(float(e.get("rec", 1.3)))
	return Vector3.ZERO


## Under the floor: unseen and unhittable, on every screen.
func _set_under(on: bool) -> void:
	_under_local(on)
	Net.event(self, "under", [on])


func _under_local(on: bool) -> void:
	_under = on
	model.visible = not on
	hurtbox.set_deferred("monitorable", not on)
	# (nobody bumps into it under the floor: its body keeps only the ground)
	collision_layer = 0 if on else BODY_LAYER


func _event(what: String, args: Array) -> void:
	if what == "under":
		_under_local(bool(args[0]))
	else:
		super._event(what, args)


func end_move(recover: float = 0.0) -> void:
	if _under:
		_under_local(false)
		Net.event(self, "under", [false])
	_rise = Vector3.ZERO
	super.end_move(recover)


func _on_table_hit(m: String, _e: Dictionary, at: Vector3) -> void:
	if m in ["spit", "eruption", "firestorm"]:
		Net.fx("embers", [at, Vector3.UP, 14])
