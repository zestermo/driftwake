class_name MapIsleView
extends Control
## The map's island page: the land inked from its heights (map_land.gdshader), its paths and town,
## the fog of war over what the crew hasn't seen (MapFog), a `?` near every spot not found yet, the
## spots found with their names, treasure Xs, the crew's marks, the ship and the captains. Fills its
## parent page; the land sits in `frame` (the page less a title strip and a hint strip).

const LAND := preload("res://shaders/map_land.gdshader")
const INK := Color(0.3, 0.2, 0.12)
const FADED := Color(0.3, 0.2, 0.12, 0.55)
const RED := Color(0.72, 0.14, 0.08)
const SHIP := Color(0.15, 0.3, 0.55)
## The page's own paper (sea_chart's), so the fog is blank paper.
const PAPER := Color(0.913, 0.864, 0.746)
## Page px kept clear above (the title) and below (the hints), and at the sides.
const TOP := 28.0
const BOTTOM := 22.0
const SIDE := 12.0
## Metres of sea round the land left out when the page fits an island.
const TRIM := 50.0
## The zooms (x the fit): the whole island, then closer in round our captain.
const ZOOMS := [1.0, 2.0, 3.5]
## How fast the view moves to a new zoom (1/s).
const GLIDE := 12.0

var d: Dictionary = {}
## The island point at the frame's middle, and page px per metre (gliding to the zoom's).
var centre := Vector2.ZERO
var k := 1.0
var zoom := 0
var _fit_k := 1.0
var _fit_c := Vector2.ZERO
var frame: Control
var _land: Control
var _under: Control
var _fog: Control
var _over: Control
var _fog_tex: ImageTexture
var _fog_v := -1
var _font: Font
var _font_big: Font


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_font = load("res://assets/fonts/Silkscreen-Regular.woff2")
	_font_big = load("res://assets/fonts/PixelifySans-Regular.woff2")
	frame = Control.new()
	frame.name = "Frame"
	frame.clip_contents = true
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(frame)
	_land = _layer("Land", _draw_land)
	_under = _layer("Under", _draw_under)
	_fog = _layer("Fog", _draw_fog)
	_over = _layer("Over", _draw_over)
	for c in [_land, _fog]:
		var m := ShaderMaterial.new()
		m.shader = LAND
		m.set_shader_parameter("fog_pass", c == _fog)
		m.set_shader_parameter("paper", PAPER)
		c.material = m


func _layer(nm: String, f: Callable) -> Control:
	var c := Control.new()
	c.name = nm
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.draw.connect(f)
	frame.add_child(c)
	return c


## Show island d (MapIsles), fitted to the page.
func show_isle(isle: Dictionary, page: Vector2) -> void:
	d = isle
	frame.position = Vector2(SIDE, TOP)
	frame.size = page - Vector2(SIDE * 2.0, TOP + BOTTOM)
	var view := (d["rect"] as Rect2).grow(-TRIM)
	_fit_c = view.get_center()
	_fit_k = minf(frame.size.x / view.size.x, frame.size.y / view.size.y)
	zoom = 0
	centre = _fit_c
	k = _fit_k
	var htex := MapIsles.heights_tex(d)
	for c in [_land, _fog]:
		var m := c.material as ShaderMaterial
		m.set_shader_parameter("heights", htex)
		m.set_shader_parameter("cells", float(d["cells"]))
		m.set_shader_parameter("extent", (d["rect"] as Rect2).size.x)
		m.set_shader_parameter("fog_k", (d["rect"] as Rect2).size.x / (int(d["n"]) * MapIsles.FOG_CELL))
	_fog_v = -1
	_fog_tex = null
	refresh()


## Everything again (the page opened, the view moved).
func refresh() -> void:
	for c in frame.get_children():
		(c as Control).queue_redraw()


## One zoom in (+1) or out (-1); false when there's no further that way.
func step_zoom(by: int) -> bool:
	var z := zoom + by
	if z < 0 or z >= ZOOMS.size():
		return false
	zoom = z
	return true


## Where the view goes: the whole island, or (zoomed) round our captain, kept on the island's square.
func _aim() -> Array:
	var kk: float = _fit_k * ZOOMS[zoom]
	if zoom == 0:
		return [_fit_c, kk]
	var me := get_tree().get_first_node_in_group("player") as Node3D
	var c := Vector2(me.global_position.x, me.global_position.z) - (d["o"] as Vector2)
	var half := frame.size * 0.5 / kk
	var r: Rect2 = d["rect"]
	return [c.clamp(r.position + half, r.end - half), kk]


