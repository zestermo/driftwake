class_name BoardingBoat
extends Node3D
## A longboat of boarders (docs/v1_23_plan.md, sea pursuit): a pirate that can't catch the crew's ship lowers it with
## the next men of her crew in it (their own bodies, seated at the oars) and they row hard for the crew's side while
## she sails on. Close enough, they leap aboard as boarders (EnemyShip.boat_landed) and the boat drifts astern. A
## crew cannon ball landing on or beside it, or enough shot, sinks it with the men.
##
## Co-op: the host rows it (group net_sync: [position, yaw, state]); every screen builds the same boat from the
## ship's "boat" event (named Boat_<ship>_<n>, beside her), with the same men moved into it.

enum B { ROWING, LANDED, SUNK, ADRIFT }

## Sprinting at the oars: a touch quicker than the crew's ship under full sail, and it heads her off.
const SPEED := 14.0
const TURN := 1.4
## Within this of its spot off the crew's side, the men leap.
const REACH := 6.5
## Rowing this long without getting there, they give up and drift.
const GIVE_UP := 50.0
const HP := 40.0
## A crew ball landing this close (m) sinks it.
const SPLASH_R := 4.5
const GONE_AFTER := 12.0
## Where the men sit (feet on the bottom boards, on the thwarts at Humanoid.seat_y).
const SEATS := [Vector3(-0.4, 0.06, -1.3), Vector3(0.4, 0.06, -0.2), Vector3(-0.4, 0.06, 0.9), Vector3(0.4, 0.06, 2.0)]

var from_ship: Node3D
## The crew indices aboard (EnemyShip._crew).
var men: Array = []
var side: float = 1.0
var state: B = B.ROWING
var hurtbox: Hurtbox
var net_puppet: bool = false
var _hp: float = HP
var _t: float = 0.0
var _end_t: float = 0.0
var _yaw: float = 0.0
var _speed: float = 0.0
var _oars: Array = []
var _bodies: Array = []
static var _mesh: Mesh
static var _oar_mesh: Mesh


## (every screen) Lower a boat from `ship` on her `side` with crew `men_idx` in it, the ship's `n`th.
static func launch(ship: Node3D, men_idx: Array, on_side: float, n: int) -> BoardingBoat:
	var b := BoardingBoat.new()
	b.name = "Boat_%s_%d" % [ship.name, n]
	b.from_ship = ship
	b.men = men_idx
	b.side = on_side
	ship.get_parent().add_child(b)
	var at: Vector3 = ship.global_transform * Vector3(on_side * 6.5, 0.0, 1.5)
	b._yaw = ship.global_rotation.y
	b.global_position = Vector3(at.x, 0.0, at.z)
	b.reset_physics_interpolation()
	b._take_men()
	return b


func _ready() -> void:
	add_to_group("net_sync")
	add_to_group("boarding_boats")
	net_puppet = Net.is_client()
	var mi := MeshInstance3D.new()
	mi.mesh = _boat_mesh()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visibility_range_end = 260.0
	add_child(mi)
	for s in [-1.0, 1.0]:
		for z in [-0.8, 1.2]:
			var oar := MeshInstance3D.new()
			oar.mesh = _oar()
			oar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			oar.visibility_range_end = 200.0
			oar.position = Vector3(s * 0.85, 0.55, z)
			oar.set_meta("side", s)
			add_child(oar)
			_oars.append(oar)
	hurtbox = Hurtbox.new()
	hurtbox.name = "Hurtbox"
	hurtbox.collision_layer = 32
	hurtbox.collision_mask = 0
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.2, 1.6, 6.0)
	cs.shape = box
	cs.position = Vector3(0, 0.6, 0)
	hurtbox.add_child(cs)
	add_child(hurtbox)
	hurtbox.owner = self
	hurtbox.hit_received.connect(_on_hit)


