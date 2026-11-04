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

const MAX_SPEED := 11.0
const MAX_REVERSE := 3.0
const ACCEL := 2.6
const BRAKE := 4.0
## Turn rate (rad/s) at full rudder once there's flow over it (>= 4 m/s).
const MAX_TURN := 0.55
## Her hull's shape (every crew class shares it); the rest of her layout (the quarterdeck, the cabin and its
## fittings, the helm, mast, rigging, ladders, gun spots) is `layout`, her class's and her Quarters level's.
const FREEBOARD := HullLayout.FREEBOARD
## How much of the swell the hull follows (a 23 m hull rides over the 8 m waves).
const HEAVE_SCALE := 0.4
const BOW_Z := HullLayout.BOW_Z
const STERN_Z := HullLayout.STERN_Z
const HALF_BEAM := HullLayout.HALF_BEAM
const DECK_Y := HullLayout.DECK_Y
var layout: HullLayout
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
const PACK_SIZE := 19

var is_player_steering: bool = false
## The helm lashed to a course (LashedHelm): she holds lash_heading with nobody steering.
var lashed: bool = false
var lash_heading: float = 0.0
## Current forward speed (m/s, negative = backing) and smoothed rudder (-1..1).
var speed: float = 0.0
var rudder: float = 0.0
## The sails as set (0 furled .. 1 full) and as they are right now (the
## canvas takes a moment to come down; the speed follows what's set out).
var sail: float = 0.0
var sail_shown: float = 0.0
## Tide Will (WillPowers.all, set on every machine): Call the Wind's seconds left (WIND_K more top speed), Helm Sense's
## seconds left and the share of hull damage it turns.
const WIND_K := 1.25
var will_wind := 0.0
## (1.28) The paddle boost (ShipGadgets): its seconds left and its share of more speed.
var paddle_t := 0.0
## (1.28) A leviathan holding her (the colossal squid's arms on her rails): her top speed x this, set every frame by
## it on every machine, eased back to 1 when nothing holds her.
var held_k := 1.0
var paddle_k := 0.0
var will_guard := 0.0
var will_guard_k := 0.0
var _turn_in: float = 0.0
var _back_in: bool = false
var _sail_node: Node3D
var _sail_corners: Array = []
var _furl_node: Node3D
var _rig: Node3D
var _yard_node: Node3D
## (1.30) The other masts' rigs (the brig's foremast, the galleon's fore and mizzen): [rig, yard, sail, furled].
var _rigs: Array = []
## How much bigger the yard and mainsail are than plain (x across, y down: the sails line's levels).
## (The yard and sails are scaled, not the rig: the swing ropes on it can't take a stretched scale.)
var rig_scale := Vector2.ONE
var _brace: float = 0.0
## Riding to her anchor: she stops and stays, sails or no sails.
var anchored: bool = false
var _anchor: Node3D
var _cable: Node3D
var _anchor_drop: float = 0.0
## The anchor hangs from the cathead here (ship-model space), off the bow.
## (the sloop's: every class's are her layout's, anchor_at and capstan_at)
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
## Her class's acceleration (ShipClasses: the caravel's quicker off the mark).
var _accel_k := 1.0
## The lines' other effects (ShipLines): speed in the dark, what's left of a reef's damage, how much less a
## ram throws the crew (1 = not at all), how far the lookout puts ships and salvage on the compass (m).
var _night_k: float = 0.0
var _reef_k: float = 1.0
var steady: float = 0.0
var lookout: float = 0.0
## The helmsman's Seamanship on her sailing ([top speed x, turning x, share of flooding's slowdown]:
## Seamanship.helm_k on their machine, from their snapshot elsewhere), and whether a captain on another
## machine has the wheel (for the Bosun's crew bonus).
var _helm_k := Vector3.ONE
var helm_other: bool = false
var _sea_m: float = 0.0
var _psx_model: MeshInstance3D
var _hull_mat: Material
var _canvas_mat: Material
## (1.29) Her trim, spars and deck stain as painted (ShipKit RAILS, SPARS, DECKS: apply_kit).
var _trim_mat: Material
var _spar_mat: Material
var _deck_tint := Color.WHITE
var _flag_node: MeshInstance3D
var _flag_pivot: Node3D
var _flag_t := 0.0
var _figure_node: Node3D
## What her layout builds (_build_layout: the hull, the cabin and its fittings, the helm, the lanterns), and the
## collision shapes it adds; a new layout (a Quarters level) frees both and builds them again.
var _layout_root: Node3D
var _layout_shapes: Array = []
var _cabin_mesh: MeshInstance3D
var _cabin_fine: MeshInstance3D
var _cabin_light: OmniLight3D
var _cabin_t := 0.0
var _hold_mesh: MeshInstance3D
var _hold_light: OmniLight3D
var _helm_post: MeshInstance3D
## What the upgrade lines have put on her (ShipParts, built from the kit).
var parts: ShipParts
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
var _cam_heading: float = 0.0
var _cam_y: float = 0.0

@onready var ship_model: Node3D = $ShipModel
@onready var helm_position: Marker3D = $ShipModel/HelmPosition
@onready var disembark_position: Marker3D = $ShipModel/DisembarkPosition
@onready var respawn_point: Marker3D = $RespawnPoint
@onready var helm_zone: Interactable = $HelmZone
## The storage chest in the cabin (a LootBag that never empties away), and its Personal tab (this captain's own).
var storage: LootBag
var personal: LootBag
## (1.29) The galley pantry (a hidden shared bag: GameManager.pantry; the galley screen shows it).
var pantry: LootBag
@onready var ship_camera: Node3D = $ShipCamera


func _ready() -> void:
	add_to_group("decks")
	layout = HullLayout.for_kit(ShipKit.merged(get_node("/root/GameManager").ship_kit))
	_build_psx_model()
	_build_layout()
	_build_cannons()
	var spray := ShipSpray.new()
	spray.name = "ShipSpray"
	add_child(spray)
	_ocean = get_node_or_null("/root/Ocean")
	_game_manager = get_node("/root/GameManager")
	apply_kit(_game_manager.ship_kit)
	helm_zone.interacted.connect(_on_helm_interacted)
	helm_zone.reach = 1.0
	var arm := ship_camera.get_node("SpringArm3D") as SpringArm3D
	arm.add_excluded_object(get_rid())
	arm.spring_length = layout.cam_arm
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
	if lashed:
		LashedHelm.apply(self, false, yaw)
	_placed = true
	_init = false
	speed = 0.0
	_yaw_rate = 0.0
	sail = 0.0
	sail_shown = 0.0
	_deck_delta = Transform3D.IDENTITY
	# (placed before it's in the world too: then its own position is the global one)
	var y := global_position.y if is_inside_tree() else position.y
	global_transform = Transform3D(Basis(Vector3.UP, yaw), Vector3(world_pos.x, y, world_pos.z))
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
			_helm_k = Vector3(float(s[15]), float(s[16]), float(s[17]))
			helm_other = bool(s[18])
		else:
			snap = []
	else:
		_read_helm()
		_helm_k = Seamanship.helm_k(get_tree(), self) if is_player_steering else Vector3.ONE
		helm_other = false
	sail_shown = move_toward(sail_shown, sail, SAIL_RATE * delta)
	var heading := _heading
	var pos := _pos
	var fwd := Vector3(-sin(heading), 0.0, -cos(heading))
	var right := Vector3(cos(heading), 0.0, -sin(heading))

	# (water in her: low and sluggish; a fair wind: a little faster)
	var top := MAX_SPEED * _top_k * _helm_k.x * (1.0 + _night_k * Weather.night) * (CRIPPLED_SPEED if crippled else 1.0) * (1.0 - 0.55 * flood * _helm_k.z) * wind_effect() * sail_k() * will_k()
	will_wind = maxf(will_wind - delta, 0.0)
	will_guard = maxf(will_guard - delta, 0.0)
	if not lines.is_empty():
		top = minf(top, LASHED_SPEED)
	top *= held_k
	held_k = move_toward(held_k, 1.0, delta * 0.5)
	var want := top * sail_shown
	# (1.28) a ship gadget's paddle boost (ShipGadgets, on every machine)
	if paddle_t > 0.0:
		want = ShipGadgets.paddle(self, want, delta)
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
		speed = move_toward(speed, want, ACCEL * _accel_k * delta)
	else:
		speed = move_toward(speed, want, (0.35 + 0.012 * speed * speed) * delta)
	rudder = move_toward(rudder, _turn_in, 2.2 * _turn_k * delta)
	var flow := clampf(absf(speed) / 4.0, 0.3, 1.0) * (0.0 if anchored else 1.0)
	var target_rate := -rudder * MAX_TURN * _turn_k * _helm_k.y * flow * (-1.0 if speed < -0.3 else 1.0)
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
					Net.fx("sfx", ["thud", global_position + fwd * (layout.bow_z * -1.0), 2.0, 0.05, 0.6])
				var was := absf(speed)
				speed *= lerpf(1.0, -0.15, head_on)
				_yaw_rate *= 0.5
				_brought_up(col.get_collider(), was)
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
	var t: float = Ocean.clock()
	var L := layout
	var hb := _wave(pos + fwd * -L.bow_z, t)
	var hs := _wave(pos + fwd * -L.stern_z, t)
	var hp := _wave(pos - right * L.half_beam, t)
	var hr := _wave(pos + right * L.half_beam, t)
	var hc := _wave(pos, t)
	var mean := (hb + hs + hp + hr + hc * 2.0) / 6.0
	# (bow/stern/sides average most of the swell away; the midship sample
	# keeps a slow, shallow rise and fall; a bigger hull rides it steadier)
	var target_y := lerpf(mean, hc, 0.5) * HEAVE_SCALE / sqrt(L.kz) + L.freeboard - 0.6 * flood
	var accel_f := (speed - _prev_speed) / maxf(delta, 0.0001)
	_prev_speed = speed
	var target_pitch := clampf(atan((hb - hs) / (L.stern_z - L.bow_z)) * 0.35, -0.045, 0.045) + clampf(accel_f * 0.008, -0.03, 0.03) + clampf(speed * 0.003, -0.01, 0.04)
	var target_roll := clampf(atan((hr - hp) / (L.half_beam * 2.0)) * 0.3, -0.05, 0.05) + clampf(_yaw_rate * speed * 0.01, -0.06, 0.06) - 0.12 * flood * _list_side()
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
	parts.steer(rudder)
	_wake(pos, fwd)
	# the helmsman's Seamanship grows with the sea under her
	if is_player_steering:
		_sea_m += absf(speed) * delta
		if _sea_m >= Seamanship.SAIL_M:
			_sea_m -= Seamanship.SAIL_M
			Seamanship.xp(get_tree(), 1)
	if speed > top:
		speed = move_toward(speed, top, 2.0 * delta)
	if not Net.is_client():
		_damage_tick(delta)


