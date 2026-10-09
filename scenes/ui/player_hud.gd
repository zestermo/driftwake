extends CanvasLayer
## Low-res PSX HUD: health, loot count, ship compass, interaction prompt,
## island title banners, toasts, the skill bar (health / stamina / energy,
## Devil Fruit skills and the item hotbar) and reticle. F4 toggles the debug
## state label.

@onready var health_bar: ProgressBar = $Top/VBox/HealthRow/HealthBar
@onready var health_label: Label = $Top/VBox/HealthRow/HealthBar/Label
@onready var state_label: Label = $Top/VBox/StateLabel
@onready var inventory_label: Label = $Top/VBox/InventoryLabel
@onready var interact_panel: PanelContainer = $InteractPanel
@onready var interact_label: Label = $InteractPanel/InteractPrompt
@onready var compass_label: Label = $CompassContainer/CompassLabel
@onready var compass_arrow: Label = $CompassContainer/CompassArrow
@onready var compass_dist: Label = $CompassContainer/CompassDist
@onready var banner: VBoxContainer = $Banner
@onready var banner_title: Label = $Banner/Title
@onready var banner_sub: Label = $Banner/Subtitle
@onready var toast: Label = $Toast

var player: Player
var ship: Node3D
var _banner_tween: Tween
var _toast_tween: Tween
var _chime: AudioStreamPlayer
var _skill_bar: SkillBar
var _reticle: Reticle
const SHOOT_STATE := preload("res://scripts/player_states/shoot_state.gd")
var _fps: Label
var _in_dialogue: bool = false
const OBJECTIVE := preload("res://scripts/ui/objective_hud.gd")
var _objective: Control


func _ready() -> void:
	add_to_group("hud")
	state_label.visible = false
	banner.modulate.a = 0.0
	toast.modulate.a = 0.0
	interact_panel.visible = false
	# held jobs ("Hold F: ...") show in the same panel, with their progress under the words
	var ivb := VBoxContainer.new()
	ivb.add_theme_constant_override("separation", 1)
	ivb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	interact_panel.remove_child(interact_label)
	ivb.add_child(interact_label)
	interact_panel.add_child(ivb)
	_hold_bar = _bar(Color(0.95, 0.8, 0.35))
	_hold_bar.custom_minimum_size = Vector2(0, 3)
	_hold_bar.max_value = 1.0
	_hold_bar.visible = false
	ivb.add_child(_hold_bar)
	_chime = AudioStreamPlayer.new()
	_chime.stream = load("res://assets/audio/discover_chime.wav")
	_chime.volume_db = -6.0
	_chime.bus = "UI"
	add_child(_chime)
	_build_skill_bar()
	# health and stamina live in the skill bar's orbs now
	$Top/VBox/HealthRow.visible = false
	_reticle = Reticle.new()
	add_child(_reticle)
	_fps = Label.new()
	_fps.add_theme_font_override("font", load("res://assets/fonts/Silkscreen-Regular.woff2"))
	_fps.add_theme_font_size_override("font_size", 8)
	_fps.add_theme_color_override("font_outline_color", Color.BLACK)
	_fps.add_theme_constant_override("outline_size", 3)
	_fps.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_fps.offset_left = -90; _fps.offset_top = 19; _fps.offset_right = -10
	_fps.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_fps)
	_build_coop()
	_build_feed()
	_build_bars()
	_build_gold()
	_build_compass()
	_objective = OBJECTIVE.new()
	_objective.name = "Objective"
	add_child(_objective)
	Dialogue.dialogue_started.connect(func(_id): _in_dialogue = true)
	Dialogue.dialogue_ended.connect(func(_id): _in_dialogue = false)
	await get_tree().process_frame
	player = get_tree().get_first_node_in_group("player")
	ship = get_tree().get_first_node_in_group("ship")
	if player:
		health_bar.max_value = player.health_component.max_health
		health_bar.value = player.health_component.current_health
		player.health_component.health_changed.connect(_on_health_changed)
		_skill_bar.bind(player)
		player.interaction_component.prompt_changed.connect(_on_prompt_changed)
		player.interaction_component.prompt_hidden.connect(_on_prompt_hidden)
		player.inventory_component.inventory_changed.connect(_on_inventory_changed)
		player.inventory_component.item_added.connect(_on_item_added)
		_on_inventory_changed()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F4:
		state_label.visible = not state_label.visible


