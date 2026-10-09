extends AnimatableBody3D
class_name Ship
## The player's sloop. A kinematic body moved by its own simple boat model:
## the sails are set in steps (W/S at the wheel) and stay set, so she keeps
## making way with nobody steering; speed builds slowly toward what the sails
## give and drag bleeds it off; the rudder (A/D) turns harder the faster you
## go; with the sails furled and nearly stopped, holding S backs her. The hull
## heaves, pitches and rolls on the swell, averaged over bow, stern and both
## sides so the motion is a slow roll rather than a jitter. Being a moving
## platform (sync_to_physics), it carries whoever stands on the deck. It
## slides along / stops against shores and docks instead of passing through.
##
## Co-op: every machine runs this same simulation (so the deck under you moves
## smoothly whatever the network does) from the helmsman's sails and rudder,
## and eases toward the helmsman's latest state, projected to now.

const MAX_SPEED := 13.0
const MAX_REVERSE := 3.0
const ACCEL := 2.6
const BRAKE := 4.0
## Turn rate (rad/s) at full rudder once there's flow over it (>= 4 m/s).
const MAX_TURN := 0.55
## The hull's layout (deck heights, the quarterdeck, mast, rigging) is
## HullBuilder's, shared with the pirates' ships.
const FREEBOARD := HullBuilder.FREEBOARD
## How much of the swell the hull follows (a 23 m hull rides over the 8 m waves).
const HEAVE_SCALE := 0.4
const BOW_Z := HullBuilder.BOW_Z
const STERN_Z := HullBuilder.STERN_Z
const HALF_BEAM := HullBuilder.HALF_BEAM
const DECK_Y := HullBuilder.DECK_Y
const QD_Y := HullBuilder.QD_Y
## The crew cabin's fittings (ship-local, on the cabin floor): the bed (and
## where you wake beside it), the galley stove, the storage chest.
const BED_AT := Vector3(-3.25, DECK_Y, 8.45)
const STOVE_AT := Vector3(3.3, DECK_Y, 9.05)
const STORAGE_AT := Vector3(-2.7, DECK_Y, 5.75)
const COUNTER_AT := Vector3(3.35, DECK_Y, 7.55)
const TABLE_AT := Vector3(0.2, DECK_Y, 8.7)
## Hull strength: enemy cannon fire wears it down. At zero the ship is
## crippled (barely makes way, smoke and flames) until it patches itself up.
const MAX_HULL := 400.0
const CRIPPLED_SPEED := 0.35
const REPAIR_DELAY := 10.0
const REPAIR_RATE := 5.0
## Sail settings above furled (W/S step through them), and how fast the canvas
## comes down or goes up (fraction of the sail a second).
const SAIL_STEPS := 3
const SAIL_RATE := 0.5
## Co-op: how quickly a copy of the ship eases onto the helmsman's (1/s), and
## how far off it may be before it just jumps there.
const FIX_RATE := 2.5
const FIX_SNAP := 6.0
const PACK_SIZE := 15

var is_player_steering: bool = false
## Current forward speed (m/s, negative = backing) and smoothed rudder (-1..1).
var speed: float = 0.0
var rudder: float = 0.0
## The sails as set (0 furled .. 1 full) and as they are right now (the
## canvas takes a moment to come down; the speed follows what's set out).
var sail: float = 0.0
var sail_shown: float = 0.0
var _turn_in: float = 0.0
var _back_in: bool = false
var _sail_node: Node3D
var _furl_node: Node3D
var _rig: Node3D
var _brace: float = 0.0
## Riding to her anchor: she stops and stays, sails or no sails.
var anchored: bool = false
var _anchor: Node3D
var _cable: Node3D
var _anchor_drop: float = 0.0
## The anchor hangs from the cathead here (ship-model space), off the bow.
const ANCHOR_AT := Vector3(2.4, 1.3, -9.3)
const CAPSTAN_AT := Vector3(0.0, DECK_Y, -7.0)
const CHAIN_STEP := 0.13
const CHAIN_LINKS := 46
const ANCHOR_TIME := 1.6
const PORT_REACH := 40.0
## How the hull moved over the last tick (Player._ride_ship carries jumpers by it).
var _deck_delta := Transform3D.IDENTITY
## Camera yaw offset from the heading while at the helm (mouse look).
var cam_yaw: float = 0.0

var wheel: Node3D
var hull: float = MAX_HULL
var max_hull: float = MAX_HULL
var crippled: bool = false
## The shipwright's work (ShipKit): refits and looks.
var kit: Dictionary = {}
var _top_k: float = 1.0
var _turn_k: float = 1.0
var _psx_model: MeshInstance3D
var _hull_mat: Material
var _canvas_mat: Material
var _flag_node: MeshInstance3D
var _figure_node: Node3D
var _armour_node: Node3D
## Rain on deck: how wet she is (0..1), the puddles it pools into.
var wet: float = 0.0
const WET_TIME := 50.0
const DRY_TIME := 160.0
## [x, z, radius] of the low spots on deck where the rain pools.
const PUDDLES := [[-1.9, -4.2, 1.3], [1.9, 1.0, 1.1], [-1.3, 3.2, 1.15], [1.8, -6.4, 0.95], [-2.3, 0.4, 0.8], [0.6, -9.2, 0.7]]
var _deck_mat: Material
var _wet_deck: ShaderMaterial
var _puddles: Node3D
var _drip_t: float = 0.0
## Swivel guns on the rails (port and starboard).
var cannons: Array = []
var _since_hit: float = 99.0
var _hull_sent: float = MAX_HULL
var _hull_send_t: float = 0.0
var _burn_t: float = 0.0
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
@onready var disembark_position: Marker3D = $ShipModel/DisembarkPosition
@onready var respawn_point: Marker3D = $RespawnPoint
@onready var helm_zone: Interactable = $HelmZone
## The storage chest in the cabin (a LootBag that never empties away).
var storage: LootBag
@onready var ship_camera: Node3D = $ShipCamera


func _ready() -> void:
	add_to_group("decks")
	_build_psx_model()
	_build_collision()
	_build_cannons()
	_ocean = get_node_or_null("/root/Ocean")
	_game_manager = get_node("/root/GameManager")
	apply_kit(_game_manager.ship_kit)
	helm_zone.interacted.connect(_on_helm_interacted)
	helm_zone.reach = 1.0
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
	sail = 0.0
	sail_shown = 0.0
	_deck_delta = Transform3D.IDENTITY
	global_transform = Transform3D(Basis(Vector3.UP, yaw), Vector3(world_pos.x, global_position.y, world_pos.z))
	reset_physics_interpolation()


func _physics_process(delta: float) -> void:
	if not _placed:
		_placed = true
		_pos = global_position
		_heading = global_rotation.y
	# the helmsman's latest state when someone else steers
	var snap: Array = []
	if Net.active and Net.ship_owner != Net.my_id():
		snap = Net.latest(self)
		# (a word older than a second is from before the wheel last changed hands)
		if snap.size() == 2 and (snap[1] as Array).size() >= PACK_SIZE and Net.time() - float(snap[0]) < 1.0:
			var s: Array = snap[1]
			sail = float(s[11])
			_turn_in = float(s[12])
			_back_in = bool(s[13])
			set_anchored(bool(s[14]))
		else:
			snap = []
	else:
		_read_helm()
	sail_shown = move_toward(sail_shown, sail, SAIL_RATE * delta)
	var heading := _heading
	var pos := _pos
	var fwd := Vector3(-sin(heading), 0.0, -cos(heading))
	var right := Vector3(cos(heading), 0.0, -sin(heading))

	# (water in her: low and sluggish; a fair wind: a little faster)
	var top := MAX_SPEED * _top_k * (CRIPPLED_SPEED if crippled else 1.0) * (1.0 - 0.55 * flood) * wind_effect()
	var want := top * sail_shown
	_fair_wind_note()
	if summoning():
		want = _summon_drive(delta)
	if anchored:
		# brought up short by the cable, and swinging to it no more
		speed = move_toward(speed, 0.0, 3.0 * delta)
		_yaw_rate = move_toward(_yaw_rate, 0.0, 0.5 * delta)
	elif _back_in:
		speed = move_toward(speed, -MAX_REVERSE, BRAKE * delta)
	elif speed < want:
		speed = move_toward(speed, want, ACCEL * delta)
	else:
		speed = move_toward(speed, want, (0.35 + 0.012 * speed * speed) * delta)
	rudder = move_toward(rudder, _turn_in, 2.2 * _turn_k * delta)
	var flow := clampf(absf(speed) / 4.0, 0.3, 1.0) * (0.0 if anchored else 1.0)
	var target_rate := -rudder * MAX_TURN * _turn_k * flow * (-1.0 if speed < -0.3 else 1.0)
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
					Net.fx("sfx", ["thud", global_position + fwd * (BOW_Z * -1.0), 2.0, 0.05, 0.6])
				speed *= lerpf(1.0, -0.15, head_on)
				_yaw_rate *= 0.5
	pos += motion
	# a whirlpool drags her round and in (the same on every screen)
	var sf := get_tree().get_first_node_in_group("sea_features")
	if sf:
		pos += sf.current_at(pos) * delta
	if not snap.is_empty():
		var fixed := _follow_helmsman(snap, pos, heading, delta)
		pos = fixed[0]
		heading = fixed[1]
		fwd = Vector3(-sin(heading), 0.0, -cos(heading))
		right = Vector3(cos(heading), 0.0, -sin(heading))

	# swell: sample the waves under bow, stern and both sides
	var t: float = _ocean.call("clock") if _ocean and _ocean.has_method("clock") else Time.get_ticks_msec() / 1000.0
	var hb := _wave(pos + fwd * -BOW_Z, t)
	var hs := _wave(pos + fwd * -STERN_Z, t)
	var hp := _wave(pos - right * HALF_BEAM, t)
	var hr := _wave(pos + right * HALF_BEAM, t)
	var hc := _wave(pos, t)
	var mean := (hb + hs + hp + hr + hc * 2.0) / 6.0
	# (bow/stern/sides average most of the swell away; the midship sample
	# keeps a slow, shallow rise and fall)
	var target_y := lerpf(mean, hc, 0.5) * HEAVE_SCALE + FREEBOARD - 0.6 * flood
	var accel_f := (speed - _prev_speed) / maxf(delta, 0.0001)
	_prev_speed = speed
	var target_pitch := clampf(atan((hb - hs) / (STERN_Z - BOW_Z)) * 0.35, -0.045, 0.045) + clampf(accel_f * 0.008, -0.03, 0.03) + clampf(speed * 0.003, -0.01, 0.04)
	var target_roll := clampf(atan((hr - hp) / (HALF_BEAM * 2.0)) * 0.3, -0.05, 0.05) + clampf(_yaw_rate * speed * 0.01, -0.06, 0.06) - 0.12 * flood * _list_side()
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
	var xf := Transform3D(Basis.from_euler(Vector3(_pitch, heading, _roll)), Vector3(pos.x, _y, pos.z))
	_deck_delta = xf * global_transform.affine_inverse()
	global_transform = xf

	# wheel follows the rudder
	if wheel:
		wheel.rotation.z = -rudder * 2.4
	_wake(delta, pos, fwd, right, mean)
	if speed > top:
		speed = move_toward(speed, top, 2.0 * delta)
	if not Net.is_client():
		_damage_tick(delta)


