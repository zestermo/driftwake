class_name SkillMapScreen
extends Control
## The skill map (K), in two tabs (click them or press Tab):
## * Skill Map: one pannable, zoomable constellation - stats in the middle;
##   Mobility, Survival, Sword, Gun, Armament and Observation Haki radiate out.
## * Devil Fruit: your fruit's own tree (empty until you've eaten one).
## Every time it opens it frames the whole cluster of the current tab.
##
## Mouse: drag to pan, wheel to zoom, click a node to select it, click it again
## (or Enter / F) to learn it. With a learned active skill selected, 1-4 puts
## it on the skill bar (R for an ultimate). Right-click a bar slot to clear it.
## WASD / arrows pan, Q / E zoom.

const FONT := preload("res://assets/fonts/Silkscreen-Regular.woff2")
const PANEL_W := 160.0
const BAR_SLOT := 24.0

var menu: Node
var _pan := Vector2.ZERO
var _zoom := 0.38
var _tab: int = 0   # 0 = skill map, 1 = devil fruit
var _sel: String = "origin"
var _hover: String = ""
var _drag := false
var _drag_from := Vector2.ZERO
var _drag_moved: float = 0.0
var _icons: Dictionary = {}
var _msg: String = ""
var _msg_t: float = 0.0
var _t: float = 0.0
var _stars: PackedVector2Array = PackedVector2Array()


func _init(owner_menu: Node) -> void:
	menu = owner_menu
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for i in range(140):
		_stars.append(Vector2(rng.randf(), rng.randf()))


func _player() -> Player:
	return get_tree().get_first_node_in_group("player") as Player if is_inside_tree() else null


func on_open() -> void:
	# icons are loaded here, never inside _draw
	_icons.clear()
	for id in Skills.ALL.keys():
		_icons[id] = Skills.icon(id)
	grab_focus()
	_frame_tab()
	queue_redraw()


func set_tab(i: int) -> void:
	_tab = clampi(i, 0, 1)
	_sel = "origin" if _tab == 0 else _fruit_root()
	_hover = ""
	_frame_tab()


## The root node of your fruit's tree ("" without a fruit).
func _fruit_root() -> String:
	var pl := _player()
	if pl == null or not pl.power.has_fruit():
		return ""
	for id in SkillTree.nodes().keys():
		var n: Dictionary = SkillTree.nodes()[id]
		if str(n["kind"]) == "root" and str(n["req"].get("fruit", "")) == pl.power.fruit:
			return id
	return ""


## Center and zoom so the current tab's whole cluster is in view.
func _frame_tab() -> void:
	var mr := _map_rect()
	if mr.size.x < 10.0:
		mr = Rect2(Vector2.ZERO, Vector2(480, 326))
	var pts: Array = []
	for id in SkillTree.nodes().keys():
		if _shown(id):
			pts.append(SkillTree.nodes()[id]["pos"])
	if _tab == 0 or pts.is_empty():
		_pan = Vector2.ZERO
		# the main constellation reaches ~470 from the center (region labels)
		_zoom = clampf(minf(mr.size.x, mr.size.y - 24.0) / 2.0 / 470.0, 0.22, 1.6)
		return
	var lo: Vector2 = pts[0]
	var hi: Vector2 = pts[0]
	for q in pts:
		lo = lo.min(q)
		hi = hi.max(q)
	_pan = (lo + hi) * 0.5 + Vector2(0, -12.0)
	var span := (hi - lo) + Vector2(140, 120)
	_zoom = clampf(minf(mr.size.x / span.x, (mr.size.y - 30.0) / span.y), 0.3, 1.4)

func _process(delta: float) -> void:
	# the screen stays "visible" inside the hidden menu root when closed:
	# only act while it's actually on screen
	if not is_visible_in_tree():
		return
	_t += delta
	_msg_t = maxf(_msg_t - delta, 0.0)
	var pan_in := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		pan_in.x -= 1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		pan_in.x += 1
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		pan_in.y -= 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		pan_in.y += 1
	_pan += pan_in * delta * 420.0 / _zoom
	queue_redraw()