## The men climb down into her: their own bodies, seated at the oars.
func _take_men() -> void:
	var crew: Array = from_ship.get("_crew")
	for i in range(men.size()):
		var c: Dictionary = crew[int(men[i])]
		c["gone"] = true
		var h := c["node"] as Humanoid
		h.reparent(self, false)
		h.position = SEATS[i % SEATS.size()]
		# (rowers face astern)
		h.rotation = Vector3.ZERO
		h.seated = true
		h.visible = true
		_bodies.append(h)


func is_dead() -> bool:
	return state == B.SUNK


func _physics_process(delta: float) -> void:
	_t += delta
	if net_puppet:
		_puppet()
	elif state == B.ROWING:
		_row(delta)
	else:
		_speed = move_toward(_speed, 0.0, 3.0 * delta)
		global_position += Vector3(-sin(_yaw), 0.0, -cos(_yaw)) * _speed * delta
	if state != B.ROWING:
		_end_t += delta
		if state == B.SUNK:
			global_position.y -= delta * 0.8
		if _end_t > GONE_AFTER:
			queue_free()
		return
	_float()


## (host) Row for a spot off the crew's side, a little ahead of where she'll be; there, the men leap.
func _row(delta: float) -> void:
	var ship := get_tree().get_first_node_in_group("ship") as Node3D
	if ship == null or not is_instance_valid(from_ship) or _t > GIVE_UP:
		_set_state(B.ADRIFT)
		return
	var l: Vector3 = ship.global_transform.affine_inverse() * global_position
	var s := 1.0 if l.x > 0.0 else -1.0
	var spot: Vector3 = ship.global_transform * Vector3(s * (HullBuilder.half_width(0.0) + 2.2), 0.0, clampf(l.z, -6.0, 3.0))
	# (an intercept: where she'll be by the time they get there)
	var gap := spot - global_position
	gap.y = 0.0
	var to: Vector3 = gap + ship.call("hull_velocity") * clampf(gap.length() / SPEED, 0.3, 6.0)
	var want := atan2(-to.x, -to.z)
	_yaw = wrapf(_yaw + clampf(wrapf(want - _yaw, -PI, PI), -TURN * delta, TURN * delta), -PI, PI)
	_speed = move_toward(_speed, SPEED, 4.0 * delta)
	global_position += Vector3(-sin(_yaw), 0.0, -cos(_yaw)) * _speed * delta
	if gap.length() < REACH:
		_set_state(B.LANDED)
		from_ship.call("boat_landed", self, ship)


func _float() -> void:
	var y := float(Ocean.get_wave_height(global_position, Ocean.clock()))
	var rock := sin(_t * 1.7) * 0.05
	global_transform = Transform3D(Basis.from_euler(Vector3(rock * 0.6, _yaw, rock)), Vector3(global_position.x, y - 0.2, global_position.z))
	# (each oar's blade outboard: a sweep fore and aft, dipping as it pulls)
	var ph := _t * 5.0
	for o in _oars:
		var s: float = o.get_meta("side")
		var out := 0.0 if s > 0.0 else PI
		o.rotation = Vector3(0.0, out + sin(ph) * 0.4 * s, -0.3 - cos(ph) * 0.15)


func _set_state(s: B) -> void:
	state = s
	_end_t = 0.0


func _on_hit(hit: HitData, _attacker: Node) -> void:
	if state == B.SUNK or net_puppet:
		return
	_hp -= hit.damage * (3.0 if hit.siege else 1.0)
	if _hp <= 0.0:
		sink()


## (host) Holed: down she goes, the men in her with her.
func sink() -> void:
	if state == B.SUNK:
		return
	if state == B.ROWING:
		var k: float = float(from_ship.get("xp_k")) if is_instance_valid(from_ship) else 1.0
		Net.award_xp(roundi(25.0 * k), global_position, 160.0)
	_set_state(B.SUNK)
	Net.event(self, "sink", [])
	_sunk_fx()