## The helmsman's hands (their machine, or the host's when nobody steers:
## the sails stay as they were, the rudder eases back to centre).
func _read_helm() -> void:
	_turn_in = 0.0
	_back_in = false
	if not is_player_steering or _helm_locked():
		return
	# (someone took the wheel while she was sailing in by herself)
	_summon_to = Vector3.INF
	_turn_in = Input.get_axis("move_left", "move_right")
	var was := sail
	if Input.is_action_just_pressed("move_forward"):
		sail = minf(roundf(sail * SAIL_STEPS + 1.0) / SAIL_STEPS, 1.0)
	elif Input.is_action_just_pressed("move_back"):
		sail = maxf(roundf(sail * SAIL_STEPS - 1.0) / SAIL_STEPS, 0.0)
	if sail != was:
		var names := ["Sails furled", "A third of sail", "Two thirds of sail", "Full sail"]
		get_tree().call_group("hud", "show_toast", names[int(roundf(sail * SAIL_STEPS))])
		FX.sfx("whoosh", global_position + Vector3.UP * 7.0, -8.0, 0.08, 0.6)
	if Input.is_action_just_pressed("jump"):
		set_anchored(not anchored)
		get_tree().call_group("hud", "show_toast", "Let go the anchor!" if anchored else "Anchor's aweigh")
	# furled and nearly stopped: hold S to back her
	_back_in = Input.is_action_pressed("move_back") and sail <= 0.0 and speed < 1.5


## Ease our copy of the ship onto the helmsman's: their last state, carried
## forward to now at its speed and turn rate. Returns [pos, heading].
func _follow_helmsman(snap: Array, pos: Vector3, heading: float, delta: float) -> Array:
	var s: Array = snap[1]
	var ahead := clampf(Net.time() - float(snap[0]), 0.0, 0.5)
	var their_speed := float(s[5])
	var their_rate := float(s[7])
	var mid := float(s[1]) + their_rate * ahead * 0.5
	var at: Vector3 = (s[0] as Vector3) + Vector3(-sin(mid), 0.0, -cos(mid)) * their_speed * ahead
	var head := float(s[1]) + their_rate * ahead
	if Vector2(at.x - pos.x, at.z - pos.z).length() > FIX_SNAP:
		speed = their_speed
		_yaw_rate = their_rate
		return [Vector3(at.x, 0.0, at.z), head]
	var k := 1.0 - exp(-FIX_RATE * delta)
	speed = lerpf(speed, their_speed, k)
	_yaw_rate = lerpf(_yaw_rate, their_rate, k)
	rudder = lerpf(rudder, float(s[6]), k)
	return [pos + Vector3(at.x - pos.x, 0.0, at.z - pos.z) * k, lerp_angle(heading, head, k)]


func deck_delta() -> Transform3D:
	return _deck_delta


## Knocked hard (a ram, a Sea King's tail): `push` (world) throws her over
## and rocks her bow; the hull's springs bring her back.
func jolt(push: Vector3) -> void:
	var l := global_basis.inverse() * push
	_vroll += clampf(-l.x * 0.06, -0.5, 0.5)
	_vpitch += clampf(l.z * 0.04, -0.3, 0.3)
	_vy += 0.6


## Inside the ship's bounds: on deck, in the rigging, on a ladder, jumping
## about over the deck (co-op positions are sent relative to the hull then).
func aboard(p: Vector3) -> bool:
	return HullBuilder.aboard_local(global_transform.affine_inverse() * p)


## The hull's own velocity (cannonballs fired from it carry it along).
func hull_velocity() -> Vector3:
	return Vector3(-sin(_heading), 0.0, -cos(_heading)) * speed


# ==========================================================================
# Cannons and the hull
# ==========================================================================
## [z, x, deck height] of each pair of swivel guns: the foredeck, forward of
## the mast (clear of the rigging), and (the shipwright's refit) up on the
## quarterdeck.
const GUN_SPOTS := [[-6.8, 3.0, DECK_Y], [-4.2, 3.65, DECK_Y], [8.0, 3.55, QD_Y]]


func _build_cannons() -> void:
	for i in range(2):
		_add_gun_pair(i)


func _add_gun_pair(i: int) -> void:
	for sgn in [-1.0, 1.0]:
		var c := ShipCannon.new()
		c.name = "Cannon%s%d" % ["S" if sgn > 0.0 else "P", i]
		c.ship = self
		c.team = "crew"
		c.position = Vector3(sgn * float(GUN_SPOTS[i][1]), float(GUN_SPOTS[i][2]), float(GUN_SPOTS[i][0]))
		c.rotation.y = -sgn * PI * 0.5
		ship_model.add_child(c)
		cannons.append(c)


## Cannons on one side: +1 starboard, -1 port.
func side_cannons(side: float) -> Array:
	var out: Array = []
	for c in cannons:
		if signf((c as Node3D).position.x) == signf(side):
			out.append(c)
	return out


## The helmsman's broadside: every loaded, unmanned gun on that side fires
## at `target` (one after another). Returns how many fired.
func broadside(side: float, target: Vector3, by: Node) -> int:
	var n := 0
	for c in side_cannons(side):
		var cn := c as ShipCannon
		if not cn.loaded() or (cn.holder() != 0 and cn.holder() != Net.my_id()) or cn.aiming_locally:
			continue
		cn.aim_at(target)
		var delay := 0.16 * n
		n += 1
		if delay <= 0.0:
			cn.fire(by)
		else:
			get_tree().create_timer(delay).timeout.connect(func():
				if is_instance_valid(cn):
					cn.aim_at(target)
					cn.fire(by))
	return n


## Enemy cannon fire hit the ship (decided by the host): the hull takes it,
## and a heavy hit may hole her near the waterline or set the deck alight.
func hull_hit(dmg: float, at: Vector3) -> void:
	if Net.is_client():
		return
	hull = maxf(hull - dmg, 0.0)
	_since_hit = 0.0
	FX.dust(at, 10, 0.8)
	Net.fx("float_text", [at + Vector3(0, 1.4, 0), "-%d hull" % int(round(dmg)), Color(1.0, 0.62, 0.25), 30])
	if hull <= 0.0 and not crippled:
		_set_crippled(true)
	_send_hull(true)
	if dmg >= BREACH_MIN_DMG:
		var l := global_transform.affine_inverse() * at
		var z := clampf(l.z, DECK_Z_MIN, DECK_Z_MAX)
		if breaches.size() < MAX_BREACHES and _dmg_rng.randf() < BREACH_CHANCE:
			add_breach(-1.0 if l.x < 0.0 else 1.0, z)
		if fires.size() < MAX_FIRES and _dmg_rng.randf() < FIRE_CHANCE:
			add_fire(Vector3(clampf(l.x, -DECK_X_MAX, DECK_X_MAX), DECK_Y, z))


func _set_crippled(on: bool) -> void:
	if crippled == on:
		return
	crippled = on
	if on:
		get_tree().call_group("hud", "show_banner", "Hull breached!", "The ship barely makes way until she's patched up", false)
		FX.sfx("wood_crack", global_position, 4.0, 0.05, 0.7)
	else:
		get_tree().call_group("hud", "show_toast", "The hull is patched up")


