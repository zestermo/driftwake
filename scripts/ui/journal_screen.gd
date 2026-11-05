extends Control
## The Captain's Log (J, Journal.screen; 1.30 guidance, Zach's approved mock): everything that's next, in one place.
## Tabs NEXT / QUESTS / NEWS / DONE.
##   NEXT: what you follow, big ("NOW - THE CREW FOLLOWS", a chip for each captain, lit for those following it), the
##   leads on this island numbered under it, the chain's next step (always on, dashed), a map with the same numbers
##   (gold = followed, dashed = the chain, red = you) and the news you might have missed. W/S pick a lead, T follows it.
##   QUESTS: every live quest (the story first while it's on) with its owner chip (YOURS / <CAPTAIN>'S / SHARED), the
##   picked one's steps, reward and who follows it; T follows, X drops (twice). NEWS: everything that happened, newest
##   first, then the rumours heard. DONE: finished quests.
## Keys: A/D tabs, W/S pick, T follow, X drop, J or Esc close; the mouse works too. Laid out for the 960x540 canvas.

const TABS := ["next", "quests", "news", "done"]
const NAMES := {"next": "NEXT", "quests": "QUESTS", "news": "NEWS", "done": "DONE"}
const W := 740.0
const H := 420.0
const LEFT_W := 380.0
const LIST_W := 260.0
const BODY_H := 354.0
const MAP_H := 210.0
const SMALL := preload("res://assets/fonts/Silkscreen-Regular.woff2")
const BOLD := preload("res://assets/fonts/PixelifySans-SemiBold.woff2")
const PAPER := Color("e9d9b0")
const PAPER_LAND := Color("c9b688")
## A news kind's mark and colour.
const MARKS := {"quest": ["*", UIStyle.SUN], "chart": ["+", UIStyle.GOOD], "rival": ["!", UIStyle.CORAL], "boss": ["!", UIStyle.CORAL],
	"stronghold": ["!", UIStyle.CORAL], "event": ["*", UIStyle.SUN], "info": ["-", UIStyle.TEAL_LIGHT]}
## How many leads on this island NEXT lists.
const LEADS := 3

var tab := "next"
## The rows on show: NEXT's numbered rows {"n", "id" (quest id, "story", or "" for the chain), "goal", "sub", "pos",
## "kind": "now" / "lead" / "chain"}; QUESTS and DONE {"id"}; NEWS a news entry or a rumour.
var rows: Array = []
var sel := 0
var _journal: Node
var _panel: PanelContainer
var _tabs: HBoxContainer
var _body: Control
var _drop_armed := ""
var _map: Control


func _init(journal: Node) -> void:
	_journal = journal
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", box(UIStyle.OUTLINE, UIStyle.BORDER_DIM, 2, 8))
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.custom_minimum_size = Vector2(W, H)
	_panel.offset_left = -W * 0.5
	_panel.offset_top = -H * 0.5
	_panel.offset_right = W * 0.5
	_panel.offset_bottom = H * 0.5
	add_child(_panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 5)
	_panel.add_child(vb)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 6)
	vb.add_child(head)
	var t := UIStyle.label("CAPTAIN'S LOG", 16, UIStyle.SUN)
	t.add_theme_font_override("font", BOLD)
	head.add_child(t)
	var st := _small("J  -  everything that's next, in one place", UIStyle.TEXT_DIM)
	st.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(st)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(gap)
	_tabs = HBoxContainer.new()
	_tabs.add_theme_constant_override("separation", 3)
	_tabs.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_tabs)
	for k in TABS:
		_tabs.add_child(_tab_button(k))
	# (1.28) the fish journal is its own page (GameMenu "fish_journal")
	var fish := _tab_button("fish")
	fish.text = "FISH"
	fish.pressed.connect(func():
		_journal.close()
		GameMenu.open("fish_journal"))
	head.add_child(fish)
	_body = Control.new()
	_body.custom_minimum_size = Vector2(W - 16.0, BODY_H)
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(_body)
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 10)
	vb.add_child(foot)
	for h in [["J", "CLOSE"], ["A D", "TAB"], ["W S", "PICK"], ["T", "FOLLOW"], ["X", "DROP"]]:
		foot.add_child(UIStyle.key_hint(h[0], h[1]))
	journal.changed.connect(func():
		if _journal.is_open():
			refresh())


