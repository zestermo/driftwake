extends "res://scripts/enemies/beasts/alpha_boar.gd"
## The hyena alpha (BeastPool "hyena", a desert island's miniboss at its ruins): a spotted
## hyena the size of a horse, a bristling dark mane down its neck and back, jaws that crack
## bone. The alpha boar's brain on a hyena: a loping run at you down a line (the charge), a
## snapping bite in front (parry it: it reels), and below half, up and down on its forelegs,
## a ring of sand round it (jump it). Name and health over its head; back to its ruins,
## healed, once everyone's gone.


func _init() -> void:
	boss_name = "Bonecrusher"
	wake_r = 18.0
	leash_r = 40.0
	charge_len = 16.0
	charge_speed = 16.0
	gore_r = 3.2
	stomp_r = 4.4


func _spec() -> Dictionary:
	return {"hip_h": 1.15, "len": 1.7, "chest_r": 0.68, "hip_r": 0.5, "neck": Vector3(0, 0.2, -0.5), "head": Vector3(0.4, 0.38, 0.44),
		"snout": 0.45, "tail": 0.8, "tail_r": 0.1, "coat": Color(0.62, 0.52, 0.38), "under": Color(0.78, 0.7, 0.56), "mark": Color(0.18, 0.13, 0.1),
		"tex": "fur", "ears": 0.6, "eye": Color(1.0, 0.7, 0.2)}


## A dark bristling mane down the neck and back, fangs.
func _extras() -> void:
	var cr: float = spec["chest_r"]
	var ln: float = spec["len"]
	var hd: Vector3 = spec["head"]
	var sn: float = spec["snout"]
	var ivory := PSXMat.flat(Color(0.94, 0.9, 0.8))
	var rng := _rng_fixed()
	for k in range(8):
		mb("Body").add_blob(spec["coat_mat"], Transform3D(Basis(), Vector3(0, cr * 0.95, -ln * 0.6 + k * ln * 0.12)), Vector3(cr * 0.15, cr * 0.32, ln * 0.09), rng, 0.3, 3, 5, 1.0, Color(0.3, 0.3, 0.3))
	for k in range(4):
		mb("Neck").add_blob(spec["coat_mat"], Transform3D(Basis(), Vector3(0, cr * 0.6, -0.1 - k * 0.12)), Vector3(cr * 0.14, cr * 0.3, 0.12), rng, 0.3, 3, 5, 1.0, Color(0.3, 0.3, 0.3))
	for s in [-1.0, 1.0]:
		mb("Head").add_cylinder(ivory, Transform3D(Basis(Vector3.RIGHT, PI), Vector3(s * hd.x * 0.25, -hd.y * 0.3, -hd.z * 0.9 - sn * 0.7)), 0.04, 0.0, 0.16, 4, 1.0, Color.WHITE, false, false, false)


## Dark spots over the tawny-grey.
func _coat_at(p: Vector3) -> Color:
	var base := (spec["coat"] as Color).lerp(spec["under"], smoothstep(-0.2, -0.6, p.y / maxf(float(spec["chest_r"]), 0.1)))
	var q := p * 5.0
	var spot := smoothstep(0.8, 0.95, absf(sin(q.x * 1.7 + sin(q.z * 1.3)) * sin(q.z * 1.9 + q.y)))
	return base.lerp(spec["mark"], spot * 0.8)


func _hp_base() -> float:
	return 560.0


func _speed() -> float:
	return 7.0


func _on_begin(m: String) -> void:
	super._on_begin(m)
	if m == "charge":
		say("snarl", global_position, 3.0, 1.1)
