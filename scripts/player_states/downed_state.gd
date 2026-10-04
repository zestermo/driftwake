extends PlayerState
## Thrown off your feet by a heavy hit, or dead.
## The body becomes a physics ragdoll; the player's root follows the hips so
## the camera tracks the tumble. Once the body has come to rest the character
## gets back up from wherever it landed. Dead bodies stay down until the
## respawn (GameManager) forces the Idle state.

const MIN_DOWN := 0.9
const MAX_DOWN := 3.0

var timer: float = 0.0
var dead: bool = false
var getting_up: bool = false
var getup_time: float = 0.0
var _rest: float = 0.0
var _landed: bool = false
var _prev_vy: float = 0.0


func enter(data: Dictionary) -> void:
	timer = 0.0
	_rest = 0.0
	_landed = false
	_prev_vy = 0.0
	getting_up = false
	dead = bool(data.get("dead", false))
	player.velocity = Vector3.ZERO
	player.sprinting = false
	player.is_parrying = false
	player.hurtbox.monitorable = false
	player.sword_hitbox.deactivate()
	player.reset_combo()
	var v: Vector3 = data.get("velocity", Vector3.ZERO)
	var spin := Vector3.UP.cross(Vector3(v.x, 0, v.z).normalized()) * 5.0 if v.length() > 0.1 else Vector3.ZERO
	player.body_model.start_ragdoll(v, spin)
	FX.sfx("whoosh_big", player.global_position, -8.0, 0.1, 0.8)


func physics_update(delta: float) -> void:
	timer += delta
	if getting_up:
		apply_gravity(delta)
		player.velocity.x = 0.0
		player.velocity.z = 0.0
		player.move_and_slide()
		if timer >= getup_time:
			transitioned.emit(self, "Idle", {})
		return
	var rag := player.body_model.ragdoll
	if rag == null:
		transitioned.emit(self, "Idle", {})
		return
	# follow the hips so the camera (and the hurtbox) stay with the body
	var hips := player.body_model.hips.global_position
	var to := hips - player.global_position
	to.y = 0.0
	player.velocity.x = to.x * 10.0
	player.velocity.z = to.z * 10.0
	apply_gravity(delta)
	player.move_and_slide()
	# a thud when the body first hits the ground
	var rb := rag.root_body()
	var vy := rb.linear_velocity.y if rb else 0.0
	if not _landed and timer > 0.1 and vy - _prev_vy > 2.0:
		_landed = true
		FX.sfx("thud", hips, -2.0, 0.1, 0.85)
		FX.dust_ring(Vector3(hips.x, player.global_position.y, hips.z), 12, 0.8)
		get_node("/root/CombatManager").apply_camera_shake(0.12)
	_prev_vy = vy
	if dead:
		return
	if rag.settled():
		_rest += delta
	else:
		_rest = 0.0
	if timer > MIN_DOWN and (_rest > 0.25 or timer > MAX_DOWN):
		getting_up = true
		timer = 0.0
		getup_time = player.get_up_from_ragdoll()


func exit() -> void:
	player.hurtbox.monitorable = true
	if player.body_model.ragdoll != null:
		player.body_model.reset_pose()
	elif getting_up and timer < getup_time:
		player.body_model.stop_action()
	getting_up = false