## A flat panel: fill, rim (`w` px), padding.
static func box(fill: Color, rim: Color, w: int, pad: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = rim
	sb.set_border_width_all(w)
	sb.content_margin_left = pad
	sb.content_margin_right = pad
	sb.content_margin_top = maxi(pad - 2, 2)
	sb.content_margin_bottom = maxi(pad - 2, 2)
	return sb


func _tab_button(k: String) -> Button:
	var b := Button.new()
	b.name = k
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", SMALL)
	b.add_theme_font_size_override("font_size", 8)
	if k != "fish":
		b.pressed.connect(func(): show_tab(k))
	_style_tab(b, false)
	return b


func _style_tab(b: Button, on: bool) -> void:
	for s in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(s, box(UIStyle.SUN if on else UIStyle.BG_LIGHT, UIStyle.BORDER_DIM if on else UIStyle.DISABLED, 1, 5))
	for s in ["font_color", "font_hover_color", "font_pressed_color"]:
		b.add_theme_color_override(s, UIStyle.INK if on else UIStyle.TEXT)


func on_open() -> void:
	show_tab(tab)
	if tab == "quests":
		var i := rows.find_custom(func(r): return r.get("id", "") == _journal.tracked)
		if i >= 0:
			pick(i)


func show_tab(k: String) -> void:
	if k != tab:
		UIStyle.sfx("select")
	tab = k
	sel = 0
	refresh()


func key(ev: InputEventKey) -> void:
	match ev.keycode:
		KEY_A, KEY_LEFT, KEY_Q:
			show_tab(TABS[(TABS.find(tab) + TABS.size() - 1) % TABS.size()])
		KEY_D, KEY_RIGHT, KEY_E, KEY_TAB:
			show_tab(TABS[(TABS.find(tab) + 1) % TABS.size()])
		KEY_W, KEY_UP:
			pick(sel - 1)
		KEY_S, KEY_DOWN:
			pick(sel + 1)
		KEY_T, KEY_ENTER, KEY_SPACE, KEY_F:
			_toggle_track()
		KEY_X, KEY_DELETE:
			_drop_quest()


func pick(i: int) -> void:
	if rows.is_empty():
		return
	var n := clampi(i, 0, rows.size() - 1)
	if n != sel:
		UIStyle.sfx("move")
		_drop_armed = ""
	sel = n
	refresh()


func refresh() -> void:
	for b in _tabs.get_children():
		var k := str(b.name)
		var n := _count(k)
		(b as Button).text = NAMES[k] + ("  %d" % n if n > 0 else "")
		_style_tab(b, k == tab)
	for c in _body.get_children():
		_body.remove_child(c)
		c.queue_free()
	_map = null
	match tab:
		"next":
			rows = next_rows()
			sel = clampi(sel, 0, maxi(rows.size() - 1, 0))
			_body.add_child(_next_page())
		"quests", "done":
			rows = _quest_rows(tab == "done")
			sel = clampi(sel, 0, maxi(rows.size() - 1, 0))
			_body.add_child(_quest_page())
		"news":
			rows = []
			_body.add_child(_news_page())


func _count(k: String) -> int:
	match k:
		"quests":
			return _journal.active().size() + (1 if Story.active() else 0)
		"news":
			return _journal.pinned().size()
	return 0


# --------------------------------------------------------------------------
# NEXT
# --------------------------------------------------------------------------
## NEXT's numbered rows: 1 what you follow, then the leads on this island, then the chain (unless it's what you follow).
func next_rows() -> Array:
	var out: Array = []
	var f := ChainGoal.followed(get_tree())
	var fid := str(f.get("id", "")) if f.get("kind", "") == "quest" else ("story" if f.get("kind", "") == "story" else "")
	if not f.is_empty():
		out.append({"n": 1, "kind": "now", "id": fid, "goal": f["goal"], "sub": f.get("sub", ""), "pos": _pos_of(f)})
	var isle := _here_isle()
	var leads: Array = _journal.active().filter(func(e): return e["id"] != fid and (isle == "" or e["isle"] == isle))
	for e in leads.slice(0, LEADS):
		out.append({"n": out.size() + 1, "kind": "lead", "id": e["id"], "goal": e["title"], "sub": _journal.goal(e["id"]),
			"pos": _journal.target(e["id"]), "chip": _journal.owner_chip(e)})
	var c := ChainGoal.next(get_tree())
	if fid != "" and not c.is_empty():
		out.append({"n": out.size() + 1, "kind": "chain", "id": "", "goal": c["goal"], "sub": c.get("sub", ""), "pos": c.get("pos", Vector3.INF)})
	return out


func _pos_of(f: Dictionary) -> Vector3:
	if f.get("kind", "") == "story":
		return Story.target_pos()
	return f.get("pos", Vector3.INF)


## The island you're on (its name, as journal entries name it), or "".
func _here_isle() -> String:
	var me := get_tree().get_first_node_in_group("player") as Node3D
	if me == null:
		return ""
	var d := MapIsles.at(get_tree(), Vector2(me.global_position.x, me.global_position.z))
	return str(d.get("name", ""))


func _next_page() -> Control:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 8)
	hb.set_anchors_preset(Control.PRESET_FULL_RECT)
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(LEFT_W, 0)
	left.add_theme_constant_override("separation", 4)
	hb.add_child(left)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 6)
	hb.add_child(right)
	if rows.is_empty():
		left.add_child(_wrap("Nothing to follow yet. Talk to people, read the notice boards, and keep your eyes open.", UIStyle.TEXT_DIM, LEFT_W))
	var leads_head := false
	for i in range(rows.size()):
		var r: Dictionary = rows[i]
		match str(r["kind"]):
			"now":
				left.add_child(_now_card(r, i == sel))
			"lead":
				if not leads_head:
					leads_head = true
					var isle := _here_isle()
					left.add_child(_small("LEADS HERE" + ("  -  " + isle.to_upper() if isle != "" else ""), UIStyle.TEXT_DIM))
				left.add_child(_lead_row(r, i == sel))
			"chain":
				left.add_child(_small("THE CHAIN", UIStyle.TEXT_DIM))
				left.add_child(_lead_row(r, i == sel))
	_map = LogMap.new()
	_map.custom_minimum_size = Vector2(0, MAP_H)
	_map.marks = rows
	right.add_child(_map)
	right.add_child(_missed())
	return hb


