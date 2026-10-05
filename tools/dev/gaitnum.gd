extends SceneTree
## Foot paths in body space for several move directions (armed): swing axis vs travel, crossing.
var f := 0
var h
var dirs := [Vector2(0, 1), Vector2(-1, 1), Vector2(1, 1), Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(-1, -1)]
var di := 0
var samples: Array = []
var tt := 0.0
func _process(d: float) -> bool:
	f += 1
	if f == 1:
		var w := Node3D.new(); get_root().add_child(w)
		h = Humanoid.new(); h.setup(CharacterLook.default_look()); w.add_child(h)
		h.armed = true; h.grounded = true
		return false
	var mv: Vector2 = dirs[di].normalized()
	h.ground_speed = 4.8
	h.local_move = mv
	tt += 1.0 / 60.0
	if tt > 0.6:
		var fl: Vector3 = h.to_local(h.shin_l.global_transform * Vector3(0, -0.4, 0))
		var fr: Vector3 = h.to_local(h.shin_r.global_transform * Vector3(0, -0.4, 0))
		samples.append([fl, fr])
	if tt > 1.8:
		# swing axis: direction of max spread of the left foot (x, -z = right, forward)
		var mean := Vector2.ZERO
		for s in samples: mean += Vector2(s[0].x, -s[0].z)
		mean /= samples.size()
		var cxx := 0.0; var cyy := 0.0; var cxy := 0.0
		var cross := 0
		for s in samples:
			var q := Vector2(s[0].x, -s[0].z) - mean
			cxx += q.x * q.x; cyy += q.y * q.y; cxy += q.x * q.y
			if s[0].x > s[1].x - 0.05: cross += 1
		var ang := 0.5 * atan2(2.0 * cxy, cxx - cyy)
		var axis := Vector2(cos(ang), sin(ang))
		print("move ", mv, " swing axis ", axis, " |dot| ", snappedf(absf(axis.dot(mv)), 0.01), " feet crossed frames ", cross, "/", samples.size(), " min gap ", _mingap())
		samples.clear(); tt = 0.0; di += 1
		if di >= dirs.size(): return true
	return false
func _mingap() -> float:
	var m := 9.0
	for s in samples: m = minf(m, s[1].x - s[0].x)
	return snappedf(m, 0.01)
