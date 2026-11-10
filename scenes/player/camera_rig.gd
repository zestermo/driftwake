extends Node3D

@export var mouse_sensitivity: float = 0.002
@export var min_pitch: float = -80.0
@export var max_pitch: float = 60.0
@export var follow_speed: float = 24.0
@export var spring_length: float = 5.0
@export var min_zoom: float = 2.0
@export var max_zoom: float = 25.0
@export var zoom_speed: float = 1.5

var target: Node3D
var current_zoom: float = 5.0

## Shake is "trauma" (0..1): hits add to it, it drains away at SHAKE_DECAY a
## second, and the offset is trauma^1.5 times smooth noise.
const SHAKE_PER := 2.5        # trauma per unit of shake intensity (0.4 = full)
const SHAKE_DECAY := 3.0
const SHAKE_OFFSET := Vector2(0.6, 0.45)
const SHAKE_ROLL := 0.05
var trauma: float = 0.0
var _shake_t: float = 0.0
## 0 = exploring, 1 = combat stance (over-the-shoulder, closer).
var _combat_blend: float = 0.0
## Camera shoulder offset and max distance while the weapon is drawn.
@export var combat_shoulder: float = 0.55
@export var combat_max_zoom: float = 3.8
## (1.30) The stance's own distance, set by the scroll wheel while the weapon is out (combat_max_zoom to start).
var combat_zoom: float = 3.8
const COMBAT_ZOOM_MAX := 8.0
## (1.30) A handover from another camera (the helm's): the arm eases out from where that camera was, slowly.
var _hand := 0.0
const HAND_SECS := 0.8

## Showcase (inventory open): the camera swings around in front of the player
## and frames them on the left of the screen, beside the inventory panel, at
## _show_x of the screen's width (set by the inventory: between its gear slots).
@export var showcase_zoom: float = 2.4
@export var showcase_pitch: float = -0.06
var _show_x: float = 0.25
var _show: float = 0.0
var _show_target: float = 0.0
var _saved_yaw: float = 0.0
var _saved_pitch: float = 0.0
var _show_yaw: float = 0.0
var _saved_mask: int = -1
var _base_fov := 75.0
## A big beast fighting near (a boss's camera_room(), 0..1): the arm draws back to fit it and the view lifts.
var _room := 0.0
const ROOM_ZOOM := 6.8
const ROOM_LIFT := 0.7
var _kick := 0.0
var _kick_t := 0.0
var _kick_len := 0.5
## The held map (MapHold): the camera comes in over the right side of the captain's head (MapHold hides
## it meanwhile) and tilts down onto the sheet (`_map_focus`), close and narrow, in 1 / MAP_SPEED s; the
## mouse is the map's meanwhile. Nearly straight on, so the page reads level on the pixel grid.
const MAP_YAW := 0.165
const MAP_PITCH := -0.9
const MAP_DIST := 0.92
const MAP_FOV := 31.0
const MAP_SPEED := 4.0
var _map_focus: Node3D = null
var _map_on := false
var _map := 0.0
var _map_e := 0.0
var _map_pitch := 0.0

@onready var spring_arm: SpringArm3D = $SpringArm3D
@onready var camera: Camera3D = $SpringArm3D/Camera3D


func _ready() -> void:
	# The rig is moved every rendered frame (in _process), so it must not be
	# physics-interpolated itself; it follows the player's interpolated transform.
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	Settings.capture_mouse()
	current_zoom = spring_length
	combat_zoom = combat_max_zoom
	spring_arm.spring_length = current_zoom
	camera.add_to_group("player_camera")
	camera.make_current()
	_base_fov = float(Settings.get_value("video", "fov"))
	camera.fov = _base_fov
	Settings.changed.connect(func(section: String, key: String, value: Variant):
		if section == "video" and key == "fov":
			_base_fov = float(value)
			camera.fov = _base_fov)
	await get_tree().process_frame
	target = get_tree().get_first_node_in_group("player")
	if target:
		global_position = target.get_global_transform_interpolated().origin + Vector3(0, 1.2, 0)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		# screen_relative ignores the low-res viewport scaling, so sensitivity
		# stays the same at every PSX resolution preset.
		var sens := mouse_sensitivity * float(Settings.get_value("controls", "mouse_sensitivity"))
		var inv_y := -1.0 if Settings.get_value("controls", "invert_y") else 1.0
		var tg := _targeting()
		if tg and tg.locked():
			# locked on: the camera holds the foe ahead; a sideways flick switches to the next one that way
			_flick += event.screen_relative.x
			if absf(_flick) > FLICK_PX:
				tg.switch(1 if _flick > 0.0 else -1)
				_flick = 0.0
		else:
			rotate_y(-event.screen_relative.x * sens)
		spring_arm.rotate_x(-event.screen_relative.y * sens * inv_y)
		spring_arm.rotation.x = clamp(
			spring_arm.rotation.x,
			deg_to_rad(min_pitch),
			deg_to_rad(max_pitch)
		)

	# Clicking back into the window recaptures the mouse (Esc opens the menu).
	if event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		var menu := get_node_or_null("/root/GameMenu")
		if menu == null or not menu.is_open():
			Settings.capture_mouse()

	# Scroll wheel zoom: the stance keeps its own distance (so a scroll with the weapon out shows at once)
	if event is InputEventMouseButton and event.pressed and _show_target == 0.0:
		var step := 0.0
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			step = -zoom_speed
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			step = zoom_speed
		if step != 0.0:
			if _in_stance():
				combat_zoom = clampf(combat_zoom + step * 0.5, min_zoom, COMBAT_ZOOM_MAX)
			else:
				current_zoom = clampf(current_zoom + step, min_zoom, max_zoom)


