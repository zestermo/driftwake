extends Control
## A compass strip across the top of the screen (1.26: always up, outside menus, talks and scenes): the way the camera
## faces in the middle, the half circle either side, N/E/S/W, where the wind blows from, the crew's chart marks
## (Net.waypoints) with how far off they are, the log pose's needles, and (1.26) every other captain of the crew (their
## colour and initial, pinned to the nearer end when behind you), the objective (a gold star) and the island's village.
## North is -z.

const W := 230.0
const H := 24.0
## Degrees from the middle to each end of the strip.
const SPAN := 90.0
const MARKS := preload("res://scripts/ui/chain_marks.gd")

var _font: Font
var _t := 0.0


func _init() -> void:
	set_anchors_preset(Control.PRESET_CENTER_TOP)
	offset_left = -W * 0.5
	offset_right = W * 0.5
	offset_top = 4
	offset_bottom = 4 + H
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = load("res://assets/fonts/Silkscreen-Regular.woff2")


static func bearing(d: Vector2) -> float:
	return rad_to_deg(atan2(d.x, -d.y))


## Screen x on the strip for a bearing (INF beyond the ends).
func _x(b: float, heading: float) -> float:
	var off := wrapf(b - heading, -180.0, 180.0)
	if absf(off) > SPAN:
		return INF
	return W * 0.5 + off / SPAN * (W * 0.5 - 6.0)


func _process(delta: float) -> void:
	_t += delta
	if visible:
		queue_redraw()


func _draw() -> void:
	var cam := get_tree().root.get_camera_3d()
	if cam == null:
		return
	var f := -cam.global_basis.z
	var heading := bearing(Vector2(f.x, f.z))
	draw_rect(Rect2(0, 0, W, 12), Color(UIStyle.BG_DARK, 0.55))
	var ink := Color(0.95, 0.92, 0.85)
	for d in range(0, 360, 15):
		var x := _x(float(d), heading)
		if x == INF:
			continue
		var major := d % 90 == 0
		draw_line(Vector2(x, 0), Vector2(x, 4 if not major else 6), Color(ink, 0.6 if not major else 1.0), 1.0)
		var lbl: String = {0: "N", 90: "E", 180: "S", 270: "W", 45: "ne", 135: "se", 225: "sw", 315: "nw"}.get(d, "")
		if lbl != "":
			var col := Color(1.0, 0.45, 0.35) if d == 0 else ink
			draw_string(_font, Vector2(x - 3, 11), lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, col if major else Color(ink, 0.6))
	# where the wind comes from
	var wx := get_node_or_null("/root/Weather")
	if wx:
		var wd: Vector2 = wx.wind_dir()
		var x := _x(bearing(-wd), heading)
		if x != INF:
			var c := Color(0.55, 0.85, 1.0)
			draw_colored_polygon(PackedVector2Array([Vector2(x, 12), Vector2(x - 3, 16), Vector2(x + 3, 16)]), c)
			draw_string(_font, Vector2(x - 8, 23), "wind", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(c, 0.8))
	# the chart marks
	var me := get_tree().get_first_node_in_group("player") as Node3D
	if me:
		var here := Vector2(me.global_position.x, me.global_position.z)
		for id in Net.waypoints.keys():
			var col: Color = Net.crew_color(id) if Net.active else UIStyle.ACCENT
			for p in Net.waypoints[id]:
				var to: Vector2 = p - here
				var off := wrapf(bearing(to) - heading, -180.0, 180.0)
				var x := W * 0.5 + clampf(off / SPAN, -1.0, 1.0) * (W * 0.5 - 6.0)
				var r := 3.5
				draw_colored_polygon(PackedVector2Array([Vector2(x, 2), Vector2(x + r, 2 + r), Vector2(x, 2 + r * 2), Vector2(x - r, 2 + r)]), col)
				if absf(off) <= SPAN:
					var txt := "%dm" % int(to.length())
					draw_string_outline(_font, Vector2(x - 8, 22), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, 3, Color.BLACK)
					draw_string(_font, Vector2(x - 8, 22), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, col)
		_draw_log_pose(heading, here)
		_draw_lookout(heading, here, me)
		_draw_treasure(heading, here, me)
		_draw_village(heading, here)
		_draw_objective(heading, here)
		_draw_crew(heading, here, me)
	# where we're facing
	draw_colored_polygon(PackedVector2Array([Vector2(W * 0.5, 12), Vector2(W * 0.5 - 3, 15), Vector2(W * 0.5 + 3, 15)]), UIStyle.ACCENT)
	draw_line(Vector2(W * 0.5, 0), Vector2(W * 0.5, 12), UIStyle.ACCENT, 1.0)


