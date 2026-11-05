extends Control
## The bookshelf (GameMenu screen "books"; the cabin's BookShelf): this captain's collection, a row of spines per kind
## (BookData.KINDS: read books lit in their cover colour, unread ones dark "???"), the lore sets by volume with their
## rewards, and the picked book's card on the right (what it taught). Books has the reading.

const W_ROWS := 320
const W_CARD := 260
const SPINE := Vector2(14, 40)

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
	var t := UIStyle.title("The Bookshelf")
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
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 2)
	_rows.custom_minimum_size = Vector2(W_ROWS, 0)
	body.add_child(_rows)
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


func _player() -> Player:
	return _menu.call("_player")


func on_open() -> void:
	_refresh()


func _refresh() -> void:
	var pr := _player().progression
	_count.text = "%d OF %d READ" % [Books.count(pr), BookData.BOOKS.size()]
	InventoryScreen._clear(_rows)
	for k in BookData.KINDS:
		if k == "lore":
			continue
		_row(str(BookData.KIND_NAMES[k]).to_upper(), BookData.of_kinds([k]), pr)
	# the lore sets on one row, a gap between sets
	var sets: Array = []
	var ids: Array = []
	for sid in BookData.LORE_SETS.keys():
		var s: Dictionary = BookData.LORE_SETS[sid]
		sets.append("%s %d/%d" % [str(s["name"]).to_upper().trim_prefix("THE ").trim_prefix("A ").get_slice(" ", 0), Books.set_have(pr, sid), (s["books"] as Array).size()])
		if not ids.is_empty():
			ids.append("")
		ids.append_array(s["books"])
	_row("LORE  " + "  ".join(sets), ids, pr)
	_show_card()


func _row(label: String, ids: Array, pr) -> void:
	_rows.add_child(InventoryScreen.small(label, UIStyle.BORDER))
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 2)
	_rows.add_child(hb)
	for id in ids:
		if id == "":
			var gap := Control.new()
			gap.custom_minimum_size = Vector2(8, 0)
			hb.add_child(gap)
			continue
		var read := Books.has_read(pr, id)
		var b := Button.new()
		b.custom_minimum_size = SPINE
		b.focus_mode = Control.FOCUS_ALL
		var sb := StyleBoxFlat.new()
		sb.bg_color = (BookData.COVERS[BookData.kind_of(id)] as Color) if read else Color(0.12, 0.16, 0.17)
		sb.border_color = Color(0.85, 0.68, 0.28) if id == _sel else Color(0.05, 0.08, 0.08)
		sb.set_border_width_all(1)
		for st in ["normal", "hover", "pressed", "focus"]:
			b.add_theme_stylebox_override(st, sb)
		b.tooltip_text = str(BookData.BOOKS[id]["name"]) if read else "???"
		b.pressed.connect(func(): _sel = id; _refresh())
		hb.add_child(b)


func _show_card() -> void:
	InventoryScreen._clear(_card)
	if _sel == "":
		_line("Pick a spine to look at it.", UIStyle.TEXT_DIM)
		return
	var b: Dictionary = BookData.BOOKS[_sel]
	if not Books.has_read(_player().progression, _sel):
		_card.add_child(InventoryScreen._text("A book you haven't read", UIStyle.TEXT_DIM, InventoryScreen.BOLD))
		_line("FIND IT IN CHESTS, LIBRARIES AND BOOKSHOPS", UIStyle.TEXT_DIM)
		return
	var it := ItemDB.get_item(_sel)
	_card.add_child(InventoryScreen._text(it.display_name, it.rarity_color(), InventoryScreen.BOLD))
	_line(str(b["desc"]), UIStyle.TEXT_DIM)
	_card.add_child(InventoryScreen._rule())
	_line(Books.teaches_text(_sel).to_upper(), Color(1.0, 0.85, 0.45))


func _line(text: String, col: Color) -> void:
	var l := InventoryScreen.small(text, col)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(W_CARD, 0)
	_card.add_child(l)


## (tests, renders) pick a book on the shelf.
func pick(id: String) -> void:
	_sel = id
	_refresh()
