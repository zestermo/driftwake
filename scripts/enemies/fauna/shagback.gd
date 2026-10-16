class_name Shagback
extends Creature
## Shagbacks: huge, placid, shaggy white grazers in small herds on the snowfields (the
## townsfolk tame them to haul their sledges and cargo). A herd plods about pawing snow
## off the moss; it ignores you unless you hit one, and then the herd lumbers off at a
## heavy trot, the struck one bawling. A big one in a hurry shoves you aside. Morphs:
## white, cream, smoke-grey.

const TROT := 4.2
const BODY_Y := 1.2

var herd: int = -1
var calf := false
var morph: int = 0

var _flee_from := Vector3.ZERO
var _gait: float = 0.0
var _body: Node3D
var _head: Node3D
var _legs: Array = []


func _setup(args: Dictionary) -> void:
	kind = "shagback"
	herd = int(args.get("pack", -1))
	calf = bool(args.get("calf", false))
	morph = int(args.get("morph", 0))
	hostile = false
	skin_tex = "fur"
	if calf:
		size_k = 0.55
		max_hp = 60.0
		xp = 10
	else:
		size_k = 1.0
		max_hp = 260.0
		xp = 40
		drops = [["boar_haunch", 0.8, 2]]
	coins = Vector2i(0, 1)


func vine_weight() -> String:
	return "light" if calf else "heavy"


func _body_shape() -> Array:
	return [0.75, 1.6, Vector3(1.6, 1.9, 2.6)]


func _moves() -> Array:
	return [[6.0, 6.0, Vector3(1.6, 1.4, 1.2), Vector3(0, 0.8, -1.4), false, 0.25]]


func _can_knock() -> bool:
	return calf


func _build() -> void:
	var coats := [Color(0.92, 0.92, 0.9), Color(0.9, 0.86, 0.76), Color(0.66, 0.66, 0.68)]
	var coat: Color = coats[morph % 3]
	var shade := coat.darkened(0.12)
	var horn := Color(0.3, 0.27, 0.24)
	var v := "%d%s" % [morph % 3, "_calf" if calf else ""]
	var skin := _skin()
	var eye := _glow(Color(0.15, 0.1, 0.08))
	_body = _part(model, "Body", Vector3(0, BODY_Y, 0), v + "_body", func(mb: MeshBuilder, rng: RandomNumberGenerator):
		var xf := Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3.ZERO)
		var rings := [[-1.15, 0.35, 0.4, 0.1], [-0.9, 0.7, 0.78, 0.15], [-0.4, 0.82, 0.9, 0.18], [0.3, 0.78, 0.8, 0.05],
			[0.9, 0.7, 0.72, 0.0], [1.15, 0.35, 0.4, 0.0]]
		mb.add_loft(skin, xf, rings, MeshBuilder.profile_circle(10), 0.8, coat, true, true)
		# the long coat hanging in a skirt nearly to the snow, in shaggy hanks
		for k in range(16):
			var a := TAU * k / 16.0
			var z := sin(a) * 0.95
			var x := cos(a) * 0.78
			if absf(z) > 0.9:
				continue
			var hank := PackedVector3Array([Vector3(x, -0.1, z), Vector3(x * 1.08, -0.6, z * 1.02), Vector3(x * 1.05, -1.0 - rng.randf() * 0.12, z)])
			mb.add_tube(skin, hank, 0.2, 0.1, 5, 1.0, shade.lightened(rng.randf() * 0.1))
		mb.add_blob(skin, Transform3D(Basis.IDENTITY, Vector3(0, 0.75, -0.6)), Vector3(0.6, 0.35, 0.55), rng, 0.15, 3, 7, 1.0, coat), true)
	_head = _part(_body, "Head", Vector3(0, -0.05, -1.25), v + "_head", func(mb: MeshBuilder, rng: RandomNumberGenerator):
		mb.add_blob(skin, Transform3D(Basis.IDENTITY, Vector3(0, -0.05, -0.2)), Vector3(0.32, 0.36, 0.4), rng, 0.12, 3, 7, 1.0, coat)
		mb.add_blob(skin, Transform3D(Basis.IDENTITY, Vector3(0, -0.25, -0.5)), Vector3(0.22, 0.18, 0.16), rng, 0.08, 3, 6, 1.0, Color(0.45, 0.4, 0.4))
		mb.add_blob(skin, Transform3D(Basis.IDENTITY, Vector3(0, 0.22, -0.32)), Vector3(0.3, 0.16, 0.2), rng, 0.25, 3, 6, 1.0, shade)
		for s in [-1.0, 1.0]:
			mb.add_box(eye, Transform3D(Basis.IDENTITY, Vector3(s * 0.2, 0.05, -0.48)), Vector3(0.04, 0.04, 0.03), 1.0, Color.WHITE, false, false)
			mb.add_tube(skin, MeshBuilder.curve_points(Vector3(s * 0.26, 0.2, -0.15), Vector3(s * 0.65, 0.2, -0.1), Vector3(s * 0.55, 0.55, -0.35), 6), 0.08, 0.02, 5, 1.0, horn))
	for i in range(4):
		var front := i < 2
		var s := -1.0 if i % 2 == 0 else 1.0
		var at := Vector3(s * 0.45, -0.55, -0.7 if front else 0.75)
		var leg := _part(_body, "Leg%d" % i, at, v + "_leg", func(mb: MeshBuilder, _rng: RandomNumberGenerator):
			mb.add_cylinder(skin, Transform3D(Basis.IDENTITY, Vector3(0, -0.65, 0)), 0.12, 0.18, 0.7, 6, 1.0, shade, false)
			mb.add_box(skin, Transform3D(Basis.IDENTITY, Vector3(0, -0.65, -0.03)), Vector3(0.2, 0.1, 0.24), 1.0, Color(0.15, 0.13, 0.12), false, false))
		_legs.append({"pivot": leg, "side": s, "front": front})


