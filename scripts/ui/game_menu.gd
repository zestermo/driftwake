extends CanvasLayer
## Pause menu, options, controls reference and inventory (autoload "GameMenu").
## Esc opens/closes the pause menu, Tab or I opens the inventory. The game is
## paused while any screen is open.

const SLOT_SIZE := 34

var _root: Control
var _dim: ColorRect
var _screens: Dictionary = {}
var _current: String = ""
var _blip: AudioStreamPlayer

# inventory overlay (paper doll + bag + character sheet)
var _inventory: InventoryScreen
# skill map (K)
var _skills: SkillMapScreen
# save slots (Load Game from the pause menu)
var _load: SaveSlotList
# sea chart (M)
const SEA_CHART := preload("res://scripts/ui/sea_chart.gd")
var _chart: Control
# the shipwright's yard (talk to Tackett)
const YARD := preload("res://scripts/ui/shipwright_screen.gd")
var _yard: Control
# traders' stalls (talk to a vendor)
const SHOP := preload("res://scripts/ui/shop_screen.gd")
var _shop: Control
## A screen to open once the talking's done: [] or ["yard"] / ["shop", id].
var _after_talk: Array = []

# options widgets that need refreshing
var _opt_refreshers: Array[Callable] = []


func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.theme = UIStyle.get_theme()
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	_dim = ColorRect.new()
	_dim.color = Color(0, 0, 0, 0.55)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(_dim)
	_blip = AudioStreamPlayer.new()
	_blip.stream = load("res://assets/audio/select.wav")
	_blip.bus = "UI"
	_blip.volume_db = -8.0
	add_child(_blip)
	_screens["pause"] = _build_pause()
	_screens["options"] = _build_options()
	_screens["controls"] = _build_controls()
	_inventory = InventoryScreen.new(self)
	_screens["inventory"] = _inventory
	_skills = SkillMapScreen.new(self)
	_screens["skills"] = _skills
	_chart = SEA_CHART.new()
	_screens["chart"] = _chart
	_yard = YARD.new(self)
	_screens["yard"] = _yard
	_shop = SHOP.new(self)
	_screens["shop"] = _shop
	var dlg := get_node("/root/Dialogue")
	dlg.dialogue_event.connect(_on_dialogue_event)
	dlg.dialogue_ended.connect(func(_id: String):
		if not _after_talk.is_empty():
			var next := _after_talk
			_after_talk = []
			if next[0] == "shop":
				open_shop.call_deferred(str(next[1]))
			else:
				open.call_deferred(str(next[0])))
	_load = SaveSlotList.new()
	_load.chosen.connect(_load_slot)
	_load.cancelled.connect(func(): open("pause"))
	_screens["load"] = _load
	for s in _screens.values():
		_root.add_child(s)
	_root.visible = false
	get_tree().root.size_changed.connect(func():
		if _current != "":
			_fit_current())


func is_open() -> bool:
	return _current != ""


## On the title screen only Options opens (from its own menu).
func _on_title() -> bool:
	return get_tree().get_first_node_in_group("title_screen") != null


## Back from Options / Controls: the pause menu, or the title screen.
func _back() -> void:
	if _on_title():
		close()
	else:
		open("pause")


# _input (not _unhandled_input) so Tab/Esc are seen before GUI focus navigation.
func _input(event: InputEvent) -> void:
	var dialogue := get_node_or_null("/root/Dialogue")
	if dialogue and dialogue.active:
		return
	if CharacterCreator.active:
		return
	if _on_title():
		if _current != "" and event.is_action_pressed("pause"):
			close()
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("pause"):
		if _current == "":
			open("pause")
		elif _current in ["options", "controls", "load"]:
			open("pause")
		else:
			close()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("skill_map"):
		if _current == "":
			open("skills")
		elif _current == "skills":
			close()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("sea_chart"):
		if _current == "":
			open("chart")
		elif _current == "chart":
			close()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("inventory"):
		if _current == "":
			open("inventory")
		elif _current == "inventory":
			close()
		get_viewport().set_input_as_handled()
	elif _current == "chart" and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_C:
		_chart.clear_marks()
		get_viewport().set_input_as_handled()
	elif _current == "inventory" and event.is_action_pressed("interact") and _inventory.has_container():
		# F in the loot window: take everything
		_inventory.take_all()
		get_viewport().set_input_as_handled()
	elif _current == "inventory" and event is InputEventKey and event.pressed and not event.echo:
		var k: int = event.keycode
		if k >= KEY_5 and k <= KEY_7:
			_inventory.assign_hotbar(k - KEY_5)
			get_viewport().set_input_as_handled()
		elif k == KEY_X or k == KEY_DELETE:
			# drop the hovered stack (shift: just one)
			_inventory.drop_selected(event.shift_pressed)
			get_viewport().set_input_as_handled()