func _process(delta: float) -> void:
	_update_reticle()
	_update_party(delta)
	_update_feed(delta)
	_update_hull()
	_update_gold(delta)
	_update_compass()
	# the loot line and the crew list sit under the objective
	var oh: float = _objective.tracker_height()
	$Top.offset_top = 8.0 + oh
	_party.position.y = 46.0 + oh
	var show_bar: bool = not _in_dialogue and player != null and player.context == Player.Context.ON_FOOT and player.current_state_name() != "Wake"
	_skill_bar.visible = show_bar and not _menu_open
	toast.visible = true
	_fps.visible = true
	var wx := get_node_or_null("/root/Weather")
	var clock := str(wx.clock_text()) if wx and wx.get("_scene") != null else ""
	if Settings.get_value("video", "show_fps"):
		_fps.text = "%d FPS\n%s" % [Engine.get_frames_per_second(), clock]
	else:
		_fps.text = clock
	_fps.visible = _fps.text != "" and not _menu_open
	if state_label.visible and player and player.state_machine and player.state_machine.current_state:
		state_label.text = player.state_machine.current_state.name

	# (no pointer to a ship that isn't yours yet)
	$CompassContainer.visible = ship != null and (ship as Ship).owned()
	if player and ship:
		var to_ship := ship.global_position - player.global_position
		var dist := Vector2(to_ship.x, to_ship.z).length()
		compass_dist.text = "%dm" % int(dist)
		if dist > 20.0:
			var camera := player.get_viewport().get_camera_3d()
			if camera:
				var cam_fwd := Vector2(-camera.global_basis.z.x, -camera.global_basis.z.z).normalized()
				var ship_dir := Vector2(to_ship.x, to_ship.z).normalized()
				var angle := cam_fwd.angle_to(ship_dir)
				if angle > -0.4 and angle < 0.4:
					compass_arrow.text = "^"
				elif angle >= 0.4 and angle < 1.2:
					compass_arrow.text = ">"
				elif angle <= -0.4 and angle > -1.2:
					compass_arrow.text = "<"
				elif angle >= 1.2 and angle < 2.4:
					compass_arrow.text = ">>"
				elif angle <= -1.2 and angle > -2.4:
					compass_arrow.text = "<<"
				else:
					compass_arrow.text = "v"
		else:
			compass_arrow.text = "*"


## Big centered title card, e.g. when arriving at an island.
func show_banner(title: String, subtitle: String = "", chime: bool = false) -> void:
	banner_title.text = title
	banner_sub.text = subtitle
	banner_sub.visible = subtitle != ""
	if _banner_tween:
		_banner_tween.kill()
	banner.modulate.a = 0.0
	_banner_tween = create_tween()
	_banner_tween.tween_interval(0.4)
	_banner_tween.tween_property(banner, "modulate:a", 1.0, 0.8)
	_banner_tween.tween_interval(2.8)
	_banner_tween.tween_property(banner, "modulate:a", 0.0, 1.2)
	if chime:
		_chime.play()


## The story moved on (Story): the objective flashes, a chime.
func show_objective_banner(_goal: String) -> void:
	_objective.flash()
	_chime.play()


## Small message bottom-left (loot picked up, banking...).
func show_toast(text: String) -> void:
	toast.text = text
	if _toast_tween:
		_toast_tween.kill()
	toast.modulate.a = 1.0
	_toast_tween = create_tween()
	_toast_tween.tween_interval(2.0)
	_toast_tween.tween_property(toast, "modulate:a", 0.0, 0.8)


func _on_health_changed(current: float, maximum: float) -> void:
	health_bar.max_value = maximum
	health_bar.value = current
	health_label.text = "%d/%d" % [int(current), int(maximum)]


var _interact_text: String = ""
var _hold_text: String = ""
var _hold_bar: ProgressBar


func _on_prompt_changed(text: String) -> void:
	_interact_text = text
	_show_interact()


func _on_prompt_hidden() -> void:
	_interact_text = ""
	_show_interact()


