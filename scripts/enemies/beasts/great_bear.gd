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


func _spec() -> Dictionary:
	var c: Array = BEAR_COATS[variant % BEAR_COATS.size()]
	return {"hip_h": 1.7, "len": 2.4, "chest_r": 1.15, "hip_r": 1.0, "neck": Vector3(0, -0.05, -0.55), "head": Vector3(0.6, 0.55, 0.62),
		"snout": 0.5, "tail": 0.3, "tail_r": 0.12, "coat": c[0], "under": c[1], "mark": c[2], "tex": "fur_white", "ears": 0.25,
		"eye": Color(0.3, 0.75, 1.0)}


## A shaggy hump, a ruff round the neck, black claws, a black nose.
func _extras() -> void:
	var hd: Vector3 = spec["head"]
	var sn: float = spec["snout"]
	var cr: float = spec["chest_r"]
	var ln: float = spec["len"]
	var black := PSXMat.flat(Color(0.06, 0.05, 0.05))
	mb("Head").add_box(black, Transform3D(Basis(), Vector3(0, -hd.y * 0.15, -hd.z * 0.95 - sn * 0.95)), Vector3(0.22, 0.14, 0.08), 1.0)
	mb("Body").add_blob(spec["coat_mat"], Transform3D(Basis(), Vector3(0, cr * 0.95, -ln * 0.35)), Vector3(cr * 0.7, cr * 0.42, ln * 0.3), _rng_fixed(), 0.2, 3, 7, 1.0, Color(0.95, 0.95, 0.95))
	for k in range(9):
		var a := -1.2 + k * 0.3
		mb("Neck").add_blob(spec["coat_mat"], Transform3D(Basis(), Vector3(sin(a) * cr * 0.6, cos(a) * cr * 0.45, -0.1)), Vector3(cr * 0.28, cr * 0.36, cr * 0.3), _rng_fixed(), 0.3, 3, 5, 1.0, Color(0.9, 0.9, 0.9))
	for leg in ["FL", "FR", "BL", "BR"]:
		for k in range(4):
			mb("Knee" + leg).add_cylinder(black, Transform3D(Basis(Vector3.RIGHT, -1.7), Vector3((k - 1.5) * 0.09, -float(spec["hip_h"]) * 0.5 + 0.08, -0.32)), 0.035, 0.0, 0.24, 3, 1.0, Color.WHITE, false, false, false)


func _coat_at(p: Vector3) -> Color:
	return (spec["coat"] as Color).lerp(spec["under"], smoothstep(-0.2, -0.6, p.y / maxf(float(spec["chest_r"]), 0.1))).lerp(spec["mark"], smoothstep(0.75, 1.0, p.y / maxf(float(spec["chest_r"]), 0.1)) * 0.3)


func _hp_base() -> float:
	return 1500.0


func _poise_max() -> float:
	return 220.0


func _phase_at() -> Array:
	return [0.5, 0.25]


func _xp_base() -> int:
	return 700


func _coins_base() -> int:
	return 40


func _speed() -> float:
	return 5.4 if phase < 3 else 6.6


func _wake_move() -> String:
	return "stomp"


func _ready() -> void:
	super._ready()
	_cd["stomp"] = 4.0
	_overhead.queue_free()
	_overhead = null


func trophy(t: int) -> ItemData:
	return Gear.make("accessory", "cape", {"cape": true, "cape_color": spec["coat"]}, "Bear King's Mantle", t)