# --------------------------------------------------------------------------
# Geometry
# --------------------------------------------------------------------------
func _map_rect() -> Rect2:
	return Rect2(Vector2.ZERO, Vector2(size.x - PANEL_W, size.y - 34.0))


func _to_screen(p: Vector2) -> Vector2:
	var mr := _map_rect()
	return mr.get_center() + (p - _pan) * _zoom


func _to_map(sp: Vector2) -> Vector2:
	var mr := _map_rect()
	return (sp - mr.get_center()) / _zoom + _pan


## Is a node on the current tab? (Skill map: everything but fruit nodes;
## Devil Fruit tab: your own fruit's nodes.)
func _shown(id: String) -> bool:
	var n := SkillTree.get_node_def(id)
	var fr := str(n["req"].get("fruit", ""))
	if _tab == 0:
		return fr == ""
	var pl := _player()
	return fr != "" and pl != null and pl.power.fruit == fr


func _radius(n: Dictionary) -> float:
	match str(n["kind"]):
		"origin":
			return 15.0
		"root", "ult":
			return 14.0
		"active":
			return 12.5
		"passive":
			return 8.5
	return 6.5


func _node_at(sp: Vector2) -> String:
	var best := ""
	var bd := INF
	for id in SkillTree.nodes().keys():
		if not _shown(id):
			continue
		var n: Dictionary = SkillTree.nodes()[id]
		var d := _to_screen(n["pos"]).distance_to(sp)
		var r := maxf(_radius(n) * clampf(_zoom * 2.0, 0.6, 1.6), 7.0)
		if d < r + 3.0 and d < bd:
			bd = d
			best = id
	return best


func _tab_rect(i: int) -> Rect2:
	return Rect2(4.0 + i * 74.0, 2.0, 72.0, 14.0)


func _tab_at(sp: Vector2) -> int:
	for i in range(2):
		if _tab_rect(i).has_point(sp):
			return i
	return -1


func _bar_slot_rect(i: int) -> Rect2:
	var y := size.y - 30.0
	var x := 64.0 + float(i) * (BAR_SLOT + 4.0) + (6.0 if i == 4 else 0.0)
	return Rect2(x, y, BAR_SLOT, BAR_SLOT)


# --------------------------------------------------------------------------
# Input
# --------------------------------------------------------------------------
func _gui_input(event: InputEvent) -> void:
	var pl := _player()
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_zoom_at(mb.position, 1.15)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_zoom_at(mb.position, 1.0 / 1.15)
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed and pl:
			for i in range(5):
				if _bar_slot_rect(i).has_point(mb.position):
					pl.power.equip("", i)
					menu._play()
		elif mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed and _tab_at(mb.position) >= 0:
			set_tab(_tab_at(mb.position))
			menu._play()
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_drag = true
				_drag_from = mb.position
				_drag_moved = 0.0
			else:
				_drag = false
				if _drag_moved < 5.0:
					_click(mb.position)
		accept_event()
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if _drag:
			_pan -= mm.relative / _zoom
			_drag_moved += mm.relative.length()
		_hover = _node_at(mm.position)
		accept_event()


func _zoom_at(sp: Vector2, k: float) -> void:
	var before := _to_map(sp)
	_zoom = clampf(_zoom * k, 0.22, 1.6)
	var after := _to_map(sp)
	_pan += before - after


