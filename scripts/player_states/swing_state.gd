extends PlayerState
## Vine Swing (Vine Fruit). Two ways in:
## * {"anchor": point}: a vine shot to a tree crown, cliff or roof and you
##   swing from it like a pendulum while it reels you in a little. The body
##   lines up with the vine, the vine arm straight up it and the free arm and
##   legs hanging loose; steer with the stick, jump to let go with your
##   momentum (you come out tilted and right yourself before landing).
##   Getting close to the anchor, landing or 3 s ends the swing.
## * {"zip": enemy}: a big enemy (a large scuttlebug, a boss) - the vine
##   hauls you to it and you crash into it feet first.

const REEL := 3.2          # rope shortens this fast (m/s)
const MIN_LEN := 2.4       # feet to anchor
const GRIP := 1.95         # feet to the vine hand with the body stretched along the vine
const STEER := 8.0
const PUMP := 4.0          # extra push along the swing when steering with it
const MAX_TIME := 3.0
const ZIP_SPEED := 24.0
const ZIP_MAX := 1.4

var anchor := Vector3.ZERO
var rope_len: float = 6.0
var t: float = 0.0
var _zip: Node3D = null
var _vine: VineRope
var _wraps: Array = []
var _prev_v := Vector3.ZERO
var _released: bool = false
## Longest the vine may be so the bottom of the swing clears the ground.
var _max_len: float = 99.0


func enter(data: Dictionary) -> void:
	t = 0.0
	_released = false
	_zip = data.get("zip", null)
	player.sprinting = false
	var h := player.body_model
	_wraps = Net.fx("arm_vines", [h, "r"])
	if _zip:
		anchor = _zip_target()
		_vine = VineRope.make(player.get_tree().current_scene, _hand(), anchor, 0.08)
		h.play("vine_zip", ZIP_MAX + 0.5)
		Net.fx("sfx", ["whoosh_big", player.global_position, -4.0, 0.08, 1.2])
		return
	anchor = data.get("anchor", player.global_position + Vector3.UP * 6.0)
	rope_len = maxf(player.global_position.distance_to(anchor), MIN_LEN + 0.5)
	_max_len = maxf(_clearance(), MIN_LEN + 0.5)
	# a little kick so a standing swing gets going
	var to := anchor - player.global_position
	to.y = 0.0
	if to.length() > 0.1:
		player.velocity += to.normalized() * 3.0
	if player.is_on_floor():
		player.velocity.y = maxf(player.velocity.y, 4.0)
	_prev_v = player.velocity
	h.play("vine_hang", MAX_TIME + 1.0)
	h.dangle = true
	player.align_hold = true
	player.align_up = (anchor - player.global_position).normalized()
	_vine = VineRope.make(player.get_tree().current_scene, _hand(), anchor, 0.1)
	Net.fx("sfx", ["whoosh", player.global_position, -6.0, 0.1, 0.8])
	Net.fx("sparkle", [anchor, 8, Color(0.5, 0.95, 0.35)])


## How long the vine can be with the bottom of the arc still off the ground
## (ground sampled just beside the anchor, so a tree's own trunk doesn't count).
func _clearance() -> float:
	var side := player.global_position - anchor
	side.y = 0.0
	side = side.normalized() * 1.2 if side.length() > 0.1 else Vector3(1.2, 0, 0)
	var from := anchor + side
	var q := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 60.0, 1)
	q.exclude = [player.get_rid()]
	var h := player.get_world_3d().direct_space_state.intersect_ray(q)
	var floor_y: float = (h["position"] as Vector3).y if not h.is_empty() else anchor.y - 30.0
	return anchor.y - floor_y - 0.5


func _hand() -> Vector3:
	var h: Node3D = player.body_model.hand_r if player.body_model else null
	return h.global_position if h else player.global_position + Vector3(0, 1.9, 0)


func _zip_target() -> Vector3:
	if _zip and is_instance_valid(_zip):
		var hb := _zip.get("hurtbox") as Node3D
		return hb.global_position if hb else _zip.global_position + Vector3.UP * 0.8
	return anchor