func _process(delta: float) -> void:
	_pad_look(delta)
	# Combat stance pulls the camera in over the right shoulder
	var in_combat := _in_stance()
	_combat_blend = move_toward(_combat_blend, 1.0 if in_combat else 0.0, delta * 3.0)
	var zoom := lerpf(current_zoom, combat_zoom, _combat_blend)
	var room := 0.0
	if target:
		for b in get_tree().get_nodes_in_group("bosses"):
			if b.has_method("camera_room"):
				room = maxf(room, float(b.camera_room(target.global_position)))
	_room = move_toward(_room, room, delta * 1.2)
	zoom = lerpf(zoom, maxf(zoom, ROOM_ZOOM), _room)
	# (1.31) a fight around you: the arm draws back to fit it, the view's centre leans toward it (_fight_frame)
	_fight_frame(delta)
	zoom = maxf(zoom, lerpf(zoom, _fight_zoom, _fight_k))
	_show = move_toward(_show, _show_target, delta * 2.6)
	var e := smoothstep(0.0, 1.0, _show)
	if _show > 0.0 or _show_target > 0.0:
		rotation.y = lerp_angle(_saved_yaw, _show_yaw, e)
		spring_arm.rotation.x = lerpf(_saved_pitch, showcase_pitch, e)
		zoom = lerpf(zoom, showcase_zoom, e)
	elif process_mode == Node.PROCESS_MODE_ALWAYS:
		process_mode = Node.PROCESS_MODE_INHERIT
		if _saved_mask >= 0:
			spring_arm.collision_mask = _saved_mask
			_saved_mask = -1
	# an ability's punch-in: the view narrows and the arm draws in, then eases back (real time)
	var rd0 := delta / maxf(Engine.time_scale, 0.01)
	if _kick_t > 0.0:
		_kick_t = maxf(_kick_t - rd0, 0.0)
	var punch := _kick * smoothstep(0.0, 1.0, _kick_t / maxf(_kick_len, 0.01))
	camera.fov = _base_fov - punch * 14.0
	zoom *= 1.0 - punch * 0.25
	# (a handover from the helm eases out slowly, then the usual quick follow)
	_hand = maxf(_hand - delta / HAND_SECS, 0.0)
	spring_arm.spring_length = lerpf(spring_arm.spring_length, zoom, 1.0 - exp(-lerpf(11.0, 2.0, _hand) * delta))
	var shoulder := combat_shoulder * _combat_blend
	# the held map
	_map = move_toward(_map, 1.0 if _map_on else 0.0, delta * MAP_SPEED)
	var swing := smoothstep(0.0, 0.6, _map)
	rotation.y += MAP_YAW * (swing - _map_e)
	_map_e = swing
	var me := smoothstep(0.3, 1.0, _map)
	if me > 0.0:
		spring_arm.rotation.x = lerpf(_map_pitch, MAP_PITCH, me)
		spring_arm.spring_length = lerpf(spring_arm.spring_length, MAP_DIST, me)
		camera.fov = lerpf(camera.fov, MAP_FOV, me)
		shoulder *= 1.0 - me

	if target:
		# Use the interpolated transform: the player moves at the physics rate
		# (60 Hz), the camera at the display rate. Reading the raw position here
		# makes everything judder on high-refresh monitors.
		var target_pos := target.get_global_transform_interpolated().origin + Vector3(0, lerpf(1.2, 0.88, e) + ROOM_LIFT * _room * (1.0 - e), 0)
		target_pos += _fight_shift * _fight_k * (1.0 - e) * (1.0 - me)
		if me > 0.0 and is_instance_valid(_map_focus):
			target_pos = target_pos.lerp(_map_focus.get_global_transform_interpolated().origin, me)
		# exponential weight: the same follow at 30 fps and at 165 fps (on the map, held to it)
		global_position = global_position.lerp(target_pos, lerpf(1.0 - exp(-follow_speed * delta), 1.0, me))
		# keep the camera above the waves (swimming, falling in), or under them with a captain deep on a dive
		var ocean := get_node_or_null("/root/Ocean")
		if ocean and camera:
			var cam_p := camera.global_position
			var surf := float(ocean.call("surface_at", cam_p))
			var swim := target.get_node_or_null("StateMachine/Swim")
			if swim and swim.has_method("camera_under") and swim.camera_under():
				if cam_p.y > surf - 0.35:
					global_position.y -= cam_p.y - (surf - 0.35)
			elif cam_p.y < surf + 0.35:
				global_position.y += surf + 0.35 - cam_p.y

	if e > 0.0:
		shoulder = lerpf(shoulder, _showcase_offset(), e)
	camera.h_offset = shoulder
	camera.v_offset = (0.15 * _combat_blend - 0.3 * e) * (1.0 - me)
	camera.rotation.z = 0.0
	if trauma > 0.0:
		# real time: a hit-stop slows the engine, but the freeze frame should still shake
		var rd := delta / maxf(Engine.time_scale, 0.01)
		_shake_t += rd
		var s := pow(trauma, 1.5)
		var t := _shake_t
		camera.h_offset += SHAKE_OFFSET.x * s * (0.6 * sin(t * 39.0) + 0.4 * sin(t * 67.0 + 1.3))
		camera.v_offset += SHAKE_OFFSET.y * s * (0.6 * sin(t * 43.0 + 2.1) + 0.4 * sin(t * 71.0 + 0.4))
		camera.rotation.z = SHAKE_ROLL * s * sin(t * 29.0 + 0.7)
		trauma = maxf(trauma - SHAKE_DECAY * rd, 0.0)
	_screen_feel(delta, me)
	_follow_lock(delta)