func _send_hull(now: bool) -> void:
	if not Net.active or Net.is_client():
		return
	if now or absf(hull - _hull_sent) >= 8.0:
		_hull_sent = hull
		Net.ship_hull(hull)


## Co-op client: the host says how the hull is holding up.
func net_hull(v: float) -> void:
	if v < hull - 0.5:
		_since_hit = 0.0
	hull = v
	_set_crippled(hull <= 0.0 or (crippled and hull < max_hull * 0.5))


func _hull_tick(delta: float) -> void:
	_since_hit += delta
	if not Net.is_client():
		if _since_hit > REPAIR_DELAY and hull < max_hull and fires.is_empty():
			hull = minf(hull + REPAIR_RATE * delta, max_hull)
			_send_hull(false)
		if crippled and hull >= max_hull * 0.5 and flood < 0.5:
			_set_crippled(false)
			_send_hull(true)
	# a crippled ship smokes and burns on deck
	if crippled or hull < max_hull * 0.3:
		_burn_t -= delta
		if _burn_t <= 0.0:
			_burn_t = 0.25 if crippled else 0.6
			var spot := global_transform * Vector3(randf_range(-DECK_X_MAX, DECK_X_MAX), DECK_Y + 0.2, randf_range(DECK_Z_MIN, DECK_Z_MAX))
			FX.smoke(spot, 2, 1.2, 2.0)
			if crippled:
				FX.flame(spot, 4, 0.5, 0.5, 0.3)


# --------------------------------------------------------------------------
# Holes, flooding, fires - and the crew's jobs
# --------------------------------------------------------------------------
## Host side: each hole lets in FLOOD_RATE of "awash" a second; pumping takes
## out BAIL_RATE a second per captain at the pump. Each fire burns FIRE_BURN
## of the hull a second and may catch next to itself after FIRE_SPREAD.
## Every screen draws them from the host's word (net_damage) and its own
## captain does the work (hold F): patch a hole from the rail above it, beat
## out a fire, man the pump.
const FLOOD_RATE := 0.006
const BAIL_RATE := 0.12
const FIRE_BURN := 1.0
const FIRE_SPREAD := 24.0
const MAX_FIRES := 3
const MAX_BREACHES := 3
## Per cannonball hit of at least BREACH_MIN_DMG.
const BREACH_CHANCE := 0.15
const FIRE_CHANCE := 0.1
const BREACH_MIN_DMG := 10.0
const PATCH_TIME := 2.2
const DOUSE_TIME := 1.4
const WORK_REACH := 1.3
const PUMP_AT := Vector3(1.2, DECK_Y, -0.3)
## Where holes and fires can be on the main deck (ship-local).
const DECK_Z_MIN := -7.8
const DECK_Z_MAX := 4.4
const DECK_X_MAX := 2.6
## The waterline on her side (ship-local y), where holes show.
const WATERLINE_Y := -1.15

## [id, deck spot above the hole (ship-local)]
var breaches: Array = []
## [id, deck spot, age]
var fires: Array = []
## 0 dry .. 1 awash (foundering: crippled)
var flood: float = 0.0
var _dmg_id: int = 0
var _dmg_rng := RandomNumberGenerator.new()
var _flood_sent: float = 0.0
var _flood_send_t: float = 0.0
var _holes: Dictionary = {}
var _fx_t: float = 0.0
var _burn_me_t: float = 0.0
var _work_key: String = ""
var _work_t: float = 0.0
var _bail_t: float = 0.0
var _scrape_t: float = 0.0


## Which way she lists as she floods: toward her holes (-1 port .. 1 starboard).
func _list_side() -> float:
	if breaches.is_empty():
		return 0.0
	var s := 0.0
	for b in breaches:
		s += signf((b[1] as Vector3).x)
	return s / breaches.size()


## Host: hole her at `side` (-1 port, 1 starboard) abreast of `z`.
func add_breach(side: float, z: float) -> void:
	_dmg_id += 1
	breaches.append([_dmg_id, Vector3(side * (HullBuilder.half_width(z) - 0.55), DECK_Y, z)])
	FX.sfx("wood_crack", global_transform * Vector3(side * HullBuilder.half_width(z), WATERLINE_Y, z), 4.0, 0.05, 0.75)
	_send_damage()


## Host: a fire on deck at `at` (ship-local).
func add_fire(at: Vector3) -> void:
	_dmg_id += 1
	fires.append([_dmg_id, at, 0.0])
	_send_damage()


func _send_damage() -> void:
	_flood_sent = flood
	_rebuild_holes()
	Net.ship_damage([breaches, fires, flood])


## Not the host: what the host says is holed, burning and flooded.
func net_damage(data: Array) -> void:
	breaches = data[0]
	fires = data[1]
	flood = float(data[2])
	_rebuild_holes()


## Host: a captain did a job (on any screen).
func do_work(kind: String, id: int, amount: float) -> void:
	match kind:
		"patch":
			breaches = breaches.filter(func(b): return int(b[0]) != id)
		"douse":
			fires = fires.filter(func(f): return int(f[0]) != id)
		"bail":
			flood = maxf(flood - amount, 0.0)
			if absf(flood - _flood_sent) < 0.02 and flood > 0.0:
				return
	_send_damage()


## Host, every tick: water coming in, fires burning and spreading, a reef
## under her keel, a whirlpool's eye grinding her.
func _damage_tick(delta: float) -> void:
	var sf := get_tree().get_first_node_in_group("sea_features")
	if sf:
		var on_reef: bool = sf.reef_at(global_position) and absf(speed) > 1.5
		var in_eye: bool = sf.in_eye(global_position)
		if on_reef or in_eye:
			hull = maxf(hull - (absf(speed) * 1.4 if on_reef else 6.0) * delta, 1.0)
			_since_hit = 0.0
			_send_hull(false)
			if on_reef:
				speed = move_toward(speed, 0.0, 2.5 * delta)
			_scrape_t -= delta
			if _scrape_t <= 0.0:
				_scrape_t = 1.2
				Net.fx("sfx", ["wood_crack", global_position, 2.0, 0.08, 0.6])
				Net.fx("dust", [global_position + Vector3(0, 0.2, 0), 12, 1.2])
				CombatManager.apply_camera_shake(0.18)
				if breaches.size() < MAX_BREACHES and _dmg_rng.randf() < 0.4:
					add_breach(-1.0 if _dmg_rng.randf() < 0.5 else 1.0, _dmg_rng.randf_range(DECK_Z_MIN, DECK_Z_MAX))
	if not breaches.is_empty():
		flood = minf(flood + breaches.size() * FLOOD_RATE * delta, 1.0)
		if flood >= 1.0 and not crippled:
			_set_crippled(true)
			_send_hull(true)
	var spread: Array = []
	for f in fires:
		f[2] = float(f[2]) + delta
		hull = maxf(hull - FIRE_BURN * delta, 1.0)
		_since_hit = 0.0
		if float(f[2]) > FIRE_SPREAD and fires.size() + spread.size() < MAX_FIRES:
			f[2] = 0.0
			var a := _dmg_rng.randf() * TAU
			var p: Vector3 = f[1] + Vector3(cos(a), 0.0, sin(a)) * 1.6
			spread.append(Vector3(clampf(p.x, -DECK_X_MAX, DECK_X_MAX), DECK_Y, clampf(p.z, DECK_Z_MIN, DECK_Z_MAX)))
	if not fires.is_empty():
		_send_hull(false)
	for p in spread:
		add_fire(p)
	_flood_send_t -= delta
	if _flood_send_t <= 0.0 and absf(flood - _flood_sent) > 0.01:
		_flood_send_t = 0.5
		_send_damage()


## The holes, drawn: a ragged dark gash in the planking at the waterline.
func _rebuild_holes() -> void:
	var keep := {}
	for b in breaches:
		var id := int(b[0])
		keep[id] = true
		if _holes.has(id):
			continue
		var spot: Vector3 = b[1]
		var side := signf(spot.x)
		var mi := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(0.9, 0.6)
		mi.mesh = q
		mi.material_override = PSXMat.lit("planks_dark", Color(0.08, 0.06, 0.05))
		mi.position = Vector3(side * (_side_at(spot.z, WATERLINE_Y) + 0.03), WATERLINE_Y, spot.z)
		mi.rotation.y = side * PI * 0.5
		ship_model.add_child(mi)
		_holes[id] = mi
	for id in _holes.keys():
		if not keep.has(id):
			(_holes[id] as Node).queue_free()
			_holes.erase(id)