## Dialogue events: "shipwright" and "shop:<id>" open their screen when the
## talk ends; "rumour_king" puts the Sea King's waters on the chart.
func _on_dialogue_event(ev: String) -> void:
	if ev == "shipwright":
		_after_talk = ["yard"]
	elif ev.begins_with("shop:"):
		_after_talk = ["shop", ev.substr(5)]
	elif ev == "rumour_king":
		var gm := get_node("/root/GameManager")
		if not gm.charted.has("king"):
			gm.charted["king"] = true
			get_tree().call_group("hud", "show_toast", "The Sea King's waters are on your chart (M)")


## A trader's stall, now or (talking) when the talk ends.
func open_shop(id: String) -> void:
	_shop.open_shop(id)
	open("shop")


func shop_after_talk(id: String) -> void:
	_after_talk = ["shop", id]


## Open a chest / bag: the inventory with the container beside your bag.
func open_container(bag: Node) -> void:
	open("inventory")
	_inventory.set_container(bag)


func open(screen: String) -> void:
	if screen == "skills" and not Story.skills_open():
		var pl := _player()
		if pl:
			pl.call("_toast", "You don't know how to train yet. Sergeant Vey will show you.")
		return
	if _current == "":
		_play()
	if _current == "inventory" and screen != "inventory":
		_inventory.on_close()
	if _current == "yard" and screen != "yard":
		_yard.end_preview()
	_current = screen
	_root.visible = true
	# the inventory sits on top of the game; other screens dim it
	_dim.visible = screen not in ["inventory", "skills", "yard"]
	for n in _screens.keys():
		_screens[n].visible = (n == screen)
	# (in co-op the world keeps running: your captain just stands still)
	Net.set_paused(true)
	get_tree().call_group("hud", "set_menu_open", true)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if screen == "inventory":
		_inventory.on_open()
	elif screen == "options":
		for r in _opt_refreshers:
			r.call()
	_fit_current.call_deferred()
	if screen == "inventory":
		_inventory.focus_bag()
	elif screen == "skills":
		_skills.on_open()
	elif screen == "chart":
		_chart.on_open()
	elif screen == "yard":
		_yard.on_open()
	elif screen == "shop":
		_shop.on_open()
	elif screen == "load":
		_load.open("load", true)
	else:
		_focus_first(_screens[screen])


## Shrink the open panel if it wouldn't fit (small or odd-shaped windows).
func _fit_current() -> void:
	if _current in ["pause", "options", "controls", "load", "shop"]:
		UIStyle.fit_to_screen(_screens[_current] as Control)


func close() -> void:
	if _current == "inventory":
		_inventory.on_close()
	elif _current == "yard":
		_yard.end_preview()
		if not Net.is_client():
			SaveGame.save(_player())
	elif _current == "shop":
		SaveGame.save(_player())
	_current = ""
	_root.visible = false
	Net.set_paused(false)
	if _on_title():
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		return
	get_tree().call_group("hud", "set_menu_open", false)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _play() -> void:
	_blip.play()


func _focus_first(node: Node) -> void:
	for c in node.find_children("*", "Button", true, false):
		if (c as Button).is_visible_in_tree():
			(c as Button).call_deferred("grab_focus")
			return


func _centered_panel(min_size: Vector2) -> PanelContainer:
	var p := PanelContainer.new()
	p.custom_minimum_size = min_size
	p.set_anchors_preset(Control.PRESET_CENTER)
	p.grow_horizontal = Control.GROW_DIRECTION_BOTH
	p.grow_vertical = Control.GROW_DIRECTION_BOTH
	p.add_theme_stylebox_override("panel", UIStyle.box(UIStyle.BG, UIStyle.BORDER, 12, 2))
	return p