## (1.31) Lock-on: the camera turns to keep the locked foe ahead of the captain (Targeting). The automatic fight
## framing that came before it is gone: it turned the view while you were aiming at another foe; the lock is the
## explicit version. A sideways flick switches (the accumulator drains, so slow drifts never switch).
const LOCK_TURN := 7.0
const FLICK_PX := 140.0
var _flick := 0.0
var _stick_flick := false


func _targeting() -> Node:
	return target.get_node_or_null("Targeting") if target is Player else null


func _follow_lock(delta: float) -> void:
	_flick = move_toward(_flick, 0.0, delta * FLICK_PX * 2.5)
	var tg := _targeting()
	if tg == null or not tg.locked() or _show_target != 0.0 or _map_on:
		return
	var d: Vector3 = tg.lock.global_position - target.global_position
	d.y = 0.0
	if d.length() < 0.6:
		return
	var want := atan2(d.x, d.z) + PI  # the rig's yaw that looks along d (the arm's +Z holds the camera behind)
	rotation.y = lerp_angle(rotation.y, want, clampf(LOCK_TURN * delta, 0.0, 1.0))


## (1.31) Screen feel, this captain's screen only (never through Net), scaled by the "Screen effects" setting:
## a red vignette at low health pulsing harder near death, a dim blink on a knockdown or a big fall (`blink`),
## the speed smear and a wider FOV when flying fast (launched, a dash, a long fall), a light bob at a sprint and a
## dip on landing (`land`).
const FEEL_LOW_HP := 0.35
const FEEL_FOV := 9.0
const FEEL_BOB := 0.035
var _blink := 0.0
var _dip := 0.0
var _bob_t := 0.0
var _speed_k := 0.0
var _feel_t := 0.0


func blink(amount: float) -> void:
	_blink = maxf(_blink, clampf(amount, 0.0, 1.0))


func land(k: float) -> void:
	_dip = maxf(_dip, clampf(k, 0.0, 1.0))


