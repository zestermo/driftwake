class_name Ragdoll
extends Node3D
## Physics ragdoll for the game's plain-Node3D rigs (Humanoid, Scuttlebug).
##
## Each part is a RigidBody3D created at its rig joint's current transform and
## joined to its parent part by a Generic6DOFJoint3D with angular limits.
## Every frame the bodies drive the rig joints' global transforms, so the
## character's own meshes flop around; nothing is duplicated.
##
## Joint limits are given in the rig's own terms (the joint's local euler
## rotation, e.g. a knee bends between -2.5 and 0) and converted to limits
## relative to the pose the ragdoll starts from, so a body knocked down mid
## swing still can't bend its knees backwards.
##
## Parts sit on their own physics layer and only collide with the world.
##
## Muscles: a living body isn't a sack. With `stiffness` > 0 every joint is
## pulled toward a target pose (set_targets, in the same local-euler terms as
## the limits) by a damped spring torque applied between the part and its
## parent, so the body still tumbles and falls freely but braces: arms out,
## knees up. Stiffness 0 (the default, and on death) is a plain limp ragdoll.

const LAYER := 1024
## Sign of a joint's relative rotation vs. the rig's local euler change
## (Jolt measures the second body against the first in the joint frame).
const LIMIT_SIGN := -1.0

## Water: bodies under the surface get buoyancy (a little more than their
## weight, so a body plunges in, slows, then bobs back up and floats) and
## heavy water drag.
const BUOYANCY := 1.3
## Per body: a Devil Fruit user doesn't float (set ~0.2: they sink).
var buoyancy: float = BUOYANCY
const WATER_DRAG := 2.6
const WATER_ANG_DRAG := 2.2

var parts: Array = []          # [{name, body, node, offset}] parent-first
var in_water: bool = false     # the root part is below the surface
var _splashed: bool = false
var _ocean: Node
var _by_name: Dictionary = {}
var _scale: float = 1.0
## 0 = limp, 1 = fully braced. Eased toward stiffness_target.
var stiffness: float = 0.0
var stiffness_target: float = 0.0
## Muscle spring (1/s^2) and damping (1/s) at full stiffness.
var muscle_k: float = 220.0
var muscle_c: float = 20.0
var _targets: Dictionary = {}   # part name -> local euler target
var _wiggle: Dictionary = {}    # part name -> euler amplitude of a slow flail
var _t: float = 0.0


## Ragdolls live in the scene root so they don't move with the character.
static func create(tree: SceneTree) -> Ragdoll:
	var r := Ragdoll.new()
	r.name = "Ragdoll"
	var root: Node = tree.current_scene if tree.current_scene else tree.root
	root.add_child(r)
	r.global_transform = Transform3D.IDENTITY
	return r


## Add a body that drives `node`. `shape` = {"capsule": [a, b, r]},
## {"box": [center, size]} or {"sphere": [center, r]}, in the node's local
## (unscaled) units. `limits` = {"x": [lo, hi], "y": [..], "z": [..]} on the
## node's local rotation; missing axes are locked.
func add_part(part_name: String, node: Node3D, shape: Dictionary, mass: float,
		parent_name: String = "", limits: Dictionary = {}) -> RigidBody3D:
	var g := node.global_transform
	var s := g.basis.get_scale().x
	_scale = s
	var b := RigidBody3D.new()
	b.name = part_name
	b.collision_layer = LAYER
	b.collision_mask = 1
	b.mass = mass
	b.linear_damp = 0.05
	b.angular_damp = 0.8
	b.can_sleep = true
	var pm := PhysicsMaterial.new()
	pm.friction = 0.9
	pm.bounce = 0.05
	b.physics_material_override = pm
	var cs := CollisionShape3D.new()
	if shape.has("capsule"):
		var a: Vector3 = shape["capsule"][0] * s
		var e: Vector3 = shape["capsule"][1] * s
		var r: float = float(shape["capsule"][2]) * s
		var cap := CapsuleShape3D.new()
		cap.radius = r
		cap.height = maxf(a.distance_to(e) + r * 2.0, r * 2.0 + 0.01)
		cs.shape = cap
		var dir := (e - a)
		var basis := Basis.IDENTITY
		if dir.length() > 0.001:
			var up := dir.normalized()
			var side := up.cross(Vector3.FORWARD if absf(up.z) < 0.9 else Vector3.RIGHT).normalized()
			basis = Basis(side, up, side.cross(up)).orthonormalized()
		cs.transform = Transform3D(basis, (a + e) * 0.5)
	elif shape.has("box"):
		var box := BoxShape3D.new()
		box.size = shape["box"][1] * s
		cs.shape = box
		cs.position = shape["box"][0] * s
	else:
		var sp := SphereShape3D.new()
		sp.radius = float(shape["sphere"][1]) * s
		cs.shape = sp
		cs.position = shape["sphere"][0] * s
	b.add_child(cs)
	add_child(b)
	b.global_transform = Transform3D(g.basis.orthonormalized(), g.origin)
	b.reset_physics_interpolation()
	var part := {"name": part_name, "body": b, "node": node, "offset": b.global_transform.affine_inverse() * g,
		"parent": parent_name, "cur": node.rotation, "rel0": Basis.IDENTITY}
	if parent_name != "" and _by_name.has(parent_name):
		var pb: RigidBody3D = _by_name[parent_name]["body"]
		part["rel0"] = pb.global_basis.orthonormalized().inverse() * b.global_basis.orthonormalized()
	parts.append(part)
	_by_name[part_name] = part
	if parent_name != "" and _by_name.has(parent_name):
		_join(_by_name[parent_name]["body"], b, node, limits)
	return b


