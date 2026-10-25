extends PanelContainer
## The crew (GameMenu screen "crew", the pause menu's Crew; 1.22, docs/v1_22_plan.md): the crew's name and flag, who's
## aboard now (their pings, the Captain's kick), and everyone who's sailed with the crew (last seen, in game days).
## The Captain renames the crew and opens the ship's paint for the flag; a crewmate sees the same without them.

var _menu: Node
var _name: LineEdit
var _rename: Button
var _flag: TextureRect
var _paint: Button
var _captain: Label
var _aboard: VBoxContainer
var _sailed: VBoxContainer


func _init(menu: Node) -> void:
	_menu = menu
	custom_minimum_size = Vector2(420, 0)
	set_anchors_preset(Control.PRESET_CENTER)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	add_theme_stylebox_override("panel", UIStyle.panel(UIStyle.BG, UIStyle.BORDER, 12))
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	add_child(vb)
	vb.add_child(UIStyle.title("Crew"))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	vb.add_child(row)
	# the crew: its flag, its name, the Captain
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(150, 0)
	row.add_child(left)
	_flag = TextureRect.new()
	_flag.custom_minimum_size = Vector2(96, 64)
	_flag.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_flag.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_flag.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	left.add_child(_flag)
	_name = LineEdit.new()
	_name.max_length = 28
	_name.add_theme_font_size_override("font_size", 12)
	left.add_child(_name)
	_captain = UIStyle.label("", 8, UIStyle.TEXT_DIM)
	left.add_child(_captain)
	var btns := HBoxContainer.new()
	left.add_child(btns)
	_rename = UIStyle.button("Rename", 70)
	_rename.pressed.connect(func():
		Net.crew_rename(_name.text)
		refresh())
	btns.add_child(_rename)
	_paint = UIStyle.button("Flag", 60)
	_paint.pressed.connect(func(): _menu.call("open_flag"))
	btns.add_child(_paint)
	# who's aboard, who's sailed with us
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(right)
	right.add_child(UIStyle.label("Aboard now", 8, UIStyle.ACCENT))
	_aboard = VBoxContainer.new()
	right.add_child(_aboard)
	right.add_child(UIStyle.label("Sailed with us", 8, UIStyle.ACCENT))
	_sailed = VBoxContainer.new()
	right.add_child(_sailed)
	var done := UIStyle.button("Done", 64)
	done.size_flags_horizontal = Control.SIZE_SHRINK_END
	done.pressed.connect(func(): _menu.call("open", "pause"))
	vb.add_child(done)
	Net.roster_changed.connect(func():
		if visible:
			refresh())


func on_open() -> void:
	refresh()


## The Captain: the host in co-op, and you on your own.
func is_captain() -> bool:
	return not Net.active or Net.hosting


func refresh() -> void:
	var gm := get_node_or_null("/root/GameManager")
	var cap := is_captain()
	_name.text = Net.crew_name()
	_name.editable = cap
	_rename.visible = cap
	_paint.visible = cap
	_captain.text = "Captain: %s" % (str(Net.roster.get(1, {}).get("name", "")) if Net.active else _local_name())
	if gm:
		_flag.texture = ImageTexture.create_from_image(ShipKit.flag_image(gm.ship_kit))
	for c in _aboard.get_children() + _sailed.get_children():
		c.queue_free()
	var here := {}
	var ids: Array = Net.roster.keys() if Net.active else [0]
	ids.sort()
	for id in ids:
		var info: Dictionary = Net.roster.get(id, {"name": _local_name(), "char": SaveGame.char_id()})
		here[str(info.get("char", ""))] = true
		var r := HBoxContainer.new()
		r.add_theme_constant_override("separation", 6)
		var sw := ColorRect.new()
		sw.custom_minimum_size = Vector2(8, 8)
		sw.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		sw.color = Net.crew_color(id) if Net.active else UIStyle.ACCENT
		r.add_child(sw)
		var nm := UIStyle.label(str(info.get("name", "A captain")), 12)
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		r.add_child(nm)
		if id == 1 or not Net.active:
			r.add_child(UIStyle.label("Captain", 8, UIStyle.ACCENT))
		else:
			r.add_child(UIStyle.label("ping %d" % Net.ping_ms(id), 8, UIStyle.TEXT_DIM))
			if cap:
				var k := UIStyle.button("Kick", 44)
				var kid: int = id
				k.pressed.connect(func():
					Net.kick(kid)
					refresh.call_deferred())
				r.add_child(k)
		_aboard.add_child(r)
	var today := int(get_node("/root/Weather").day()) if get_node_or_null("/root/Weather") else 0
	var members: Dictionary = gm.crew.get("members", {}) if gm else {}
	var any := false
	for key in members.keys():
		if here.has(str(key)):
			continue
		var m: Dictionary = members[key]
		var days := today - int(m.get("seen", today))
		var r := HBoxContainer.new()
		var nm := UIStyle.label(str(m.get("name", "A captain")), 12, UIStyle.TEXT_DIM)
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		r.add_child(nm)
		r.add_child(UIStyle.label("today" if days <= 0 else ("yesterday" if days == 1 else "%d days ago" % days), 8, UIStyle.TEXT_DIM))
		_sailed.add_child(r)
		any = true
	if not any:
		_sailed.add_child(UIStyle.label("No one else yet. Host Co-op and they'll be on this list.", 8, UIStyle.TEXT_DIM))


func _local_name() -> String:
	var p := get_tree().get_first_node_in_group("player")
	return str(p.display_name()) if p and p.has_method("display_name") else "Captain"
