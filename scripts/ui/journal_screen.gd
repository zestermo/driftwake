extends Control
## The crew journal (J, Journal.screen): tabs Active / Done / Rumours. Active and Done list the quests on
## the left (the story first while it's on) and the picked one on the right: who gave it and where, its steps
## (done, now, still to come), the reward, and Track (the objective HUD follows it). Rumours lists what the
## crew has heard. Keys: A/D tabs, W/S pick, T track, J or Esc close; the mouse works too.

const TABS := ["active", "done", "rumours"]
const NAMES := {"active": "ACTIVE", "done": "DONE", "rumours": "RUMOURS"}
const LIST_W := 196
const INFO_W := 300
const BODY_H := 222
const SMALL := preload("res://assets/fonts/Silkscreen-Regular.woff2")
const BOLD := preload("res://assets/fonts/PixelifySans-SemiBold.woff2")

var tab := "active"
## The rows on show: {"id": quest id or "story"} (or a rumour) each.
var rows: Array = []
var sel := 0
var _journal: Node
var _panel: PanelContainer
var _tabs: HBoxContainer
var _list: VBoxContainer
var _scroll: ScrollContainer
var _info: VBoxContainer
var _info_box: Control
var _track: Button


func _init(journal: Node) -> void:
	_journal = journal
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", UIStyle.panel(UIStyle.BG, UIStyle.BORDER, 8))
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(_panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	_panel.add_child(vb)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 4)
	vb.add_child(head)
	var t := UIStyle.title("Crew Journal")
	t.add_theme_font_size_override("font_size", 18)
	head.add_child(t)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(gap)
	_tabs = HBoxContainer.new()
	_tabs.add_theme_constant_override("separation", 3)
	_tabs.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_tabs)
	for k in TABS:
		var b := UIStyle.button(NAMES[k], 64)
		b.name = k
		b.add_theme_font_override("font", SMALL)
		b.add_theme_font_size_override("font_size", 8)
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(func(): show_tab(k))
		_tabs.add_child(b)
	vb.add_child(InventoryScreen._rule())
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 8)
	vb.add_child(body)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.custom_minimum_size = Vector2(LIST_W, BODY_H)
	body.add_child(_scroll)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 2)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_list)
	_info_box = VBoxContainer.new()
	_info_box.custom_minimum_size = Vector2(INFO_W, BODY_H)
	body.add_child(_info_box)
	_info = VBoxContainer.new()
	_info.add_theme_constant_override("separation", 3)
	_info.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_info_box.add_child(_info)
	_track = UIStyle.button("Track", 90)
	_track.size_flags_horizontal = Control.SIZE_SHRINK_END
	_track.focus_mode = Control.FOCUS_NONE
	_track.pressed.connect(_toggle_track)
	_info_box.add_child(_track)
	vb.add_child(InventoryScreen._rule())
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 10)
	vb.add_child(foot)
	for h in [["J", "CLOSE"], ["A D", "TAB"], ["W S", "PICK"], ["T", "TRACK"]]:
		foot.add_child(UIStyle.key_hint(h[0], h[1]))
	journal.changed.connect(func():
		if is_visible_in_tree():
			refresh())


func on_open() -> void:
	show_tab(tab)
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


func pick(i: int) -> void:
	if rows.is_empty():
		return
	var n := clampi(i, 0, rows.size() - 1)
	if n != sel:
		UIStyle.sfx("move")
	sel = n
	refresh()


func _rows() -> Array:
	match tab:
		"active":
			var out: Array = [{"id": "story"}] if Story.active() else []
			return out + _journal.active().map(func(e): return {"id": e["id"]})
		"done":
			return _journal.done().map(func(e): return {"id": e["id"]})
	var rs: Array = _journal.rumours.duplicate()
	rs.reverse()
	return rs


func refresh() -> void:
	rows = _rows()
	sel = clampi(sel, 0, maxi(rows.size() - 1, 0))
	for b in _tabs.get_children():
		var n: int = _count(str(b.name))
		(b as Button).text = NAMES[str(b.name)] + ("  %d" % n if n > 0 else "")
		(b as Button).button_pressed = str(b.name) == tab
		b.add_theme_stylebox_override("normal", UIStyle.frame(UIStyle.SUN if str(b.name) == tab else UIStyle.BG_LIGHT, UIStyle.BORDER_DIM, 5, "plank"))
		b.add_theme_color_override("font_color", UIStyle.INK if str(b.name) == tab else UIStyle.TEXT)
	InventoryScreen._clear(_list)
	InventoryScreen._clear(_info)
	_scroll.custom_minimum_size.x = LIST_W if tab != "rumours" else LIST_W + INFO_W + 8
	_info_box.visible = tab != "rumours"
	if rows.is_empty():
		var l := InventoryScreen._text({"active": "No quests yet. Talk to people, read the notice boards, and keep your eyes open.",
			"done": "Nothing finished yet.", "rumours": "No rumours yet. Ask around."}[tab], UIStyle.TEXT_DIM)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(_scroll.custom_minimum_size.x - 8, 0)
		_list.add_child(l)
		_track.visible = false
		return
	for i in range(rows.size()):
		_list.add_child(_row(i))
	if tab != "rumours":
		_fill_info(rows[sel])


