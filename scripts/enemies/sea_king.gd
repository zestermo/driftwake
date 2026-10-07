extends Node3D
## A Sea King: a great sea serpent lurking in deep water far out (SeaFeatures
## places its lair). When a ship with a captain aboard comes into its waters
## it rises beside her and fights her from the sea:
## * it circles the ship, head high, the body trailing through the swell;
## * BITE: it rears up over the deck (a ring warns where), then strikes down
##   onto it - a hole in the hull and a blow for anyone in the ring (jump or
##   get clear) - and its head lies on the deck a moment: cut at it then;
## * TAIL: its tail rises out of the water and slams down beside her: the
##   ship is thrown over and everyone standing on deck knocked flat (jump!);
## * it dives and comes up on the other side.
## Cannon fire (on the head or the body), guns, powers and blades on its head
## hurt it. Killed, it sinks and leaves its hoard floating; it's back in its
## lair after a long while.
##
## Co-op: the host runs it (group net_sync); the others play back its head
## and body; the bite and the tail are judged on each captain's own machine.

enum S { LURK, RISE, CIRCLE, REAR, STRIKE, DOWN, TAIL, DIVE, DEAD }

const HP := 1600.0
const SEGS := 16
const SPACING := 2.3
const CIRCLE_R := 24.0
const NOTICE := 220.0
const BITE_R := 3.6
const BITE_DMG := 34.0
const BITE_HULL := 45.0
const REAR_TIME := 1.3
const DOWN_TIME := 1.7
const TAIL_UP := 1.4
const TAIL_SLAM := 1.75
const TAIL_END := 2.6
const SINK_TIME := 6.0
const RETURN_AFTER := 600.0
const HEAD_K := 1.4
const HEAD_C := Vector3(0, 0.3 * HEAD_K, -1.6 * HEAD_K)
## How high its head lies over the deck after a bite (jaw resting on the planks).
const DOWN_Y := 1.3
const BANNER :=["A Sea King!", "It's rising beside the ship - man the guns!"]

var lair := Vector2.ZERO
var state: S = S.LURK
var st_t: float = 0.0
var hp: float = HP
var max_hp: float = HP
var net_puppet: bool = false
var hurtbox: Hurtbox

var _head: Node3D
var _jaw: Node3D
var _segs: Array = []
var _seg_pos: Array = []
var _target := Vector3.ZERO
var _ang: float = 0.0
var _spin: float = 1.0
var _bite_local := Vector3.ZERO
var _strike_dir := Vector3.FORWARD
var _jaw_open: float = 0.0
var _next: float = 3.0
var _dead_t: float = 0.0
var _flash_t: float = 0.0
var _rng := RandomNumberGenerator.new()
var _mat: ShaderMaterial
var _tail_at := Vector3.ZERO
var _boss_shown: bool = false


func _ready() -> void:
	add_to_group("net_sync")
	add_to_group("sea_kings")
	net_puppet = Net.is_client()
	_rng.randomize()
	_build()
	_set_hidden(true)
	if Net.hosting:
		net_rescale(Net.hp_scale())


func net_rescale(k: float) -> void:
	var frac := hp / maxf(max_hp, 1.0)
	max_hp = HP * k
	if state != S.DEAD:
		hp = maxf(frac * max_hp, 1.0)


func is_dead() -> bool:
	return state == S.DEAD


func head_position() -> Vector3:
	return _head.global_position


