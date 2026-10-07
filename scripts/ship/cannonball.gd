extends Node3D
class_name Cannonball
## An iron ball from a ship's cannon. A plain ballistic flight (the same on
## every machine, so the copies on the other screens fly the same arc), then
## it bursts on whatever it meets: a hull, the deck, a rock, someone's head -
## or the sea, with a big splash.
##
## Damage (co-op: decided where it matters):
## * Fired by the crew (team "crew"): only the shooter's own copy deals
##   damage. A direct hit on an enemy ship hurts its hull (through the ship's
##   Hurtbox, so a client's hit goes to the host); the burst knocks down
##   enemies nearby. Captains are never hurt by their own side's fire.
## * Fired by an enemy ship (team "enemy"): every machine checks its own
##   captain against the burst (dodge it!); the host decides hull damage to
##   the crew's ship.
##
## An enemy ball can be stopped in flight (its Hurtbox takes captains'
## attacks): a cutting blow from a katana or a cutlass slices it in two (the
## halves fly on, split apart, and nothing bursts); a bullet or a power sets
## it off in mid-air. Whoever stops it tells every screen; with crewmates
## around, a burst's damage waits GRACE seconds first, so a cut that lands
## just before it on another screen still counts.

const GRAVITY := 14.0
const LIFETIME := 7.0
const BURST := 2.7
const GRACE := 0.35
## Blades that can cut a ball in two (weapon models).
const CUTTERS := ["katana", "cutlass"]
## The halves part this far either side of the ball's line, and last this long.
const SPLIT := PI * 0.25
const HALF_LIFE := 20.0

var velocity := Vector3.ZERO
var team: String = "crew"
## This copy decides damage (see above).
var authority: bool = false
var shooter: Node = null
var hull_damage: float = 30.0
var splash_damage: float = 22.0
## The same on every screen: "<cannon key>#<shot>".
var id: String = ""
var hurtbox: Hurtbox
var _t: float = 0.0
var _exclude: Array[RID] = []
var _trail_t: float = 0.0
var _done: bool = false
var _cancelled: bool = false
var _mi: MeshInstance3D

static var _mesh: Mesh
static var _half_mesh: Mesh
## Balls in flight by id (and recently burst ones, while their damage waits).
static var live: Dictionary = {}


## Fire one. `ship` (the firing ship) is ignored by the flight for the first
## moment so the ball doesn't burst on its own bulwark.
static func launch(tree: SceneTree, from: Vector3, vel: Vector3, team_name: String, auth: bool, by: Node,
		ship: CollisionObject3D = null, shot_id: String = "") -> Cannonball:
	var b := Cannonball.new()
	b.velocity = vel
	b.team = team_name
	b.authority = auth
	b.shooter = by
	b.id = shot_id
	if ship:
		b._exclude.append(ship.get_rid())
	var root := tree.current_scene if tree.current_scene else tree.root
	root.add_child(b)
	b.global_position = from
	return b


func _ready() -> void:
	add_to_group("cannonballs")
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	if _mesh == null:
		var sm := SphereMesh.new()
		sm.radius = 0.17
		sm.height = 0.34
		sm.radial_segments = 6
		sm.rings = 4
		sm.material = PSXMat.lit("metal", Color(0.18, 0.17, 0.17))
		_mesh = sm
	_mi = MeshInstance3D.new()
	_mi.mesh = _mesh
	_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mi)
	if id != "":
		live[id] = self
	if team == "enemy":
		# generous: catching it is a timing skill, not a pixel hunt
		hurtbox = Hurtbox.new()
		hurtbox.name = "Hurtbox"
		hurtbox.collision_layer = 32
		hurtbox.collision_mask = 0
		var cs := CollisionShape3D.new()
		var sh := SphereShape3D.new()
		sh.radius = 0.9
		cs.shape = sh
		hurtbox.add_child(cs)
		add_child(hurtbox)
		hurtbox.owner = self
		hurtbox.hit_received.connect(_on_hit)


