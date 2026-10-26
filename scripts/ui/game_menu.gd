extends CanvasLayer
## Pause menu, options, controls reference and inventory (autoload "GameMenu").
## Esc opens/closes the pause menu, Tab or I opens the inventory. The game is
## paused while any screen is open.

var _root: Control
var _dim: ColorRect
var _pc: PixelCanvas
var _screens: Dictionary = {}
var _current: String = ""

# inventory overlay (paper doll + bag + character sheet)
var _inventory: InventoryScreen
# skill map (K)
var _skills: SkillMapScreen
# save slots (Load Game from the pause menu)
var _load: SaveSlotList
# the shipwright's yard (talk to Tackett)
const YARD := preload("res://scripts/ui/shipwright_screen.gd")
# the crew (1.22: the pause menu's Crew)
const CREW := preload("res://scripts/ui/crew_screen.gd")
const WANTED := preload("res://scripts/ui/wanted_screen.gd")
var _crew: Control
var _wanted: Control
var _yard: Control
# traders' stalls (talk to a vendor)
const SHOP := preload("res://scripts/ui/shop_screen.gd")
const SHOP_DATA := preload("res://scripts/game/shops.gd")
var _shop: Control
# cooking (the ship's galley; a camp's fire)
const GALLEY := preload("res://scripts/ui/galley_screen.gd")
var _galley: Control
# suggest an idea (a QR for the companion app)
const IDEA := preload("res://scripts/ui/idea_screen.gd")
var _idea: Control
## A screen to open once the talking's done: [] or ["yard", shipwright] / ["shop", id].
var _after_talk: Array = []

# options widgets that need refreshing
var _opt_refreshers: Array[Callable] = []

# web: the pointer lock last frame, and when losing it opened the pause menu
var _was_captured: bool = false
var _lock_lost_ms: int = -1000


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
	UIStyle.make_sound_players(self)
	_screens["pause"] = _build_pause()
	_screens["options"] = _build_options()
	_screens["controls"] = _build_controls()
	_inventory = InventoryScreen.new(self)
	_screens["inventory"] = _inventory
	_skills = SkillMapScreen.new(self)
	_screens["skills"] = _skills
	_yard = YARD.new(self)
	_screens["yard"] = _yard
	_shop = SHOP.new(self)
	_screens["shop"] = _shop
	_galley = GALLEY.new(self)
	_screens["galley"] = _galley
	_galley.register_wheel()
	_idea = IDEA.new(_back)
	_screens["idea"] = _idea
	_crew = CREW.new(self)
	_screens["crew"] = _crew
	_wanted = WANTED.new(self)
	_screens["wanted"] = _wanted
	var dlg := get_node("/root/Dialogue")
	dlg.dialogue_event.connect(_on_dialogue_event)
	dlg.dialogue_ended.connect(func(_id: String):
		if not _after_talk.is_empty():
			var next := _after_talk
			_after_talk = []
			if next[0] == "yard":
				_yard.set_yard(str(next[1]), next[2] if next.size() > 2 else [], next[3] if next.size() > 3 else true)
			if next[0] == "shop":
				open_shop.call_deferred(str(next[1]))
			else:
				open.call_deferred(str(next[0])))
	_load = SaveSlotList.new()
	_load.chosen.connect(_load_slot)
	_load.cancelled.connect(func(): open("pause"))
	_screens["load"] = _load
	# every screen but the inventory (its own canvas) shares one crisp canvas
	_pc = PixelCanvas.new()
	_root.add_child(_pc)
	for s in _screens.values():
		(_root if s == _inventory else _pc.ui).add_child(s)
	_root.visible = false
	get_tree().root.size_changed.connect(func():
		if _current != "":
			_fit_current())
	set_process(OS.has_feature("web"))


