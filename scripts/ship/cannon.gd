extends Node3D
class_name ShipCannon
## A swivel cannon on a ship's rail. Local -Z points out over the side; the
## barrel swings `yaw` (left/right) and `pitch` (up/down) around that.
##
## On the crew's ship anyone can man one (F): their own camera behind the
## barrel, the mouse aims, a dotted arc shows where the ball will fall,
## left click fires (then it reloads). The helmsman can also fire every
## loaded, unmanned gun on one side at once (a broadside). Enemy ships fire
## theirs from their AI.
##
## Co-op: one captain per cannon (the host hands out the seats); firing
## sends a copy of the shot to every other screen (Net.event "fire").

signal fired

const MUZZLE_SPEED := 46.0
const YAW_LIMIT := 0.9
const PITCH_MIN := -0.14
const PITCH_MAX := 0.42
const PIVOT_Y := 0.88
const BARREL := 1.15

@export var reload_time: float = 3.2
## "crew" (the player's ship) or "enemy".
@export var team: String = "crew"
## Can a captain man it (shows the F prompt)?
@export var mannable: bool = true

var ship: CollisionObject3D
var yaw: float = 0.0
var pitch: float = 0.08
var cool: float = 0.0
var hull_damage: float = 30.0
var splash_damage: float = 22.0
var interactable: Interactable
var camera: Camera3D
## A captain is aiming it on this machine (draws the arc).
var aiming_locally: bool = false

var _yaw_node: Node3D
var _pitch_node: Node3D
var _barrel: Node3D
var _recoil: float = 0.0
## Shots fired so far: with the gun's key, the ball's name on every screen.
var _shots: int = 0
var _arc: MeshInstance3D
var _arc_mesh: ImmediateMesh
var _cam_arm: Node3D
var _cam_pitch: float = 0.0

static var _arc_mat: StandardMaterial3D


func _ready() -> void:
	_build()
	if mannable:
		interactable = Interactable.new()
		interactable.name = "Seat"
		interactable.collision_layer = 512
		interactable.collision_mask = 0
		interactable.prompt_text = "Press F to man the cannon"
		var cs := CollisionShape3D.new()
		var sp := SphereShape3D.new()
		sp.radius = 1.1
		cs.shape = sp
		interactable.add_child(cs)
		interactable.position = Vector3(0, 0.6, 0.9)
		add_child(interactable)
		interactable.interacted.connect(_on_interact)
		# the gunner's camera: behind and above the breech, looking out
		_cam_arm = Node3D.new()
		_cam_arm.name = "CamArm"
		# (aimed every frame; the hull under it is still interpolated)
		_cam_arm.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		_cam_arm.position = Vector3(0, PIVOT_Y, 0)
		_yaw_node.add_child(_cam_arm)
		camera = Camera3D.new()
		camera.name = "GunCam"
		camera.fov = 62.0
		# (the fog is solid by 820 m)
		camera.far = 1200.0
		# over the gunner's right shoulder
		camera.position = Vector3(0.75, 1.5, 3.3)
		camera.rotation = Vector3(-0.2, 0.12, 0)
		_cam_arm.add_child(camera)


func _build() -> void:
	var wood := PSXMat.lit("planks_dark")
	var iron := PSXMat.lit("metal", Color(0.24, 0.23, 0.22))
	var brass := PSXMat.lit("metal", Color(1.0, 0.78, 0.4))
	# the post and its iron yoke stay put; the yoke turns
	var base := MeshBuilder.new()
	base.add_box(wood, Transform3D(Basis(), Vector3(0, 0.3, 0.05)), Vector3(0.5, 0.6, 0.55), 1.0)
	base.add_box(wood, Transform3D(Basis(), Vector3(0, 0.05, 0.05)), Vector3(0.8, 0.1, 0.8), 1.0)
	add_child(base.to_instance("Post"))
	_yaw_node = Node3D.new()
	_yaw_node.name = "Yaw"
	add_child(_yaw_node)
	var yoke := MeshBuilder.new()
	yoke.add_box(iron, Transform3D(Basis(), Vector3(0, 0.64, 0.05)), Vector3(0.36, 0.1, 0.36), 1.0)
	for sx in [-0.2, 0.2]:
		yoke.add_box(iron, Transform3D(Basis(), Vector3(sx, 0.78, 0.0)), Vector3(0.06, 0.28, 0.12), 1.0)
	_yaw_node.add_child(yoke.to_instance("Yoke"))
	_pitch_node = Node3D.new()
	_pitch_node.name = "Pitch"
	_pitch_node.position = Vector3(0, PIVOT_Y, 0)
	_yaw_node.add_child(_pitch_node)
	_barrel = Node3D.new()
	_barrel.name = "Barrel"
	_pitch_node.add_child(_barrel)
	var bm := MeshBuilder.new()
	# the tube (along -Z), thick at the breech, a ring at the muzzle
	bm.add_cylinder(iron, Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(0, 0, 0.42)), 0.2, 0.14, BARREL + 0.42, 8, 1.0)
	bm.add_cylinder(iron, Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(0, 0, -BARREL + 0.12)), 0.18, 0.18, 0.14, 8, 1.0)
	bm.add_cylinder(brass, Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(0, 0, 0.1)), 0.215, 0.215, 0.08, 8, 1.0)
	bm.add_box(iron, Transform3D(Basis(), Vector3(0, 0, 0.5)), Vector3(0.12, 0.12, 0.16), 1.0)
	_barrel.add_child(bm.to_instance("Tube"))
	_apply_aim()