## One prompt panel for both: "[F] Man the cannon", "[Hold F] Patch the hole".
func _show_interact() -> void:
	var text := ""
	if _hold_text != "":
		text = "[Hold F] " + _hold_text
	elif _interact_text != "":
		text = "[F] " + _interact_text
	interact_panel.visible = text != ""
	_hold_bar.visible = _hold_text != ""
	if text == "" or text == interact_label.text:
		return
	interact_label.text = text
	interact_panel.reset_size()
	interact_panel.position.x = (get_viewport().get_visible_rect().size.x - interact_panel.size.x) * 0.5


func _on_inventory_changed() -> void:
	if player:
		var count := player.inventory_component.get_loot_count()
		inventory_label.text = "Loot: %d (bank it at the ship)" % count if count > 0 else ""
		_gold_changed(player.inventory_component.count("gold"))


# ---- Compass strip: at the helm, aboard, or with chart marks set ----
const COMPASS := preload("res://scripts/ui/compass_strip.gd")
## A chart mark this close (m, flat) is reached and cleared.
const MARK_REACHED := 25.0
var _compass: Control


func _build_compass() -> void:
	_compass = COMPASS.new()
	_compass.name = "Compass"
	_compass.visible = false
	add_child(_compass)


func _update_compass() -> void:
	if player == null:
		return
	var aboard: bool = ship != null and (player.context == Player.Context.HELM or (ship as Ship).aboard(player.global_position))
	_compass.visible = (aboard or not Net.waypoints.is_empty()) and not _menu_open and not _in_dialogue
	# (below the boss bar while it's up)
	_compass.offset_top = 34.0 if _boss_box.visible else 4.0
	_compass.offset_bottom = _compass.offset_top + COMPASS.H
	var mine: Array = Net.waypoints.get(Net.my_id(), [])
	var here := Vector2(player.global_position.x, player.global_position.z)
	for p in mine:
		if here.distance_to(p) < MARK_REACHED:
			Net.set_waypoints(mine.filter(func(q): return q != p))
			show_toast("Reached your mark")
			FX.sfx("blip_high", player.global_position, -6.0, 0.02, 1.1)
			break


# ---- Gold: shown for a few seconds whenever it changes ----
const GOLD_SHOW := 4.0
var _gold_box: HBoxContainer
var _gold_label: Label
var _gold_delta: Label
var _gold_seen: int = -1
var _gold_t: float = 0.0


func _build_gold() -> void:
	_gold_box = HBoxContainer.new()
	_gold_box.name = "Gold"
	_gold_box.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_gold_box.offset_left = -150; _gold_box.offset_top = 30; _gold_box.offset_bottom = 43; _gold_box.offset_right = -10
	_gold_box.alignment = BoxContainer.ALIGNMENT_END
	_gold_box.add_theme_constant_override("separation", 3)
	_gold_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_gold_delta = _tiny_label()
	_gold_delta.add_theme_font_size_override("font_size", 8)
	_gold_box.add_child(_gold_delta)
	var icon := TextureRect.new()
	icon.texture = load("res://assets/textures/icons/gold.png")
	icon.custom_minimum_size = Vector2(14, 14)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_gold_box.add_child(icon)
	_gold_label = _tiny_label()
	_gold_label.add_theme_font_size_override("font_size", 12)
	_gold_label.add_theme_color_override("font_color", UIStyle.ACCENT)
	_gold_box.add_child(_gold_label)
	_gold_box.modulate.a = 0.0
	add_child(_gold_box)


func _gold_changed(n: int) -> void:
	if _gold_box == null or n == _gold_seen:
		return
	if _gold_seen >= 0:
		var d := n - _gold_seen
		_gold_delta.text = "%+d" % d
		_gold_delta.add_theme_color_override("font_color", Color(0.6, 1.0, 0.5) if d > 0 else Color(1.0, 0.5, 0.4))
		_gold_t = GOLD_SHOW
		_bump(_gold_label)
	_gold_seen = n
	_gold_label.text = str(n)


func _update_gold(delta: float) -> void:
	_gold_t = maxf(_gold_t - delta, 0.0)
	# (always up with the inventory open)
	var keep: bool = GameMenu._current == "inventory"
	_gold_box.modulate.a = 1.0 if keep else clampf(_gold_t / 0.8, 0.0, 1.0)
	_gold_delta.visible = _gold_t > 0.0


# ---- Skill bar ----
var _menu_open: bool = false