## The helmsman's hands (their machine, or the host's when nobody steers:
## the sails stay as they were, the rudder eases back to centre).
func _read_helm() -> void:
	_turn_in = 0.0
	_back_in = false
	if lashed and not is_player_steering:
		_turn_in = LashedHelm.turn(self)
		LashedHelm.watch(self)
		return
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
## (1.26) Run into another ship or a blockade's boom and brought nearly to a stop (from STOP_FROM m/s to under
## STOP_UNDER): she furls her sails, so a captain thrown off or fighting on the other deck isn't left watching her sail
## away. Raise them again at the helm. (On whoever sails her; `sail` goes out with her state.)
const STOP_FROM := 2.5
const STOP_UNDER := 1.2


func _brought_up(by: Object, was: float) -> void:
	if sail <= 0.0 or was < STOP_FROM or absf(speed) >= STOP_UNDER:
		return
	if not (by is EnemyShip or by is AdmiraltyBoom or (by is Node and (by as Node).is_in_group("enemy_ships"))):
		return
	sail = 0.0
	sail_shown = 0.0
	Net.fx("sfx", ["flap", global_position + Vector3(0, 6.0, 0), 0.0, 0.05, 0.8])


func jolt(push: Vector3) -> void:
	var l := global_basis.inverse() * push
	_vroll += clampf(-l.x * 0.06, -0.5, 0.5)
	_vpitch += clampf(l.z * 0.04, -0.3, 0.3)
	_vy += 0.6


## Inside the ship's bounds: on deck, in the rigging, on a ladder, jumping
## about over the deck (co-op positions are sent relative to the hull then).
func aboard(p: Vector3) -> bool:
	return layout.aboard_local(global_transform.affine_inverse() * p)


## The hull's own velocity (cannonballs fired from it carry it along).
func hull_velocity() -> Vector3:
	return Vector3(-sin(_heading), 0.0, -cos(_heading)) * speed


# ==========================================================================
# Cannons and the hull
# ==========================================================================
## [z, x, deck height] of each pair of swivel guns: the foredeck, forward of
## the mast (clear of the rigging), and (the shipwright's refit) up on the
## quarterdeck.
## A crew gun's ball (hull, splash) and reload before the gun deck's levels.
const GUN_HULL := 30.0
const GUN_SPLASH := 22.0
const GUN_RELOAD := 3.2


func _build_cannons() -> void:
	for i in range(layout.base_guns):
		_add_gun_pair(i)


## The Gun deck line's pair on the quarterdeck: the one after her class's own (the sloop's third).
func _aft_pair() -> int:
	return layout.base_guns


func _add_gun_pair(i: int) -> void:
	for sgn in [-1.0, 1.0]:
		var c := ShipCannon.new()
		c.name = "Cannon%s%d" % ["S" if sgn > 0.0 else "P", i]
		c.ship = self
		c.team = "crew"
		c.position = Vector3(sgn * float(layout.gun_spots[i][1]), float(layout.gun_spots[i][2]), float(layout.gun_spots[i][0]))
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
	if will_guard > 0.0:
		dmg *= 1.0 - will_guard_k
	hull = maxf(hull - dmg, 0.0)
	_since_hit = 0.0
	FX.dust(at, 10, 0.8)
	Net.fx("float_text", [at + Vector3(0, 1.4, 0), "-%d hull" % int(round(dmg)), Color(1.0, 0.62, 0.25), 30])
	if hull <= 0.0 and not crippled:
		_set_crippled(true)
	_send_hull(true)
	if dmg >= BREACH_MIN_DMG:
		var l := global_transform.affine_inverse() * at
		var z := clampf(l.z, layout.deck_z_min, layout.deck_z_max)
		if breaches.size() < MAX_BREACHES and _dmg_rng.randf() < BREACH_CHANCE:
			add_breach(-1.0 if l.x < 0.0 else 1.0, z)
		if fires.size() < MAX_FIRES and _dmg_rng.randf() < FIRE_CHANCE:
			add_fire(Vector3(clampf(l.x, -layout.deck_x_max, layout.deck_x_max), DECK_Y, z))


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
			var spot := global_transform * Vector3(randf_range(-layout.deck_x_max, layout.deck_x_max), DECK_Y + 0.2, randf_range(layout.deck_z_min, layout.deck_z_max))
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
## Where holes and fires can be on the sloop's main deck (ship-local; every class's: layout.deck_z_min...).
const DECK_Z_MIN := -7.8
const DECK_Z_MAX := 4.4
const DECK_X_MAX := 2.6
## The waterline on the sloop's side (ship-local y), where holes show (layout.waterline_y).
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
	breaches.append([_dmg_id, Vector3(side * (layout.half_width(z) - 0.55), DECK_Y, z)])
	FX.sfx("wood_crack", global_transform * Vector3(side * layout.half_width(z), layout.waterline_y, z), 4.0, 0.05, 0.75)
	_send_damage()


## Host: a fire on deck at `at` (ship-local).
func add_fire(at: Vector3) -> void:
	_dmg_id += 1
	fires.append([_dmg_id, at, 0.0])
	_send_damage()


func _send_damage() -> void:
	_flood_sent = flood
	_rebuild_holes()
	_rebuild_tears()
	Net.ship_damage([breaches, fires, flood, torn, lines])


## Not the host: what the host says is holed, burning, flooded, torn and lashed.
func net_damage(data: Array) -> void:
	breaches = data[0]
	fires = data[1]
	flood = float(data[2])
	torn = data[3]
	lines = data[4]
	_rebuild_holes()
	_rebuild_tears()


## Host: a captain did a job (on any screen).
func do_work(kind: String, id: int, amount: float) -> void:
	match kind:
		"patch":
			breaches = breaches.filter(func(b): return int(b[0]) != id)
		"douse":
			fires = fires.filter(func(f): return int(f[0]) != id)
		"mend":
			torn = torn.filter(func(t): return int(t[0]) != id)
		"cut":
			var was := lines.size()
			lines = lines.filter(func(l): return int(l[0]) != id)
			if lines.size() < was:
				Net.fx("sfx", ["rope", global_position, 0.0, 0.05, 1.4])
		"bail":
			flood = maxf(flood - amount, 0.0)
			if absf(flood - _flood_sent) < 0.02 and flood > 0.0:
				return
	_send_damage()


## Host, every tick: water coming in, fires burning and spreading, a reef
## under her keel, a whirlpool's eye grinding her, grapple lines holding.
func _damage_tick(delta: float) -> void:
	if not lines.is_empty():
		_lines_tick(delta)
	var sf := get_tree().get_first_node_in_group("sea_features")
	if sf:
		var on_reef: bool = sf.reef_at(global_position) and absf(speed) > 1.5
		var in_eye: bool = sf.in_eye(global_position)
		if on_reef or in_eye:
			hull = maxf(hull - (absf(speed) * 1.4 if on_reef else 6.0) * _reef_k * delta, 1.0)
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
					add_breach(-1.0 if _dmg_rng.randf() < 0.5 else 1.0, _dmg_rng.randf_range(layout.deck_z_min, layout.deck_z_max))
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
			spread.append(Vector3(clampf(p.x, -layout.deck_x_max, layout.deck_x_max), DECK_Y, clampf(p.z, layout.deck_z_min, layout.deck_z_max)))
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
		mi.position = Vector3(side * (_side_at(spot.z, layout.waterline_y) + 0.03), layout.waterline_y, spot.z)
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
			var at := global_transform * Vector3(side * (_side_at(spot.z, layout.waterline_y) + 0.2), layout.waterline_y + 0.1, spot.z)
			FX.splash(at, 3, 0.5)
	if not _ropes.is_empty():
		_show_ropes()
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
	for t in torn:
		var spot: Vector3 = layout.mend_at[int(t[1])]
		var d := Vector2(local.x - spot.x, local.z - spot.z).length()
		if d < best:
			best = d; job = "mend"; id = int(t[0])
	for l in lines:
		var d := Vector2(local.x - l[1].x, local.z - l[1].z).length()
		if d < best:
			best = d; job = "cut"; id = int(l[0])
	if flood > 0.0 and Vector2(local.x - layout.pump_at.x, local.z - layout.pump_at.z).length() < best:
		job = "bail"; id = 0
	elif job == "" and Vector2(local.x - layout.capstan_at.x, local.z - layout.capstan_at.z).length() < WORK_REACH:
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
					Net.ship_work("bail", 0, BAIL_RATE * _bail_t * (1.0 + Seamanship.station(get_tree(), "pump", self)))
					_bail_t = 0.0
					Seamanship.xp(get_tree(), Seamanship.BAIL)
			_set_work("Hold %s: work the pump" % Glyphs.of("interact"), flood)
		"anchor":
			var need := job_time("anchor")
			_work_t = _work_t + delta if holding else 0.0
			me.body_model.kneeling = holding
			if _work_t >= need:
				_work_t = 0.0
				me.body_model.kneeling = false
				Net.ship_anchor(not anchored)
				FX.sfx("rope", global_transform * layout.capstan_at, -2.0, 0.05, 0.75)
				Seamanship.xp(get_tree(), Seamanship.CAPSTAN)
			_set_work(("Hold %s: weigh anchor" if anchored else "Hold %s: let go the anchor") % Glyphs.of("interact"), _work_t / need)
		_:
			var need := job_time(job)
			_work_t = _work_t + delta if holding else 0.0
			me.body_model.kneeling = holding
			if _work_t >= need:
				_work_t = 0.0
				me.body_model.kneeling = false
				Net.ship_work(job, id, 0.0)
				Seamanship.xp(get_tree(), Seamanship.PATCH)
				FX.sfx({"patch": "wood_crack", "douse": "splash", "mend": "whoosh", "cut": "parry"}[job], me.global_position, -6.0, 0.05, 1.3)
			var verbs := {"patch": "patch the hole", "douse": "beat out the fire", "mend": "mend the torn sail", "cut": "cut the grapple line"}
			_set_work("Hold %s: %s" % [Glyphs.of("interact"), verbs[job]], _work_t / need)