## Every screen: water gushing in, flames and smoke, burns for our captain
## standing in a fire, and our captain's jobs.
func _damage_view(delta: float) -> void:
	_fx_t -= delta
	if _fx_t <= 0.0:
		_fx_t = 0.15
		for f in fires:
			var at := global_transform * (f[1] as Vector3)
			FX.flame(at, 5, 0.75, 0.55, 0.35)
			if randf() < 0.4:
				FX.smoke(at + Vector3.UP * 0.6, 2, 1.2, 1.8)
		for b in breaches:
			var spot: Vector3 = b[1]
			var side := signf(spot.x)
			var at := global_transform * Vector3(side * (_side_at(spot.z, WATERLINE_Y) + 0.2), WATERLINE_Y + 0.1, spot.z)
			FX.splash(at, 3, 0.5)
	var me := get_tree().get_first_node_in_group("player") as Player
	if me == null or me.context != Player.Context.ON_FOOT or not aboard(me.global_position):
		local_job = ""
		_set_work("", 0.0)
		return
	var local := global_transform.affine_inverse() * me.global_position
	# standing in a fire
	_burn_me_t -= delta
	for f in fires:
		if Vector2(local.x - f[1].x, local.z - f[1].z).length() < 0.9 and absf(local.y - DECK_Y) < 0.6 and _burn_me_t <= 0.0:
			_burn_me_t = 0.5
			var hd := HitData.new()
			hd.dot = true
			hd.damage = 4.0
			me.hurtbox.take_hit(hd, self)
	# the nearest job within reach
	var job := ""
	var id := 0
	var best := WORK_REACH
	for b in breaches:
		var d := Vector2(local.x - b[1].x, local.z - b[1].z).length()
		if d < best:
			best = d; job = "patch"; id = int(b[0])
	for f in fires:
		var d := Vector2(local.x - f[1].x, local.z - f[1].z).length()
		if d < best:
			best = d; job = "douse"; id = int(f[0])
	if flood > 0.0 and Vector2(local.x - PUMP_AT.x, local.z - PUMP_AT.z).length() < best:
		job = "bail"; id = 0
	elif job == "" and Vector2(local.x - CAPSTAN_AT.x, local.z - CAPSTAN_AT.z).length() < WORK_REACH:
		job = "anchor"; id = 1 if anchored else 0
	local_job = job
	if job == "":
		_set_work("", 0.0)
		return
	var holding := Input.is_action_pressed("interact") and not me.input_locked
	var key := "%s%d" % [job, id]
	if key != _work_key:
		_work_key = key
		_work_t = 0.0
	match job:
		"bail":
			if holding:
				_bail_t += delta
				if _bail_t >= 0.25:
					Net.ship_work("bail", 0, BAIL_RATE * _bail_t)
					_bail_t = 0.0
			_set_work("Hold F: work the pump", flood)
		"anchor":
			_work_t = _work_t + delta if holding else 0.0
			me.body_model.kneeling = holding
			if _work_t >= ANCHOR_TIME:
				_work_t = 0.0
				me.body_model.kneeling = false
				Net.ship_anchor(not anchored)
				FX.sfx("rope", global_transform * CAPSTAN_AT, -2.0, 0.05, 0.75)
			_set_work("Hold F: weigh anchor" if anchored else "Hold F: let go the anchor", _work_t / ANCHOR_TIME)
		_:
			var need := PATCH_TIME if job == "patch" else DOUSE_TIME
			_work_t = _work_t + delta if holding else 0.0
			me.body_model.kneeling = holding
			if _work_t >= need:
				_work_t = 0.0
				me.body_model.kneeling = false
				Net.ship_work(job, id, 0.0)
				FX.sfx("wood_crack" if job == "patch" else "splash", me.global_position, -6.0, 0.05, 1.3)
			_set_work("Hold F: patch the hole" if job == "patch" else "Hold F: beat out the fire", _work_t / need)


var _prompting: bool = false
## The deck job our captain is in reach of ("" none): F is for it then, not
## a cannon or ladder close by (InteractionComponent stands aside).
var local_job: String = ""


func _set_work(text: String, progress: float) -> void:
	if text == "":
		if _prompting:
			_prompting = false
			get_tree().call_group("hud", "show_prompt", "", -1.0)
			var me := get_tree().get_first_node_in_group("player") as Player
			if me:
				me.body_model.kneeling = false
		return
	_prompting = true
	get_tree().call_group("hud", "show_prompt", text, progress)


## Bow spray and wake (every machine makes its own from the ship's speed).
func _wake(delta: float, pos: Vector3, fwd: Vector3, right: Vector3, mean: float) -> void:
	if absf(speed) > 1.0:
		Ocean.wake(self, pos - fwd * STERN_Z, clampf(absf(speed) / 9.0, 0.0, 1.0))
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
	# (shared through the host while there's a crew, local alone)
	storage.shared_id = "storage" if Net.active else ""
	_summon_view(delta)
	_hull_tick(delta)
	_show_sail(delta)
	_show_anchor(delta)
	_damage_view(delta)
	_rain_on_deck(delta)
	var xf := get_global_transform_interpolated()
	var heading := xf.basis.get_euler().y
	_cam_heading = lerp_angle(_cam_heading, heading, minf(4.0 * delta, 1.0))
	_cam_y = lerpf(_cam_y, xf.origin.y, minf(1.5 * delta, 1.0))
	ship_camera.global_position = Vector3(xf.origin.x, _cam_y + 4.5, xf.origin.z)
	ship_camera.global_rotation = Vector3(0.0, _cam_heading + cam_yaw, 0.0)


# ==========================================================================
# Deck collision: what you walk on matches what you see
# ==========================================================================
func _build_collision() -> void:
	# the hull, decks, cabin, stairs, mast and crow's nest
	HullBuilder.collide(self)
	# the helm post, the capstan, and the cabin's furniture
	_box_at(Vector3(0, QD_Y + 0.45, HullBuilder.WHEEL_Z + 0.1), Vector3(0.3, 0.9, 0.3))
	var capstan := CylinderShape3D.new()
	capstan.radius = 0.32
	capstan.height = 0.75
	_shape(capstan, Transform3D(Basis.IDENTITY, CAPSTAN_AT + Vector3(0, 0.37, 0)))
	_box_at(BED_AT + Vector3(0, 0.26, 0), Vector3(1.15, 0.52, 2.15))
	_box_at(STOVE_AT + Vector3(0, 0.45, 0), Vector3(0.95, 0.9, 0.95))
	_box_at(COUNTER_AT + Vector3(0, 0.45, 0), Vector3(0.8, 0.9, 1.6))
	_box_at(STORAGE_AT + Vector3(0, 0.3, 0), Vector3(1.0, 0.6, 0.65))
	_box_at(TABLE_AT + Vector3(0, 0.4, 0), Vector3(1.5, 0.8, 0.9))


# ==========================================================================
# Summoning (a captain ashore calls her: SummonShip on the player, Net)
# ==========================================================================
## She sails in at this speed, and is this deep-water clear all round.
const SUMMON_SPEED := 5.0
const SUMMON_DEPTH := 2.4
const SUMMON_FADE := 2.5
var _summon_to := Vector3.INF
var _summon_t: float = 0.0
var _fade_t: float = -1.0
## [mesh, surface (-1: the override), the material it had]
var _faded: Array = []
static var _fade_shader: Shader


## Where to bring her for a captain at `at`: [where she appears, where she
## anchors] - the nearest water deep and wide enough, and out to sea from
## it - or [] if there's none in reach.
func summon_spot(at: Vector3) -> Array:
	var best := Vector3.INF
	for r in [14.0, 20.0, 27.0, 35.0, 45.0]:
		for k in range(24):
			var a := TAU * k / 24.0
			var c := Vector3(at.x + cos(a) * r, 0.0, at.z + sin(a) * r)
			if _fits(c) and (best == Vector3.INF or c.distance_to(at) < best.distance_to(at)):
				best = c
		if best != Vector3.INF:
			break
	if best == Vector3.INF:
		return []
	var out := Vector3(best.x - at.x, 0.0, best.z - at.z).normalized()
	var from := best + out * 30.0
	return [from if _fits(from) else best, best]


## Deep water under her and round her (no land, docks or rocks). (Probed
## from high up: from sea level the ray would start inside a hillside.)
func _fits(c: Vector3) -> bool:
	for k in range(9):
		var p := c if k == 8 else c + Vector3(cos(TAU * k / 8.0), 0.0, sin(TAU * k / 8.0)) * 12.0
		p.y = 80.0
		if float(Ocean.depth_at(p, [get_rid()], true)) < SUMMON_DEPTH:
			return false
	return true


## Every screen: she fades in out of nothing at `from` and sails slowly in to
## `to`, where she lets go her anchor.
func summon(from: Vector3, to: Vector3) -> void:
	var d := to - from
	place(from, atan2(-d.x, -d.z) if Vector2(d.x, d.z).length() > 0.5 else _heading)
	set_anchored(false)
	_summon_to = to
	_summon_t = 0.0
	_fade_in()
	FX.sfx("bell", global_position + Vector3.UP * 4.0, 2.0, 0.02, 0.9)


func summoning() -> bool:
	return _summon_to != Vector3.INF


## The autopilot while she sails in (instead of the helm): toward the spot,
## slowing as she nears it, then the anchor.
func _summon_drive(delta: float) -> float:
	_summon_t += delta
	var to := _summon_to - _pos
	to.y = 0.0
	var dist := to.length()
	if dist < 2.5 or _summon_t > 30.0 or (_summon_t > 6.0 and absf(speed) < 0.3):
		_summon_to = Vector3.INF
		speed = 0.0
		set_anchored(true)
		return 0.0
	var diff := wrapf(atan2(-to.x, -to.z) - _heading, -PI, PI)
	_turn_in = clampf(-diff * 2.0, -1.0, 1.0)
	return SUMMON_SPEED * clampf(dist / 12.0, 0.3, 1.0)


