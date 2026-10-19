extends PlayerState
## A downtime activity (Downtime, from the action wheel): the body holds its loop (DowntimePoses) and every
## interval of it the captain earns its reward. Any move, jump, dodge, attack or F gets you up; so does
## danger (Downtime.danger, checked twice a second) or a blow, with a word on why.

const CHECK_SECS := 0.5
## A moment before input can end it (the wheel's release).
const COOL := 0.35

var kind := ""
var _pose := ""
var _t := 0.0
var _earned := 0.0
var _check := 0.0
var _hp := 0.0


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
	player.body_model.hold(_pose, 0.4)


func physics_update(delta: float) -> void:
	apply_gravity(delta)
	player.velocity.x = 0.0
	player.velocity.z = 0.0
	player.move_and_slide()
	_t += delta
	_earned += delta
	var every: float = Downtime.KINDS[kind]["every"]
	if _earned >= every:
		_earned -= every
		Downtime.reward(player, kind)
	if player.health_component.current_health < _hp:
		_stop("")
		return
	_hp = player.health_component.current_health
	_check -= delta
	if _check <= 0.0:
		_check = CHECK_SECS
		var why := Downtime.danger(player)
		if why != "":
			_stop(why)
			return
	if _t < COOL:
		return
	if get_movement_input().length() > 0.3 or Input.is_action_just_pressed("jump") or Input.is_action_just_pressed("interact") \
			or input_buffer.has_action("dodge") or input_buffer.has_action("light_attack") or input_buffer.has_action("heavy_attack"):
		transitioned.emit(self, "Idle", {})


## Roused: on your feet with a start, and why.
func _stop(why: String) -> void:
	if why != "":
		player.call("_toast", why)
		FX.sfx("bell", player.global_position + Vector3.UP * 3.0, -6.0, 0.02, 1.2)
	transitioned.emit(self, "Idle", {})
	player.body_model.play("dt_startle", 0.5)


func exit() -> void:
	if player.body_model.current_action() == _pose:
		player.body_model.stop_action()