## How long our captain takes over a deck job ("patch", "douse", "mend", "cut", "anchor"), with their Seamanship.
func job_time(job: String) -> float:
	if job == "anchor":
		return ANCHOR_TIME / (1.0 + Seamanship.station(get_tree(), "capstan", self))
	var base: float = {"patch": PATCH_TIME, "douse": DOUSE_TIME, "mend": MEND_TIME, "cut": CUT_TIME}[job]
	return base / (1.0 + Seamanship.station(get_tree(), "repair", self))


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


# --------------------------------------------------------------------------
# Torn sails and grapple lines (docs/v1_23_plan.md, sea pursuit)
# --------------------------------------------------------------------------
## Chain shot through the canvas: each tear takes TORN_SLOW off her top speed until it's mended at the foot of the
## mast (hold F). Grapples from a ship alongside lash her to it: LASHED_SPEED at most until every line is cut at the
## rail. The host keeps both (net_damage); every screen draws them and its own captain does the work.
const MAX_TORN := 3
const TORN_SLOW := 0.18
const MEND_TIME := 3.0
const MEND_AT := [Vector3(-1.2, DECK_Y, -2.9), Vector3(1.2, DECK_Y, -2.9), Vector3(-1.1, DECK_Y, -0.7)]
const LASHED_SPEED := 2.2
const CUT_TIME := 1.1
## A line parts when the ships it holds drift this far apart.
const LINE_SNAP := 26.0
## [id, mend slot (layout.mend_at), the tear on the sail (sail-local)]
var torn: Array = []
## [id, rail spot (ship-local), the ship holding it (Net key), its end on her (her local)]
var lines: Array = []
var _tears: Dictionary = {}
var _ropes: Dictionary = {}
var _snap_t: float = 0.0
static var _rope_mesh: Mesh


func sail_k() -> float:
	return 1.0 - TORN_SLOW * torn.size()


## Call the Wind's lift on her top speed (1 without it).
func will_k() -> float:
	return WIND_K if will_wind > 0.0 else 1.0


## Host: chain shot tore through the canvas at `local` (ship-local).
func tear_sail(local: Vector3) -> void:
	if torn.size() >= MAX_TORN:
		return
	var used := torn.map(func(t): return int(t[1]))
	var slot := 0
	while slot in used:
		slot += 1
	_dmg_id += 1
	var rs := layout.sail_k
	var py := clampf((local.y - (layout.yard_y - 0.15)) / rs.y, -7.6, -0.9)
	# (on the sheet, which bellies aft to 0.45 at its middle reef band and back to 0.1 at the foot: _build_rig)
	var pz := lerpf(0.0, 0.45, -py / 4.35) if py > -4.35 else lerpf(0.45, 0.1, (-py - 4.35) / 4.2)
	var patch := Vector3(clampf(local.x / rs.x, -3.4, 3.4), py, pz)
	torn.append([_dmg_id, slot, patch])
	Net.fx("sfx", ["whoosh_big", global_transform * local, 2.0, 0.05, 0.7])
	Net.fx("dust", [global_transform * local, 14, 1.2])
	_send_damage()


## Host: grapples from `by` (on our `side`: 1 starboard) bite into the rail.
func lash(by: Node3D, side: float) -> void:
	for z0 in [-5.0, -1.0, 3.0]:
		var z: float = z0 * layout.kz
		_dmg_id += 1
		lines.append([_dmg_id, Vector3(side * (layout.half_width(z) - 0.5), DECK_Y, z), Net.key_of(by), Vector3(-side * 3.7, 2.6, z)])
	_send_damage()


## Host: `by` lets go of her (nobody left aboard to hold).
func unlash(by: Node) -> void:
	var k := Net.key_of(by)
	if lines.any(func(l): return l[2] == k):
		lines = lines.filter(func(l): return l[2] != k)
		_send_damage()


## How many of the lines on her `by` holds.
func lines_of(by: Node) -> int:
	var k := Net.key_of(by)
	return lines.filter(func(l): return l[2] == k).size()


## Host: a line whose ship is gone or going down lets go; one strained past LINE_SNAP for a second parts.
func _lines_tick(delta: float) -> void:
	var keep: Array = []
	var far := false
	for l in lines:
		var by := Net.node_of(str(l[2])) as Node3D
		if by == null or by.call("is_dead"):
			continue
		if by.global_position.distance_to(global_position) > LINE_SNAP:
			far = true
			if _snap_t > 1.0:
				continue
		keep.append(l)
	_snap_t = _snap_t + delta if far else 0.0
	if keep.size() != lines.size():
		lines = keep
		_send_damage()


## Every screen: the tears on the sail, the lines' ropes, and the word when she's lashed or free.
func _rebuild_tears() -> void:
	var keep := {}
	for t in torn:
		var id := int(t[0])
		keep[id] = true
		if not _tears.has(id):
			_tears[id] = _tear_mesh(t[2], id)
	for id in _tears.keys():
		if not keep.has(id):
			(_tears[id] as Node).queue_free()
			_tears.erase(id)
	var was := not _ropes.is_empty()
	keep = {}
	for l in lines:
		var id := int(l[0])
		keep[id] = true
		if not _ropes.has(id):
			_ropes[id] = _rope_node(l[1])
	for id in _ropes.keys():
		if not keep.has(id):
			(_ropes[id] as Node).queue_free()
			_ropes.erase(id)
	if was and _ropes.is_empty():
		_toast("Cut free!")
	elif not was and not _ropes.is_empty():
		get_tree().call_group("hud", "show_banner", "Grappled!", "Cut the lines at the rail (hold %s) to break free" % Glyphs.of("interact"), false)


## A ragged hole through the canvas (both faces; it hangs on the sail, so it furls and braces with it).
func _tear_mesh(at: Vector3, id: int) -> Node3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = id
	var mb := MeshBuilder.new()
	var mat := PSXMat.lit("planks_dark", Color(0.06, 0.05, 0.05))
	var pts: Array = []
	for k in range(7):
		var a := TAU * k / 7.0
		var r := rng.randf_range(0.35, 0.8)
		pts.append(Vector3(cos(a) * r * 1.3, sin(a) * r, 0.0))
	# (a face just aft of the sheet and one just forward of it, so it shows from either side)
	var aft := Vector3(0, 0, 0.06)
	for k in range(7):
		var a: Vector3 = pts[k]
		var b: Vector3 = pts[(k + 1) % 7]
		for o in [aft, -aft]:
			mb.add_tri(mat, o, a + o, b + o, Vector3.BACK, Vector3.BACK, Vector3.BACK, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Color.WHITE, Vector3.BACK)
			mb.add_tri(mat, o, b + o, a + o, Vector3.FORWARD, Vector3.FORWARD, Vector3.FORWARD, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Color.WHITE, Vector3.FORWARD)
	var mi := mb.to_instance("Tear%d" % id)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = at
	_sail_node.add_child(mi)
	return mi


## A hook on the rail and its rope (drawn in world space each frame, to the ship holding it).
func _rope_node(rail: Vector3) -> Node3D:
	if _rope_mesh == null:
		var mb := MeshBuilder.new()
		mb.add_cylinder(PSXMat.lit("planks", Color(0.85, 0.72, 0.5)), Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3.ZERO), 0.08, 0.08, 1.0, 4, 1.0)
		_rope_mesh = mb.commit()
	var hook := MeshBuilder.new()
	var iron := PSXMat.lit("metal", Color(0.25, 0.24, 0.23))
	# (a three-pronged grapnel hooked over the rail, shank up)
	hook.add_box(iron, Transform3D(Basis(), Vector3(0, 0.3, 0)), Vector3(0.1, 0.6, 0.1), 1.0)
	for a in [0.0, TAU / 3.0, TAU * 2.0 / 3.0]:
		var d := Vector3(cos(a), 0.0, sin(a))
		hook.add_box(iron, Transform3D(Basis.looking_at(d + Vector3.DOWN * 0.6, Vector3.UP), d * 0.14), Vector3(0.07, 0.07, 0.36), 1.0)
	var n := hook.to_instance("Grapple")
	n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.position = rail + Vector3(signf(rail.x) * 0.45, 0.75, 0.0)
	ship_model.add_child(n)
	var rope := MeshInstance3D.new()
	rope.name = "Rope"
	rope.mesh = _rope_mesh
	rope.top_level = true
	rope.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	rope.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	n.add_child(rope)
	return n


