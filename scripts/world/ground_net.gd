class_name GroundNet
extends RefCounted
## The safety net under the islands (1.23, Zach: "falling through the ground and into the water level underneath the
## terrain"). The ground's collider is a thin triangle mesh, and a fast body (a dash, a launch, a ragdoll, a big
## knockback) can slip through it into the sea that runs on under every island. A captain found swimming where the
## island's ground stands well above them is put back on top (the local captain checks itself every few ticks).

## Checked once every this many physics ticks.
const EVERY := 8
## The ground must stand this far over the swimmer's head (and over the sea) to count as "under the island".
const UNDER := 1.0
const LAND := 0.8


## Tests: the ground's height at a point, in place of the islands' (Callable(at: Vector3) -> float).
static var height_override := Callable()


## The island ground's height under world point `at` (the nearest island's terrain), or NAN if none is about.
static func land_height(tree: SceneTree, at: Vector3) -> float:
	if height_override.is_valid():
		return float(height_override.call(at))
	var w := tree.get_first_node_in_group("world_gen")
	if w == null:
		return NAN
	var best = null
	var best_d := INF
	var list: Array = []
	if "starter_island" in w and w.starter_island and is_instance_valid(w.starter_island):
		list.append(w.starter_island)
	if "chain_islands" in w:
		list.append_array((w.chain_islands as Dictionary).values())
	for isl in list:
		if isl == null or not is_instance_valid(isl) or not (isl as Node).is_inside_tree() or not isl.has_method("height_at"):
			continue
		var d := Vector2(at.x - (isl as Node3D).global_position.x, at.z - (isl as Node3D).global_position.z).length()
		if d < best_d:
			best_d = d
			best = isl
	if best == null:
		return NAN
	var lp: Vector3 = (best as Node3D).to_local(at)
	return float(best.height_at(lp.x, lp.z)) + (best as Node3D).global_position.y


## Put `p` back on the ground if it's swimming under an island. True if it was moved.
static func rescue(p: Node3D) -> bool:
	if not p.has_method("is_swimming") or not p.is_swimming():
		return false
	var h := land_height(p.get_tree(), p.global_position)
	if is_nan(h) or h < LAND or h < p.global_position.y + UNDER:
		return false
	p.global_position = Vector3(p.global_position.x, h + 0.4, p.global_position.z)
	if p is CharacterBody3D:
		(p as CharacterBody3D).velocity = Vector3.ZERO
	p.reset_physics_interpolation()
	return true