# --------------------------------------------------------------------------
# The body
# --------------------------------------------------------------------------
func _build() -> void:
	_mat = PSXMat.lit("roof_tiles", Color(0.5, 1.45, 1.3)).duplicate() as ShaderMaterial
	var belly := PSXMat.lit("leather", Color(1.6, 1.45, 1.0))
	var fin := PSXMat.lit("leather", Color(1.5, 0.4, 0.35))
	var along := Basis(Vector3.RIGHT, PI * 0.5)
	for i in range(SEGS):
		var r := _seg_r(i)
		var mb := MeshBuilder.new()
		# each piece runs from its joint (origin) back along +z to the next
		mb.add_cylinder(_mat, Transform3D(along, Vector3(0, 0, -SPACING * 0.15)), r, r * 0.92, SPACING * 1.3, 8, 1.0)
		mb.add_box(belly, Transform3D(Basis(), Vector3(0, -r * 0.72, SPACING * 0.5)), Vector3(r * 1.2, r * 0.4, SPACING * 1.1), 1.0)
		if i % 2 == 0 and i > 1 and i < SEGS - 2:
			mb.add_card(fin, Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(0, r * 0.8, SPACING * 0.5)), SPACING, 1.1 * r + 0.4)
		var seg := mb.to_instance("Seg%d" % i)
		add_child(seg)
		_segs.append(seg)
		_seg_pos.append(Vector3.ZERO)
	# the head: a long snout, horns, a jaw that opens, yellow eyes
	_head = Node3D.new()
	_head.name = "Head"
	add_child(_head)
	var hb := MeshBuilder.new()
	hb.add_box(_mat, Transform3D(Basis(), Vector3(0, 0.3, -1.4)), Vector3(2.4, 1.5, 3.6), 1.0)
	hb.add_box(_mat, Transform3D(Basis(), Vector3(0, 0.55, -3.6)), Vector3(1.6, 0.9, 1.4), 1.0)
	var eye := PSXMat.glow(Color(1.0, 0.85, 0.2), 3.0)
	for s in [-1.0, 1.0]:
		hb.add_box(belly, Transform3D(Basis(Vector3.RIGHT, -0.6), Vector3(s * 0.8, 1.4, 0.2)), Vector3(0.25, 1.6, 0.25), 1.0)
		hb.add_box(eye, Transform3D(Basis(), Vector3(s * 1.05, 0.75, -2.3)), Vector3(0.3, 0.3, 0.3), 1.0)
	# (scaled on a child: _head's basis is set outright every tick)
	var big := Node3D.new()
	big.scale = Vector3.ONE * HEAD_K
	_head.add_child(big)
	big.add_child(hb.to_instance("Skull"))
	_jaw = Node3D.new()
	_jaw.name = "Jaw"
	_jaw.position = Vector3(0, -0.3, 0.0)
	big.add_child(_jaw)
	var jb := MeshBuilder.new()
	jb.add_box(belly, Transform3D(Basis(), Vector3(0, -0.3, -1.8)), Vector3(2.0, 0.6, 3.6), 1.0)
	var tooth := PSXMat.lit("canvas", Color(0.95, 0.92, 0.85))
	for t in range(5):
		for s in [-1.0, 1.0]:
			jb.add_box(tooth, Transform3D(Basis(), Vector3(s * 0.75, 0.1, -0.6 - t * 0.7)), Vector3(0.15, 0.45, 0.15), 1.0)
	_jaw.add_child(jb.to_instance("JawMesh"))
	# what hits it: the head (blades, shots, powers; cannonballs via struck())
	hurtbox = Hurtbox.new()
	hurtbox.name = "Hurtbox"
	hurtbox.collision_layer = 32
	hurtbox.collision_mask = 0
	var cs := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = 2.6 * HEAD_K
	cs.shape = sh
	cs.position = HEAD_C
	hurtbox.add_child(cs)
	_head.add_child(hurtbox)
	hurtbox.owner = self
	hurtbox.hit_received.connect(_on_hit)


func _seg_r(i: int) -> float:
	return lerpf(1.55, 0.45, float(i) / (SEGS - 1))


func _set_hidden(h: bool) -> void:
	visible = not h
	hurtbox.monitorable = not h


## A basis whose -z looks along `dir` (straight up or down as well).
func _look(dir: Vector3) -> Basis:
	var d := dir.normalized()
	return Basis.looking_at(d, Vector3.UP if absf(d.y) < 0.97 else Vector3.FORWARD)


