extends AnimatableBody3D
class_name Ship
## The player's sloop. A kinematic body moved by its own simple boat model:
## sails (W/S) build speed slowly and drag bleeds it off, the rudder (A/D)
## turns harder the faster you go, and the hull heaves, pitches and rolls on
## the swell, averaged over bow, stern and both sides so the motion is a slow
## roll rather than a jitter. Being a moving platform (sync_to_physics), it
## carries whoever stands on the deck. It slides along / stops against shores
## and docks instead of passing through them.

const MAX_SPEED := 13.0
const MAX_REVERSE := 3.0
const ACCEL := 2.6
const BRAKE := 4.0
## Turn rate (rad/s) at full rudder once there's flow over it (>= 4 m/s).
const MAX_TURN := 0.55
## Origin height above the (averaged) water surface: deck ~1.2 m above it.
const FREEBOARD := 0.85
## How much of the swell the hull follows (a 14 m hull rides over the 8 m waves).
const HEAVE_SCALE := 0.45
const BOW_Z := -5.8
const STERN_Z := 5.8
const HALF_BEAM := 2.7
const DECK_Y := 0.32

var is_player_steering: bool = false
## Current forward speed (m/s, negative = backing) and smoothed rudder (-1..1).
var speed: float = 0.0
var rudder: float = 0.0
## Camera yaw offset from the heading while at the helm (mouse look).
var cam_yaw: float = 0.0

var wheel: Node3D
var _ocean: Node
var _game_manager: Node
var _yaw_rate: float = 0.0
var _y: float = 0.0
var _vy: float = 0.0
var _pitch: float = 0.0
var _vpitch: float = 0.0
var _roll: float = 0.0
var _vroll: float = 0.0
var _init: bool = false
var _placed: bool = false
var _pos := Vector3.ZERO
var _heading: float = 0.0
var _prev_speed: float = 0.0
var _wake_t: float = 0.0
var _cam_heading: float = 0.0
var _cam_y: float = 0.0

@onready var ship_model: Node3D = $ShipModel
@onready var helm_position: Marker3D = $ShipModel/HelmPosition
@onready var bank_position: Marker3D = $ShipModel/BankPosition
@onready var disembark_position: Marker3D = $ShipModel/DisembarkPosition
@onready var respawn_point: Marker3D = $RespawnPoint
@onready var helm_zone: Interactable = $HelmZone
@onready var bank_zone: Interactable = $BankZone
@onready var ship_camera: Node3D = $ShipCamera


func _ready() -> void:
	_build_psx_model()
	_build_collision()
	_ocean = get_node_or_null("/root/Ocean")
	_game_manager = get_node("/root/GameManager")
	helm_zone.interacted.connect(_on_helm_interacted)
	bank_zone.interacted.connect(_on_bank_interacted)
	var arm := ship_camera.get_node("SpringArm3D") as SpringArm3D
	arm.add_excluded_object(get_rid())
	# moved every rendered frame from the hull's interpolated transform
	ship_camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF


# ==========================================================================
# Sailing
# ==========================================================================
## Put the ship somewhere (mooring, teleports). Use this rather than setting
## the transform: the hull keeps its own position/heading state.
func place(world_pos: Vector3, yaw: float) -> void:
	_pos = Vector3(world_pos.x, 0.0, world_pos.z)
	_heading = yaw
	_placed = true
	_init = false
	speed = 0.0
	_yaw_rate = 0.0
	global_transform = Transform3D(Basis(Vector3.UP, yaw), Vector3(world_pos.x, global_position.y, world_pos.z))
	reset_physics_interpolation()


