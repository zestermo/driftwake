class_name BeastShapes
extends RefCounted
## Where a beast's blow lands (JungleBeast.strike): is a captain's feet at `at` in it?
##   ring [centre, r]                 flat round area (jumped when the feet are `jump` m up)
##   ball [centre, r]                 a sphere (in the air: nothing to jump)
##   cone [from, dir, reach, half deg] a sweep in front
##   lane [from, to, half width]      a strip (lunges, charges, dives)


static func inside(shape: String, a: Array, at: Vector3, jump: float) -> bool:
	match shape:
		"ring":
			var c: Vector3 = a[0]
			return _flat(at - c).length() <= float(a[1]) and at.y <= c.y + jump
		"ball":
			return (at + Vector3(0, 0.9, 0)).distance_to(a[0]) <= float(a[1])
		"cone":
			var c: Vector3 = a[0]
			var d := _flat(at - c)
			if d.length() > float(a[2]) or at.y > c.y + jump:
				return false
			if d.length() < 1.2:
				return true
			return rad_to_deg(d.normalized().angle_to(_flat(a[1]).normalized())) <= float(a[3])
		"lane":
			var f: Vector3 = a[0]
			var t: Vector3 = a[1]
			var q := Geometry3D.get_closest_point_to_segment(_flat(at), _flat(f), _flat(t))
			var ground := lerpf(f.y, t.y, clampf(_flat(q - f).length() / maxf(_flat(t - f).length(), 0.01), 0.0, 1.0))
			return _flat(at).distance_to(q) <= float(a[2]) and at.y <= ground + jump
	push_error("BeastShapes: no shape %s" % shape)
	return false


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)
