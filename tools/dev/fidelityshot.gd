extends SceneTree
## Matched-camera renders (docs/island_fidelity_plan.md, phase 0): the same shot
## recipes, found by role rather than by coordinates (fidelity.gd's anchors and what
## it finds on the island), on Brinehollow and on a generated chain island: the
## harbour approach from the sea, on the pier at eye height, the village plaza, a
## street between houses, the market, the tallest landmark, the pirates' camp, the
## settled core from overhead (both at the same scale), the village at night (21:00).
## Clear weather, 11:00, no ship, player or HUD. Saves each frame
## (<out>_<recipe>_b.png Brinehollow, _g the generated one) and <out>_sheet.png:
## Brinehollow left, the generated island right, a row per recipe. Prints where each
## recipe found its shot. Args: <out_prefix> [chain seed | -] [node id | -] [psx]
const F := preload("res://tools/dev/fidelity.gd")
const ORDER := ["approach", "pier", "plaza", "street", "market", "landmark", "camp", "overhead", "night"]
const LANDMARK_KINDS := ["lighthouse", "lookout tower", "harbour tower", "chapel", "ruins", "standing stone"]

var t := 0.0
var out := ""
var want := -1
var cam: Camera3D
var caption: Label
var isles: Array = []
var labels: Array = []
var shots: Array = []
var idx := 0
var settle := 0
var frames := {}
var started := false


func _initialize():
	var a := OS.get_cmdline_user_args()
	out = a[0]
	if a.size() > 1 and a[1] != "-":
		root.get_node("GameManager").chain_seed = int(a[1])
	if a.size() > 2 and a[2] != "-":
		want = int(a[2])
	change_scene_to_file("res://scenes/world/world.tscn")


func _process(d: float) -> bool:
	t += d
	var w = root.get_node_or_null("World/Islands")
	if w == null or t < 1.5:
		return false
	var gm = root.get_node("GameManager")
	if not started:
		started = true
		if want < 0:
			want = int(w.chain().start_next[0])
		if gm.chain_at != want:
			gm.apply_chain(want, false, root.get_node("Weather").world_time())
		root.get_node("Weather").force(0)
		_set_hour(11.0)
		gm.chain_since = root.get_node("Weather").world_time()
		if OS.get_cmdline_user_args().has("psx"):
			root.get_node("Settings").set_value("video", "pixelate", true, false)
		return false
	if isles.is_empty():
		if not w.chain_ready() or not w.chain_islands.has(want):
			return false
		_setup(w)
		return false
	settle += 1
	if settle < 8:
		return false
	var s: Array = shots[idx]
	var img := root.get_texture().get_image()
	img.save_png("%s_%s_%s.png" % [out, s[1], "b" if s[0] == 0 else "g"])
	frames["%s_%d" % [s[1], s[0]]] = img
	idx += 1
	settle = 0
	if idx >= shots.size():
		_sheet()
		print("SAVED")
		quit()
		return false
	if shots[idx][1] == "night" and shots[idx - 1][1] != "night":
		_set_hour(21.0)
		settle = -90  # (lamps check the hour once a second)
	_aim()
	return false


func _set_hour(h: float) -> void:
	var wx = root.get_node("Weather")
	wx.set_world_time(wx.time_at(h, 2))


func _setup(w) -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	for n in root.find_children("*", "CharacterCreator", true, false):
		n._finish(true)
	var hud = get_first_node_in_group("hud")
	if hud:
		hud.visible = false
	root.get_node("Settings").set_value("video", "perf_overlay", false, false)
	for g in ["player", "ship"]:
		var n = get_first_node_in_group(g)
		if n:
			n.visible = false
	var b = w.get_node("Brinehollow")
	var g = w.chain_islands[want]
	isles = [b, g]
	labels = ["Brinehollow", "%s (seed %d, node %d)" % [g.island_name, int(root.get_node("GameManager").chain_seed), want]]
	var recipes: Array = []
	var cores: Array = []
	for isl in isles:
		var r := F.measure(isl)
		recipes.append(_recipes(isl, r))
		cores.append(_core(r))
	# the overheads at one scale, the bigger core's
	var size := maxf(float(cores[0][1]), float(cores[1][1])) * 1.15
	for i in range(2):
		var c: Vector2 = cores[i][0]
		var top := 0.0
		for q in [c, c + Vector2(size, 0) * 0.5, c - Vector2(size, 0) * 0.5, c + Vector2(0, size) * 0.5, c - Vector2(0, size) * 0.5]:
			top = maxf(top, isles[i].hv(q))
		recipes[i]["overhead"] = ["the settled core from overhead (%d m across)" % int(size), Vector3(c.x, top + 80.0, c.y), Vector3(c.x, 0.0, c.y - 0.001), size]
	for nm in ORDER:
		for i in range(2):
			shots.append([i, nm] + recipes[i][nm])
			print("%s %s: %s  cam %s -> %s" % [labels[i], nm, recipes[i][nm][0], recipes[i][nm][1], recipes[i][nm][2]])
	cam = Camera3D.new()
	cam.fov = 60
	cam.far = 3000
	root.add_child(cam)
	cam.current = true
	var cl := CanvasLayer.new()
	cl.layer = 100
	root.add_child(cl)
	caption = Label.new()
	caption.position = Vector2(12, 8)
	caption.add_theme_font_size_override("font_size", 22)
	caption.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	caption.add_theme_constant_override("outline_size", 6)
	cl.add_child(caption)
	_aim()