# ==========================================================================
# Pause
# ==========================================================================
func _build_pause() -> Control:
	var p := _centered_panel(Vector2(190, 0))
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 3)
	p.add_child(vb)
	vb.add_child(UIStyle.title("Paused"))
	var items := [
		["Resume", func(): close()],
		["Inventory", func(): open("inventory")],
		["Skill Map", func(): open("skills")],
		["Sea Chart", func(): open("chart")],
		["Appearance", func(): _open_appearance()],
		["Options", func(): open("options")],
		["Controls", func(): open("controls")],
		["Save Game", func():
			var pl := _player()
			if pl:
				SaveGame.save(pl)
				pl.call("_toast", "Saved to slot %d" % maxi(SaveGame.slot, 1))
			close()],
		["Load Game", func():
			if Net.active:
				_player().call("_toast", "Leave the co-op session first")
				close()
				return
			open("load")],
		["Host Co-op", func(): _host_from_game()],
		["Quit to Title", func(): _quit_to_title()],
		["Quit Game", func():
			var pl := _player()
			if pl:
				SaveGame.save(pl)
			get_tree().quit()],
	]
	for it in items:
		var b := UIStyle.button(it[0], 160)
		b.pressed.connect(it[1])
		b.pressed.connect(_play)
		vb.add_child(b)
	return p


## Open this running game to friends (they join from the title screen).
func _host_from_game() -> void:
	var pl := _player()
	close()
	if Net.active:
		if pl:
			pl.call("_toast", "Already in a co-op session (%d aboard)" % Net.roster.size())
		return
	Net.my_info = {"name": pl.display_name() if pl else "Captain", "look": pl.body_model.look if pl else {}}
	var err := Net.host_game()
	if pl:
		pl.call("_toast", ("Hosting co-op on port %d - friends can join from the title screen" % Net.DEFAULT_PORT) if err == OK else Net.last_error)


## Save, then back to the title screen.
func _quit_to_title() -> void:
	var pl := _player()
	if pl and pl.health_component.current_health > 0.0:
		SaveGame.save(pl)
	close()
	Net.leave()
	SaveGame.slot = 0
	get_tree().change_scene_to_file(SaveGame.TITLE_SCENE)


## Load a slot from the pause menu: rebuild the world from that save.
func _load_slot(slot: int) -> void:
	close()
	SaveGame.begin(slot, false, get_tree())
	LoadingScreen.go(get_tree(), SaveGame.WORLD_SCENE)


func _open_appearance() -> void:
	var p := _player()
	close()
	if p:
		p.open_creator(false)


# ==========================================================================
# Options
# ==========================================================================
func _build_options() -> Control:
	var p := _centered_panel(Vector2(420, 0))
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 4)
	p.add_child(outer)
	outer.add_child(UIStyle.title("Options"))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(400, 210)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 3)
	scroll.add_child(list)

	_section(list, "Video")
	_toggle_row(list, "Fullscreen", "video", "fullscreen")
	_cycle_row(list, "PSX resolution", "video", "psx_preset", preload("res://scripts/psx/psx_settings.gd").PRESETS.map(func(x): return x["name"]))
	_toggle_row(list, "Dithering", "video", "dither")
	_slider_row(list, "Vertex wobble", "video", "wobble", 0.0, 1.0, 0.05, "%d%%", 100.0)
	_slider_row(list, "Texture warp", "video", "warp", 0.0, 1.0, 0.05, "%d%%", 100.0)
	_slider_row(list, "Field of view", "video", "fov", 60.0, 100.0, 1.0, "%d", 1.0)
	_toggle_row(list, "Show FPS", "video", "show_fps")
	_section(list, "Audio")
	_slider_row(list, "Master", "audio", "master", 0.0, 1.0, 0.05, "%d%%", 100.0)
	_slider_row(list, "Effects", "audio", "sfx", 0.0, 1.0, 0.05, "%d%%", 100.0)
	_slider_row(list, "Ambience", "audio", "ambience", 0.0, 1.0, 0.05, "%d%%", 100.0)
	_slider_row(list, "Interface", "audio", "ui", 0.0, 1.0, 0.05, "%d%%", 100.0)
	_slider_row(list, "Music", "audio", "music", 0.0, 1.0, 0.05, "%d%%", 100.0)
	_section(list, "Controls")
	_slider_row(list, "Mouse sensitivity", "controls", "mouse_sensitivity", 0.2, 3.0, 0.05, "%.2fx", 1.0)
	_toggle_row(list, "Invert look Y", "controls", "invert_y")
	_section(list, "Gameplay")
	_slider_row(list, "Camera shake", "gameplay", "camera_shake", 0.0, 1.0, 0.05, "%d%%", 100.0)
	_toggle_row(list, "NPC name tags", "gameplay", "name_tags")
	_toggle_row(list, "Reticle", "gameplay", "reticle")

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 10)
	outer.add_child(buttons)
	var reset := UIStyle.button("Reset defaults", 140)
	reset.pressed.connect(func():
		for sec in ["video", "audio", "controls", "gameplay"]:
			Settings.reset_section(sec)
		for r in _opt_refreshers:
			r.call())
	buttons.add_child(reset)
	var back := UIStyle.button("Back", 120)
	back.pressed.connect(_back)
	back.pressed.connect(_play)
	buttons.add_child(back)
	return p