func _click(sp: Vector2) -> void:
	var id := _node_at(sp)
	if id == "":
		return
	if id == _sel:
		_try_learn(id)
	else:
		_sel = id
		menu._play()


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var k: int = (event as InputEventKey).keycode
	var pl := _player()
	if pl == null:
		return
	if k == KEY_TAB:
		set_tab(1 - _tab)
		menu._play()
		get_viewport().set_input_as_handled()
	elif k == KEY_ENTER or k == KEY_KP_ENTER or k == KEY_F:
		_try_learn(_sel)
		get_viewport().set_input_as_handled()
	elif k == KEY_Q:
		_zoom_at(_map_rect().get_center(), 1.0 / 1.2)
		get_viewport().set_input_as_handled()
	elif k == KEY_E:
		_zoom_at(_map_rect().get_center(), 1.2)
		get_viewport().set_input_as_handled()
	elif (k >= KEY_1 and k <= KEY_4) or k == KEY_R:
		var slot := 4 if k == KEY_R else k - KEY_1
		var sk := str(SkillTree.get_node_def(_sel).get("skill", ""))
		if sk == "":
			_say("Select a learned active skill first")
		elif not pl.progression.knows(sk):
			_say("Learn it first")
		elif Skills.is_ult(sk) != (slot == 4):
			_say("Ultimates go on R" if Skills.is_ult(sk) else "R is for ultimates")
		elif pl.power.equip(sk, slot):
			menu._play()
			_say("%s on %s" % [Skills.get_skill(sk)["name"], "R" if slot == 4 else str(slot + 1)])
		get_viewport().set_input_as_handled()


func _try_learn(id: String) -> void:
	var pl := _player()
	if pl == null:
		return
	var why := pl.progression.can_learn(id)
	if why == "":
		pl.progression.learn(id)
		menu._play()
		var n := SkillTree.get_node_def(id)
		_say("Learned %s" % str(n["name"]))
		FX.sfx("coin", pl.global_position, -10.0, 0.0, 1.3)
	elif why != "Learned":
		_say(why)


func _say(m: String) -> void:
	_msg = m
	_msg_t = 2.5


# --------------------------------------------------------------------------
# Drawing
# --------------------------------------------------------------------------
func _text(pos: Vector2, s: String, col: Color = UIStyle.TEXT, sz: int = 8, align := HORIZONTAL_ALIGNMENT_LEFT, w := -1.0) -> void:
	draw_string_outline(FONT, pos, s, align, w, sz, 3, Color(0, 0, 0, 0.9))
	draw_string(FONT, pos, s, align, w, sz, col)


