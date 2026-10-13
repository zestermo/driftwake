class_name Bat
extends Flyer
## Bats: a colony hanging upside down under the canopy's crowns or from a cave
## roof. By day they sleep - come right under them, or hit one, and the colony
## drops off its perch and comes for you. At night they're out, flitting round
## the roost, and anyone who wanders by gets swooped. The swoop: it hangs in the
## air a moment with a screech (the tell), then dives through you and back up.
## Morphs: brown bats, big rusty fruit bats, pale cave bats.

const COLORS := [
	[Color(0.2, 0.15, 0.12), Color(0.32, 0.24, 0.2), Color(0.95, 0.25, 0.15)],
	[Color(0.45, 0.24, 0.12), Color(0.55, 0.32, 0.18), Color(0.95, 0.6, 0.2)],
	[Color(0.78, 0.76, 0.72), Color(0.62, 0.55, 0.55), Color(0.85, 0.2, 0.25)],
]

var morph: int = 0
## Bats of a colony wake together.
var colony: int = -1
var _body: Node3D
var _wings: Array = []
var _ears: Node3D


func _setup(args: Dictionary) -> void:
	kind = "bat"
	morph = int(args.get("morph", 0))
	colony = int(args.get("colony", -1))
	_setup_flyer(args)
	size_k = 1.35 if morph == 1 else 1.0
	max_hp = 22.0 * (1.4 if morph == 1 else 1.0)
	xp = 15
	coins = Vector2i(0, 2)
	speed = 6.5
	dive_speed = 10.5
	orbit = Vector2(3.2, 2.4)
	dives_max = 4
	skin_tex = "leather"


func _body_shape() -> Array:
	return [0.18, 0.36, Vector3(0.7, 0.45, 0.5)]


func _moves() -> Array:
	return [[7.0, 2.5, Vector3(0.7, 0.6, 0.7), Vector3(0, 0.1, -0.2), false, 0.2]]


func _perch_point() -> Vector3:
	return anchor + Vector3.DOWN * 0.3 * size_k


func _build() -> void:
	var c: Array = COLORS[morph]
	var fur: Color = c[0]
	var web: Color = c[1]
	var skin := _skin()
	var eye := _glow(c[2])
	var m := "m%d_" % morph
	_body = _part(model, "Body", Vector3.ZERO, m + "body", func(mb: MeshBuilder, rng: RandomNumberGenerator):
		mb.add_blob(skin, Transform3D.IDENTITY, Vector3(0.07, 0.065, 0.11), rng, 0.1, 3, 6, 2.0, fur)
		mb.add_blob(skin, Transform3D(Basis.IDENTITY, Vector3(0, 0.03, -0.12)), Vector3(0.055, 0.05, 0.055), rng, 0.08, 3, 6, 2.0, fur)
		mb.add_cone(skin, Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(0, 0.02, -0.16)), 0.025, 0.05, 4, 2.0, web)
		for s in [-1.0, 1.0]:
			mb.add_box(eye, Transform3D(Basis.IDENTITY, Vector3(s * 0.025, 0.05, -0.16)), Vector3(0.015, 0.015, 0.015), 2.0, Color.WHITE, false, false)
			Creature.seg(mb, skin, Vector3(s * 0.03, -0.03, 0.08), Vector3(s * 0.035, 0.0, 0.17), 0.012, fur), false)
	_ears = _part(_body, "Ears", Vector3(0, 0.06, -0.12), m + "ears", func(mb: MeshBuilder, _rng: RandomNumberGenerator):
		for s in [-1.0, 1.0]:
			var ear := PackedVector2Array([Vector2(-0.025, 0), Vector2(0.025, 0), Vector2(0.005, 0.09)])
			mb.add_extrude(skin, Transform3D(Basis(Vector3.FORWARD, s * 0.35), Vector3(s * 0.03, 0.0, 0.0)), ear, 0.01, 2.0, web))
	for s in [-1.0, 1.0]:
		var w := _part(_body, "Wing", Vector3(s * 0.05, 0.02, -0.03), m + ("wing_l" if s < 0.0 else "wing_r"), func(mb: MeshBuilder, _rng: RandomNumberGenerator):
			var pts := [Vector2(0, -0.04), Vector2(0.14, -0.06), Vector2(0.3, -0.02), Vector2(0.44, -0.05), Vector2(0.4, 0.06), Vector2(0.3, 0.05),
				Vector2(0.24, 0.15), Vector2(0.15, 0.1), Vector2(0.06, 0.15), Vector2(0, 0.08)]
			var outline := PackedVector2Array()
			for q in pts:
				outline.append(Vector2(q.x * s, q.y))
			mb.add_extrude(skin, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3.ZERO), outline, 0.008, 2.0, web)
			for f in [Vector2(0.44, -0.05), Vector2(0.24, 0.15), Vector2(0.06, 0.15)]:
				Creature.seg(mb, skin, Vector3(s * 0.14, 0.004, -0.06), Vector3(s * f.x, 0.004, f.y), 0.012, fur))
		_wings.append([w, s])


