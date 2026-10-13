class_name Monkey
extends Creature
## Monkeys: a troop up in the crowns. They hoot and jeer at anyone passing and
## pelt them with fruit (the tell: one stands up, arm back, chattering). Come
## right under their tree, or hit one, and it drops to the floor: a bold one
## dashes in, snatches a fistful of your gold and runs for it (catch it and the
## gold's back), a timid one just runs - then it climbs back up. Morphs:
## brown capuchins, golden monkeys, grey langurs.

const SEE := 18.0
const COLORS := [
	[Color(0.24, 0.15, 0.08), Color(0.88, 0.78, 0.6), Color(0.15, 0.09, 0.05)],
	[Color(0.85, 0.5, 0.15), Color(0.2, 0.12, 0.08), Color(0.6, 0.32, 0.1)],
	[Color(0.55, 0.55, 0.52), Color(0.1, 0.1, 0.1), Color(0.38, 0.38, 0.36)],
]
const FRUIT := [Color(0.95, 0.6, 0.12), Color(0.95, 0.85, 0.2), Color(0.55, 0.8, 0.2)]

var morph: int = 0
## Where it sits in the crown (world).
var anchor := Vector3.ZERO
var bold := false
## Gold it's run off with (dropped when it's killed).
var loot: int = 0

var _climbing := false
var _gait: float = 0.0
var _body: Node3D
var _head: Node3D
var _arms: Array = []
var _legs: Array = []
var _tail: Node3D


func _setup(args: Dictionary) -> void:
	kind = "monkey"
	morph = int(args.get("morph", 0))
	anchor = args.get("anchor", home)
	bold = bool(args.get("bold", false))
	max_hp = 36.0
	xp = 30
	coins = Vector2i(1, 2)
	drops = [["jungle_fruit", 0.5, 1]]
	skin_tex = "fabric"
	flying = true


func in_combat() -> bool:
	return state in [S.TELL, S.ATTACK, S.CHASE] or (state == S.PERCH and _cool > 0.0)


func _body_shape() -> Array:
	return [0.2, 0.6, Vector3(0.55, 0.75, 0.6)]


func _moves() -> Array:
	return [[5.0, 2.0, Vector3(0.6, 0.6, 0.6), Vector3(0, 0.4, -0.4), false, 0.2],
		[2.0, 1.5, Vector3(0.7, 0.8, 0.7), Vector3(0, 0.4, -0.45), false, 0.15]]


