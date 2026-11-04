extends Flyer
## Grave moths (the fog isles, 1.30): moths with wings as wide as your arms, grey-brown and dusty, two pale eye-spots on
## the hind wings, resting flat in the grass by day. Light draws them: after dark, or whenever a captain's belt lantern
## is lit near them, they lift off and come fluttering round it in a loose cloud - then one hangs, flares its wings
## (the eye-spots glow: the tell) and dives at the light, dusting you with scales that sicken (a short poison).
## Put your lantern out (L) and by day they settle again.

const LURE_R := 22.0
const WING := Color(0.42, 0.37, 0.3)
const BAND := Color(0.24, 0.2, 0.17)
const SPOT := Color(0.85, 0.95, 0.8)

var morph: int = 0
var _body: Node3D
var _wings: Array = []
var _look_t := 0.0


func _setup(args: Dictionary) -> void:
	kind = "grave_moth"
	morph = int(args.get("morph", 0)) % 3
	args = args.duplicate()
	args["anchor"] = args.get("anchor", home + Vector3.UP * 0.15)
	_setup_flyer(args)
	size_k = 1.5 + 0.15 * morph
	max_hp = 30.0
	xp = 22
	coins = Vector2i(0, 2)
	speed = 4.2
	dive_speed = 8.0
	orbit = Vector2(2.4, 1.6)
	dives_max = 5
	venom = [4.0, 3.0]
	skin_tex = "fur_white"
	drops = [["plume", 0.5, 1], ["canvas", 0.15, 1]]


func _body_shape() -> Array:
	return [0.2, 0.4, Vector3(0.9, 0.5, 0.7)]


func _moves() -> Array:
	return [[7.0, 2.0, Vector3(0.8, 0.8, 0.8), Vector3(0, 0.1, -0.25), false, 0.25]]


func _build() -> void:
	var skin := _skin()
	var spot := _glow(SPOT)
	var wing := WING.lerp(Color(0.5, 0.5, 0.48), 0.3 * morph)
	_body = _part(model, "Body", Vector3.ZERO, "body", func(mb: MeshBuilder, rng: RandomNumberGenerator):
		mb.add_blob(skin, Transform3D(Basis.IDENTITY, Vector3(0, 0, 0.12)), Vector3(0.07, 0.07, 0.2), rng, 0.08, 3, 6, 1.0, BAND)
		mb.add_blob(skin, Transform3D(Basis.IDENTITY, Vector3(0, 0.01, -0.07)), Vector3(0.08, 0.08, 0.09), rng, 0.2, 3, 6, 1.0, Color(0.55, 0.5, 0.42))
		mb.add_blob(skin, Transform3D(Basis.IDENTITY, Vector3(0, 0.0, -0.17)), Vector3(0.05, 0.05, 0.05), rng, 0.1, 3, 6, 1.0, BAND)
		for s in [-1.0, 1.0]:
			mb.add_box(spot, Transform3D(Basis.IDENTITY, Vector3(s * 0.035, 0.02, -0.2)), Vector3(0.025, 0.025, 0.02), 1.0, Color.WHITE, false, false)
			# feathered antennae
			mb.add_tube(skin, PackedVector3Array([Vector3(s * 0.02, 0.04, -0.2), Vector3(s * 0.08, 0.12, -0.28), Vector3(s * 0.14, 0.14, -0.3)]), 0.012, 0.004, 3, 1.0, Color(0.6, 0.55, 0.45))
		for k in range(3):
			for s in [-1.0, 1.0]:
				seg(mb, skin, Vector3(s * 0.04, -0.04, -0.1 + k * 0.05), Vector3(s * 0.12, -0.12, -0.12 + k * 0.06), 0.012, BAND)
		# bands round the abdomen
		for k in range(3):
			mb.add_box(skin, Transform3D(Basis.IDENTITY, Vector3(0, 0.03, 0.06 + k * 0.08)), Vector3(0.11, 0.03, 0.025), 1.0, wing.lightened(0.15), false, false))
	for s in [-1.0, 1.0]:
		var w := _part(_body, "Wing" + ("L" if s < 0.0 else "R"), Vector3(s * 0.05, 0.04, -0.06), "wing%d%s" % [morph, "l" if s < 0.0 else "r"], func(mb: MeshBuilder, _rng: RandomNumberGenerator):
			var fore := [Vector2(0, -0.06), Vector2(0.28, -0.16), Vector2(0.62, -0.12), Vector2(0.64, 0.0), Vector2(0.36, 0.08), Vector2(0, 0.06)]
			var hind := [Vector2(0, 0.04), Vector2(0.3, 0.06), Vector2(0.46, 0.2), Vector2(0.34, 0.38), Vector2(0.12, 0.34), Vector2(0, 0.18)]
			for pts in [fore, hind]:
				var outline := PackedVector2Array()
				for q in pts:
					outline.append(Vector2(q.x * s, q.y))
				mb.add_extrude(skin, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3.ZERO), outline, 0.006, 1.0, wing)
			# a dark band across the forewing, the eye-spot on the hind
			mb.add_box(skin, Transform3D(Basis(Vector3.UP, s * 0.35), Vector3(s * 0.34, 0.005, -0.05)), Vector3(0.05, 0.004, 0.2), 1.0, BAND, false, false)
			mb.add_cylinder(spot, Transform3D(Basis.IDENTITY, Vector3(s * 0.28, 0.006, 0.2)), 0.06, 0.06, 0.004, 6, 1.0, Color.WHITE)
			mb.add_cylinder(skin, Transform3D(Basis.IDENTITY, Vector3(s * 0.28, 0.0055, 0.2)), 0.085, 0.085, 0.004, 6, 1.0, BAND))
		_wings.append([w, s])


