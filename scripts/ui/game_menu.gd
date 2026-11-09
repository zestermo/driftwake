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
const BENCH := preload("res://scripts/ui/gadget_bench_screen.gd")
# (1.28) the cooking game in first person
const COOK := preload("res://scripts/ui/cook_game_screen.gd")
var _cook: Control
var _galley: Control
var _bench: Control
const BOOKSHELF := preload("res://scripts/ui/bookshelf_screen.gd")
const FISH_JOURNAL := preload("res://scripts/ui/fish_journal_screen.gd")
const BOARD := preload("res://scripts/ui/notice_board_screen.gd")
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
	_cook = COOK.new(self)
	_screens["cook"] = _cook
	_bench = BENCH.new(self)
	_screens["workbench"] = _bench
	_idea = IDEA.new(_back)
	_screens["idea"] = _idea
	_crew = CREW.new(self)
	_screens["crew"] = _crew
	_wanted = WANTED.new(self)
	_screens["wanted"] = _wanted
	# (1.28 life systems) the bookshelf; their on_open runs on open
	_screens["books"] = BOOKSHELF.new(self)
	_screens["fish_journal"] = FISH_JOURNAL.new(self)
	_screens["fish_journal"].register_wheel()
	_screens["notice_board"] = BOARD.new(self)
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
	_load.allow_new = false
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


func screen() -> String:
	return _current


## The pad's B (ui_cancel): back out of a screen, like Esc. (Not the B key's dodge in play.)
static func pad_back(event: InputEvent) -> bool:
	return event is InputEventJoypadButton and event.is_action_pressed("ui_cancel")


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
	if bind_wait != "" and _current == "controls":
		if event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton:
			if event.is_pressed():
				bind_event(event)
			get_viewport().set_input_as_handled()
		return
	var dialogue := get_node_or_null("/root/Dialogue")
	if dialogue and dialogue.active:
		return
	if CharacterCreator.active or ChatBox.typing:
		return
	if _on_title():
		if _current != "" and (event.is_action_pressed("pause") or pad_back(event)):
			Pad.swallow(event)
			close()
			get_viewport().set_input_as_handled()
		return
	if pad_back(event) and _current != "" and _current != "cook":
		Pad.swallow(event)
		_play("back")
		if _current in ["options", "controls", "load", "idea"]:
			open("pause")
		else:
			close()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("pause"):
		if _current == "cook":
			_cook.give_up()
		elif _current == "":
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
	elif ev.begins_with("master:"):
		# a master's test (ArenaBout "master:<tree>"): once the talk's over
		Net.request_arena.call_deferred(ev, 0)
	elif ev.begins_with("shop:"):
		_after_talk = ["shop", ev.substr(5)]
	elif ev.begins_with("ship:"):
		_ship_event(ev.get_slice(":", 1), ev.get_slice(":", 2))
	elif ev == "rumour_king":
		var gm := get_node("/root/GameManager")
		if not gm.charted.has("king"):
			gm.charted["king"] = true
			get_tree().call_group("hud", "show_toast", "The Leviathan's waters are on your chart (%s)" % Glyphs.short_of("sea_chart"))


## (1.28) A workbench's gadgets (Workbench.use).
func open_workbench(at: Node3D) -> void:
	_bench.bench = at
	open("workbench")


## (1.30) A generated village's notice board: its page (NoticeBoardScreen).
func open_board(isl: Node) -> void:
	_screens["notice_board"].isl = isl
	open("notice_board")


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


## The cooking game (CookTiming, in first person over a counter): `done(quality, grade)` once it's over;
## opts: "speed" x the beats' speed, "beats" a subset like ["stir", "plate"], "meal" the dish (its colours),
## "back" the screen to return to ("" closes the menu). Esc gives up without calling `done`.
func open_cook_game(title: String, done: Callable, opts: Dictionary = {}) -> void:
	open("cook")
	_cook.start(title, str(opts.get("meal", "")), done, opts, str(opts.get("back", "")))


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
	Perf.crumb("open " + screen)
	if _current == "":
		_play("open")
	if _current == "inventory" and screen != "inventory":
		_inventory.on_close()
	if _current == "yard" and screen != "yard":
		_yard.end_preview()
	if bind_wait != "":
		bind_wait = ""
		_refresh_bindings()
	_current = screen
	_root.visible = true
	Walkthrough.first(get_tree(), screen)
	# the inventory sits on top of the game; other screens dim it
	_dim.visible = screen not in ["inventory", "skills", "yard", "cook"]
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
	elif screen == "workbench":
		_bench.on_open()
	elif screen == "wanted":
		_wanted.on_open()
		_focus_first(_wanted)
	elif screen == "crew":
		_crew.on_open()
		_focus_first(_crew)
	elif screen == "load":
		_load.open("load", true)
	elif _screens[screen].has_method("on_open"):
		_screens[screen].on_open()
	else:
		_focus_first(_screens[screen])


