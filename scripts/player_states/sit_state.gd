extends PlayerState
## Sitting: on a Seat (Player.sit) or on the ground anywhere (Player.sit_ground,
## the emote wheel). Settles onto the seat over SETTLE s, facing the way the seat
## faces; any move input, jump, dodge, an attack or F gets you up again, back on
## the spot you sat down from (it rides along with the seat: a ship's).

const SETTLE := 0.3
## The ground sit's "seat" height (Humanoid's floor-sit pose below 0.25).
const GROUND_Y := 0.1

var seat: Seat
## Where you stood when you sat down, in the seat's parent's frame.
var _from := Vector3.ZERO
var _yaw_from: float = 0.0
var _yaw: float = 0.0
var _k: float = 0.0
var _cool: float = 0.0


func enter(data: Dictionary) -> void:
	seat = data.get("seat") as Seat
	if player.armed:
		player.sheathe_weapon()
	player.velocity = Vector3.ZERO
	player.sprinting = false
	player.body_model.stop_action()
	player.body_model.seated = true
	player.body_model.seat_y = seat.height if seat else GROUND_Y
	_yaw_from = player.player_model.rotation.y
	_yaw = _yaw_from
	if seat:
		_from = _frame().affine_inverse() * player.global_position
		var f := seat.facing_for(player.global_position)
		_yaw = atan2(-f.x, -f.z)
	_k = 0.0
	_cool = 0.35


func _frame() -> Transform3D:
	return (seat.get_parent() as Node3D).global_transform


func physics_update(delta: float) -> void:
	if seat != null and not is_instance_valid(seat):
		seat = null
		transitioned.emit(self, "Idle", {})
		return
	_k = minf(_k + delta / SETTLE, 1.0)
	var e := _k * _k * (3.0 - 2.0 * _k)
	player.player_model.rotation.y = lerp_angle(_yaw_from, _yaw, e)
	if seat:
		player.global_position = (_frame() * _from).lerp(seat.floor_point(), e)
		player.velocity = Vector3.ZERO
	else:
		apply_gravity(delta)
		player.velocity.x = 0.0
		player.velocity.z = 0.0
		player.move_and_slide()
	if _cool > 0.0:
		_cool -= delta
		return
	if get_movement_input().length() > 0.3 or player.inp.just_pressed("jump") or player.inp.just_pressed("interact") \
			or input_buffer.has_action("dodge") or input_buffer.has_action("light_attack") or input_buffer.has_action("heavy_attack"):
		transitioned.emit(self, "Idle", {})


func exit() -> void:
	player.body_model.seated = false
	if seat and is_instance_valid(seat):
		Net.release_seat(seat)
		player.global_position = _frame() * _from + Vector3.UP * 0.05
		player.reset_physics_interpolation()
	seat = null