## Web only: a browser's Esc releases the pointer lock and may never reach the
## game, so losing the lock while playing opens the pause menu.
func _process(_delta: float) -> void:
	var cap := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	var dialogue := get_node_or_null("/root/Dialogue")
	if _was_captured and not cap and _current == "" and not _on_title() and not CharacterCreator.active \
			and not (dialogue and dialogue.active):
		open("pause")
		_lock_lost_ms = Time.get_ticks_msec()
	_was_captured = cap


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
	if CharacterCreator.active or ChatBox.typing:
		return
	if _on_title():
		if _current != "" and event.is_action_pressed("pause"):
			close()
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("pause"):
		if _current == "":
			open("pause")
		elif _current in ["options", "controls", "load", "idea"]:
			_play("back")
			open("pause")
		elif _current == "pause" and Time.get_ticks_msec() - _lock_lost_ms < 300:
			pass   # (web: the same Esc that released the pointer lock)
		else:
			close()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("skill_map"):
		if _current == "":
			open("skills")
		elif _current == "skills":
			close()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("inventory"):
		if _current == "":
			open("inventory")
		elif _current == "inventory":
			close()
		get_viewport().set_input_as_handled()
	elif _current == "inventory" and event.is_action_pressed("interact") and _inventory.has_container():
		# F in the loot window: take everything
		_inventory.take_all()
		get_viewport().set_input_as_handled()
	elif _current == "inventory" and event is InputEventKey and event.pressed and not event.echo:
		var k: int = event.keycode
		if event.is_action_pressed("quick_item"):
			_inventory.select_quick()
			get_viewport().set_input_as_handled()
		elif k == KEY_X or k == KEY_DELETE:
			# drop the hovered stack (shift: just one)
			_inventory.drop_selected(event.shift_pressed)
			get_viewport().set_input_as_handled()


## Dialogue events: "shipwright" (Tackett's yard; "shipwright:<name>" another's, "shipwright:<name>|<line>,<line>" only those lines) and "shop:<id>" open their screen when the
## talk ends; "rumour_king" puts the Sea King's waters on the chart; "learn_black_leg" (Gus) teaches the kicks.
func _on_dialogue_event(ev: String) -> void:
	if ev == "shipwright" or ev.begins_with("shipwright:"):
		var spec := ev.substr(11).split("|") if ev.begins_with("shipwright:") else PackedStringArray(["Tackett"])
		# (Tackett: the home lines only; a harbour vendor: their own, no paint; a city's yard: everything)
		var lines: Array = Array(spec[1].split(",")) if spec.size() > 1 else (ShipLines.HOME_LINES if ev == "shipwright" else [])
		_after_talk = ["yard", spec[0], lines, spec.size() < 2]
	elif ev == "learn_black_leg":
		var pl := _player()
		if pl:
			pl.learn_black_leg()
	elif ev.begins_with("shop:"):
		_after_talk = ["shop", ev.substr(5)]
	elif ev.begins_with("ship:"):
		_ship_event(ev.get_slice(":", 1), ev.get_slice(":", 2))
	elif ev == "rumour_king":
		var gm := get_node("/root/GameManager")
		if not gm.charted.has("king"):
			gm.charted["king"] = true
			get_tree().call_group("hud", "show_toast", "The Leviathan's waters are on your chart (M)")


## A trader's stall, now or (talking) when the talk ends.
func open_shop(id: String) -> void:
	# a wanted captain past what this trade will stand (Bounty.shop_k): turned away
	var p := get_tree().get_first_node_in_group("player")
	var b := int(p.get("bounty")) if p and p.get("bounty") != null else 0
	if Bounty.shop_k(str(SHOP_DATA.shop(id).get("trade", "")), b) < 0.0:
		get_tree().call_group("hud", "show_toast", "%s: \"%s\"" % [str(SHOP_DATA.shop(id).get("name", "")), Bounty.REFUSE_LINES[randi() % Bounty.REFUSE_LINES.size()]])
		return
	_shop.open_shop(id)
	open("shop")


## Cooking: `portions` of each dish from one set of ingredients (the ship's galley line; a camp fire 1).
func open_galley(portions: int) -> void:
	_galley.portions = portions
	open("galley")


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
		_play("open")
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
	_pc.visible = screen != "inventory"
	# (in co-op the world keeps running: your captain just stands still)
	Net.set_paused(true)
	get_tree().call_group("hud", "set_menu_open", true)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if screen == "inventory":
		_inventory.on_open()
	elif screen == "options":
		for r in _opt_refreshers:
			r.call()
	elif screen == "idea":
		_idea.on_open()
	_fit_current.call_deferred()
	if screen == "inventory":
		_inventory.focus_bag()
	elif screen == "skills":
		_skills.on_open()
	elif screen == "yard":
		_yard.on_open()
	elif screen == "shop":
		_shop.on_open()
	elif screen == "galley":
		_galley.on_open()
	elif screen == "wanted":
		_wanted.on_open()
		_focus_first(_wanted)
	elif screen == "crew":
		_crew.on_open()
		_focus_first(_crew)
	elif screen == "load":
		_load.open("load", true)
	else:
		_focus_first(_screens[screen])