func _build_skill_bar() -> void:
	_skill_bar = SkillBar.new()
	_skill_bar.name = "SkillBar"
	_skill_bar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_skill_bar.offset_left = -SkillBar.W * 0.5
	_skill_bar.offset_right = SkillBar.W * 0.5
	_skill_bar.offset_top = -SkillBar.H - 3.0
	_skill_bar.offset_bottom = -3.0
	add_child(_skill_bar)


# ---- Reticle ----
func _update_reticle() -> void:
	var visible_now: bool = player != null and player.context == Player.Context.ON_FOOT and not _in_dialogue \
		and Settings.get_value("gameplay", "reticle")
	_reticle.visible = visible_now
	if not visible_now:
		return
	var on_target := false
	if player.armed:
		var ray: Array = player.reticle_ray()
		if not ray.is_empty():
			var from: Vector3 = ray[0]
			var dir: Vector3 = ray[1]
			var reach := SHOOT_STATE.RANGE if player.weapon_class() == "gun" else 4.0
			from += dir * maxf((player.global_position - from).dot(dir), 0.0)
			# World too, so an enemy behind a wall doesn't light it up
			var q := PhysicsRayQueryParameters3D.create(from, from + dir * reach, 1 | 4)
			q.exclude = [player.get_rid()]
			var h := player.get_world_3d().direct_space_state.intersect_ray(q)
			on_target = not h.is_empty() and (h["collider"] as CollisionObject3D).collision_layer & 4 != 0
	_reticle.set_state(player.armed, on_target)


func _on_item_added(item: ItemData, quantity: int) -> void:
	_feed_add(item, quantity)


# ---- Pickup feed: "+3 Gold" rows in the top-right corner ----
const FEED_TIME := 3.5
const FEED_MAX := 5
var _feed: VBoxContainer
## item id -> [row, quantity, time left]
var _feed_rows: Dictionary = {}


func _build_feed() -> void:
	_feed = VBoxContainer.new()
	_feed.name = "PickupFeed"
	_feed.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_feed.offset_left = -150
	_feed.offset_right = -8
	_feed.offset_top = 47
	_feed.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_feed.alignment = BoxContainer.ALIGNMENT_BEGIN
	_feed.add_theme_constant_override("separation", 1)
	_feed.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_feed)


func _feed_add(item: ItemData, quantity: int) -> void:
	if _feed == null or item == null:
		return
	var key := item.id if item.id != "" else item.display_name
	if _feed_rows.has(key):
		var e: Array = _feed_rows[key]
		e[1] = int(e[1]) + quantity
		e[2] = FEED_TIME
		_feed_text(e)
		(e[0] as Control).modulate.a = 1.0
		_feed.move_child(e[0], _feed.get_child_count() - 1)
		_bump(e[0])
		return
	var row := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.03, 0.05, 0.62)
	sb.border_color = Color(UIStyle.ACCENT.r, UIStyle.ACCENT.g, UIStyle.ACCENT.b, 0.5)
	sb.border_width_left = 2
	sb.content_margin_left = 4
	sb.content_margin_right = 5
	sb.content_margin_top = 1
	sb.content_margin_bottom = 1
	row.add_theme_stylebox_override("panel", sb)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.size_flags_horizontal = Control.SIZE_SHRINK_END
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 4)
	row.add_child(hb)
	var ic := TextureRect.new()
	ic.texture = item.icon
	ic.custom_minimum_size = Vector2(12, 12)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	hb.add_child(ic)
	var lb := Label.new()
	lb.add_theme_font_override("font", load("res://assets/fonts/Silkscreen-Regular.woff2"))
	lb.add_theme_font_size_override("font_size", 8)
	lb.add_theme_color_override("font_outline_color", Color.BLACK)
	lb.add_theme_constant_override("outline_size", 3)
	hb.add_child(lb)
	_feed.add_child(row)
	var e := [row, quantity, FEED_TIME, lb, item]
	_feed_rows[key] = e
	_feed_text(e)
	_bump(row)
	# too many: the oldest goes first
	while _feed.get_child_count() > FEED_MAX:
		var old := _feed.get_child(0)
		for k in _feed_rows.keys():
			if _feed_rows[k][0] == old:
				_feed_rows.erase(k)
				break
		_feed.remove_child(old)
		old.queue_free()