func _sunk_fx() -> void:
	FX.cannon_splash(global_position)
	FX.sfx("wood_crack", global_position, 2.0, 0.05, 0.9)
	for h in _bodies:
		if is_instance_valid(h) and (h as Node).get_parent() == self:
			(h as Node3D).visible = false


func net_pack() -> Array:
	return [global_position, _yaw, int(state)]


func _puppet() -> void:
	var smp := Net.sample(self)
	if smp.is_empty():
		return
	var a: Array = smp[0]
	var b: Array = smp[1]
	if a.size() < 3 or b.size() < 3:
		return
	var f: float = smp[2]
	var p: Vector3 = (a[0] as Vector3).lerp(b[0], f)
	global_position = Vector3(p.x, global_position.y, p.z)
	_yaw = lerp_angle(float(a[1]), float(b[1]), f)
	var st := int(b[2]) as B
	if st != state:
		_set_state(st)
		if st == B.SUNK:
			_sunk_fx()


func net_event(what: String, _args: Array) -> void:
	if what == "sink" and state != B.SUNK:
		_set_state(B.SUNK)
		_sunk_fx()


## (the crew's shooter) A crew ball splashing down by a boat holes it.
static func near_splash(tree: SceneTree, at: Vector3, dmg: float, by: Node) -> void:
	for b in tree.get_nodes_in_group("boarding_boats"):
		var boat := b as BoardingBoat
		if boat.state == B.ROWING and Vector2(at.x - boat.global_position.x, at.z - boat.global_position.z).length() < SPLASH_R:
			var hd := HitData.new()
			hd.damage = dmg
			hd.siege = true
			hd.unblockable = true
			hd.ranged = true
			hd.knockback_force = 0.0
			boat.hurtbox.take_hit(hd, by)


static func _boat_mesh() -> Mesh:
	if _mesh:
		return _mesh
	var mb := MeshBuilder.new()
	var wood := PSXMat.lit("planks", Color(0.62, 0.5, 0.4))
	var dark := PSXMat.lit("planks_dark")
	# a flat bottom, sides flaring out, a pointed bow and a square stern; thwarts across
	mb.add_box(dark, Transform3D(Basis(), Vector3(0, 0.0, 0.3)), Vector3(1.3, 0.12, 4.6), 0.8, Color.WHITE, false)
	for s in [-1.0, 1.0]:
		mb.add_box(wood, Transform3D(Basis(Vector3.BACK, s * 0.35), Vector3(s * 0.78, 0.32, 0.4)), Vector3(0.08, 0.6, 4.4), 0.8, Color.WHITE, false)
		mb.add_box(wood, Transform3D(Basis(Vector3.UP, s * 0.55), Vector3(s * 0.38, 0.32, -2.45)), Vector3(0.08, 0.6, 1.5), 0.8, Color.WHITE, false)
	mb.add_box(wood, Transform3D(Basis(), Vector3(0, 0.32, 2.6)), Vector3(1.75, 0.6, 0.08), 0.8, Color.WHITE, false)
	for z in [-1.3, -0.2, 0.9, 2.0]:
		mb.add_box(wood, Transform3D(Basis(), Vector3(0, 0.5, z)), Vector3(1.5, 0.06, 0.28), 0.8)
	_mesh = mb.commit()
	return _mesh


static func _oar() -> Mesh:
	if _oar_mesh:
		return _oar_mesh
	var mb := MeshBuilder.new()
	var wood := PSXMat.lit("planks", Color(0.75, 0.62, 0.45))
	mb.add_box(wood, Transform3D(Basis(), Vector3(0.9, 0, 0)), Vector3(2.6, 0.06, 0.06), 0.8)
	mb.add_box(wood, Transform3D(Basis(), Vector3(2.1, 0, 0)), Vector3(0.6, 0.03, 0.2), 0.8)
	_oar_mesh = mb.commit()
	return _oar_mesh