func _screen_feel(delta: float, map_k: float) -> void:
	var fx := float(Settings.get_value("gameplay", "screen_fx"))
	var rd := delta / maxf(Engine.time_scale, 0.01)
	_feel_t += rd
	var p := target as Player
	var vig := 0.0
	var spd := 0.0
	if p and is_instance_valid(p):
		var hc = p.health_component
		if hc and hc.max_health > 0.0 and hc.current_health > 0.0:
			var low := 1.0 - clampf(hc.current_health / hc.max_health / FEEL_LOW_HP, 0.0, 1.0)
			if low > 0.0:
				var rate := lerpf(3.0, 9.0, low)
				vig = low * (0.45 + 0.3 * (0.5 + 0.5 * sin(_feel_t * rate)))
		# fast through the air (launched, falling) or a dash
		var v: Vector3 = p.velocity
		var fast := v.length() if not p.is_on_floor() else Vector2(v.x, v.z).length() * 0.8
		spd = smoothstep(11.0, 24.0, fast)
		if p.sprinting and p.is_on_floor():
			_bob_t += rd * Vector2(v.x, v.z).length() * 1.15
			camera.v_offset += sin(_bob_t) * FEEL_BOB * fx * (1.0 - map_k)
			camera.h_offset += cos(_bob_t * 0.5) * FEEL_BOB * 0.6 * fx * (1.0 - map_k)
	_speed_k = lerpf(_speed_k, spd, clampf(rd * 6.0, 0.0, 1.0))
	camera.fov += FEEL_FOV * _speed_k * fx * (1.0 - map_k)
	if _dip > 0.0:
		camera.v_offset -= 0.22 * fx * sin(_dip * PI * 0.5) * _dip
		_dip = maxf(_dip - rd * 3.5, 0.0)
	var dim := _blink * fx
	_blink = maxf(_blink - rd * 1.6, 0.0)
	var psx := get_node_or_null("/root/PSX")
	if psx and psx.has_method("set_feel"):
		psx.set_feel(vig * fx, smoothstep(0.0, 1.0, dim) * 0.85, _speed_k * fx)


## Weapon out, not sprinting: the over-the-shoulder stance.
func _in_stance() -> bool:
	return target is Player and (target as Player).armed and not (target as Player).sprinting


## (1.30) Take the view from another camera (leaving the helm): the arm points at where that camera stands from
## the captain's head, at its distance, so the cut is seamless, then eases back to the captain's own distance.
func take_view(cam_pos: Vector3) -> void:
	if target == null:
		return
	global_position = target.get_global_transform_interpolated().origin + Vector3(0, 1.2, 0)
	var d := cam_pos - global_position
	var l := d.length()
	if l < 0.5:
		return
	# the arm's +Z holds the camera: yaw turns +Z to (sin, 0, cos), pitch x tips it to (0, -sin, cos)
	rotation.y = atan2(d.x, d.z)
	spring_arm.rotation.x = clampf(asin(clampf(-d.y / l, -1.0, 1.0)), deg_to_rad(min_pitch), deg_to_rad(max_pitch))
	spring_arm.spring_length = l
	_hand = 1.0

## The sideways camera shift that puts the character (at the pivot, spring
## length away) at _show_x of the screen. The FOV is vertical (keep height),
## so how far a metre moves them on screen depends on the window's shape.
func _showcase_offset() -> float:
	var vis := get_viewport().get_visible_rect().size
	var half_w := spring_arm.spring_length * tan(deg_to_rad(camera.fov) * 0.5) * vis.x / vis.y
	return (1.0 - 2.0 * _show_x) * half_w


## Swing around to face the character (`facing_yaw` = their model's yaw) and
## frame them at `screen_x` of the screen's width, or swing back to where the
## camera was.
func set_showcase(on: bool, facing_yaw: float = 0.0, screen_x: float = 0.25) -> void:
	if on:
		if _show_target == 0.0 and _show == 0.0:
			_saved_yaw = rotation.y
			_saved_pitch = spring_arm.rotation.x
		_show_yaw = facing_yaw + PI - 0.42
		_show_x = screen_x
		_show_target = 1.0
		process_mode = Node.PROCESS_MODE_ALWAYS
		# frame the character even if a post or palm is behind the camera
		if _saved_mask < 0:
			_saved_mask = spring_arm.collision_mask
			spring_arm.collision_mask = 0
	else:
		_show_target = 0.0


## The held map out (`focus`: its sheet) or away (null).
func set_map(focus: Node3D) -> void:
	if focus and not _map_on and _map == 0.0:
		_map_pitch = spring_arm.rotation.x
	_map_on = focus != null
	if focus:
		_map_focus = focus


## How far the camera has turned for the map (0..1).
func map_blend() -> float:
	return _map_e


## Is the camera on its way to, at or back from the map?
func on_map() -> bool:
	return _map > 0.0


func is_showcasing() -> bool:
	return _show_target > 0.0


