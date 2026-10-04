extends CanvasLayer
## Low-res PSX HUD: health, loot count, ship compass, interaction prompt,
## island title banners, toasts, hotbar and reticle. F4 toggles the debug state label.

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
var _hotbar_box: HBoxContainer
var _hotbar_slots: Array[Button] = []
var _reticle: Reticle
var _fps: Label
var _in_dialogue: bool = false
var _stamina_bar: ProgressBar
var _stamina_fill: StyleBoxFlat
var _stamina_flash: float = 0.0
const STAMINA_COLOR := Color(0.36, 0.78, 0.32)
const STAMINA_EMPTY_COLOR := Color(0.85, 0.62, 0.18)


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
	_build_hotbar()
	_build_stamina()
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
	Dialogue.dialogue_started.connect(func(_id): _in_dialogue = true)
	Dialogue.dialogue_ended.connect(func(_id): _in_dialogue = false)
	await get_tree().process_frame
	player = get_tree().get_first_node_in_group("player")
	ship = get_tree().get_first_node_in_group("ship")
	if player:
		health_bar.max_value = player.health_component.max_health
		health_bar.value = player.health_component.current_health
		player.health_component.health_changed.connect(_on_health_changed)
		player.stamina_changed.connect(_on_stamina_changed)
		player.stamina_denied.connect(func(): _stamina_flash = 0.45)
		_on_stamina_changed(player.stamina, player.max_stamina)
		player.interaction_component.prompt_changed.connect(_on_prompt_changed)
		player.interaction_component.prompt_hidden.connect(_on_prompt_hidden)
		player.inventory_component.inventory_changed.connect(_on_inventory_changed)
		player.inventory_component.item_added.connect(_on_item_added)
		player.inventory_component.hotbar_changed.connect(_refresh_hotbar)
		player.inventory_component.inventory_changed.connect(_refresh_hotbar)
		player.armed_changed.connect(func(_a): _refresh_hotbar())
		player.weapon_changed.connect(func(_w): _refresh_hotbar())
		_refresh_hotbar()
		_on_inventory_changed()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F4:
		state_label.visible = not state_label.visible


func _process(_delta: float) -> void:
	_update_reticle()
	_update_stamina_flash(_delta)
	var show_hotbar: bool = not _in_dialogue and player != null and player.context == Player.Context.ON_FOOT
	_hotbar_box.visible = show_hotbar
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


# ---- Hotbar ----
func _build_hotbar() -> void:
	_hotbar_box = HBoxContainer.new()
	_hotbar_box.add_theme_constant_override("separation", 2)
	_hotbar_box.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_hotbar_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_hotbar_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_hotbar_box.offset_top = -36
	_hotbar_box.offset_bottom = -6
	_hotbar_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hotbar_box)
	for i in range(InventoryComponent.HOTBAR_SIZE):
		var slot := GameMenu.make_slot(30)
		slot.focus_mode = Control.FOCUS_NONE
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_hotbar_box.add_child(slot)
		_hotbar_slots.append(slot)


func _refresh_hotbar() -> void:
	if player == null:
		return
	var inv := player.inventory_component
	for i in range(_hotbar_slots.size()):
		var item := inv.get_hotbar_item(i)
		var equipped := item != null and item == player.equipped_weapon and player.armed
		GameMenu.set_slot(_hotbar_slots[i], item, inv.count(item.id) if item else 0, str(i + 1), equipped)


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


# --------------------------------------------------------------------------
# Stamina
# --------------------------------------------------------------------------
## A thin bar under the health bar (same frame style), green while there's
## stamina, amber once it's run dry; flashes red when an action is refused.
func _build_stamina() -> void:
	var row := HBoxContainer.new()
	row.name = "StaminaRow"
	var lab := Label.new()
	lab.text = "ST"
	lab.label_settings = $Top/VBox/HealthRow/HP.label_settings
	row.add_child(lab)
	_stamina_bar = ProgressBar.new()
	_stamina_bar.name = "StaminaBar"
	_stamina_bar.custom_minimum_size = Vector2(110, 7)
	_stamina_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_stamina_bar.show_percentage = false
	_stamina_bar.max_value = 100.0
	_stamina_bar.value = 100.0
	_stamina_bar.add_theme_stylebox_override("background", health_bar.get_theme_stylebox("background"))
	_stamina_fill = StyleBoxFlat.new()
	_stamina_fill.bg_color = STAMINA_COLOR
	_stamina_bar.add_theme_stylebox_override("fill", _stamina_fill)
	row.add_child(_stamina_bar)
	var vbox := $Top/VBox
	vbox.add_child(row)
	vbox.move_child(row, $Top/VBox/HealthRow.get_index() + 1)


func _on_stamina_changed(current: float, maximum: float) -> void:
	if _stamina_bar == null:
		return
	_stamina_bar.max_value = maximum
	_stamina_bar.value = current


func _update_stamina_flash(delta: float) -> void:
	if _stamina_fill == null or player == null:
		return
	var base := STAMINA_EMPTY_COLOR if (player.stamina < player.LIGHT_COST or player.winded) else STAMINA_COLOR
	if _stamina_flash > 0.0:
		_stamina_flash -= delta
		var on := int(_stamina_flash * 16.0) % 2 == 0
		_stamina_fill.bg_color = Color(0.9, 0.2, 0.15) if on else base
		_stamina_bar.modulate = Color(1.4, 0.7, 0.7) if on else Color.WHITE
	else:
		_stamina_fill.bg_color = base
		_stamina_bar.modulate = Color.WHITE


## Called by GameMenu (the HUD is paused while menus are open): the inventory
## overlay has its own hotbar and uses the bottom of the screen.
func set_menu_open(open: bool) -> void:
	if _hotbar_box:
		_hotbar_box.visible = not open
	toast.visible = not open
	banner.visible = not open