func _night_out() -> bool:
	return _night() > 0.55


func _perched(p: Node3D, _delta: float) -> void:
	if _cool > 0.0:
		return
	if p and _player_ok(p) and p.global_position.distance_to(anchor) < 7.5:
		_rouse()
	elif _night_out() and _rng.randf() < 0.01:
		take_off("roam")


func _flying(p: Node3D, delta: float) -> void:
	if _mode == "roam" and p and _player_ok(p) and p.global_position.distance_to(global_position) < 9.0:
		_rouse()
	super._flying(p, delta)


func _roam_done() -> bool:
	return not _night_out() and _rng.randf() < 0.005


func _after_dives() -> String:
	return "roam" if _night_out() else "home"


## Woken: it and the colony come for you.
func _rouse() -> void:
	take_off("hunt")
	Net.fx("sfx", ["screech", global_position, -2.0, 0.15, 1.0 / size_k])
	for f in get_tree().get_nodes_in_group("fauna"):
		if f is Bat and f != self and (f as Bat).colony == colony and (f as Node3D).global_position.distance_to(global_position) < 16.0:
			(f as Bat).take_off("hunt")


func _hurt(hit: HitData, attacker: Node, dir: Vector3) -> bool:
	if state == S.PERCH:
		_rouse()
	return super._hurt(hit, attacker, dir)


func _cry() -> void:
	Net.fx("sfx", ["screech", global_position, -3.0, 0.15, 1.1 / size_k])


func _tell_len() -> float:
	return 0.35


func _cry_death() -> void:
	Net.fx("sfx", ["screech", global_position, -4.0, 0.1, 0.7 / size_k])


func _pose(delta: float) -> void:
	var ph := _wing_phase(delta, 22.0)
	var hanging := state == S.PERCH
	model.rotation.x = PI if hanging else (0.35 if state == S.ATTACK else 0.0)
	for w in _wings:
		var s: float = w[1]
		var node: Node3D = w[0]
		if hanging:
			# wrapped round itself
			node.rotation = Vector3(0, s * 1.2, s * -1.1)
		elif state in [S.DOWN, S.DEAD]:
			node.rotation = Vector3(0, 0, s * (0.25 + sin(_t * 9.0) * 0.3 * (1.0 if state == S.DOWN else 0.0)))
		elif state == S.ATTACK:
			node.rotation = Vector3(0, s * 0.5, s * 0.35)
		else:
			node.rotation = Vector3(0, 0, -s * sin(ph) * 1.0)
	_body.position.y = 0.0 if hanging or state in [S.DOWN, S.DEAD] else sin(ph) * 0.03
	_ears.rotation = Vector3(sin(_t * 3.0) * 0.1, 0, 0)
