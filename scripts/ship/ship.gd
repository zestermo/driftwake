extends RigidBody3D
class_name Ship

@export var thrust_force: float = 4000.0
@export var turn_torque: float = 1200.0
@export var visual_tilt_speed: float = 3.0
@export var max_tilt_degrees: float = 8.0

var is_player_steering: bool = false
var _ocean: Node
var _game_manager: Node

@onready var ship_model: Node3D = $ShipModel
@onready var helm_position: Marker3D = $ShipModel/HelmPosition
@onready var bank_position: Marker3D = $ShipModel/BankPosition
@onready var disembark_position: Marker3D = $ShipModel/DisembarkPosition
@onready var respawn_point: Marker3D = $RespawnPoint
@onready var helm_zone: Interactable = $HelmZone
@onready var bank_zone: Interactable = $BankZone
@onready var ship_camera: Node3D = $ShipCamera


func _ready() -> void:
	_ocean = get_node("/root/Ocean")
	_game_manager = get_node("/root/GameManager")
	helm_zone.interacted.connect(_on_helm_interacted)
	bank_zone.interacted.connect(_on_bank_interacted)


func _physics_process(delta: float) -> void:
	if is_player_steering:
		var forward_input := 0.0
		if Input.is_action_pressed("move_forward"):
			forward_input = 1.0
		elif Input.is_action_pressed("move_back"):
			forward_input = -1.0

		var turn_input := 0.0
		if Input.is_action_pressed("move_right"):
			turn_input = 1.0
		elif Input.is_action_pressed("move_left"):
			turn_input = -1.0

		if forward_input != 0.0:
			var forward := Vector3(-sin(global_rotation.y), 0.0, -cos(global_rotation.y))
			apply_central_force(forward * forward_input * thrust_force)

		if turn_input != 0.0:
			apply_torque(Vector3.UP * -turn_input * turn_torque)

	_apply_visual_tilt(delta)


func _apply_visual_tilt(delta: float) -> void:
	if not _ocean:
		return
	var time := Time.get_ticks_msec() / 1000.0
	var wave_normal: Vector3 = _ocean.get_wave_normal(global_position, time)

	var max_tilt := deg_to_rad(max_tilt_degrees)
	var target_pitch := clampf(asin(-wave_normal.z), -max_tilt, max_tilt)
	var target_roll := clampf(asin(wave_normal.x), -max_tilt, max_tilt)

	ship_model.rotation.x = lerp(ship_model.rotation.x, target_pitch, visual_tilt_speed * delta)
	ship_model.rotation.z = lerp(ship_model.rotation.z, target_roll, visual_tilt_speed * delta)


func _on_helm_interacted(player: Player) -> void:
	if player.context == Player.Context.ON_FOOT:
		player.current_ship = self
		var sm := player.state_machine
		if sm.current_state:
			sm.current_state.transitioned.emit(sm.current_state, "Helm", {})


func _on_bank_interacted(_player: Player) -> void:
	var count: int = _game_manager.bank_items()
	if count > 0:
		print("Banked %d items!" % count)
	else:
		print("Nothing to bank.")