func _now_card(r: Dictionary, on: bool) -> Control:
	var pc := _clickable(box(UIStyle.BG_DARK, UIStyle.SUN, 2, 6), 0)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 1)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pc.add_child(vb)
	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(top)
	top.add_child(_small("NOW  -  THE CREW FOLLOWS" if Net.active else "NOW  -  YOU FOLLOW", UIStyle.SUN))
	var g := Control.new()
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(g)
	top.add_child(_chips(str(r["id"])))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(row)
	row.add_child(_badge(1, UIStyle.SUN, 15))
	var title := UIStyle.label(str(r["goal"]), 16, UIStyle.TEXT)
	title.add_theme_font_override("font", BOLD)
	title.add_theme_constant_override("line_spacing", -5)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.custom_minimum_size = Vector2(LEFT_W - 36.0, 0)
	row.add_child(title)
	if str(r["sub"]) != "":
		vb.add_child(_wrap(str(r["sub"]), UIStyle.TEXT_DIM, LEFT_W - 14.0))
	vb.add_child(_small(_owner_line(r), UIStyle.GOOD))
	return pc


## "SHARED  -  everyone's step  -  1.4 KM EAST" / "YOURS  -  ..." / "THE CHAIN  -  ...".
func _owner_line(r: Dictionary) -> String:
	var who := "THE CHAIN  -  everyone's step"
	var id := str(r["id"])
	if id == "story":
		who = "YOUR STORY"
	elif _journal.has(id):
		var e: Dictionary = _journal.entries[id]
		who = _journal.owner_chip(e) + ("  -  everyone's step" if _journal.owner_chip(e) == "SHARED" else "")
		var by: String = _journal.owner_name(e)
		if by != "":
			who += "  -  taken by " + by
	var me := get_tree().get_first_node_in_group("player") as Node3D
	var p: Vector3 = r["pos"]
	if me and p != Vector3.INF:
		var here := Vector2(me.global_position.x, me.global_position.z)
		var d := here.distance_to(Vector2(p.x, p.z))
		if d > 4.0:
			who += "  -  %s %s" % [ObjectiveHud.dist_text(d), ChainGoal.bearing(here, Vector2(p.x, p.z)).to_upper()]
	return who


