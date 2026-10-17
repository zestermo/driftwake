extends "res://scripts/enemies/beasts/behemoth.gd"
## The Wild Hunt (BeastPool "wild_hunt", a forest island's roamer): only at night, a spectral elk taller than a
## house, black as the wood with antlers of pale fire, and on its back a hooded rider with a horn. It rides the
## island's floor from one place to the next; crowd it or strike it and it charges, tosses its antlers and stamps,
## a bellow before each. By day there's nothing there: it isn't anywhere (hidden, out of the physics space, asleep)
## until dusk. The same on every screen: night is the synced world time's.

var _gone := false


func _init() -> void:
	super._init()
	boss_name = "The Wild Hunt"


func _spec() -> Dictionary:
	return {"hip_h": 2.6, "len": 3.0, "chest_r": 1.25, "hip_r": 1.05, "neck": Vector3(0, 0.5, -0.8), "head": Vector3(0.6, 0.6, 0.8),
		"snout": 0.7, "tail": 0.5, "tail_r": 0.12, "coat": Color(0.12, 0.13, 0.17), "under": Color(0.2, 0.22, 0.28), "mark": Color(0.35, 0.6, 0.55),
		"tex": "fur_white", "ears": 0.7, "eye": Color(0.55, 1.0, 0.85)}


## Antlers of pale fire, a mane of shadow, and the rider: a hooded figure sat high on its back, a horn at his hip.
func _extras() -> void:
	var hd: Vector3 = spec["head"]
	var cr: float = spec["chest_r"]
	var ghost := PSXMat.lit("", Color(0.6, 1.0, 0.85), {"emission": Color(0.45, 1.0, 0.8), "emission_energy": 1.4, "affine": 0.3})
	var cloak := PSXMat.flat(Color(0.06, 0.07, 0.08))
	var rng := _rng_fixed()
	for s in [-1.0, 1.0]:
		var root := Vector3(s * hd.x * 0.4, hd.y * 0.7, hd.z * 0.1)
		var beam := MeshBuilder.curve_points(root, root + Vector3(s * 1.6, 0.6, 0.8), root + Vector3(s * 2.2, 2.0, 0.3), 7)
		mb("Head").add_tube(ghost, beam, 0.13, 0.04, 5, 1.0)
		for t in [2, 4, 6]:
			var at: Vector3 = beam[t]
			mb("Head").add_tube(ghost, PackedVector3Array([at, at + Vector3(s * 0.2, 0.7, -0.4)]), 0.07, 0.02, 4, 1.0)
	for k in range(7):
		mb("Neck").add_blob(cloak, Transform3D(Basis(), Vector3(0, cr * 0.4 + k * 0.1, 0.1 - k * 0.12)), Vector3(0.22, 0.18, 0.2), rng, 0.35, 2, 5, 1.0)
	var seat := Vector3(0, cr * 1.0, -0.2)
	mb("Body").add_blob(cloak, Transform3D(Basis(), seat + Vector3(0, 0.7, 0)), Vector3(0.45, 0.8, 0.38), rng, 0.15, 3, 6, 1.0)
	mb("Body").add_cone(cloak, Transform3D(Basis(), seat + Vector3(0, 1.4, 0.05)), 0.3, 0.7, 6, 1.0)
	for s in [-1.0, 1.0]:
		mb("Body").add_tube(cloak, PackedVector3Array([seat + Vector3(s * 0.35, 0.2, 0), seat + Vector3(s * 0.55, -0.4, -0.1), seat + Vector3(s * 0.5, -0.9, -0.2)]), 0.12, 0.08, 5, 1.0)
		mb("Body").add_box(ghost, Transform3D(Basis(), seat + Vector3(s * 0.09, 1.25, -0.3)), Vector3(0.07, 0.04, 0.04), 1.0)
	mb("Body").add_tube(PSXMat.flat(Color(0.86, 0.8, 0.66)), MeshBuilder.curve_points(seat + Vector3(0.45, 0.3, 0.1), seat + Vector3(0.7, 0.2, 0.3), seat + Vector3(0.6, 0.55, 0.45), 4), 0.05, 0.1, 5, 1.0)


func _coat_at(p: Vector3) -> Color:
	return (spec["coat"] as Color).lerp(spec["mark"], smoothstep(0.6, 1.0, sin(p.x * 5.0 + p.z * 3.0 + p.y * 2.0) * 0.5 + 0.5) * 0.25)


func _hp_base() -> float:
	return 1900.0


func _speed() -> float:
	return 5.6


## Abroad only at night (or while it's fighting someone, or dying).
func _abroad() -> bool:
	return float(Weather.night) > 0.5 or state in [S.FIGHT, S.STAGGER, S.DEAD]


func _vanish(on: bool) -> void:
	if on == _gone:
		return
	_gone = on
	model.visible = not on
	collision_layer = 0 if on else BODY_LAYER
	hurtbox.set_deferred("monitorable", not on)


func _process(delta: float) -> void:
	_vanish(not _abroad())
	if _gone:
		return
	super._process(delta)


func _physics_process(delta: float) -> void:
	if _gone and not net_puppet:
		return
	super._physics_process(delta)