func _process(delta: float) -> void:
	if d.is_empty() or not is_visible_in_tree():
		return
	var aim := _aim()
	var w := 1.0 - exp(-GLIDE * delta)
	var moved: bool = (centre - aim[0]).length() * k > 0.25 or absf(k - aim[1]) > 0.0005
	if moved:
		centre = centre.lerp(aim[0], w)
		k = lerpf(k, aim[1], w)
	if _fog_v != MapFog.version:
		_fog_v = MapFog.version
		_upload_fog()
		refresh()
	elif moved:
		refresh()
	else:
		_over.queue_redraw()


func _upload_fog() -> void:
	var n := int(d["n"])
	var img := Image.create_from_data(n, n, false, Image.FORMAT_L8, MapFog.grid(GameManager, d))
	if _fog_tex == null:
		_fog_tex = ImageTexture.create_from_image(img)
		(_fog.material as ShaderMaterial).set_shader_parameter("fog", _fog_tex)
	else:
		_fog_tex.update(img)


## Island point -> frame px.
func to_frame(p: Vector2) -> Vector2:
	return frame.size * 0.5 + (p - centre) * k


## World x/z -> frame px.
func world_to_frame(w: Vector2) -> Vector2:
	return to_frame(w - (d["o"] as Vector2))


## Page px (this control's) -> world x/z.
func page_to_world(at: Vector2) -> Vector2:
	return (d["o"] as Vector2) + centre + (at - frame.position - frame.size * 0.5) / k


func _rect_px() -> Rect2:
	var r: Rect2 = d["rect"]
	return Rect2(to_frame(r.position), r.size * k)


func _draw_land() -> void:
	if not d.is_empty():
		_land.draw_texture_rect(MapIsles.heights_tex(d), _rect_px(), false)


func _draw_fog() -> void:
	if not d.is_empty() and _fog_tex:
		_fog.draw_texture_rect(MapIsles.heights_tex(d), _rect_px(), false)


## Under the fog: the paths (dashed) and the town.
func _draw_under() -> void:
	if d.is_empty():
		return
	for path in d["isl"].paths:
		var carry := 0.0
		for i in range(path.size() - 1):
			var a := to_frame(path[i])
			var b := to_frame(path[i + 1])
			var seg := a.distance_to(b)
			var t := carry
			while t < seg:
				_under.draw_line(a.lerp(b, t / seg), a.lerp(b, minf(t + 2.0, seg) / seg), FADED, 1.0)
				t += 4.0
			carry = t - seg
	var town: Array = d["town"]
	if not town.is_empty():
		var c := to_frame(town[0])
		var h := absi(hash(str(d["key"])))
		for i in range(7):
			var o := Vector2(float((h >> (i * 3)) % 9) - 4.0, float((h >> (i * 3 + 13)) % 7) - 3.0) * 2.0
			_under.draw_rect(Rect2(c + o - Vector2(2, 2), Vector2(4, 3)), INK)


## Over the fog: the spots, Xs, marks, ship and crew.
func _draw_over() -> void:
	if d.is_empty():
		return
	var gm := GameManager
	var taken: Array = found_spots().map(func(s): return Rect2(to_frame(s["at"]) - Vector2(6, 6), Vector2(12, 12)))
	var town: Array = d["town"]
	if not town.is_empty() and MapFog.seen(gm, d, town[0]):
		_label(to_frame(town[0]), 10.0, str(town[1]), INK, taken)
	for s in found_spots():
		var c := to_frame(s["at"])
		icon(_over, c, str(s["kind"]), INK)
		_label(c, 6.0, str(s["name"]), INK, taken)
	for s in question_marks():
		_over.draw_string(_font_big, to_frame(MapIsles.rough(d, s)) + Vector2(-3, 5), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, RED)
	var sf := get_tree().get_first_node_in_group("sea_features")
	if sf:
		for t in gm.maps.keys():
			var ti := int(t)
			if ti < sf.treasures.size() and not gm.opened.has("treasure_%d" % ti):
				var p3: Vector3 = sf.treasures[ti][0]
				var c := world_to_frame(Vector2(p3.x, p3.z))
				_over.draw_line(c + Vector2(-4, -4), c + Vector2(4, 4), RED, 2.0)
				_over.draw_line(c + Vector2(-4, 4), c + Vector2(4, -4), RED, 2.0)
	for id in Net.waypoints.keys():
		var col: Color = Net.crew_color(id) if Net.active else RED
		var pts: Array = Net.waypoints[id]
		for i in range(pts.size()):
			var c := world_to_frame(pts[i])
			_over.draw_line(c, c + Vector2(0, -10), INK, 1.0)
			_over.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -10), c + Vector2(7, -7.5), c + Vector2(0, -5)]), col)
			_text(_over, c + Vector2(3, 8), str(i + 1), INK)
	MapMarks.draw_all(_over, world_to_frame, _font)
	var ship := get_tree().get_first_node_in_group("ship") as Node3D
	if ship:
		arrow(_over, world_to_frame(Vector2(ship.global_position.x, ship.global_position.z)), ship.global_rotation.y, 7.0, SHIP)
	for p in get_tree().get_nodes_in_group("players"):
		var pl := p as Node3D
		var c := world_to_frame(Vector2(pl.global_position.x, pl.global_position.z))
		var yaw: float = p.player_model.global_rotation.y
		if p.is_local:
			arrow(_over, c, yaw, 6.0, RED)
			_over.draw_arc(c, 7.0, 0.0, TAU, 14, RED, 1.0)
		else:
			arrow(_over, c, yaw, 5.0, Net.crew_color(p.net_id).darkened(0.35))
			_text(_over, c + Vector2(6, -3), p.display_name(), Net.crew_color(p.net_id).darkened(0.5))