func _show_ropes() -> void:
	for l in lines:
		var n = _ropes.get(int(l[0]))
		if n == null:
			continue
		var rope := (n as Node3D).get_node("Rope") as MeshInstance3D
		var by := Net.node_of(str(l[2])) as Node3D
		rope.visible = by != null
		if by == null:
			continue
		var a := (n as Node3D).global_position + Vector3(0, 0.45, 0)
		var b := by.get_global_transform_interpolated() * (l[3] as Vector3)
		var d := b - a
		if d.length() < 0.1:
			continue
		rope.global_transform = Transform3D(Basis.looking_at(d, Vector3.UP) * Basis.from_scale(Vector3(1, 1, d.length())), a)


## The foam wake (every machine lays its own from the ship's speed; her spray is ShipSpray's).
func _wake(pos: Vector3, fwd: Vector3) -> void:
	if absf(speed) > 1.0:
		Ocean.wake(self, pos - fwd * layout.stern_z, clampf(absf(speed) / 9.0, 0.0, 1.0))


func _wave(p: Vector3, t: float) -> float:
	if _ocean and _ocean.has_method("get_wave_height"):
		return float(_ocean.call("get_wave_height", p, t))
	return 0.0


## Ship camera (used at the helm): follows the hull's position and heading
## but not its pitch/roll/heave jitter, so steering stays steady.
func _process(delta: float) -> void:
	# (shared through the host while there's a crew, local alone)
	storage.shared_id = "storage" if Net.active else ""
	pantry.shared_id = "pantry" if Net.active else ""
	_summon_view(delta)
	_hull_tick(delta)
	_show_sail(delta)
	_show_anchor(delta)
	_damage_view(delta)
	_rain_on_deck(delta)
	_show_flag(delta)
	_show_cabin(delta)
	var xf := get_global_transform_interpolated()
	var heading := xf.basis.get_euler().y
	_cam_heading = lerp_angle(_cam_heading, heading, minf(4.0 * delta, 1.0))
	_cam_y = lerpf(_cam_y, xf.origin.y, minf(1.5 * delta, 1.0))
	ship_camera.global_position = Vector3(xf.origin.x, _cam_y + 4.5, xf.origin.z)
	ship_camera.global_rotation = Vector3(0.0, _cam_heading + cam_yaw, 0.0)


# ==========================================================================
# Deck collision: what you walk on matches what you see
# ==========================================================================
## (Every shape it adds goes in _layout_shapes: a new layout takes them all away and builds them again.)
func _build_collision() -> void:
	var before := get_child_count()
	# the hull, decks, cabin, stairs, mast and crow's nest
	HullBuilder.collide(self, true, layout)
	# the helm's pedestal, the capstan, and the cabin's furniture
	_box_at(Vector3(0, layout.qd_y + 0.45, layout.wheel_z - 0.16), Vector3(0.36, 0.9, 0.36))
	var capstan := CylinderShape3D.new()
	capstan.radius = 0.32
	capstan.height = 0.75
	_shape(capstan, Transform3D(Basis.IDENTITY, layout.capstan_at + Vector3(0, 0.37, 0)))
	for s in ShipCabin.solids(layout, layout.tier) + ShipRooms.hold_solids(layout):
		_box_at(s[0], s[1])
	_box_at(_bench_at() + Vector3(0, Workbench.TOP * 0.5, 0), Vector3(Workbench.W, Workbench.TOP, Workbench.D))
	_box_at(_shelf_at() + Vector3(0, BookModels.SHELF_H * 0.5, BookModels.SHELF_D * 0.5), Vector3(BookModels.SHELF_W, BookModels.SHELF_H, BookModels.SHELF_D))
	_layout_shapes = get_children().slice(before)


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
	# out to sea from it, or a little nearer or to either side (a moored hull there would leave her no run in)
	for d in [30.0, 22.0, 15.0]:
		for turn in [0.0, 0.5, -0.5]:
			var from: Vector3 = best + out.rotated(Vector3.UP, turn) * d
			if _fits(from):
				return [from, best]
	return [best, best]


## Deep water under her and round her (no land, docks or rocks). (Probed
## from high up: from sea level the ray would start inside a hillside.)
func _fits(c: Vector3) -> bool:
	for k in range(9):
		var p := c if k == 8 else c + Vector3(cos(TAU * k / 8.0), 0.0, sin(TAU * k / 8.0)) * 12.0 * layout.kz
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
## Yours to sail (the story hands her over at Tackett's; until then she's moored).
func owned() -> bool:
	return bool(kit.get("owned", true))


func _on_helm_interacted(player: Player) -> void:
	if not owned():
		player.call("_toast", "She isn't yours to sail. Tackett's still working on her.")
		return
	if player.is_free():
		# co-op: one captain at the wheel (clients ask the host first; the
		# answer puts them at the helm - Player.take_helm)
		if Net.active and not Net.request_helm():
			return
		player.current_ship = self
		var sm := player.state_machine
		if sm.current_state:
			sm.current_state.transitioned.emit(sm.current_state, "Helm", {})


## Low-poly PSX sloop: what her layout doesn't move (the rig, the climbing, the anchor, the pump, the flag, the
## figurehead, the storage chests, the puddles); the hull, cabin and helm are _build_layout's.
func _build_psx_model() -> void:
	var hull := PSXMat.lit("planks_dark", Color.WHITE, {"affine": 0.6})
	var deck := PSXMat.lit("planks", Color.WHITE, {"affine": 0.6})
	var trim := PSXMat.lit("planks", Color(0.85, 0.65, 0.35))
	var canvas := PSXMat.lit("canvas", Color(0.95, 0.92, 0.82), {"affine": 0.6})
	var wood := PSXMat.lit("bark")
	_hull_mat = hull
	_canvas_mat = canvas
	_deck_mat = deck
	parts = ShipParts.new()
	parts.setup(self)
	ship_model.add_child(parts)
	_build_rig(canvas, wood)
	_build_climbing()
	_build_anchor(wood)
	_build_pump(wood, trim)
	_dmg_rng.randomize()
	_build_flag()
	_figure_node = Node3D.new()
	_figure_node.name = "Figurehead"
	ship_model.add_child(_figure_node)
	_place_figure()
	_build_storage()
	_build_puddles()


## The bilge pump by the mast.
func _build_pump(wood: Material, trim: Material) -> void:
	var pmb := MeshBuilder.new()
	pmb.add_box(wood, Transform3D(Basis(), layout.pump_at + Vector3(0, 0.35, 0)), Vector3(0.3, 0.7, 0.3), 1.0)
	pmb.add_box(trim, Transform3D(Basis(), layout.pump_at + Vector3(0, 0.75, 0)), Vector3(0.12, 0.12, 0.7), 1.0)
	pmb.add_box(trim, Transform3D(Basis(), layout.pump_at + Vector3(0.18, 0.55, 0)), Vector3(0.08, 0.08, 0.22), 1.0)
	ship_model.add_child(pmb.to_instance("Pump"))


## (1.30) How much further off a quay or pier the crew's ship lies than the sloop does (the brig and galleon are wider):
## every island's mooring() adds it on her open side.
static func moor_out(tree: SceneTree) -> float:
	var s := tree.get_first_node_in_group("ship") as Ship
	return s.layout.half_beam - HALF_BEAM if s else 0.0


func _place_figure() -> void:
	_figure_node.position = layout.figure_at
	_figure_node.scale = Vector3.ONE * layout.figure_k


## (1.30) A different hull (her class changed at a shipyard, on every screen): what the old one carried goes and is
## built again on the new one (the rig and its masts, the climbing, the anchor and capstan, the pump, the puddles, the
## guns), then her layout's own (_relayout). The upgrade lines' pieces come back with the next ShipParts.apply.
func _refit_class(want: HullLayout) -> void:
	parts.strip()
	for n in ["Rig", "RiggingS", "RiggingP", "Anchor", "Chain", "Capstan", "DeckChain", "Pump", "Puddles"]:
		ship_model.get_node(n).free()
	for r in _rigs:
		(r[0] as Node).free()
	_rigs.clear()
	_tears.clear()
	for c in cannons:
		(c as Node).free()
	cannons.clear()
	layout = want
	var wood := PSXMat.lit("bark")
	_build_rig(_canvas_mat, wood)
	_build_climbing()
	_build_anchor(wood)
	_build_pump(wood, PSXMat.lit("planks", Color(0.85, 0.65, 0.35)))
	_build_puddles()
	_place_figure()
	_relayout()
	_build_cannons()
	_rebuild_tears()
	(ship_camera.get_node("SpringArm3D") as SpringArm3D).spring_length = layout.cam_arm
	(get_node("ShipSpray") as ShipSpray).fit(layout)


