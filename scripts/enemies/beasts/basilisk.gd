extends "res://scripts/enemies/beasts/alpha_boar.gd"
## The Basilisk (BeastPool "basilisk", a desert island's boss): a lizard the length of a
## house, low-slung and armoured, a frill of spines round its neck and a crest down its back,
## a club of a tail. The alpha boar's brain at a boss's scale: it hisses with its frill up and
## runs you down a line (the charge), snaps its jaws in front (parry it: it reels), and from
## half health rears and slams down, a ring of sand round it (jump it). Looks: dune ochre,
## basalt grey, copper green.

const LOOKS := [
	[Color(0.72, 0.56, 0.32), Color(0.9, 0.8, 0.58), Color(0.42, 0.24, 0.1)],
	[Color(0.38, 0.37, 0.36), Color(0.6, 0.58, 0.54), Color(0.75, 0.3, 0.12)],
	[Color(0.36, 0.48, 0.36), Color(0.68, 0.72, 0.52), Color(0.82, 0.62, 0.2)],
]


func _init() -> void:
	boss_name = "The Basilisk"
	wake_r = 0.0
	charge_len = 18.0
	charge_speed = 14.0
	gore_r = 4.2
	stomp_r = 6.6


func _spec() -> Dictionary:
	var c: Array = LOOKS[variant % LOOKS.size()]
	# (1.20: rebuilt on the quadruped rig, docs/v1_20_beasts.md 12: low and long on sprawled clawed legs, a longer neck
	# with a flat wedge of a head, the frill a fan of membrane between its spines, a long tapering tail)
	return {"hip_h": 0.95, "len": 3.4, "chest_r": 0.78, "hip_r": 0.72, "neck": Vector3(0, 0.4, -1.0), "head": Vector3(0.5, 0.3, 0.78),
		"snout": 0.8, "tail": 5.0, "tail_r": 0.42, "coat": c[0], "under": c[1], "mark": c[2], "tex": "scales", "ears": 0.0,
		"eye": Color(1.0, 0.85, 0.2), "sprawl": 0.8, "foot": "claw", "leg_k": 1.1, "bend": 1.2}


## A frill fanned out behind the head (spines with membrane between), a crest down the back, horns over the eyes,
## banded scales.
func _extras() -> void:
	var hd: Vector3 = spec["head"]
	var cr: float = spec["chest_r"]
	var ln: float = spec["len"]
	var spine := PSXMat.flat((spec["mark"] as Color).lightened(0.2))
	var skin := PSXMat.lit("leather", (spec["mark"] as Color).lightened(0.35))
	var rng := _rng_fixed()
	var nk: Vector3 = spec["neck"]
	for k in range(11):
		var a := -1.4 + k * 0.28
		var r := 1.0 + (0.35 if k % 2 == 0 else 0.0)
		var at := nk * 0.85 + Vector3(sin(a) * cr * 0.35, cos(a) * cr * 0.35, 0.2)
		mb("Neck").add_cylinder(spine, Transform3D(Basis(Vector3.BACK, a) * Basis(Vector3.RIGHT, 0.35), at), 0.07, 0.0, r, 4, 1.0, Color.WHITE, false, false, false)
		# the membrane: a thin vane from this spine toward the next
		if k < 10:
			var b := a + 0.14
			mb("Neck").add_box(skin, Transform3D(Basis(Vector3.BACK, b) * Basis(Vector3.RIGHT, 0.35), at + Basis(Vector3.BACK, b) * Vector3(0, r * 0.42, 0)), Vector3(0.26, r * 0.8, 0.03), 1.0, Color.WHITE, false)
	for k in range(10):
		var z := -ln * 0.6 + k * ln * 0.13
		mb("Body").add_cylinder(spine, Transform3D(Basis(Vector3.RIGHT, 0.25), Vector3(0, cr * 0.9, z)), 0.12, 0.0, 0.6 - absf(k - 4.5) * 0.04, 4, 1.0, Color.WHITE, false, false, false)
	for s in [-1.0, 1.0]:
		mb("Head").add_cylinder(spine, Transform3D(Basis(Vector3.RIGHT, 1.2) * Basis(Vector3.BACK, -s * 0.3), Vector3(s * hd.x * 0.55, hd.y * 0.65, -hd.z * 0.2)), 0.1, 0.0, 0.7, 4, 1.0, Color.WHITE, false, false, false)
	for i in range(4):
		mb("Tail%d" % i).add_cylinder(spine, Transform3D(Basis(Vector3.RIGHT, 0.4), Vector3(0, float(spec["tail_r"]) * 0.8, 0.3)), 0.08, 0.0, 0.4, 4, 1.0, Color.WHITE, false, false, false)
	# (a tapering tail for its whip, a small flat spade at the tip)
	mb("Tail3").add_box(spine, Transform3D(Basis(Vector3.UP, PI * 0.25), Vector3(0, 0, float(spec["tail"]) * 0.25)), Vector3(0.38, 0.05, 0.38), 1.0, Color.WHITE, false)


## Banded across the back, pale underneath.
func _coat_at(p: Vector3) -> Color:
	var base := (spec["coat"] as Color).lerp(spec["under"], smoothstep(-0.2, -0.6, p.y / maxf(float(spec["chest_r"]), 0.1)))
	var band := smoothstep(0.55, 0.8, absf(sin(p.z * 2.2)))
	return base.lerp(spec["mark"], band * 0.45 * smoothstep(-0.1, 0.4, p.y))