func _build() -> void:
	var c: Array = COLORS[morph]
	var fur: Color = c[0]
	var face: Color = c[1]
	var dark: Color = c[2]
	var skin := _skin()
	var m := "m%d_" % morph
	_body = _part(model, "Body", Vector3(0, 0.32, 0), m + "body", func(mb: MeshBuilder, rng: RandomNumberGenerator):
		mb.add_blob(skin, Transform3D(Basis(Vector3.RIGHT, 0.3), Vector3(0, 0.1, 0)), Vector3(0.13, 0.19, 0.11), rng, 0.06, 3, 7, 2.0, fur)
		mb.add_blob(skin, Transform3D(Basis(Vector3.RIGHT, 0.3), Vector3(0, 0.08, -0.06)), Vector3(0.09, 0.13, 0.05), rng, 0.04, 3, 6, 2.0, fur.lightened(0.2)), true)
	_head = _part(_body, "Head", Vector3(0, 0.3, -0.05), m + "head", func(mb: MeshBuilder, rng: RandomNumberGenerator):
		mb.add_blob(skin, Transform3D.IDENTITY, Vector3(0.1, 0.1, 0.095), rng, 0.04, 3, 7, 2.0, fur)
		mb.add_blob(skin, Transform3D(Basis.IDENTITY, Vector3(0, -0.01, -0.07)), Vector3(0.07, 0.075, 0.04), rng, 0.0, 3, 6, 2.0, face)
		mb.add_blob(skin, Transform3D(Basis.IDENTITY, Vector3(0, -0.04, -0.1)), Vector3(0.045, 0.035, 0.03), rng, 0.0, 2, 6, 2.0, face.darkened(0.15))
		for s in [-1.0, 1.0]:
			mb.add_box(skin, Transform3D(Basis.IDENTITY, Vector3(s * 0.03, 0.015, -0.105)), Vector3(0.022, 0.02, 0.012), 2.0, Color(0.03, 0.02, 0.02), false, false)
			mb.add_blob(skin, Transform3D(Basis.IDENTITY, Vector3(s * 0.1, 0.01, 0.0)), Vector3(0.025, 0.035, 0.015), rng, 0.0, 2, 5, 2.0, face.darkened(0.2))
		mb.add_box(skin, Transform3D(Basis.IDENTITY, Vector3(0, 0.05, -0.08)), Vector3(0.1, 0.018, 0.02), 2.0, dark, false, false))
	for s in [-1.0, 1.0]:
		var arm := _part(_body, "Arm", Vector3(s * 0.12, 0.2, -0.02), m + ("arm_l" if s < 0.0 else "arm_r"), func(mb: MeshBuilder, _rng: RandomNumberGenerator):
			Creature.seg(mb, skin, Vector3.ZERO, Vector3(s * 0.03, -0.17, -0.02), 0.05, fur)
			Creature.seg(mb, skin, Vector3(s * 0.03, -0.17, -0.02), Vector3(s * 0.03, -0.33, -0.06), 0.04, fur)
			mb.add_box(skin, Transform3D(Basis.IDENTITY, Vector3(s * 0.03, -0.36, -0.07)), Vector3(0.045, 0.05, 0.04), 2.0, face.darkened(0.2), false, false))
		_arms.append([arm, s])
		var leg := _part(_body, "Leg", Vector3(s * 0.08, -0.06, 0.04), m + ("leg_l" if s < 0.0 else "leg_r"), func(mb: MeshBuilder, _rng: RandomNumberGenerator):
			Creature.seg(mb, skin, Vector3.ZERO, Vector3(s * 0.04, -0.06, -0.15), 0.06, fur)
			Creature.seg(mb, skin, Vector3(s * 0.04, -0.06, -0.15), Vector3(s * 0.04, -0.24, -0.1), 0.045, fur)
			mb.add_box(skin, Transform3D(Basis.IDENTITY, Vector3(s * 0.04, -0.26, -0.13)), Vector3(0.05, 0.03, 0.08), 2.0, face.darkened(0.2), false, false))
		_legs.append([leg, s])
	_tail = _part(_body, "Tail", Vector3(0, -0.04, 0.1), m + "tail", func(mb: MeshBuilder, _rng: RandomNumberGenerator):
		var pts := PackedVector3Array()
		for i in range(10):
			var t := i / 9.0
			var a := t * 4.0
			pts.append(Vector3(0, 0.05 - t * 0.1 + sin(a) * 0.1 * t, 0.05 + t * 0.4 + cos(a) * 0.06 * t))
		mb.add_tube(skin, pts, 0.025, 0.012, 4, 2.0, fur))


func _start() -> void:
	global_position = anchor
	_set_state(S.PERCH)


## Back up its tree: run to the trunk, then climb.
func _climb() -> void:
	_climbing = false
	_set_state(S.FLEE)
	st_t = 99.0