func _exit_tree() -> void:
	if id != "" and live.get(id) == self:
		live.erase(id)


func _physics_process(delta: float) -> void:
	if _done:
		return
	_t += delta
	if _t > LIFETIME:
		queue_free()
		return
	var from := global_position
	velocity.y -= GRAVITY * delta
	var to := from + velocity * delta
	# the sea
	var sea := _sea(to)
	# what's in the way: terrain, hulls, docks, bodies (an enemy ball bursts on a
	# captain it hits square, instead of flying on through them)
	var q := PhysicsRayQueryParameters3D.create(from, to, 1 | 4 | 2048 | (2 if team == "enemy" else 0))
	q.exclude = _exclude if _t < 0.25 else []
	q.hit_from_inside = false
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty() and (hit["position"] as Vector3).y > sea - 0.05:
		_burst(hit["position"], hit["collider"] as Node, hit.get("normal", Vector3.UP))
		return
	if team == "crew":
		for k in get_tree().get_nodes_in_group("sea_kings"):
			var at: Vector3 = k.struck(from, to)
			if at != Vector3.INF and at.y > sea - 0.05:
				_burst(at, k, (from - to).normalized())
				return
	if to.y < sea:
		var t := clampf((from.y - sea) / maxf(from.y - to.y, 0.001), 0.0, 1.0)
		_splash(from.lerp(to, t))
		return
	global_position = to
	_trail_t -= delta
	if _trail_t <= 0.0:
		_trail_t = 0.05
		FX.smoke(from, 1, 0.35, 0.6)


func _sea(at: Vector3) -> float:
	var oc := get_node_or_null("/root/Ocean")
	if oc and oc.has_method("get_wave_height"):
		var t: float = oc.call("clock") if oc.has_method("clock") else 0.0
		return float(oc.call("get_wave_height", at, t))
	return 0.0


func _shake(at: Vector3, strength: float) -> void:
	var me := get_tree().get_first_node_in_group("player") as Node3D
	if me == null:
		return
	var d := me.global_position.distance_to(at)
	var k := clampf(1.0 - d / 30.0, 0.0, 1.0)
	if k > 0.0:
		CombatManager.apply_camera_shake(strength * k)


func _splash(at: Vector3) -> void:
	_done = true
	FX.splash(at, 10, 1.4)
	FX.splash(at + Vector3(0, 0.6, 0), 6, 0.9)
	FX.sfx("splash_big", at, -2.0, 0.08)
	_shake(at, 0.08)
	_finish(func(): _check_crew(at, BURST * 0.7, splash_damage * 0.6))


func _burst(at: Vector3, col: Node, normal: Vector3) -> void:
	_done = true
	FX.impact(at, Color(1.0, 0.7, 0.35))
	FX.flame(at, 12, 0.8, 0.45, 0.6)
	FX.smoke(at + normal * 0.3, 8, 1.3, 1.8)
	FX.dust(at, 8, 0.9)
	FX.sfx("cannon_hit", at, 0.0, 0.08)
	_shake(at, 0.25)
	var ship := _ship_of(col)
	if ship:
		FX.sfx("wood_crack", at, -2.0, 0.1)
	if team == "crew":
		if authority:
			var hd := HitData.new()
			hd.damage = hull_damage
			hd.siege = true
			hd.unblockable = true
			hd.ranged = true
			hd.knockback_force = 0.0
			hd.hitstop_duration = 0.0
			hd.camera_shake_intensity = 0.0
			var hit_ship := false
			if ship and ship.has_method("is_dead") and ship.get("hurtbox"):
				(ship.get("hurtbox") as Hurtbox).take_hit(hd, shooter)
				hit_ship = true
			elif col and col.is_in_group("sea_kings"):
				(col.get("hurtbox") as Hurtbox).take_hit(hd, shooter)
				hit_ship = true
			_burst_enemies(at, hit_ship)
		queue_free()
		return
	_finish(func():
		_check_crew(at, BURST, splash_damage)
		# the host decides what happens to the crew's ship
		if ship is Ship and not Net.is_client():
			(ship as Ship).hull_hit(hull_damage, at))