func _section(list: VBoxContainer, text: String) -> void:
	var l := UIStyle.label(text, 14, UIStyle.ACCENT)
	list.add_child(l)
	list.add_child(HSeparator.new())


func _row(list: VBoxContainer, text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var l := UIStyle.label(text)
	l.custom_minimum_size = Vector2(140, 0)
	row.add_child(l)
	list.add_child(row)
	return row


func _toggle_row(list: VBoxContainer, text: String, section: String, key: String) -> void:
	var row := _row(list, text)
	var b := UIStyle.button("", 90)
	row.add_child(b)
	var refresh := func(): b.text = "On" if Settings.get_value(section, key) else "Off"
	b.pressed.connect(func():
		Settings.set_value(section, key, not Settings.get_value(section, key))
		refresh.call()
		_play())
	_opt_refreshers.append(refresh)
	refresh.call()


func _cycle_row(list: VBoxContainer, text: String, section: String, key: String, names: Array) -> void:
	var row := _row(list, text)
	var b := UIStyle.button("", 150)
	row.add_child(b)
	var refresh := func(): b.text = "< %s >" % names[clampi(int(Settings.get_value(section, key)), 0, names.size() - 1)]
	b.pressed.connect(func():
		Settings.set_value(section, key, (int(Settings.get_value(section, key)) + 1) % names.size())
		refresh.call()
		_play())
	_opt_refreshers.append(refresh)
	refresh.call()


func _slider_row(list: VBoxContainer, text: String, section: String, key: String,
		lo: float, hi: float, step: float, fmt: String, display_mult: float) -> void:
	var row := _row(list, text)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.custom_minimum_size = Vector2(150, 14)
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.focus_mode = Control.FOCUS_ALL
	row.add_child(s)
	var val := UIStyle.label("", 12, UIStyle.TEXT_DIM)
	val.custom_minimum_size = Vector2(56, 0)
	row.add_child(val)
	var refresh := func():
		s.set_value_no_signal(float(Settings.get_value(section, key)))
		val.text = fmt % (float(Settings.get_value(section, key)) * display_mult)
	s.value_changed.connect(func(v: float):
		Settings.set_value(section, key, v)
		val.text = fmt % (v * display_mult))
	_opt_refreshers.append(refresh)
	refresh.call()


# ==========================================================================
# Controls reference
# ==========================================================================
const BINDINGS := [
	["Move", "W A S D"], ["Look", "Mouse"], ["Sprint", "Shift"], ["Jump / double jump", "Space"],
	["Ready / sheathe weapon", "Z"], ["Light attack (3-hit combo)", "Left click"], ["Heavy attack", "Right click"],
	["Dodge roll", "Left Ctrl"], ["Parry", "Q"], ["Interact / talk", "F"], ["Devil Fruit skills", "1 - 4"],
	["Ultimate", "R"], ["Quick items (rum...)", "5 - 7"], ["Block (hold)", "Q"],
	["Inventory", "Tab / I"], ["Skill map", "K"], ["Sea chart (click: mark)", "M"], ["Read the log pose (hold)", "L"], ["Zoan: shift form", "V"], ["Summon your ship (hold)", "B"], ["Pause menu", "Esc"], ["Zoom camera", "Mouse wheel"],
	["PSX resolution / dither", "F2 / F3"], ["Fullscreen", "F11 / Alt+Enter"],
]


func _build_controls() -> Control:
	var p := _centered_panel(Vector2(520, 0))
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	p.add_child(vb)
	vb.add_child(UIStyle.title("Controls"))
	# two columns of (action, key) pairs
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 0)
	vb.add_child(grid)
	var half := ceili(BINDINGS.size() / 2.0)
	for i in range(half):
		for j in [i, i + half]:
			if j < BINDINGS.size():
				grid.add_child(UIStyle.label(BINDINGS[j][0], 12))
				grid.add_child(UIStyle.label(BINDINGS[j][1], 12, UIStyle.ACCENT))
	var back := UIStyle.button("Back", 120)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(_back)
	back.pressed.connect(_play)
	vb.add_child(back)
	return p