## (1.26) A point on the strip, pinned to its nearer end when it's behind you (so a crewmate behind you still shows
## which way to turn). Returns its x.
func _pin(heading: float, to: Vector2) -> float:
	var off := wrapf(bearing(to) - heading, -180.0, 180.0)
	return W * 0.5 + clampf(off / SPAN, -1.0, 1.0) * (W * 0.5 - 6.0)


## (1.26) Every other captain of the crew: a pip in their crew colour with their initial, and how far.
func _draw_crew(heading: float, here: Vector2, me: Node3D) -> void:
	for c in get_tree().get_nodes_in_group("players"):
		if c == me or not (c is Player) or (c as Player).is_ai:
			continue
		var cp := c as Player
		var to := Vector2(cp.global_position.x, cp.global_position.z) - here
		if to.length() < 4.0:
			continue
		var x := _pin(heading, to)
		var col: Color = Net.crew_color(cp.net_id) if Net.active else UIStyle.ACCENT
		draw_circle(Vector2(x, 6), 4.0, Color.BLACK)
		draw_circle(Vector2(x, 6), 3.0, col)
		var nm := str(cp.net_profile.get("name", cp.display_name() if cp.has_method("display_name") else "?"))
		var txt := "%s %dm" % [nm.substr(0, 1).to_upper(), int(to.length())]
		draw_string_outline(_font, Vector2(x - 8, 22), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, 3, Color.BLACK)
		draw_string(_font, Vector2(x - 8, 22), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, col)


## (1.26) The objective (the tracked quest's or the story's: the HUD's Objective): a gold star, and how far.
func _draw_objective(heading: float, here: Vector2) -> void:
	var oh := get_parent().get_node_or_null("Objective")
	if oh == null or not oh.has_method("objective") or (oh.objective() as Dictionary).is_empty():
		return
	var t: Vector3 = oh._target()
	if t == Vector3.INF:
		return
	var to := Vector2(t.x, t.z) - here
	var x := _pin(heading, to)
	var gold := Color(1.0, 0.82, 0.3)
	var pts := PackedVector2Array()
	for i in range(10):
		var r := 4.5 if i % 2 == 0 else 2.0
		var a := -PI * 0.5 + i * PI / 5.0
		pts.append(Vector2(x, 6) + Vector2(cos(a), sin(a)) * r)
	draw_colored_polygon(pts, gold)
	if to.length() > 6.0:
		var txt := "%dm" % int(to.length())
		draw_string_outline(_font, Vector2(x - 8, 22), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, 3, Color.BLACK)
		draw_string(_font, Vector2(x - 8, 22), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, gold)


## (1.26) The village of the chain island you're on, while you're off its plaza: a little house.
func _draw_village(heading: float, here: Vector2) -> void:
	var gm := get_node_or_null("/root/GameManager")
	var w := get_tree().get_first_node_in_group("world_gen")
	if gm == null or w == null or not ("chain_islands" in w):
		return
	var isl = w.chain_islands.get(int(gm.chain_at))
	if isl == null or not is_instance_valid(isl) or not ("village_plan" in isl) or (isl.village_plan as Dictionary).is_empty():
		return
	var vc: Vector2 = isl.village_plan["c"]
	var at: Vector3 = (isl as Node3D).to_global(Vector3(vc.x, 0.0, vc.y))
	var to := Vector2(at.x, at.z) - here
	if to.length() < float(isl.village_plan.get("plaza_r", 15.0)) + 10.0 or to.length() > 900.0:
		return
	var x := _x(bearing(to), heading)
	if x == INF:
		return
	var c := Color(0.95, 0.85, 0.65)
	draw_colored_polygon(PackedVector2Array([Vector2(x - 3, 5), Vector2(x, 2), Vector2(x + 3, 5)]), c)
	draw_rect(Rect2(x - 2.5, 5, 5, 4), c)