## An enemy ball's damage: now alone, after GRACE with crewmates (it may yet
## turn out to have been cut on another screen).
func _finish(damage: Callable) -> void:
	if team == "crew":
		queue_free()
		return
	if not Net.coop():
		damage.call()
		queue_free()
		return
	_mi.visible = false
	if hurtbox:
		hurtbox.set_deferred("monitorable", false)
	await get_tree().create_timer(GRACE).timeout
	if not _cancelled:
		damage.call()
	queue_free()


## The ship a collider belongs to (or null).
func _ship_of(n: Node) -> Node:
	while n:
		if n is Ship or n.is_in_group("enemy_ships"):
			return n
		n = n.get_parent()
	return null


## Crew fire: knock down the enemies around the burst (not ship hulls).
func _burst_enemies(at: Vector3, skip_ships: bool) -> void:
	var sh := SphereShape3D.new()
	sh.radius = BURST
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = sh
	q.transform = Transform3D(Basis.IDENTITY, at)
	q.collide_with_areas = true
	q.collide_with_bodies = false
	q.collision_mask = 32
	var done := {}
	for r in get_world_3d().direct_space_state.intersect_shape(q, 24):
		var hb := r["collider"] as Hurtbox
		if hb == null or not hb.monitorable:
			continue
		var o := hb.owner
		if o == null or done.has(o) or o is Cannonball:
			continue
		if o.is_in_group("enemy_ships") or o.is_in_group("sea_kings"):
			if skip_ships:
				continue
			# a near miss still rattles the hull a little
			var hs := HitData.new()
			hs.damage = hull_damage * 0.35
			hs.siege = true
			hs.unblockable = true
			hs.ranged = true
			hs.knockback_force = 0.0
			done[o] = true
			hb.take_hit(hs, shooter)
			continue
		done[o] = true
		var hd := HitData.new()
		hd.damage = splash_damage + 8.0
		hd.knockdown = true
		hd.unblockable = true
		hd.knockback_force = 8.0
		hd.hitstop_duration = 0.0
		hd.camera_shake_intensity = 0.0
		hb.take_hit(hd, shooter)


## Enemy fire: this machine's captain, if they're in the burst.
func _check_crew(at: Vector3, radius: float, dmg: float) -> void:
	if team == "crew":
		return
	var me := get_tree().get_first_node_in_group("player") as Node3D
	if me == null or not me.has_node("Hurtbox"):
		return
	var hb := me.get_node("Hurtbox") as Hurtbox
	if not hb.monitorable:
		return  # dodging (i-frames) or already down
	var c := me.global_position + Vector3(0, 0.9, 0)
	if c.distance_to(at) > radius:
		return
	var hd := HitData.new()
	hd.damage = dmg
	hd.knockdown = true
	hd.unblockable = true
	hd.knockback_force = 7.0
	hd.stagger_duration = 0.4
	hd.hitstop_duration = 0.05
	hd.camera_shake_intensity = 0.25
	hb.take_hit(hd, self)  # (knocked away from the burst)


# --------------------------------------------------------------------------
# Stopped in flight
# --------------------------------------------------------------------------
## One of our captain's attacks reached it.
func _on_hit(hit: HitData, attacker: Node) -> void:
	if _done or hit.dot:
		return
	if hit.ranged or hit.siege:
		_stop("pop", attacker)
	elif hit.sever and _blade_of(attacker) in CUTTERS:
		_stop("cut", attacker)


## The weapon model in a captain's hand ("" if none).
static func _blade_of(by: Node) -> String:
	var w = by.get("equipped_weapon") if by else null
	return str(w.weapon_model) if w else ""