## A chip per captain (their initial in their crew colour), lit when they follow quest `id`.
func _chips(id: String) -> Control:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 2)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not Net.active:
		return hb
	for p in Net.all_players():
		var pid := int(p.net_id)
		var theirs := str(_journal.follows.get(pid, ""))
		var on: bool = theirs == id or (id in ["", "story"] and not _journal.has(theirs))
		var cr := PanelContainer.new()
		cr.add_theme_stylebox_override("panel", box(Net.crew_color(pid) if on else UIStyle.DISABLED, UIStyle.OUTLINE, 0, 2))
		cr.custom_minimum_size = Vector2(12, 12)
		cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var l := _small(str(p.display_name()).substr(0, 1).to_upper(), UIStyle.OUTLINE if on else UIStyle.TEXT_DISABLED)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cr.add_child(l)
		hb.add_child(cr)
	return hb


func _lead_row(r: Dictionary, on: bool) -> Control:
	var chain: bool = r["kind"] == "chain"
	var pc := _clickable(box(UIStyle.BG, UIStyle.SUN if on else (Color(0, 0, 0, 0) if chain else UIStyle.BG_LIGHT), 0 if chain and not on else 2, 5),
		int(r["n"]) - 1)
	if chain and not on:
		pc.draw.connect(func(): LogMap.dashed_rect(pc, Rect2(Vector2.ZERO, pc.size).grow(-1.0), UIStyle.BORDER_DIM, 2.0))
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 5)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pc.add_child(hb)
	hb.add_child(_badge(int(r["n"]), UIStyle.BORDER_DIM if chain else UIStyle.TEAL_LIGHT, 13))
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", -2)
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(vb)
	var t := InventoryScreen._text(str(r["goal"]), UIStyle.TEXT)
	t.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	t.clip_text = true
	t.custom_minimum_size = Vector2(LEFT_W - 100.0, 0)
	vb.add_child(t)
	var s := _small(str(r["sub"]), UIStyle.TEXT_DIM)
	s.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	s.clip_text = true
	s.custom_minimum_size = Vector2(LEFT_W - 100.0, 0)
	vb.add_child(s)
	hb.add_child(_chip("ALWAYS ON", UIStyle.SUN) if chain else _chip(str(r.get("chip", "")), _chip_col(str(r.get("chip", "")))))
	return pc


func _chip_col(c: String) -> Color:
	return UIStyle.CORAL if c == "YOURS" else (UIStyle.GOOD if c == "SHARED" else UIStyle.TEAL_LIGHT)


func _chip(text: String, col: Color) -> Control:
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", box(Color(0, 0, 0, 0), col, 1, 3))
	pc.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pc.add_child(_small(text, col))
	return pc


func _badge(n: int, col: Color, s: float) -> Control:
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", box(col, col, 0, 0))
	pc.custom_minimum_size = Vector2(s, s)
	pc.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := UIStyle.label(str(n), 12, UIStyle.INK)
	l.add_theme_font_override("font", BOLD)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pc.add_child(l)
	return pc


