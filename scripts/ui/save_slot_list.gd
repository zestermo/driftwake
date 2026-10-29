class_name SaveSlotList
extends PanelContainer
## Your saves as a scrolling list (1.26: as many as you like; title screen Load / Host / Join, pause menu Load), newest
## first. Each row: the screen when it was saved, the captain's name and level, their Driftfruit, play time and when,
## where they were (an island, or at sea near one), the captains they've sailed with, and the build it was saved in
## with a mark for whether this build can load it. A "+ New captain" row starts a fresh save (a new number: nothing is
## ever overwritten). Deleting and (from the pause menu) loading ask first.

signal chosen(slot: int)
signal cancelled

## "load": pick a save (or a new captain: `mode` turns "new" for that pick). "new": the same list, the new row first.
var mode: String = "load"
## Loading from inside a game: warn that unsaved progress is lost.
var warn_unsaved: bool = false
## The new-captain row (off for the pause menu's Load).
var allow_new: bool = true
var _title: Label
var _body: VBoxContainer
var _list: VBoxContainer
var _scroll: ScrollContainer
const ROW_W := 520.0
const THUMB := Vector2(128, 72)


func _init() -> void:
	custom_minimum_size = Vector2(ROW_W + 40.0, 0)
	set_anchors_preset(Control.PRESET_CENTER)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	add_theme_stylebox_override("panel", UIStyle.panel())
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	add_child(vb)
	_title = UIStyle.title("Load Game")
	vb.add_child(_title)
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 4)
	vb.add_child(_body)


func open(mode_: String, warn: bool = false) -> void:
	mode = mode_
	warn_unsaved = warn
	_title.text = "Choose a Captain" if mode == "new" else "Load Game"
	refresh()


func _clear() -> void:
	for c in _body.get_children():
		_body.remove_child(c)
		c.queue_free()


func refresh() -> void:
	_clear()
	_scroll = ScrollContainer.new()
	_scroll.custom_minimum_size = Vector2(ROW_W + 16.0, 300)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_body.add_child(_scroll)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 4)
	_list.custom_minimum_size = Vector2(ROW_W, 0)
	_scroll.add_child(_list)
	var first: Button = null
	if allow_new:
		var nb := UIStyle.button("+  New captain", ROW_W)
		nb.add_theme_font_size_override("font_size", 12)
		nb.pressed.connect(func():
			mode = "new"
			chosen.emit(SaveGame.first_free_slot()))
		_list.add_child(nb)
		first = nb
	var saves := SaveGame.slots()
	if saves.is_empty() and not allow_new:
		_list.add_child(UIStyle.label("No saves yet", 12, UIStyle.TEXT_DIM))
	for i in saves:
		var info := SaveGame.slot_info(int(i))
		if info.is_empty():
			continue
		var b := _row(int(i), info)
		if first == null or (mode == "load" and first.text.begins_with("+")):
			first = b
	var back := UIStyle.button("Back", 120)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(func(): cancelled.emit())
	_body.add_child(back)
	(first if first else back).call_deferred("grab_focus")


## One save as a row: a button over the whole of it (load / pick), the picture on the left, the lines beside, Delete.
func _row(slot: int, info: Dictionary) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(ROW_W, THUMB.y + 10.0)
	b.focus_mode = Control.FOCUS_ALL
	_list.add_child(b)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 8)
	hb.set_anchors_preset(Control.PRESET_FULL_RECT)
	hb.offset_left = 5
	hb.offset_top = 5
	hb.offset_right = -5
	hb.offset_bottom = -5
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(hb)
	var pic := TextureRect.new()
	pic.custom_minimum_size = THUMB
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shot := str(info.get("shot", ""))
	if shot != "":
		var img := Image.load_from_file(ProjectSettings.globalize_path(shot))
		if img:
			pic.texture = ImageTexture.create_from_image(img)
	hb.add_child(pic)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 0)
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(vb)
	for l in lines(info):
		var lab := UIStyle.label(str(l[0]), int(l[1]), l[2])
		lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lab.clip_text = true
		vb.add_child(lab)
	var del := UIStyle.danger(UIStyle.button("Delete", 0))
	del.add_theme_font_size_override("font_size", 12)
	del.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	del.pressed.connect(func(): _ask_delete(slot, info))
	hb.add_child(del)
	if not bool(info.get("compatible", true)):
		b.disabled = true
	b.pressed.connect(func(): _pick(slot, info))
	return b


## The row's lines: [text, size, colour].
static func lines(info: Dictionary) -> Array:
	var fr := str(info["fruit"])
	var fruit_name := "No Driftfruit" if fr == "" else str(DevilFruits.get_fruit(fr).get("name", fr))
	var out: Array = [["%s   Lv %d" % [str(info["name"]), int(info["level"])], 16, UIStyle.TEXT]]
	out.append(["%s  ·  %s played  ·  saved %s" % [fruit_name, SaveGame.format_time(float(info["play_time"])), when(int(info["saved_at"]))], 12, UIStyle.TEXT_DIM])
	var place := str(info.get("place", ""))
	out.append([place if place != "" else "Somewhere on the First Sea", 12, UIStyle.ACCENT])
	var crew: Array = info.get("crew", [])
	out.append(["Sailed with " + ", ".join(crew) if not crew.is_empty() else "Sailed alone", 12, UIStyle.TEXT_DIM])
	var ver := str(info.get("game_version", ""))
	var ok := bool(info.get("compatible", true))
	out.append([("%s  v%s" % ["✓" if ok else "⚠", ver] if ver != "" else ("✓  an older build" if ok else "⚠")) + ("" if ok else "  ·  made in a newer build: update to load it"), 12,
		Color(0.55, 0.85, 0.5) if ok else UIStyle.CORAL])
	return out


## "Slot 1  Mara  Lv 7 ..." (one line: menus and tests that still ask for a slot's text).
static func slot_text(i: int, info: Dictionary) -> String:
	if info.is_empty():
		return "Save %d      - empty -" % i
	var ls := lines(info)
	return "%s\n%s" % [ls[0][0], ls[1][0]]


static func when(unix: int) -> String:
	if unix <= 0:
		return "?"
	var bias := int(Time.get_time_zone_from_system().get("bias", 0)) * 60
	var d := Time.get_datetime_dict_from_unix_time(unix + bias)
	var months := ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
	return "%s %d, %02d:%02d" % [months[int(d["month"]) - 1], int(d["day"]), int(d["hour"]), int(d["minute"])]


func _pick(slot: int, info: Dictionary) -> void:
	mode = "load"
	if warn_unsaved:
		_confirm("Load %s (Lv %d)?\nAnything since your last save is lost." % [info["name"], info["level"]],
			"Load", func(): chosen.emit(slot))
	else:
		chosen.emit(slot)


func _ask_delete(slot: int, info: Dictionary) -> void:
	_confirm("Delete %s (Lv %d)?\nThis can't be undone." % [info["name"], info["level"]],
		"Delete", func():
			SaveGame.delete_slot(slot)
			refresh())


func _confirm(question: String, yes_text: String, on_yes: Callable) -> void:
	_clear()
	var q := UIStyle.label(question, 16)
	q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_body.add_child(q)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	_body.add_child(row)
	var yes := UIStyle.button(yes_text, 110)
	if yes_text != "Load":
		UIStyle.danger(yes)
	yes.pressed.connect(func(): on_yes.call())
	row.add_child(yes)
	var no := UIStyle.button("Cancel", 110)
	no.pressed.connect(func(): refresh())
	row.add_child(no)
	no.call_deferred("grab_focus")