func _draw() -> void:
	var pl := _player()
	if pl == null:
		return
	var pr := pl.progression
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.03, 0.07, 1.0))
	for st in _stars:
		var sp := Vector2(st.x * size.x, st.y * size.y) - _pan * 0.05 * _zoom
		sp = Vector2(fposmod(sp.x, size.x), fposmod(sp.y, size.y))
		draw_rect(Rect2(sp, Vector2(1, 1)), Color(0.6, 0.65, 0.9, 0.35 + 0.25 * sin(_t * 1.3 + st.x * 40.0)))
	var mr := _map_rect()
	if _tab == 0:
		# region labels
		var labels := [["Mobility", "Mobility"], ["Survival", "Survival"], ["Sword", "Sword"], ["Gun", "Gun"],
			["Armament", "Armament Haki"], ["Observation", "Observation Haki"]]
		for l in labels:
			var a := deg_to_rad(SkillTree.REGION_ANGLE[l[0]])
			var lp := _to_screen(Vector2(cos(a), sin(a)) * 470.0)
			var col: Color = SkillTree.REGION_COLORS[l[0]]
			_text(lp + Vector2(-60, 0), str(l[1]).to_upper(), Color(col.r, col.g, col.b, 0.75), 8, HORIZONTAL_ALIGNMENT_CENTER, 120)
			if pr.level < 10 and l[0] in ["Armament", "Observation"]:
				_text(lp + Vector2(-60, 10), "awakens at level 10", Color(0.7, 0.6, 0.8, 0.6), 8, HORIZONTAL_ALIGNMENT_CENTER, 120)
	elif pl.power.has_fruit():
		var fd := pl.power.fruit_data()
		var fc: Color = fd["color"]
		_text(Vector2(0, 32), ("%s (%s)" % [fd["name"], DevilFruits.type_name(pl.power.fruit)]).to_upper(), Color(fc.r, fc.g, fc.b, 0.9), 8, HORIZONTAL_ALIGNMENT_CENTER, mr.size.x)
		var passive: Array = fd.get("passive", ["", ""])
		_text(Vector2(0, 42), "Passive: %s" % passive[0], Color(0.8, 0.8, 0.9, 0.7), 8, HORIZONTAL_ALIGNMENT_CENTER, mr.size.x)
	else:
		_text(Vector2(0, mr.size.y * 0.45), "NO DEVIL FRUIT YET", Color(0.75, 0.65, 0.8, 0.85), 8, HORIZONTAL_ALIGNMENT_CENTER, mr.size.x)
		_text(Vector2(0, mr.size.y * 0.45 + 12), "Eat one and its powers grow here. Three are hidden on Brinehollow.", Color(0.6, 0.55, 0.65, 0.75), 8, HORIZONTAL_ALIGNMENT_CENTER, mr.size.x)
	# links
	for id in SkillTree.nodes().keys():
		if not _shown(id):
			continue
		var n: Dictionary = SkillTree.nodes()[id]
		for l in n["links"]:
			if not _shown(l):
				continue
			var a2 := _to_screen(n["pos"])
			var b2 := _to_screen(SkillTree.get_node_def(l)["pos"])
			var both := pr.owns(id) and pr.owns(l)
			var one := pr.owns(id) or pr.owns(l)
			var col2 := UIStyle.ACCENT if both else (Color(0.55, 0.55, 0.65, 0.7) if one else Color(0.25, 0.25, 0.32, 0.6))
			draw_line(a2, b2, col2, 2.0 if both else 1.0)
	# nodes
	var k := clampf(_zoom * 2.0, 0.6, 1.6)
	for id in SkillTree.nodes().keys():
		if not _shown(id):
			continue
		_draw_node(id, SkillTree.nodes()[id], k, pr)
	# header
	draw_rect(Rect2(0, 0, mr.size.x, 18), Color(0, 0, 0, 0.55))
	for i in range(2):
		var tr := _tab_rect(i)
		var on := i == _tab
		draw_rect(tr, Color(0.25, 0.2, 0.1, 0.95) if on else Color(0.06, 0.06, 0.09, 0.95))
		draw_rect(tr, UIStyle.ACCENT if on else UIStyle.BORDER_DIM, false, 1.0)
		_text(tr.position + Vector2(0, 10), "SKILL MAP" if i == 0 else "DEVIL FRUIT", UIStyle.ACCENT if on else UIStyle.TEXT_DIM, 8, HORIZONTAL_ALIGNMENT_CENTER, tr.size.x)
	_text(Vector2(156, 12), "Lv %d  XP %d/%d" % [pr.level, pr.xp, Progression.xp_to_next(pr.level)], UIStyle.TEXT)
	var spc := Color(0.75, 0.95, 0.55) if pr.skill_points > 0 else UIStyle.TEXT_DIM
	_text(Vector2(272, 12), "SP %d" % pr.skill_points, spc)
	_text(Vector2(mr.size.x - 136, 12), "Tab: switch  K: close", UIStyle.TEXT_DIM, 8, HORIZONTAL_ALIGNMENT_RIGHT, 130)
	if pr.skill_points == 0 and pr.owned.size() <= 1:
		_text(Vector2(0, 30), "Win fights to earn XP. Every level gives 2 skill points.", Color(0.85, 0.85, 0.95, 0.75), 8, HORIZONTAL_ALIGNMENT_CENTER, mr.size.x)
	_draw_panel(pl)
	_draw_bar(pl)
	if _msg_t > 0.0:
		_text(Vector2(mr.size.x * 0.5 - 150, mr.size.y - 8), _msg, Color(1.0, 0.9, 0.6, clampf(_msg_t, 0.0, 1.0)), 8, HORIZONTAL_ALIGNMENT_CENTER, 300)


