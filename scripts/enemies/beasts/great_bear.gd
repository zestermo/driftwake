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


## (1.20: rebuilt on the quadruped rig's new keys, docs/v1_20_beasts.md 7: high humped shoulders over thick forelegs,
## broad pads, the head carried low, a stub tail, a heavy lumbering walk)
func _spec() -> Dictionary:
	var c: Array = BEAR_COATS[variant % BEAR_COATS.size()]
	return {"hip_h": 1.6, "front_h": 1.95, "len": 2.8, "chest_r": 0.95, "hip_r": 0.8, "neck": Vector3(0, -0.15, -0.7), "head": Vector3(0.55, 0.47, 0.55),
		"snout": 0.42, "tail": 0.32, "tail_r": 0.16, "coat": c[0], "under": c[1], "mark": c[2], "tex": "fur_white", "ears": 0.0,
		"eye": Color(0.3, 0.75, 1.0), "hump": 1.0, "leg_k": 1.25, "front_k": 1.15, "foot": "pad", "tail_kind": "stub", "gait": "lumber", "bend": 1.7}


## A shaggy hump and ruff, a brow, small round ears, a black nose and lip, a fringe of fur under the belly,
## black sickle claws on every pad.
func _extras() -> void:
	var hd: Vector3 = spec["head"]
	var sn: float = spec["snout"]
	var cr: float = spec["chest_r"]
	var hr: float = spec["hip_r"]
	var ln: float = spec["len"]
	var hh: float = spec["hip_h"]
	var lift: float = float(spec["front_h"]) - hh
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
		for k in range(4):
			mb(foot_part(leg)).add_cylinder(black, Transform3D(Basis(Vector3.RIGHT, -1.75), Vector3((k - 1.5) * thick * 0.42, foot_y(leg) + thick * 0.22, -thick * 1.75)), thick * 0.1, 0.0, thick * 0.75, 3, 1.0, Color.WHITE, false, false, false)


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