## A PS1 dissolve: every lit surface of her swapped for a fading copy, which
## comes in over SUMMON_FADE; then the real materials go back.
func _fade_in() -> void:
	_fade_restore()
	if _fade_shader == null:
		_fade_shader = load("res://shaders/psx/psx_lit_fade.gdshader")
	for mi in ship_model.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.material_override:
			var fo := _fade_copy(m.material_override)
			if fo:
				_faded.append([m, -1, m.material_override])
				m.material_override = fo
			continue
		if m.mesh == null:
			continue
		for s in range(m.mesh.get_surface_count()):
			var f := _fade_copy(m.get_active_material(s))
			if f:
				_faded.append([m, s, m.get_surface_override_material(s)])
				m.set_surface_override_material(s, f)
	_fade_t = 0.0
	_set_fade(0.0)


func _fade_copy(mat: Material) -> ShaderMaterial:
	var sm := mat as ShaderMaterial
	if sm == null or sm.shader != PSXMat.LIT_SHADER:
		return null
	var f := sm.duplicate() as ShaderMaterial
	f.shader = _fade_shader
	return f


func _set_fade(k: float) -> void:
	for e in _faded:
		var m := e[0] as MeshInstance3D
		if not is_instance_valid(m):
			continue
		var mat := (m.material_override if int(e[1]) < 0 else m.get_surface_override_material(int(e[1]))) as ShaderMaterial
		if mat:
			mat.set_shader_parameter("fade", k)


func _fade_restore() -> void:
	for e in _faded:
		var m := e[0] as MeshInstance3D
		if not is_instance_valid(m):
			continue
		if int(e[1]) < 0:
			m.material_override = e[2]
		else:
			m.set_surface_override_material(int(e[1]), e[2])
	_faded.clear()
	_fade_t = -1.0


## The fade's progress, and the sea mist she comes out of.
func _summon_view(delta: float) -> void:
	if _fade_t < 0.0:
		return
	_fade_t += delta
	var k := clampf(_fade_t / SUMMON_FADE, 0.0, 1.0)
	_set_fade(k * k * (3.0 - 2.0 * k))
	if randf() < delta * 14.0 * (1.0 - k):
		var p := global_transform * Vector3(randf_range(-4.5, 4.5), randf_range(0.5, 6.0), randf_range(-12.0, 10.0))
		FX.smoke(p, 3, 3.0, 2.5)
	if k >= 1.0:
		_fade_restore()


func _box_at(at: Vector3, size: Vector3) -> void:
	var b := BoxShape3D.new()
	b.size = size
	_shape(b, Transform3D(Basis.IDENTITY, at))


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
		# co-op: one captain at the wheel (clients ask the host first; the
		# answer puts them at the helm - Player.take_helm)
		if Net.active and not Net.request_helm():
			return
		player.current_ship = self
		var sm := player.state_machine
		if sm.current_state:
			sm.current_state.transitioned.emit(sm.current_state, "Helm", {})


## Low-poly PSX sloop: tapered plank hull, deck, mast + sail, stern cabin,
## helm (the wheel is its own node so it can turn) and the banking chest.
func _build_psx_model() -> void:
	var mb := MeshBuilder.new()
	var hull := PSXMat.lit("planks_dark", Color.WHITE, {"affine": 0.6})
	var deck := PSXMat.lit("planks", Color.WHITE, {"affine": 0.6})
	var trim := PSXMat.lit("planks", Color(0.85, 0.65, 0.35))
	var canvas := PSXMat.lit("canvas", Color(0.95, 0.92, 0.82), {"affine": 0.6})
	var wood := PSXMat.lit("bark")
	var glass := PSXMat.glow(Color(1.0, 0.8, 0.4), 2.5)
	_hull_mat = hull
	_canvas_mat = canvas
	_deck_mat = deck

	# hull, decks, quarterdeck over the cabin, stairs, mast, crow's nest, rigging
	HullBuilder.hull(mb, {"hull": hull, "deck": deck, "trim": trim, "wood": wood, "rope": PSXMat.lit("rope")})
	_build_rig(canvas, wood)
	_build_climbing()
	_build_anchor(wood)
	# the bilge pump by the mast
	var pmb := MeshBuilder.new()
	pmb.add_box(wood, Transform3D(Basis(), PUMP_AT + Vector3(0, 0.35, 0)), Vector3(0.3, 0.7, 0.3), 1.0)
	pmb.add_box(trim, Transform3D(Basis(), PUMP_AT + Vector3(0, 0.75, 0)), Vector3(0.12, 0.12, 0.7), 1.0)
	pmb.add_box(trim, Transform3D(Basis(), PUMP_AT + Vector3(0.18, 0.55, 0)), Vector3(0.08, 0.08, 0.22), 1.0)
	ship_model.add_child(pmb.to_instance("Pump"))
	_dmg_rng.randomize()
	# the flag at the masthead (painted from the kit: apply_kit)
	var fmb := MeshBuilder.new()
	var flag := PSXMat.lit("cloth_red")
	var flag_at := Vector3(0, HullBuilder.MAST_TOP + 0.2, HullBuilder.MAST_Z + 0.45)
	fmb.add_card(flag, Transform3D(Basis(Vector3.UP, PI * 0.5), flag_at), 2.1, 1.25)
	fmb.add_card(flag, Transform3D(Basis(Vector3.UP, -PI * 0.5), flag_at), 2.1, 1.25, Rect2(1, 0, -1, 1))
	_flag_node = fmb.to_instance("Flag")
	ship_model.add_child(_flag_node)
	_figure_node = Node3D.new()
	_figure_node.name = "Figurehead"
	_figure_node.position = Vector3(0, 0.75, -12.6)
	_figure_node.rotation.x = 0.45
	_figure_node.scale = Vector3.ONE * 2.5
	ship_model.add_child(_figure_node)
	# windows either side of the cabin door, the stern lantern
	mb.add_box(glass, Transform3D(Basis(), Vector3(2.0, DECK_Y + 1.5, HullBuilder.QD_FRONT - 0.02)), Vector3(0.4, 0.4, 0.06), 1.0)
	mb.add_box(glass, Transform3D(Basis(), Vector3(-2.0, DECK_Y + 1.5, HullBuilder.QD_FRONT - 0.02)), Vector3(0.4, 0.4, 0.06), 1.0)
	mb.add_box(glass, Transform3D(Basis(), Vector3(0, QD_Y + 1.3, HullBuilder.QD_BACK + 0.15)), Vector3(0.3, 0.4, 0.3), 1.0, Color.WHITE, false)
	# the helm on the quarterdeck: its post, and the wheel (its own node, it turns)
	mb.add_box(wood, Transform3D(Basis(), Vector3(0, QD_Y + 0.45, HullBuilder.WHEEL_Z + 0.1)), Vector3(0.16, 0.9, 0.16), 1.0)
	var wmb := MeshBuilder.new()
	wmb.add_cylinder(trim, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 0, 0.03)), 0.42, 0.42, 0.06, 8, 1.0, Color.WHITE, true, true, false)
	for k in range(4):
		var b := Basis(Vector3.BACK, PI * k / 4.0)
		wmb.add_box(wood, Transform3D(b, Vector3(0, 0, -0.05)), Vector3(0.05, 1.05, 0.05), 1.0)
	wheel = wmb.to_instance("Wheel")
	wheel.position = Vector3(0, QD_Y + 0.93, HullBuilder.WHEEL_Z)
	ship_model.add_child(wheel)
	_build_cabin(mb, wood, trim, glass)
	_psx_model = mb.to_instance("PSXModel")
	ship_model.add_child(_psx_model)
	_build_armour(HullBuilder.RINGS)
	_build_puddles()
	# rope ladders down both sides: climb back aboard from the water
	for sgn in [-1.0, 1.0]:
		var lad := Ladder.new()
		lad.name = "LadderStarboard" if sgn > 0.0 else "LadderPort"
		lad.length = HullBuilder.LADDER_LEN
		lad.rail = 0.8
		lad.deck_depth = 0.9
		lad.position = Vector3(sgn * (HullBuilder.half_width(HullBuilder.LADDER_Z) + 0.02), DECK_Y, HullBuilder.LADDER_Z)
		lad.rotation.y = sgn * PI * 0.5
		ship_model.add_child(lad)