func _draw_node(id: String, n: Dictionary, k: float, pr: Progression) -> void:
	var c := _to_screen(n["pos"])
	if not Rect2(Vector2(-40, -40), size + Vector2(80, 80)).has_point(c):
		return
	var r := _radius(n) * k
	var owned := pr.owns(id)
	var why := pr.can_learn(id)
	var avail := why == ""
	var region_col: Color = SkillTree.REGION_COLORS.get(str(n["region"]), Color.WHITE)
	var kind := str(n["kind"])
	var fill := Color(0.07, 0.07, 0.1)
	var ring := Color(0.3, 0.3, 0.36)
	if owned:
		fill = region_col.darkened(0.35)
		ring = UIStyle.ACCENT
	elif avail:
		ring = region_col.lerp(Color.WHITE, 0.3 + 0.3 * sin(_t * 5.0))
	elif why.begins_with("Needs") and not why.ends_with("point") and not why.ends_with("points"):
		ring = Color(0.35, 0.25, 0.25)
	if kind in ["active", "ult"]:
		var rr := Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0)
		draw_rect(rr, fill)
		var tex: Texture2D = _icons.get(str(n["skill"]))
		if tex:
			draw_texture_rect(tex, rr.grow(-1.0), false, Color.WHITE if owned else Color(0.55, 0.55, 0.6, 0.85))
		draw_rect(rr, ring, false, 2.0 if (owned or avail) else 1.0)
		if kind == "ult":
			draw_arc(c, r * 1.45, 0, TAU, 24, Color(ring.r, ring.g, ring.b, 0.6), 1.0)
	elif kind == "passive":
		var pts := PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0)])
		draw_colored_polygon(pts, fill)
		pts.append(pts[0])
		draw_polyline(pts, ring, 2.0 if (owned or avail) else 1.0)
	else:
		draw_circle(c, r, fill)
		draw_arc(c, r, 0, TAU, 20, ring, 2.0 if (owned or avail) else 1.0)
		if kind in ["origin", "root"]:
			draw_circle(c, r * 0.45, region_col if owned else Color(0.3, 0.3, 0.35))
	if id == _sel:
		draw_arc(c, r + 4.0, 0, TAU, 24, Color.WHITE, 1.0)
	if id == _hover or kind in ["active", "ult", "root"] or (k >= 1.2 and kind != "stat"):
		var nc := Color(1, 1, 1, 0.95) if (owned or avail or id == _hover) else Color(0.75, 0.75, 0.82, 0.7)
		_text(c + Vector2(-60, r + 9.0), str(n["name"]), nc, 8, HORIZONTAL_ALIGNMENT_CENTER, 120)