func _feed_text(e: Array) -> void:
	var item: ItemData = e[4]
	var lb: Label = e[3]
	lb.text = "+%d %s" % [int(e[1]), item.display_name]
	lb.add_theme_color_override("font_color", item.rarity_color())
	lb.add_theme_color_override("font_outline_color", item.rarity_outline())


func _bump(c: Control) -> void:
	c.pivot_offset = Vector2(c.size.x, c.size.y * 0.5)
	c.scale = Vector2(1.15, 1.15)
	create_tween().tween_property(c, "scale", Vector2.ONE, 0.18)


func _update_feed(delta: float) -> void:
	if _feed == null:
		return
	_feed.visible = not _menu_open
	for k in _feed_rows.keys():
		var e: Array = _feed_rows[k]
		e[2] = float(e[2]) - delta
		var c: Control = e[0]
		if float(e[2]) < 0.6:
			c.modulate.a = clampf(float(e[2]) / 0.6, 0.0, 1.0)
		if float(e[2]) <= 0.0:
			_feed_rows.erase(k)
			c.queue_free()


## Called by GameMenu (the HUD is paused while menus are open): the inventory
## overlay has its own hotbar and uses the bottom of the screen.
func set_menu_open(open: bool) -> void:
	_menu_open = open
	if _skill_bar:
		_skill_bar.visible = not open
	toast.visible = not open
	banner.visible = not open
	if _objective:
		_objective.hidden_by_menu = open
	if _feed:
		_feed.visible = not open


# ---- Co-op: crew list, knocked-out / revive prompt ----
var _party: VBoxContainer
var _party_t: float = 0.0
var _my_ping: Label
var markers: MarkerLayer
var _prompt: Label
var _prompt_bar: ProgressBar


func _build_coop() -> void:
	_party = VBoxContainer.new()
	_party.name = "Party"
	_party.position = Vector2(8, 46)
	_party.add_theme_constant_override("separation", 2)
	_party.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_party)
	_my_ping = _tiny_label()
	_my_ping.visible = false
	_party.add_child(_my_ping)
	markers = MarkerLayer.new()
	markers.name = "Markers"
	add_child(markers)
	move_child(markers, 0)
	_prompt = UIStyle.label("", 12, UIStyle.TEXT)
	_prompt.add_theme_color_override("font_outline_color", Color.BLACK)
	_prompt.add_theme_constant_override("outline_size", 4)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.set_anchors_preset(Control.PRESET_CENTER)
	_prompt.offset_left = -160
	_prompt.offset_right = 160
	_prompt.offset_top = 40
	_prompt.offset_bottom = 58
	_prompt.visible = false
	add_child(_prompt)
	_prompt_bar = _bar(Color(0.95, 0.8, 0.35))
	_prompt_bar.set_anchors_preset(Control.PRESET_CENTER)
	_prompt_bar.offset_left = -50
	_prompt_bar.offset_right = 50
	_prompt_bar.offset_top = 60
	_prompt_bar.offset_bottom = 65
	_prompt_bar.max_value = 1.0
	_prompt_bar.visible = false
	add_child(_prompt_bar)


func _bar(fill: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.show_percentage = false
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.05, 0.04, 0.04, 0.8)
	bg.border_color = Color(0, 0, 0, 0.9)
	bg.set_border_width_all(1)
	var fg := StyleBoxFlat.new()
	fg.bg_color = fill
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fg)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return bar


func _tiny_label() -> Label:
	var l := UIStyle.label("", 8, UIStyle.TEXT)
	l.add_theme_font_override("font", load("res://assets/fonts/Silkscreen-Regular.woff2"))
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 3)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


# --------------------------------------------------------------------------
# Boss health and the ship's hull
# --------------------------------------------------------------------------
var _boss_box: VBoxContainer
var _boss_name: Label
var _boss_bar: ProgressBar
var _boss_ticks: Array = []
var _boss_shown: float = 0.0
var _hull_box: HBoxContainer
var _hull_bar: ProgressBar
var _hull_label: Label
const SAIL_GAUGE := preload("res://scripts/ui/sail_gauge.gd")
var _sail_gauge: Control
var _flood_bar: ProgressBar