## The news you might have missed: the newest that mattered (not the small stuff), on NEXT.
func _missed() -> Control:
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", box(UIStyle.BG_DARK, UIStyle.DISABLED, 2, 5))
	pc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 1)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pc.add_child(vb)
	vb.add_child(_small("NEWS YOU MIGHT HAVE MISSED", UIStyle.SUN))
	var big: Array = _journal.news.filter(func(n): return n["kind"] != "info")
	big.reverse()
	if big.is_empty():
		vb.add_child(_small("Nothing yet.", UIStyle.TEXT_DIM))
	for n in big.slice(0, 4):
		vb.add_child(_news_line(n, W - LEFT_W - 50.0, false))
	return pc


func _news_line(n: Dictionary, w: float, full: bool) -> Control:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 4)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m: Array = MARKS.get(n["kind"], MARKS["info"])
	var mk := UIStyle.label(str(m[0]), 12, m[1])
	mk.add_theme_font_override("font", SMALL)
	mk.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	hb.add_child(mk)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", -3)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(vb)
	var t := InventoryScreen._text(str(n["title"]), UIStyle.TEXT)
	t.custom_minimum_size = Vector2(w, 0)
	if full:
		t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	else:
		t.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		t.clip_text = true
	vb.add_child(t)
	var sub := ago(float(n["at"]))
	if full and str(n["text"]) != "":
		sub = str(n["text"]) + "  -  " + sub
	vb.add_child(_small(sub, UIStyle.TEXT_DIM))
	return hb


## "just now", "4 min ago", "2 h ago" (game time played).
func ago(at: float) -> String:
	var s := GameManager.play_time - at
	if s < 60.0:
		return "just now"
	if s < 3600.0:
		return "%d min ago" % int(s / 60.0)
	return "%d h ago" % int(s / 3600.0)


# --------------------------------------------------------------------------
# QUESTS and DONE
# --------------------------------------------------------------------------
func _quest_rows(finished: bool) -> Array:
	if finished:
		return _journal.done().map(func(e): return {"id": e["id"]})
	var out: Array = [{"id": "story"}] if Story.active() else []
	return out + _journal.active().map(func(e): return {"id": e["id"]})


func _quest_page() -> Control:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 8)
	hb.set_anchors_preset(Control.PRESET_FULL_RECT)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(LIST_W, BODY_H)
	hb.add_child(scroll)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 2)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 3)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(info)
	if rows.is_empty():
		list.add_child(_wrap("No quests yet. Talk to people, read the notice boards, and keep your eyes open." if tab == "quests" else "Nothing finished yet.",
			UIStyle.TEXT_DIM, LIST_W - 8.0))
		return hb
	for i in range(rows.size()):
		list.add_child(_quest_row(i))
	_fill_info(info, str(rows[sel]["id"]))
	return hb


func _quest_row(i: int) -> Control:
	var id := str(rows[i]["id"])
	var on := i == sel
	var pc := _clickable(box(UIStyle.BG_LIGHT if on else UIStyle.BG_DARK, UIStyle.SUN if on else UIStyle.DISABLED, 1, 4), i)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 3)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pc.add_child(hb)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", -2)
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(vb)
	var followed: bool = _journal.tracked == id or (id == "story" and not _journal.has(_journal.tracked))
	var title := "Your story" if id == "story" else str(_journal.entries[id]["title"])
	var l := InventoryScreen._text(("> " if followed and tab == "quests" else "") + title, UIStyle.ACCENT if followed and tab == "quests" else UIStyle.TEXT, BOLD)
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.clip_text = true
	l.custom_minimum_size = Vector2(LIST_W - 80.0, 0)
	vb.add_child(l)
	vb.add_child(_small("Brinehollow and beyond" if id == "story" else str(_journal.entries[id]["isle"]), UIStyle.TEXT_DIM))
	if id != "story":
		var c: String = _journal.owner_chip(_journal.entries[id])
		hb.add_child(_chip(c, _chip_col(c)))
	return pc