## The body follows the head like a rope, the far end sinking back into the sea.
func _drag_body(delta: float) -> void:
	var prev := _head.global_position + _head.global_basis.z * 1.2
	for i in range(SEGS):
		var p: Vector3 = _seg_pos[i]
		var d := p - prev
		if d.length() < 0.01:
			d = _head.global_basis.z
		p = prev + d.normalized() * SPACING
		var want_y: float = Ocean.get_wave_height(p, Ocean.clock()) - lerpf(0.3, 4.0, float(i) / SEGS)
		if p.y > want_y:
			p.y = lerpf(p.y, want_y, clampf(delta * (0.6 + i * 0.12), 0.0, 1.0))
		_seg_pos[i] = p
		prev = p


func _pose_segs() -> void:
	var prev := _head.global_position + _head.global_basis.z * 1.2
	for i in range(SEGS):
		var p: Vector3 = _seg_pos[i]
		var seg := _segs[i] as Node3D
		var dir := p - prev
		if dir.length() > 0.01:
			# (stretched when the tail is flung out further than the rope allows)
			var b := _look(-dir) * Basis.from_scale(Vector3(1, 1, maxf(dir.length() / SPACING, 1.0)))
			seg.global_transform = Transform3D(b, prev)
		prev = p


## The tail end rises out of the sea beside her, then comes down.
func _lift_tail() -> void:
	var up := clampf(st_t / TAIL_UP, 0.0, 1.0)
	var down := clampf((st_t - TAIL_UP) / (TAIL_SLAM - TAIL_UP), 0.0, 1.0)
	var w := clampf(st_t / 0.4, 0.0, 1.0) * clampf((TAIL_END - st_t) / 0.6, 0.0, 1.0)
	var tip := _tail_at + Vector3(0, 12.0 * up * (1.0 - down), 0)
	var base_i := SEGS - 7
	var base: Vector3 = _seg_pos[base_i]
	for j in range(1, 7):
		var k := j / 6.0
		var p := base.lerp(tip, k) + Vector3(0, sin(k * PI) * 4.0 * up * (1.0 - down * 0.7), 0)
		_seg_pos[base_i + j] = (_seg_pos[base_i + j] as Vector3).lerp(p, w)


# --------------------------------------------------------------------------
# The brain (host)
# --------------------------------------------------------------------------
func _ship() -> Node3D:
	return get_tree().get_first_node_in_group("ship") as Node3D


func _manned(ship: Node3D) -> bool:
	for p in Net.all_players():
		if ship.aboard((p as Node3D).global_position):
			return true
	return false


func _ring(sp: Vector3, ang: float, h: float) -> Vector3:
	return sp + Vector3(cos(ang), 0, sin(ang)) * CIRCLE_R + Vector3(0, h, 0)


