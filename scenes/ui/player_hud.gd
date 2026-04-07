extends CanvasLayer

@onready var health_bar: ProgressBar = $MarginContainer/VBoxContainer/HealthBar
@onready var health_label: Label = $MarginContainer/VBoxContainer/HealthBar/Label
@onready var state_label: Label = $MarginContainer/VBoxContainer/StateLabel
@onready var interact_label: Label = $InteractPrompt
@onready var inventory_label: Label = $MarginContainer/VBoxContainer/InventoryLabel
@onready var compass_label: Label = $CompassContainer/CompassLabel
@onready var compass_arrow: Label = $CompassContainer/CompassArrow
@onready var compass_dist: Label = $CompassContainer/CompassDist

var player: Player
var ship: Node3D


func _ready() -> void:
	await get_tree().process_frame
	player = get_tree().get_first_node_in_group("player")
	ship = get_tree().get_first_node_in_group("ship")
	if player:
		health_bar.max_value = player.health_component.max_health
		health_bar.value = player.health_component.current_health
		player.health_component.health_changed.connect(_on_health_changed)
		player.interaction_component.prompt_changed.connect(_on_prompt_changed)
		player.interaction_component.prompt_hidden.connect(_on_prompt_hidden)
		player.inventory_component.inventory_changed.connect(_on_inventory_changed)
	interact_label.visible = false


func _process(_delta: float) -> void:
	if player and player.state_machine and player.state_machine.current_state:
		state_label.text = player.state_machine.current_state.name

	# Ship compass
	if player and ship:
		var to_ship := ship.global_position - player.global_position
		var dist := Vector2(to_ship.x, to_ship.z).length()
		compass_dist.text = "%dm" % int(dist)

		if dist > 20.0:
			# Get camera forward direction on XZ
			var camera := player.get_viewport().get_camera_3d()
			if camera:
				var cam_fwd := Vector2(-camera.global_basis.z.x, -camera.global_basis.z.z).normalized()
				var ship_dir := Vector2(to_ship.x, to_ship.z).normalized()
				var angle := cam_fwd.angle_to(ship_dir)

				# Arrow character based on angle
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
			compass_arrow.text = "•"


func _on_health_changed(current: float, maximum: float) -> void:
	health_bar.max_value = maximum
	health_bar.value = current
	health_label.text = "%d / %d" % [int(current), int(maximum)]


func _on_prompt_changed(text: String) -> void:
	interact_label.text = "[F] " + text
	interact_label.visible = true


func _on_prompt_hidden() -> void:
	interact_label.visible = false


func _on_inventory_changed() -> void:
	if player:
		var count := player.inventory_component.get_total_items()
		inventory_label.text = "Loot: %d items" % count if count > 0 else ""
