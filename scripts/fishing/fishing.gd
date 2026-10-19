class_name Fishing
extends RefCounted
## Fishing (v1.18): where a line can go in.

## How far ahead a cast can land (m) and how deep the water must be there.
const REACH_MIN := 2.5
const REACH_MAX := 9.0
const DEEP := 0.4


## The nearest spot of water ahead of `p` a line can reach (Vector3.INF: none), on the calm sea level.
static func water_ahead(p, reach := REACH_MAX) -> Vector3:
	var fwd: Vector3 = -p.player_model.global_basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var ocean: Node = p.get_node("/root/Ocean")
	var d := REACH_MIN
	while d <= reach:
		var at: Vector3 = p.global_position + fwd * d
		if ocean.depth_at(at, [], true) > DEEP:
			return Vector3(at.x, 0.0, at.z)
		d += 1.0
	return Vector3.INF