## Shrink the open panel if it wouldn't fit (small or odd-shaped windows).
func _fit_current() -> void:
	if _current in ["pause", "options", "controls", "load", "idea"]:
		UIStyle.fit_to_screen(_screens[_current] as Control)


func close() -> void:
	var was := _current
	if _current == "inventory":
		_inventory.on_close()
	elif _current == "yard":
		_yard.end_preview()
		if not Net.is_client():
			SaveGame.save(_player())
	elif _current in ["shop", "galley"]:
		SaveGame.save(_player())
	_current = ""
	_play("close")
	if was == "inventory":
		_inventory.fade_out(func():
			if _current == "":
				_root.visible = false)
	else:
		_root.visible = false
	Net.set_paused(false)
	if _on_title():
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		return
	get_tree().call_group("hud", "set_menu_open", false)
	Settings.capture_mouse()


## A menu sound (UIStyle.SOUNDS).
func _play(what: String = "confirm") -> void:
	UIStyle.sfx(what)


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
	p.add_theme_stylebox_override("panel", UIStyle.panel(UIStyle.BG, UIStyle.BORDER, 12))
	return p


# ==========================================================================
# Pause
# ==========================================================================
func _build_pause() -> Control:
	var p := _centered_panel(Vector2(190, 0))
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 6)
	p.add_child(outer)
	outer.add_child(UIStyle.title("Paused"))
	# two columns of planks (one column ran past a 360-tall canvas)
	var vb := GridContainer.new()
	vb.columns = 2
	vb.add_theme_constant_override("h_separation", 6)
	vb.add_theme_constant_override("v_separation", 4)
	outer.add_child(vb)
	var items := [
		["Resume", func(): close()],
		["Inventory", func(): open("inventory")],
		["Skill Map", func(): open("skills")],
		["Crew", func(): open("crew")],
		["Wanted", func(): open("wanted")],
		["Appearance", func(): _open_appearance()],
		["Options", func(): open("options")],
		["Controls", func(): open("controls")],
		["Suggest an Idea", func(): open("idea")],
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
		if OS.has_feature("web") and it[0] in ["Host Co-op", "Quit Game"]:
			continue
		var b := UIStyle.button(it[0], 130)
		b.pressed.connect(it[1])
		vb.add_child(b)
	return p


## The crew's flag (the Crew screen's Flag): the ship's paint, from anywhere (paint's free; the Captain's to change).
func open_flag() -> void:
	_yard.set_yard("Tackett")
	_yard.show_tab("paint")
	open("yard")


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
	_toggle_row(list, "Pixelation", "video", "pixelate")
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
	_slider_row(list, "Pad look sensitivity", "controls", "pad_look_sensitivity", 0.2, 3.0, 0.05, "%.2fx", 1.0)
	_slider_row(list, "Pad look deadzone", "controls", "pad_look_deadzone", 0.05, 0.4, 0.01, "%d%%", 100.0)
	_slider_row(list, "Pad move deadzone", "controls", "pad_move_deadzone", 0.05, 0.4, 0.01, "%d%%", 100.0)
	_toggle_row(list, "Pad skill list", "gameplay", "pad_skills")
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
	buttons.add_child(back)
	return p


func _section(list: VBoxContainer, text: String) -> void:
	if list.get_child_count() > 0:
		list.add_child(UIStyle.rule())
	list.add_child(UIStyle.ribbon(text))


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
	b.name = key
	row.add_child(b)
	var refresh := func(): b.text = "On" if Settings.get_value(section, key) else "Off"
	b.pressed.connect(func():
		Settings.set_value(section, key, not Settings.get_value(section, key))
		refresh.call())
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
## [what, keyboard and mouse, pad]: the pad's is an action Glyphs names (so it follows Pad's layout) or the
## words themselves. The page shows the device in use (Pad.using_pad) and flips with it.
const BINDINGS := [
	["Move", "W A S D", "move"], ["Look", "Mouse", "look"], ["Sprint", "Shift", "L3 (click: run)"], ["Jump / double jump", "Space", "jump"],
	["Ready / sheathe weapon", "Z", "ready_weapon"], ["Light attack (3-hit combo)", "Left click", "light_attack"], ["Heavy attack", "Right click", "heavy_attack"],
	["Dodge roll", "Left Ctrl", "dodge"], ["Sneak (toggle)", "C", "crouch"], ["Emote wheel (hold, point to pick)", "T", "emote"], ["Parry", "Q", "parry"], ["Interact / talk", "F", "interact"], ["Skills", "1 - 5", "LB+X Y B A RB"],
	["Ultimate", "R", "ultimate"], ["Eat / drink (hold: choose)", "E", "quick_item"], ["Action wheel (hold: camp...)", "N", "action_wheel"], ["Swap weapon loadout (hold: choose)", "X", "loadout"], ["Crew chat (co-op)", "Enter", "-"],["Block (hold)", "Q", "parry"],
	["Inventory", "Tab / I", "inventory"], ["Skill map", "K", "skill_map"], ["Map: out / away (click: mark)", "M", "sea_chart"], ["Belt lantern on / off", "L", "lantern"], ["Read the lodestone (hold)", "H", "log_pose"], ["Zoan: shift form", "V", "transform"], ["Summon your ship (hold)", "B", "summon_ship"], ["Pause menu", "Esc", "pause"], ["Zoom camera", "Mouse wheel", "-"],
	["PSX resolution / dither", "F2 / F3", "F2 / F3"], ["Fullscreen", "F11 / Alt+Enter", "F11 / Alt+Enter"],
]
var _binding_keys: Array[Label] = []


## Row i's button(s) for the device in use.
func _binding_key(i: int) -> String:
	if Pad.using_pad:
		var a: String = BINDINGS[i][2]
		return Glyphs.pad_of(a) if InputMap.has_action(a) or Glyphs.PAD_PSEUDO.has(a) else a
	var key: String = BINDINGS[i][1]
	if OS.has_feature("web") and key == "Left Ctrl":
		key = "C"   # (Settings: Ctrl+W would close the browser tab)
	return key


func _refresh_bindings() -> void:
	for i in range(_binding_keys.size()):
		_binding_keys[i].text = _binding_key(i)


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
	_binding_keys.resize(BINDINGS.size())
	for i in range(half):
		for j in [i, i + half]:
			if j < BINDINGS.size():
				grid.add_child(UIStyle.label(BINDINGS[j][0], 12))
				_binding_keys[j] = UIStyle.label("", 12, UIStyle.ACCENT)
				grid.add_child(_binding_keys[j])
	_refresh_bindings()
	Pad.device_changed.connect(func(_pad: bool): _refresh_bindings())
	var back := UIStyle.button("Back", 120)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(_back)
	vb.add_child(back)
	return p


# ==========================================================================
# Inventory
# ==========================================================================
func _player() -> Player:
	return get_tree().get_first_node_in_group("player") as Player


## "ship:buy:<class>" / "ship:switch:<class>" from a shipwright's talk (ShipClasses, 1.21): the buyer pays from their
## own bag first (or hears what they're short of), then the host changes the crew's ship.
func _ship_event(action: String, cls: String) -> void:
	var pl := _player()
	if pl == null or not ShipClasses.CLASSES.has(cls):
		return
	var name_: String = ShipClasses.CLASSES[cls]["name"]
	if action == "buy":
		var short := ShipClasses.short_of(pl.inventory_component, cls)
		if short != "":
			get_tree().call_group("hud", "show_toast", "The %s costs %s: you're short %s." % [name_.to_lower(), ShipClasses.price_text(cls), short])
			return
		ShipClasses.pay(pl.inventory_component, cls)
		get_tree().call_group("hud", "show_banner", "A %s of your own!" % name_.to_lower(), "She's at the berth. Your sloop's laid up at the yard, upgrades and all.", true)
	else:
		get_tree().call_group("hud", "show_toast", "You'll sail the %s. The other's laid up at the yard." % name_.to_lower())
	get_node("/root/Net").request_ship(action, cls)