func _on_interact(player: Player) -> void:
	if player == null or not player.is_free():
		return
	if Net.active and not Net.request_seat(self):
		return  # the host answers (Player.take_seat)
	player.man_cannon(self)


## Who has this gun (co-op net id; 0 = free).
func holder() -> int:
	return Net.seat_holder(self)


func _process(delta: float) -> void:
	cool = maxf(cool - delta, 0.0)
	if _recoil > 0.0:
		_recoil = maxf(_recoil - delta * 1.6, 0.0)
	_barrel.position.z = _recoil * 0.45
	_apply_aim()
	if interactable:
		var h := holder()
		interactable.enabled = (h == 0 or h == Net.my_id()) and not aiming_locally
	_update_arc()


func _apply_aim() -> void:
	yaw = clampf(yaw, -YAW_LIMIT, YAW_LIMIT)
	pitch = clampf(pitch, PITCH_MIN, PITCH_MAX)
	_yaw_node.rotation.y = yaw
	_pitch_node.rotation.x = pitch
	if _cam_arm:
		# the camera keeps a steadier pitch than the barrel
		_cam_pitch = lerpf(_cam_pitch, pitch * 0.55, 0.3)
		_cam_arm.rotation.x = _cam_pitch


func loaded() -> bool:
	return cool <= 0.0


func reload_frac() -> float:
	return 1.0 - cool / maxf(reload_time, 0.01)


## Where the ball leaves the muzzle, and how fast (world space).
func muzzle() -> Vector3:
	return _pitch_node.global_transform * Vector3(0, 0, -BARREL - 0.05)


func shot_velocity() -> Vector3:
	var dir := -_pitch_node.global_basis.z.normalized()
	var v := dir * MUZZLE_SPEED
	if ship and ship.has_method("hull_velocity"):
		v += ship.hull_velocity()
	return v


## Fire (if loaded). `by` is who pulled the lanyard (a captain or a ship).
func fire(by: Node = null) -> bool:
	if not loaded():
		return false
	cool = reload_time
	var from := muzzle()
	var vel := shot_velocity()
	_shots += 1
	_shoot(from, vel, true, by, _shots)
	Net.event(self, "fire", [from, vel, _shots])
	fired.emit()
	return true


func _shoot(from: Vector3, vel: Vector3, auth: bool, by: Node, n: int) -> void:
	_recoil = 1.0
	var b := Cannonball.launch(get_tree(), from, vel, team, auth, by if by else ship, ship, "%s#%d" % [Net.key_of(self), n])
	b.hull_damage = hull_damage
	b.splash_damage = splash_damage
	var dir := vel.normalized()
	FX.muzzle_sparks(from, dir, 16)
	FX.smoke(from + dir * 0.6, 10, 1.6, 2.2)
	FX.flame(from + dir * 0.3, 8, 0.7, 0.25, 0.25)
	FX.sfx("cannon", from, 2.0, 0.06)
	var me := get_tree().get_first_node_in_group("player") as Node3D
	if me and me.global_position.distance_to(from) < 14.0:
		CombatManager.apply_camera_shake(0.18 if aiming_locally else 0.1)


func net_event(what: String, args: Array) -> void:
	if what == "fire" and args.size() >= 3:
		cool = reload_time
		_shots = int(args[2])
		_shoot(args[0], args[1], false, null, _shots)