func _join(parent: RigidBody3D, child: RigidBody3D, node: Node3D, limits: Dictionary) -> void:
	var j := Generic6DOFJoint3D.new()
	add_child(j)
	j.global_transform = Transform3D(child.global_basis, child.global_position)
	var cur := node.rotation
	for ax in ["x", "y", "z"]:
		var lim: Array = limits.get(ax, [0.0, 0.0])
		var c: float = cur[ax]
		var lo := (float(lim[0]) - c) * LIMIT_SIGN
		var hi := (float(lim[1]) - c) * LIMIT_SIGN
		if lo > hi:
			var t := lo
			lo = hi
			hi = t
		# never start outside the range (a pose can exceed the limits slightly)
		lo = minf(lo, 0.0)
		hi = maxf(hi, 0.0)
		match ax:
			"x":
				j.set_flag_x(Generic6DOFJoint3D.FLAG_ENABLE_ANGULAR_LIMIT, true)
				j.set_param_x(Generic6DOFJoint3D.PARAM_ANGULAR_LOWER_LIMIT, lo)
				j.set_param_x(Generic6DOFJoint3D.PARAM_ANGULAR_UPPER_LIMIT, hi)
			"y":
				j.set_flag_y(Generic6DOFJoint3D.FLAG_ENABLE_ANGULAR_LIMIT, true)
				j.set_param_y(Generic6DOFJoint3D.PARAM_ANGULAR_LOWER_LIMIT, lo)
				j.set_param_y(Generic6DOFJoint3D.PARAM_ANGULAR_UPPER_LIMIT, hi)
			"z":
				j.set_flag_z(Generic6DOFJoint3D.FLAG_ENABLE_ANGULAR_LIMIT, true)
				j.set_param_z(Generic6DOFJoint3D.PARAM_ANGULAR_LOWER_LIMIT, lo)
				j.set_param_z(Generic6DOFJoint3D.PARAM_ANGULAR_UPPER_LIMIT, hi)
	j.exclude_nodes_from_collision = true
	j.node_a = j.get_path_to(parent)
	j.node_b = j.get_path_to(child)


## Target pose for the muscles: {part name: local euler (rig terms)}, plus an
## optional slow wiggle amplitude per part.
func set_targets(targets: Dictionary, wiggle: Dictionary = {}) -> void:
	_targets = targets
	_wiggle = wiggle


## Go limp (death).
func relax() -> void:
	stiffness = 0.0
	stiffness_target = 0.0


func _muscles(delta: float) -> void:
	_t += delta
	stiffness = move_toward(stiffness, stiffness_target, delta * 1.5)
	if stiffness <= 0.001 or _targets.is_empty():
		return
	var k := muscle_k * stiffness
	var c := muscle_c * sqrt(stiffness)
	for i in range(parts.size()):
		var part: Dictionary = parts[i]
		var pn: String = part["parent"]
		if pn == "" or not _targets.has(part["name"]) or not _by_name.has(pn):
			continue
		var b: RigidBody3D = part["body"]
		var pb: RigidBody3D = _by_name[pn]["body"]
		if b.freeze or pb.freeze:
			continue
		var tgt: Vector3 = _targets[part["name"]]
		if _wiggle.has(part["name"]):
			# flail in the air, then calm down so the body can come to rest
			var w: Vector3 = _wiggle[part["name"]] * clampf(1.0 - (_t - 1.0) / 0.8, 0.0, 1.0)
			var ph := float(i) * 1.7
			tgt += Vector3(w.x * sin(_t * 4.3 + ph), w.y * sin(_t * 3.1 + ph * 0.6), w.z * sin(_t * 3.7 + ph * 1.3))
		var cur0: Vector3 = part["cur"]
		# desired relative rotation: the creation offset re-posed from cur0 to tgt
		var want_rel: Basis = (part["rel0"] as Basis) * Basis.from_euler(cur0).inverse() * Basis.from_euler(tgt)
		var pbas := pb.global_basis.orthonormalized()
		var want := (pbas * want_rel).orthonormalized()
		var err_q := Quaternion(want) * Quaternion(b.global_basis.orthonormalized()).inverse()
		err_q = err_q.normalized()
		if err_q.w < 0.0:
			err_q = -err_q
		var ang := err_q.get_angle()
		var axis := err_q.get_axis() if ang > 0.0001 else Vector3.ZERO
		var rel_w := b.angular_velocity - pb.angular_velocity
		var acc := axis * ang * k - rel_w * c
		# scale by the part's inertia so light limbs and heavy chests move alike
		var inv := b.get_inverse_inertia_tensor()
		var inertia := inv.inverse() if absf(inv.determinant()) > 1e-9 else Basis.IDENTITY * b.mass * 0.02
		var torque := inertia * acc
		b.apply_torque(torque)
		pb.apply_torque(-torque)