# ==========================================================================
# Inventory
# ==========================================================================
func _player() -> Player:
	return get_tree().get_first_node_in_group("player") as Player


static func make_slot(size: int) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(size, size)
	b.focus_mode = Control.FOCUS_ALL
	b.add_theme_stylebox_override("normal", UIStyle.box(Color(0.02, 0.02, 0.04, 0.9), UIStyle.BORDER_DIM, 0, 1))
	b.add_theme_stylebox_override("hover", UIStyle.box(Color(0.15, 0.12, 0.07, 0.95), UIStyle.BORDER, 0, 1))
	b.add_theme_stylebox_override("focus", UIStyle.box(Color(0, 0, 0, 0), UIStyle.ACCENT, 0, 2))
	b.add_theme_stylebox_override("pressed", UIStyle.box(Color(0.25, 0.2, 0.1, 0.95), UIStyle.ACCENT, 0, 1))
	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon.offset_left = 4; icon.offset_top = 4; icon.offset_right = -4; icon.offset_bottom = -4
	icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(icon)
	var count := Label.new()
	count.name = "Count"
	count.add_theme_font_override("font", load("res://assets/fonts/Silkscreen-Regular.woff2"))
	count.add_theme_font_size_override("font_size", 8)
	count.add_theme_color_override("font_outline_color", Color.BLACK)
	count.add_theme_constant_override("outline_size", 3)
	count.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	count.offset_left = -18; count.offset_top = -12; count.offset_right = -2; count.offset_bottom = 0
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(count)
	var key := Label.new()
	key.name = "Key"
	key.add_theme_font_override("font", load("res://assets/fonts/Silkscreen-Regular.woff2"))
	key.add_theme_font_size_override("font_size", 8)
	key.add_theme_color_override("font_color", UIStyle.ACCENT)
	key.add_theme_color_override("font_outline_color", Color.BLACK)
	key.add_theme_constant_override("outline_size", 3)
	key.position = Vector2(2, 0)
	key.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(key)
	return b


static func set_slot(b: Button, item: ItemData, qty: int, key_text: String = "", equipped: bool = false) -> void:
	var icon := b.get_node("Icon") as TextureRect
	var count := b.get_node("Count") as Label
	(b.get_node("Key") as Label).text = key_text
	icon.texture = item.icon if item else null
	icon.modulate = Color(1, 1, 1, 1) if qty > 0 else Color(1, 1, 1, 0.3)
	count.text = str(qty) if item and (qty > 1 or (item.stackable and qty != 1)) else ""
	if equipped:
		b.add_theme_stylebox_override("normal", UIStyle.box(Color(0.12, 0.09, 0.04, 0.95), UIStyle.ACCENT, 0, 2))
	elif item and item.rarity == ItemData.Rarity.SUPREME:
		# (black on black: a pale slot behind it)
		b.add_theme_stylebox_override("normal", UIStyle.box(Color(0.45, 0.45, 0.42, 0.9), Color(0.02, 0.02, 0.02), 0, 2))
	elif item and item.rarity > ItemData.Rarity.COMMON:
		var rc := item.rarity_color()
		b.add_theme_stylebox_override("normal", UIStyle.box(Color(rc.r * 0.12, rc.g * 0.12, rc.b * 0.12, 0.92), rc, 0, 1))
	else:
		b.add_theme_stylebox_override("normal", UIStyle.box(Color(0.02, 0.02, 0.04, 0.9), UIStyle.BORDER_DIM, 0, 1))
