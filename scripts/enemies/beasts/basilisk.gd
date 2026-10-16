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
	return {"hip_h": 1.05, "len": 3.0, "chest_r": 1.0, "hip_r": 0.9, "neck": Vector3(0, 0.05, -0.75), "head": Vector3(0.62, 0.42, 0.8),
		"snout": 0.85, "tail": 5.0, "tail_r": 0.55, "coat": c[0], "under": c[1], "mark": c[2], "tex": "scales", "ears": 0.05,
		"eye": Color(1.0, 0.85, 0.2)}


## A frill of spines round the neck, a crest down the back, horns over the eyes, banded scales.
func _extras() -> void:
	var hd: Vector3 = spec["head"]
	var cr: float = spec["chest_r"]
	var ln: float = spec["len"]
	var spine := PSXMat.flat((spec["mark"] as Color).lightened(0.2))
	var rng := _rng_fixed()
	for k in range(11):
		var a := -1.4 + k * 0.28
		mb("Neck").add_cylinder(spine, Transform3D(Basis(Vector3.BACK, a) * Basis(Vector3.RIGHT, 0.35), Vector3(sin(a) * cr * 0.55, cos(a) * cr * 0.55, 0.1)), 0.09, 0.0, 1.0 + (0.4 if k % 2 == 0 else 0.0), 4, 1.0, Color.WHITE, false, false, false)
	for k in range(10):
		var z := -ln * 0.6 + k * ln * 0.13
		mb("Body").add_cylinder(spine, Transform3D(Basis(Vector3.RIGHT, 0.25), Vector3(0, cr * 0.9, z)), 0.12, 0.0, 0.6 - absf(k - 4.5) * 0.04, 4, 1.0, Color.WHITE, false, false, false)
	for s in [-1.0, 1.0]:
		mb("Head").add_cylinder(spine, Transform3D(Basis(Vector3.RIGHT, 1.2) * Basis(Vector3.BACK, -s * 0.3), Vector3(s * hd.x * 0.55, hd.y * 0.65, -hd.z * 0.2)), 0.1, 0.0, 0.7, 4, 1.0, Color.WHITE, false, false, false)
	for i in range(4):
		mb("Tail%d" % i).add_cylinder(spine, Transform3D(Basis(Vector3.RIGHT, 0.4), Vector3(0, float(spec["tail_r"]) * 0.8, 0.3)), 0.08, 0.0, 0.4, 4, 1.0, Color.WHITE, false, false, false)
	mb("Tail3").add_blob(spec["coat_mat"], Transform3D(Basis(), Vector3(0, 0, float(spec["tail"]) * 0.25)), Vector3(0.6, 0.45, 0.7), rng, 0.2, 3, 7, 1.0, Color(0.8, 0.8, 0.8))


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


func _wake_move() -> String:
	return "charge"


func _ready() -> void:
	super._ready()
	_overhead.queue_free()
	_overhead = null


func _on_begin(m: String) -> void:
	super._on_begin(m)
	say("hiss", global_position, 4.0, 0.55, 110.0)


func trophy(t: int) -> ItemData:
	return Gear.make("accessory", "cape", {"cape": true, "cape_color": spec["coat"]}, "Basilisk Hide", t)