func _count(k: String) -> int:
	match k:
		"active":
			return _journal.active().size() + (1 if Story.active() else 0)
		"done":
			return _journal.done().size()
	return _journal.rumours.size()


func _row(i: int) -> Control:
	var r: Dictionary = rows[i]
	var on := i == sel
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", UIStyle.framed(UIStyle.BG_LIGHT if on else UIStyle.BG_DARK, UIStyle.SUN if on else UIStyle.BORDER_DIM, "chip", 4, 2))
	pc.mouse_filter = Control.MOUSE_FILTER_STOP
	pc.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			pick(i))
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", -2)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pc.add_child(vb)
	var w: float = _scroll.custom_minimum_size.x - 18
	if tab == "rumours":
		var l := InventoryScreen._text(str(r["text"]), UIStyle.TEXT)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(w, 0)
		vb.add_child(l)
		vb.add_child(_small("%s, %s" % [r["who"], r["isle"]], UIStyle.TEXT_DIM))
		return pc
	var id: String = r["id"]
	var tracked: bool = _journal.tracked == id
	var title := ("Your story" if id == "story" else str(_journal.entries[id]["title"]))
	var l := InventoryScreen._text(("> " if tracked else "") + title, UIStyle.ACCENT if tracked else UIStyle.TEXT, BOLD)
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.custom_minimum_size = Vector2(w, 0)
	l.clip_text = true
	vb.add_child(l)
	vb.add_child(_small("Brinehollow and beyond" if id == "story" else str(_journal.entries[id]["isle"]), UIStyle.TEXT_DIM))
	return pc


func _small(text: String, col: Color) -> Label:
	var l := InventoryScreen.small(text, col)
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.clip_text = true
	return l


func _fill_info(r: Dictionary) -> void:
	var id: String = r["id"]
	_track.visible = tab == "active"
	_track.text = "Tracking" if _journal.tracked == id else "Track"
	if id == "story":
		_line(_title("Your story"))
		_line(_wrap("The tale that began on Brinehollow's beach.", UIStyle.TEXT_DIM))
		_line(InventoryScreen._rule())
		_step(Story.goal(), "now")
		return
	var e: Dictionary = _journal.entries[id]
	_line(_title(str(e["title"])))
	var how: String = {"board": "From a notice posted by %s, on %s", "found": "Found on %s, for %s"}.get(str(e["src"]), "From %s, on %s")
	_line(_wrap(how % ([e["isle"], e["giver"]] if e["src"] == "found" else [e["giver"], e["isle"]]), UIStyle.TEXT_DIM))
	_line(InventoryScreen._rule())
	var goals: Array = e["goals"]
	for i in range(goals.size()):
		var state := "done" if e["done"] or i < int(e["step"]) else ("now" if i == int(e["step"]) else "later")
		_step(_journal.goal(id) if state == "now" else str(goals[i]), state)
	_line(InventoryScreen._rule())
	_line(_small("REWARD", UIStyle.BORDER))
	_line(_wrap(QuestRewards.text(e["reward"]), UIStyle.GOOD))
	if _journal.favour_owed(id):
		_line(_wrap("%s still owes the crew that favour." % e["reward"]["favour"]["who"], UIStyle.TEXT_DIM))


func _line(c: Control) -> void:
	_info.add_child(c)


func _title(text: String) -> Label:
	var l := InventoryScreen._text(text, UIStyle.ACCENT, BOLD)
	l.add_theme_font_size_override("font_size", 16)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(INFO_W, 0)
	return l


func _wrap(text: String, col: Color) -> Label:
	var l := InventoryScreen._text(text, col)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(INFO_W, 0)
	return l


## A step: ticked (done), marked (now) or dim (still to come).
func _step(text: String, state: String) -> void:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 4)
	var mark := InventoryScreen.small({"done": "[X]", "now": "[>]", "later": "[ ]"}[state], {"done": UIStyle.GOOD, "now": UIStyle.ACCENT, "later": UIStyle.TEXT_DISABLED}[state])
	mark.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	hb.add_child(mark)
	var l := InventoryScreen._text(text, {"done": UIStyle.TEXT_DIM, "now": UIStyle.TEXT, "later": UIStyle.TEXT_DISABLED}[state])
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(INFO_W - 24, 0)
	hb.add_child(l)
	_info.add_child(hb)


func _toggle_track() -> void:
	if tab != "active" or rows.is_empty():
		return
	var id: String = rows[sel]["id"]
	_journal.track("" if _journal.tracked == id else id)
	UIStyle.sfx("confirm")