## Everything her layout places (Ship.layout: her class's and her Quarters level's), under _layout_root: the hull,
## decks and quarterdeck, the cabin furnished (ShipCabin), the helm (ShipWheel), the lanterns, the cabin's fittings
## and seats; the hull ladders and the galley table (by name on ShipModel); the collision; the markers.
func _build_layout() -> void:
	_layout_root = Node3D.new()
	_layout_root.name = "Layout"
	ship_model.add_child(_layout_root)
	var mb := MeshBuilder.new()
	_trim_mat = PSXMat.lit("planks", Color(0.85, 0.65, 0.35))
	_spar_mat = PSXMat.lit("bark")
	var glass := PSXMat.glow(Color(1.0, 0.8, 0.4), 2.5)
	# hull, decks, quarterdeck over the cabin, stairs, mast, crow's nest, rigging
	HullBuilder.hull(mb, {"hull": _hull_mat, "deck": _deck_mat, "trim": _trim_mat, "wood": _spar_mat, "rope": PSXMat.lit("rope")}, true, layout)
	# windows either side of the cabin door, the stern lantern
	for sx in [-2.0, 2.0]:
		mb.add_box(glass, Transform3D(Basis(), Vector3(sx * layout.kx, DECK_Y + 1.5, layout.qd_front - 0.02)), Vector3(0.4, 0.4, 0.06), 1.0)
	var top := layout.poop_y if layout.has_poop() else layout.qd_y
	mb.add_box(glass, Transform3D(Basis(), Vector3(0, top + 1.3, layout.qd_back + 0.15)), Vector3(0.3, 0.4, 0.3), 1.0, Color.WHITE, false)
	_psx_model = mb.to_instance("PSXModel")
	_layout_root.add_child(_psx_model)
	_wet_overrides()
	_build_helm()
	_build_cabin()
	ShipLights.crew(_layout_root, layout)
	# rope ladders down both sides, lying on the hull to the waterline: climb back aboard from the water
	var r := layout.ring_at(layout.ladder_z)
	for sgn in [-1.0, 1.0]:
		var lad := Ladder.new()
		lad.name = "LadderStarboard" if sgn > 0.0 else "LadderPort"
		lad.length = layout.ladder_len
		lad.rail = 0.8
		lad.deck_depth = 0.9
		lad.lean = (float(r[1]) - float(r[2])) / (float(r[3]) - float(r[4]))
		lad.position = Vector3(sgn * (layout.half_width(layout.ladder_z) + 0.02), DECK_Y, layout.ladder_z)
		lad.rotation.y = sgn * PI * 0.5
		ship_model.add_child(lad)
	_build_collision()
	helm_position.position = Vector3(0, layout.qd_y + 0.01, layout.helm_z)
	helm_zone.position = Vector3(0, layout.qd_y + 0.18, layout.helm_z)
	respawn_point.position = layout.bed_at + Vector3(1.15, 0.23, -0.05)
	disembark_position.position = layout.map(Vector3(0, 0.5, -6.0))


## A new layout (her Quarters level changed at the yard, every screen): what it built goes and is built again, and
## the guns on the quarterdeck move with it.
func _relayout() -> void:
	for cs in _layout_shapes:
		cs.free()
	_layout_shapes.clear()
	_layout_root.free()
	for n in ["LadderStarboard", "LadderPort", "GalleyTable"]:
		ship_model.get_node(n).free()
	_build_layout()
	var ai := _aft_pair()
	for c in cannons:
		var cn := c as Node3D
		if cn.name in ["CannonS%d" % ai, "CannonP%d" % ai]:
			cn.position.y = float(layout.gun_spots[ai][2])
	var old := ship_model.get_node_or_null("Mizzen")
	if old:
		old.free()
	if ship_model.get_node_or_null("HelmLashing"):
		ship_model.get_node("HelmLashing").free()
		if lashed:
			LashedHelm.apply(self, lashed, lash_heading)
	parts.levels = {}


## The helm: the pedestal (with the deck) and the wheel on its own node (it turns), both from ShipWheel at the
## Rudder & helm line's level (fit_helm: ShipParts).
func _build_helm() -> void:
	_helm_post = MeshInstance3D.new()
	_helm_post.name = "HelmPost"
	_helm_post.visibility_range_end = 120.0
	_layout_root.add_child(_helm_post)
	wheel = Node3D.new()
	wheel.name = "Wheel"
	wheel.position = Vector3(0, layout.qd_y + ShipWheel.HUB_Y, layout.wheel_z)
	_layout_root.add_child(wheel)
	var wm := MeshInstance3D.new()
	wm.name = "WheelMesh"
	wm.visibility_range_end = 120.0
	wm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	wheel.add_child(wm)
	fit_helm(ShipLines.level(kit, "rudder"))


## The wheel and its pedestal as the Rudder & helm line's level `n` shows them.
func fit_helm(n: int) -> void:
	var m := ShipWheel.mats()
	var pmb := MeshBuilder.new()
	ShipWheel.pedestal(pmb, m, Vector3(0, layout.qd_y, layout.wheel_z), n)
	pmb.fold_tints()
	_helm_post.mesh = pmb.commit()
	var wmb := MeshBuilder.new()
	ShipWheel.wheel(wmb, m, n)
	wmb.fold_tints()
	(wheel.get_node("WheelMesh") as MeshInstance3D).mesh = wmb.commit()


## The crew cabin under the quarterdeck, furnished for her Quarters level (ShipCabin; hidden while no camera is near
## it: _show_cabin), its lamp's warm light, the bunk (rest), the galley (cook: GalleyScreen), the galley table, the
## seats, the bookshelf inside the front wall, the workbench on deck against it; the storage chests moved to their spot.
func _build_cabin() -> void:
	var meshes := ShipCabin.build(layout, layout.tier)
	_cabin_mesh = (meshes[0] as MeshBuilder).to_instance("Cabin")
	_cabin_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_cabin_mesh.visibility_range_end = 40.0
	_layout_root.add_child(_cabin_mesh)
	_cabin_fine = (meshes[1] as MeshBuilder).to_instance("CabinFine")
	_cabin_fine.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_cabin_fine.visibility_range_end = 14.0
	_layout_root.add_child(_cabin_fine)
	storage.position = layout.storage_at
	personal.position = layout.storage_at + Vector3(0, -0.6, 0)
	var bunk := _cabin_zone("Bunk", "Rest in the bunk  (K: switch your build here)", layout.bed_at + Vector3(0.85, 0.6, 0.0))
	bunk.interacted.connect(func(p: Player): _toast(get_node("/root/GameManager").rest(p)))
	bunk.add_to_group("rest_spots")
	var galley := _cabin_zone("Galley", "Cook at the galley", layout.counter_at + Vector3(-0.85, 0.6, 0.3))
	galley.interacted.connect(func(_p: Player): GameMenu.open_galley(get_node("/root/GameManager").galley_portions()))
	galley.gesture = "reach"
	pantry.position = layout.pantry_at
	var shelves := _cabin_zone("PantryShelves", "Open the pantry", layout.pantry_at + Vector3(-0.7, 0.6, 0.0))
	shelves.interacted.connect(func(_p: Player): GameMenu.open_galley(get_node("/root/GameManager").galley_portions()))
	shelves.gesture = "reach"
	# the galley table: a pot of several portions goes here for the crew (GalleyTable)
	var table := GalleyTable.new()
	table.name = "GalleyTable"
	ship_model.add_child(table)
	table.position = layout.counter_at + Vector3(-1.05, 0.0, -0.4)
	# seats: the cabin's at the table, the crate by the chest, the two crates on deck
	for s in ShipCabin.seats(layout, layout.tier):
		Seat.add(_layout_root, s[0], s[1], s[2])
	Seat.add(_layout_root, layout.storage_at + Vector3(-0.4, 0.6, 1.0), 0.6)
	for s in layout.deck_seats:
		Seat.add(_layout_root, s[0], s[1], s[2])
	# (1.28) the tinker's workbench on deck, against the cabin front under the port window (Workbench)
	# (solid as one of her own shapes: a body of its own aboard would stop her dead; _build_collision)
	Workbench.place(_layout_root, _bench_at(), 0.0, {"style": "ship", "solid": false})
	# (1.28) the bookshelf against the cabin's front wall, starboard of the door (BookShelf)
	BookShelf.place(_layout_root, _shelf_at(), 0.0)
	_cabin_light = OmniLight3D.new()
	_cabin_light.name = "CabinLight"
	_cabin_light.light_color = Color(1.0, 0.75, 0.45)
	_cabin_light.light_energy = 1.4
	_cabin_light.omni_range = 8.5 if layout.rooms else 6.5
	_cabin_light.shadow_enabled = false
	_cabin_light.position = ShipCabin.lamp_at(layout, layout.tier) + Vector3(0, -0.15, 0)
	_layout_root.add_child(_cabin_light)
	# (1.30) the brig's and galleon's other rooms' lamps (they hide with the cabin), and the galleon's gun deck below
	# (its own mesh and light, shown while a camera's near it)
	for at in ShipRooms.lamps(layout):
		var l := _cabin_light.duplicate() as OmniLight3D
		l.position = at
		_cabin_mesh.add_child(l)
	_hold_mesh = null
	_hold_light = null
	if layout.has_lower():
		_hold_mesh = (ShipRooms.hold(layout) as MeshBuilder).to_instance("GunDeck")
		_hold_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_hold_mesh.visibility_range_end = 60.0
		_layout_root.add_child(_hold_mesh)
		_hold_light = _cabin_light.duplicate() as OmniLight3D
		_hold_light.omni_range = (layout.lower_back - layout.lower_front) * 0.6
		_hold_light.light_energy = 1.2
		_hold_light.position = Vector3(0, layout.deck_y - 0.6, (layout.lower_front + layout.lower_back) * 0.5)
		_layout_root.add_child(_hold_light)
		for n in [_hold_mesh, _hold_light]:
			(n as Node3D).visible = false
	# (hidden until _show_cabin finds a camera near, next frame)
	for n in [_cabin_mesh, _cabin_fine, _cabin_light]:
		(n as Node3D).visible = false
	_cabin_t = 0.0


## (1.29) How many stacks the galley pantry holds: PANTRY_SLOTS, and the Galley & bunks line's "pantry" more (its spice
## rack, cold box, fruit net: ShipParts).
const PANTRY_SLOTS := 24


func pantry_slots() -> int:
	return PANTRY_SLOTS + int(ShipLines.total(kit, "pantry"))


func _bench_at() -> Vector3:
	return Vector3(-1.75, DECK_Y, layout.qd_front - Workbench.D * 0.5 - 0.02)


func _shelf_at() -> Vector3:
	return Vector3(2.0, layout.cabin_y, layout.qd_front + 0.13)


