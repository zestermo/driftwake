class_name RivalShip
extends AnimatableBody3D
## (1.30, docs/v1_30_plan.md "Rival crews") A rival crew's ship, seen: she sails in from the horizon at a steady
## cruise, brakes over the last stretch, swings broadside to the shore and lets go her anchor off the harbour;
## when the visit's over she weighs and sails back out, and is gone. The pirates' hull (HullBuilder) in the crew's
## colours and flag. No AI: where she is is a function of the shared wave clock (Ocean.clock) from the leg's start,
## so every screen sails the same ship from one call (Net._all_rival_ship / _all_rival_ship_leave), with no snapshots.

## Cruise (m/s) and the stretch she brakes over before the anchor (m).
const CRUISE := 12.0
const BRAKE := 60.0
## She swings broadside to the shore over the last share of the leg in.
const SWING := 0.3
## The anchorage off the dock's end: this far out to sea, this far to the side away from the crew's mooring; she comes
## from LANE off, angled LANE_A off straight out.
const ANCHOR_OUT := 36.0
const ANCHOR_SIDE := 18.0
const LANE := 300.0
const LANE_A := 0.3
const HEAVE_SCALE := 0.4
## Ahead of this (m from the camera) she rides only the swell's height.
const NEAR := 260.0
## ActorSleep: asleep far off (her clock keeps her place: sleep_pos), never hidden (the horizon is the point).
const SLEEP := [700.0, 600.0, INF, INF]
## The lane's length (tests sail a short one).
static var lane_m := LANE

var crew_id := ""
var leg_from := Vector3.ZERO
var leg_to := Vector3.ZERO
var leg_t0 := 0.0
var leaving := false
var _anchored := false
var _heading_in := 0.0
var _heading_moor := 0.0
var _y := 0.0
var _pitch := 0.0
var _roll := 0.0
var _vy := 0.0
var _vpitch := 0.0
var _vroll := 0.0
var _swell_ready := false
var _near := true
var _near_t := 0.0
var _wake_t := 0.0


## Where a crew's ship comes from and anchors, off a dock at `dock` whose sea lies along `out`: [from, anchor, her
## heading at anchor (broadside to the shore, bow on along the turn she came in on)].
static func lane(dock: Vector3, out: Vector3) -> Array:
	out.y = 0.0
	out = out.normalized()
	var side := out.cross(Vector3.UP)
	var anchor := dock + out * ANCHOR_OUT - side * ANCHOR_SIDE
	anchor.y = 0.0
	var from := anchor + (out * cos(LANE_A) - side * sin(LANE_A)) * lane_m
	return [from, anchor, atan2(-side.x, -side.z)]


## Seconds from the horizon to the anchor.
static func leg_secs() -> float:
	return (lane_m - BRAKE) / CRUISE + 2.0 * BRAKE / CRUISE


## Every machine: the crew's ship on its way in from `from` to `to` since `t0` (Ocean.clock), to lie at `moor` (heading).
static func arrive(tree: SceneTree, crew: String, from: Vector3, to: Vector3, moor: float, t0: float) -> RivalShip:
	var old := of(tree)
	if old:
		old.remove_from_group("rival_ship")
		old.queue_free()
	var s := RivalShip.new()
	s.name = "RivalShip"
	s.crew_id = crew
	s.leg_from = from
	s.leg_to = to
	s.leg_t0 = t0
	s._heading_moor = moor
	tree.current_scene.add_child(s)
	return s


## Every machine: she weighs anchor at `t0` and sails back out the way she came.
static func leave_all(tree: SceneTree, t0: float) -> void:
	var s := of(tree)
	if s and not s.leaving:
		var back := s.leg_from
		s.leg_from = s.leg_to
		s.leg_to = back
		s.leg_t0 = t0
		s.leaving = true
		s._anchored = false
		s.set_anchor_fx(false)


static func of(tree: SceneTree) -> RivalShip:
	return tree.get_first_node_in_group("rival_ship") as RivalShip


func _ready() -> void:
	add_to_group("rival_ship")
	collision_layer = 1
	collision_mask = 1
	sync_to_physics = true
	var c: Dictionary = RivalCrews.crew(crew_id)
	var pal: Array = c["palette"]
	var model := Node3D.new()
	model.name = "Model"
	add_child(model)
	HullBuilder.build(model, {"hull": Color(0.5, 0.42, 0.38).lerp(pal[2], 0.35), "deck": Color(0.75, 0.68, 0.6),
		"trim": c["flag"], "sail": (pal[0] as Color).lerp(Color(0.92, 0.9, 0.84), 0.25), "flag": c["flag"], "emblem": "jolly"})
	for g in model.get_children():
		(g as GeometryInstance3D).visibility_range_end = 1400.0
	ShipLights.enemy(model)
	HullBuilder.collide(self)
	var d := leg_to - leg_from
	_heading_in = atan2(-d.x, -d.z)
	ActorSleep.add(self, SLEEP)
	_place(Ocean.clock())
	reset_physics_interpolation()


func sleep_ok() -> bool:
	return not leaving


