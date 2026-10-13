class_name Toucan
extends Flyer
## A bad-tempered big-billed bird up in the canopy. It perches on its crown and
## shrieks at anyone passing under its tree; linger and it comes down at you:
## it hangs above you flapping with a squawk (the tell), then dives beak first,
## climbs and comes again - three times, then back to its branch. Its bright
## plumes fetch a little in town. Morphs: toco (orange bill), keel-billed
## (rainbow bill), hornbill (casqued, bigger).

const COLORS := [
	[Color(0.06, 0.06, 0.07), Color(0.95, 0.95, 0.88), Color(0.98, 0.55, 0.08), Color(0.2, 0.45, 0.95)],
	[Color(0.07, 0.07, 0.06), Color(0.98, 0.88, 0.2), Color(0.45, 0.8, 0.2), Color(0.25, 0.8, 0.4)],
	[Color(0.12, 0.11, 0.1), Color(0.9, 0.88, 0.82), Color(0.95, 0.78, 0.2), Color(0.85, 0.2, 0.15)],
]

var morph: int = 0
var _hop: float = 0.0
var _body: Node3D
var _head: Node3D
var _wings: Array = []
var _tail: Node3D


func _setup(args: Dictionary) -> void:
	kind = "toucan"
	morph = int(args.get("morph", 0))
	_setup_flyer(args)
	size_k = 1.3 if morph == 2 else 1.0
	max_hp = 26.0 * size_k
	xp = 25
	coins = Vector2i(0, 2)
	drops = [["plume", 0.6, 1]]
	speed = 8.0
	dive_speed = 13.0
	orbit = Vector2(2.0, 5.0)
	dives_max = 3


func _body_shape() -> Array:
	return [0.16, 0.4, Vector3(0.6, 0.5, 0.7)]


func _moves() -> Array:
	return [[9.0, 3.0, Vector3(0.6, 0.6, 0.8), Vector3(0, 0.2, -0.35), false, 0.25]]


func _build() -> void:
	var c: Array = COLORS[morph]
	var black: Color = c[0]
	var bib: Color = c[1]
	var bill: Color = c[2]
	var ring: Color = c[3]
	var skin := _skin()
	var m := "m%d_" % morph
	_body = _part(model, "Body", Vector3(0, 0.12, 0), m + "body", func(mb: MeshBuilder, rng: RandomNumberGenerator):
		mb.add_blob(skin, Transform3D(Basis(Vector3.RIGHT, 0.5), Vector3.ZERO), Vector3(0.09, 0.1, 0.15), rng, 0.04, 3, 7, 2.0, black)
		mb.add_blob(skin, Transform3D(Basis(Vector3.RIGHT, 0.5), Vector3(0, 0.06, -0.08)), Vector3(0.07, 0.07, 0.05), rng, 0.03, 3, 6, 2.0, bib)
		mb.add_box(skin, Transform3D(Basis(Vector3.RIGHT, 0.4), Vector3(0, -0.07, 0.04)), Vector3(0.08, 0.03, 0.08), 2.0, Color(0.85, 0.15, 0.1), false, false)
		for s in [-1.0, 1.0]:
			Creature.seg(mb, skin, Vector3(s * 0.035, -0.08, 0.0), Vector3(s * 0.035, -0.14, -0.02), 0.015, Color(0.3, 0.4, 0.6))
			mb.add_box(skin, Transform3D(Basis.IDENTITY, Vector3(s * 0.035, -0.145, -0.03)), Vector3(0.03, 0.01, 0.05), 2.0, Color(0.3, 0.4, 0.6), false, false), true)
	_head = _part(_body, "Head", Vector3(0, 0.13, -0.1), m + "head", func(mb: MeshBuilder, rng: RandomNumberGenerator):
		mb.add_blob(skin, Transform3D.IDENTITY, Vector3(0.06, 0.065, 0.065), rng, 0.0, 3, 6, 2.0, black)
		mb.add_blob(skin, Transform3D(Basis.IDENTITY, Vector3(0, -0.02, -0.02)), Vector3(0.055, 0.04, 0.05), rng, 0.0, 2, 6, 2.0, bib)
		for s in [-1.0, 1.0]:
			mb.add_box(skin, Transform3D(Basis.IDENTITY, Vector3(s * 0.05, 0.015, -0.025)), Vector3(0.012, 0.04, 0.04), 2.0, ring, false, false)
			mb.add_box(skin, Transform3D(Basis.IDENTITY, Vector3(s * 0.057, 0.015, -0.025)), Vector3(0.008, 0.018, 0.018), 2.0, Color(0.02, 0.02, 0.02), false, false)
		# the bill: deep at the face, curving to a point; the tip darker
		var xf := Transform3D(Basis(Vector3.RIGHT, -PI * 0.5 - 0.1), Vector3(0, 0.0, -0.05))
		mb.add_loft(skin, xf, [[0.0, 0.035, 0.05, 0.0], [0.08, 0.03, 0.045, -0.004], [0.17, 0.02, 0.03, -0.015], [0.24, 0.006, 0.01, -0.03]],
			MeshBuilder.profile_circle(6), 3.0, bill, true, true)
		mb.add_box(skin, Transform3D(Basis(Vector3.RIGHT, -0.15), Vector3(0, -0.005, -0.27)), Vector3(0.024, 0.03, 0.04), 2.0, Color(0.1, 0.06, 0.05), false, false)
		if morph == 1:
			mb.add_box(skin, Transform3D(Basis(Vector3.RIGHT, -0.1), Vector3(0, 0.0, -0.16)), Vector3(0.062, 0.07, 0.03), 2.0, Color(0.95, 0.45, 0.1), false, false)
		if morph == 2:
			mb.add_blob(skin, Transform3D(Basis.IDENTITY, Vector3(0, 0.05, -0.12)), Vector3(0.025, 0.035, 0.09), rng, 0.0, 2, 5, 2.0, bill), true)
	_tail = _part(_body, "Tail", Vector3(0, 0.0, 0.13), m + "tail", func(mb: MeshBuilder, _rng: RandomNumberGenerator):
		var fan := PackedVector2Array([Vector2(-0.04, 0), Vector2(0.04, 0), Vector2(0.05, 0.2), Vector2(-0.05, 0.2)])
		mb.add_extrude(skin, Transform3D(Basis(Vector3.RIGHT, PI * 0.5 + 0.9), Vector3.ZERO), fan, 0.012, 2.0, black))
	for s in [-1.0, 1.0]:
		var w := _part(_body, "Wing", Vector3(s * 0.07, 0.04, -0.03), m + ("wing_l" if s < 0.0 else "wing_r"), func(mb: MeshBuilder, _rng: RandomNumberGenerator):
			var pts := [Vector2(0, -0.06), Vector2(0.18, -0.07), Vector2(0.34, -0.02), Vector2(0.3, 0.06), Vector2(0.12, 0.1), Vector2(0, 0.08)]
			var outline := PackedVector2Array()
			for q in pts:
				outline.append(Vector2(q.x * s, q.y))
			mb.add_extrude(skin, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3.ZERO), outline, 0.012, 2.0, black))
		_wings.append([w, s])