## The cabin's furniture and its light only while a camera could see in (inside, or by the door); four times a second.
func _show_cabin(delta: float) -> void:
	_cabin_t -= delta
	if _cabin_t > 0.0:
		return
	_cabin_t = 0.25
	var cam := get_viewport().get_camera_3d()
	var on := false
	if cam:
		var l := ship_model.to_local(cam.global_position)
		var top := layout.poop_y if layout.has_poop() else layout.qd_y
		on = absf(l.x) < layout.cabin_hw + 1.5 and l.z > layout.qd_front - 6.0 and l.z < layout.qd_back + 0.5 and l.y < top + 0.5
		if _hold_mesh:
			_hold_mesh.visible = absf(l.x) < layout.half_beam + 1.0 and l.z > layout.lower_front - 3.0 and l.z < layout.lower_back + 1.0 and l.y < layout.deck_y + 2.6
			_hold_light.visible = _hold_mesh.visible
	_cabin_mesh.visible = on
	_cabin_fine.visible = on
	_cabin_light.visible = on


## The storage chest (its Shared tab: GameManager.storage, shared in co-op; its Personal tab, personal: this
## captain's own sea chest, GameManager.sea_chest, never shared: a hidden bag the storage window switches to).
## _build_cabin puts them in the cabin.
func _build_storage() -> void:
	storage = (load("res://scenes/loot/loot_bag.tscn") as PackedScene).instantiate() as LootBag
	storage.name = "Storage"
	storage.persistent = true
	storage.label = "Ship's storage: shared"
	storage.add_to_group("ship_storage")
	storage.shared_id = "storage" if Net.active else ""
	if not Net.is_client():
		storage.contents = _game_manager_storage()
	ship_model.add_child(storage)
	personal = (load("res://scenes/loot/loot_bag.tscn") as PackedScene).instantiate() as LootBag
	personal.name = "SeaChest"
	personal.persistent = true
	personal.label = "Ship's storage: personal"
	personal.add_to_group("ship_storage")
	personal.contents = get_node("/root/GameManager").sea_chest
	ship_model.add_child(personal)
	personal.visible = false
	personal.collision_layer = 0
	personal.interactable.monitorable = false
	personal.interactable.collision_layer = 0
	# (1.29) the galley pantry: food and ingredients for the crew's cooking (Food.picks takes from it first), shared
	# through the host like the storage; no bag of its own to see: the galley screen shows it (GalleyScreen)
	pantry = (load("res://scenes/loot/loot_bag.tscn") as PackedScene).instantiate() as LootBag
	pantry.name = "Pantry"
	pantry.persistent = true
	pantry.label = "Galley pantry"
	pantry.shared_id = "pantry" if Net.active else ""
	if not Net.is_client():
		pantry.contents = get_node("/root/GameManager").pantry
	ship_model.add_child(pantry)
	pantry.visible = false
	pantry.collision_layer = 0
	pantry.interactable.monitorable = false
	pantry.interactable.collision_layer = 0
	(storage.get_node("MeshInstance3D") as MeshInstance3D).mesh = Props.treasure_chest_mesh()
	(storage.get_node("MeshInstance3D") as MeshInstance3D).position = Vector3.ZERO
	storage.get_node("CollisionShape3D").queue_free()
	var chest_cs := storage.get_node("Interactable/CollisionShape3D") as CollisionShape3D
	chest_cs.shape = chest_cs.shape.duplicate()
	(chest_cs.shape as SphereShape3D).radius = 1.1
	storage.interactable.reach = 1.1


## The flag at the masthead (painted from the kit: apply_kit) on a short pole: the hoist along the pole, the fly
## streaming out in a few soft folds and sagging a little toward its end (both faces read). `_flag_pivot` turns it
## downwind with a slow stir (_show_flag) and goes up the staff over the nest's hood (raise_flag).
func _build_flag() -> void:
	_flag_pivot = Node3D.new()
	_flag_pivot.name = "FlagPivot"
	ship_model.add_child(_flag_pivot)
	raise_flag(false)
	var mb := MeshBuilder.new()
	var cloth := PSXMat.lit("cloth_red")
	var w := 2.1
	var h := 1.25
	var cols := 6
	var edge: Array = []
	for i in range(cols + 1):
		var u := float(i) / cols
		var x := sin(u * PI * 2.2) * 0.14 * u
		var sag := 0.2 * u * u
		edge.append([Vector3(x, h - sag, 0.07 + u * w), Vector3(x, -sag * 1.3, 0.07 + u * w)])
	for i in range(cols):
		var u0 := float(i) / cols
		var u1 := float(i + 1) / cols
		var a: Vector3 = edge[i][0]
		var b: Vector3 = edge[i + 1][0]
		var c: Vector3 = edge[i + 1][1]
		var d: Vector3 = edge[i][1]
		var n := (b - a).cross(d - a).normalized()
		var shade := Color.WHITE.darkened(0.12 * (i % 2))
		mb.add_quad(cloth, a, b, c, d, Vector2(u0, 0), Vector2(u1, 0), Vector2(u1, 1), Vector2(u0, 1), shade, n)
		mb.add_quad(cloth, a, d, c, b, Vector2(1.0 - u0, 0), Vector2(1.0 - u0, 1), Vector2(1.0 - u1, 1), Vector2(1.0 - u1, 0), shade.darkened(0.1), -n)
	_flag_node = mb.to_instance("Flag")
	_flag_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_flag_pivot.add_child(_flag_node)
	var pole := MeshBuilder.new()
	pole.add_cylinder(PSXMat.lit("planks_dark"), Transform3D(Basis(), Vector3(0, -0.25, 0)), 0.045, 0.035, h + 0.4, 6, 0.8)
	pole.add_cylinder(PSXMat.lit("", Color(1.0, 0.76, 0.28)), Transform3D(Basis(), Vector3(0, h + 0.15, 0)), 0.07, 0.07, 0.07, 6, 1.0, Color.WHITE, true, true)
	var pm := pole.to_instance("FlagPole")
	pm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_flag_pivot.add_child(pm)


## The flag at the masthead, or run up the staff over the nest's hood (ShipParts).
func raise_flag(up: bool) -> void:
	_flag_pivot.position = Vector3(0, layout.mast_top + 0.2 + (0.75 if up else 0.0), layout.mast_z)


## The flag streams downwind (the wind's bearing off her bow: _wind_rel), stirring a little.
func _show_flag(delta: float) -> void:
	_flag_t += delta
	_flag_pivot.rotation.y = lerp_angle(_flag_pivot.rotation.y, PI - _wind_rel() + sin(_flag_t * 2.3) * 0.07, minf(3.0 * delta, 1.0))


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
	_layout_root.add_child(z)
	return z


func _toast(text: String) -> void:
	get_tree().call_group("hud", "show_toast", text)


func _line_mesh(mb: MeshBuilder, mat: Material, a: Vector3, b: Vector3) -> void:
	HullBuilder._line(mb, mat, a, b, 0.03)


## The hull's deck planks on the copy that darkens as they soak.
func _wet_overrides() -> void:
	for i in range(_psx_model.mesh.get_surface_count()):
		if _psx_model.mesh.surface_get_material(i) == _deck_mat:
			_psx_model.set_surface_override_material(i, _wet_deck)