## The crew cabin under the quarterdeck: a bunk at the back on the port side,
## the galley (stove and counter) to starboard, the storage chest by the door,
## a table, stern windows and a lantern (with a little warm light).
func _build_cabin(mb: MeshBuilder, wood: Material, trim: Material, glass: Material) -> void:
	var cloth := PSXMat.lit("fabric", Color(0.55, 0.12, 0.1))
	var linen := PSXMat.lit("fabric", Color(0.9, 0.86, 0.75))
	var iron := PSXMat.lit("metal", Color(0.25, 0.24, 0.23))
	var fire := PSXMat.glow(Color(1.0, 0.45, 0.12), 3.0)
	var crate := PSXMat.lit("planks", Color(0.8, 0.65, 0.45))
	# the bunk: frame, mattress, a pillow and a red blanket
	mb.add_box(wood, Transform3D(Basis(), BED_AT + Vector3(0, 0.2, 0)), Vector3(1.15, 0.4, 2.15), 1.0)
	mb.add_box(linen, Transform3D(Basis(), BED_AT + Vector3(0, 0.46, 0)), Vector3(1.0, 0.14, 2.0), 1.0)
	mb.add_box(linen, Transform3D(Basis(), BED_AT + Vector3(0, 0.6, 0.72)), Vector3(0.7, 0.14, 0.4), 1.0)
	mb.add_box(cloth, Transform3D(Basis(), BED_AT + Vector3(0, 0.55, -0.3)), Vector3(1.04, 0.06, 1.3), 1.0)
	mb.add_box(wood, Transform3D(Basis(), BED_AT + Vector3(0, 0.45, 1.05)), Vector3(1.15, 0.9, 0.08), 1.0)
	# the galley: an iron stove with fire behind its door and a pipe up through
	# the deck, a counter with pots, a water barrel
	mb.add_box(iron, Transform3D(Basis(), STOVE_AT + Vector3(0, 0.45, 0)), Vector3(0.9, 0.9, 0.9), 1.0)
	mb.add_box(fire, Transform3D(Basis(), STOVE_AT + Vector3(-0.46, 0.35, 0)), Vector3(0.04, 0.3, 0.45), 1.0)
	mb.add_cylinder(iron, Transform3D(Basis(), STOVE_AT + Vector3(0.1, 0.9, 0.1)), 0.09, 0.09, QD_Y - DECK_Y - 0.9, 6, 1.0)
	mb.add_box(trim, Transform3D(Basis(), COUNTER_AT + Vector3(0, 0.45, 0)), Vector3(0.75, 0.9, 1.55), 0.6)
	mb.add_cylinder(iron, Transform3D(Basis(), COUNTER_AT + Vector3(0, 0.9, 0.35)), 0.2, 0.2, 0.25, 8, 1.0)
	mb.add_cylinder(iron, Transform3D(Basis(), COUNTER_AT + Vector3(-0.05, 0.9, -0.35)), 0.14, 0.12, 0.18, 8, 1.0)
	mb.add_cylinder(crate, Transform3D(Basis(), COUNTER_AT + Vector3(0.1, 0.0, -1.25)), 0.35, 0.35, 0.9, 8, 0.6)
	# storage: the chest by the door, crates and a barrel round it
	mb.add_box(crate, Transform3D(Basis(Vector3.UP, 0.2), STORAGE_AT + Vector3(-0.4, 0.3, 1.0)), Vector3(0.6, 0.6, 0.6), 1.0)
	mb.add_box(crate, Transform3D(Basis(Vector3.UP, -0.3), STORAGE_AT + Vector3(-0.45, 0.85, 1.0)), Vector3(0.45, 0.45, 0.45), 1.0)
	mb.add_cylinder(crate, Transform3D(Basis(), STORAGE_AT + Vector3(0.9, 0.0, -0.05)), 0.32, 0.32, 0.8, 8, 0.6)
	# the table and two stools
	mb.add_box(wood, Transform3D(Basis(), TABLE_AT + Vector3(0, 0.78, 0)), Vector3(1.5, 0.07, 0.9), 1.0)
	for sx in [-0.6, 0.6]:
		for sz in [-0.35, 0.35]:
			mb.add_box(wood, Transform3D(Basis(), TABLE_AT + Vector3(sx, 0.38, sz)), Vector3(0.08, 0.76, 0.08), 1.0)
	for sx in [-0.4, 0.5]:
		mb.add_cylinder(wood, Transform3D(Basis(), TABLE_AT + Vector3(sx, 0.0, -0.75)), 0.2, 0.18, 0.45, 6, 1.0)
	# stern windows, a lantern hung from a beam
	for sx in [-1.6, 0.0, 1.6]:
		mb.add_box(glass, Transform3D(Basis(), Vector3(sx, DECK_Y + 1.55, HullBuilder.QD_BACK - 0.18)), Vector3(0.6, 0.45, 0.04), 1.0)
	mb.add_box(glass, Transform3D(Basis(), Vector3(0.2, QD_Y - 0.65, 7.6)), Vector3(0.22, 0.3, 0.22), 1.0)
	_line_mesh(mb, iron, Vector3(0.2, QD_Y - 0.5, 7.6), Vector3(0.2, QD_Y - 0.2, 7.6))
	# the storage chest (the crew's bank: GameManager.storage, shared in co-op),
	# the bunk (rest) and the galley (restock provisions)
	storage = (load("res://scenes/loot/loot_bag.tscn") as PackedScene).instantiate() as LootBag
	storage.name = "Storage"
	storage.persistent = true
	storage.label = "Ship's storage"
	storage.shared_id = "storage" if Net.active else ""
	if not Net.is_client():
		storage.contents = _game_manager_storage()
	ship_model.add_child(storage)
	storage.position = STORAGE_AT
	(storage.get_node("MeshInstance3D") as MeshInstance3D).mesh = Props.treasure_chest_mesh()
	(storage.get_node("MeshInstance3D") as MeshInstance3D).position = Vector3.ZERO
	storage.get_node("CollisionShape3D").queue_free()
	var chest_cs := storage.get_node("Interactable/CollisionShape3D") as CollisionShape3D
	chest_cs.shape = chest_cs.shape.duplicate()
	(chest_cs.shape as SphereShape3D).radius = 1.1
	storage.interactable.reach = 1.1
	var bunk := _cabin_zone("Bunk", "Rest in the bunk", BED_AT + Vector3(0.85, 0.6, 0.0))
	bunk.interacted.connect(func(p: Player): _toast(get_node("/root/GameManager").rest(p)))
	var galley := _cabin_zone("Galley", "Restock provisions", COUNTER_AT + Vector3(-0.85, 0.6, 0.3))
	galley.interacted.connect(func(p: Player): _toast(get_node("/root/GameManager").restock(p)))
	var lamp := OmniLight3D.new()
	lamp.name = "CabinLight"
	lamp.light_color = Color(1.0, 0.75, 0.45)
	lamp.light_energy = 1.4
	lamp.omni_range = 6.5
	lamp.shadow_enabled = false
	lamp.position = Vector3(0.2, QD_Y - 0.8, 7.6)
	ship_model.add_child(lamp)


## (GameManager's storage array itself: the chest edits it in place, saves read it)
func _game_manager_storage() -> Array[ItemStack]:
	return get_node("/root/GameManager").storage


func _cabin_zone(n: String, prompt: String, at: Vector3) -> Interactable:
	var z := Interactable.new()
	z.name = n
	z.collision_layer = 512
	z.collision_mask = 0
	z.prompt_text = prompt
	z.reach = 0.9
	var cs := CollisionShape3D.new()
	var sp := SphereShape3D.new()
	sp.radius = 0.9
	cs.shape = sp
	z.add_child(cs)
	z.position = at
	ship_model.add_child(z)
	return z


func _toast(text: String) -> void:
	get_tree().call_group("hud", "show_toast", text)


func _line_mesh(mb: MeshBuilder, mat: Material, a: Vector3, b: Vector3) -> void:
	HullBuilder._line(mb, mat, a, b, 0.03)


## Iron straps down her sides and a rubbing band along them (the armour refit).
func _build_armour(rings: Array) -> void:
	var iron := PSXMat.lit("metal", Color(0.55, 0.55, 0.6))
	var mb := MeshBuilder.new()
	for z in [-8.0, -5.0, -2.0, 1.0, 4.0, 7.0, 9.4]:
		var r := _ring_at(rings, z)
		var top := Vector2(float(r[1]), float(r[3]))
		var low := top.lerp(Vector2(float(r[2]), float(r[4])), 0.55)
		var along := top - low
		for sgn in [-1.0, 1.0]:
			var mid := (top + low) * 0.5
			var b := Basis(Vector3.BACK, -sgn * asin(along.x / along.length()))
			mb.add_box(iron, Transform3D(b, Vector3(sgn * (mid.x + 0.04), mid.y, z)), Vector3(0.07, along.length(), 0.22), 1.0)
	for i in range(rings.size() - 2):
		var a: Array = rings[i]
		var c: Array = rings[i + 1]
		for sgn in [-1.0, 1.0]:
			var p0 := Vector3(sgn * (float(a[1]) - 0.05), float(a[3]) - 0.35, float(a[0]))
			var p1 := Vector3(sgn * (float(c[1]) - 0.05), float(c[3]) - 0.35, float(c[0]))
			mb.add_box(iron, Transform3D(Basis.looking_at((p1 - p0).normalized(), Vector3.UP), (p0 + p1) * 0.5), Vector3(0.08, 0.12, p0.distance_to(p1) + 0.05), 1.0)
	_armour_node = mb.to_instance("Armour")
	_armour_node.visible = false
	ship_model.add_child(_armour_node)


