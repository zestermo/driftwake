extends PlayerState
## Reading the map (M, MapHold): the captain unrolls it at the chest and the camera tilts down onto it
## over the right shoulder. You walk slowly with it (WASD, the way the camera faces; the mouse is a pen
## on the page, and pushed past its side turns you). M again rolls it up quickly; a jump, a dodge,
## falling or a hit (Player puts you in Stagger) ends it there and then.

const SPEED := 2.2
const OPEN_SECS := 0.34
const AWAY_SECS := 0.2

var _t := 0.0
var _closing := false


func enter(_data: Dictionary) -> void:
	player.sprinting = false
	player.sheathe_weapon(true)
	_t = 0.0
	_closing = false
	# (a touch longer than it takes: map_hold takes over before it ends)
	player.body_model.play("map_open", OPEN_SECS + 0.1)
	MapHold.of(player).opened()


func physics_update(delta: float) -> void:
	apply_gravity(delta)
	_t += delta
	if not _closing and _t >= OPEN_SECS and player.body_model.current_action() != "map_hold":
		player.body_model.hold("map_hold")
	var input := get_movement_input()
	if input.length() > 0.1:
		var dir := get_camera_relative_direction(input)
		var speed := SPEED * player.wade_mult()
		player.velocity.x = dir.x * speed
		player.velocity.z = dir.z * speed
	else:
		player.velocity.x = move_toward(player.velocity.x, 0.0, player.deceleration * delta)
		player.velocity.z = move_toward(player.velocity.z, 0.0, player.deceleration * delta)
	player.move_and_slide()
	face_direction(MapHold.of(player).facing(), delta)
	if _closing and _t >= AWAY_SECS:
		transitioned.emit(self, "Idle" if input.length() < 0.1 else "Move", {})
		return
	if not player.is_on_floor():
		transitioned.emit(self, "Fall", {})
		return
	if wants_jump():
		transitioned.emit(self, "Jump", {})
		return
	if wants_dodge():
		transitioned.emit(self, "Dodge", {})


## M again: rolled up and away (the camera's already on its way back).
func put_away() -> void:
	if _closing:
		return
	_closing = true
	_t = 0.0
	player.body_model.play("map_away", AWAY_SECS)
	MapHold.of(player).closed()


func exit() -> void:
	if not _closing:
		MapHold.of(player).closed()
		if player.body_model.current_action().begins_with("map_"):
			player.body_model.stop_action()
	_closing = false