## Point the barrel so the ball comes down at `target` (low arc). Returns
## false if it's out of reach (the gun is then pointed as close as it gets).
func aim_at(target: Vector3) -> bool:
	var from := _pitch_node.global_position
	var to := target - from
	var inv := global_basis.orthonormalized().inverse()
	var local := inv * to
	yaw = clampf(atan2(-local.x, -local.z), -YAW_LIMIT, YAW_LIMIT)
	var flat := Vector2(to.x, to.z).length()
	var p = ShipCannon.solve_pitch(flat, to.y, MUZZLE_SPEED, Cannonball.GRAVITY)
	if p == null:
		pitch = PITCH_MAX * 0.7
		_apply_aim()
		return false
	# (the deck's own tilt counts: aim in the gun's frame)
	var ship_tilt := asin(clampf((global_basis * Vector3(0, 0, -1)).normalized().y, -1.0, 1.0))
	pitch = clampf(float(p) - ship_tilt, PITCH_MIN, PITCH_MAX)
	_apply_aim()
	return absf(atan2(-local.x, -local.z)) <= YAW_LIMIT


## Launch angle to cover `dx` metres and rise `dy` (low arc), or null.
static func solve_pitch(dx: float, dy: float, v: float, g: float):
	var v2 := v * v
	var disc := v2 * v2 - g * (g * dx * dx + 2.0 * dy * v2)
	if disc < 0.0 or dx < 0.01:
		return null
	return atan((v2 - sqrt(disc)) / (g * dx))


# --------------------------------------------------------------------------
# The aiming arc (only for whoever mans it here)
# --------------------------------------------------------------------------
func _update_arc() -> void:
	if not aiming_locally:
		if _arc:
			_arc.visible = false
		return
	if _arc == null:
		if _arc_mat == null:
			_arc_mat = StandardMaterial3D.new()
			_arc_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			_arc_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			_arc_mat.vertex_color_use_as_albedo = true
			_arc_mat.no_depth_test = true
			_arc_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		_arc_mesh = ImmediateMesh.new()
		_arc = MeshInstance3D.new()
		_arc.name = "Arc"
		_arc.mesh = _arc_mesh
		_arc.material_override = _arc_mat
		_arc.top_level = true
		_arc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_arc.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		add_child(_arc)
	_arc.visible = true
	_arc.global_transform = Transform3D.IDENTITY
	_arc_mesh.clear_surfaces()
	var p := muzzle()
	var v := shot_velocity()
	var is_loaded := loaded()
	var col := Color(1.0, 0.9, 0.55, 0.75) if is_loaded else Color(0.75, 0.75, 0.75, 0.4)
	var space := get_world_3d().direct_space_state
	var dt := 0.05
	var pts: Array = [p]
	var land := Vector3.INF
	for i in range(120):
		var nv := v + Vector3.DOWN * Cannonball.GRAVITY * dt
		var np := p + (v + nv) * 0.5 * dt
		v = nv
		if np.y < 0.0:
			land = p.lerp(np, clampf(p.y / maxf(p.y - np.y, 0.001), 0.0, 1.0))
			pts.append(land)
			break
		if i % 3 == 0:
			var q := PhysicsRayQueryParameters3D.create(p, np, 1 | 4 | 2048)
			if ship:
				q.exclude = [ship.get_rid()]
			var hit := space.intersect_ray(q)
			if not hit.is_empty():
				land = hit["position"]
				pts.append(land)
				break
		p = np
		pts.append(p)
	_arc_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	# dashes: little cross-shaped ribbons, readable from any angle
	for i in range(0, pts.size() - 1, 2):
		_ribbon(pts[i], pts[i + 1], 0.07, col)
	# a ring where it lands
	if land != Vector3.INF:
		var r := 1.4
		for k in range(16):
			var a0 := TAU * k / 16.0
			var a1 := TAU * (k + 0.6) / 16.0
			_ribbon(land + Vector3(cos(a0) * r, 0.2, sin(a0) * r), land + Vector3(cos(a1) * r, 0.2, sin(a1) * r), 0.09, col)
	_arc_mesh.surface_end()


func _ribbon(a: Vector3, b: Vector3, w: float, col: Color) -> void:
	var d := b - a
	if d.length() < 0.001:
		return
	var s1 := d.cross(Vector3.UP)
	if s1.length() < 0.001:
		s1 = Vector3.RIGHT
	s1 = s1.normalized() * w
	var s2 := d.cross(s1).normalized() * w
	for s in [s1, s2]:
		for v in [a - s, a + s, b + s, a - s, b + s, b - s]:
			_arc_mesh.surface_set_color(col)
			_arc_mesh.surface_add_vertex(v)