## Flat, ragged puddles in the deck's low spots (grown by `wet`), and a copy
## of the deck planks to darken as they soak.
func _build_puddles() -> void:
	_wet_deck = (_deck_mat as ShaderMaterial).duplicate() as ShaderMaterial
	for i in range(_psx_model.mesh.get_surface_count()):
		if _psx_model.mesh.surface_get_material(i) == _deck_mat:
			_psx_model.set_surface_override_material(i, _wet_deck)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.13, 0.17, 0.22, 0.7)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.roughness = 0.05
	mat.metallic_specular = 1.0
	_puddles = Node3D.new()
	_puddles.name = "Puddles"
	ship_model.add_child(_puddles)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	for p in PUDDLES:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		st.set_normal(Vector3.UP)
		var pts: Array = []
		for k in range(12):
			var a := TAU * k / 12.0
			pts.append(Vector3(cos(a), 0, sin(a) * 0.75) * rng.randf_range(0.65, 1.15))
		for k in range(12):
			st.add_vertex(Vector3.ZERO)
			st.add_vertex(pts[k])
			st.add_vertex(pts[(k + 1) % 12])
		var mi := MeshInstance3D.new()
		mi.mesh = st.commit()
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position = Vector3(float(p[0]), DECK_Y + 0.012, float(p[1]))
		mi.visible = false
		_puddles.add_child(mi)


## Rain soaks the planks and pools on deck (and they dry out after); the
## puddles run to the low side as she rolls, and the drops ripple them.
func _rain_on_deck(delta: float) -> void:
	var rain: float = Weather.rain
	if rain > 0.1:
		wet = minf(wet + rain * delta / WET_TIME, 1.0)
	else:
		wet = maxf(wet - delta / DRY_TIME, 0.0)
	_wet_deck.set_shader_parameter("albedo_color", Color.WHITE.lerp(Color(0.55, 0.53, 0.56), clampf(wet * 1.5, 0.0, 1.0)))
	# (rolled to starboard-up, the water runs to port; bow up, it runs aft)
	_puddles.position = Vector3(clampf(-_roll * 7.0, -0.45, 0.45), 0.0, clampf(_pitch * 9.0, -0.5, 0.5))
	for i in range(_puddles.get_child_count()):
		var mi := _puddles.get_child(i) as MeshInstance3D
		var k := clampf((wet - 0.15 - i * 0.08) / 0.5, 0.0, 1.0)
		mi.visible = k > 0.02
		mi.scale = Vector3.ONE * float(PUDDLES[i][2]) * k
	_drip_t -= delta
	if rain > 0.2 and wet > 0.3 and _drip_t <= 0.0:
		_drip_t = 0.25 / rain
		var mi := _puddles.get_child(randi() % _puddles.get_child_count()) as MeshInstance3D
		if mi.visible:
			FX.splash(mi.global_transform * Vector3(randf_range(-0.5, 0.5), 0.0, randf_range(-0.4, 0.4)) + Vector3.UP * 0.03, 1, 0.12)


## The hull's half-width at (z, y): from the rail tapering down to the keel.
func _side_at(z: float, y: float) -> float:
	var r := _ring_at(HullBuilder.RINGS, z)
	var k := clampf((float(r[3]) - y) / maxf(float(r[3]) - float(r[4]), 0.01), 0.0, 1.0)
	return lerpf(float(r[1]), float(r[2]), k)


## The hull's cross-section at `z` ([z, top half-width, bottom half-width, top y, bottom y]).
func _ring_at(rings: Array, z: float) -> Array:
	for i in range(rings.size() - 1):
		var a: Array = rings[i]
		var b: Array = rings[i + 1]
		if z <= float(a[0]) and z >= float(b[0]):
			var k := (float(a[0]) - z) / (float(a[0]) - float(b[0]))
			var out: Array = [z]
			for j in range(1, 5):
				out.append(lerpf(float(a[j]), float(b[j]), k))
			return out
	return rings[0]


## Put the shipwright's work on her (every screen: the host's kit in co-op).
func apply_kit(k: Dictionary) -> void:
	kit = ShipKit.merged(k)
	var was := max_hull
	max_hull = MAX_HULL * (1.4 if kit["armour"] else 1.0)
	hull = clampf(hull + maxf(max_hull - was, 0.0), 0.0, max_hull)
	_top_k = 1.15 if kit["sails"] else 1.0
	_turn_k = 1.3 if kit["rudder"] else 1.0
	if kit["guns"] and cannons.size() < GUN_SPOTS.size() * 2:
		_add_gun_pair(2)
	_armour_node.visible = kit["armour"]
	_rig.scale = Vector3(1.18, 1.12, 1.0) if kit["sails"] else Vector3.ONE
	var paint := (_hull_mat as ShaderMaterial).duplicate() as ShaderMaterial
	paint.set_shader_parameter("albedo_color", ShipKit.HULL_PAINT[int(kit["hull"])][1])
	for i in range(_psx_model.mesh.get_surface_count()):
		if _psx_model.mesh.surface_get_material(i) == _hull_mat:
			_psx_model.set_surface_override_material(i, paint)
	var sails := (_canvas_mat as ShaderMaterial).duplicate() as ShaderMaterial
	sails.set_shader_parameter("albedo_color", ShipKit.SAILS[int(kit["sail"])][1])
	_sail_node.material_override = sails
	_furl_node.material_override = sails
	var flag := ShaderMaterial.new()
	flag.shader = PSXMat.LIT_SHADER
	flag.set_shader_parameter("albedo_tex", ImageTexture.create_from_image(ShipKit.flag_image(kit)))
	flag.set_shader_parameter("albedo_color", Color.WHITE)
	flag.set_shader_parameter("affine_amount", 0.6)
	flag.set_shader_parameter("use_vertex_color", true)
	_flag_node.material_override = flag
	for c in _figure_node.get_children():
		c.free()
	var fig := ShipKit.figurehead(int(kit["figure"]))
	if fig:
		_figure_node.add_child(fig)


## The rig: the yard on the mast (it swings round to trim to the wind), the
## sail hanging from it (its own node, origin on the yard, so it rolls up by
## scaling toward it and fills or flaps), and the furled canvas on the yard.
func _build_rig(canvas: Material, wood: Material) -> void:
	var pivot := Vector3(0, HullBuilder.YARD_Y, HullBuilder.MAST_Z)
	_rig = Node3D.new()
	_rig.name = "Rig"
	_rig.position = pivot
	ship_model.add_child(_rig)
	var ymb := MeshBuilder.new()
	ymb.add_cylinder(wood, Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(4.5, 0, 0)), 0.12, 0.12, 9.0, 6, 0.8)
	_rig.add_child(ymb.to_instance("Yard"))
	var sz := HullBuilder.MAST_Z + 0.25
	var top := Vector3(0, HullBuilder.YARD_Y - 0.15, sz)
	var mid_y := top.y - 4.35
	var bot_y := mid_y - 4.2
	var smb := MeshBuilder.new()
	var n := Vector3(0, 0, 1)
	var dim := Color(0.8, 0.8, 0.75)
	var c := [Vector3(-4.2, top.y, sz) - top, Vector3(4.2, top.y, sz) - top, Vector3(3.9, mid_y, sz + 0.45) - top,
		Vector3(-3.9, mid_y, sz + 0.45) - top, Vector3(3.6, bot_y, sz + 0.1) - top, Vector3(-3.6, bot_y, sz + 0.1) - top]
	smb.add_quad(canvas, c[0], c[1], c[2], c[3], Vector2(0, 0), Vector2(2.0, 0), Vector2(2.0, 1.0), Vector2(0, 1.0), Color.WHITE, n)
	smb.add_quad(canvas, c[3], c[2], c[4], c[5], Vector2(0, 1.0), Vector2(2.0, 1.0), Vector2(2.0, 2.0), Vector2(0, 2.0), Color.WHITE, n)
	smb.add_quad(canvas, c[0], c[3], c[2], c[1], Vector2(0, 0), Vector2(0, 1.0), Vector2(2.0, 1.0), Vector2(2.0, 0), dim, -n)
	smb.add_quad(canvas, c[3], c[5], c[4], c[2], Vector2(0, 1.0), Vector2(0, 2.0), Vector2(2.0, 2.0), Vector2(2.0, 1.0), dim, -n)
	_sail_node = smb.to_instance("Sail")
	_sail_node.position = top - pivot
	_rig.add_child(_sail_node)
	var fmb := MeshBuilder.new()
	fmb.add_cylinder(canvas, Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(4.05, 0, 0)), 0.28, 0.28, 8.1, 6, 0.8)
	_furl_node = fmb.to_instance("FurledSail")
	_furl_node.position = top + Vector3(0, -0.12, 0.05) - pivot
	_rig.add_child(_furl_node)
	_show_sail(0.0)


## The rigging up to the crow's nest (both sides), and a rope to swing from at
## each end of the yard (they turn with it as it's braced round).
func _build_climbing() -> void:
	for sgn in [-1.0, 1.0]:
		var rig := ShipRigging.new()
		rig.name = "RiggingS" if sgn > 0.0 else "RiggingP"
		rig.side = sgn
		ship_model.add_child(rig)
		var rope := SwingRope.new()
		rope.name = "RopeS" if sgn > 0.0 else "RopeP"
		rope.length = HullBuilder.YARD_Y - DECK_Y - 2.2
		# (inside the rail, even with the bigger sails' longer yard)
		rope.position = Vector3(sgn * 3.6, -0.1, 0.0)
		_rig.add_child(rope)