func _physics_process(delta: float) -> void:
	if not _placed:
		_placed = true
		_pos = global_position
		_heading = global_rotation.y
	var heading := _heading
	var pos := _pos
	var fwd := Vector3(-sin(heading), 0.0, -cos(heading))
	var right := Vector3(cos(heading), 0.0, -sin(heading))

	var throttle := 0.0
	var turn := 0.0
	if is_player_steering:
		throttle = Input.get_axis("move_back", "move_forward")
		turn = Input.get_axis("move_left", "move_right")
	if throttle > 0.0:
		speed = move_toward(speed, MAX_SPEED * throttle, ACCEL * delta)
	elif throttle < 0.0:
		speed = move_toward(speed, -MAX_REVERSE, BRAKE * delta)
	else:
		speed = move_toward(speed, 0.0, (0.35 + 0.012 * speed * speed) * delta)
	rudder = move_toward(rudder, turn, 2.2 * delta)
	var flow := clampf(absf(speed) / 4.0, 0.3, 1.0)
	var target_rate := -rudder * MAX_TURN * flow * (-1.0 if speed < -0.3 else 1.0)
	_yaw_rate = move_toward(_yaw_rate, target_rate, 1.1 * delta)
	heading += _yaw_rate * delta

	# hull motion: slide along whatever we run into (shore, dock, rocks)
	var motion := fwd * speed * delta
	if motion.length() > 0.0001:
		var col := KinematicCollision3D.new()
		if test_move(global_transform, motion, col, 0.05):
			var n := col.get_normal()
			n.y = 0.0
			if n.length() > 0.1 and motion.dot(n) < 0.0:
				n = n.normalized()
				var head_on := -motion.normalized().dot(n)
				var travel := col.get_travel()
				travel.y = 0.0
				var rest := (motion - travel).slide(n)
				motion = travel + rest * (1.0 - head_on)
				if head_on > 0.5 and absf(speed) > 3.0:
					var cm := get_node_or_null("/root/CombatManager")
					if cm:
						cm.apply_camera_shake(0.25)
					FX.sfx("thud", global_position + fwd * (BOW_Z * -1.0), 2.0, 0.05, 0.6)
				speed *= lerpf(1.0, -0.15, head_on)
				_yaw_rate *= 0.5
	pos += motion

	# swell: sample the waves under bow, stern and both sides
	var t := Time.get_ticks_msec() / 1000.0
	var hb := _wave(pos + fwd * -BOW_Z, t)
	var hs := _wave(pos + fwd * -STERN_Z, t)
	var hp := _wave(pos - right * HALF_BEAM, t)
	var hr := _wave(pos + right * HALF_BEAM, t)
	var hc := _wave(pos, t)
	var mean := (hb + hs + hp + hr + hc * 2.0) / 6.0
	# (bow/stern/sides average most of the swell away; the midship sample
	# keeps a slow, shallow rise and fall)
	var target_y := lerpf(mean, hc, 0.5) * HEAVE_SCALE + FREEBOARD
	var accel_f := (speed - _prev_speed) / maxf(delta, 0.0001)
	_prev_speed = speed
	var target_pitch := clampf(atan((hb - hs) / (STERN_Z - BOW_Z)) * 0.35, -0.045, 0.045) + clampf(accel_f * 0.008, -0.03, 0.03) + clampf(speed * 0.003, -0.01, 0.04)
	var target_roll := clampf(atan((hr - hp) / (HALF_BEAM * 2.0)) * 0.3, -0.05, 0.05) + clampf(_yaw_rate * speed * 0.01, -0.06, 0.06)
	if not _init:
		_init = true
		_y = target_y
		_pitch = target_pitch
		_roll = target_roll
		_cam_heading = heading
		_cam_y = target_y
	# critically damped springs: the hull eases into the swell, no jitter
	var w := 2.2
	_vy += ((target_y - _y) * w * w - _vy * 2.0 * w) * delta
	_y += _vy * delta
	var wa := 2.6
	_vpitch += ((target_pitch - _pitch) * wa * wa - _vpitch * 2.0 * wa) * delta
	_pitch += _vpitch * delta
	_vroll += ((target_roll - _roll) * wa * wa - _vroll * 2.0 * wa) * delta
	_roll += _vroll * delta

	_pos = Vector3(pos.x, 0.0, pos.z)
	_heading = wrapf(heading, -PI, PI)
	global_transform = Transform3D(Basis.from_euler(Vector3(_pitch, heading, _roll)), Vector3(pos.x, _y, pos.z))

	# wheel follows the rudder
	if wheel:
		wheel.rotation.z = -rudder * 2.4
	# bow spray and wake
	_wake_t -= delta
	if absf(speed) > 2.5 and _wake_t <= 0.0:
		_wake_t = clampf(0.5 - absf(speed) * 0.03, 0.12, 0.4)
		var water := mean
		var bow := pos + fwd * (-BOW_Z + 0.6)
		FX.splash(Vector3(bow.x, water + 0.2, bow.z), int(clampf(absf(speed) * 0.5, 2.0, 7.0)), 0.6)
		for sgn in [-1.0, 1.0]:
			var side: Vector3 = pos + right * (HALF_BEAM + 0.2) * float(sgn) + fwd * 2.0
			FX.splash(Vector3(side.x, water + 0.1, side.z), 2, 0.5)
		var stern := pos - fwd * (STERN_Z + 0.8)
		FX.splash(Vector3(stern.x, water + 0.05, stern.z), 3, 0.8)


