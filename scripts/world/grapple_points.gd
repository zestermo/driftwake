class_name GrapplePoints
extends RefCounted
## Spots a Vine Swing can latch onto that a ray can't find on its own: tree
## crowns (the canopies have no collision, only the trunks do). Islands add
## a point per tree as they plant them; points are stored relative to their
## island so they follow it, and vanish with it.

static var _points: Array = []   # [holder Node3D, local Vector3]
## (1.30) Ledges the grappling-hook gadget bites from far off (GadgetState.hook_point): a fortress wall's walk, a
## tower's top, a rooftop. Kept apart from the swing's crowns (a vine doesn't swing from a wall top).
static var _ledges: Array = []
static var _ring_mesh: ArrayMesh


static func clear() -> void:
	_points.clear()
	_ledges.clear()


static func add(holder: Node3D, local: Vector3) -> void:
	_points.append([holder, local])


## (1.30) A ledge the hook can reach, `local` in `holder`'s space (on the top surface, at its lip); `mark` bolts a
## small iron ring there so it reads from below.
static func add_ledge(holder: Node3D, local: Vector3, mark := true) -> void:
	_ledges.append([holder, local])
	if mark:
		var mi := MeshInstance3D.new()
		mi.name = "HookRing"
		mi.mesh = ring_mesh()
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visibility_range_end = 60.0
		mi.position = local
		holder.add_child(mi)


static func ledge_count() -> int:
	return _ledges.size()


static func best_ledge(from: Vector3, dir: Vector3, origin: Vector3, max_dist: float, max_angle: float, min_y: float) -> Vector3:
	return _best(_ledges, from, dir, origin, max_dist, max_angle, min_y)


## An iron ring on a bolt plate: a hook point's mark.
static func ring_mesh() -> ArrayMesh:
	if _ring_mesh == null:
		var mb := MeshBuilder.new()
		var iron := PSXMat.lit("metal", Color(0.32, 0.3, 0.3))
		mb.add_box(iron, Transform3D(Basis(), Vector3(0, 0.02, 0)), Vector3(0.22, 0.04, 0.16), 4.0)
		mb.add_tube(iron, MeshBuilder.curve_points(Vector3(-0.08, 0.04, 0), Vector3(0, 0.2, 0), Vector3(0.08, 0.04, 0), 6), 0.025, 0.025, 4)
		_ring_mesh = mb.commit()
	return _ring_mesh


static func count() -> int:
	return _points.size()


## A tree mesh's crown, in the mesh's own space (a little under the top of
## its bounds, at the middle of the canopy).
static func crown_of(mesh: Mesh) -> Vector3:
	var bb := mesh.get_aabb()
	var c := bb.get_center()
	return Vector3(c.x, bb.end.y - minf(1.2, bb.size.y * 0.15), c.z)


## The point nearest the aim ray (from + dir * t): no more than `max_angle`
## (radians) off it, within `max_dist` of `origin` (and not too close), and
## higher than `min_y`. Vector3.INF when there's none.
static func best(from: Vector3, dir: Vector3, origin: Vector3, max_dist: float, max_angle: float, min_y: float) -> Vector3:
	return _best(_points, from, dir, origin, max_dist, max_angle, min_y)


static func _best(list: Array, from: Vector3, dir: Vector3, origin: Vector3, max_dist: float, max_angle: float, min_y: float) -> Vector3:
	var best_p := Vector3.INF
	var best_score := INF
	var i := list.size() - 1
	while i >= 0:
		var e: Array = list[i]
		i -= 1
		var h = e[0]
		if not is_instance_valid(h):
			list.remove_at(i + 1)
			continue
		var p: Vector3 = (h as Node3D).to_global(e[1])
		if p.y < min_y:
			continue
		var d := p.distance_to(origin)
		if d > max_dist or d < 2.5:
			continue
		var to := p - from
		if to.length() < 0.01:
			continue
		var ang := acos(clampf(to.normalized().dot(dir), -1.0, 1.0))
		if ang > max_angle:
			continue
		var score := ang * 12.0 + d * 0.04
		if score < best_score:
			best_score = score
			best_p = p
	return best_p