func body(part_name: String) -> RigidBody3D:
	return _by_name[part_name]["body"] if _by_name.has(part_name) else null


## Give every part a starting velocity (the hit), with optional per-part
## multipliers so e.g. the upper body is flung harder than the legs.
func launch(velocity: Vector3, spin: Vector3 = Vector3.ZERO, mult: Dictionary = {}) -> void:
	for p in parts:
		var b: RigidBody3D = p["body"]
		var m: float = float(mult.get(p["name"], 1.0))
		b.linear_velocity = velocity * m
		b.angular_velocity = spin


## Push the whole ragdoll (another hit while it's down).
func push(velocity: Vector3) -> void:
	for p in parts:
		var b: RigidBody3D = p["body"]
		b.sleeping = false
		b.linear_velocity += velocity


## Average speed of the main part (first one added).
func root_speed() -> float:
	if parts.is_empty():
		return 0.0
	var b: RigidBody3D = parts[0]["body"]
	return b.linear_velocity.length()


func root_spin() -> float:
	if parts.is_empty():
		return 0.0
	var b: RigidBody3D = parts[0]["body"]
	return b.angular_velocity.length()


func root_body() -> RigidBody3D:
	return parts[0]["body"] if not parts.is_empty() else null


## Is everything (nearly) at rest?
func settled(lin: float = 0.35, ang: float = 1.2) -> bool:
	for p in parts:
		var b: RigidBody3D = p["body"]
		if b.linear_velocity.length() > lin or b.angular_velocity.length() > ang * 2.0:
			return false
	return root_spin() < ang


func _process(_delta: float) -> void:
	drive()


func _physics_process(delta: float) -> void:
	_muscles(delta)
	if _ocean == null:
		_ocean = get_node_or_null("/root/Ocean")
		if _ocean == null:
			return
	var g := float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
	var root_wet := false
	for i in range(parts.size()):
		var b: RigidBody3D = parts[i]["body"]
		if b.freeze:
			continue
		var p := b.global_position
		var depth := float(_ocean.call("get_wave_height", p)) - p.y
		if depth <= -0.15:
			continue
		if i == 0:
			root_wet = depth > 0.1
		# buoyancy ramps in over the last 15 cm so bodies settle at the surface
		var sub := clampf((depth + 0.15) / 0.4, 0.0, 1.0)
		b.sleeping = false
		b.apply_central_force(Vector3.UP * b.mass * g * buoyancy * sub)
		var k := clampf(WATER_DRAG * sub * delta, 0.0, 0.9)
		b.linear_velocity *= 1.0 - k
		b.angular_velocity *= 1.0 - clampf(WATER_ANG_DRAG * sub * delta, 0.0, 0.9)
	if root_wet and not in_water and not _splashed:
		_splashed = true
		var rb: RigidBody3D = parts[0]["body"]
		var at := Vector3(rb.global_position.x, float(_ocean.call("get_wave_height", rb.global_position)), rb.global_position.z)
		var fx := get_node_or_null("/root/FX")
		if fx:
			fx.call("splash", at, 12, 1.0)
			fx.call("sfx", "splash", at, -2.0, 0.08, 0.85)
	in_water = root_wet


## Is the main part in (or right at) the water?
func root_depth() -> float:
	if parts.is_empty():
		return -INF
	if _ocean == null:
		_ocean = get_node_or_null("/root/Ocean")
	if _ocean == null:
		return -INF
	var p: Vector3 = (parts[0]["body"] as RigidBody3D).global_position
	return float(_ocean.call("get_wave_height", p)) - p.y


## Pose the rig from the bodies (parents first, so children land correctly).
func drive() -> void:
	for p in parts:
		var node: Node3D = p["node"]
		if not is_instance_valid(node):
			continue
		var b: RigidBody3D = p["body"]
		var xf := b.get_global_transform_interpolated() if b.is_inside_tree() else b.global_transform
		node.global_transform = xf * (p["offset"] as Transform3D)