func _fill_info(info: VBoxContainer, id: String) -> void:
	var iw := W - LIST_W - 30.0
	if id == "story":
		info.add_child(_title("Your story", iw))
		info.add_child(_wrap("The tale that began on Brinehollow's beach.", UIStyle.TEXT_DIM, iw))
		info.add_child(InventoryScreen._rule())
		info.add_child(_step(Story.goal(), "now", iw))
		info.add_child(_buttons(id))
		return
	var e: Dictionary = _journal.entries[id]
	info.add_child(_title(str(e["title"]), iw))
	var how: String = {"board": "From a notice posted by %s, on %s", "found": "Found on %s, for %s", "line": "%s  -  %s"}.get(str(e["src"]), "From %s, on %s")
	info.add_child(_wrap(how % ([e["isle"], e["giver"]] if e["src"] == "found" else [e["giver"], e["isle"]]), UIStyle.TEXT_DIM, iw))
	info.add_child(_small(_who_line(e), _chip_col(_journal.owner_chip(e))))
	info.add_child(InventoryScreen._rule())
	var goals: Array = e["goals"]
	for i in range(goals.size()):
		var state := "done" if e["done"] or i < int(e["step"]) else ("now" if i == int(e["step"]) else "later")
		info.add_child(_step(_journal.goal(id) if state == "now" else str(goals[i]), state, iw))
	info.add_child(InventoryScreen._rule())
	info.add_child(_small("REWARD", UIStyle.BORDER))
	info.add_child(_wrap(QuestRewards.text(e["reward"]), UIStyle.GOOD, iw))
	if _journal.favour_owed(id):
		info.add_child(_wrap("%s still owes the crew that favour." % e["reward"]["favour"]["who"], UIStyle.TEXT_DIM, iw))
	if tab == "quests":
		info.add_child(_buttons(id))


## "YOURS  -  followed by Zilk, Yeastyy": the owner chip's words and who follows it.
func _who_line(e: Dictionary) -> String:
	var line: String = _journal.owner_chip(e)
	var by: String = _journal.owner_name(e)
	if by != "":
		line = "TAKEN BY " + by.to_upper()
	if Net.active:
		var names: Array = []
		for p in Net.all_players():
			if str(_journal.follows.get(int(p.net_id), "")) == str(e["id"]):
				names.append(str(p.display_name()))
		if not names.is_empty():
			line += "  -  followed by " + ", ".join(names)
	return line


func _buttons(id: String) -> Control:
	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_END
	hb.add_theme_constant_override("separation", 4)
	var follow := UIStyle.button("Following" if _journal.tracked == id else "Follow", 90)
	follow.focus_mode = Control.FOCUS_NONE
	follow.pressed.connect(_toggle_track)
	hb.add_child(follow)
	if id != "story" and str(_journal.entries[id]["src"]) != "line":
		var drop := UIStyle.button("Sure?" if _drop_armed == id else "Drop", 70)
		drop.focus_mode = Control.FOCUS_NONE
		drop.pressed.connect(_drop_quest)
		hb.add_child(drop)
	return hb


func _title(text: String, w: float) -> Label:
	var l := InventoryScreen._text(text, UIStyle.ACCENT, BOLD)
	l.add_theme_font_size_override("font_size", 16)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(w, 0)
	return l


## A step: ticked (done), marked (now) or dim (still to come).
func _step(text: String, state: String, w: float) -> Control:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 4)
	var mark := InventoryScreen.small({"done": "[X]", "now": "[>]", "later": "[ ]"}[state], {"done": UIStyle.GOOD, "now": UIStyle.ACCENT, "later": UIStyle.TEXT_DISABLED}[state])
	mark.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	hb.add_child(mark)
	var l := InventoryScreen._text(text, {"done": UIStyle.TEXT_DIM, "now": UIStyle.TEXT, "later": UIStyle.TEXT_DISABLED}[state])
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(w - 24.0, 0)
	hb.add_child(l)
	return hb