func _hp_base() -> float:
	return 1650.0


func _poise_max() -> float:
	return 240.0


func _phase_at() -> Array:
	return [0.5, 0.25]


func _xp_base() -> int:
	return 700


func _coins_base() -> int:
	return 40


func _speed() -> float:
	return 5.0 if phase < 3 else 6.2



func _ready() -> void:
	super._ready()
	_overhead.queue_free()
	_overhead = null


func _on_begin(m: String) -> void:
	super._on_begin(m)
	say("hiss", global_position, 4.0, 0.55, 110.0)


func trophy(t: int) -> ItemData:
	return Gear.make("accessory", "cape", {"cape": true, "cape_color": spec["coat"]}, "Basilisk Hide", t)


# 1.20's moves (docs/v1_20_beasts.md 12), as a table: its one knockdown the burrow run. The gaze holds only a
# captain facing it (look away); basking heals it until it's struck (knocked off: an opening).
const GAZE_R := 10.0
const GAZE_DEG := 50.0


func _table() -> Dictionary:
	var gold := Color(1.0, 0.85, 0.2)
	return {
		"bask": {"phase": 2, "min": 6.0, "max": 30.0, "cd": [14.0, 18.0], "tell": 3.5, "shape": "none", "rec": 0.4, "fx": "none",
			"pose": [{"rear": 0.5, "head": 0.5}, {"rear": 0.5, "head": 0.5}, {"crouch": 0.6}]},
		"gaze": {"min": 3.0, "max": GAZE_R, "cd": [7.0, 9.0], "tell": 0.8, "shape": "none", "rec": 1.0, "fx": "none", "say": ["hiss", 0.7],
			"pose": [{"rear": 0.3, "head": 0.25, "jaw": 0.4}, {"head": 0.2, "jaw": 1.0}, {}]},
		"tail": {"max": 5.0, "cd": [3.0, 4.0], "tell": 0.5, "shape": "behind", "r": 5.0, "deg": 150.0, "dmg": 18.0, "kb": 9.0, "rec": 0.8,
			"pose": [{"tail": 1.0, "crouch": 0.3}, {"tail": 0.0}, {}]},
		"bite": {"max": 4.0, "cd": [1.6, 2.4], "tell": 0.4, "shape": "cone", "r": 3.6, "deg": 50.0, "dmg": 20.0, "kb": 7.0, "parry": true, "rec": 0.6,
			"pose": [{"head": 0.3, "jaw": 0.3}, {"head": -0.3, "jaw": 1.0}, {"head": -0.2}]},
		"burrow": {"min": 6.0, "max": 18.0, "cd": [7.0, 9.0], "tell": 0.9, "shape": "charge", "len": 16.0, "w": 1.6, "speed": 14.0, "dmg": 28.0, "knock": true,
			"rec": 1.4, "col": gold, "pose": [{"crouch": 0.9, "head": -0.4}, {"crouch": 0.6, "stretch": 0.6}, {"crouch": 0.3}]},
	}


func _wake_move() -> String:
	return "bite"


var _bask_hp := 0.0


func _table_tick(m: String, _e: Dictionary, _p: Node3D) -> Vector3:
	if m != "bask":
		return Vector3.INF
	if mv_t < 0.05:
		_bask_hp = health.current_health
	# struck while basking: knocked off it, an opening
	if health.current_health < _bask_hp - 1.0:
		say("hiss", global_position, 2.0, 1.3)
		end_move(1.6)
		return Vector3.ZERO
	health.current_health = minf(health.max_health, health.current_health + health.max_health * 0.03 / float(Engine.physics_ticks_per_second))
	_bask_hp = health.current_health
	return Vector3.INF


func _on_table_hit(m: String, _e: Dictionary, _at: Vector3) -> void:
	if m == "gaze":
		var args := [global_position + Vector3.UP * 1.0, _fwd(), GAZE_R, GAZE_DEG]
		Net.fx("sparkle", [global_position + _fwd() * 1.5 + Vector3.UP * 1.2, 20, Color(1.0, 0.9, 0.3)])
		_gaze_local(args)
		Net.event(self, "gaze", args)


## Each screen judges its own captain: in the cone and facing the basilisk, held (a long stagger).
func _gaze_local(args: Array) -> void:
	var me := get_tree().get_first_node_in_group("player") as Node3D
	if me == null or not me.has_node("Hurtbox"):
		return
	var at: Vector3 = args[0]
	if not BeastShapes.inside("cone", [at, args[1], float(args[2]), float(args[3])], me.global_position, 1.1):
		return
	var look: Vector3 = -(me.get("player_model") as Node3D).global_basis.z if me.get("player_model") else Vector3.ZERO
	var to := _flat(at - me.global_position).normalized()
	if _flat(look).normalized().dot(to) < 0.3:
		return
	var hd := HitData.new()
	hd.damage = _dmg(4.0)
	hd.unblockable = true
	hd.knockback_force = 0.0
	hd.stagger_duration = 2.0
	hd.hitstop_duration = 0.05
	(me.get_node("Hurtbox") as Hurtbox).take_hit(hd, self)


func _event(what: String, args: Array) -> void:
	if what == "gaze":
		_gaze_local(args)
	else:
		super._event(what, args)