## Flat, ragged puddles in the deck's low spots (grown by `wet`), and a copy
## of the deck planks to darken as they soak.
func _build_puddles() -> void:
	_wet_deck = (_deck_mat as ShaderMaterial).duplicate() as ShaderMaterial
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
	_wet_deck.set_shader_parameter("albedo_color", _deck_tint * Color.WHITE.lerp(Color(0.55, 0.53, 0.56), clampf(wet * 1.5, 0.0, 1.0)))
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
	var r := _ring_at(layout.rings, z)
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
	# (her class and her Quarters level: her layout, 1.29)
	var want := HullLayout.for_kit(kit)
	if want != layout:
		if want.rings != layout.rings:
			_refit_class(want)
		else:
			layout = want
			_relayout()
	# (her class over her upgrades: ShipClasses, 1.21)
	var sc := ShipClasses.of(kit)
	var was := max_hull
	max_hull = MAX_HULL * (1.0 + ShipLines.total(kit, "hull") + float(sc["hull"]))
	hull = clampf(hull + maxf(max_hull - was, 0.0), 0.0, max_hull)
	_top_k = 1.0 + ShipLines.total(kit, "speed") + float(sc["speed"])
	_turn_k = 1.0 + ShipLines.total(kit, "turn") + float(sc["turn"])
	_accel_k = 1.0 + float(sc["accel"])
	var ai := _aft_pair()
	var aft := get_node_or_null("ShipModel/CannonS%d" % ai) != null
	var aft_ok: bool = ShipLines.total(kit, "guns") >= 1.0 and bool(sc["aft_guns"])
	if aft_ok and not aft:
		_add_gun_pair(ai)
	elif not aft_ok and aft:
		for n in ["CannonS%d" % ai, "CannonP%d" % ai]:
			var c := ship_model.get_node(n)
			cannons.erase(c)
			c.free()
	var bow := get_node_or_null("ShipModel/CannonBow") as ShipCannon
	var chaser_ok: bool = ShipLines.total(kit, "chaser") >= 1.0 or bool(sc["chaser"])
	if chaser_ok and bow == null:
		bow = ShipCannon.new()
		bow.name = "CannonBow"
		bow.ship = self
		bow.team = "crew"
		bow.position = layout.map(ShipParts.CHASER_AT)
		ship_model.add_child(bow)
		cannons.append(bow)
	elif not chaser_ok and bow:
		cannons.erase(bow)
		bow.free()
	for c in cannons:
		var cn := c as ShipCannon
		var chase := cn.name == "CannonBow"
		var dmg := 1.0 + ShipLines.total(kit, "dmg") + (ShipLines.total(kit, "chaser_dmg") if chase else 0.0)
		cn.hull_damage = GUN_HULL * dmg
		cn.splash_damage = GUN_SPLASH * dmg
		cn.reload_time = GUN_RELOAD * (1.0 - ShipLines.total(kit, "reload"))
		cn.muzzle_speed = ShipCannon.MUZZLE_SPEED * sqrt(1.0 + ShipLines.total(kit, "range") + (ShipLines.total(kit, "chaser_range") if chase else 0.0))
	_night_k = ShipLines.total(kit, "night")
	_reef_k = 1.0 - ShipLines.total(kit, "reef")
	steady = ShipLines.total(kit, "steady")
	lookout = ShipLines.total(kit, "spot")
	InventoryComponent.bonus_slots = int(ShipLines.total(kit, "slots")) + int(sc["slots"])
	var paint := (_hull_mat as ShaderMaterial).duplicate() as ShaderMaterial
	paint.set_shader_parameter("albedo_color", ShipKit.HULL_PAINT[int(kit["hull"])][1])
	for i in range(_psx_model.mesh.get_surface_count()):
		if _psx_model.mesh.surface_get_material(i) == _hull_mat:
			_psx_model.set_surface_override_material(i, paint)
	# (1.29) her rails and trim, her masts and spars, her deck's stain, a stripe and stern accents
	_repaint(_trim_mat, ShipKit.RAILS[int(kit["rail"])][1])
	var spars := _repaint(_spar_mat, ShipKit.SPARS[int(kit["spar"])][1])
	_yard_node.material_override = spars
	for e in _rigs:
		(e[1] as MeshInstance3D).material_override = spars
	_deck_tint = ShipKit.DECKS[int(kit["deck"])][1]
	_rain_on_deck(0.0)
	_stripe(int(kit["stripe"]))
	var sails := (_canvas_mat as ShaderMaterial).duplicate() as ShaderMaterial
	sails.set_shader_parameter("albedo_color", ShipKit.SAILS[int(kit["sail"])][1])
	_sail_node.material_override = sails
	_furl_node.material_override = sails
	for e in _rigs:
		(e[2] as MeshInstance3D).material_override = sails
		(e[3] as MeshInstance3D).material_override = sails
	_sail_emblem(kit)
	parts.apply(kit, sails)
	_mizzen(ShipClasses.class_of(kit) == "caravel", sails)
	var flag := ShaderMaterial.new()
	flag.shader = PSXMat.LIT_SHADER
	flag.set_shader_parameter("albedo_tex", ImageTexture.create_from_image(ShipKit.flag_image(kit)))
	flag.set_shader_parameter("albedo_color", Color.WHITE)
	flag.set_shader_parameter("affine_amount", 0.6)
	flag.set_shader_parameter("use_vertex_color", true)
	_flag_node.material_override = flag
	for c in _figure_node.get_children():
		c.free()
	# (leaning out along the stem under the bowsprit, as far as its kind does: Figureheads.LEAN)
	_figure_node.rotation.x = Figureheads.lean(int(kit["figure"]))
	var fig := ShipKit.figurehead(int(kit["figure"]))
	if fig:
		_figure_node.add_child(fig)


## Her hull mesh's surfaces of `mat` in a copy of it painted `col` (returned).
func _repaint(mat: Material, col: Color) -> ShaderMaterial:
	var paint := (mat as ShaderMaterial).duplicate() as ShaderMaterial
	paint.set_shader_parameter("albedo_color", col)
	for i in range(_psx_model.mesh.get_surface_count()):
		if _psx_model.mesh.surface_get_material(i) == mat:
			_psx_model.set_surface_override_material(i, paint)
	return paint


## (1.29) A stripe in a second colour (ShipKit.STRIPES; 0 none) down both sides on the bulwark, following her sheer
## from the bow to the stern, and across her transom with a diamond badge at each end.
func _stripe(n: int) -> void:
	var old := _layout_root.get_node_or_null("Stripe")
	if old:
		old.free()
	if n <= 0:
		return
	var mat := PSXMat.lit("planks", ShipKit.STRIPES[n][1])
	var mb := MeshBuilder.new()
	var z0 := float(layout.rings[layout.rings.size() - 1][0]) + 0.5
	var z1 := float(layout.rings[0][0]) - 0.02
	var seg := 18
	for sgn in [-1.0, 1.0]:
		for i in range(seg):
			var za := lerpf(z0, z1, float(i) / seg)
			var zb := lerpf(z0, z1, float(i + 1) / seg)
			var ra := layout.ring_at(za)
			var rb := layout.ring_at(zb)
			var ya := float(ra[3]) + 0.22
			var yb := float(rb[3]) + 0.22
			var a := Vector3(sgn * (float(ra[1]) + 0.015), ya - 0.08, za)
			var b := Vector3(sgn * (float(rb[1]) + 0.015), yb - 0.08, zb)
			mb.add_quad(mat, a, b, b + Vector3(0, 0.16, 0), a + Vector3(0, 0.16, 0), Vector2(za * 0.5, 0), Vector2(zb * 0.5, 0), Vector2(zb * 0.5, 0.1), Vector2(za * 0.5, 0.1), Color.WHITE, Vector3(sgn, 0, 0))
	var st: Array = layout.rings[0]
	var z := float(st[0]) + 0.02
	mb.add_box(mat, Transform3D(Basis(), Vector3(0, layout.qd_y + 0.02, z)), Vector3(float(st[1]) * 2.0 - 0.1, 0.14, 0.03), 1.0)
	for sx in [-3.3, 3.3]:
		mb.add_box(mat, Transform3D(Basis(Vector3.BACK, PI * 0.25), Vector3(sx * layout.kx, layout.qd_y - 0.45, z)), Vector3(0.32, 0.32, 0.04), 1.0)
	var mi := mb.to_instance("Stripe")
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visibility_range_end = 400.0
	_layout_root.add_child(mi)


## The caravel's lateen mizzen (ShipClasses): a mast at the stern, a long yard slanting up aft over the helm (well
## above head height) and a triangular sail under it in her sails' colour; made or removed with her class.
func _mizzen(on: bool, sails: Material) -> void:
	var old := ship_model.get_node_or_null("Mizzen")
	if old and not on:
		old.free()
		return
	if old or not on:
		return
	var mb := MeshBuilder.new()
	var wood := PSXMat.lit("planks_dark")
	var qd := layout.qd_y
	var mz := 9.2
	mb.add_cylinder(wood, Transform3D(Basis(), Vector3(0, qd, mz)), 0.14, 0.1, 8.6, 6, 0.8)
	var a := Vector3(0.22, qd + 3.4, 5.6)
	var b := Vector3(0.22, qd + 10.2, 11.0)
	mb.add_tube(wood, PackedVector3Array([a, b]), 0.07, 0.05, 5, 0.8)
	var c := Vector3(0.24, qd + 2.9, mz + 0.2)
	var n := Vector3.RIGHT
	mb.add_tri(sails, a, b, c, n, n, n, Vector2(0, 0), Vector2(1, 1), Vector2(0.6, 0), Color.WHITE, n)
	mb.add_tri(sails, a, c, b, -n, -n, -n, Vector2(0, 0), Vector2(0.6, 0), Vector2(1, 1), Color(0.8, 0.8, 0.8), -n)
	mb.add_box(wood, Transform3D(Basis(), Vector3(0, qd + 8.7, mz)), Vector3(0.5, 0.12, 0.5), 1.0)
	var mi := mb.to_instance("Mizzen")
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ship_model.add_child(mi)


## The crew's emblem painted on the main sail (1.22): a patch on the sail's own two planes (so it fills, flaps and
## furls with it), a hair in front of the canvas and a mirrored one behind, in the flag's mark colour; none without
## an emblem.
func _sail_emblem(kit: Dictionary) -> void:
	var old := _sail_node.get_node_or_null("Emblem")
	if old:
		old.free()
	var img := ShipKit.sail_emblem_image(kit)
	if img == null:
		return
	var mat := ShaderMaterial.new()
	mat.shader = PSXMat.CUTOUT_SHADER
	mat.set_shader_parameter("albedo_tex", ImageTexture.create_from_image(img))
	mat.set_shader_parameter("use_vertex_color", false)
	var mb := MeshBuilder.new()
	for side: float in [1.0, -1.0]:
		# the sail's two planes (as _build_rig), the patch 0.12-0.88 across, 0.27-1.73 down (0-1 the upper, 1-2 the lower)
		for half in range(2):
			var q: Array = _sail_corners[half]
			var t0 := 0.27 if half == 0 else 0.0
			var t1 := 1.0 if half == 0 else 0.73
			var v0 := (t0 - 0.27 + float(half)) / 1.46
			var v1 := (t1 - 0.27 + float(half)) / 1.46
			var pts: Array = []
			for tv: float in [t0, t1]:
				for su: float in [0.12, 0.88]:
					var top_p: Vector3 = (q[0] as Vector3).lerp(q[1], su)
					var bot_p: Vector3 = (q[3] as Vector3).lerp(q[2], su)
					pts.append(top_p.lerp(bot_p, tv) + Vector3(0, 0, 0.04 * side))
			var u0 := 0.0 if side > 0.0 else 1.0
			var u1 := 1.0 - u0
			var n := Vector3(0, 0, side)
			if side > 0.0:
				mb.add_quad(mat, pts[0], pts[1], pts[3], pts[2], Vector2(u0, v0), Vector2(u1, v0), Vector2(u1, v1), Vector2(u0, v1), Color.WHITE, n)
			else:
				mb.add_quad(mat, pts[0], pts[2], pts[3], pts[1], Vector2(u0, v0), Vector2(u0, v1), Vector2(u1, v1), Vector2(u1, v0), Color.WHITE, n)
	var mi := mb.to_instance("Emblem")
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_sail_node.add_child(mi)