func _physics_process(delta: float) -> void:
	if net_puppet:
		return
	st_t += delta
	var ship := _ship()
	var sp := ship.global_position
	var near := Vector2(sp.x, sp.z).distance_to(lair) < NOTICE and _manned(ship)
	match state:
		S.LURK:
			if near:
				_ang = _rng.randf() * TAU
				_surface_at(_ring(sp, _ang, -12.0))
				_set_hidden(false)
				_go(S.RISE)
				Net.fx("sfx", ["roar", sp, 10.0, 0.02, 0.55])
				_banner()
				Net.event(self, "banner", [])
			return
		S.RISE:
			_target = _ring(sp, _ang, 7.0)
			_move_head(delta, 9.0, sp + Vector3(0, 6, 0))
			if st_t > 2.2:
				Net.fx("splash", [Vector3(_head.global_position.x, 0.5, _head.global_position.z), 30, 2.5])
				_go(S.CIRCLE)
		S.CIRCLE:
			if not near and st_t > 4.0:
				_go(S.DIVE)
			else:
				_ang += _spin * delta * 0.32
				_target = _ring(sp, _ang, 6.0 + sin(st_t * 1.3) * 1.5)
				_move_head(delta, 11.0, sp + Vector3(0, 4, 0))
				_next -= delta
				if _next <= 0.0:
					var roll := _rng.randf()
					if roll < 0.5:
						_start_rear(ship)
					elif roll < 0.8:
						_start_tail(ship)
					else:
						_go(S.DIVE)
		S.REAR:
			var deck: Vector3 = ship.global_transform * _bite_local
			var flat := Vector3(_head.global_position.x - deck.x, 0, _head.global_position.z - deck.z).normalized()
			_target = deck + flat * 7.0 + Vector3(0, 13.0, 0)
			_move_head(delta, 9.0, deck)
			_jaw_open = minf(st_t / REAR_TIME, 1.0)
			if st_t > REAR_TIME:
				_strike_dir = -flat
				_go(S.STRIKE)
		S.STRIKE:
			var deck: Vector3 = ship.global_transform * _bite_local
			_target = deck + Vector3(0, DOWN_Y, 0)
			_move_head(delta, 40.0, deck + _strike_dir * 6.0 + Vector3(0, -2.0, 0))
			if _head.global_position.distance_to(_target) < 1.0 or st_t > 0.5:
				_bite(ship)
				_go(S.DOWN)
		S.DOWN:
			# its head lies on the deck: the moment to cut at it
			_jaw_open = maxf(_jaw_open - delta * 2.0, 0.2)
			_head.global_position = ship.global_transform * _bite_local + Vector3(0, DOWN_Y, 0)
			_head.global_basis = _head.global_basis.slerp(_look(_strike_dir), clampf(delta * 6.0, 0.0, 1.0))
			if st_t > DOWN_TIME:
				_next = _rng.randf_range(4.0, 7.0)
				_go(S.CIRCLE)
		S.TAIL:
			_ang += _spin * delta * 0.15
			_target = _ring(sp, _ang, 4.0)
			_move_head(delta, 8.0, sp)
			if st_t >= TAIL_SLAM and st_t - delta < TAIL_SLAM:
				_slam(ship)
			if st_t > TAIL_END:
				_next = _rng.randf_range(4.0, 7.0)
				_go(S.CIRCLE)
		S.DIVE:
			_target = _head.global_position + Vector3(0, -14.0, 0)
			_move_head(delta, 8.0, _head.global_position - _head.global_basis.z * 5.0 + Vector3(0, -6, 0))
			if st_t > 2.5:
				if near:
					_ang += PI * _rng.randf_range(0.7, 1.3)
					_spin = -_spin
					_surface_at(_ring(sp, _ang, -12.0))
					_go(S.RISE)
				else:
					_set_hidden(true)
					_go(S.LURK)
		S.DEAD:
			_dead_t += delta
			_head.global_position += Vector3(0, -2.0 * delta, 0)
			if _dead_t > SINK_TIME and visible:
				_set_hidden(true)
			if _dead_t > RETURN_AFTER:
				hp = max_hp
				_dead_t = 0.0
				_go(S.LURK)
	if visible:
		_drag_body(delta)
		if state == S.TAIL:
			_lift_tail()
		_pose_segs()
	_jaw.rotation.x = _jaw_open * 0.7


func _go(s: S) -> void:
	state = s
	st_t = 0.0


func _surface_at(at: Vector3) -> void:
	_head.global_position = at
	for i in range(SEGS):
		_seg_pos[i] = at + Vector3(0, -(i + 1) * 1.5, 0)


func _move_head(delta: float, spd: float, look: Vector3) -> void:
	_head.global_position = _head.global_position.move_toward(_target, spd * delta)
	var to := look - _head.global_position
	if to.length() > 0.1:
		_head.global_basis = _head.global_basis.orthonormalized().slerp(_look(to), clampf(delta * 4.0, 0.0, 1.0))