func _stop(what: String, by: Node) -> void:
	var me := get_tree().get_first_node_in_group("player")
	if by == me and what == "cut":
		CombatManager.apply_hitstop(0.07, [me])
		CombatManager.apply_camera_shake(0.12)
	Net.everyone("_all_ball", [id, what, global_position, velocity, Net.my_id()])


## Every screen (Net._all_ball): what became of ball `ball_id`.
static func net_act(ball_id: String, what: String, at: Vector3, vel: Vector3, _by_id: int) -> void:
	var b = live.get(ball_id)
	if b == null or not is_instance_valid(b):
		return
	var ball := b as Cannonball
	ball._cancelled = true
	if ball._done:
		return  # already burst here: just no damage
	match what:
		"cut":
			ball._cut(at, vel)
		"pop":
			ball._pop(at)


## Sliced in two: the halves carry on with the ball's momentum, parted 45
## degrees either side of its line, and tumble off into the sea or onto the
## deck behind whoever cut it. Nothing bursts.
func _cut(at: Vector3, vel: Vector3) -> void:
	_done = true
	var side := vel.normalized().cross(Vector3.UP).normalized()
	if side.length() < 0.1:
		side = Vector3.RIGHT
	FX.muzzle_sparks(at, side, 14)
	FX.muzzle_sparks(at, -side, 14)
	FX.sparkle(at, 8, Color(1.0, 0.85, 0.5))
	FX.sfx("parry", at, 2.0, 0.05, 0.7)
	if _half_mesh == null:
		var hm := SphereMesh.new()
		hm.radius = 0.17
		hm.height = 0.17
		hm.is_hemisphere = true
		hm.radial_segments = 6
		hm.rings = 2
		hm.material = PSXMat.lit("metal", Color(0.24, 0.22, 0.21))
		_half_mesh = hm
	for s in [-1.0, 1.0]:
		var half := Half.new()
		var cs := CollisionShape3D.new()
		var sh := SphereShape3D.new()
		sh.radius = 0.12
		cs.shape = sh
		half.add_child(cs)
		var mi := MeshInstance3D.new()
		mi.mesh = _half_mesh
		# flat face toward the other half
		mi.rotation = Vector3(0, 0, PI * 0.5 * s)
		half.add_child(mi)
		get_tree().current_scene.add_child(half)
		half.global_position = at + side * 0.1 * s
		half.look_at(at + vel, Vector3.UP)
		half.linear_velocity = vel.rotated(Vector3.UP, SPLIT * s)
		half.angular_velocity = side * s * 10.0 + Vector3(0, randf_range(-6, 6), 0)
		get_tree().create_timer(HALF_LIFE).timeout.connect(half.queue_free)
	queue_free()


## Set off in mid-air: a burst nobody is under.
func _pop(at: Vector3) -> void:
	_done = true
	FX.impact(at, Color(1.0, 0.7, 0.35))
	FX.flame(at, 10, 0.7, 0.4, 0.5)
	FX.smoke(at, 6, 1.2, 1.6)
	FX.sfx("cannon_hit", at, -3.0, 0.08, 1.2)
	queue_free()


## Half a cut ball: bounces on decks and rocks, splashes into the sea and
## sinks slowly.
class Half extends RigidBody3D:
	var _wet: bool = false

	func _init() -> void:
		collision_layer = 0
		collision_mask = 1
		mass = 4.0
		continuous_cd = true

	func _physics_process(_delta: float) -> void:
		if _wet:
			return
		var oc := get_node_or_null("/root/Ocean")
		if oc and global_position.y < float(oc.call("get_wave_height", global_position)):
			_wet = true
			FX.splash(global_position, 6, 0.8)
			FX.sfx("splash", global_position, -6.0, 0.1, 1.3)
			linear_damp = 4.0
			angular_damp = 3.0
			gravity_scale = 0.25
