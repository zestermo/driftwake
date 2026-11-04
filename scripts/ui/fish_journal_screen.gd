extends Control
## The fish journal (1.28; GameMenu screen "fish_journal": the action wheel's Fish journal, the crew journal's Fish
## button): a row per page (FishTable.PAGES) with its count and reward, each catch's icon once caught (dark "?" until
## then), and the picked catch's card: times caught, the biggest, where it was first caught; an uncaught one gives
## a hint of where and when it bites. Fishing.record keeps the log and pays the pages.

const W_ROWS := 300
const W_CARD := 200
const CELL := Vector2(26, 26)

var _menu: Node
var _count: Label
var _rows: VBoxContainer
var _card: VBoxContainer
var _sel := ""


func _init(menu: Node) -> void:
	_menu = menu
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UIStyle.panel(UIStyle.BG, UIStyle.BORDER, 8))
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	panel.add_child(vb)
	var head := HBoxContainer.new()
	vb.add_child(head)
	var t := UIStyle.title("Fish Journal")
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	head.add_child(t)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(gap)
	_count = InventoryScreen.small("", UIStyle.ACCENT)
	_count.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_count)
	vb.add_child(InventoryScreen._rule())
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 10)
	vb.add_child(body)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(W_ROWS + 10, 380)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	body.add_child(scroll)
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 2)
	_rows.custom_minimum_size = Vector2(W_ROWS, 0)
	scroll.add_child(_rows)
	_card = VBoxContainer.new()
	_card.add_theme_constant_override("separation", 2)
	_card.custom_minimum_size = Vector2(W_CARD, 0)
	body.add_child(_card)
	var foot := HBoxContainer.new()
	vb.add_child(foot)
	var hints := HBoxContainer.new()
	hints.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hints.add_theme_constant_override("separation", 10)
	for p in [["LMB", "LOOK"], ["ESC", "LEAVE"]]:
		hints.add_child(UIStyle.key_hint(p[0], p[1]))
	foot.add_child(hints)
	var leave := UIStyle.button("Leave", 80)
	leave.pressed.connect(func(): _menu.close())
	foot.add_child(leave)


## The action wheel's Fish journal (a method callable, not a lambda: see GalleyScreen.register_wheel).
func register_wheel() -> void:
	ActionWheel.register("fish_journal", "Fish journal", "res://assets/textures/icons/fish_stew.png", _wheel_ok, _wheel_open, 66)


func _wheel_ok(p):
	return ActionWheel.on_foot(p)


func _wheel_open(_p) -> void:
	_menu.open("fish_journal")


func _player() -> Player:
	return _menu.call("_player")


func on_open() -> void:
	_refresh()


func _refresh() -> void:
	var pr := _player().progression
	var total := 0
	var caught := 0
	InventoryScreen._clear(_rows)
	for page in FishTable.PAGES:
		var ids: Array = page[2]
		var have := ids.filter(func(f): return pr.fish_log.has(f)).size()
		total += ids.size()
		caught += have
		var rw: Dictionary = page[3]
		var item := ItemDB.get_item(str(rw["item"][0]))
		var tail := "DONE" if pr.fish_pages.has(page[0]) else "%d GOLD + %s" % [int(rw["gold"]), (item.display_name if item else "").to_upper()]
		_rows.add_child(InventoryScreen.small("%s  %d/%d  -  %s" % [str(page[1]).to_upper(), have, ids.size(), tail],
			UIStyle.GOOD if pr.fish_pages.has(page[0]) else UIStyle.BORDER))
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 2)
		_rows.add_child(hb)
		for id in ids:
			hb.add_child(_cell(id, pr.fish_log.has(id)))
	_count.text = "%d OF %d CAUGHT" % [caught, total]
	_show_card()


func _cell(id: String, got: bool) -> Button:
	var b := Button.new()
	b.custom_minimum_size = CELL
	b.focus_mode = Control.FOCUS_ALL
	b.expand_icon = true
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.14, 0.16) if got else Color(0.06, 0.08, 0.09)
	sb.border_color = Color(0.85, 0.68, 0.28) if id == _sel else (ItemData.RARITY_COLORS[FishTable.rarity_of(id)] as Color).darkened(0.4 if got else 0.75)
	sb.set_border_width_all(1)
	for st in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(st, sb)
	if got:
		b.icon = ItemDB.get_item(id).icon
	else:
		b.text = "?"
		b.add_theme_font_size_override("font_size", 8)
		b.add_theme_color_override("font_color", UIStyle.TEXT_DIM)
	b.tooltip_text = ItemDB.get_item(id).display_name if got else "???"
	b.pressed.connect(func(): pick(id))
	return b


func _show_card() -> void:
	InventoryScreen._clear(_card)
	if _sel == "":
		_line("Pick a fish to look at it.", UIStyle.TEXT_DIM)
		return
	var it := ItemDB.get_item(_sel)
	var c: Array = FishTable.CATCHES[_sel]
	var where := "%s%s%s" % [", ".join(c[3]), " off %s coasts" % str(c[4]) if str(c[4]) != "" else "", ", by %s" % str(c[5]) if str(c[5]) != "" else ""]
	var e: Dictionary = _player().progression.fish_log.get(_sel, {})
	if e.is_empty():
		_card.add_child(InventoryScreen._text("Not caught yet", UIStyle.TEXT_DIM, InventoryScreen.BOLD))
		_line(("%s - bites in %s" % [it.rarity_name(), where]).to_upper(), UIStyle.TEXT_DIM)
		return
	_card.add_child(InventoryScreen._text(it.display_name, it.rarity_color(), InventoryScreen.BOLD))
	_line(it.description, UIStyle.TEXT_DIM)
	_card.add_child(InventoryScreen._rule())
	_line("CAUGHT %d  -  BIGGEST %.2f M" % [int(e["n"]), float(e["best"])], Color(1.0, 0.85, 0.45))
	_line(("FIRST CAUGHT: %s" % str(e["where"])).to_upper(), UIStyle.TEXT)
	_line(("BITES IN %s" % where).to_upper(), UIStyle.TEXT_DIM)


func _line(text: String, col: Color) -> void:
	var l := InventoryScreen.small(text, col)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(W_CARD, 0)
	_card.add_child(l)


## (tests, renders) pick a catch.
func pick(id: String) -> void:
	_sel = id
	_refresh()
