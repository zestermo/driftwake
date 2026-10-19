extends PlayerState
## A downtime activity (Downtime, from the action wheel): the body holds its loop (DowntimePoses) and every
## interval of it the captain earns its reward. Some take you to their spot aboard first (the rail to fish, the
## bunk to sleep; settled over SETTLE s and carried with the hull), some sit you on a crate. Any move, jump,
## dodge, attack or F gets you up; so does danger (Downtime.danger, checked twice a second) or a blow, with a
## word on why.

const CHECK_SECS := 0.5
## A moment before input can end it (the wheel's release).
const COOL := 0.35
const SETTLE := 0.35

var kind := ""
var _pose := ""
var _t := 0.0
var _earned := 0.0
var _check := 0.0
var _hp := 0.0
var _ship: Ship
## Ship-local: where you were, the activity's spot and facing (none: stay where you stand).
var _from := Vector3.ZERO
var _spot: Array = []
var _yaw_from := 0.0


func enter(data: Dictionary) -> void:
	kind = str(data["kind"])
	_pose = Downtime.pose_of(player, kind)
	_t = 0.0
	_earned = 0.0
	_check = CHECK_SECS
	_hp = player.health_component.current_health
	player.velocity = Vector3.ZERO
	player.sprinting = false
	if kind == "train":
		player.draw_weapon(true)
	else:
		player.sheathe_weapon(true)
	var seat := Downtime.seat_of(kind)
	player.body_model.seated = seat > 0.0
	player.body_model.seat_y = seat
	_ship = Downtime.ship_under(player)
	_spot = Downtime.spot(player, kind, _ship) if _ship else []
	if not _spot.is_empty():
		_from = _ship.global_transform.affine_inverse() * player.global_position
		_yaw_from = player.player_model.rotation.y
	player.body_model.hold(_pose, 0.4)


func physics_update(delta: float) -> void:
	if _spot.is_empty():
		apply_gravity(delta)
		player.velocity.x = 0.0
		player.velocity.z = 0.0
		player.move_and_slide()
	else:
		_pin()
	_t += delta
	_earned += delta
	Downtime.tick(player, kind, delta)
	if _earned >= Downtime.every(player, kind):
		_earned = 0.0
		Downtime.reward(player, kind)
	# (back to the loop after a one-off, the fish's reel-in)
	if player.body_model.current_action() == "":
		player.body_model.hold(_pose, 0.25)
	if player.health_component.current_health < _hp:
		_stop("")
		return
	_hp = player.health_component.current_health
	_check -= delta
	if _check <= 0.0:
		_check = CHECK_SECS
		var why := Downtime.danger(player, kind)
		if why != "":
			_stop(why)
			return
	if _t < COOL:
		return
	if get_movement_input().length() > 0.3 or Input.is_action_just_pressed("jump") or Input.is_action_just_pressed("interact") \
			or input_buffer.has_action("dodge") or input_buffer.has_action("light_attack") or input_buffer.has_action("heavy_attack"):
		transitioned.emit(self, "Idle", {})


## Eased onto the spot, then held there as the hull moves (its last-step lag, like the helm's).
func _pin() -> void:
	var k := clampf(_t / SETTLE, 0.0, 1.0)
	var e := k * k * (3.0 - 2.0 * k)
	var at: Vector3 = _from.lerp(_spot[0], e)
	player.global_position = _ship.deck_delta() * (_ship.global_transform * at)
	player.player_model.rotation.y = lerp_angle(_yaw_from, _ship.global_rotation.y + float(_spot[1]), e)
	player.velocity = Vector3.ZERO


## Roused: on your feet with a start, and why.
func _stop(why: String) -> void:
	if why != "":
		player.call("_toast", why)
		FX.sfx("bell", player.global_position + Vector3.UP * 3.0, -6.0, 0.02, 1.2)
	transitioned.emit(self, "Idle", {})
	player.body_model.play("dt_startle", 0.5)


func exit() -> void:
	player.body_model.seated = false
	if player.body_model.current_action() in [_pose, "dt_fish_reel"]:
		player.body_model.stop_action()
	if not _spot.is_empty() and is_instance_valid(_ship):
		player.global_position = _ship.global_transform * Downtime.leave_spot(kind, _spot[0])
		player.reset_physics_interpolation()
	_spot = []
	_ship = null