## Shrink the open panel if it wouldn't fit (small or odd-shaped windows).
func _fit_current() -> void:
	if _current in ["pause", "options", "controls", "load", "idea"]:
		UIStyle.fit_to_screen(_screens[_current] as Control)


func close() -> void:
	var was := _current
	Perf.crumb("close " + was)
	if _current == "cook" and _cook.timing != null:
		_cook.clear()
	if _current == "inventory":
		_inventory.on_close()
	elif _current == "yard":
		_yard.end_preview()
		if not Net.is_client():
			SaveGame.save(_player())
	elif _current in ["shop", "galley", "workbench", "books"]:
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
		["Captain's Log", func():
			close()
			Journal.open()],
		["Crew", func(): open("crew")],
		["Wanted", func(): open("wanted")],
		["Appearance", func(): _open_appearance()],
		["Options", func(): open("options")],
		["Controls", func(): open("controls")],
		["Suggest an Idea", func(): open("idea")],
		["Unstuck", func():
			var pl := _player()
			close()
			if pl:
				pl.call("_toast", pl.unstuck.request(pl))],
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
	var p := _centered_panel(Vector2(500, 0))
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 4)
	p.add_child(outer)
	outer.add_child(UIStyle.title("Options"))
	var scroll := ScrollContainer.new()
	scroll.follow_focus = true
	scroll.custom_minimum_size = Vector2(480, 300)
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
	_toggle_row(list, "Cel shading", "video", "cel")
	_slider_row(list, "Vertex wobble", "video", "wobble", 0.0, 1.0, 0.05, "%d%%", 100.0)
	_slider_row(list, "Texture warp", "video", "warp", 0.0, 1.0, 0.05, "%d%%", 100.0)
	_slider_row(list, "Field of view", "video", "fov", 60.0, 100.0, 1.0, "%d", 1.0)
	_toggle_row(list, "Show FPS", "video", "show_fps")
	_toggle_row(list, "Vsync", "video", "vsync")
	_slider_row(list, "Frame cap (0: none)", "video", "max_fps", 0.0, 240.0, 30.0, "%d", 1.0)
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
	_toggle_row(list, "Reduce flashing", "gameplay", "reduce_flashing")
	_toggle_row(list, "Get unstable updates", "gameplay", "beta_updates")

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
	var tips := UIStyle.button("Replay the tips", 130)
	tips.pressed.connect(func():
		Walkthrough.reset(get_tree())
		_play("confirm"))
	buttons.add_child(tips)
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
	l.custom_minimum_size = Vector2(180, 0)
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
	s.custom_minimum_size = Vector2(190, 14)
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
# Controls (1.30.1: a keybind editor, Keybinds)
# ==========================================================================
## The keys that can't be changed, under the list.
const FIXED_KEYS := "Esc: pause   Mouse: look   Wheel: zoom   F2 / F3: pixelation / dither   F11: fullscreen"
## action -> its key button; the pad's button beside it is a dim label.
var _bind_buttons: Dictionary = {}
var _bind_pads: Dictionary = {}
## The action waiting for a key ("": none) and the line that says what happened.
var bind_wait: String = ""
var _bind_note: Label


func _refresh_bindings() -> void:
	for a in _bind_buttons.keys():
		(_bind_buttons[a] as Button).text = "Press a key..." if a == bind_wait else Keybinds.keys_text(a)
		(_bind_pads[a] as Label).text = Glyphs.pad_of(a).replace("?", "-").replace("Left stick", "L stick")


## Click a row: its next key or mouse button press binds it (GameMenu._input sends it to bind_event).
func start_bind(action: String) -> void:
	bind_wait = action
	_bind_note.text = "Press a key or mouse button for %s (Esc: cancel)" % Keybinds.label_of(action)
	_refresh_bindings()


