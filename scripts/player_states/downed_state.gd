extends PlayerState
## Thrown off your feet by a heavy hit, or dead.
## The body becomes a physics ragdoll; the player's root follows the hips so
## the camera tracks the tumble. Once the body has come to rest the character
## gets back up from wherever it landed. Dead bodies stay down until the
## respawn (GameManager) forces the Idle state.
## Knocked into deep water, the body plunges under, then floats back up
## (the ragdoll is buoyant); once it's bobbing at the surface you right
## yourself and start treading water. Dead bodies just float.

const MIN_DOWN := 0.9
const MAX_DOWN := 3.0
## In deep water: recover once the hips are this close under the surface...
const FLOAT_DEPTH := 0.45
## ...or after this long regardless.
const MAX_UNDER := 4.0
## The root more than this behind the hips (it couldn't follow): it jumps there.
const FOLLOW_GAP := 1.0

var timer: float = 0.0
var dead: bool = false
var getting_up: bool = false
var getup_time: float = 0.0
var _rest: float = 0.0
var _landed: bool = false
var _prev_vy: float = 0.0
var _wet: bool = false


func enter(data: Dictionary) -> void:
	timer = 0.0
	_rest = 0.0
	_landed = false
	_prev_vy = 0.0
	_wet = false
	getting_up = false
	dead = bool(data.get("dead", false))
	player.velocity = Vector3.ZERO
	player.sprinting = false
	player.is_parrying = false
	player.hurtbox.set_deferred("monitorable", false)
	player.sword_hitbox.deactivate()
	player.reset_combo()
	var v: Vector3 = data.get("velocity", Vector3.ZERO)
	var spin := Vector3.UP.cross(Vector3(v.x, 0, v.z).normalized()) * 5.0 if v.length() > 0.1 else Vector3.ZERO
	# on a ship under way the body keeps the deck's speed (or the deck sails out from under it)
	player.body_model.start_ragdoll(v + _deck_velocity(), spin, not dead)
	if player.power.has_fruit() and player.body_model.ragdoll:
		player.body_model.ragdoll.buoyancy = 0.2  # the sea's curse: you sink
	Net.fx("sfx", ["whoosh_big", player.global_position, -8.0, 0.1, 0.8])


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
	# in the water the body floats: the root rides along with the hips
	# instead of dropping to the sea floor
	var hip_depth := player.water_surface(hips) - hips.y
	if hip_depth > -0.3:
		_wet = true
	var deep := _wet and player.water_depth_at(hips) > Player.SWIM_ENTER_DEPTH
	if deep:
		var want_y := hips.y - player.body_model.hip_y * player.body_model.scale.y
		player.velocity.y = clampf((want_y - player.global_position.y) * 10.0, -12.0, 8.0)
	else:
		apply_gravity(delta)
	player.move_and_slide()
	# blocked (a ship's rail, a wall) while the body flies on: the root jumps
	# to the ground under the body, so the camera goes with it and the get-up
	# happens where it landed
	var gap := hips - player.global_position
	if Vector2(gap.x, gap.z).length() > FOLLOW_GAP:
		var q := PhysicsRayQueryParameters3D.create(hips + Vector3.UP * 0.3, hips + Vector3.DOWN * 30.0, 1)
		q.exclude = [player.get_rid()]
		var hit := player.get_world_3d().direct_space_state.intersect_ray(q)
		var y := (hit["position"] as Vector3).y if not hit.is_empty() else hips.y - player.body_model.hip_y * player.body_model.scale.y
		player.global_position = Vector3(hips.x, maxf(y, hips.y - 1.5) if deep else y, hips.z)
		player.velocity = Vector3.ZERO
	# a thud when the body first hits the ground (the water splashes instead)
	var rb := rag.root_body()
	var vy := rb.linear_velocity.y if rb else 0.0
	if _wet:
		_landed = true
	if not _landed and timer > 0.1 and vy - _prev_vy > 2.0:
		_landed = true
		Net.fx("sfx", ["thud", hips, -2.0, 0.1, 0.85])
		Net.fx("dust_ring", [Vector3(hips.x, player.global_position.y, hips.z), 12, 0.8])
		get_node("/root/CombatManager").apply_camera_shake(0.12)
	_prev_vy = vy
	if dead:
		return
	if deep:
		# bob back up, then right yourself and tread water
		if timer > MIN_DOWN and (hip_depth < FLOAT_DEPTH and vy > -0.6 or timer > MAX_UNDER):
			player.recover_into_swim()
		return
	if rag.settled():
		_rest += delta
	else:
		_rest = 0.0
	if timer > MIN_DOWN and (_rest > 0.25 or timer > MAX_DOWN):
		getting_up = true
		timer = 0.0
		getup_time = player.get_up_from_ragdoll()


## The velocity of whatever deck you're standing on (a ship under way).
func _deck_velocity() -> Vector3:
	var pv := player.get_platform_velocity()
	if pv.length() > 0.05:
		return pv
	var ship := player.get_tree().get_first_node_in_group("ship") as Node3D
	if ship and ship.has_method("aboard") and ship.aboard(player.global_position):
		return ship.hull_velocity()
	return Vector3.ZERO


func exit() -> void:
	player.hurtbox.set_deferred("monitorable", true)
	if player.body_model.ragdoll != null:
		player.body_model.reset_pose()
	elif getting_up and timer < getup_time:
		player.body_model.stop_action()
	getting_up = false