## The island's spots the crew has found (marked by name).
func found_spots() -> Array:
	return (d["spots"] as Array).filter(func(s): return MapFog.found(GameManager, str(d["key"]), str(s["id"])))


## ...and the ones not found yet (a `?` near each).
func question_marks() -> Array:
	return (d["spots"] as Array).filter(func(s): return not MapFog.found(GameManager, str(d["key"]), str(s["id"])))


## A name beside the mark at c (`gap` px off it): right, left, below or above, the first clear of the
## names already placed (`taken`).
func _label(c: Vector2, gap: float, s: String, col: Color, taken: Array) -> void:
	var sz := _font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 8)
	var at := c + Vector2(gap, 3)
	for o in [Vector2(gap, 3), Vector2(-gap - sz.x, 3), Vector2(-sz.x * 0.5, gap + 7), Vector2(-sz.x * 0.5, -gap - 1)]:
		var r := Rect2(c + o - Vector2(0, 7), sz + Vector2(2, 0))
		if not taken.any(func(t): return (t as Rect2).intersects(r)):
			at = c + o
			break
	taken.append(Rect2(at - Vector2(0, 7), sz + Vector2(2, 0)))
	_text(_over, at, s, col)


func _text(ci: CanvasItem, at: Vector2, s: String, col: Color) -> void:
	ci.draw_string(_font, at, s, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, col)


## A pointer at c facing `yaw` (a Node3D's y rotation: -Z forward), `s` px long.
static func arrow(ci: CanvasItem, c: Vector2, yaw: float, s: float, col: Color) -> void:
	var f := Vector2(-sin(yaw), -cos(yaw))
	var r := Vector2(f.y, -f.x)
	ci.draw_colored_polygon(PackedVector2Array([c + f * s, c - f * s * 0.7 + r * s * 0.6, c - f * s * 0.4, c - f * s * 0.7 - r * s * 0.6]), col)


## A found spot's mark, about 5 px round c.
static func icon(ci: CanvasItem, c: Vector2, kind: String, col: Color) -> void:
	match kind:
		"camp":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -5), c + Vector2(5, 4), c + Vector2(-5, 4)]), col)
			ci.draw_line(c + Vector2(0, -1), c + Vector2(0, 4), Color(0.9, 0.84, 0.68), 1.0)
		"cave":
			ci.draw_arc(c + Vector2(0, 3), 5.0, PI, TAU, 8, col, 2.0)
			ci.draw_line(c + Vector2(-6, 3), c + Vector2(6, 3), col, 1.0)
		"ruins":
			for x in [-4.0, 0.0, 4.0]:
				ci.draw_line(c + Vector2(x, 4), c + Vector2(x, -3.0 if x != 0.0 else -1.0), col, 2.0)
			ci.draw_line(c + Vector2(-5, -4), c + Vector2(1, -4), col, 1.0)
		"lookout":
			ci.draw_line(c + Vector2(-3, 5), c + Vector2(-1, -3), col, 1.0)
			ci.draw_line(c + Vector2(3, 5), c + Vector2(1, -3), col, 1.0)
			ci.draw_rect(Rect2(c + Vector2(-3, -6), Vector2(6, 3)), col)
		"lair", "beast":
			for x in [-3.0, 0.0, 3.0]:
				ci.draw_line(c + Vector2(x - 1.5, -4), c + Vector2(x + 1.5, 4), col, 1.0)
		"treasure":
			ci.draw_line(c + Vector2(-4, -4), c + Vector2(4, 4), RED, 2.0)
			ci.draw_line(c + Vector2(-4, 4), c + Vector2(4, -4), RED, 2.0)
		_:
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -5), c + Vector2(1.5, -1.5), c + Vector2(5, 0), c + Vector2(1.5, 1.5),
				c + Vector2(0, 5), c + Vector2(-1.5, 1.5), c + Vector2(-5, 0), c + Vector2(-1.5, -1.5)]), col)