func _start_rear(ship: Node3D) -> void:
	_bite_local = Vector3(_rng.randf_range(-1.6, 1.6), Ship.DECK_Y, _rng.randf_range(-4.5, 4.0))
	_go(S.REAR)
	Net.fx("sfx", ["roar", _head.global_position, 6.0, 0.03, 0.75])
	Net.fx("telegraph", [ship.global_transform * _bite_local, BITE_R, REAR_TIME + 0.4, Color(1.0, 0.18, 0.12), Net.key_of(ship)])


func _start_tail(ship: Node3D) -> void:
	# the side its tail is on, just clear of her hull
	var tail: Vector3 = _seg_pos[SEGS - 1]
	var side := Vector3(tail.x - ship.global_position.x, 0, tail.z - ship.global_position.z).normalized()
	_tail_at = ship.global_position + side * 9.0
	_tail_at.y = 0.0
	_go(S.TAIL)
	Net.fx("splash", [_tail_at + Vector3(0, 0.5, 0), 16, 1.8])


func _bite(ship: Node3D) -> void:
	var at: Vector3 = ship.global_transform * _bite_local
	Net.fx("dust", [at, 20, 1.5])
	Net.fx("sfx", ["wood_crack", at, 8.0, 0.05, 0.55])
	Net.fx("sfx", ["thud", at, 6.0, 0.05, 0.5])
	(ship as Ship).hull_hit(BITE_HULL, at)
	_bite_local_hit(Net.key_of(ship), _bite_local)
	Net.event(self, "bite", [Net.key_of(ship), _bite_local])


## Each captain on their own screen: in the ring when the jaws come down?
func _bite_local_hit(ship_key: String, local: Vector3) -> void:
	var ship := Net.node_of(ship_key) as Node3D
	var me := get_tree().get_first_node_in_group("player") as Node3D
	if ship == null or me == null or not me.has_node("Hurtbox"):
		return
	CombatManager.apply_camera_shake(0.45)
	var hb := me.get_node("Hurtbox") as Hurtbox
	if not hb.monitorable:
		return
	var at: Vector3 = ship.global_transform * local
	var d := Vector2(me.global_position.x - at.x, me.global_position.z - at.z).length()
	if d > BITE_R or me.global_position.y > at.y + 1.6:
		return  # clear of it, or jumped over the jaws
	var hd := HitData.new()
	hd.damage = BITE_DMG
	hd.knockdown = true
	hd.unblockable = true
	hd.knockback_force = 9.0
	hd.stagger_duration = 0.4
	hd.hitstop_duration = 0.06
	hd.camera_shake_intensity = 0.3
	hb.take_hit(hd, self)


func _slam(ship: Node3D) -> void:
	Net.fx("splash", [_tail_at + Vector3(0, 0.6, 0), 40, 3.0])
	Net.fx("sfx", ["splash_big", _tail_at, 8.0, 0.05, 0.6])
	var push := ship.global_position - _tail_at
	push.y = 0.0
	Net.everyone("_all_rammed", [Net.key_of(ship), _tail_at, push.normalized() * 1.2])


func _banner() -> void:
	get_tree().call_group("hud", "show_banner", BANNER[0], BANNER[1], true)
	GameManager.charted["king"] = true


# --------------------------------------------------------------------------
# Taking hits
# --------------------------------------------------------------------------
## Where a cannonball flying from `from` to `to` strikes it (INF: a miss).
func struck(from: Vector3, to: Vector3) -> Vector3:
	if not visible or state == S.LURK or state == S.DEAD:
		return Vector3.INF
	var c := _head.global_transform * HEAD_C
	var q := Geometry3D.get_closest_point_to_segment(c, from, to)
	if q.distance_to(c) < 2.8 * HEAD_K:
		return q
	for i in range(SEGS):
		var p: Vector3 = _seg_pos[i]
		q = Geometry3D.get_closest_point_to_segment(p, from, to)
		if q.distance_to(p) < _seg_r(i) + 0.4:
			return q
	return Vector3.INF