## Resting on the ground (the anchor), wings flat.
func _perch_point() -> Vector3:
	return anchor


## Is there light to come to: night, or a captain's lantern lit.
func _lured(p: Node3D) -> bool:
	if p == null or not _player_ok(p) or p.global_position.distance_to(global_position) > LURE_R:
		return false
	if _night() > 0.5:
		return true
	var bm = p.get("body_model")
	return bm != null and bm.get("lantern") != null and bool(bm.lantern.lit)


func _perched(p: Node3D, delta: float) -> void:
	_look_t -= delta
	if _look_t > 0.0 or _cool > 0.0:
		return
	_look_t = 0.5
	if _lured(p):
		take_off("hunt")
		Net.fx("sfx", ["moth_flutter", global_position, -4.0, 0.1, 1.0 / size_k])


func _flying(p: Node3D, delta: float) -> void:
	_look_t -= delta
	if _mode == "hunt" and _look_t <= 0.0:
		_look_t = 0.5
		if not _lured(p):
			_mode = "home"
	super._flying(p, delta)


func _after_dives() -> String:
	return "home"


func _cry() -> void:
	Net.fx("sfx", ["moth_flutter", global_position, -2.0, 0.1, 0.8 / size_k])


func _tell_len() -> float:
	return 0.6


func _landed(target: Node, data: HitData) -> void:
	super._landed(target, data)
	FX.poison((target as Node3D).global_position + Vector3.UP * 1.2, 5, 0.35)
	FX.sparkle((target as Node3D).global_position + Vector3.UP * 1.3, 6, Color(0.7, 0.66, 0.55))


func _cry_death() -> void:
	Net.fx("sparkle", [global_position, 12, Color(0.7, 0.66, 0.55)])
	Net.fx("sfx", ["moth_flutter", global_position, -4.0, 0.05, 0.6])


func _pose(delta: float) -> void:
	var ph := _wing_phase(delta, 11.0)
	var resting := state == S.PERCH
	model.rotation.x = 0.3 if state == S.ATTACK else 0.0
	for w in _wings:
		var s: float = w[1]
		var node: Node3D = w[0]
		if resting:
			# flat on the ground, swept back like a tent, a slow breathing open and shut
			node.rotation = Vector3(0, s * 0.35, s * (0.05 + 0.05 * sin(_t * 1.3)))
		elif state == S.TELL:
			# wide open and shivering: the eye-spots shown
			node.rotation = Vector3(0, 0, -s * (0.25 + sin(_t * 40.0) * 0.08))
		elif state == S.ATTACK:
			node.rotation = Vector3(0, s * 0.6, -s * 0.7)
		elif state in [S.DOWN, S.DEAD]:
			node.rotation = Vector3(0, s * 0.2, s * (0.1 + sin(_t * 12.0) * 0.2 * (1.0 if state == S.DOWN else 0.0)))
		else:
			node.rotation = Vector3(0, 0, -s * sin(ph) * 1.1)
	_body.position.y = 0.0 if resting or state in [S.DOWN, S.DEAD] else sin(ph) * 0.05