func _perched(p: Node3D, delta: float) -> void:
	_hop -= delta
	if _hop <= 0.0:
		_hop = _rng.randf_range(2.0, 6.0)
		_yaw += _rng.randf_range(-1.2, 1.2)
	if _cool > 0.0 or not _player_ok(p):
		return
	var under := flat(p.global_position - anchor).length()
	if under < 13.0 and p.global_position.y < anchor.y - 2.0:
		if st_t > 1.2:
			take_off("hunt")
			_cry()
		elif fmod(st_t, 0.6) < delta:
			Net.fx("sfx", ["squawk", global_position, -4.0, 0.1, 1.2 / size_k])
	else:
		st_t = 0.0


func _flying(p: Node3D, delta: float) -> void:
	if _mode == "home" and _dives >= dives_max:
		_cool = 10.0
	super._flying(p, delta)


func _cry() -> void:
	Net.fx("sfx", ["squawk", global_position, -1.0, 0.1, 1.0 / size_k])


func _tell_len() -> float:
	return 0.45


func _cry_death() -> void:
	Net.fx("sfx", ["squawk", global_position, -2.0, 0.1, 0.8 / size_k])
	Net.fx("petals", [global_position, Vector3.UP, 8, COLORS[morph][1], 2.0])


func _pose(delta: float) -> void:
	var ph := _wing_phase(delta, 16.0)
	var perched := state == S.PERCH
	model.rotation.x = 0.5 if state == S.ATTACK else (-0.15 if state == S.TELL else 0.0)
	for w in _wings:
		var s: float = w[1]
		var node: Node3D = w[0]
		if perched or state in [S.DOWN, S.DEAD]:
			node.rotation = Vector3(0, s * 1.35, s * -0.3)
		elif state == S.ATTACK:
			node.rotation = Vector3(0, s * 0.8, s * 0.2)
		else:
			node.rotation = Vector3(0, 0, -s * sin(ph) * 0.9)
	_body.rotation.x = -0.6 if perched else 0.0
	_head.rotation = Vector3(0.5 if perched else 0.0, sin(_t * 1.7) * 0.6 if perched else 0.0, 0)
	_tail.rotation = Vector3(0.4 if perched else 0.0, 0, 0)