func _on_hit(hit: HitData, _attacker: Node) -> void:
	if state == S.LURK or state == S.DEAD:
		return
	var dmg := hit.damage * (1.5 if hit.siege else 1.0)
	hp = maxf(hp - dmg, 0.0)
	Net.damage_number(dmg, _head.global_position + Vector3(0, 2.5, 0))
	Net.fx("blood", [_head.global_position, Vector3.UP, 20])
	_flash_t = 0.12
	Net.event(self, "flash", [])
	if hp <= 0.0:
		_die()


func _die() -> void:
	_go(S.DEAD)
	_dead_t = 0.0
	_jaw_open = 1.0
	hurtbox.set_deferred("monitorable", false)
	Net.award_xp(400, _head.global_position, 120.0)
	_dead_fx()
	Net.event(self, "dead", [])


## (every screen) The death roar, the banner, its hoard floating up: each
## captain finds their own.
func _dead_fx() -> void:
	FX.sfx("roar", _head.global_position, 8.0, 0.02, 0.4)
	FX.splash(_head.global_position, 40, 3.0)
	get_tree().call_group("hud", "show_banner", "The Sea King falls!", "Its hoard floats up from the deep.", true)
	var bag := (load("res://scenes/loot/loot_bag.tscn") as PackedScene).instantiate() as LootBag
	var items: Array[ItemStack] = []
	for e in [["gold", 90], ["treasure", 6], ["rum", 3]]:
		var st := ItemStack.new()
		st.item = load("res://resources/items/%s.tres" % e[0]) as ItemData
		st.quantity = int(e[1])
		items.append(st)
	bag.setup(items, false)
	bag.floating = true
	bag.name = "SeaKingHoard"
	get_tree().current_scene.add_child(bag)
	bag.global_position = Vector3(_head.global_position.x, 0.0, _head.global_position.z)


func _process(delta: float) -> void:
	if _flash_t > 0.0:
		_flash_t -= delta
		_mat.set_shader_parameter("tint_mul", Color(2.2, 1.4, 1.4) if _flash_t > 0.0 else Color(1, 1, 1))
	if net_puppet:
		_puppet()
	# the boss bar while it's up and we're near
	var me := get_tree().get_first_node_in_group("player") as Node3D
	var show := visible and state != S.DEAD and state != S.LURK and me != null and me.global_position.distance_to(_head.global_position) < 150.0
	if show:
		get_tree().call_group("hud", "show_boss", "Sea King", hp / maxf(max_hp, 1.0), 1)
		_boss_shown = true
	elif _boss_shown:
		_boss_shown = false
		get_tree().call_group("hud", "hide_boss")


# --------------------------------------------------------------------------
# Co-op
# --------------------------------------------------------------------------
func net_pack() -> Array:
	return [int(state), hp, max_hp, _head.global_position, _head.global_basis.get_rotation_quaternion(), _jaw_open,
		PackedVector3Array(_seg_pos), visible]


func _puppet() -> void:
	var smp := Net.sample(self)
	if smp.is_empty():
		return
	var a: Array = smp[0]
	var b: Array = smp[1]
	var f: float = smp[2]
	state = int(b[0]) as S
	hp = float(b[1])
	max_hp = float(b[2])
	visible = bool(b[7])
	hurtbox.monitorable = visible and state != S.DEAD
	_head.global_position = (a[3] as Vector3).lerp(b[3], f)
	_head.global_basis = Basis((a[4] as Quaternion).slerp(b[4], f))
	_jaw.rotation.x = lerpf(float(a[5]), float(b[5]), f) * 0.7
	var sa: PackedVector3Array = a[6]
	var sb: PackedVector3Array = b[6]
	for i in range(SEGS):
		_seg_pos[i] = sa[i].lerp(sb[i], f)
	_pose_segs()


func net_event(what: String, args: Array) -> void:
	match what:
		"bite":
			_bite_local_hit(str(args[0]), args[1])
		"flash":
			_flash_t = 0.12
		"dead":
			_dead_fx()
		"banner":
			_banner()