# --------------------------------------------------------------------------
# NEWS
# --------------------------------------------------------------------------
func _news_page() -> Control:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 3)
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vb)
	var all: Array = _journal.news.duplicate()
	all.reverse()
	if all.is_empty():
		vb.add_child(_small("No news yet.", UIStyle.TEXT_DIM))
	for n in all:
		vb.add_child(_news_line(n, W - 60.0, true))
	if not _journal.rumours.is_empty():
		vb.add_child(InventoryScreen._rule())
		vb.add_child(_small("RUMOURS HEARD", UIStyle.SUN))
		var rs: Array = _journal.rumours.duplicate()
		rs.reverse()
		for r in rs:
			vb.add_child(_wrap(str(r["text"]), UIStyle.TEXT, W - 40.0))
			vb.add_child(_small("%s, %s" % [r["who"], r["isle"]], UIStyle.TEXT_DIM))
	return scroll


# --------------------------------------------------------------------------
# Bits
# --------------------------------------------------------------------------
## A panel that picks row `i` when clicked.
func _clickable(sb: StyleBox, i: int) -> PanelContainer:
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", sb)
	pc.mouse_filter = Control.MOUSE_FILTER_STOP
	pc.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			# (deferred: picking rebuilds the page, and this row mustn't be freed inside its own click)
			pick.call_deferred(i))
	return pc