## recipe -> [caption, camera, target (island space), ortho size or 0].
func _recipes(isl, r: Dictionary) -> Dictionary:
	var a: Dictionary = r["d"]["anchors"]
	var dock: Vector2 = a["dock"]
	var dd: Vector2 = a["dock_dir"]
	var side := Vector2(-dd.y, dd.x)
	var v: Vector2 = a["village"]
	var to_dock := (dock - v).normalized()
	var vs := Vector2(-to_dock.y, to_dock.x)
	var out_r := {}
	out_r["approach"] = ["the harbour approach from the sea", _g(isl, a["dock_end"] + dd * 110.0 + side * 35.0, 12.0), _g(isl, dock - dd * 25.0, 4.0), 0.0]
	var pe: Vector2 = a["dock_end"] - dd * 3.0
	out_r["pier"] = ["on the pier at eye height", Vector3(pe.x, float(a["deck_y"]) + 1.7, pe.y), _g(isl, dock - dd * 30.0, 2.0), 0.0]
	out_r["plaza"] = ["the village plaza", _g(isl, v + to_dock * 13.0 + vs * 3.0, 1.7), _g(isl, v - to_dock * 8.0, 1.5), 0.0]
	# a street: the stretch of path with the most buildings close on both sides
	var best = null
	var best_score := -1.0
	for s in r["d"]["streets"]:
		var p: Vector2 = s[0]
		if p.distance_to(v) > 90.0 and p.distance_to(dock) > 90.0:
			continue
		var l := 0
		var rr := 0
		for b in r["d"]["buildings"]:
			var rel: Vector2 = (b["p"] as Vector2) - p
			if rel.length() - float(b["r"]) > 12.0:
				continue
			if (s[2] as Vector2).cross(rel) > 0.0:
				l += 1
			else:
				rr += 1
		var score := minf(l, rr) * 10.0 + l + rr
		if score > best_score:
			best_score = score
			best = s
	if best:
		var p: Vector2 = best[0]
		var dir: Vector2 = best[2]
		if dir.dot(v - p) < 0.0 and p.distance_to(v) > 12.0:
			dir = -dir
		out_r["street"] = ["a street (%d buildings within 12 m)" % int(best_score) if best_score < 10.0 else "a street between houses", _g(isl, p - dir * 2.0, 1.7), _g(isl, p + dir * 20.0, 1.5), 0.0]
	else:
		out_r["street"] = ["(no street)", out_r["plaza"][1], out_r["plaza"][2], 0.0]
	# the market: the stalls round the one nearest the village
	var stalls: Array = r["d"]["buildings"].filter(func(b): return b["kind"] == "stall")
	if stalls.is_empty():
		out_r["market"] = ["(no market)", out_r["plaza"][1], out_r["plaza"][2], 0.0]
	else:
		stalls.sort_custom(func(x, y): return (x["p"] as Vector2).distance_to(v) < (y["p"] as Vector2).distance_to(v))
		var mc := Vector2.ZERO
		var n := 0
		for st in stalls:
			if (st["p"] as Vector2).distance_to(stalls[0]["p"]) < 20.0:
				mc += st["p"]
				n += 1
		mc /= n
		var from := (v - mc).normalized() if mc.distance_to(v) > 3.0 else to_dock
		var perp := Vector2(-from.y, from.x)
		out_r["market"] = ["the market (%d stalls)" % n, _g(isl, mc + from * 10.0 + perp * 2.0, 2.2), _g(isl, mc, 1.0), 0.0]
	# the landmark: the one standing highest
	var lm = null
	for l in r["d"]["landmarks"]:
		if LANDMARK_KINDS.has(l["kind"]) and (lm == null or float(l["top"]) > float(lm["top"])):
			lm = l
	if lm:
		var lp: Vector2 = lm["p"]
		var h := maxf(float(lm["h"]), 3.0)
		var away := (v - lp).normalized() if v.distance_to(lp) > 5.0 else to_dock
		var dist := maxf(3.0 * h + 10.0, 25.0)
		var cp := lp + away * dist + Vector2(-away.y, away.x) * dist * 0.3
		var cy := maxf(maxf(isl.hv(cp), 0.0) + 5.0, isl.hv(lp) + h + 3.0)
		out_r["landmark"] = ["the landmark: %s" % lm["kind"], Vector3(cp.x, cy, cp.y), Vector3(lp.x, isl.hv(lp) + h * 0.5, lp.y), 0.0]
	else:
		out_r["landmark"] = ["(no landmark)", out_r["plaza"][1], out_r["plaza"][2], 0.0]
	var c: Vector2 = a["camp"]
	var to_v := (v - c).normalized()
	out_r["camp"] = ["the pirates' camp", _g(isl, c + to_v * 18.0 + Vector2(-to_v.y, to_v.x) * 5.0, 5.0), _g(isl, c, 1.0), 0.0]
	out_r["night"] = ["the village at night (21:00)", _g(isl, v + to_dock * 30.0 + vs * 20.0, 16.0), _g(isl, v, 0.0), 0.0]
	return out_r