## Canvas let down as far as sail_shown (the rest bundled on the yard); the
## yard braced round to the wind; the sail bellies out, fuller in a fair wind.
func _show_sail(delta: float) -> void:
	var k := clampf(sail_shown, 0.0, 1.0)
	var rel := _wind_rel()
	_brace = lerp_angle(_brace, clampf(rel * 0.5, -0.8, 0.8), clampf(1.5 * delta, 0.0, 1.0))
	_rig.rotation.y = _brace
	var belly := lerpf(0.8, 1.25, clampf((wind_effect() - 1.0) / FAIR_BOOST, 0.0, 1.0))
	_sail_node.scale = Vector3(1.0, lerpf(0.03, 1.0, k), belly)
	_sail_node.visible = k > 0.01
	var r := lerpf(1.0, 0.35, k)
	_furl_node.scale = Vector3(1.0, r, r)
	_furl_node.visible = k < 0.98


# --------------------------------------------------------------------------
# Wind
# --------------------------------------------------------------------------
## Where the wind blows, relative to the bow (radians, -PI..PI; 0 = from
## dead astern, running before it).
func _wind_rel() -> float:
	var wx := get_node_or_null("/root/Weather")
	var wd: Vector2 = wx.wind_dir() if wx else Vector2(1, 0)
	var fwd := Vector2(-sin(_heading), -cos(_heading))
	return fwd.angle_to(wd)


## The wind never holds her back: she sails at her own speed on any heading,
## and a fair wind (on the beam, or behind her) adds up to FAIR_BOOST on top,
## more the stronger it blows. 1.0 = sailing normally.
const FAIR_BOOST := 0.3
var _fair_on: bool = false


func wind_effect() -> float:
	var a := rad_to_deg(absf(_wind_rel()))
	var pts := [[0.0, 0.8], [60.0, 1.0], [110.0, 1.0], [140.0, 0.0], [180.0, 0.0]]
	var fair := 0.0
	for i in range(pts.size() - 1):
		if a <= float(pts[i + 1][0]):
			var t := (a - float(pts[i][0])) / (float(pts[i + 1][0]) - float(pts[i][0]))
			fair = lerpf(float(pts[i][1]), float(pts[i + 1][1]), t)
			break
	var wx := get_node_or_null("/root/Weather")
	var w: float = float(wx.get("wind")) if wx else 0.3
	return 1.0 + FAIR_BOOST * fair * lerpf(0.4, 1.0, clampf(w, 0.0, 1.0))


## The helmsman hears when a fair wind fills the sails.
func _fair_wind_note() -> void:
	if not is_player_steering or sail <= 0.0:
		_fair_on = false
		return
	var boost := wind_effect() - 1.0
	if not _fair_on and boost > FAIR_BOOST * 0.5:
		_fair_on = true
		get_tree().call_group("hud", "show_toast", "A fair wind! (+%d%% speed)" % int(roundf(boost * 100.0)))
	elif _fair_on and boost < FAIR_BOOST * 0.25:
		_fair_on = false


# --------------------------------------------------------------------------
# Anchor
# --------------------------------------------------------------------------
## An anchor at the bow on its chain: catted up under way, let go to hold the
## ship where she is. The chain runs from the capstan on the foredeck to the
## rail and down; anyone on deck can work the capstan (hold F), and the
## helmsman can let go with Space.
func _build_anchor(wood: Material) -> void:
	var iron := PSXMat.lit("metal", Color(0.22, 0.21, 0.2))
	var amb := MeshBuilder.new()
	amb.add_box(iron, Transform3D(Basis(), Vector3(0, -0.45, 0)), Vector3(0.09, 0.9, 0.09), 1.0)
	amb.add_box(wood, Transform3D(Basis(), Vector3(0, -0.05, 0)), Vector3(0.7, 0.09, 0.09), 1.0)
	amb.add_box(iron, Transform3D(Basis(Vector3.BACK, 0.9), Vector3(0.2, -0.82, 0)), Vector3(0.08, 0.42, 0.08), 1.0)
	amb.add_box(iron, Transform3D(Basis(Vector3.BACK, -0.9), Vector3(-0.2, -0.82, 0)), Vector3(0.08, 0.42, 0.08), 1.0)
	amb.add_cylinder(iron, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 0.02, -0.04)), 0.07, 0.07, 0.08, 6, 1.0)
	_anchor = amb.to_instance("Anchor")
	_anchor.position = ANCHOR_AT
	ship_model.add_child(_anchor)
	# the capstan: a drum with its bars, chain wound round it
	var cap := MeshBuilder.new()
	cap.add_cylinder(wood, Transform3D(Basis(), CAPSTAN_AT), 0.32, 0.26, 0.75, 8, 1.0)
	cap.add_cylinder(iron, Transform3D(Basis(), CAPSTAN_AT + Vector3(0, 0.3, 0)), 0.29, 0.29, 0.14, 8, 1.0)
	for k in range(4):
		var b := Basis(Vector3.UP, PI * 0.25 * k)
		cap.add_box(wood, Transform3D(b, CAPSTAN_AT + Vector3(0, 0.66, 0)), Vector3(1.3, 0.06, 0.06), 1.0)
	ship_model.add_child(cap.to_instance("Capstan"))
	# a link, two ways round (they alternate down the chain)
	var lm := MeshBuilder.new()
	lm.add_box(iron, Transform3D(Basis(), Vector3(0, 0, 0.045)), Vector3(0.03, CHAIN_STEP + 0.03, 0.025), 1.0)
	lm.add_box(iron, Transform3D(Basis(), Vector3(0, 0, -0.045)), Vector3(0.03, CHAIN_STEP + 0.03, 0.025), 1.0)
	var link := lm.commit()
	# along the deck to the rail (it doesn't move)
	var deck_chain := MeshBuilder.new()
	var from := CAPSTAN_AT + Vector3(0, 0.3, 0)
	var to := ANCHOR_AT + Vector3(-0.15, 0.1, 0.0)
	var n := int(from.distance_to(to) / CHAIN_STEP)
	var along := Basis.looking_at((to - from).normalized(), Vector3.UP) * Basis(Vector3.RIGHT, PI * 0.5)
	for i in range(n):
		var at := from.lerp(to, (i + 0.5) / n)
		var b := along * Basis(Vector3.UP, PI * 0.5 * (i % 2))
		deck_chain.add_box(iron, Transform3D(b, at), Vector3(0.1, CHAIN_STEP + 0.03, 0.03), 1.0)
	ship_model.add_child(deck_chain.to_instance("DeckChain"))
	# down to the anchor: links shown as far as it's let go
	_cable = Node3D.new()
	_cable.name = "Chain"
	_cable.position = ANCHOR_AT
	ship_model.add_child(_cable)
	for i in range(CHAIN_LINKS):
		var mi := MeshInstance3D.new()
		mi.mesh = link
		mi.position = Vector3(0, -(i + 0.5) * CHAIN_STEP, 0)
		mi.rotation.y = PI * 0.5 * (i % 2)
		_cable.add_child(mi)
	_show_anchor(0.0)


## Let go / weigh (the helmsman's Space, or the host's copy following them).
func set_anchored(on: bool) -> void:
	if anchored == on:
		return
	anchored = on
	FX.sfx("rope", global_transform * ANCHOR_AT, -2.0, 0.05, 0.7 if on else 0.9)
	if on:
		FX.splash(global_transform * (ANCHOR_AT + Vector3(0, -2.0, 0)), 8, 1.0)


func _show_anchor(delta: float) -> void:
	_anchor_drop = move_toward(_anchor_drop, 1.0 if anchored else 0.0, delta * 0.8)
	var depth := lerpf(0.0, 5.6, _anchor_drop)
	_anchor.position = ANCHOR_AT + Vector3(0, -depth, 0)
	for i in range(_cable.get_child_count()):
		(_cable.get_child(i) as Node3D).visible = (i + 1) * CHAIN_STEP <= depth + 0.05


## Near a dock (an island's DockingArea): her anchor goes down by itself when
## the helmsman leaves the wheel there.
func in_port() -> bool:
	for d in get_tree().current_scene.find_children("DockingArea", "", true, false):
		if (d as Node3D).global_position.distance_to(global_position) < PORT_REACH:
			return true
	return false


# ==========================================================================
# Co-op: the ship belongs to whoever is at the helm (the host otherwise)
# ==========================================================================
func _helm_locked() -> bool:
	var gm := get_node_or_null("/root/GameManager")
	return gm != null and gm.player != null and is_instance_valid(gm.player) and gm.player.input_locked


func net_pack() -> Array:
	return [_pos, _heading, _y, _pitch, _roll, speed, rudder, _yaw_rate, _vy, _vpitch, _vroll, sail, _turn_in, _back_in, anchored]


## We now steer. Our copy has been following the helmsman all along, so it
## carries on from itself; only the sails are taken from their last word
## (and the whole state if we never had one, e.g. just joined).
func net_take_over(state: Array) -> void:
	var st := state
	if st.size() < PACK_SIZE:
		var last := Net.latest(self)
		st = last[1] if last.size() == 2 else []
	if st.size() < PACK_SIZE:
		return
	sail = float(st[11])
	set_anchored(bool(st[14]))
	if _init:
		return
	_pos = st[0]
	_heading = float(st[1])
	_y = float(st[2])
	_pitch = float(st[3])
	_roll = float(st[4])
	speed = float(st[5])
	rudder = float(st[6])
	_yaw_rate = float(st[7])
	_vy = float(st[8])
	_vpitch = float(st[9])
	_vroll = float(st[10])
	_init = true
	_placed = true