## The log pose's needles on the strip, each with its island's theme icon,
## distance and danger under it (at a fork the left one's label to its left).
## Unset, one faint needle wanders about with a "?".
func _draw_log_pose(heading: float, here: Vector2) -> void:
	var gm := get_node_or_null("/root/GameManager")
	if gm == null or gm.player == null or not gm.player.has_log_pose():
		return
	var targets: Array = MARKS.targets(gm)
	if targets.is_empty():
		var x := W * 0.5 + sin(_t * 0.9) * sin(_t * 0.37 + 1.0) * (W * 0.5 - 20.0)
		_needle(x, Color(MARKS.NEEDLE_COLORS[0], 0.5))
		_label(x + 4.0, "?", Color(0.95, 0.9, 0.8, 0.7))
		return
	var marks: Array = []
	for i in range(targets.size()):
		var to: Vector2 = (targets[i]["pos"] as Vector2) - here
		var off := wrapf(bearing(to) - heading, -180.0, 180.0)
		marks.append([W * 0.5 + clampf(off / SPAN, -1.0, 1.0) * (W * 0.5 - 6.0), i, to.length()])
	marks.sort_custom(func(a, b): return a[0] < b[0])
	var lvl: int = gm.player.progression.level
	for j in range(marks.size()):
		var x: float = marks[j][0]
		var n: Dictionary = targets[marks[j][1]]
		_needle(x, MARKS.NEEDLE_COLORS[marks[j][1]])
		var theme := str(n["theme"])
		MARKS.icon(self, Vector2(x, 18), theme, 3.5, MARKS.theme_color(theme))
		var dz: Array = MARKS.danger(int(n["level"]), lvl)
		var txt := "%.1fkm %s" % [float(marks[j][2]) / 1000.0, dz[0]]
		var w := _font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
		var left := j == 0 and marks.size() > 1
		_label(x - 6.0 - w if left else x + 6.0, txt, dz[1])


## The lookout (the ship's nest line, Ship.lookout m, plus your Seamanship's): enemy sails (red, with how far)
## and floating salvage (gold) in range, while you're aboard her.
func _draw_lookout(heading: float, here: Vector2, me: Node3D) -> void:
	var ship := get_tree().get_first_node_in_group("ship") as Ship
	# (her nest, and your own Seamanship's Weather Eye)
	var reach := (ship.lookout if ship else 0.0) + Seamanship.stat(get_tree(), "lookout")
	if ship == null or reach <= 0.0 or not ship.aboard(me.global_position):
		return
	for n in get_tree().get_nodes_in_group("enemy_ships"):
		var to := Vector2(n.global_position.x, n.global_position.z) - here
		var x := _x(bearing(to), heading)
		if n.is_dead() or to.length() > reach or x == INF:
			continue
		var c := Color(1.0, 0.36, 0.3)
		draw_colored_polygon(PackedVector2Array([Vector2(x - 3, 0), Vector2(x + 3, 0), Vector2(x, 5)]), c)
		_label(x - 7.0, "%dm" % int(to.length()), c)
	for n in get_tree().get_nodes_in_group("salvage"):
		var to := Vector2(n.global_position.x, n.global_position.z) - here
		var x := _x(bearing(to), heading)
		if to.length() > reach or x == INF:
			continue
		draw_rect(Rect2(x - 1.5, 13.0, 3.0, 3.0), Color(1.0, 0.85, 0.4))


## Treasure Sense (a Captain talent, Progression "treasure_sense" m): chests not opened yet within reach, a gold coin.
func _draw_treasure(heading: float, here: Vector2, me: Node3D) -> void:
	var pr = me.get("progression")
	var reach: float = pr.stat("treasure_sense") if pr else 0.0
	if reach <= 0.0:
		return
	for b in get_tree().get_nodes_in_group("loot_bags"):
		var bag := b as LootBag
		if bag.save_id == "" or bag.rolled:
			continue
		var to := Vector2(bag.global_position.x, bag.global_position.z) - here
		var x := _x(bearing(to), heading)
		if to.length() > reach or x == INF:
			continue
		draw_circle(Vector2(x, 15.0), 2.5, Color(1.0, 0.82, 0.3))


## A needle standing on the strip: the coloured point up, the dark tail down.
func _needle(x: float, col: Color) -> void:
	draw_rect(Rect2(x - 2.0, -1.0, 4.0, 13.0), Color(0, 0, 0, col.a * 0.8))
	draw_colored_polygon(PackedVector2Array([Vector2(x, -1), Vector2(x + 1.5, 6), Vector2(x - 1.5, 6)]), col)
	draw_rect(Rect2(x - 1.0, 6.0, 2.0, 5.0), Color(0.15, 0.15, 0.18, col.a))


func _label(x: float, txt: String, col: Color) -> void:
	draw_string_outline(_font, Vector2(x, 22), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, 3, Color.BLACK)
	draw_string(_font, Vector2(x, 22), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, col)