func _wave(p: Vector3, t: float) -> float:
	if _ocean and _ocean.has_method("get_wave_height"):
		return float(_ocean.call("get_wave_height", p, t))
	return 0.0


## Ship camera (used at the helm): follows the hull's position and heading
## but not its pitch/roll/heave jitter, so steering stays steady.
func _process(delta: float) -> void:
	var xf := get_global_transform_interpolated()
	var heading := xf.basis.get_euler().y
	_cam_heading = lerp_angle(_cam_heading, heading, minf(4.0 * delta, 1.0))
	_cam_y = lerpf(_cam_y, xf.origin.y, minf(1.5 * delta, 1.0))
	ship_camera.global_position = Vector3(xf.origin.x, _cam_y + 3.0, xf.origin.z)
	ship_camera.global_rotation = Vector3(0.0, _cam_heading + cam_yaw, 0.0)


# ==========================================================================
# Deck collision: what you walk on matches what you see
# ==========================================================================
func _build_collision() -> void:
	# hull volume: its top face is the deck
	var rings := [[6.6, 2.7, 1.5, -1.6], [3.0, 2.95, 1.6, -1.9], [-2.0, 2.95, 1.5, -1.9], [-5.5, 2.4, 1.0, -1.7], [-8.4, 0.25, 0.1, -0.9]]
	var pts := PackedVector3Array()
	for r in rings:
		for sgn in [-1.0, 1.0]:
			pts.append(Vector3(sgn * float(r[1]), DECK_Y, float(r[0])))
			pts.append(Vector3(sgn * float(r[2]), float(r[3]), float(r[0])))
	var hull := ConvexPolygonShape3D.new()
	hull.points = pts
	_shape(hull, Transform3D.IDENTITY)
	# bulwarks along the gunwales (waist high: jump to get over the side)
	for i in range(rings.size() - 1):
		var a: Array = rings[i]
		var b: Array = rings[i + 1]
		for sgn in [-1.0, 1.0]:
			var p0 := Vector3(sgn * (float(a[1]) - 0.05), DECK_Y, float(a[0]))
			var p1 := Vector3(sgn * (float(b[1]) - 0.05), DECK_Y, float(b[0]))
			var dir := p1 - p0
			var box := BoxShape3D.new()
			box.size = Vector3(0.16, 0.75, dir.length() + 0.2)
			_shape(box, Transform3D(Basis.looking_at(dir.normalized(), Vector3.UP), (p0 + p1) * 0.5 + Vector3(0, 0.37, 0)))
	var transom := BoxShape3D.new()
	transom.size = Vector3(5.4, 0.75, 0.16)
	_shape(transom, Transform3D(Basis.IDENTITY, Vector3(0, DECK_Y + 0.37, 6.6)))
	# stern cabin (and its roof you can stand on), mast, helm post, chest
	var cabin := BoxShape3D.new()
	cabin.size = Vector3(4.5, 1.62, 1.6)
	_shape(cabin, Transform3D(Basis.IDENTITY, Vector3(0, DECK_Y + 0.83 + 0.0, 5.85)))
	var mast := CylinderShape3D.new()
	mast.radius = 0.22
	mast.height = 11.0
	_shape(mast, Transform3D(Basis.IDENTITY, Vector3(0, DECK_Y + 5.5, -1.2)))
	var post := BoxShape3D.new()
	post.size = Vector3(0.3, 1.2, 0.3)
	_shape(post, Transform3D(Basis.IDENTITY, Vector3(0, DECK_Y + 0.6, 3.3)))
	var chest := BoxShape3D.new()
	chest.size = Vector3(0.6, 0.6, 1.0)
	_shape(chest, Transform3D(Basis.IDENTITY, bank_position.position + Vector3(0, 0.12, 0)))