func _draw_panel(pl: Player) -> void:
	var x0 := size.x - PANEL_W
	draw_rect(Rect2(x0, 0, PANEL_W, size.y), Color(0.04, 0.05, 0.09, 0.97))
	draw_line(Vector2(x0, 0), Vector2(x0, size.y), UIStyle.BORDER_DIM, 1.0)
	var id := _hover if _hover != "" else _sel
	var n := SkillTree.get_node_def(id)
	if n.is_empty():
		return
	var pr := pl.progression
	var region_col: Color = SkillTree.REGION_COLORS.get(str(n["region"]), Color.WHITE)
	var y := 16.0
	var title := str(n["name"])
	var tsz := 16 if FONT.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x <= PANEL_W - 14.0 else 8
	_text(Vector2(x0 + 8, y), title, UIStyle.ACCENT, tsz)
	y += 14.0 if tsz == 16 else 10.0
	var kind := str(n["kind"])
	var kind_name: String = {"origin": "Start", "stat": "Stat", "passive": "Passive", "active": "Active skill", "ult": "Ultimate", "root": "Devil Fruit"}.get(kind, kind)
	_text(Vector2(x0 + 8, y), "%s  -  %s" % [n["region"], kind_name], region_col)
	y += 12.0
	var desc := str(n["desc"])
	var sk := str(n["skill"])
	if sk != "":
		var sd := Skills.get_skill(sk)
		desc = str(sd["desc"])
		y += 2.0
		var line := "Cooldown %ss" % str(snappedf(float(sd["cooldown"]), 0.1))
		if not Skills.is_ult(sk):
			line = "%d energy   %s" % [int(sd["cost"]), line]
		if str(sd.get("needs", "")) != "":
			line += "   needs %s" % ("a sword" if sd["needs"] == "sword" else "a pistol")
		_text(Vector2(x0 + 8, y), line, Color(0.6, 0.8, 1.0))
		y += 12.0
	y = _wrap(x0 + 8, y, desc, PANEL_W - 16, UIStyle.TEXT) + 8.0
	var why := pr.can_learn(id)
	var cost := int(n["cost"])
	if pr.owns(id):
		_text(Vector2(x0 + 8, y), "LEARNED", Color(0.6, 0.95, 0.5))
		y += 12.0
		if sk != "":
			var slot := pl.power.loadout.find(sk)
			if slot >= 0:
				_text(Vector2(x0 + 8, y), "On the bar: %s" % ("R" if slot == 4 else str(slot + 1)), UIStyle.TEXT_DIM)
			else:
				_text(Vector2(x0 + 8, y), "Press %s to put it on the bar" % ("R" if Skills.is_ult(sk) else "1-4"), Color(0.75, 0.95, 0.55))
	else:
		_text(Vector2(x0 + 8, y), "Cost: %d skill point%s" % [cost, "" if cost == 1 else "s"], UIStyle.TEXT)
		y += 12.0
		if why == "":
			_text(Vector2(x0 + 8, y), "Click again / Enter to learn", Color(0.75, 0.95, 0.55, 0.7 + 0.3 * sin(_t * 5.0)))
		else:
			_wrap(x0 + 8, y, why, PANEL_W - 16, Color(1.0, 0.55, 0.45))


func _wrap(x: float, y: float, text: String, w: float, col: Color) -> float:
	var words := text.split(" ")
	var line := ""
	for wd in words:
		var trial := wd if line == "" else line + " " + wd
		if FONT.get_string_size(trial, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x > w and line != "":
			_text(Vector2(x, y), line, col)
			y += 10.0
			line = wd
		else:
			line = trial
	if line != "":
		_text(Vector2(x, y), line, col)
		y += 10.0
	return y


func _draw_bar(pl: Player) -> void:
	var y := size.y - 34.0
	draw_rect(Rect2(0, y, size.x - PANEL_W, 34), Color(0, 0, 0, 0.6))
	_text(Vector2(6, y + 18), "SKILL BAR", UIStyle.TEXT_DIM)
	for i in range(5):
		var r := _bar_slot_rect(i)
		draw_rect(r, Color(0.02, 0.02, 0.04, 0.95))
		var sk := pl.power.loadout[i]
		if sk != "" and _icons.get(sk):
			draw_texture_rect(_icons[sk], r.grow(-1.0), false)
		var sel_sk := str(SkillTree.get_node_def(_sel).get("skill", ""))
		var hl := sk != "" and sk == sel_sk
		draw_rect(r, UIStyle.ACCENT if hl else UIStyle.BORDER_DIM, false, 2.0 if hl else 1.0)
		_text(r.position + Vector2(2, 8), "R" if i == 4 else str(i + 1), UIStyle.ACCENT)
	_text(Vector2(_bar_slot_rect(4).end.x + 8, y + 18), "select a skill, press 1-4 / R   right-click a slot to clear", UIStyle.TEXT_DIM)