## The rig: the yard on the mast (it swings round to trim to the wind), the
## sail hanging from it (its own node, origin on the yard, so it rolls up by
## scaling toward it and fills or flaps), and the furled canvas on the yard.
func _build_rig(canvas: Material, wood: Material) -> void:
	var pivot := Vector3(0, layout.yard_y, layout.mast_z)
	_rig = Node3D.new()
	_rig.name = "Rig"
	_rig.position = pivot
	ship_model.add_child(_rig)
	var ymb := MeshBuilder.new()
	ymb.add_cylinder(wood, Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(4.5, 0, 0)), 0.12, 0.12, 9.0, 6, 0.8)
	_yard_node = ymb.to_instance("Yard")
	_rig.add_child(_yard_node)
	var sz := layout.mast_z + 0.25
	var top := Vector3(0, layout.yard_y - 0.15, sz)
	var mid_y := top.y - 4.35
	var bot_y := mid_y - 4.2
	var smb := MeshBuilder.new()
	var n := Vector3(0, 0, 1)
	var dim := Color(0.8, 0.8, 0.75)
	var c := [Vector3(-4.2, top.y, sz) - top, Vector3(4.2, top.y, sz) - top, Vector3(3.9, mid_y, sz + 0.45) - top,
		Vector3(-3.9, mid_y, sz + 0.45) - top, Vector3(3.6, bot_y, sz + 0.1) - top, Vector3(-3.6, bot_y, sz + 0.1) - top]
	# (the upper and lower planes' corners, top-left, top-right, bottom-right, bottom-left: the emblem's patch)
	_sail_corners = [[c[0], c[1], c[2], c[3]], [c[3], c[2], c[4], c[5]]]
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
	for i in range(layout.masts.size()):
		_rigs.append(_mast_rig(i + 1, layout.masts[i], canvas, wood))
	_show_sail(0.0)


## Another mast's yard and its square sail (sized to the mast: its yard's width, down to ~3 m over its deck) and the
## canvas furled on the yard; it braces, sets and furls with the main (_show_sail).
func _mast_rig(i: int, m: Array, canvas: Material, wood: Material) -> Array:
	var z := float(m[0])
	var w := float(m[4])
	var drop := float(m[3]) - float(m[1]) - 3.2
	var rig := Node3D.new()
	rig.name = "Rig%d" % i
	rig.position = Vector3(0, float(m[3]), z)
	ship_model.add_child(rig)
	var ymb := MeshBuilder.new()
	ymb.add_cylinder(wood, Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(w * 0.5, 0, 0)), 0.12, 0.12, w, 6, 0.8)
	var yard := ymb.to_instance("Yard")
	rig.add_child(yard)
	var hw := w * 0.5 - 0.3
	var c := [Vector3(-hw, 0, 0), Vector3(hw, 0, 0), Vector3(hw - 0.3, -drop * 0.51, 0.45), Vector3(-hw + 0.3, -drop * 0.51, 0.45),
		Vector3(hw - 0.6, -drop, 0.1), Vector3(-hw + 0.6, -drop, 0.1)]
	var smb := MeshBuilder.new()
	var n := Vector3(0, 0, 1)
	var dim := Color(0.8, 0.8, 0.75)
	var u := w / 4.2
	smb.add_quad(canvas, c[0], c[1], c[2], c[3], Vector2(0, 0), Vector2(u, 0), Vector2(u, 1.0), Vector2(0, 1.0), Color.WHITE, n)
	smb.add_quad(canvas, c[3], c[2], c[4], c[5], Vector2(0, 1.0), Vector2(u, 1.0), Vector2(u, 2.0), Vector2(0, 2.0), Color.WHITE, n)
	smb.add_quad(canvas, c[0], c[3], c[2], c[1], Vector2(0, 0), Vector2(0, 1.0), Vector2(u, 1.0), Vector2(u, 0), dim, -n)
	smb.add_quad(canvas, c[3], c[5], c[4], c[2], Vector2(0, 1.0), Vector2(0, 2.0), Vector2(u, 2.0), Vector2(u, 1.0), dim, -n)
	var sail := smb.to_instance("Sail")
	sail.position = Vector3(0, -0.15, 0.25)
	rig.add_child(sail)
	var fmb := MeshBuilder.new()
	fmb.add_cylinder(canvas, Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(hw - 0.15, 0, 0)), 0.26, 0.26, hw * 2.0 - 0.3, 6, 0.8)
	var furl := fmb.to_instance("FurledSail")
	furl.position = Vector3(0, -0.27, 0.3)
	rig.add_child(furl)
	furl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for mi in [yard, sail, furl]:
		(mi as MeshInstance3D).visibility_range_end = 900.0
	return [rig, yard, sail, furl]


## The rigging up to the crow's nest (both sides). The swing ropes at the yard's
## ends are the yard ropes upgrade (ShipParts).
func _build_climbing() -> void:
	for sgn in [-1.0, 1.0]:
		var rig := ShipRigging.new()
		rig.name = "RiggingS" if sgn > 0.0 else "RiggingP"
		rig.side = sgn
		rig.layout = layout
		ship_model.add_child(rig)


## Canvas let down as far as sail_shown (the rest bundled on the yard); the
## yard braced round to the wind; the sail bellies out, fuller in a fair wind.
func _show_sail(delta: float) -> void:
	var k := clampf(sail_shown, 0.0, 1.0)
	var rel := _wind_rel()
	_brace = lerp_angle(_brace, clampf(rel * 0.5, -0.8, 0.8), clampf(1.5 * delta, 0.0, 1.0))
	_rig.rotation.y = _brace
	var belly := lerpf(0.8, 1.25, clampf((wind_effect() - 1.0) / FAIR_BOOST, 0.0, 1.0))
	var rs := rig_scale * layout.sail_k
	_sail_node.scale = Vector3(rs.x, lerpf(0.03, 1.0, k) * rs.y, belly)
	_sail_node.visible = k > 0.01
	var r := lerpf(1.0, 0.35, k)
	_furl_node.scale = Vector3(rs.x, r, r)
	_yard_node.scale.x = rig_scale.x * layout.yard_w / 9.0
	_furl_node.visible = k < 0.98
	for e in _rigs:
		(e[0] as Node3D).rotation.y = _brace
		(e[2] as Node3D).scale = Vector3(1.0, lerpf(0.03, 1.0, k), belly)
		(e[2] as Node3D).visible = k > 0.01
		(e[3] as Node3D).scale = Vector3(1.0, r, r)
		(e[3] as Node3D).visible = k < 0.98
	parts.show_sail(k)


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
const FAIR_BOOST := 0.2
var _fair_on: bool = false


func wind_effect() -> float:
	return wind_boost(_heading, get_node_or_null("/root/Weather"))


## The same for any ship on `heading` (the pirates sail by it too).
static func wind_boost(heading: float, wx: Node) -> float:
	var wd: Vector2 = wx.wind_dir() if wx else Vector2(1, 0)
	var a := rad_to_deg(absf(Vector2(-sin(heading), -cos(heading)).angle_to(wd)))
	var pts := [[0.0, 0.8], [60.0, 1.0], [110.0, 1.0], [140.0, 0.0], [180.0, 0.0]]
	var fair := 0.0
	for i in range(pts.size() - 1):
		if a <= float(pts[i + 1][0]):
			var t := (a - float(pts[i][0])) / (float(pts[i + 1][0]) - float(pts[i][0]))
			fair = lerpf(float(pts[i][1]), float(pts[i + 1][1]), t)
			break
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
	_anchor.position = layout.anchor_at
	ship_model.add_child(_anchor)
	# the capstan: a drum with its bars, chain wound round it
	var cap := MeshBuilder.new()
	cap.add_cylinder(wood, Transform3D(Basis(), layout.capstan_at), 0.32, 0.26, 0.75, 8, 1.0)
	cap.add_cylinder(iron, Transform3D(Basis(), layout.capstan_at + Vector3(0, 0.3, 0)), 0.29, 0.29, 0.14, 8, 1.0)
	for k in range(4):
		var b := Basis(Vector3.UP, PI * 0.25 * k)
		cap.add_box(wood, Transform3D(b, layout.capstan_at + Vector3(0, 0.66, 0)), Vector3(1.3, 0.06, 0.06), 1.0)
	ship_model.add_child(cap.to_instance("Capstan"))
	# a link, two ways round (they alternate down the chain)
	var lm := MeshBuilder.new()
	lm.add_box(iron, Transform3D(Basis(), Vector3(0, 0, 0.045)), Vector3(0.03, CHAIN_STEP + 0.03, 0.025), 1.0)
	lm.add_box(iron, Transform3D(Basis(), Vector3(0, 0, -0.045)), Vector3(0.03, CHAIN_STEP + 0.03, 0.025), 1.0)
	var link := lm.commit()
	# along the deck to the rail (it doesn't move)
	var deck_chain := MeshBuilder.new()
	var from := layout.capstan_at + Vector3(0, 0.3, 0)
	var to := layout.anchor_at + Vector3(-0.15, 0.1, 0.0)
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
	_cable.position = layout.anchor_at
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
	FX.sfx("rope", global_transform * layout.anchor_at, -2.0, 0.05, 0.7 if on else 0.9)
	if on:
		FX.splash(global_transform * (layout.anchor_at + Vector3(0, -2.0, 0)), 8, 1.0)


func _show_anchor(delta: float) -> void:
	_anchor_drop = move_toward(_anchor_drop, 1.0 if anchored else 0.0, delta * 0.8)
	var depth := lerpf(0.0, 5.6, _anchor_drop)
	_anchor.position = layout.anchor_at + Vector3(0, -depth, 0)
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
	return [_pos, _heading, _y, _pitch, _roll, speed, rudder, _yaw_rate, _vy, _vpitch, _vroll, sail, _turn_in, _back_in, anchored,
		_helm_k.x, _helm_k.y, _helm_k.z, is_player_steering]


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