## Where her clock has her now (ActorSleep judges a sleeper by it, so she wakes as she sails into sight).
func sleep_pos() -> Vector3:
	return _pos_at(Ocean.clock())


## Riding to her anchor (the leg in run out).
func anchored() -> bool:
	return not leaving and Ocean.clock() >= leg_t0 + leg_secs()


## How far along the leg (m) at `t`: in, a cruise then an even brake to a stop; out, the brake mirrored then a cruise.
func _along(t: float) -> float:
	var e := maxf(t - leg_t0, 0.0)
	var brake_s := 2.0 * BRAKE / CRUISE
	if leaving:
		if e < brake_s:
			return 0.5 * CRUISE / brake_s * e * e
		return BRAKE + (e - brake_s) * CRUISE
	var cruise_s := (lane_m - BRAKE) / CRUISE
	if e < cruise_s:
		return e * CRUISE
	var b := minf(e - cruise_s, brake_s)
	return lane_m - BRAKE + CRUISE * b - 0.5 * CRUISE / brake_s * b * b


func _pos_at(t: float) -> Vector3:
	return leg_from + (leg_to - leg_from).normalized() * _along(t)


func _speed_at(t: float) -> float:
	return (_along(t + 0.1) - _along(t)) * 10.0


func _heading_at(t: float) -> float:
	var u := clampf(_along(t) / lane_m, 0.0, 1.0)
	if leaving:
		var k := smoothstep(0.0, SWING, u)
		return lerp_angle(_heading_moor, _heading_in + PI, k)
	return lerp_angle(_heading_in, _heading_moor, smoothstep(1.0 - SWING, 1.0, u))


func _physics_process(delta: float) -> void:
	var t := Ocean.clock()
	_near_t -= delta
	if _near_t <= 0.0:
		_near_t = 0.5
		var cam := get_viewport().get_camera_3d()
		_near = cam != null and cam.global_position.distance_to(global_position) < NEAR
	_place(t, delta)
	if leaving and _along(t) >= lane_m:
		queue_free()
		return
	if not leaving and not _anchored and anchored():
		_anchored = true
		set_anchor_fx(true)
	var v := _speed_at(t)
	if _near and v > 1.0:
		var fwd := Vector3(-sin(_heading_at(t)), 0.0, -cos(_heading_at(t)))
		Ocean.wake(self, global_position - fwd * HullLayout.STERN_Z, clampf(v / 9.0, 0.0, 1.0))
		_wake_t -= delta
		if v > 2.5 and _wake_t <= 0.0:
			_wake_t = 0.3
			var bow := global_position + fwd * 6.4
			FX.splash(Vector3(bow.x, 0.3, bow.z), int(clampf(v * 0.5, 2.0, 6.0)), 0.6)


func set_anchor_fx(on: bool) -> void:
	var bow := global_transform * Vector3(0.0, 0.0, HullLayout.BOW_Z + 1.0)
	FX.sfx("rope", bow, -2.0, 0.05, 0.7 if on else 0.9)
	if on:
		FX.splash(Vector3(bow.x, 0.0, bow.z), 8, 1.0)


func _wave(p: Vector3, t: float) -> float:
	return Ocean.get_wave_height(p, t)


func _place(t: float, delta := 0.0) -> void:
	var pos := _pos_at(t)
	var h := _heading_at(t)
	var fwd := Vector3(-sin(h), 0.0, -cos(h))
	var right := Vector3(cos(h), 0.0, -sin(h))
	var hc := _wave(pos, t)
	var ty := hc * HEAVE_SCALE + HullLayout.FREEBOARD
	var tp := 0.0
	var tr := 0.0
	if _near:
		var hb := _wave(pos + fwd * HullLayout.STERN_Z, t)
		var hs := _wave(pos - fwd * HullLayout.STERN_Z, t)
		var hp := _wave(pos - right * HullLayout.HALF_BEAM, t)
		var hr := _wave(pos + right * HullLayout.HALF_BEAM, t)
		ty = lerpf((hb + hs + hp + hr + hc * 2.0) / 6.0, hc, 0.5) * HEAVE_SCALE + HullLayout.FREEBOARD
		tp = clampf(atan((hb - hs) / (HullLayout.STERN_Z * 2.0)) * 0.35, -0.045, 0.045)
		tr = clampf(atan((hr - hp) / (HullLayout.HALF_BEAM * 2.0)) * 0.3, -0.05, 0.05)
	if not _swell_ready or delta <= 0.0:
		_swell_ready = true
		_y = ty
		_pitch = tp
		_roll = tr
	else:
		var w := 2.2
		_vy += ((ty - _y) * w * w - _vy * 2.0 * w) * delta
		_y += _vy * delta
		var wa := 2.6
		_vpitch += ((tp - _pitch) * wa * wa - _vpitch * 2.0 * wa) * delta
		_pitch += _vpitch * delta
		_vroll += ((tr - _roll) * wa * wa - _vroll * 2.0 * wa) * delta
		_roll += _vroll * delta
	global_transform = Transform3D(Basis.from_euler(Vector3(_pitch, h, _roll)), Vector3(pos.x, _y, pos.z))