func _small(text: String, col: Color) -> Label:
	var l := InventoryScreen.small(text, col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _wrap(text: String, col: Color, w: float) -> Label:
	var l := InventoryScreen._text(text, col)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(w, 0)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _toggle_track() -> void:
	if rows.is_empty() or tab in ["news", "done"]:
		return
	var id := str(rows[sel]["id"])
	# (the chain or the story: follow nothing, and the box shows the chain's step)
	_journal.track("" if _journal.tracked == id or id in ["", "story"] else id)
	UIStyle.sfx("confirm")


## Drop the picked quest: the first press asks, the second drops it (the story and the chain can't be dropped).
func _drop_quest() -> void:
	if rows.is_empty() or tab in ["news", "done"]:
		return
	var id := str(rows[sel]["id"])
	if id in ["", "story"] or not _journal.has(id) or str(_journal.entries[id]["src"]) == "line":
		return
	if _drop_armed != id:
		_drop_armed = id
		UIStyle.sfx("select")
		refresh()
		return
	_drop_armed = ""
	_journal.abandon(id)
	UIStyle.sfx("confirm")


## NEXT's map: this island's page (MapIsleView: its land, fog and the crew's marks), or a plain sea chart round you at
## sea, with the rows' numbers on it (gold = followed, teal = a lead, dashed = the chain) and a red arrow for you.
class LogMap extends Control:
	const RED := Color("f17c62")
	const INK := Color("2b1a0c")
	var marks: Array = []
	var view: MapIsleView
	var _font: Font
	var _bold: Font
	var _t := 0.0

	func _ready() -> void:
		clip_contents = true
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_font = load("res://assets/fonts/Silkscreen-Regular.woff2")
		_bold = load("res://assets/fonts/PixelifySans-SemiBold.woff2")
		resized.connect(_fit)
		_fit.call_deferred()

	func _fit() -> void:
		if not is_inside_tree():
			return
		var me := get_tree().get_first_node_in_group("player") as Node3D
		var d := MapIsles.at(get_tree(), Vector2(me.global_position.x, me.global_position.z)) if me else {}
		if d.is_empty() or size.x < 10.0:
			return
		if view == null:
			view = MapIsleView.new()
			add_child(view)
			move_child(view, 0)
		view.show_isle(d, size + Vector2(MapIsleView.SIDE * 2.0 - 8.0, MapIsleView.TOP + MapIsleView.BOTTOM - 14.0))
		view.position = Vector2(-MapIsleView.SIDE + 4.0, -MapIsleView.TOP + 4.0)

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	## World x/z -> this control's px.
	func px(w: Vector2, fit: Array) -> Vector2:
		if view:
			return view.world_to_frame(w) + view.frame.position + view.position
		return size * 0.5 + (w - fit[0]) * float(fit[1])

	func _draw() -> void:
		var me := get_tree().get_first_node_in_group("player") as Node3D
		if view == null:
			draw_rect(Rect2(Vector2.ZERO, size), Color("e9d9b0"))
			for k in range(1, 6):
				draw_line(Vector2(0, size.y * k / 6.0), Vector2(size.x, size.y * k / 6.0), Color(INK, 0.08), 1.0)
				draw_line(Vector2(size.x * k / 6.0, 0), Vector2(size.x * k / 6.0, size.y), Color(INK, 0.08), 1.0)
		var here := Vector2(me.global_position.x, me.global_position.z) if me else Vector2.ZERO
		# (at sea: fitted round you and every mark)
		var r := Rect2(here, Vector2.ZERO)
		for m in marks:
			var p: Vector3 = m["pos"]
			if p != Vector3.INF:
				r = r.expand(Vector2(p.x, p.z))
		var k := minf((size.x - 30.0) / maxf(r.size.x, 1.0), (size.y - 34.0) / maxf(r.size.y, 1.0))
		var fit := [r.get_center(), clampf(k, 0.0005, 2.0)]
		var inner := Rect2(Vector2(9, 9), size - Vector2(18, 24))
		for m in marks:
			var p: Vector3 = m["pos"]
			if p == Vector3.INF:
				continue
			var c := px(Vector2(p.x, p.z), fit)
			c = Vector2(clampf(c.x, inner.position.x, inner.end.x), clampf(c.y, inner.position.y, inner.end.y))
			var kind := str(m["kind"])
			var s := 8.0 if kind == "now" else 7.0
			var col: Color = UIStyle.SUN if kind == "now" else (UIStyle.BORDER_DIM if kind == "chain" else UIStyle.TEAL_LIGHT)
			var rr := Rect2(c - Vector2(s, s), Vector2(s, s) * 2.0)
			draw_rect(rr, col)
			if kind == "chain":
				dashed_rect(self, rr, INK, 1.5)
			else:
				draw_rect(rr, INK, false, 2.0 if kind == "now" else 1.0)
			var t := str(m["n"])
			var tw := _bold.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
			draw_string(_bold, c + Vector2(-tw * 0.5, 4.5), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UIStyle.INK)
		if me:
			var c := px(here, fit)
			var yaw := me.global_rotation.y
			var fwd := Vector2(-sin(yaw), -cos(yaw))
			var side := Vector2(-fwd.y, fwd.x)
			draw_colored_polygon(PackedVector2Array([c + fwd * 7.0, c - fwd * 4.0 + side * 5.0, c - fwd * 4.0 - side * 5.0]), RED)
			draw_polyline(PackedVector2Array([c + fwd * 7.0, c - fwd * 4.0 + side * 5.0, c - fwd * 4.0 - side * 5.0, c + fwd * 7.0]), INK, 1.0)
		draw_rect(Rect2(Vector2.ZERO, size), UIStyle.BORDER_DIM, false, 2.0)
		draw_rect(Rect2(0, size.y - 13.0, size.x, 13.0), Color(Color("e9d9b0"), 0.85))
		draw_string(_font, Vector2(5, size.y - 4.0), "GOLD FOLLOWED - DASHED CHAIN - RED YOU",
			HORIZONTAL_ALIGNMENT_LEFT, size.x - 8.0, 8, INK)

	## A dashed rectangle's outline on `ci`.
	static func dashed_rect(ci: CanvasItem, r: Rect2, col: Color, w: float) -> void:
		var pts := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y), r.position]
		for i in range(4):
			var a: Vector2 = pts[i]
			var b: Vector2 = pts[i + 1]
			var n := maxi(int(a.distance_to(b) / 4.0), 1)
			for k in range(0, n, 2):
				ci.draw_line(a.lerp(b, float(k) / n), a.lerp(b, minf(float(k + 1) / n, 1.0)), col, w)