## [middle, size] of the settled land within 70 m of the waterfront or the village.
func _core(r: Dictionary) -> Array:
	var a: Dictionary = r["d"]["anchors"]
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for k in r["d"]["settled"].keys():
		var q := (Vector2(k) + Vector2(0.5, 0.5)) * F.GRID
		if q.distance_to(a["village"]) > 70.0 and F._poly_dist(a["harbour"], q) > 70.0:
			continue
		lo = Vector2(minf(lo.x, q.x), minf(lo.y, q.y))
		hi = Vector2(maxf(hi.x, q.x), maxf(hi.y, q.y))
	if lo.x == INF:
		return [a["village"], 120.0]
	return [(lo + hi) * 0.5, maxf(hi.x - lo.x, hi.y - lo.y)]


func _g(isl, p: Vector2, up: float) -> Vector3:
	return Vector3(p.x, maxf(isl.hv(p), 0.0) + up, p.y)


func _aim() -> void:
	var s: Array = shots[idx]
	var isl: Node3D = isles[s[0]]
	var ortho := float(s[5]) > 0.0
	for we in root.find_children("*", "WorldEnvironment", true, false):
		we.environment.fog_enabled = not ortho
	var clouds = root.get_node_or_null("World/Clouds")
	if clouds:
		clouds.visible = not ortho
	caption.text = "%s  -  %s" % [labels[s[0]], s[2]]
	cam.global_position = isl.to_global(s[3])
	if ortho:
		cam.projection = Camera3D.PROJECTION_ORTHOGONAL
		cam.size = float(s[5])
		cam.global_rotation = Vector3(-PI * 0.5, isl.global_rotation.y, 0.0)
	else:
		cam.projection = Camera3D.PROJECTION_PERSPECTIVE
		cam.look_at(isl.to_global(s[4]), Vector3.UP)


## Brinehollow left, the generated island right, a row per recipe, each at half size.
func _sheet() -> void:
	var any: Image = frames.values()[0]
	var w: int = any.get_width() / 2
	var h: int = any.get_height() / 2
	var sheet := Image.create(w * 2 + 6, (h + 6) * ORDER.size(), false, Image.FORMAT_RGB8)
	sheet.fill(Color(0.08, 0.08, 0.08))
	for row in range(ORDER.size()):
		for i in range(2):
			var f: Image = frames.get("%s_%d" % [ORDER[row], i])
			if f == null:
				continue
			f.convert(Image.FORMAT_RGB8)
			f.resize(w, h, Image.INTERPOLATE_BILINEAR)
			sheet.blit_rect(f, Rect2i(0, 0, w, h), Vector2i(i * (w + 6), row * (h + 6)))
	sheet.save_png("%s_sheet.png" % out)