## Punch in on the action: `amount` 0..1 (1 = 14 degrees narrower and a quarter
## closer), easing back out over `secs`.
func kick(amount: float, secs: float = 0.5) -> void:
	_kick = maxf(_kick * smoothstep(0.0, 1.0, _kick_t / maxf(_kick_len, 0.01)), amount)
	_kick_len = secs
	_kick_t = secs


func shake(intensity: float, _duration: float = 0.2) -> void:
	trauma = minf(trauma + intensity * SHAKE_PER * float(Settings.get_value("gameplay", "camera_shake")), 1.0)


## The right stick turns the view (real time: a hit-stop doesn't slow it), curved and at the pad's
## sensitivity (Pad.look), invert Y shared with the mouse; not while a wheel, the map, the showcase or a
## menu has the stick, or the captain's input is locked (chat).
func _pad_look(delta: float) -> void:
	if _show_target != 0.0 or _map_on or RadialWheel.shown != null or GameMenu.is_open():
		return
	if target is Player and (target as Player).input_locked:
		return
	var l: Vector2 = Pad.look(delta / maxf(Engine.time_scale, 0.01))
	if absf(l.x) < 0.01:
		_stick_flick = false
	if l == Vector2.ZERO:
		return
	var inv_y := -1.0 if Settings.get_value("controls", "invert_y") else 1.0
	var tg := _targeting()
	if tg and tg.locked():
		# locked on: a push of the stick sideways switches (once per push)
		if absf(l.x) > 0.04 and not _stick_flick:
			_stick_flick = true
			tg.switch(1 if l.x > 0.0 else -1)
	else:
		rotate_y(-l.x)
	spring_arm.rotate_x(-l.y * inv_y)
	spring_arm.rotation.x = clamp(spring_arm.rotation.x, deg_to_rad(min_pitch), deg_to_rad(max_pitch))


## (1.31) The combat camera (Zach: "pull out a little and focus the other targets"): weapon out with foes within
## FIGHT_R m, the arm draws back just far enough to fit them (up to FIGHT_ZOOM_MAX) and the point it looks at leans
## toward the fight's middle (FIGHT_LEAN of the way, at most FIGHT_SHIFT_MAX m; nearer foes count more, the locked one
## most). It never turns the view: the mouse keeps the aim. Eased in and out over ~0.5 s; walls still pull the arm
## in (the spring arm). Off with the "Combat camera" setting.
const FIGHT_R := 12.0
const FIGHT_ZOOM_MAX := 7.0
const FIGHT_LEAN := 0.33
const FIGHT_SHIFT_MAX := 2.5
const FIGHT_EVERY := 6
var _fight_k := 0.0
var _fight_zoom := 0.0
var _fight_shift := Vector3.ZERO
var _fight_want_zoom := 0.0
var _fight_want_shift := Vector3.ZERO
var _fight_on := false
var _fight_n := 0


func _fight_frame(delta: float) -> void:
	var p := target as Player
	_fight_n += 1
	if _fight_n % FIGHT_EVERY == 0:
		_fight_on = false
		var tg := _targeting()
		if p and tg and _combat_blend > 0.5 and bool(Settings.get_value("gameplay", "combat_camera")):
			var at: Vector3 = p.global_position
			var foes: Array = tg.candidates(FIGHT_R)
			if not foes.is_empty():
				var mid := Vector3.ZERO
				var wsum := 0.0
				var far := 0.0
				for f in foes:
					var d: Vector3 = (f as Node3D).global_position - at
					d.y = 0.0
					var w := 1.0 / (1.0 + d.length())
					if tg.locked() and f == tg.lock:
						w *= 4.0
					mid += d * w
					wsum += w
					far = maxf(far, d.length())
				mid /= maxf(wsum, 0.001)
				_fight_want_shift = (mid * FIGHT_LEAN).limit_length(FIGHT_SHIFT_MAX)
				# one close foe barely moves it; a ring of them round you draws it back to fit
				var spread := far * 0.3 + 0.35 * minf(float(foes.size() - 1), 3.0)
				_fight_want_zoom = clampf(combat_zoom + spread, combat_zoom, FIGHT_ZOOM_MAX)
				_fight_on = true
	var k := 1.0 - exp(-2.2 * delta)
	_fight_k = move_toward(_fight_k, 1.0 if _fight_on else 0.0, delta * 2.0)
	if _fight_on:
		_fight_zoom = lerpf(_fight_zoom if _fight_zoom > 0.0 else combat_zoom, _fight_want_zoom, k)
		_fight_shift = _fight_shift.lerp(_fight_want_shift, k)