func physics_update(delta: float) -> void:
	t += delta
	if _zip != null:
		_zip_update(delta)
		return
	rope_len = maxf(rope_len - REEL * delta, MIN_LEN)
	if rope_len > _max_len:
		# a long vine reels in fast first, so you swing clear of the ground
		rope_len = maxf(rope_len - 12.0 * delta, _max_len)
	var v := player.velocity
	v.y -= player.gravity * delta
	var mi := get_movement_input()
	if mi.length() > 0.1:
		var want := get_camera_relative_direction(mi)
		v += want * STEER * delta
		# pumping: pushing the way you're already swinging builds speed
		var hv := Vector3(v.x, 0, v.z)
		if hv.length() > 1.0 and hv.normalized().dot(want) > 0.5:
			v += hv.normalized() * PUMP * delta
	player.velocity = v
	player.move_and_slide()
	# the vine: the feet stay within its length (plus the body) of the anchor
	var to_p := player.global_position - anchor
	var d := to_p.length()
	if d > rope_len and d > 0.01:
		var n := to_p / d
		player.global_position -= n * (d - rope_len)
		var radial := player.velocity.dot(n)
		if radial > 0.0:
			player.velocity -= n * radial
	var hv2 := Vector3(player.velocity.x, 0, player.velocity.z)
	if hv2.length() > 0.5:
		face_direction(hv2, delta * 0.8)
	# body along the vine; what the loose limbs feel
	player.align_up = (anchor - player.global_position).normalized()
	player.align_w = move_toward(player.align_w, 1.0, delta * 6.0)
	var accel := (player.velocity - _prev_v) / maxf(delta, 0.0001)
	_prev_v = player.velocity
	var inv := player.lean.global_basis.orthonormalized().inverse()
	player.body_model.dangle_g = inv * (Vector3(0, -player.gravity, 0) - accel.limit_length(60.0))
	player.body_model.dangle_v = inv * player.velocity
	if _vine:
		_vine.set_ends(_hand(), anchor)
	# let go
	if Input.is_action_just_pressed("jump"):
		player.velocity.y = maxf(player.velocity.y, 0.0) + 5.0
		player.jumps_remaining = maxi(player.max_jumps - 1, 0)
		_released = true
		transitioned.emit(self, "Fall", {})
		return
	if t > MAX_TIME or (player.is_on_floor() and t > 0.6) or d < MIN_LEN * 0.8:
		_released = not player.is_on_floor()
		transitioned.emit(self, "Fall" if not player.is_on_floor() else "Idle", {})


func _zip_update(delta: float) -> void:
	var alive := is_instance_valid(_zip) and BurnStatus.alive(_zip)
	if alive:
		anchor = _zip_target()
	var to := anchor - (player.global_position + Vector3.UP * 0.9)
	var dist := to.length()
	if _vine:
		_vine.set_ends(_hand(), anchor)
	if _vine and not _vine.arrived():
		# the vine is still flying out
		player.velocity = player.velocity.move_toward(Vector3.ZERO, 30.0 * delta)
		player.move_and_slide()
		return
	var dir := to / maxf(dist, 0.01)
	face_direction(Vector3(dir.x, 0, dir.z), 1.0)
	player.velocity = dir * ZIP_SPEED
	player.move_and_slide()
	if int(t * 30.0) % 2 == 0:
		Net.fx("afterimage", [player.body_model, Color(0.5, 0.95, 0.4), 0.18])
	if dist < 1.7 or not alive or t > ZIP_MAX or player.get_slide_collision_count() > 0 and dist < 3.0:
		if alive and dist < 3.0:
			_crash()
		player.velocity = -dir * 1.5 + Vector3.UP * 5.5
		player.velocity.y = maxf(player.velocity.y, 5.5)
		transitioned.emit(self, "Fall", {})


## Arriving feet first: a solid hit and a bounce off.
func _crash() -> void:
	var hb := _zip.get("hurtbox") as Hurtbox
	if hb == null:
		return
	var hd := player.melee_hit(14.0)
	hd.knockback_force = 8.0
	hd.stagger_duration = 0.6
	hd.hitstop_duration = 0.08
	hd.camera_shake_intensity = 0.2
	hb.take_hit(hd, player)
	player.power.add_ult(hd.damage)
	Net.fx("impact", [hb.global_position, Color(0.6, 1.0, 0.45)])
	Net.fx("punch_wind", [player.global_position + Vector3.UP * 0.9, (hb.global_position - player.global_position).normalized(), 1.2, Color(0.75, 1.0, 0.6), true])


func exit() -> void:
	var h := player.body_model
	h.dangle = false
	player.align_hold = false
	if _released:
		h.play("vine_release", 0.75)
	else:
		h.stop_action()
		if _zip == null:
			player.align_w = minf(player.align_w, 0.5)
	if _vine:
		_vine.retract()
		_vine = null
	Net.fx("wither_vines", [_wraps])
	_wraps = []
	player.power.linger("vine_swing")
	_zip = null
