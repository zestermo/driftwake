class_name SeaVessel
extends AnimatableBody3D
## A sea stop that floats (docs/v1_28_plan.md, The sea): the wandering merchant ship, the floating restaurant.
## Like EnemyShip it runs its own sailing (_pos and _heading are the truth, written to the transform each physics
## tick) and rides the swell; captains walk its decks (group "decks": aboard / deck_delta / hull_velocity).
## Subclasses fill `bounds` (ship-local AABB of where you count as aboard) and `_brain` (the course and speed
## it wants). Co-op: the host sails it (group net_sync), guests run the same sailing from its snapshots.

const HEAVE_SCALE := 0.4
const ACCEL := 1.6
const MAX_TURN := 0.3
## No roll, pitch or wake past this far from the camera (checked twice a second).
const FAR := 350.0

var bounds := AABB(Vector3(-5.0, -1.5, -14.0), Vector3(10.0, 20.0, 25.0))
var freeboard := HullLayout.FREEBOARD
## Where the swell is sampled (half the length and beam).
var half_len := HullLayout.STERN_Z
var half_beam := HullLayout.HALF_BEAM
var net_puppet := false
var net_idle := false
var speed := 0.0

var _pos := Vector3.ZERO
var _heading := 0.0
var _yaw_rate := 0.0
var _y := 0.0
var _vy := 0.0
var _pitch := 0.0
var _vpitch := 0.0
var _roll := 0.0
var _vroll := 0.0
var _swell_ready := false
var _deck_delta := Transform3D.IDENTITY
var _far := false
var _far_t := 0.0
var _copy_ready := false


func _ready() -> void:
	add_to_group("decks")
	add_to_group("net_sync")
	add_to_group("sea_stops")
	net_puppet = Net.is_client()
	collision_layer = 1
	collision_mask = 1
	sync_to_physics = true
	_build()
	_pos = Vector3(global_position.x, 0.0, global_position.z)
	_heading = global_rotation.y
	_y = freeboard
	ActorSleep.add(self, ActorSleep.SHIP)


## (subclasses) The model, collision and fittings.
func _build() -> void:
	pass


## (subclasses, host) [heading, speed] it wants this tick.
func _brain(_delta: float) -> Array:
	return [_heading, 0.0]


func place(at: Vector3, yaw: float) -> void:
	_pos = Vector3(at.x, 0.0, at.z)
	_heading = yaw
	global_transform = Transform3D(Basis(Vector3.UP, yaw), Vector3(at.x, freeboard, at.z))
	reset_physics_interpolation()


func aboard(p: Vector3) -> bool:
	return bounds.has_point(global_transform.affine_inverse() * p)


func deck_delta() -> Transform3D:
	return _deck_delta


func hull_velocity() -> Vector3:
	return _fwd() * speed


func anyone_aboard() -> bool:
	for p in Net.all_players():
		if aboard((p as Node3D).global_position):
			return true
	return false


func sleep_ok() -> bool:
	return not anyone_aboard()


func _fwd() -> Vector3:
	return Vector3(-sin(_heading), 0.0, -cos(_heading))


func _right() -> Vector3:
	return Vector3(cos(_heading), 0.0, -sin(_heading))


func _physics_process(delta: float) -> void:
	_far_t -= delta
	if _far_t <= 0.0:
		_far_t = 0.5
		var cam := get_viewport().get_camera_3d()
		_far = cam != null and cam.global_position.distance_to(global_position) > FAR
	if net_puppet:
		_puppet(delta)
		return
	var want := _brain(delta)
	speed = move_toward(speed, float(want[1]), ACCEL * delta)
	var diff := wrapf(float(want[0]) - _heading, -PI, PI)
	var flow := clampf(absf(speed) / 3.0, 0.3, 1.0)
	_yaw_rate = move_toward(_yaw_rate, clampf(diff * 1.2, -1.0, 1.0) * MAX_TURN * flow, 0.6 * delta)
	_heading = wrapf(_heading + _yaw_rate * delta, -PI, PI)
	_pos += _fwd() * speed * delta
	_swell(delta)
	_place_hull()


func _place_hull() -> void:
	var xf := Transform3D(Basis.from_euler(Vector3(_pitch, _heading, _roll)), Vector3(_pos.x, _y, _pos.z))
	_deck_delta = xf * global_transform.affine_inverse()
	global_transform = xf


func _swell(delta: float) -> void:
	var t: float = Ocean.clock()
	if _far and _swell_ready:
		_y = lerpf(_y, Ocean.get_wave_height(_pos, t) * HEAVE_SCALE + freeboard, minf(delta * 2.0, 1.0))
		return
	var fwd := _fwd()
	var right := _right()
	var hb := Ocean.get_wave_height(_pos + fwd * half_len, t)
	var hs := Ocean.get_wave_height(_pos - fwd * half_len, t)
	var hp := Ocean.get_wave_height(_pos - right * half_beam, t)
	var hr := Ocean.get_wave_height(_pos + right * half_beam, t)
	var hc := Ocean.get_wave_height(_pos, t)
	var mean := (hb + hs + hp + hr + hc * 2.0) / 6.0
	var ty := lerpf(mean, hc, 0.5) * HEAVE_SCALE + freeboard
	var tp := clampf(atan((hb - hs) / (half_len * 2.0)) * 0.35, -0.04, 0.04)
	var tr := clampf(atan((hr - hp) / (half_beam * 2.0)) * 0.3, -0.045, 0.045)
	if not _swell_ready:
		_swell_ready = true
		_y = ty
		_pitch = tp
		_roll = tr
	var w := 2.0
	_vy += ((ty - _y) * w * w - _vy * 2.0 * w) * delta
	_y += _vy * delta
	var wa := 2.4
	_vpitch += ((tp - _pitch) * wa * wa - _vpitch * 2.0 * wa) * delta
	_pitch += _vpitch * delta
	_vroll += ((tr - _roll) * wa * wa - _vroll * 2.0 * wa) * delta
	_roll += _vroll * delta


func net_pack() -> Array:
	return [_pos, _heading, speed, _yaw_rate, net_extra()]


## (subclasses) What else a guest's copy needs from the host (a state, a flag).
func net_extra() -> Array:
	return []


func net_apply(_extra: Array) -> void:
	pass


func _puppet(delta: float) -> void:
	var last := Net.latest(self)
	if last.size() != 2 or (last[1] as Array).size() < 5:
		return
	var s: Array = last[1]
	net_apply(s[4])
	var age := clampf(Net.time() - float(last[0]), 0.0, 0.5)
	var head := float(s[1]) + float(s[3]) * age
	var at: Vector3 = (s[0] as Vector3) + Vector3(-sin(head), 0.0, -cos(head)) * float(s[2]) * age
	if not _copy_ready or Vector2(at.x - _pos.x, at.z - _pos.z).length() > 8.0:
		_copy_ready = true
		_pos = Vector3(at.x, 0.0, at.z)
		_heading = head
	else:
		_heading = wrapf(_heading + _yaw_rate * delta, -PI, PI)
		_pos += _fwd() * speed * delta
		var k := 1.0 - exp(-2.5 * delta)
		_pos += Vector3(at.x - _pos.x, 0.0, at.z - _pos.z) * k
		_heading = lerp_angle(_heading, head, k)
	speed = float(s[2])
	_yaw_rate = float(s[3])
	_swell(delta)
	_place_hull()
