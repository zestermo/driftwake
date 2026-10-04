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
var _fps: Label
var _in_dialogue: bool = false


func _ready() -> void:
	add_to_group("hud")
	state_label.visible = false
	banner.modulate.a = 0.0
	toast.modulate.a = 0.0
	interact_panel.visible = false
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
	_fps.offset_left = -60; _fps.offset_top = 28; _fps.offset_right = -10
	_fps.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_fps)
	_build_coop()
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
	var show_bar: bool = not _in_dialogue and player != null and player.context == Player.Context.ON_FOOT
	_skill_bar.visible = show_bar and not _menu_open
	toast.visible = true
	_fps.visible = Settings.get_value("video", "show_fps")
	if _fps.visible:
		_fps.text = "%d FPS" % Engine.get_frames_per_second()
	if state_label.visible and player and player.state_machine and player.state_machine.current_state:
		state_label.text = player.state_machine.current_state.name

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


func _on_prompt_changed(text: String) -> void:
	interact_label.text = "[F] " + text
	interact_panel.visible = true
	interact_panel.reset_size()
	interact_panel.position.x = (get_viewport().get_visible_rect().size.x - interact_panel.size.x) * 0.5


func _on_prompt_hidden() -> void:
	interact_panel.visible = false


func _on_inventory_changed() -> void:
	if player:
		var count := player.inventory_component.get_loot_count()
		inventory_label.text = "Loot: %d (bank it at the ship)" % count if count > 0 else ""


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
		var cam := get_viewport().get_camera_3d()
		if cam:
			var from := cam.global_position
			var to := from - cam.global_basis.z * (cam.global_position.distance_to(player.global_position) + 4.0)
			var q := PhysicsRayQueryParameters3D.create(from, to, 4)  # EnemyBody layer
			q.exclude = [player.get_rid()]
			on_target = not player.get_world_3d().direct_space_state.intersect_ray(q).is_empty()
	_reticle.set_state(player.armed, on_target)


func _on_item_added(item: ItemData, quantity: int) -> void:
	show_toast("+%d %s" % [quantity, item.display_name])


## Called by GameMenu (the HUD is paused while menus are open): the inventory
## overlay has its own hotbar and uses the bottom of the screen.
func set_menu_open(open: bool) -> void:
	_menu_open = open
	if _skill_bar:
		_skill_bar.visible = not open
	toast.visible = not open
	banner.visible = not open


# ---- Co-op: crew list, knocked-out / revive prompt ----
var _party: VBoxContainer
var _party_t: float = 0.0
var _prompt: Label
var _prompt_bar: ProgressBar


func _build_coop() -> void:
	_party = VBoxContainer.new()
	_party.name = "Party"
	_party.position = Vector2(8, 46)
	_party.add_theme_constant_override("separation", 2)
	_party.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_party)
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


## A centered prompt with an optional progress bar (progress < 0: none).
## Empty text hides it.
func show_prompt(text: String, progress: float = -1.0) -> void:
	if _prompt == null:
		return
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
	while _party.get_child_count() > others.size():
		var c := _party.get_child(_party.get_child_count() - 1)
		_party.remove_child(c)
		c.queue_free()
	while _party.get_child_count() < others.size():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		var nm := UIStyle.label("", 8, UIStyle.TEXT)
		nm.add_theme_font_override("font", load("res://assets/fonts/Silkscreen-Regular.woff2"))
		nm.add_theme_color_override("font_outline_color", Color.BLACK)
		nm.add_theme_constant_override("outline_size", 3)
		nm.custom_minimum_size = Vector2(70, 0)
		row.add_child(nm)
		var bar := _bar(Color(0.85, 0.25, 0.2))
		bar.custom_minimum_size = Vector2(54, 5)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(bar)
		_party.add_child(row)
	for i in range(others.size()):
		var p = others[i]
		var row := _party.get_child(i)
		var nm := row.get_child(0) as Label
		var bar := row.get_child(1) as ProgressBar
		var down: bool = p.is_bleeding()
		nm.text = str(p.display_name()) + (" (down)" if down else "")
		nm.modulate = Color(1.0, 0.5, 0.4) if down else Color.WHITE
		bar.max_value = maxf(p.health_component.max_health, 1.0)
		bar.value = p.health_component.current_health
