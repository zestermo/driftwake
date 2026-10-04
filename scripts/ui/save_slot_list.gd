class_name SaveSlotList
extends PanelContainer
## The three save slots as a list (title screen New Game / Load, pause menu
## Load). Each row shows the captain's name, level, Devil Fruit, play time
## and when it was saved; occupied slots have a Delete button. Overwriting,
## deleting and (from the pause menu) loading ask for confirmation first.

signal chosen(slot: int)
signal cancelled

## "load": pick a saved slot. "new": pick a slot for a new game.
var mode: String = "load"
## Loading from inside a game: warn that unsaved progress is lost.
var warn_unsaved: bool = false
var _title: Label
var _body: VBoxContainer
var _blip: AudioStreamPlayer


func _init() -> void:
	custom_minimum_size = Vector2(360, 0)
	set_anchors_preset(Control.PRESET_CENTER)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	add_theme_stylebox_override("panel", UIStyle.box(UIStyle.BG, UIStyle.BORDER, 10, 2))
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	add_child(vb)
	_title = UIStyle.title("Load Game")
	vb.add_child(_title)
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 4)
	vb.add_child(_body)
	_blip = AudioStreamPlayer.new()
	_blip.stream = load("res://assets/audio/select.wav")
	_blip.bus = "UI"
	_blip.volume_db = -8.0
	add_child(_blip)


func open(mode_: String, warn: bool = false) -> void:
	mode = mode_
	warn_unsaved = warn
	_title.text = "New Game" if mode == "new" else "Load Game"
	refresh()


func _clear() -> void:
	for c in _body.get_children():
		_body.remove_child(c)
		c.queue_free()


func refresh() -> void:
	_clear()
	var hint := "Choose a slot for your new captain" if mode == "new" else "Choose a save to load"
	var hl := UIStyle.label(hint, 12, UIStyle.TEXT_DIM)
	hl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_body.add_child(hl)
	var first: Button = null
	for i in range(1, SaveGame.SLOTS + 1):
		var info := SaveGame.slot_info(i)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		_body.add_child(row)
		var b := UIStyle.button(slot_text(i, info), 280)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_size_override("font_size", 12)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(b)
		if info.is_empty() and mode == "load":
			b.disabled = true
		var slot := i
		b.pressed.connect(func(): _pick(slot, info))
		if first == null and not b.disabled:
			first = b
		if not info.is_empty():
			var del := UIStyle.button("Delete", 0)
			del.add_theme_font_size_override("font_size", 12)
			del.pressed.connect(func(): _ask_delete(slot, info))
			row.add_child(del)
	var back := UIStyle.button("Back", 120)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(func():
		_blip.play()
		cancelled.emit())
	_body.add_child(back)
	(first if first else back).call_deferred("grab_focus")


## "Slot 1  Mara  Lv 7\n  Ember Fruit  -  1h 05m  -  Oct 4, 14:20"
static func slot_text(i: int, info: Dictionary) -> String:
	if info.is_empty():
		return "Slot %d      - empty -" % i
	var fr := str(info["fruit"])
	var fruit_name := "No Devil Fruit" if fr == "" else str(DevilFruits.get_fruit(fr).get("name", fr))
	return "Slot %d   %s   Lv %d\n%s  -  %s  -  %s" % [i, str(info["name"]), int(info["level"]),
		fruit_name, SaveGame.format_time(float(info["play_time"])), when(int(info["saved_at"]))]


static func when(unix: int) -> String:
	if unix <= 0:
		return "?"
	var bias := int(Time.get_time_zone_from_system().get("bias", 0)) * 60
	var d := Time.get_datetime_dict_from_unix_time(unix + bias)
	var months := ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
	return "%s %d, %02d:%02d" % [months[int(d["month"]) - 1], int(d["day"]), int(d["hour"]), int(d["minute"])]


func _pick(slot: int, info: Dictionary) -> void:
	_blip.play()
	if mode == "new" and not info.is_empty():
		_confirm("Overwrite slot %d (%s, Lv %d)?\nThat save will be gone for good." % [slot, info["name"], info["level"]],
			"Overwrite", func(): chosen.emit(slot))
	elif mode == "load" and warn_unsaved:
		_confirm("Load slot %d (%s, Lv %d)?\nAnything since your last save is lost." % [slot, info["name"], info["level"]],
			"Load", func(): chosen.emit(slot))
	else:
		chosen.emit(slot)


func _ask_delete(slot: int, info: Dictionary) -> void:
	_blip.play()
	_confirm("Delete slot %d (%s, Lv %d)?\nThis can't be undone." % [slot, info["name"], info["level"]],
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
	yes.pressed.connect(func():
		_blip.play()
		on_yes.call())
	row.add_child(yes)
	var no := UIStyle.button("Cancel", 110)
	no.pressed.connect(func():
		_blip.play()
		refresh())
	row.add_child(no)
	no.call_deferred("grab_focus")