func _stampede(from: Vector3) -> void:
	_flee_from = from
	if state not in [S.FLEE, S.DEAD]:
		_set_state(S.FLEE)


func _hurt(_hit: HitData, attacker: Node, _dir: Vector3) -> bool:
	var from: Vector3 = (attacker as Node3D).global_position if attacker is Node3D else global_position + _fwd()
	Net.fx("sfx", ["grunt", global_position, 0.0, 0.08, 0.5 if not calf else 0.8])
	for f in get_tree().get_nodes_in_group("fauna"):
		if f is Shagback and (f as Shagback).herd == herd and (f as Node3D).global_position.distance_to(global_position) < 30.0:
			(f as Shagback)._stampede(from)
	return false


func _after_stun() -> void:
	_set_state(S.FLEE)


func _after_daze() -> void:
	_set_state(S.FLEE)


func _brain(_delta: float) -> void:
	match state:
		S.IDLE, S.WANDER:
			_wander(0.7, Vector2(2.0, 10.0))
		S.FLEE:
			var away := _flee_dir(_flee_from)
			_face(away)
			_turn = 4.0
			_want = away * TROT
			# a big one in a hurry shoves through whoever's in its way
			var p := _target()
			if not calf and p and flat(p.global_position - global_position).length() < 2.2 and _cool <= 0.0:
				_strike(0)
				_cool = 1.0
			elif hitbox.active and _cool < 0.7:
				hitbox.deactivate()
			if st_t > 5.0:
				_set_state(S.WANDER)
				_wander_to = home


func _tick(delta: float) -> void:
	anim_a = move_toward(anim_a, 1.0 if (state == S.WANDER and _wander_wait > 0.5) else 0.0, delta * 1.5)


func _pose(delta: float) -> void:
	var hs := flat(velocity).length() if state not in [S.DOWN, S.DEAD] else 0.0
	var moving := clampf(hs / 0.4, 0.0, 1.0)
	_gait += hs * 2.0 * delta / maxf(size_k, 0.7)
	var graze := anim_a
	_body.position.y = BODY_Y + absf(sin(_gait)) * 0.05 * moving
	_body.rotation = Vector3(0, 0, sin(_gait) * 0.03 * moving)
	_head.rotation = Vector3(-graze * 0.6 - sin(_t * 2.0) * 0.08 * graze, sin(_t * 0.5) * 0.15 * (1.0 - moving), 0)
	for leg in _legs:
		var sw := sin(_gait + (0.0 if leg["front"] else PI) + (PI if float(leg["side"]) > 0.0 else 0.0)) * 0.4 * moving
		if graze > 0.5 and leg["front"] and float(leg["side"]) < 0.0:
			sw = maxf(sin(_t * 3.0), 0.0) * 0.5
		(leg["pivot"] as Node3D).rotation = Vector3(sw, 0, 0)
	if graze > 0.5 and lod == LOD_FULL and fmod(_t, 1.2) < delta:
		FX.puff(_head.global_position + Vector3.DOWN * 1.0, "snow", 1, 0.5, 0.6, Color.WHITE, 0.3, Vector3.UP)