func _build_bars() -> void:
	_boss_box = VBoxContainer.new()
	_boss_box.name = "BossBar"
	_boss_box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_boss_box.offset_left = -130
	_boss_box.offset_right = 130
	_boss_box.offset_top = 6
	_boss_box.add_theme_constant_override("separation", 1)
	_boss_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_box.visible = false
	add_child(_boss_box)
	_boss_name = UIStyle.label("", 12, Color(1.0, 0.85, 0.75))
	_boss_name.add_theme_color_override("font_outline_color", Color.BLACK)
	_boss_name.add_theme_constant_override("outline_size", 4)
	_boss_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boss_box.add_child(_boss_name)
	_boss_bar = _bar(Color(0.8, 0.12, 0.1))
	_boss_bar.custom_minimum_size = Vector2(260, 7)
	_boss_bar.max_value = 1.0
	_boss_box.add_child(_boss_bar)
	# phase marks at 60% and 30%
	for f in [0.6, 0.3]:
		var tick := ColorRect.new()
		tick.color = Color(1.0, 0.9, 0.7, 0.9)
		tick.size = Vector2(1, 7)
		tick.position = Vector2(260.0 * f, 0)
		tick.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_boss_bar.add_child(tick)
		_boss_ticks.append(tick)
	_hull_box = HBoxContainer.new()
	_hull_box.name = "Hull"
	_hull_box.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_hull_box.offset_left = -60
	_hull_box.offset_right = 60
	_hull_box.offset_top = -76
	_hull_box.offset_bottom = -68
	_hull_box.add_theme_constant_override("separation", 4)
	_hull_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hull_box.visible = false
	add_child(_hull_box)
	_hull_label = _tiny_label()
	_hull_label.text = "Hull"
	_hull_box.add_child(_hull_label)
	_hull_bar = _bar(Color(0.75, 0.55, 0.3))
	_hull_bar.custom_minimum_size = Vector2(90, 5)
	_hull_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_hull_bar.max_value = 1.0
	_hull_box.add_child(_hull_bar)
	# water in her (holed): fills up blue
	_flood_bar = _bar(Color(0.3, 0.55, 0.95))
	_flood_bar.custom_minimum_size = Vector2(40, 5)
	_flood_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_flood_bar.max_value = 1.0
	_flood_bar.visible = false
	_hull_box.add_child(_flood_bar)
	_sail_gauge = SAIL_GAUGE.new()
	_sail_gauge.name = "SailGauge"
	_sail_gauge.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_sail_gauge.offset_left = -76
	_sail_gauge.offset_top = -150
	_sail_gauge.offset_right = -12
	_sail_gauge.offset_bottom = -76
	_sail_gauge.visible = false
	add_child(_sail_gauge)


## The boss's name and health across the top (phase marks on the bar).
func show_boss(boss_name: String, frac: float, phase: int) -> void:
	if _boss_box == null:
		return
	_boss_box.visible = not _menu_open
	_boss_name.text = boss_name
	var prev := _boss_bar.value
	_boss_bar.value = clampf(frac, 0.0, 1.0)
	if _boss_bar.value < prev - 0.001:
		_boss_bar.modulate = Color(1.6, 1.6, 1.6)
	else:
		_boss_bar.modulate = _boss_bar.modulate.lerp(Color.WHITE, 0.2)
	for i in range(_boss_ticks.size()):
		(_boss_ticks[i] as ColorRect).visible = phase <= i + 1


func hide_boss() -> void:
	if _boss_box:
		_boss_box.visible = false


## The ship's hull, while you're aboard (or it's damaged and you're near).
func _update_hull() -> void:
	if _hull_box == null or player == null or ship == null or not is_instance_valid(ship):
		return
	var hull: float = float(ship.get("hull")) if ship.get("hull") != null else -1.0
	if hull < 0.0:
		return
	var mx: float = (ship as Ship).max_hull
	var aboard := player.context != Player.Context.ON_FOOT or player.global_position.distance_to(ship.global_position) < 9.0
	_sail_gauge.ship = ship
	_sail_gauge.visible = (player.context == Player.Context.HELM or (ship as Ship).aboard(player.global_position)) and not _menu_open and not _in_dialogue
	var flood: float = float(ship.get("flood"))
	_hull_box.visible = aboard and not _menu_open and not _in_dialogue and (hull < mx - 0.5 or flood > 0.0 or player.context != Player.Context.ON_FOOT)
	if _hull_box.visible:
		_hull_bar.value = hull / mx
		_flood_bar.visible = flood > 0.005
		_flood_bar.value = flood
		var crippled: bool = bool(ship.get("crippled"))
		_hull_label.text = "Hull!" if crippled else "Hull"
		_hull_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.3) if crippled else UIStyle.TEXT)