func _brain(delta: float) -> void:
	var p := _target()
	var to_p := flat(p.global_position - global_position) if p else Vector3.ZERO
	var dist := to_p.length() if p else INF
	match state:
		S.PERCH:
			velocity = Vector3.ZERO
			global_position = anchor
			flying = true
			if not _player_ok(p):
				return
			_face(to_p)
			var under := flat(p.global_position - anchor).length()
			if under < 4.5 and p.global_position.y < anchor.y - 2.0:
				_drop_down()
			elif dist < SEE and _cool <= 0.0:
				_set_state(S.TELL)
				Net.fx("sfx", ["monkey", global_position, -2.0, 0.12, 1.0])
			elif fmod(_t + seed_v(), 7.0) < delta:
				Net.fx("sfx", ["monkey", global_position, -8.0, 0.15, 1.15])
		S.TELL:
			global_position = anchor
			_face(to_p)
			_turn = 10.0
			if st_t >= 0.55:
				if _player_ok(p):
					_throw(p)
				_cool = _rng.randf_range(1.8, 3.2)
				_set_state(S.PERCH)
		S.FLY:
			# falling from the crown
			pass
		S.CHASE:
			if not _player_ok(p) or dist > 14.0 or _player_gold(p) <= 0:
				_climb()
				return
			_face(to_p)
			_want = to_p.normalized() * 5.6
			_turn = 12.0
			if dist < 1.3:
				_set_state(S.ATTACK)
				_strike(1)
				velocity = to_p.normalized() * 4.0 + Vector3.UP * 2.0
		S.ATTACK:
			_want = flat(velocity)
			if st_t > 0.3:
				_set_state(S.FLEE)
		S.FLEE:
			var trunk := Vector3(anchor.x, global_position.y, anchor.z)
			if st_t < 4.0 and p:
				var away := _flee_dir(p.global_position)
				_face(away)
				_want = away * 6.0
				_turn = 12.0
				return
			var d := flat(trunk - global_position)
			if d.length() > 0.6 and not _climbing:
				_face(d)
				_want = d.normalized() * 5.0
				return
			_climbing = true
			flying = true
			velocity = Vector3.ZERO
			global_position = global_position.move_toward(anchor, 4.0 * delta)
			if global_position.distance_to(anchor) < 0.05:
				_climbing = false
				_cool = 2.0
				_set_state(S.PERCH)


func _fly(delta: float) -> void:
	if state == S.FLY:
		# dropping out of the tree
		velocity.y -= GRAVITY * delta
		move_and_slide()
		if is_on_floor() and st_t > 0.1:
			flying = false
			Net.fx("dust", [global_position, 4, 0.4])
			if bold and _player_gold(_target()) > 0:
				_set_state(S.CHASE)
				Net.fx("sfx", ["monkey", global_position, 0.0, 0.1, 1.3])
			else:
				_set_state(S.FLEE)
		return
	if state == S.FLEE and _climbing:
		return
	super._fly(delta)


func _drop_down() -> void:
	flying = true
	velocity = Vector3(0, 1.0, 0)
	_set_state(S.FLY)
	Net.fx("sfx", ["monkey", global_position, 0.0, 0.1, 1.2])


func _player_gold(p: Node3D) -> int:
	# (the host can't see a guest's purse: it just goes for them)
	if p is Player and (p as Player).is_local:
		return (p as Player).inventory_component.count("gold")
	return 1 if p else 0


func _throw(p: Node3D) -> void:
	var from := global_position + Vector3(0, 0.6, 0)
	var tgt := p.global_position + Vector3(0, 1.1, 0)
	if p is CharacterBody3D:
		tgt += flat((p as CharacterBody3D).velocity) * 0.3
	var t := clampf(from.distance_to(tgt) / 11.0, 0.5, 1.2)
	var vel := (tgt - from) / t + Vector3(0, 0.5 * ThrownFruit.GRAVITY * t, 0)
	_spawn_fruit(from, vel, _dmg(5.0))
	Net.event(self, "throw", [from, vel, _dmg(5.0)])
	Net.fx("sfx", ["whoosh", from, -8.0, 0.1, 1.6])


func _spawn_fruit(from: Vector3, vel: Vector3, dmg: float) -> void:
	var f := ThrownFruit.new()
	f.vel = vel
	f.damage = dmg
	f.color = FRUIT[morph]
	get_tree().current_scene.add_child(f)
	f.global_position = from