func _shape(shape: Shape3D, xf: Transform3D) -> void:
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.transform = xf
	add_child(cs)


# ==========================================================================
# Interactions
# ==========================================================================
func _on_helm_interacted(player: Player) -> void:
	if player.is_free():
		player.current_ship = self
		var sm := player.state_machine
		if sm.current_state:
			sm.current_state.transitioned.emit(sm.current_state, "Helm", {})


func _on_bank_interacted(_player: Player) -> void:
	var count: int = _game_manager.bank_items()
	if count > 0:
		get_tree().call_group("hud", "show_toast", "Banked %d items. They're safe now." % count)
	else:
		get_tree().call_group("hud", "show_toast", "Nothing to bank.")


## Low-poly PSX sloop: tapered plank hull, deck, mast + sail, stern cabin,
## helm (the wheel is its own node so it can turn) and the banking chest.
func _build_psx_model() -> void:
	var mb := MeshBuilder.new()
	var hull := PSXMat.lit("planks_dark", Color.WHITE, {"affine": 0.6})
	var deck := PSXMat.lit("planks", Color.WHITE, {"affine": 0.6})
	var trim := PSXMat.lit("planks", Color(0.85, 0.65, 0.35))
	var canvas := PSXMat.lit("canvas", Color(0.95, 0.92, 0.82), {"affine": 0.6})
	var wood := PSXMat.lit("bark")
	var flag := PSXMat.lit("cloth_red")
	var glass := PSXMat.glow(Color(1.0, 0.8, 0.4), 2.5)

	# Hull cross-sections along Z (stern at +Z, bow at -Z): [z, top half-width, bottom half-width, top y, bottom y]
	var rings := [
		[6.6, 2.7, 1.5, 0.35, -1.6],
		[3.0, 2.95, 1.6, 0.25, -1.9],
		[-2.0, 2.95, 1.5, 0.25, -1.9],
		[-5.5, 2.4, 1.0, 0.35, -1.7],
		[-8.4, 0.25, 0.1, 0.8, -0.9],
	]
	for i in range(rings.size() - 1):
		var a: Array = rings[i]
		var b: Array = rings[i + 1]
		var a_tl := Vector3(-a[1], a[3], a[0]); var a_bl := Vector3(-a[2], a[4], a[0])
		var a_tr := Vector3(a[1], a[3], a[0]); var a_br := Vector3(a[2], a[4], a[0])
		var b_tl := Vector3(-b[1], b[3], b[0]); var b_bl := Vector3(-b[2], b[4], b[0])
		var b_tr := Vector3(b[1], b[3], b[0]); var b_br := Vector3(b[2], b[4], b[0])
		var L: float = absf(float(a[0]) - float(b[0])) * 0.5
		var Ha: float = (float(a[3]) - float(a[4])) * 0.5
		mb.add_quad(hull, a_tl, a_bl, b_bl, b_tl, Vector2(0, 0), Vector2(0, Ha), Vector2(L, Ha), Vector2(L, 0), Color.WHITE, Vector3(-1, -0.3, 0).normalized())
		mb.add_quad(hull, a_tr, b_tr, b_br, a_br, Vector2(0, 0), Vector2(L, 0), Vector2(L, Ha), Vector2(0, Ha), Color.WHITE, Vector3(1, -0.3, 0).normalized())
		mb.add_quad(hull, a_bl, a_br, b_br, b_bl, Vector2(0, 0), Vector2(1, 0), Vector2(1, L), Vector2(0, L), Color(0.7, 0.7, 0.7), Vector3.DOWN)
		# deck surface
		var dy := 0.32
		mb.add_quad(deck, Vector3(-a[1] + 0.1, dy, a[0]), Vector3(a[1] - 0.1, dy, a[0]), Vector3(b[1] - 0.1, dy, b[0]), Vector3(-b[1] + 0.1, dy, b[0]),
			Vector2(0, 0), Vector2(a[1], 0), Vector2(b[1], L * 2.0), Vector2(0, L * 2.0), Color.WHITE, Vector3.UP)
		# gunwale rails (visual only)
		for sgn in [-1.0, 1.0]:
			var p0 := Vector3(sgn * float(a[1]), float(a[3]) + 0.35, float(a[0]))
			var p1 := Vector3(sgn * float(b[1]), float(b[3]) + 0.35, float(b[0]))
			var mid := (p0 + p1) * 0.5
			var dir := (p1 - p0)
			var basis := Basis.looking_at(dir.normalized(), Vector3.UP)
			mb.add_box(trim, Transform3D(basis, mid), Vector3(0.14, 0.12, dir.length() + 0.1), 1.0)
	# stern transom
	var st: Array = rings[0]
	mb.add_quad(hull, Vector3(-st[1], st[3], st[0]), Vector3(st[1], st[3], st[0]), Vector3(st[2], st[4], st[0]), Vector3(-st[2], st[4], st[0]),
		Vector2(0, 0), Vector2(2.7, 0), Vector2(2.0, 1.0), Vector2(0.7, 1.0), Color.WHITE, Vector3.BACK)
	# rail posts
	for z in [-4.0, -1.0, 2.0, 5.5]:
		for sgn in [-1.0, 1.0]:
			mb.add_box(trim, Transform3D(Basis(), Vector3(sgn * 2.8, 0.5, z)), Vector3(0.12, 0.4, 0.12), 1.0)
	# mast, yard, sail, flag
	mb.add_cylinder(wood, Transform3D(Basis(), Vector3(0, 0.3, -1.2)), 0.2, 0.13, 11.0, 6, 0.8)
	mb.add_cylinder(wood, Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(3.0, 9.2, -1.2)), 0.08, 0.08, 6.0, 5, 0.8)
	var sail_n := Vector3(0, 0, 1)
	mb.add_quad(canvas, Vector3(-2.8, 9.1, -1.05), Vector3(2.8, 9.1, -1.05), Vector3(2.6, 6.2, -0.75), Vector3(-2.6, 6.2, -0.75),
		Vector2(0, 0), Vector2(2.0, 0), Vector2(2.0, 1.0), Vector2(0, 1.0), Color.WHITE, sail_n)
	mb.add_quad(canvas, Vector3(-2.6, 6.2, -0.75), Vector3(2.6, 6.2, -0.75), Vector3(2.4, 3.4, -1.0), Vector3(-2.4, 3.4, -1.0),
		Vector2(0, 1.0), Vector2(2.0, 1.0), Vector2(2.0, 2.0), Vector2(0, 2.0), Color.WHITE, sail_n)
	mb.add_quad(canvas, Vector3(-2.8, 9.1, -1.05), Vector3(-2.6, 6.2, -0.75), Vector3(2.6, 6.2, -0.75), Vector3(2.8, 9.1, -1.05),
		Vector2(0, 0), Vector2(0, 1.0), Vector2(2.0, 1.0), Vector2(2.0, 0), Color(0.8, 0.8, 0.75), -sail_n)
	mb.add_quad(canvas, Vector3(-2.6, 6.2, -0.75), Vector3(-2.4, 3.4, -1.0), Vector3(2.4, 3.4, -1.0), Vector3(2.6, 6.2, -0.75),
		Vector2(0, 1.0), Vector2(0, 2.0), Vector2(2.0, 2.0), Vector2(2.0, 1.0), Color(0.8, 0.8, 0.75), -sail_n)
	mb.add_card(flag, Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(0, 11.0, -0.75)), 0.9, 0.5, Rect2(0, 0, 0.5, 0.5))
	mb.add_card(flag, Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(0, 11.0, -0.75)), 0.9, 0.5, Rect2(0, 0, 0.5, 0.5))
	# bowsprit
	mb.add_cylinder(wood, Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-70)), Vector3(0, 0.7, -8.2)), 0.1, 0.06, 3.0, 5, 0.8)
	# stern cabin
	mb.add_box(trim, Transform3D(Basis(), Vector3(0, 0.32 + 0.75, 5.85)), Vector3(4.2, 1.5, 1.3), 0.6, Color.WHITE, true, false)
	mb.add_box(deck, Transform3D(Basis(), Vector3(0, 1.9, 5.85)), Vector3(4.5, 0.12, 1.6), 0.6, Color.WHITE, false, false)
	mb.add_box_unit_uv(PSXMat.lit("door", Color.WHITE, {"vertex_color": false}), Transform3D(Basis(), Vector3(0, 0.32 + 0.6, 5.18)), Vector3(0.7, 1.2, 0.05))
	mb.add_box(glass, Transform3D(Basis(), Vector3(1.6, 1.4, 5.15)), Vector3(0.3, 0.3, 0.06), 1.0)
	mb.add_box(glass, Transform3D(Basis(), Vector3(-1.6, 1.4, 5.15)), Vector3(0.3, 0.3, 0.06), 1.0)
	# helm wheel in front of the helmsman (who stands at z = 4)
	mb.add_box(wood, Transform3D(Basis(), Vector3(0, 0.75, 3.35)), Vector3(0.14, 0.9, 0.14), 1.0)
	var wmb := MeshBuilder.new()
	wmb.add_cylinder(trim, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 0, 0.03)), 0.42, 0.42, 0.06, 8, 1.0, Color.WHITE, true, true, false)
	for k in range(4):
		var b := Basis(Vector3.BACK, PI * k / 4.0)
		wmb.add_box(wood, Transform3D(b, Vector3(0, 0, -0.05)), Vector3(0.05, 1.05, 0.05), 1.0)
	wheel = wmb.to_instance("Wheel")
	wheel.position = Vector3(0, 1.25, 3.25)
	ship_model.add_child(wheel)
	# stern lantern
	mb.add_box(glass, Transform3D(Basis(), Vector3(0, 2.25, 6.4)), Vector3(0.25, 0.32, 0.25), 1.0, Color.WHITE, false)
	ship_model.add_child(mb.to_instance("PSXModel"))
	# banking chest at the bank zone
	var chest := MeshInstance3D.new()
	chest.name = "BankChest"
	chest.mesh = Props.treasure_chest_mesh()
	chest.position = bank_position.position + Vector3(0, -0.18, 0)
	chest.rotation.y = PI * 0.5
	ship_model.add_child(chest)
	# rope ladders down both sides, amidships: climb back aboard from the water
	for sgn in [-1.0, 1.0]:
		var lad := Ladder.new()
		lad.name = "LadderStarboard" if sgn > 0.0 else "LadderPort"
		lad.length = 2.15
		lad.rail = 0.75
		lad.deck_depth = 0.9
		lad.position = Vector3(sgn * 3.0, DECK_Y, 0.6)
		lad.rotation.y = sgn * PI * 0.5
		ship_model.add_child(lad)