## A crew marker (Net.mark): a diamond over the spot / enemy.
func add_marker(id: int, who: String, pos: Vector3, target: Node) -> void:
	if markers == null:
		return
	var col: Color = Net.crew_color(id) if Net.active else Color(1.0, 0.85, 0.3)
	markers.add(id, who, pos, target, col)
	FX.sparkle(pos, 10, col)
	FX.sfx("blip_high", pos, -8.0, 0.02, 1.35)


func remove_marker(id: int) -> void:
	if markers:
		markers.markers.erase(id)


static func ping_color(ms: int) -> Color:
	if ms < 0:
		return UIStyle.TEXT_DIM
	if ms < 90:
		return Color(0.55, 0.95, 0.5)
	if ms < 180:
		return Color(1.0, 0.85, 0.35)
	return Color(1.0, 0.4, 0.35)


## A centered prompt with an optional progress bar (progress < 0: none).
## Empty text hides it.
func show_prompt(text: String, progress: float = -1.0) -> void:
	if _prompt == null:
		return
	if text.begins_with("Hold F: "):
		var job := text.trim_prefix("Hold F: ")
		_hold_text = job.substr(0, 1).to_upper() + job.substr(1)
		_hold_bar.value = maxf(progress, 0.0)
		_prompt.visible = false
		_prompt_bar.visible = false
		_show_interact()
		return
	if _hold_text != "":
		_hold_text = ""
		_show_interact()
	_prompt.text = text
	_prompt.visible = text != ""
	_prompt_bar.visible = text != "" and progress >= 0.0
	if progress >= 0.0:
		_prompt_bar.value = progress


## The rest of the crew: name, health, and whether they're down.
func _update_party(delta: float) -> void:
	_party_t -= delta
	if _party_t > 0.0 or _party == null:
		return
	_party_t = 0.2
	var others: Array = []
	if Net.active:
		for p in Net.all_players():
			if p != player:
				others.append(p)
	# your own ping (co-op guests) above the crew
	var mine := Net.ping_ms(Net.my_id()) if Net.active and not Net.hosting else -1
	_my_ping.visible = mine >= 0 and not others.is_empty()
	if _my_ping.visible:
		_my_ping.text = "Ping %dms" % mine
		_my_ping.add_theme_color_override("font_color", ping_color(mine))
	var rows := _party.get_child_count() - 1
	while rows > others.size():
		var c := _party.get_child(_party.get_child_count() - 1)
		_party.remove_child(c)
		c.queue_free()
		rows -= 1
	while rows < others.size():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		var sw := ColorRect.new()
		sw.custom_minimum_size = Vector2(3, 7)
		sw.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(sw)
		var nm := _tiny_label()
		nm.custom_minimum_size = Vector2(70, 0)
		row.add_child(nm)
		var bar := _bar(Color(0.85, 0.25, 0.2))
		bar.custom_minimum_size = Vector2(54, 5)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(bar)
		var pg := _tiny_label()
		pg.custom_minimum_size = Vector2(34, 0)
		pg.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(pg)
		_party.add_child(row)
		rows += 1
	for i in range(others.size()):
		var p = others[i]
		var row := _party.get_child(i + 1)
		var sw := row.get_child(0) as ColorRect
		var nm := row.get_child(1) as Label
		var bar := row.get_child(2) as ProgressBar
		var pg := row.get_child(3) as Label
		var down: bool = p.is_bleeding()
		sw.color = Net.crew_color(int(p.net_id))
		nm.text = str(p.display_name()) + (" (down)" if down else "")
		nm.modulate = Color(1.0, 0.5, 0.4) if down else Color.WHITE
		bar.max_value = maxf(p.health_component.max_health, 1.0)
		bar.value = p.health_component.current_health
		var ms := Net.ping_ms(int(p.net_id))
		pg.text = "host" if int(p.net_id) == 1 else ("%dms" % ms if ms >= 0 else "...")
		pg.add_theme_color_override("font_color", UIStyle.TEXT_DIM if int(p.net_id) == 1 else ping_color(ms))
