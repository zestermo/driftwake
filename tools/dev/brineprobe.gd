extends SceneTree
## Brinehollow's ground at given island points: height, slope, distance to the nearest path's edge, whether
## it's reserved, and the nearest named nodes (for laying out a new piece). Headless is fine.
## Args: "x,z" ... ; "grid:x0,z0,x1,z1,step" prints a table of height/slope/path/reserved; "near:x,z,r" lists the
## top-level nodes within r.
var t := 0.0


func _initialize():
	change_scene_to_file("res://scenes/world/world.tscn")


func _process(d: float) -> bool:
	t += d
	var isl = root.get_node_or_null("World/Islands/Brinehollow")
	if isl == null or t < 1.5:
		return false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("grid:"):
			var g := a.substr(5).split(",")
			var z := float(g[1])
			while z <= float(g[3]):
				var row := "z%6.1f " % z
				var x := float(g[0])
				while x <= float(g[2]):
					var p := Vector2(x, z)
					row += "%5.1f%s%s " % [isl.hv(p), "/" if isl._slope_at(p) > 0.3 else " ", "P" if isl._path_dist(p, isl.paths.size(), 0, true) < 1.0 else ("x" if isl.excluded(p, 0.0) else ".")]
					x += float(g[4])
				print(row)
				z += float(g[4])
		elif a.begins_with("near:"):
			var g := a.substr(5).split(",")
			var c := Vector3(float(g[0]), 0, float(g[1]))
			for n in isl.get_children():
				if n is Node3D:
					var l: Vector3 = n.position
					if Vector2(l.x - c.x, l.z - c.z).length() < float(g[2]):
						print("%s %s (%.1f, %.1f, %.1f)" % [n.name, n.get_class(), l.x, l.y, l.z])
		else:
			var g := a.split(",")
			var p := Vector2(float(g[0]), float(g[1]))
			print("(%s) h %.2f slope %.2f path %.1f reserved %s" % [a, isl.hv(p), isl._slope_at(p), isl._path_dist(p, isl.paths.size(), 0, true), isl.excluded(p, 0.0)])
	quit()
	return false