## A press while a row waits: binds it (a key another action had swaps over), Esc or a pad button cancels.
func bind_event(event: InputEvent) -> void:
	if event is InputEventJoypadButton or event.device == Pad.CURSOR_DEVICE or (event is InputEventKey and event.pressed \
			and (event.physical_keycode == KEY_ESCAPE or event.keycode == KEY_ESCAPE)):
		_bind_note.text = "Cancelled"
		bind_wait = ""
		_refresh_bindings()
		return
	var e := Keybinds.bindable(event)
	if e == null:
		return
	var a := bind_wait
	bind_wait = ""
	var other := Keybinds.bind(a, e)
	Settings.save_keys()
	_play("confirm")
	_bind_note.text = "%s: %s" % [Keybinds.label_of(a), Keybinds.keys_text(a)]
	if other != "":
		_bind_note.text += "  (swapped: %s is now %s)" % [Keybinds.label_of(other), Keybinds.keys_text(other)]
	_refresh_bindings()


func reset_binds() -> void:
	bind_wait = ""
	Keybinds.reset()
	Settings.save_keys()
	_bind_note.text = "Every key back to its default"
	_refresh_bindings()


func _build_controls() -> Control:
	var p := _centered_panel(Vector2(600, 0))
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	p.add_child(vb)
	vb.add_child(UIStyle.title("Controls"))
	var scroll := ScrollContainer.new()
	scroll.follow_focus = true
	scroll.custom_minimum_size = Vector2(580, 300)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(scroll)
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 16)
	cols.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(cols)
	# Movement and Combat on the left, Abilities and Interface on the right
	for half in [Keybinds.GROUPS.slice(0, 2), Keybinds.GROUPS.slice(2)]:
		var list := VBoxContainer.new()
		list.add_theme_constant_override("separation", 2)
		list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cols.add_child(list)
		for g in half:
			list.add_child(UIStyle.ribbon(g[0]))
			for row in g[1]:
				var action: String = row[0]
				var hb := HBoxContainer.new()
				hb.add_theme_constant_override("separation", 4)
				var l := UIStyle.label(row[1], 12)
				l.custom_minimum_size = Vector2(136, 0)
				l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				l.clip_text = true
				hb.add_child(l)
				var b := UIStyle.button("", 88)
				b.name = action
				b.clip_text = true
				b.pressed.connect(start_bind.bind(action))
				hb.add_child(b)
				var pad := UIStyle.label("", 12, UIStyle.TEXT_DIM)
				pad.custom_minimum_size = Vector2(56, 0)
				pad.clip_text = true
				hb.add_child(pad)
				list.add_child(hb)
				_bind_buttons[action] = b
				_bind_pads[action] = pad
	_bind_note = UIStyle.label("Click a key to change it. A key another action uses swaps over.", 12, UIStyle.ACCENT)
	_bind_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(_bind_note)
	var fixed := UIStyle.label(FIXED_KEYS, 12, UIStyle.TEXT_DIM)
	fixed.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(fixed)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 10)
	vb.add_child(buttons)
	var reset := UIStyle.button("Reset to defaults", 150)
	reset.name = "ResetKeys"
	reset.pressed.connect(reset_binds)
	buttons.add_child(reset)
	var back := UIStyle.button("Back", 120)
	back.pressed.connect(_back)
	buttons.add_child(back)
	_refresh_bindings()
	Pad.device_changed.connect(func(_pad: bool): _refresh_bindings())
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
	var was: String = ShipClasses.CLASSES[ShipClasses.class_of(GameManager.ship_kit)]["name"]
	if action == "buy":
		var why := ShipClasses.locked_why(cls, ShipClasses.chain_layer(GameManager), GameManager.log_pose_set())
		if why != "":
			get_tree().call_group("hud", "show_toast", why)
			return
		var short := ShipClasses.short_of(pl.inventory_component, cls)
		if short != "":
			get_tree().call_group("hud", "show_toast", "The %s costs %s: you're short %s." % [name_.to_lower(), ShipClasses.price_text(cls), short])
			return
		ShipClasses.pay(pl.inventory_component, cls)
		get_tree().call_group("hud", "show_banner", "A %s of your own!" % name_.to_lower(), "She's at the berth, in your colours. Your %s's laid up at the yard, upgrades and all." % was.to_lower(), true)
	else:
		get_tree().call_group("hud", "show_toast", "You'll sail the %s. The other's laid up at the yard." % name_.to_lower())
	get_node("/root/Net").request_ship(action, cls)
