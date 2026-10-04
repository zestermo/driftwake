class_name GrapplePoints
extends RefCounted
## Spots a Vine Swing can latch onto that a ray can't find on its own: tree
## crowns (the canopies have no collision, only the trunks do). Islands add
## a point per tree as they plant them; points are stored relative to their
## island so they follow it, and vanish with it.

static var _points: Array = []   # [holder Node3D, local Vector3]


static func clear() -> void:
	_points.clear()


static func add(holder: Node3D, local: Vector3) -> void:
	_points.append([holder, local])


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
	var best_p := Vector3.INF
	var best_score := INF
	var i := _points.size() - 1
	while i >= 0:
		var e: Array = _points[i]
		i -= 1
		var h = e[0]
		if not is_instance_valid(h):
			_points.remove_at(i + 1)
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
