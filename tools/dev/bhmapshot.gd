extends SceneTree
## Brinehollow as a map (headless): a fresh StarterIsland built 9 km off, painted top down at `px` m a
## pixel: the sea by depth, the land by height (contours every 2 m), the paths, every reserve's edge,
## the places (white dots), where the grown land changed the old island's ground (purple) and a 50 m grid (lines through the island's centre brighter). For laying
## out districts. Args: <out.png> [px] [x0,z0,x1,z1 island-space window]
var t := 0.0


func _initialize():
	change_scene_to_file("res://scenes/world/world.tscn")


func _process(d: float) -> bool:
	t += d
	var w = root.get_node_or_null("World/Islands")
	if w == null or t < 1.5:
		return false
	var a := OS.get_cmdline_user_args()
	var px := float(a[1]) if a.size() > 1 else 1.5
	var isl = load("res://scripts/island/starter_island.gd").new()
	isl.name = "MapIsle"
	isl.position = Vector3(0.0, 0.0, 9000.0)
	w.add_child(isl)
	isl.build(int(w.world_seed))
	var r: Rect2 = isl.grid_rect() if isl.has_method("grid_rect") else Rect2(-315, -315, 630, 630)
	if a.size() > 2:
		var v := a[2].split(",")
		r = Rect2(float(v[0]), float(v[1]), float(v[2]) - float(v[0]), float(v[3]) - float(v[1]))
	var nx := int(r.size.x / px)
	var nz := int(r.size.y / px)
	var img := Image.create(nx, nz, false, Image.FORMAT_RGB8)
	for iz in range(nz):
		for ix in range(nx):
			var p := r.position + Vector2(ix + 0.5, iz + 0.5) * px
			var h: float = isl.hv(p)
			var c: Color
			if h < 0.0:
				c = Color(0.1, 0.25, 0.5).lerp(Color(0.35, 0.65, 0.8), clampf(1.0 + h / 8.0, 0.0, 1.0))
			else:
				c = Color(0.85, 0.8, 0.55) if h < 1.6 else Color(0.3, 0.55, 0.25).lerp(Color(0.6, 0.45, 0.3), clampf(h / 30.0, 0.0, 1.0))
				if fposmod(h, 2.0) < 0.12 * px:
					c = c.darkened(0.25)
				if isl.path_dist(p) < 0.0:
					c = Color(0.75, 0.6, 0.4)
			if isl.has_method("_grown_at") and isl._grown_at(p):
				c = c.lerp(Color(0.8, 0.2, 0.9), 0.25)
			if absf(fposmod(p.x, 50.0)) < px or absf(fposmod(p.y, 50.0)) < px:
				c = c.lerp(Color.WHITE, 0.45 if absf(p.x) < px or absf(p.y) < px else 0.15)
			img.set_pixel(ix, iz, c)
	for e in isl.exclusions:
		var c: Vector2 = e[0]
		var rr := float(e[1])
		var n := maxi(int(TAU * rr / px), 8)
		for k in range(n):
			var q: Vector2 = (c + Vector2.from_angle(TAU * k / n) * rr - r.position) / px
			if q.x >= 0 and q.y >= 0 and q.x < nx and q.y < nz:
				img.set_pixel(int(q.x), int(q.y), Color(0.9, 0.2, 0.2) if rr < 6.0 else Color(1.0, 0.5, 0.1))
	var places: Array = isl.map_places() if isl.has_method("map_places") else [isl.VILLAGE, isl.TRAINING, isl.HILL, isl.RUINS, isl.COVE, isl.CAMP, isl.SMUGGLERS, isl.FOREST, isl.CAVE, isl.DEN, isl.MARKET]
	for p in places:
		var q: Vector2 = (p - r.position) / px
		for dz in range(-2, 3):
			for dx in range(-2, 3):
				if q.x + dx >= 0 and q.y + dz >= 0 and q.x + dx < nx and q.y + dz < nz:
					img.set_pixel(int(q.x) + dx, int(q.y) + dz, Color.WHITE)
	img.save_png(a[0])
	print("MAP %dx%d %s -> %s" % [nx, nz, str(r), a[0]])
	quit()
	return true
