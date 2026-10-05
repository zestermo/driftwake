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

const GRAVITY := 14.0
const LIFETIME := 7.0
const BURST := 2.7

var velocity := Vector3.ZERO
var team: String = "crew"
## This copy decides damage (see above).
var authority: bool = false
var shooter: Node = null
var hull_damage: float = 30.0
var splash_damage: float = 22.0
var _t: float = 0.0
var _exclude: Array[RID] = []
var _trail_t: float = 0.0
var _done: bool = false

static var _mesh: Mesh


## Fire one. `ship` (the firing ship) is ignored by the flight for the first
## moment so the ball doesn't burst on its own bulwark.
static func launch(tree: SceneTree, from: Vector3, vel: Vector3, team_name: String, auth: bool, by: Node, ship: CollisionObject3D = null) -> Cannonball:
	var b := Cannonball.new()
	b.velocity = vel
	b.team = team_name
	b.authority = auth
	b.shooter = by
	if ship:
		b._exclude.append(ship.get_rid())
	var root := tree.current_scene if tree.current_scene else tree.root
	root.add_child(b)
	b.global_position = from
	return b


func _ready() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	if _mesh == null:
		var sm := SphereMesh.new()
		sm.radius = 0.17
		sm.height = 0.34
		sm.radial_segments = 6
		sm.rings = 4
		sm.material = PSXMat.lit("metal", Color(0.18, 0.17, 0.17))
		_mesh = sm
	var mi := MeshInstance3D.new()
	mi.mesh = _mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


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
	# what's in the way: terrain, hulls, docks, bodies
	var q := PhysicsRayQueryParameters3D.create(from, to, 1 | 4 | 2048)
	q.exclude = _exclude if _t < 0.25 else []
	q.hit_from_inside = false
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty() and (hit["position"] as Vector3).y > sea - 0.05:
		_burst(hit["position"], hit["collider"] as Node, hit.get("normal", Vector3.UP))
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
	_check_crew(at, BURST * 0.7, splash_damage * 0.6)
	queue_free()


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
			_burst_enemies(at, hit_ship)
	else:
		_check_crew(at, BURST, splash_damage)
		# the host decides what happens to the crew's ship
		if ship is Ship and not Net.is_client():
			(ship as Ship).hull_hit(hull_damage, at)
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
		if o == null or done.has(o):
			continue
		if o.is_in_group("enemy_ships"):
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