func _net_event(what: String, args: Array) -> void:
	if what == "throw":
		_spawn_fruit(args[0], args[1], float(args[2]))


## Its snatch landed on our captain: the gold goes with it.
func _landed(target: Node, data: HitData) -> void:
	super._landed(target, data)
	if strike_id != 1 or not (target is Player) or not (target as Player).is_local:
		return
	var pl := target as Player
	var n := mini(pl.inventory_component.count("gold"), 3 + level)
	if n <= 0:
		return
	pl.inventory_component.remove_item(ItemDB.get_item("gold"), n)
	pl.call("_toast", "A monkey stole %d gold!" % n)
	stole(n)


func stole(n: int) -> void:
	if Net.forward(self, "stole", [n]):
		return
	loot += n
	Net.fx("sfx", ["monkey", global_position, 0.0, 0.1, 1.4])
	Net.fx("sparkle", [global_position + Vector3(0, 0.6, 0), 6, Color(1.0, 0.85, 0.3)])
	if state not in [S.DEAD, S.DOWN]:
		_set_state(S.FLEE)


func _hurt(_hit: HitData, _attacker: Node, _dir: Vector3) -> bool:
	if state in [S.PERCH, S.TELL]:
		_drop_down()
		return true
	return false


func _after_stun() -> void:
	_set_state(S.FLEE)


func _after_daze() -> void:
	_set_state(S.FLEE)


func _reward() -> void:
	super._reward()
	if loot > 0:
		Net.coins(global_position + Vector3(0, 0.5, 0), loot)


func _cry_death() -> void:
	Net.fx("sfx", ["monkey", global_position, 0.0, 0.05, 0.75])


func _pose(delta: float) -> void:
	var hs := flat(velocity).length() if state not in [S.DOWN, S.DEAD] else 0.0
	var moving := clampf(hs / 0.5, 0.0, 1.0)
	_gait += hs * 5.0 * delta
	var sitting := state in [S.PERCH, S.TELL] or (state == S.FLEE and _climbing)
	var arm_r := 0.0
	var arm_l := 0.0
	var body_pitch := 0.0
	if sitting:
		body_pitch = -0.1
		arm_l = 0.6
		arm_r = 0.6
		if state == S.TELL:
			var k := clampf(st_t / 0.45, 0.0, 1.0)
			arm_r = -2.4 * k + (3.4 if st_t > 0.5 else 0.0)
			body_pitch = -0.3 * k
		if _climbing:
			arm_l = 2.6 + sin(_t * 12.0) * 0.6
			arm_r = 2.6 - sin(_t * 12.0) * 0.6
	else:
		# on all fours
		body_pitch = 0.9
		arm_l = sin(_gait) * 0.8 * moving + 0.9
		arm_r = -sin(_gait) * 0.8 * moving + 0.9
		if state == S.ATTACK:
			arm_l = 1.8
			arm_r = 1.8
	_body.rotation = Vector3(body_pitch, 0, sin(_t * 9.0) * 0.08 if state == S.TELL else 0.0)
	_head.rotation = Vector3(-body_pitch * 0.8, sin(_t * 1.9) * 0.4 if state == S.PERCH else 0.0, 0)
	(_arms[0][0] as Node3D).rotation = Vector3(arm_l, 0, 0)
	(_arms[1][0] as Node3D).rotation = Vector3(arm_r, 0, 0)
	for l in _legs:
		var sw := sin(_gait + (PI if float(l[1]) > 0.0 else 0.0)) * 0.7 * moving
		(l[0] as Node3D).rotation = Vector3((0.9 if sitting else -0.2) + sw, 0, 0)
	_tail.rotation = Vector3(sin(_t * 1.3) * 0.3 - (0.8 if sitting else 0.0), sin(_t * 0.9) * 0.4, 0)
