extends "res://scripts/enemies/beasts/alpha_boar.gd"
## The Ice Golem (BeastPool "ice_golem", a snow island's boss): a hulking four-legged
## thing of packed ice and black rock, blue crystals grown out of its back that glow in
## the dark, slow and very heavy. The alpha boar's brain at a boss's scale: a long
## grinding charge down a line, a sweep of its crystal-horned head in front (parry it: it
## reels), and its stomp, a ring of shattering ice round it, from the start. Looks: glacier
## blue, black-rock, pale.

const ICE_LOOKS := [
	[Color(0.62, 0.78, 0.9), Color(0.8, 0.9, 0.97), Color(0.3, 0.42, 0.55)],
	[Color(0.32, 0.34, 0.38), Color(0.56, 0.62, 0.7), Color(0.6, 0.8, 0.95)],
	[Color(0.85, 0.9, 0.95), Color(0.95, 0.97, 1.0), Color(0.55, 0.68, 0.8)],
]


func _init() -> void:
	boss_name = "The Ice Golem"
	wake_r = 0.0
	charge_len = 20.0
	charge_speed = 11.0
	gore_r = 4.4
	stomp_r = 7.0


func _spec() -> Dictionary:
	var c: Array = ICE_LOOKS[variant % ICE_LOOKS.size()]
	return {"hip_h": 1.9, "len": 2.6, "chest_r": 1.25, "hip_r": 1.05, "neck": Vector3(0, -0.1, -0.5), "head": Vector3(0.7, 0.55, 0.7),
		"snout": 0.3, "tail": 0.6, "tail_r": 0.2, "coat": c[0], "under": c[1], "mark": c[2], "tex": "ice_block", "ears": 0.1,
		"eye": Color(0.4, 0.85, 1.0)}


## Crystal spines down its back and on its brow, glowing; plates of rock on its shoulders.
func _extras() -> void:
	var hd: Vector3 = spec["head"]
	var cr: float = spec["chest_r"]
	var ln: float = spec["len"]
	var crystal := PSXMat.lit("ice", Color(0.8, 0.93, 1.0), {"emission": Color(0.25, 0.62, 1.0), "emission_energy": 1.2, "affine": 0.3})
	var rock := PSXMat.lit("black_rock", Color.WHITE, {"affine": 0.6})
	var rng := _rng_fixed()
	for k in range(9):
		var z := -ln * 0.6 + k * ln * 0.15
		var L := 0.9 + sin(k * 0.7) * 0.4 + rng.randf() * 0.3
		var tilt := Basis(Vector3.RIGHT, 0.3 + rng.randf_range(-0.2, 0.2)) * Basis(Vector3.BACK, rng.randf_range(-0.4, 0.4))
		mb("Body").add_cylinder(crystal, Transform3D(tilt, Vector3(rng.randf_range(-0.2, 0.2), cr * 0.85, z)), 0.18, 0.0, L, 6, 0.8, Color.WHITE, false, false, false)
	for s in [-1.0, 1.0]:
		mb("Body").add_blob(rock, Transform3D(Basis(), Vector3(s * cr * 0.7, cr * 0.55, -ln * 0.4)), Vector3(cr * 0.45, cr * 0.3, cr * 0.5), rng, 0.25, 3, 6, 1.0)
		mb("Head").add_cylinder(crystal, Transform3D(Basis(Vector3.BACK, -s * 0.5) * Basis(Vector3.RIGHT, -0.4), Vector3(s * hd.x * 0.5, hd.y * 0.4, -hd.z * 0.3)), 0.12, 0.0, 0.9, 6, 0.8, Color.WHITE, false, false, false)


func _coat_at(p: Vector3) -> Color:
	var base := (spec["coat"] as Color).lerp(spec["under"], smoothstep(-0.2, -0.6, p.y / maxf(float(spec["chest_r"]), 0.1)))
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
	return 4.4 if phase < 3 else 5.4


func _wake_move() -> String:
	return "stomp"


func _ready() -> void:
	super._ready()
	_cd["stomp"] = 3.0
	_overhead.queue_free()
	_overhead = null


func trophy(t: int) -> ItemData:
	return Gear.make("accessory", "cape", {"cape": true, "cape_color": spec["under"]}, "Rimeheart Mantle", t)
