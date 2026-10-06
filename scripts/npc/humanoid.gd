class_name Humanoid
extends Node3D
## Tapered low-poly PS1-style character (see BodyBuilder / CharacterLook) with a
## procedural pose animator.
## Faces -Z (Godot forward). Feet at local y = 0, about 1.8 m tall.
##
## Skeleton (all plain Node3D pivots):
##   Pivot (hip height, used for rolls/flips/crouch)
##     Hips
##       LegL/LegR (thigh) -> ShinL/ShinR (knee)
##       Torso -> Neck -> Head, ArmL/ArmR (shoulder) -> ForeL/ForeR (elbow) -> HandL/HandR sockets
##       Torso -> HipSocket (sheathed weapon)
##
## Rotation conventions (radians):
##   thigh/arm  +x = swing forward      shin  -x = bend knee      fore +x = bend elbow
##   torso      -x = lean forward       head  -x = look down (split over neck + head)
##   arm_r      +z = raise sideways     arm_l -z = raise sideways
##
## Look: a CharacterLook dictionary (body, face, hair, hats, clothing layers,
## accessories). Older keys (shirt/pants/boots, coat bool, face 0..7) still work.

signal action_finished(action_name: String)
## Emitted on each footfall while walking/running (strength 0..1 ~ speed).
signal footstep(strength: float)

const PIVOT_Y := 0.9
const JOINTS := ["pivot", "hips", "torso", "head", "arm_l", "fore_l", "arm_r", "fore_r", "leg_l", "shin_l", "leg_r", "shin_r", "hand_r"]
## Actions that spin the whole body (applied instantly, pivot reset after).
const SPIN_ACTIONS := ["roll", "flip", "spin_slash", "roundhouse", "dual_spin", "gun_kata"]
const UPPER := ["torso", "head", "arm_l", "fore_l", "arm_r", "fore_r", "hand_r"]

var look: Dictionary = {}

var pivot: Node3D
var hips: Node3D
var torso: Node3D
var neck: Node3D
var head: Node3D
var leg_l: Node3D
var leg_r: Node3D
var shin_l: Node3D
var shin_r: Node3D
var arm_l: Node3D
var arm_r: Node3D
var fore_l: Node3D
var fore_r: Node3D
var hand_l: Node3D
var hand_r: Node3D
var hip_socket: Node3D

# ---- Animation inputs (set by the owner every frame) ----
## Horizontal speed in m/s (drives walk/run cadence).
var ground_speed: float = 0.0
## Legacy NPC input: 0 idle .. 1 walk (converted to ground_speed when ground_speed is 0).
var move_speed: float = 0.0
## Movement direction relative to facing: x = right, y = forward (for strafing).
var local_move: Vector2 = Vector2(0, 1)
## Direction of the current "dash" action in model space (x = right, y = forward).
var dash_dir: Vector2 = Vector2(1, 0)
var grounded: bool = true
var vertical_speed: float = 0.0
## Combat stance (weapon drawn).
var armed: bool = false
var sprinting: bool = false
var talking: bool = false
## Sitting on a bench / stool (seat height `seat_y` above the feet).
var seated: bool = false
## Standing at a ship's wheel: hands on the spokes, `helm_steer` (-1..1)
## turns the wheel and shifts the body with it.
var at_helm: bool = false
var helm_steer: float = 0.0
## Down on one knee, hands reaching to someone on the ground (reviving a
## crewmate).
var kneeling: bool = false
## Working a ship's cannon: crouched behind it, hands on the carriage.
var manning: bool = false
## In the water: breaststroke when moving, treading water otherwise; `diving`
## ducks under head first. `climbing` = hand over hand up a ladder, with
## `climb_phase` = how high you are (drives the arm/leg cycle).
var swimming: bool = false
## Carrying a long gun at the ready (riflemen): both hands on it across the body.
var carry: String = ""
## Gun elevation while aiming (radians, + = up).
var aim_pitch: float = 0.0
var diving: bool = false
var climbing: bool = false
## Plant the feet on uneven ground (stairs, slopes, the deck): two-bone leg IK
## with the hips dropping to the lower foot. Off while airborne, swimming,
## climbing, seated or at the helm.
var foot_ik: bool = true
var _ik_w: float = 0.0
var _ik_h := Vector2.ZERO        # smoothed ground offset under each foot (l, r)
var _ik_drop: float = 0.0
var _ik_body: RID
var _ik_body_found: bool = false
var climb_phase: float = 0.0
var _swim_phase: float = 0.0
var _swim_move: float = 0.0
var seat_y: float = 0.47
var gesture: float = 0.0
## Where the character wants to look (world space), e.g. the camera's aim for
## the player; look_weight 0 = ignore. The head eases toward it within the
## neck's range.
var look_target: Vector3 = Vector3.ZERO
var look_weight: float = 0.0

# ---- Weapon ----
var weapon: MeshInstance3D
var weapon_in_hand: bool = false
## Off-hand weapon (dual wielding): in the left hand when drawn, on the left hip
## when sheathed.
var offhand: MeshInstance3D
var _hip_socket_l: Node3D
## Fighting stance for the guard pose: sword, dual_sword, fist, pistol,
## dual_pistol, claw.
var stance: String = "sword"
## Hanging from a vine: the free arm and both legs swing loose, ragdoll
## style, driven by what the body feels - `dangle_g` (gravity minus the
## body's own acceleration) and `dangle_v` (its velocity, for air drag), both
## in the body's local frame (set by the owner every frame).
var dangle: bool = false
var dangle_g: Vector3 = Vector3(0, -9.8, 0)
var dangle_v: Vector3 = Vector3.ZERO
var _dg: Dictionary = {}   # joint -> [angle Vector2 (x = swing fwd, y = toward +X), velocity Vector2]
## Loose limbs and where they rest relative to straight down (x fwd, toward +X).
const DANGLE_LIMBS := {"leg_l": Vector2(0.2, -0.12), "leg_r": Vector2(0.05, 0.12), "arm_l": Vector2(0.15, -0.3)}
## Build the hands as separate meshes so they can close into fists (the
## player; set before setup()).
var swappable_hands: bool = false
## Hands closed into fists (bare-handed fighting; set automatically while the
## fist stance is up).
var fists: bool = false
## Zoan hybrid extras (ears, snout, claws, tail).
var _beast: Array = []
var _tail: Node3D
var _left_prop: MeshInstance3D

# ---- Internal state ----
var _cur: Dictionary = {}
var _lift: Vector3 = Vector3.ZERO
var _phase: float = 0.0
## Strafing (combat stance): the travel direction relative to where the body
## faces (smoothed, radians, 0 = ahead), whether the legs are backpedalling,
## and how far the hips (and so the legs) turn toward it while the chest stays
## square to the target.
var _travel_ang: float = 0.0
var _gait_back: bool = false
var _hip_yaw: float = 0.0
## Most the hips turn into a strafe; the rest is a side-reach of the legs.
const HIP_YAW_MAX := 0.95
## How much of that turn the pelvis takes; the thighs turn in their sockets for the rest.
const PELVIS_SHARE := 0.4
## Combat stance: the chest tips into a change of direction (lagging body-space velocity).
var _tip_lag: Vector2 = Vector2.ZERO
const TIP_GAIN := 0.075
const TIP_MAX := 0.5
## Jump pose variety: which side leads (+1 = left) and per-limb offsets, rolled each take-off.
var _jside: float = 1.0
var _jv: Array = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
var _air_vy: float = 0.0
## Idle weight shift phase (per body, so a crowd doesn't sway in step).
var _idle_seed: float = 0.0
## Out of combat: push-off / planted stop / skid timers (1 -> 0) and what set them.
var _start: float = 0.0
var _stop: float = 0.0
var _stop_k: float = 0.0
var _stop_side: float = 1.0
var _skid: float = 0.0
var _skid_k: float = 0.0
var _slow_t: float = 0.0
var _prev_spd: float = 0.0
var _peak_spd: float = 0.0
var _fast_dir: Vector3 = Vector3.ZERO
var _fast_t: float = 99.0
var _t: float = 0.0
var _was_grounded: bool = true
var _land: float = 0.0
var _land_strength: float = 0.0
var _air_time: float = 0.0
var _action: Dictionary = {}
var _action_w: float = 0.0
var _base: Dictionary = {}
## Hip height from the body style (the legs' length); PIVOT_Y is the reference.
var hip_y: float = PIVOT_Y
## Hair / cloth physics (SpringChains) owned by this body.
var _sims: Array = []
var _last_step_sign: float = 1.0
# ---- Procedural head / neck "look" layer (on top of the posed head) ----
var _look := Vector3.ZERO
var _gait_look := Vector3.ZERO
var _look_total := Vector3.ZERO
var _glance := Vector3.ZERO
var _glance_t := 0.0
var _turn_lead := 0.0
var _prev_yaw := INF
var _rng := RandomNumberGenerator.new()
var _look_v := Vector3.ZERO
# secondary motion: the head's inertia against the body (lags, overshoots)
var _hs := Vector3.ZERO
var _hv := Vector3.ZERO
var _prev_body := Vector3.INF
var _prev_body_w := Vector3.ZERO
var _prev_lift_y := INF
var _prev_lift_vy := 0.0
## Physics ragdoll (heavy hits, death). While it exists the bodies pose the rig.
var ragdoll: Ragdoll = null
## Co-op: this body is simulated here (your captain, or an enemy on the
## host), so its one-shot animations, ragdolls and get-ups are mirrored to
## the other players (through the Net autoload, looked up at run time so the
## class stays usable without it).
var net_sync: bool = false
var _net_last_name: String = ""
var _net_last_dur: float = 0.0
var _net_last_ms: int = -100000
var _getup_from: Dictionary = {}
var _getup_lift := Vector3.ZERO
## A soft blend out of the ragdoll (recover_from_ragdoll): pose smoothing is
## slowed for this long.
var _soft_t: float = 0.0
var _soft_dur: float = 0.0
var _getup_face_up := true


func setup(look_dict: Dictionary) -> Humanoid:
	look = look_dict
	_build()
	_rng.randomize()
	_glance_t = _rng.randf_range(0.5, 2.5)
	_idle_seed = _rng.randf() * TAU
	for j in JOINTS:
		_cur[j] = Vector3.ZERO
	return self


func _c(key: String, fallback: Color) -> Color:
	return look.get(key, fallback)


# ==========================================================================
# Model
# ==========================================================================
func _build() -> void:
	look = CharacterLook.normalize(look)
	for c in get_children():
		remove_child(c)
		c.queue_free()
	_sims.clear()
	var s: float = float(look.get("height", 1.0))
	scale = Vector3(s, s, s)
	BodyBuilder.build(self, look)


## Rebuild the body with a new look (character creator), keeping the weapon
## and the current pose.
func apply_look(look_dict: Dictionary) -> void:
	if weapon and weapon.get_parent():
		weapon.get_parent().remove_child(weapon)
	hide_left_prop()
	if offhand and offhand.get_parent():
		offhand.get_parent().remove_child(offhand)
	_hip_socket_l = null
	look = look_dict
	_build()
	_beast.clear()
	_tail = null
	_attach_weapon(weapon_in_hand)
	_apply_fists()


func _update_physics(delta: float) -> void:
	if _sims.is_empty():
		return
	# Physics only near the camera; far characters keep their last pose and
	# snap to rest when they come back into range.
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	var near := cam == null or cam.global_position.distance_squared_to(global_position) < 30.0 * 30.0
	for s in _sims:
		if near:
			(s as SpringChains).simulate(delta)
		else:
			(s as SpringChains).reset()


# ==========================================================================
# Weapon + props
# ==========================================================================
## Give the character a weapon mesh (grip at origin, blade along -Z).
## It starts sheathed on the hip.
func set_weapon(mesh: Mesh) -> void:
	if weapon:
		weapon.queue_free()
		weapon = null
	if mesh == null:
		return
	weapon = MeshInstance3D.new()
	weapon.name = "Weapon"
	weapon.mesh = mesh
	_attach_weapon(weapon_in_hand)


func _attach_weapon(in_hand: bool) -> void:
	weapon_in_hand = in_hand
	if offhand:
		var t2 := hand_l if in_hand else _left_hip()
		if offhand.get_parent() != t2:
			if offhand.get_parent():
				offhand.get_parent().remove_child(offhand)
			t2.add_child(offhand)
		offhand.transform = Transform3D.IDENTITY
	if weapon == null:
		return
	var target := hand_r if in_hand else hip_socket
	if weapon.get_parent() != target:
		if weapon.get_parent():
			weapon.get_parent().remove_child(weapon)
		target.add_child(weapon)
	weapon.transform = Transform3D.IDENTITY


## The player's bodies (and their co-op puppets) aim their pistols every frame
## after posing (grunts aim their own).
var auto_point_guns := false


## Pistols in hand point where the body faces (pitched by aim_pitch) instead of
## along the wrist (which, with the hand down, is straight up); in the gun kata
## each follows its own forearm, out to the sides. Called by whoever drives a
## pistol-wielding body (the player and its co-op puppets) after posing it.
func point_guns() -> void:
	if stance not in ["pistol", "dual_pistol"] or not weapon_in_hand or current_action() == "reload" or not is_inside_tree():
		return
	var kata := current_action() == "gun_kata"
	var fwd := -global_basis.z
	fwd.y = 0.0
	if fwd.length() < 0.01:
		return
	fwd = fwd.normalized()
	var dir := (fwd * cos(aim_pitch) + Vector3.UP * sin(aim_pitch)).normalized()
	for g in [[weapon, fore_r], [offhand, fore_l]]:
		var w: Node3D = g[0]
		if w == null or not is_instance_valid(w) or not w.is_inside_tree():
			continue
		var d := -(g[1] as Node3D).global_basis.y.normalized() if kata else dir
		w.global_basis = Basis.looking_at(d, Vector3.UP if absf(d.y) < 0.95 else Vector3.FORWARD)


## A second weapon in the off hand (null clears it).
func set_offhand(mesh: Mesh) -> void:
	if offhand:
		offhand.queue_free()
		offhand = null
	if mesh == null:
		return
	offhand = MeshInstance3D.new()
	offhand.name = "Offhand"
	offhand.mesh = mesh
	_attach_weapon(weapon_in_hand)


## Zoan hybrid form extras: pointed ears, a muzzle, claws and a tail, in the
## fur color (the body itself is re-skinned by the caller).
func set_beast(on: bool, fur: Color = Color(0.55, 0.5, 0.44)) -> void:
	for n in _beast:
		if is_instance_valid(n):
			(n as Node).queue_free()
	_beast.clear()
	_tail = null
	if not on:
		return
	var fm := PSXMat.lit("hair", fur)
	var dk := PSXMat.flat(fur.darkened(0.55))
	var cl := PSXMat.flat(Color(0.93, 0.9, 0.8))
	# ears + muzzle on the head
	var hb := MeshBuilder.new()
	for sx in [-1.0, 1.0]:
		hb.add_cone(fm, Transform3D(Basis(Vector3.FORWARD, -sx * 0.3), Vector3(sx * 0.085, 0.25, 0.0)), 0.06, 0.18, 4)
		hb.add_cone(dk, Transform3D(Basis(Vector3.FORWARD, -sx * 0.3), Vector3(sx * 0.085, 0.255, -0.02)), 0.035, 0.12, 4)
	var lt := PSXMat.lit("hair", fur.lightened(0.25))
	hb.add_box(lt, Transform3D(Basis(Vector3.RIGHT, 0.12), Vector3(0, 0.055, -0.13)), Vector3(0.1, 0.075, 0.13))
	hb.add_box(dk, Transform3D(Basis(), Vector3(0, 0.085, -0.2)), Vector3(0.05, 0.035, 0.03))
	hb.add_box(PSXMat.flat(Color(0.95, 0.93, 0.85)), Transform3D(Basis(), Vector3(0, 0.022, -0.17)), Vector3(0.07, 0.012, 0.04))
	var hm := hb.to_instance("BeastHead")
	head.add_child(hm)
	_beast.append(hm)
	# claws: three on each hand
	for hand in [hand_l, hand_r]:
		var cb := MeshBuilder.new()
		for i in range(3):
			var x := (float(i) - 1.0) * 0.022
			cb.add_cone(cl, Transform3D(Basis(Vector3.RIGHT, PI * 0.88), Vector3(x, -0.07, -0.03)), 0.009, 0.06, 4)
		var cm := cb.to_instance("Claws")
		(hand as Node3D).add_child(cm)
		_beast.append(cm)
	# tail off the hips
	_tail = Node3D.new()
	_tail.name = "Tail"
	_tail.position = Vector3(0, -0.02, 0.13)
	hips.add_child(_tail)
	var tb := MeshBuilder.new()
	tb.add_cylinder(fm, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 0, 0.14)), 0.045, 0.06, 0.28, 5, 1.0)
	tb.add_cone(fm, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 0, 0.28)), 0.06, 0.2, 5)
	_tail.add_child(tb.to_instance("TailMesh"))
	_beast.append(_tail)


## The right hip socket mirrored to the left side (made on demand).
func _left_hip() -> Node3D:
	if _hip_socket_l == null or not is_instance_valid(_hip_socket_l):
		_hip_socket_l = Node3D.new()
		_hip_socket_l.name = "HipSocketL"
		hip_socket.get_parent().add_child(_hip_socket_l)
		var m := Basis(Vector3(-1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, 1))
		_hip_socket_l.transform = Transform3D(m * hip_socket.basis * m, Vector3(-hip_socket.position.x, hip_socket.position.y, hip_socket.position.z))
	return _hip_socket_l


## Guard pose for the current stance.
func _guard() -> Dictionary:
	match stance:
		"dual_sword":
			return {"arm_r": Vector3(0.75, -0.2, 0.35), "fore_r": Vector3(0.5, 0, 0),
				"arm_l": Vector3(0.75, 0.2, -0.35), "fore_l": Vector3(0.5, 0, 0),
				"torso": Vector3(-0.12, 0.1, 0), "head": Vector3(0.08, -0.1, 0)}
		"fist":
			return FIST_GUARD
		"claw":
			# hunched forward, claws held out low at the sides
			return {"arm_r": Vector3(0.3, -0.25, 0.75), "fore_r": Vector3(1.25, 0, 0),
				"arm_l": Vector3(0.3, 0.25, -0.75), "fore_l": Vector3(1.25, 0, 0),
				"torso": Vector3(-0.5, -0.15, 0), "head": Vector3(0.8, 0.15, 0)}
		"pistol":
			return {"arm_r": Vector3(1.05, -0.2, 0.18), "fore_r": Vector3(0.45, 0, 0), "hand_r": Vector3(-0.35, 0, 0),
				"arm_l": Vector3(0.25, 0.1, -0.2), "fore_l": Vector3(0.6, 0, 0),
				"torso": Vector3(-0.05, 0.25, 0), "head": Vector3(0.05, -0.2, 0)}
		"dual_pistol":
			# held low and close, elbows a little bent (raised to fire: shoot_r/l)
			return {"arm_r": Vector3(0.35, -0.1, 0.1), "fore_r": Vector3(0.7, 0, 0), "hand_r": Vector3(-0.35, 0, 0),
				"arm_l": Vector3(0.35, 0.1, -0.1), "fore_l": Vector3(0.7, 0, 0),
				"torso": Vector3(-0.05, 0.0, 0), "head": Vector3(0.05, 0, 0)}
	return GUARD


## Loose limbs while hanging (see `dangle`): each swings like a damped
## pendulum toward the direction it would hang given what the body feels.
func _update_dangle(delta: float) -> void:
	if not dangle:
		if not _dg.is_empty():
			_dg.clear()
		return
	var g := dangle_g - dangle_v * 0.8   # air drag: limbs trail behind the motion
	var d := g.normalized() if g.length() > 0.5 else Vector3.DOWN
	var ax := atan2(-d.z, -d.y)
	var az := atan2(d.x, sqrt(d.y * d.y + d.z * d.z))
	var steps := clampi(ceili(minf(delta, 0.1) / (1.0 / 120.0)), 1, 12)
	var h := minf(delta, 0.1) / steps
	for j in DANGLE_LIMBS.keys():
		var rest: Vector2 = DANGLE_LIMBS[j]
		if not _dg.has(j):
			_dg[j] = [rest, Vector2.ZERO]
		var a: Vector2 = _dg[j][0]
		var v: Vector2 = _dg[j][1]
		var tgt := Vector2(clampf(ax + rest.x, -1.3, 2.2), clampf(az + rest.y, -1.2, 1.2))
		var k := 55.0 if j != "arm_l" else 40.0
		for i in range(steps):
			var acc := (tgt - a) * k - v * 4.0
			v += acc * h
			a += v * h
		_dg[j] = [a, v]


## The held block for the current stance (upper body; the legs keep walking).
func _block_pose() -> Dictionary:
	match stance:
		"fist", "claw", "dual_pistol", "pistol":
			# forearms up in front of the face, chin tucked, square to the front
			return {"torso": Vector3(-0.2, 0.45, 0), "head": Vector3(0.28, 0.05, 0),
				"arm_l": Vector3(1.3, -0.32, -0.05), "fore_l": Vector3(2.2, 0, 0),
				"arm_r": Vector3(1.3, 0.32, 0.05), "fore_r": Vector3(2.2, 0, 0), "hand_r": Vector3(-0.3, 0, 0)}
		"dual_sword":
			# both blades crossed in front
			return {"torso": Vector3(-0.12, 0.0, 0), "head": Vector3(0.12, 0, 0),
				"arm_r": Vector3(1.35, -0.6, -0.15), "fore_r": Vector3(1.25, 0, 0), "hand_r": Vector3(0, 0, 1.2),
				"arm_l": Vector3(1.35, 0.6, 0.15), "fore_l": Vector3(1.25, 0, 0)}
	# one blade held level across the body, the off hand bracing it
	return {"torso": Vector3(-0.08, -0.2, 0), "head": Vector3(0.08, 0.2, 0),
		"arm_r": Vector3(1.35, -0.6, -0.15), "fore_r": Vector3(1.25, 0, 0), "hand_r": Vector3(0, 0, 1.2),
		"arm_l": Vector3(1.1, 0.5, -0.1), "fore_l": Vector3(1.6, 0, 0)}


## Close or open both hands (swaps the mitten hand meshes for fists).
func set_fists(on: bool) -> void:
	if on == fists:
		return
	fists = on
	_apply_fists()


func _apply_fists() -> void:
	for f in [fore_l, fore_r]:
		if f == null or not is_instance_valid(f):
			continue
		var mit := f.get_node_or_null("Mitten") as Node3D
		var fi := f.get_node_or_null("Fist") as Node3D
		if mit and fi:
			mit.visible = not fists
			fi.visible = fists


## Show a temporary prop in the left hand (e.g. a rum bottle while drinking).
func show_left_prop(mesh: Mesh) -> void:
	hide_left_prop()
	_left_prop = MeshInstance3D.new()
	_left_prop.mesh = mesh
	hand_l.add_child(_left_prop)


func hide_left_prop() -> void:
	if _left_prop:
		_left_prop.queue_free()
		_left_prop = null


# ==========================================================================
# Actions (one-shot animations)
# ==========================================================================
## Play a named action. Known names: draw, sheathe, slash_r, slash_l, slash_down,
## heavy, roll, flip, parry, stagger, drink, wave, hit.
func play(action_name: String, duration: float) -> void:
	if net_sync:
		var now := Time.get_ticks_msec()
		# (some states re-play a held pose every frame: don't flood the wire)
		if action_name != _net_last_name or absf(duration - _net_last_dur) > 0.01 or now - _net_last_ms > 250:
			_net_last_name = action_name
			_net_last_dur = duration
			_net_last_ms = now
			_net_send("play", [action_name, duration])
	if not _action.is_empty() and _action["name"] != action_name:
		_finish_action()
	_action = {"name": action_name, "t": 0.0, "dur": maxf(duration, 0.01), "events": {}}
	_action_w = 1.0 if action_name in SPIN_ACTIONS else 0.0


func stop_action() -> void:
	if net_sync and not _action.is_empty():
		_net_last_name = ""
		_net_send("stop", [])
	if not _action.is_empty():
		_finish_action()


func current_action() -> String:
	return "" if _action.is_empty() else str(_action["name"])


func is_busy() -> bool:
	return not _action.is_empty()


func _finish_action() -> void:
	var n := str(_action["name"])
	# make sure attach events happened even if interrupted
	if n == "draw":
		_attach_weapon(true)
	elif n == "sheathe":
		_attach_weapon(false)
	elif n == "drink":
		hide_left_prop()
	if n in SPIN_ACTIONS:
		_cur["pivot"] = Vector3.ZERO
	_action = {}
	action_finished.emit(n)


static func _ease(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)


## The hybrid's beast stance (stance "claw"): `walk` 0 = crouched in place,
## 1 = on the move; `run` adds the sprint. Writes the pose into `p` (the
## legs keep the gait's stride, deeper and wider) and returns how far the
## hips drop.
func _feral(p: Dictionary, walk: float, run: float, s: float) -> float:
	var br := sin(_t * 4.2)
	var tw := sin(_t * 9.0) * 0.05
	if sprinting:
		run = 1.0
	# (the whole body pitches forward from the hips: the "pivot")
	var idle := {
		"pivot": Vector3(-0.22, 0, 0),
		"hips": Vector3(0, 0.25, 0), "torso": Vector3(-0.5 + br * 0.04, -0.15, br * 0.02), "head": Vector3(0.8 - br * 0.03, 0.15, 0),
		"arm_l": Vector3(0.3 + br * 0.05, 0.25, -0.75 - br * 0.04), "fore_l": Vector3(1.25 + tw, 0, 0),
		"arm_r": Vector3(0.3 + br * 0.05, -0.25, 0.75 + br * 0.04), "fore_r": Vector3(1.25 - tw, 0, 0),
		"leg_l": Vector3(1.25, 0, -0.34), "shin_l": Vector3(-1.85, 0, 0),
		"leg_r": Vector3(0.6, 0, 0.34), "shin_r": Vector3(-1.45, 0, 0)}
	var lean := lerpf(0.6, 0.85, run)
	var back := lerpf(0.35, 0.8, run)
	var move := {
		"pivot": Vector3(-lerpf(0.25, 0.4, run), 0, 0),
		"hips": p["hips"], "torso": Vector3(-lean, s * 0.25, 0), "head": Vector3(lean + 0.35, 0, 0),
		"arm_l": Vector3(-back - s * 0.55, 0.2, -0.9 - absf(s) * 0.15), "fore_l": Vector3(0.95, 0, 0),
		"arm_r": Vector3(-back + s * 0.55, -0.2, 0.9 + absf(s) * 0.15), "fore_r": Vector3(0.95, 0, 0)}
	for leg in ["leg_l", "leg_r"]:
		var g: Vector3 = p[leg]
		var side := -1.0 if leg == "leg_l" else 1.0
		move[leg] = Vector3(g.x * 1.25 + 0.55, 0, g.z + side * 0.12)
	for shin in ["shin_l", "shin_r"]:
		move[shin] = (p[shin] as Vector3) * 1.2 + Vector3(-0.55, 0, 0)
	var w := clampf(walk, 0.0, 1.0)
	for j in idle.keys():
		p[j] = (idle[j] as Vector3).lerp(move[j], w)
	return lerpf(-0.44, lerpf(-0.3, -0.36, run), w) + br * 0.015 * (1.0 - w)


## Interpolate between key poses. keys = [[t, {joint: Vector3}], ...]
## Joints missing from a key fall back to the current locomotion pose (_base),
## so actions blend in and out of whatever the legs/arms were doing.
func _keys(u: float, keys: Array) -> Dictionary:
	var a: Array = keys[0]
	var b: Array = keys[0]
	var k := 0.0
	if u <= keys[0][0]:
		k = 0.0
	elif u >= keys[keys.size() - 1][0]:
		a = keys[keys.size() - 1]
		b = a
	else:
		for i in range(keys.size() - 1):
			if u <= keys[i + 1][0]:
				a = keys[i]
				b = keys[i + 1]
				var x := clampf((u - a[0]) / maxf(b[0] - a[0], 0.0001), 0.0, 1.0)
				var mode: String = b[2] if b.size() > 2 else "smooth"
				match mode:
					"out":  # fast start, soft stop (strikes)
						k = 1.0 - pow(1.0 - x, 3.0)
					"in":   # slow start, fast end (wind-ups snapping)
						k = x * x * x
					"back": # overshoot then settle
						var c1 := 1.9
						k = 1.0 + (c1 + 1.0) * pow(x - 1.0, 3.0) + c1 * pow(x - 1.0, 2.0)
					_:
						k = _ease(x)
				break
	var pa: Dictionary = a[1]
	var pb: Dictionary = b[1]
	var out := {}
	for j in pa.keys():
		out[j] = true
	for j in pb.keys():
		out[j] = true
	for j in out.keys():
		var va: Vector3 = pa.get(j, _base.get(j, Vector3.ZERO))
		var vb: Vector3 = pb.get(j, _base.get(j, Vector3.ZERO))
		out[j] = va.lerp(vb, k)
	return out


# Combat guard pose for the arms (sword raised in front).
const GUARD := {
	"arm_r": Vector3(0.55, -0.25, 0.22), "fore_r": Vector3(0.45, 0, 0),
	"arm_l": Vector3(0.45, 0.25, -0.25), "fore_l": Vector3(1.25, 0, 0),
	"torso": Vector3(-0.08, 0.32, 0), "head": Vector3(0.05, -0.3, 0),
}
# Enemy swordsman poses (wind-up held as a readable tell, then the swing).
const E_LUNGE_L := {"leg_l": Vector3(0.85, 0, -0.1), "shin_l": Vector3(-0.8, 0, 0), "leg_r": Vector3(-0.65, 0, 0.1), "shin_r": Vector3(-0.3, 0, 0)}
const E_LUNGE_R := {"leg_l": Vector3(-0.55, 0, -0.1), "shin_l": Vector3(-0.35, 0, 0), "leg_r": Vector3(0.9, 0, 0.1), "shin_r": Vector3(-0.85, 0, 0)}
const E_WIND_R := {"arm_r": Vector3(1.0, 0.75, 1.85), "fore_r": Vector3(0.8, 0, 0), "torso": Vector3(0.08, 1.2, 0.1), "arm_l": Vector3(0.75, 0, -0.55), "fore_l": Vector3(1.2, 0, 0), "head": Vector3(0, -0.85, 0)}
const E_HIT_R := {"arm_r": Vector3(1.45, -0.9, -1.1), "fore_r": Vector3(0.0, 0, 0), "torso": Vector3(-0.3, -1.05, -0.1), "arm_l": Vector3(0.3, 0, -1.3), "fore_l": Vector3(0.4, 0, 0), "head": Vector3(-0.1, 0.8, 0)}
const E_WIND_L := {"arm_r": Vector3(1.35, -0.75, -1.05), "fore_r": Vector3(1.65, 0, 0), "torso": Vector3(0.0, -1.15, -0.1), "arm_l": Vector3(0.5, 0, -0.4), "fore_l": Vector3(1.4, 0, 0), "head": Vector3(0, 0.85, 0)}
const E_HIT_L := {"arm_r": Vector3(1.3, 0.8, 1.6), "fore_r": Vector3(0.05, 0, 0), "torso": Vector3(-0.25, 1.05, 0.1), "arm_l": Vector3(0.4, 0, -1.4), "fore_l": Vector3(0.3, 0, 0), "head": Vector3(-0.1, -0.8, 0)}
const E_COIL := {"arm_r": Vector3(0.15, 0.0, 0.5), "fore_r": Vector3(1.85, 0, 0), "hand_r": Vector3(-2.0, 0, 0),
	"arm_l": Vector3(1.0, 0.2, -0.35), "fore_l": Vector3(0.7, 0, 0), "torso": Vector3(0.05, -0.55, 0.05), "head": Vector3(0.05, 0.5, 0),
	"leg_r": Vector3(0.3, 0, 0.05), "shin_r": Vector3(-0.75, 0, 0), "leg_l": Vector3(-0.35, 0, -0.08), "shin_l": Vector3(-0.9, 0, 0)}
const E_REACH := {"arm_r": Vector3(1.5, 0.05, 0.12), "fore_r": Vector3(0.02, 0, 0), "hand_r": Vector3(-1.52, 0, 0),
	"arm_l": Vector3(-0.75, 0, -0.55), "fore_l": Vector3(0.35, 0, 0), "torso": Vector3(-0.32, 0.5, -0.05), "head": Vector3(0.3, -0.45, 0),
	"leg_r": Vector3(1.2, 0, 0.04), "shin_r": Vector3(-1.3, 0, 0), "leg_l": Vector3(-0.95, 0, -0.06), "shin_l": Vector3(-0.08, 0, 0)}
const E_BLOCK := {"arm_r": Vector3(1.35, -0.6, -0.15), "fore_r": Vector3(1.25, 0, 0), "hand_r": Vector3(0, 0, 1.2), "arm_l": Vector3(1.1, 0.5, -0.1), "fore_l": Vector3(1.6, 0, 0),
	"torso": Vector3(0.1, -0.35, 0), "head": Vector3(0.05, 0.3, 0), "leg_l": Vector3(0.35, 0, -0.12), "shin_l": Vector3(-0.5, 0, 0), "leg_r": Vector3(-0.35, 0, 0.12), "shin_r": Vector3(-0.3, 0, 0)}
# Bare-handed boxing guard (orthodox): hips and shoulders turned so the left
# side leads, lead fist out at chin height, rear fist tucked by the cheek,
# elbows down, chin tucked and eyes forward.
const FIST_GUARD := {
	"hips": Vector3(0, -0.5, 0), "torso": Vector3(-0.14, -0.12, 0), "head": Vector3(0.14, 0.58, 0),
	"arm_l": Vector3(1.15, 0.5, -0.12), "fore_l": Vector3(1.45, 0, 0),
	"arm_r": Vector3(0.75, 0.75, 0.12), "fore_r": Vector3(2.3, 0, 0),
}
const REST_ARMS := {"arm_r": Vector3(0, 0, 0.08), "fore_r": Vector3(0.15, 0, 0), "arm_l": Vector3(0, 0, -0.08), "fore_l": Vector3(0.15, 0, 0)}


## Returns [pose_dict, mask("upper"/"full"), extra_lift]
func _action_pose(n: String, u: float) -> Array:
	var lift := Vector3.ZERO
	match n:
		"draw":
			if u >= 0.45 and not _action["events"].has("hand"):
				_action["events"]["hand"] = true
				_attach_weapon(true)
			return [_keys(u, [
				[0.0, REST_ARMS],
				[0.45, {"arm_r": Vector3(0.55, 0.0, -0.75), "fore_r": Vector3(1.35, 0, 0), "torso": Vector3(-0.05, 0.4, 0)}],
				[1.0, GUARD]]), "upper", lift]
		"sheathe":
			if u >= 0.55 and not _action["events"].has("hip"):
				_action["events"]["hip"] = true
				_attach_weapon(false)
			return [_keys(u, [
				[0.0, GUARD],
				[0.55, {"arm_r": Vector3(0.55, 0.0, -0.75), "fore_r": Vector3(1.35, 0, 0), "torso": Vector3(-0.05, 0.4, 0), "arm_l": Vector3(0, 0, -0.1), "fore_l": Vector3(0.2, 0, 0)}],
				[1.0, REST_ARMS]]), "upper", lift]
		"slash_r":
			# combo 1: big wind-up to the right, whip across to the left
			var lunge := {"leg_l": Vector3(0.85, 0, -0.1), "shin_l": Vector3(-0.8, 0, 0), "leg_r": Vector3(-0.65, 0, 0.1), "shin_r": Vector3(-0.3, 0, 0)}
			var wind := {"arm_r": Vector3(0.9, 0.7, 1.7), "fore_r": Vector3(0.7, 0, 0), "torso": Vector3(0.05, 1.15, 0.1), "arm_l": Vector3(0.7, 0, -0.5), "fore_l": Vector3(1.2, 0, 0), "head": Vector3(0, -0.8, 0)}
			var hit := {"arm_r": Vector3(1.45, -0.9, -1.1), "fore_r": Vector3(0.0, 0, 0), "torso": Vector3(-0.3, -1.05, -0.1), "arm_l": Vector3(0.3, 0, -1.3), "fore_l": Vector3(0.4, 0, 0), "head": Vector3(-0.1, 0.8, 0)}
			lift = Vector3(0, -0.16 * sin(clampf(u * 1.4, 0.0, 1.0) * PI), 0)
			return [_keys(u, [[0.0, GUARD], [0.18, wind.merged(lunge), "out"], [0.26, wind.merged(lunge)], [0.42, hit.merged(lunge), "out"], [0.62, hit.merged(lunge)], [1.0, GUARD]]), "full", lift]
		"slash_l":
			# combo 2: backhand left-to-right, stepping through with the other foot
			var lunge2 := {"leg_l": Vector3(-0.55, 0, -0.1), "shin_l": Vector3(-0.35, 0, 0), "leg_r": Vector3(0.9, 0, 0.1), "shin_r": Vector3(-0.85, 0, 0)}
			var wind2 := {"arm_r": Vector3(1.35, -0.7, -1.0), "fore_r": Vector3(1.6, 0, 0), "torso": Vector3(0.0, -1.1, -0.1), "arm_l": Vector3(0.5, 0, -0.4), "fore_l": Vector3(1.4, 0, 0), "head": Vector3(0, 0.8, 0)}
			var hit2 := {"arm_r": Vector3(1.3, 0.8, 1.6), "fore_r": Vector3(0.05, 0, 0), "torso": Vector3(-0.25, 1.05, 0.1), "arm_l": Vector3(0.4, 0, -1.4), "fore_l": Vector3(0.3, 0, 0), "head": Vector3(-0.1, -0.8, 0)}
			lift = Vector3(0, -0.16 * sin(clampf(u * 1.4, 0.0, 1.0) * PI), 0)
			return [_keys(u, [[0.0, GUARD], [0.16, wind2.merged(lunge2), "out"], [0.24, wind2.merged(lunge2)], [0.4, hit2.merged(lunge2), "out"], [0.6, hit2.merged(lunge2)], [1.0, GUARD]]), "full", lift]
		"spin_slash":
			# combo 3 finisher: hop and spin 360 with the blade held out wide
			var out_arm := {"arm_r": Vector3(1.35, 0.0, 1.55), "fore_r": Vector3(0.05, 0, 0), "arm_l": Vector3(0.6, 0, -1.4), "fore_l": Vector3(0.6, 0, 0),
				"torso": Vector3(-0.25, 0.0, 0.15), "head": Vector3(0.1, 0, 0),
				"leg_l": Vector3(0.6, 0, -0.2), "shin_l": Vector3(-0.9, 0, 0), "leg_r": Vector3(-0.2, 0, 0.2), "shin_r": Vector3(-0.6, 0, 0)}
			var crouch := {"leg_l": Vector3(0.7, 0, -0.15), "shin_l": Vector3(-1.1, 0, 0), "leg_r": Vector3(-0.5, 0, 0.15), "shin_r": Vector3(-0.7, 0, 0),
				"arm_r": Vector3(0.8, 0.6, 1.4), "fore_r": Vector3(0.8, 0, 0), "torso": Vector3(-0.1, 0.9, 0)}
			var spin := clampf((u - 0.18) / 0.5, 0.0, 1.0)
			spin = 1.0 - pow(1.0 - spin, 2.5)
			var pose := _keys(u, [[0.0, GUARD], [0.16, crouch, "out"], [0.3, out_arm, "out"], [0.72, out_arm], [1.0, GUARD]])
			pose["pivot"] = Vector3(0, -TAU * spin, 0)
			var hop := sin(clampf((u - 0.18) / 0.5, 0.0, 1.0) * PI)
			var dip := 1.0 - clampf(absf(u - 0.12) / 0.12, 0.0, 1.0)
			lift = Vector3(0, -0.2 * dip + 0.32 * hop, 0)
			return [pose, "full", lift]
		"slash_down":
			var legs3 := {"leg_l": Vector3(0.75, 0, -0.08), "shin_l": Vector3(-0.7, 0, 0), "leg_r": Vector3(-0.6, 0, 0.08), "shin_r": Vector3(-0.35, 0, 0)}
			var up := {"arm_r": Vector3(3.1, 0, 0.25), "fore_r": Vector3(0.9, 0, 0), "arm_l": Vector3(2.8, 0, -0.25), "fore_l": Vector3(1.1, 0, 0), "torso": Vector3(0.35, 0.1, 0), "head": Vector3(0.25, 0, 0)}
			var down := {"arm_r": Vector3(0.5, 0, 0.1), "fore_r": Vector3(-0.1, 0, 0), "arm_l": Vector3(0.7, 0, -0.1), "fore_l": Vector3(0.3, 0, 0), "torso": Vector3(-0.65, 0, 0), "head": Vector3(-0.3, 0, 0)}
			lift.y = -0.18 * _ease(u * 2.0)
			return [_keys(u, [[0.0, GUARD], [0.22, up.merged(legs3), "out"], [0.3, up.merged(legs3)], [0.48, down.merged(legs3), "out"], [0.65, down.merged(legs3)], [1.0, GUARD]]), "full", lift]
		"heavy":
			# windup 0..0.375, slam 0.375..0.625, recovery ..1 (matches 0.3/0.2/0.3 s)
			# crouch + raise, hop up, crash down into a deep lunge
			var coil := {"leg_l": Vector3(0.6, 0, -0.15), "shin_l": Vector3(-1.2, 0, 0), "leg_r": Vector3(0.3, 0, 0.15), "shin_r": Vector3(-1.1, 0, 0)}
			var raise := {"arm_r": Vector3(3.2, 0.2, 0.3), "fore_r": Vector3(1.3, 0, 0), "arm_l": Vector3(3.0, -0.2, -0.3), "fore_l": Vector3(1.4, 0, 0), "torso": Vector3(0.45, 0.3, 0), "head": Vector3(0.35, -0.2, 0)}
			var air := {"leg_l": Vector3(1.0, 0, -0.1), "shin_l": Vector3(-1.4, 0, 0), "leg_r": Vector3(0.2, 0, 0.1), "shin_r": Vector3(-0.9, 0, 0)}
			var slam := {"arm_r": Vector3(0.35, 0, 0.05), "fore_r": Vector3(-0.1, 0, 0), "arm_l": Vector3(0.45, 0, -0.05), "fore_l": Vector3(0.1, 0, 0), "torso": Vector3(-0.85, 0, 0), "head": Vector3(-0.35, 0, 0)}
			var lunge3 := {"leg_l": Vector3(1.1, 0, -0.1), "shin_l": Vector3(-1.2, 0, 0), "leg_r": Vector3(-0.85, 0, 0.1), "shin_r": Vector3(-0.15, 0, 0)}
			if u < 0.3:
				lift.y = -0.25 * _ease(u / 0.3)
			elif u < 0.45:
				lift.y = lerpf(-0.25, 0.45, _ease((u - 0.3) / 0.15))
			elif u < 0.52:
				lift.y = lerpf(0.45, -0.38, (u - 0.45) / 0.07)
			else:
				lift.y = -0.38 * (1.0 - _ease((u - 0.6) / 0.4)) if u > 0.6 else -0.38
			return [_keys(u, [[0.0, GUARD], [0.28, raise.merged(coil), "out"], [0.42, raise.merged(air)], [0.52, slam.merged(lunge3), "in"], [0.72, slam.merged(lunge3)], [1.0, GUARD]]), "full", lift]
		"thrust":
			# cutlass heavy: coil back, then a long fencing lunge with the blade
			# lined up along the arm. windup ..0.29, strike ..0.51, recovery.
			var coil := {"arm_r": Vector3(0.15, 0.0, 0.5), "fore_r": Vector3(1.85, 0, 0), "hand_r": Vector3(-2.0, 0, 0),
				"arm_l": Vector3(1.0, 0.2, -0.35), "fore_l": Vector3(0.7, 0, 0),
				"torso": Vector3(0.05, -0.55, 0.05), "head": Vector3(0.05, 0.5, 0),
				"leg_r": Vector3(0.3, 0, 0.05), "shin_r": Vector3(-0.55, 0, 0), "leg_l": Vector3(-0.35, 0, -0.08), "shin_l": Vector3(-0.7, 0, 0)}
			var reach := {"arm_r": Vector3(1.5, 0.05, 0.12), "fore_r": Vector3(0.02, 0, 0), "hand_r": Vector3(-1.52, 0, 0),
				"arm_l": Vector3(-0.75, 0, -0.55), "fore_l": Vector3(0.35, 0, 0),
				"torso": Vector3(-0.32, 0.5, -0.05), "head": Vector3(0.3, -0.45, 0),
				"leg_r": Vector3(1.2, 0, 0.04), "shin_r": Vector3(-1.3, 0, 0), "leg_l": Vector3(-0.95, 0, -0.06), "shin_l": Vector3(-0.08, 0, 0)}
			if u < 0.27:
				lift.y = -0.14 * _ease(u / 0.27)
			elif u < 0.4:
				lift.y = lerpf(-0.14, -0.32, 1.0 - pow(1.0 - (u - 0.27) / 0.13, 3.0))
			else:
				lift.y = -0.32 * (1.0 - _ease(clampf((u - 0.58) / 0.42, 0.0, 1.0)))
			return [_keys(u, [[0.0, GUARD], [0.27, coil, "out"], [0.31, coil], [0.4, reach, "out"], [0.58, reach], [1.0, GUARD]]), "full", lift]
		"axe_heavy":
			# axe heavy: one-handed overhead chop. Rear back with the axe cocked
			# behind the head, then hack down through a forward step.
			# windup ..0.38, strike ..0.53, recovery.
			var cock := {"arm_r": Vector3(2.95, -0.1, 0.35), "fore_r": Vector3(1.45, 0, 0), "hand_r": Vector3(0.2, 0, 0),
				"arm_l": Vector3(1.25, 0.1, -0.55), "fore_l": Vector3(0.45, 0, 0),
				"torso": Vector3(0.32, -0.3, 0.05), "head": Vector3(0.12, 0.25, 0),
				"leg_l": Vector3(0.45, 0, -0.08), "shin_l": Vector3(-0.35, 0, 0), "leg_r": Vector3(-0.25, 0, 0.08), "shin_r": Vector3(-0.45, 0, 0)}
			var chop := {"arm_r": Vector3(0.55, 0.0, 0.12), "fore_r": Vector3(0.05, 0, 0), "hand_r": Vector3(-0.65, 0, 0),
				"arm_l": Vector3(-0.35, 0, -0.75), "fore_l": Vector3(0.5, 0, 0),
				"torso": Vector3(-0.62, 0.32, 0.0), "head": Vector3(0.22, -0.25, 0),
				"leg_l": Vector3(0.95, 0, -0.1), "shin_l": Vector3(-1.1, 0, 0), "leg_r": Vector3(-0.6, 0, 0.1), "shin_r": Vector3(-0.3, 0, 0)}
			if u < 0.36:
				lift.y = 0.05 * _ease(u / 0.36)
			elif u < 0.47:
				lift.y = lerpf(0.05, -0.34, pow((u - 0.36) / 0.11, 2.0))
			else:
				lift.y = -0.34 * (1.0 - _ease(clampf((u - 0.62) / 0.38, 0.0, 1.0)))
			return [_keys(u, [[0.0, GUARD], [0.34, cock, "out"], [0.38, cock], [0.47, chop, "in"], [0.62, chop], [1.0, GUARD]]), "full", lift]
		"roll":
			var tuck := {"leg_l": Vector3(1.7, 0, 0), "shin_l": Vector3(-2.2, 0, 0), "leg_r": Vector3(1.5, 0, 0), "shin_r": Vector3(-2.1, 0, 0),
				"arm_l": Vector3(1.2, 0, -0.3), "fore_l": Vector3(1.6, 0, 0), "arm_r": Vector3(1.2, 0, 0.3), "fore_r": Vector3(1.6, 0, 0),
				"torso": Vector3(-0.7, 0, 0), "head": Vector3(-0.5, 0, 0)}
			var k := _ease(u)
			var spin := -TAU * clampf((u - 0.08) / 0.8, 0.0, 1.0)
			var tw := sin(clampf(u, 0, 1) * PI)
			var pose := {}
			for j in tuck.keys():
				pose[j] = (tuck[j] as Vector3) * tw
			pose["pivot"] = Vector3(spin, 0, 0)
			lift.y = -0.45 * tw
			return [pose, "full", lift]
		"dash":
			# Sidestep / dash: low crouch, whole body leans into the move, lead
			# leg reaches, trailing leg pushes off, arms swing out for balance.
			var d := dash_dir.normalized() if dash_dir.length() > 0.1 else Vector2(0, -1)
			var sx := signf(d.x) if absf(d.x) > 0.01 else 1.0
			var wx := absf(d.x)
			var wf := maxf(d.y, 0.0)
			var wb := maxf(-d.y, 0.0)
			var lead := "r" if sx > 0.0 else "l"
			var trail := "l" if sx > 0.0 else "r"
			var p := {}
			for j in ["leg_l", "shin_l", "leg_r", "shin_r", "arm_l", "fore_l", "arm_r", "fore_r", "torso", "head", "pivot"]:
				p[j] = Vector3.ZERO
			# sideways: lead leg out, trail leg pushing, lean into the dash
			p["leg_" + lead] += Vector3(0.25, 0, 0.75 * sx) * wx
			p["shin_" + lead] += Vector3(-0.7, 0, 0) * wx
			p["leg_" + trail] += Vector3(-0.1, 0, -0.35 * sx) * wx  # planted foot splays away from the dash
			p["shin_" + trail] += Vector3(-0.2, 0, 0) * wx
			p["arm_" + trail] += Vector3(0.3, 0, -1.1 * sx) * wx  # flung out on its own side
			p["fore_" + trail] += Vector3(0.5, 0, 0) * wx
			p["arm_" + lead] += Vector3(0.6, 0, 0.25 * -sx) * wx
			p["fore_" + lead] += Vector3(1.3, 0, 0) * wx
			p["torso"] += Vector3(-0.15, 0.25 * sx, 0.1 * sx) * wx
			p["head"] += Vector3(0.05, 0, 0.18 * sx) * wx
			p["pivot"] += Vector3(0, 0, -0.32 * sx) * wx
			# forward dash: low lunge, arms swept back
			p["leg_r"] += Vector3(0.95, 0, 0) * wf
			p["shin_r"] += Vector3(-1.0, 0, 0) * wf
			p["leg_l"] += Vector3(-0.55, 0, 0) * wf
			p["shin_l"] += Vector3(-0.3, 0, 0) * wf
			p["arm_l"] += Vector3(-0.9, 0, -0.35) * wf
			p["arm_r"] += Vector3(-0.9, 0, 0.35) * wf
			p["fore_l"] += Vector3(0.3, 0, 0) * wf
			p["fore_r"] += Vector3(0.3, 0, 0) * wf
			p["torso"] += Vector3(-0.25, 0, 0) * wf
			p["head"] += Vector3(0.2, 0, 0) * wf
			p["pivot"] += Vector3(-0.3, 0, 0) * wf
			# backstep: one leg reaches back, lean back, arms forward
			p["leg_l"] += Vector3(-0.75, 0, -0.05) * wb
			p["shin_l"] += Vector3(-0.35, 0, 0) * wb
			p["leg_r"] += Vector3(0.45, 0, 0.05) * wb
			p["shin_r"] += Vector3(-0.9, 0, 0) * wb
			p["arm_l"] += Vector3(0.7, 0, -0.45) * wb
			p["arm_r"] += Vector3(0.7, 0, 0.45) * wb
			p["fore_l"] += Vector3(0.8, 0, 0) * wb
			p["fore_r"] += Vector3(0.8, 0, 0) * wb
			p["torso"] += Vector3(0.1, 0, 0) * wb
			p["pivot"] += Vector3(0.22, 0, 0) * wb
			if armed:
				p["arm_r"] = _guard()["arm_r"] + Vector3(0.0, 0.0, 0.15 * sx * wx)
				p["fore_r"] = _guard()["fore_r"]
				# the free (off) hand opens out for balance: reaching ahead when
				# dashing forward or to the left, flung out to the side otherwise
				var reach := clampf(wf + (wx if sx < 0.0 else 0.0), 0.0, 1.0)
				var fling := clampf(wb + (wx if sx > 0.0 else 0.0), 0.0, 1.0)
				p["arm_l"] = Vector3(1.2, 0.0, -0.95) * reach + Vector3(0.35, 0.0, -1.35) * fling
				p["fore_l"] = Vector3(0.1, 0, 0) * reach + Vector3(0.3, 0, 0) * fling
				if reach + fling < 0.2:
					p["arm_l"] = Vector3(0.9, 0.1, -1.0)
					p["fore_l"] = Vector3(0.25, 0, 0)
			else:
				# unarmed: lead arm reaches straight out in front
				var inward := -0.15 if lead == "r" else 0.15
				p["arm_" + lead] = Vector3(1.5, 0.0, inward)
				p["fore_" + lead] = Vector3(0.15, 0.0, 0.0)
			var env := 0.0
			if u < 0.14:
				env = 1.0 - pow(1.0 - u / 0.14, 3.0)
			elif u < 0.55:
				env = 1.0
			else:
				env = 1.0 - _ease((u - 0.55) / 0.45)
			var pose := {}
			for j in p.keys():
				pose[j] = (p[j] as Vector3) * env
			lift.y = -0.24 * env
			return [pose, "full", lift]
		"flip":
			var tuck2 := {"leg_l": Vector3(1.6, 0, 0), "shin_l": Vector3(-2.0, 0, 0), "leg_r": Vector3(1.6, 0, 0), "shin_r": Vector3(-2.0, 0, 0),
				"arm_l": Vector3(1.0, 0, -0.4), "fore_l": Vector3(1.4, 0, 0), "arm_r": Vector3(1.0, 0, 0.4), "fore_r": Vector3(1.4, 0, 0), "torso": Vector3(-0.5, 0, 0)}
			var tw2 := sin(clampf(u, 0, 1) * PI)
			var pose2 := {}
			for j in tuck2.keys():
				pose2[j] = (tuck2[j] as Vector3) * tw2
			pose2["pivot"] = Vector3(-TAU * _ease(u), 0, 0)
			return [pose2, "full", lift]
		"parry":
			var block := {"arm_r": Vector3(1.35, -0.6, -0.15), "fore_r": Vector3(1.25, 0, 0), "arm_l": Vector3(1.1, 0.5, -0.1), "fore_l": Vector3(1.6, 0, 0), "torso": Vector3(-0.05, -0.35, 0), "head": Vector3(0, 0.3, 0)}
			var crouch := {"leg_l": Vector3(0.35, 0, -0.1), "shin_l": Vector3(-0.45, 0, 0), "leg_r": Vector3(-0.25, 0, 0.1), "shin_r": Vector3(-0.35, 0, 0)}
			lift.y = -0.1 * sin(clampf(u, 0, 1) * PI)
			return [_keys(u, [[0.0, GUARD.merged(crouch)], [0.12, block.merged(crouch)], [0.6, block.merged(crouch)], [1.0, GUARD.merged(crouch)]]), "full", lift]
		"stagger":
			var reel := {"torso": Vector3(0.45, 0.2, 0.1), "head": Vector3(0.35, 0, 0), "arm_l": Vector3(0.4, 0, -1.1), "fore_l": Vector3(0.5, 0, 0),
				"arm_r": Vector3(0.6, 0, 1.0), "fore_r": Vector3(0.6, 0, 0), "leg_l": Vector3(-0.35, 0, 0), "shin_l": Vector3(-0.3, 0, 0), "leg_r": Vector3(0.2, 0, 0), "shin_r": Vector3(-0.5, 0, 0)}
			lift.y = -0.1 * sin(clampf(u, 0, 1) * PI)
			return [_keys(u, [[0.0, {}], [0.15, reel], [0.6, reel], [1.0, {}]]), "full", lift]
		"getup":
			return _getup_pose(u)
		# --- enemy swordsman: held wind-ups (the tell) and fast swings ---
		"wind_r", "wind_l":
			var w: Dictionary = (E_WIND_R if n == "wind_r" else E_WIND_L).merged(E_LUNGE_L if n == "wind_r" else E_LUNGE_R)
			var tremble := sin(_t * 38.0) * 0.03 * _ease((u - 0.5) * 2.0)
			var held := w.duplicate()
			held["arm_r"] = (w["arm_r"] as Vector3) + Vector3(tremble, 0, tremble)
			lift.y = -0.08 * _ease(u * 2.0)
			return [_keys(u, [[0.0, GUARD], [0.45, w, "out"], [1.0, held]]), "full", lift]
		"swing_r", "swing_l":
			var w2: Dictionary = (E_WIND_R if n == "swing_r" else E_WIND_L).merged(E_LUNGE_L if n == "swing_r" else E_LUNGE_R)
			var h2: Dictionary = (E_HIT_R if n == "swing_r" else E_HIT_L).merged(E_LUNGE_L if n == "swing_r" else E_LUNGE_R)
			lift.y = -0.12 * (1.0 - _ease((u - 0.4) / 0.6))
			return [_keys(u, [[0.0, w2], [0.3, h2, "out"], [0.6, h2], [1.0, GUARD]]), "full", lift]
		"lunge_wind":
			lift.y = -0.16 * _ease(u * 2.0)
			var coil2 := E_COIL.duplicate()
			coil2["arm_r"] = (E_COIL["arm_r"] as Vector3) + Vector3(sin(_t * 38.0) * 0.03 * _ease((u - 0.5) * 2.0), 0, 0)
			return [_keys(u, [[0.0, GUARD], [0.5, E_COIL, "out"], [1.0, coil2]]), "full", lift]
		"lunge":
			lift.y = lerpf(-0.16, -0.3, _ease(u * 3.0)) * (1.0 - _ease((u - 0.6) / 0.4))
			return [_keys(u, [[0.0, E_COIL], [0.22, E_REACH, "out"], [0.6, E_REACH], [1.0, GUARD]]), "full", lift]
		"block":
			lift.y = -0.08 * sin(clampf(u, 0, 1) * PI)
			return [_keys(u, [[0.0, GUARD], [0.15, E_BLOCK, "out"], [0.7, E_BLOCK], [1.0, GUARD]]), "full", lift]
		# --- jumping attack: sword raised, knees tucked, then the plunge ---
		"plunge_air":
			var up := {"arm_r": Vector3(3.0, 0, 0.25), "fore_r": Vector3(1.0, 0, 0), "hand_r": Vector3(0.3, 0, 0),
				"arm_l": Vector3(2.6, 0, -0.45), "fore_l": Vector3(1.2, 0, 0), "torso": Vector3(0.3, 0, 0), "head": Vector3(0.1, 0, 0),
				"leg_l": Vector3(1.4, 0, -0.1), "shin_l": Vector3(-1.9, 0, 0), "leg_r": Vector3(1.1, 0, 0.1), "shin_r": Vector3(-1.7, 0, 0)}
			var dive := {"arm_r": Vector3(0.35, 0, 0.1), "fore_r": Vector3(-0.1, 0, 0), "hand_r": Vector3(-0.9, 0, 0),
				"arm_l": Vector3(0.2, 0, -1.2), "fore_l": Vector3(0.3, 0, 0), "torso": Vector3(-0.6, 0, 0), "head": Vector3(-0.2, 0, 0),
				"leg_l": Vector3(0.7, 0, -0.1), "shin_l": Vector3(-0.9, 0, 0), "leg_r": Vector3(0.2, 0, 0.1), "shin_r": Vector3(-0.6, 0, 0)}
			return [_keys(u, [[0.0, {}], [0.3, up, "out"], [0.45, up], [0.6, dive, "in"], [1.0, dive]]), "full", lift]
		"plunge_land":
			var hit := {"arm_r": Vector3(0.35, 0, 0.1), "fore_r": Vector3(-0.1, 0, 0), "hand_r": Vector3(-0.9, 0, 0),
				"arm_l": Vector3(0.2, 0, -1.2), "fore_l": Vector3(0.3, 0, 0), "torso": Vector3(-0.75, 0, 0), "head": Vector3(-0.15, 0, 0),
				"leg_l": Vector3(1.4, 0, -0.15), "shin_l": Vector3(-1.9, 0, 0), "leg_r": Vector3(-0.4, 0, 0.15), "shin_r": Vector3(-1.2, 0, 0)}
			lift.y = -0.42 * (1.0 - _ease((u - 0.35) / 0.65))
			return [_keys(u, [[0.0, hit], [0.35, hit], [1.0, GUARD]]), "full", lift]
		# --- firearms (the grunt points the gun itself; these pose the body) ---
		"aim_pistol":
			var ap := aim_pitch
			var aim := {"torso": Vector3(ap * 0.3, -0.45, 0), "head": Vector3(-ap * 0.2, 0.4, 0),
				"arm_r": Vector3(1.5 + ap, 0.45, 0.05), "fore_r": Vector3(0.05, 0, 0), "hand_r": Vector3(-1.55, 0, 0),
				"arm_l": Vector3(-0.15, 0, -0.5), "fore_l": Vector3(1.3, 0, 0)}
			var kick := aim.duplicate()
			kick["arm_r"] = (aim["arm_r"] as Vector3) + Vector3(0.6, 0, 0)
			if u < 0.85:
				return [_keys(u, [[0.0, {}], [0.2, aim, "out"], [0.85, aim]]), "upper", lift]
			return [_keys(u, [[0.85, aim], [0.9, kick, "out"], [1.0, aim]]), "upper", lift]
		"aim_rifle":
			var ap2 := aim_pitch
			var aim2 := {"torso": Vector3(ap2 * 0.3, -0.4, 0), "head": Vector3(0.15 - ap2 * 0.2, 0.35, 0.1),
				"arm_r": Vector3(0.75 + ap2, 0.65, 0.4), "fore_r": Vector3(1.65, 0, 0), "hand_r": Vector3(-2.4, 0, 0),
				"arm_l": Vector3(1.45 + ap2, -0.1, 0.05), "fore_l": Vector3(0.25, 0, 0),
				"leg_l": Vector3(0.3, 0, -0.12), "shin_l": Vector3(-0.25, 0, 0), "leg_r": Vector3(-0.25, 0, 0.12), "shin_r": Vector3(-0.15, 0, 0)}
			var kick2 := aim2.duplicate()
			kick2["torso"] = (aim2["torso"] as Vector3) + Vector3(0.25, 0, 0)
			kick2["head"] = (aim2["head"] as Vector3) + Vector3(0.2, 0, 0)
			if u < 0.85:
				return [_keys(u, [[0.0, {}], [0.2, aim2, "out"], [0.85, aim2]]), "full", lift]
			return [_keys(u, [[0.85, aim2], [0.9, kick2, "out"], [1.0, aim2]]), "full", lift]
		"shove":
			# rifle butt: pull back, then drive it forward into whoever's too close
			var cock := {"torso": Vector3(0.1, 0.5, 0), "arm_r": Vector3(0.2, 0.3, 0.3), "fore_r": Vector3(1.6, 0, 0),
				"arm_l": Vector3(0.6, 0.4, -0.2), "fore_l": Vector3(1.5, 0, 0), "leg_l": Vector3(0.4, 0, -0.1), "shin_l": Vector3(-0.4, 0, 0),
				"leg_r": Vector3(-0.35, 0, 0.1), "shin_r": Vector3(-0.3, 0, 0)}
			var ram := {"torso": Vector3(-0.35, -0.35, 0), "arm_r": Vector3(1.2, -0.2, 0.2), "fore_r": Vector3(0.6, 0, 0),
				"arm_l": Vector3(1.35, 0.2, -0.1), "fore_l": Vector3(0.4, 0, 0), "leg_l": Vector3(0.85, 0, -0.1), "shin_l": Vector3(-0.8, 0, 0),
				"leg_r": Vector3(-0.6, 0, 0.1), "shin_r": Vector3(-0.2, 0, 0)}
			lift.y = -0.12 * sin(clampf(u, 0, 1) * PI)
			return [_keys(u, [[0.0, {}], [0.45, cock, "out"], [0.6, ram, "out"], [0.8, ram], [1.0, {}]]), "full", lift]
		"mantle":
			# hands on the edge, haul up, knee onto the ledge, stand
			var hang := {"pivot": Vector3.ZERO, "torso": Vector3(-0.2, 0, 0), "head": Vector3(0.35, 0, 0),
				"arm_l": Vector3(2.7, 0, -0.2), "fore_l": Vector3(0.7, 0, 0), "arm_r": Vector3(2.7, 0, 0.2), "fore_r": Vector3(0.7, 0, 0),
				"leg_l": Vector3(0.3, 0, -0.05), "shin_l": Vector3(-0.5, 0, 0), "leg_r": Vector3(0.1, 0, 0.05), "shin_r": Vector3(-0.3, 0, 0)}
			var push := {"pivot": Vector3.ZERO, "torso": Vector3(-0.75, 0, 0), "head": Vector3(0.4, 0, 0),
				"arm_l": Vector3(0.1, 0, -0.25), "fore_l": Vector3(0.25, 0, 0), "arm_r": Vector3(0.1, 0, 0.25), "fore_r": Vector3(0.25, 0, 0),
				"leg_l": Vector3(1.7, 0, -0.1), "shin_l": Vector3(-2.2, 0, 0), "leg_r": Vector3(-0.3, 0, 0.05), "shin_r": Vector3(-0.6, 0, 0)}
			lift.y = -0.15 * sin(clampf(u, 0.0, 1.0) * PI)
			return [_keys(u, [[0.0, hang], [0.25, hang], [0.62, push, "out"], [1.0, {}]]), "full", lift]
		# --- Devil Fruit powers ---
		"fire_punch":
			var wind := {"arm_r": Vector3(-0.5, 0.2, 0.35), "fore_r": Vector3(1.9, 0, 0), "torso": Vector3(0.0, 0.55, 0), "head": Vector3(0, -0.45, 0),
				"arm_l": Vector3(1.2, -0.3, -0.2), "fore_l": Vector3(0.6, 0, 0),
				"leg_l": Vector3(0.45, 0, -0.12), "shin_l": Vector3(-0.5, 0, 0), "leg_r": Vector3(-0.35, 0, 0.12), "shin_r": Vector3(-0.35, 0, 0)}
			var punch := {"arm_r": Vector3(1.55, -0.15, 0.05), "fore_r": Vector3(0.05, 0, 0), "torso": Vector3(-0.2, -0.5, 0), "head": Vector3(0.1, 0.45, 0),
				"arm_l": Vector3(-0.45, 0.2, -0.3), "fore_l": Vector3(1.5, 0, 0),
				"leg_l": Vector3(0.7, 0, -0.12), "shin_l": Vector3(-0.6, 0, 0), "leg_r": Vector3(-0.55, 0, 0.12), "shin_r": Vector3(-0.25, 0, 0)}
			lift.y = -0.08 * sin(clampf(u, 0, 1) * PI)
			return [_keys(u, [[0.0, {}], [0.25, wind, "out"], [0.4, punch, "out"], [0.75, punch], [1.0, {}]]), "full", lift]
		"flame_dash":
			var streak := {"pivot": Vector3(-0.35, 0, 0), "torso": Vector3(-0.4, 0, 0), "head": Vector3(0.45, 0, 0),
				"arm_l": Vector3(-1.0, 0, -0.35), "fore_l": Vector3(0.3, 0, 0), "arm_r": Vector3(-1.0, 0, 0.35), "fore_r": Vector3(0.3, 0, 0),
				"leg_l": Vector3(0.9, 0, -0.08), "shin_l": Vector3(-1.4, 0, 0), "leg_r": Vector3(-0.4, 0, 0.08), "shin_r": Vector3(-0.7, 0, 0)}
			return [_keys(u, [[0.0, {}], [0.12, streak, "out"], [0.62, streak], [1.0, {}]]), "full", lift]
		"fire_ring":
			var gather := {"torso": Vector3(-0.45, 0, 0), "head": Vector3(0.2, 0, 0),
				"arm_l": Vector3(1.1, -0.6, 0.35), "fore_l": Vector3(1.9, 0, 0), "arm_r": Vector3(1.1, 0.6, -0.35), "fore_r": Vector3(1.9, 0, 0),
				"leg_l": Vector3(0.6, 0, -0.2), "shin_l": Vector3(-1.1, 0, 0), "leg_r": Vector3(0.6, 0, 0.2), "shin_r": Vector3(-1.1, 0, 0)}
			var burst := {"torso": Vector3(0.22, 0, 0), "head": Vector3(0.3, 0, 0),
				"arm_l": Vector3(0.25, 0, -1.55), "fore_l": Vector3(0.15, 0, 0), "arm_r": Vector3(0.25, 0, 1.55), "fore_r": Vector3(0.15, 0, 0),
				"leg_l": Vector3(0.15, 0, -0.38), "shin_l": Vector3(-0.3, 0, 0), "leg_r": Vector3(0.15, 0, 0.38), "shin_r": Vector3(-0.3, 0, 0)}
			lift.y = -0.22 * _ease(u / 0.35) * (1.0 - _ease((u - 0.38) / 0.12))
			return [_keys(u, [[0.0, {}], [0.35, gather, "out"], [0.45, burst, "out"], [0.8, burst], [1.0, {}]]), "full", lift]
		"fire_plant":
			var plant := {"torso": Vector3(-0.55, 0, 0), "head": Vector3(0.35, 0, 0),
				"arm_l": Vector3(0.95, 0, -0.25), "fore_l": Vector3(0.2, 0, 0), "arm_r": Vector3(0.95, 0, 0.25), "fore_r": Vector3(0.2, 0, 0),
				"hand_r": Vector3(-0.6, 0, 0),
				"leg_l": Vector3(0.95, 0, -0.15), "shin_l": Vector3(-1.4, 0, 0), "leg_r": Vector3(-0.2, 0, 0.15), "shin_r": Vector3(-0.9, 0, 0)}
			lift.y = -0.25 * _ease(u / 0.45) * (1.0 - _ease((u - 0.8) / 0.2))
			return [_keys(u, [[0.0, {}], [0.45, plant, "out"], [0.8, plant], [1.0, {}]]), "full", lift]
		"inferno":
			var up := {"torso": Vector3(0.2, 0, 0), "head": Vector3(0.35, 0, 0),
				"arm_l": Vector3(2.9, 0, -0.3), "fore_l": Vector3(0.4, 0, 0), "arm_r": Vector3(2.9, 0, 0.3), "fore_r": Vector3(0.4, 0, 0),
				"leg_l": Vector3(1.3, 0, -0.1), "shin_l": Vector3(-1.8, 0, 0), "leg_r": Vector3(1.0, 0, 0.1), "shin_r": Vector3(-1.6, 0, 0)}
			var slam := {"torso": Vector3(-0.8, 0, 0), "head": Vector3(-0.1, 0, 0),
				"arm_l": Vector3(0.45, 0, -0.15), "fore_l": Vector3(0.1, 0, 0), "arm_r": Vector3(0.45, 0, 0.15), "fore_r": Vector3(0.1, 0, 0),
				"leg_l": Vector3(1.45, 0, -0.25), "shin_l": Vector3(-2.0, 0, 0), "leg_r": Vector3(-0.3, 0, 0.25), "shin_r": Vector3(-1.4, 0, 0)}
			lift.y = -0.4 * _ease((u - 0.36) / 0.12) * (1.0 - _ease((u - 0.72) / 0.28))
			return [_keys(u, [[0.0, {}], [0.12, up, "out"], [0.36, up], [0.46, slam, "in"], [0.72, slam], [1.0, {}]]), "full", lift]
		"eat":
			var bite := {"arm_l": Vector3(1.85, 0.6, 0.35), "fore_l": Vector3(2.35, 0, 0), "head": Vector3(-0.1, 0, 0), "torso": Vector3(-0.08, 0, 0)}
			var chew := bite.duplicate()
			chew["head"] = Vector3(0.05 + sin(_t * 18.0) * 0.06, 0, 0)
			return [_keys(u, [[0.0, {}], [0.2, bite], [0.4, chew], [0.8, chew], [1.0, {}]]), "upper", lift]
		# --- holding a block (player) ---
		"guard_block", "guard_block_hit":
			var bp := _block_pose()
			if n == "guard_block_hit":
				var rock := bp.duplicate()
				rock["torso"] = (bp["torso"] as Vector3) + Vector3(0.22, 0, 0)
				rock["head"] = (bp["head"] as Vector3) + Vector3(-0.15, 0, 0)
				return [_keys(u, [[0.0, bp], [0.25, rock, "out"], [1.0, bp]]), "upper", lift]
			return [_keys(u, [[0.0, {}], [0.0004, bp, "out"], [1.0, bp]]), "upper", lift]
		# --- unarmed: jab, cross, hook, roundhouse; heavy flying kick ---
		"fists_up":
			return [_keys(u, [[0.0, REST_ARMS], [1.0, _guard()]]), "upper", lift]
		"jab":
			# lead (left) straight: the shoulder rolls forward and the fist snaps
			# out to full reach at chin height as the lead foot steps in
			var g := _guard()
			var load_ := {"hips": Vector3(0, -0.4, 0), "torso": Vector3(-0.1, -0.05, 0), "head": Vector3(0.14, 0.45, 0),
				"arm_l": Vector3(0.9, 0.55, -0.1), "fore_l": Vector3(1.95, 0, 0), "arm_r": g["arm_r"], "fore_r": g["fore_r"]}
			var hit := {"hips": Vector3(0, -0.72, 0), "torso": Vector3(-0.22, -0.32, 0.06), "head": Vector3(0.12, 1.0, 0),
				"arm_l": Vector3(1.58, 1.04, 0.0), "fore_l": Vector3(0.02, 0, 0),
				"arm_r": Vector3(0.8, 0.95, 0.15), "fore_r": Vector3(2.35, 0, 0),
				"leg_l": Vector3(0.55, 0, -0.22), "shin_l": Vector3(-0.5, 0, 0), "leg_r": Vector3(-0.42, 0, 0.22), "shin_r": Vector3(-0.22, 0, 0)}
			lift.y = -0.1 * sin(clampf(u * 1.4, 0, 1) * PI)
			return [_keys(u, [[0.0, g], [0.12, load_], [0.3, hit, "out"], [0.52, hit], [1.0, g]]), "full", lift]
		"cross":
			# rear (right) straight: the back heel spins, hips and shoulders whip
			# round and the right fist drives through the middle; the left hand
			# snaps back to the chin
			var g := _guard()
			var load_ := {"hips": Vector3(0, -0.65, 0), "torso": Vector3(-0.08, -0.2, 0), "head": Vector3(0.14, 0.8, 0),
				"arm_r": Vector3(0.55, 0.8, 0.2), "fore_r": Vector3(2.4, 0, 0), "arm_l": g["arm_l"], "fore_l": g["fore_l"]}
			var hit := {"hips": Vector3(0, 0.32, 0), "torso": Vector3(-0.32, 0.42, -0.06), "head": Vector3(0.12, -0.72, 0),
				"arm_r": Vector3(1.6, -0.72, 0.0), "fore_r": Vector3(0.02, 0, 0),
				"arm_l": Vector3(0.75, -0.55, -0.05), "fore_l": Vector3(2.35, 0, 0),
				"leg_l": Vector3(0.62, 0, -0.24), "shin_l": Vector3(-0.72, 0, 0), "leg_r": Vector3(-0.6, 0, 0.26), "shin_r": Vector3(-0.12, 0, 0)}
			lift.y = -0.14 * sin(clampf(u * 1.4, 0, 1) * PI)
			return [_keys(u, [[0.0, g], [0.12, load_], [0.3, hit, "out"], [0.52, hit], [1.0, g]]), "full", lift]
		"hook":
			# lead hook: load onto the lead side, then the whole body turns and
			# the bent arm (elbow at shoulder height) swings round into the target
			var g := _guard()
			var load_ := {"hips": Vector3(0, -0.2, 0), "torso": Vector3(-0.1, 0.25, 0.1), "head": Vector3(0.14, 0.0, 0),
				"arm_l": Vector3(0.55, 0.3, -0.75), "fore_l": Vector3(1.75, 0, 0), "arm_r": g["arm_r"], "fore_r": g["fore_r"],
				"leg_l": Vector3(0.3, 0, -0.2), "shin_l": Vector3(-0.6, 0, 0), "leg_r": Vector3(-0.15, 0, 0.2), "shin_r": Vector3(-0.55, 0, 0)}
			var hit := {"hips": Vector3(0, -0.9, 0), "torso": Vector3(-0.2, -0.5, -0.1), "head": Vector3(0.12, 1.3, 0),
				"arm_l": Vector3(0.12, 0.1, -1.5), "fore_l": Vector3(1.6, 0, 0),
				"arm_r": Vector3(0.75, 0.95, 0.12), "fore_r": Vector3(2.35, 0, 0),
				"leg_l": Vector3(0.45, 0, -0.22), "shin_l": Vector3(-0.5, 0, 0), "leg_r": Vector3(-0.35, 0, 0.22), "shin_r": Vector3(-0.35, 0, 0)}
			lift.y = -0.12 * sin(clampf(u * 1.3, 0, 1) * PI)
			return [_keys(u, [[0.0, g], [0.16, load_, "out"], [0.36, hit, "out"], [0.56, hit], [1.0, g]]), "full", lift]
		"roundhouse":
			# rear-leg roundhouse: chamber the knee up and out while pivoting on
			# the lead foot, then the shin whips round level with the ribs; the
			# body leans away and the right arm swings down for balance
			var g2 := _guard()
			var chamber := {"leg_r": Vector3(1.0, 0, 1.15), "shin_r": Vector3(-2.1, 0, 0),
				"leg_l": Vector3(0.05, 0, -0.08), "shin_l": Vector3(-0.3, 0, 0),
				"hips": Vector3.ZERO, "torso": Vector3(0.0, 0.0, 0.3), "head": Vector3(0.1, -0.7, -0.2),
				"arm_l": Vector3(1.0, 0.5, -0.2), "fore_l": Vector3(1.8, 0, 0), "arm_r": Vector3(0.2, 0, 0.7), "fore_r": Vector3(1.2, 0, 0)}
			var kick := {"leg_r": Vector3(0.25, 0, 1.6), "shin_r": Vector3(-0.08, 0, 0),
				"leg_l": Vector3(0.0, 0, -0.1), "shin_l": Vector3(-0.2, 0, 0),
				"hips": Vector3.ZERO, "torso": Vector3(0.05, 0.0, 0.62), "head": Vector3(0.1, -1.25, -0.45),
				"arm_l": Vector3(1.2, 0.6, -0.3), "fore_l": Vector3(1.6, 0, 0), "arm_r": Vector3(-0.45, 0, 0.9), "fore_r": Vector3(0.5, 0, 0)}
			var pose := _keys(u, [[0.0, g2], [0.22, chamber, "out"], [0.42, kick, "out"], [0.64, kick], [1.0, g2]])
			var turn := 0.0
			if u < 0.42:
				turn = 1.35 * (1.0 - pow(1.0 - u / 0.42, 2.2))
			else:
				turn = 1.35 * (1.0 - _ease((u - 0.64) / 0.36))
			pose["pivot"] = Vector3(0, turn, 0)
			lift.y = 0.04 * sin(clampf(u / 0.7, 0, 1) * PI)
			return [pose, "full", lift]
		"flying_kick":
			# crouch, spring up with the left knee tucked, then shoot the right
			# leg out straight, leaning back behind it, arms flung back
			var g3 := _guard()
			var crouch := {"leg_l": Vector3(0.95, 0, -0.12), "shin_l": Vector3(-1.5, 0, 0), "leg_r": Vector3(0.5, 0, 0.12), "shin_r": Vector3(-1.4, 0, 0),
				"hips": Vector3.ZERO, "torso": Vector3(-0.5, 0, 0), "head": Vector3(0.35, 0, 0),
				"arm_l": Vector3(-0.6, 0, -0.35), "fore_l": Vector3(0.4, 0, 0), "arm_r": Vector3(-0.6, 0, 0.35), "fore_r": Vector3(0.4, 0, 0)}
			var tuck := {"pivot": Vector3(0.15, 0, 0), "leg_l": Vector3(1.6, 0, -0.1), "shin_l": Vector3(-2.3, 0, 0),
				"leg_r": Vector3(1.4, 0, 0.1), "shin_r": Vector3(-2.2, 0, 0), "hips": Vector3.ZERO, "torso": Vector3(-0.2, 0, 0), "head": Vector3(0.1, 0, 0),
				"arm_l": Vector3(1.3, 0, -0.5), "fore_l": Vector3(1.4, 0, 0), "arm_r": Vector3(0.9, 0, 0.5), "fore_r": Vector3(1.6, 0, 0)}
			var fly := {"pivot": Vector3(0.34, 0, 0), "leg_r": Vector3(1.3, 0, 0.04), "shin_r": Vector3(-0.02, 0, 0),
				"leg_l": Vector3(1.0, 0, -0.12), "shin_l": Vector3(-2.3, 0, 0), "hips": Vector3.ZERO, "torso": Vector3(0.05, 0, 0), "head": Vector3(-0.3, 0, 0),
				"arm_l": Vector3(0.9, 0.3, -0.75), "fore_l": Vector3(1.3, 0, 0), "arm_r": Vector3(-0.9, 0, 0.55), "fore_r": Vector3(0.3, 0, 0)}
			if u < 0.25:
				lift.y = -0.26 * _ease(u / 0.25)
			elif u < 0.72:
				lift.y = lerpf(-0.26, 0.0, _ease((u - 0.25) / 0.1)) + 0.38 * sin(clampf((u - 0.25) / 0.47, 0, 1) * PI)
			return [_keys(u, [[0.0, g3], [0.24, crouch, "out"], [0.34, tuck, "out"], [0.44, fly, "out"], [0.68, fly], [1.0, g3]]), "full", lift]
		# --- dual swords ---
		"dual_1", "dual_2":
			var gd := _guard()
			var r1 := n == "dual_1"
			var wind_d := {"arm_r": Vector3(0.9, 0.7, 1.6) if r1 else Vector3(0.6, 0.2, 0.4), "fore_r": Vector3(0.7, 0, 0),
				"arm_l": Vector3(0.6, -0.2, -0.4) if r1 else Vector3(0.9, -0.7, -1.6), "fore_l": Vector3(0.7, 0, 0),
				"torso": Vector3(0.05, 0.9 if r1 else -0.9, 0)}
			var hit_d := {"arm_r": Vector3(1.4, -0.9, -1.0) if r1 else Vector3(0.7, 0.3, 0.6), "fore_r": Vector3(0.05, 0, 0),
				"arm_l": Vector3(0.7, -0.3, -0.6) if r1 else Vector3(1.4, 0.9, 1.0), "fore_l": Vector3(0.05, 0, 0),
				"torso": Vector3(-0.25, -0.9 if r1 else 0.9, 0),
				"leg_l": Vector3(0.75, 0, -0.1) if r1 else Vector3(-0.5, 0, -0.1), "shin_l": Vector3(-0.7, 0, 0),
				"leg_r": Vector3(-0.5, 0, 0.1) if r1 else Vector3(0.75, 0, 0.1), "shin_r": Vector3(-0.4, 0, 0)}
			lift.y = -0.12 * sin(clampf(u * 1.3, 0.0, 1.0) * PI)
			return [_keys(u, [[0.0, gd], [0.2, wind_d, "out"], [0.42, hit_d, "out"], [0.62, hit_d], [1.0, gd]]), "full", lift]
		"dual_cross":
			var gc := _guard()
			var open_x := {"arm_r": Vector3(2.4, 0.3, 0.9), "fore_r": Vector3(0.4, 0, 0), "arm_l": Vector3(2.4, -0.3, -0.9), "fore_l": Vector3(0.4, 0, 0),
				"torso": Vector3(0.3, 0, 0), "head": Vector3(0.2, 0, 0)}
			var cross_x := {"arm_r": Vector3(1.2, -0.9, -0.6), "fore_r": Vector3(0.1, 0, 0), "arm_l": Vector3(1.2, 0.9, 0.6), "fore_l": Vector3(0.1, 0, 0),
				"torso": Vector3(-0.45, 0, 0), "head": Vector3(-0.1, 0, 0),
				"leg_l": Vector3(0.85, 0, -0.12), "shin_l": Vector3(-0.85, 0, 0), "leg_r": Vector3(-0.55, 0, 0.12), "shin_r": Vector3(-0.3, 0, 0)}
			lift.y = -0.2 * sin(clampf((u - 0.25) / 0.6, 0.0, 1.0) * PI)
			return [_keys(u, [[0.0, gc], [0.24, open_x, "out"], [0.42, cross_x, "in"], [0.65, cross_x], [1.0, gc]]), "full", lift]
		"dual_spin":
			var gs := _guard()
			var out2 := {"arm_r": Vector3(1.4, 0.0, 1.5), "fore_r": Vector3(0.05, 0, 0), "arm_l": Vector3(1.4, 0.0, -1.5), "fore_l": Vector3(0.05, 0, 0),
				"torso": Vector3(-0.2, 0, 0), "leg_l": Vector3(0.5, 0, -0.25), "shin_l": Vector3(-0.8, 0, 0), "leg_r": Vector3(0.5, 0, 0.25), "shin_r": Vector3(-0.8, 0, 0)}
			var spin2 := 1.0 - pow(1.0 - clampf((u - 0.15) / 0.6, 0.0, 1.0), 2.2)
			var pose2 := _keys(u, [[0.0, gs], [0.15, out2, "out"], [0.78, out2], [1.0, gs]])
			pose2["pivot"] = Vector3(0, -TAU * spin2, 0)
			lift.y = 0.18 * sin(clampf((u - 0.15) / 0.6, 0.0, 1.0) * PI) - 0.1
			return [pose2, "full", lift]
		"gun_kata":
			# crouch, hop up into a double spin with the arms crossed, each gun
			# pointing out to the opposite side, land
			var gk := _guard()
			var crouch := {"arm_r": Vector3(0.9, 0.9, -0.3), "fore_r": Vector3(0.9, 0, 0), "arm_l": Vector3(0.95, -0.9, 0.3), "fore_l": Vector3(0.9, 0, 0),
				"torso": Vector3(-0.35, 0, 0), "head": Vector3(0.2, 0, 0),
				"leg_l": Vector3(0.9, 0, -0.12), "shin_l": Vector3(-1.5, 0, 0), "leg_r": Vector3(0.7, 0, 0.12), "shin_r": Vector3(-1.4, 0, 0)}
			var cross := {"arm_r": Vector3(1.45, 1.25, 0.0), "fore_r": Vector3(0.05, 0, 0), "arm_l": Vector3(1.62, -1.25, 0.0), "fore_l": Vector3(0.05, 0, 0),
				"torso": Vector3(-0.05, 0, 0), "head": Vector3(0.05, 0, 0),
				"leg_l": Vector3(0.75, 0, -0.08), "shin_l": Vector3(-1.2, 0, 0), "leg_r": Vector3(0.25, 0, 0.08), "shin_r": Vector3(-0.7, 0, 0)}
			var land := crouch.duplicate()
			land["arm_r"] = Vector3(0.6, 0.2, 0.3)
			land["arm_l"] = Vector3(0.6, -0.2, -0.3)
			var spin_k := 1.0 - pow(1.0 - clampf((u - 0.16) / 0.62, 0.0, 1.0), 1.8)
			var posek := _keys(u, [[0.0, gk], [0.13, crouch, "out"], [0.24, cross, "out"], [0.76, cross], [0.86, land, "in"], [1.0, gk]])
			posek["pivot"] = Vector3(0, -TAU * 2.0 * spin_k, 0)
			lift.y = (-0.14 * sin(clampf(u / 0.16, 0.0, 1.0) * PI * 0.5)) if u < 0.16 else \
				(-0.14 * sin(clampf((u - 0.8) / 0.2, 0.0, 1.0) * PI) if u > 0.8 else 0.0)
			return [posek, "full", lift]
		"dual_heavy":
			var gh := _guard()
			var up2 := {"arm_r": Vector3(3.1, 0.2, 0.45), "fore_r": Vector3(0.6, 0, 0), "arm_l": Vector3(3.1, -0.2, -0.45), "fore_l": Vector3(0.6, 0, 0),
				"torso": Vector3(0.4, 0, 0), "head": Vector3(0.3, 0, 0), "leg_l": Vector3(0.6, 0, -0.15), "shin_l": Vector3(-1.1, 0, 0), "leg_r": Vector3(0.3, 0, 0.15), "shin_r": Vector3(-1.0, 0, 0)}
			var down2 := {"arm_r": Vector3(0.6, -0.4, 0.2), "fore_r": Vector3(0.0, 0, 0), "arm_l": Vector3(0.6, 0.4, -0.2), "fore_l": Vector3(0.0, 0, 0),
				"torso": Vector3(-0.85, 0, 0), "head": Vector3(-0.3, 0, 0), "leg_l": Vector3(1.1, 0, -0.1), "shin_l": Vector3(-1.2, 0, 0), "leg_r": Vector3(-0.85, 0, 0.1), "shin_r": Vector3(-0.15, 0, 0)}
			lift.y = (-0.2 * _ease(u / 0.35)) if u < 0.35 else (-0.4 * (1.0 - _ease((u - 0.6) / 0.4)) if u > 0.6 else -0.4)
			return [_keys(u, [[0.0, gh], [0.32, up2, "out"], [0.45, down2, "in"], [0.68, down2], [1.0, gh]]), "full", lift]
		# --- pistols ---
		"shoot_r", "shoot_l":
			var gp := _guard()
			var rr := n == "shoot_r"
			var aim := gp.duplicate()
			if stance == "dual_pistol":
				# both guns come up in front, close together; the firing one kicks
				aim["arm_r"] = Vector3(1.5 + aim_pitch, 0.18, -0.06)
				aim["arm_l"] = Vector3(1.5 + aim_pitch, -0.18, 0.06)
				aim["fore_r"] = Vector3(0.12, 0, 0)
				aim["fore_l"] = Vector3(0.12, 0, 0)
				aim["torso"] = Vector3(0.0, 0.0, 0)
				var kd := aim.duplicate()
				kd["arm_r" if rr else "arm_l"] = (aim["arm_r" if rr else "arm_l"] as Vector3) + Vector3(0.4, 0, 0)
				kd["fore_r" if rr else "fore_l"] = Vector3(0.35, 0, 0)
				return [_keys(u, [[0.0, gp], [0.08, kd, "out"], [0.35, aim], [0.8, aim], [1.0, gp]]), "upper", lift]
			if rr:
				aim["arm_r"] = Vector3(1.55 + aim_pitch, -0.05, 0.1)
				aim["fore_r"] = Vector3(0.05, 0, 0)
				aim["hand_r"] = Vector3(-1.55, 0, 0)
			else:
				aim["arm_l"] = Vector3(1.55 + aim_pitch, 0.05, -0.1)
				aim["fore_l"] = Vector3(0.05, 0, 0)
			aim["torso"] = Vector3(0.0, -0.35 if rr else 0.35, 0)
			var kick3 := aim.duplicate()
			kick3["arm_r" if rr else "arm_l"] = (aim["arm_r" if rr else "arm_l"] as Vector3) + Vector3(0.55, 0, 0)
			kick3["fore_r" if rr else "fore_l"] = Vector3(0.4, 0, 0)
			return [_keys(u, [[0.0, aim], [0.12, kick3, "out"], [0.5, aim], [1.0, gp]]), "upper", lift]
		"reload":
			var rl := {"arm_r": Vector3(0.6, 0.6, 0.2), "fore_r": Vector3(1.7, 0, 0), "arm_l": Vector3(0.6, -0.5, -0.2), "fore_l": Vector3(1.7, 0, 0),
				"head": Vector3(-0.35, 0, 0), "torso": Vector3(-0.15, 0, 0)}
			var rl2 := rl.duplicate()
			rl2["arm_l"] = Vector3(0.75, -0.45, -0.1) + Vector3(sin(_t * 18.0) * 0.08, 0, 0)
			return [_keys(u, [[0.0, {}], [0.2, rl], [0.5, rl2], [0.8, rl], [1.0, {}]]), "upper", lift]
		"pistol_whip":
			var gw := _guard()
			var cockw := {"arm_r": Vector3(1.6, 0.9, 1.4), "fore_r": Vector3(1.2, 0, 0), "torso": Vector3(0.05, 0.8, 0), "arm_l": Vector3(0.8, 0, -0.5), "fore_l": Vector3(1.2, 0, 0)}
			var whip := {"arm_r": Vector3(1.3, -0.9, -0.9), "fore_r": Vector3(0.3, 0, 0), "torso": Vector3(-0.3, -0.8, 0), "arm_l": Vector3(0.3, 0, -1.0), "fore_l": Vector3(0.5, 0, 0),
				"leg_l": Vector3(0.8, 0, -0.1), "shin_l": Vector3(-0.8, 0, 0), "leg_r": Vector3(-0.6, 0, 0.1), "shin_r": Vector3(-0.3, 0, 0)}
			return [_keys(u, [[0.0, gw], [0.3, cockw, "out"], [0.48, whip, "out"], [0.7, whip], [1.0, gw]]), "full", lift]
		# --- claws (Zoan hybrid) ---
		"claw_r", "claw_l":
			# a big wound-up rake: the arm cocks high behind the shoulder, the
			# body coils, then lunges low and tears across
			var gk := _guard()
			var sg := 1.0 if n == "claw_r" else -1.0
			var coil := {"torso": Vector3(-0.45, 0.85 * sg, 0), "head": Vector3(0.7, -0.5 * sg, 0), "pivot": Vector3(-0.18, 0, 0),
				"leg_l": Vector3(1.05, 0, -0.3), "shin_l": Vector3(-1.5, 0, 0), "leg_r": Vector3(0.1, 0, 0.3), "shin_r": Vector3(-1.2, 0, 0)}
			var rake := {"torso": Vector3(-0.95, -0.95 * sg, 0), "head": Vector3(0.75, 0.45 * sg, 0), "pivot": Vector3(-0.28, 0, 0),
				"leg_l": Vector3(1.4, 0, -0.22), "shin_l": Vector3(-1.65, 0, 0), "leg_r": Vector3(-0.8, 0, 0.22), "shin_r": Vector3(-0.35, 0, 0)}
			var att := "_r" if sg > 0.0 else "_l"
			var off := "_l" if sg > 0.0 else "_r"
			coil["arm" + att] = Vector3(-0.55, 0.0, 1.5 * sg)
			coil["fore" + att] = Vector3(1.3, 0, 0)
			coil["arm" + off] = Vector3(0.95, 0.1 * sg, -0.4 * sg)
			coil["fore" + off] = Vector3(1.25, 0, 0)
			rake["arm" + att] = Vector3(0.55, -1.0 * sg, -1.05 * sg)
			rake["fore" + att] = Vector3(0.1, 0, 0)
			rake["arm" + off] = Vector3(-0.4, 0.2 * sg, -1.0 * sg)
			rake["fore" + off] = Vector3(0.9, 0, 0)
			lift.y = -0.12 * _ease(u / 0.3) if u < 0.3 else -0.12 - 0.22 * sin(clampf((u - 0.3) / 0.7, 0.0, 1.0) * PI)
			return [_keys(u, [[0.0, gk], [0.3, coil, "out"], [0.48, rake, "in"], [0.72, rake], [1.0, gk]]), "full", lift]
		"claw_double", "rending_fang":
			# both claws up overhead in a hop, then a crossing double slash
			# down through the target, landing low
			var gk := _guard()
			var rear := {"torso": Vector3(-0.15, 0, 0), "head": Vector3(0.5, 0, 0), "pivot": Vector3(-0.05, 0, 0),
				"arm_l": Vector3(2.1, -0.4, -0.95), "fore_l": Vector3(1.25, 0, 0), "arm_r": Vector3(2.1, 0.4, 0.95), "fore_r": Vector3(1.25, 0, 0),
				"leg_l": Vector3(1.0, 0, -0.3), "shin_l": Vector3(-1.6, 0, 0), "leg_r": Vector3(0.5, 0, 0.3), "shin_r": Vector3(-1.3, 0, 0)}
			var cross := {"torso": Vector3(-1.05, 0, 0), "head": Vector3(0.8, 0, 0), "pivot": Vector3(-0.32, 0, 0),
				"arm_l": Vector3(0.35, 0.95, 0.85), "fore_l": Vector3(0.15, 0, 0), "arm_r": Vector3(0.35, -0.95, -0.85), "fore_r": Vector3(0.15, 0, 0),
				"leg_l": Vector3(1.35, 0, -0.35), "shin_l": Vector3(-1.8, 0, 0), "leg_r": Vector3(-0.6, 0, 0.35), "shin_r": Vector3(-0.5, 0, 0)}
			if u < 0.32:
				lift.y = lerpf(-0.2, 0.06, sin(clampf(u / 0.32, 0.0, 1.0) * PI * 0.5))
			else:
				lift.y = lerpf(0.06, -0.38, _ease((u - 0.32) / 0.18)) * (1.0 - _ease((u - 0.75) / 0.25)) - 0.2 * _ease((u - 0.75) / 0.25)
			return [_keys(u, [[0.0, gk], [0.32, rear, "out"], [0.5, cross, "in"], [0.75, cross], [1.0, gk]]), "full", lift]
		"maul", "pounce":
			var gm := _guard()
			var low := {"leg_l": Vector3(1.1, 0, -0.15), "shin_l": Vector3(-1.8, 0, 0), "leg_r": Vector3(0.8, 0, 0.15), "shin_r": Vector3(-1.7, 0, 0),
				"torso": Vector3(-0.7, 0, 0), "head": Vector3(0.6, 0, 0), "arm_l": Vector3(0.6, 0, -0.3), "fore_l": Vector3(0.6, 0, 0),
				"arm_r": Vector3(0.6, 0, 0.3), "fore_r": Vector3(0.6, 0, 0)}
			var leap := {"pivot": Vector3(-0.6, 0, 0), "leg_l": Vector3(-0.3, 0, -0.1), "shin_l": Vector3(-0.6, 0, 0), "leg_r": Vector3(-0.5, 0, 0.1),
				"shin_r": Vector3(-0.4, 0, 0), "torso": Vector3(0.1, 0, 0), "head": Vector3(0.5, 0, 0),
				"arm_l": Vector3(2.7, 0, -0.35), "fore_l": Vector3(0.3, 0, 0), "arm_r": Vector3(2.7, 0, 0.35), "fore_r": Vector3(0.3, 0, 0)}
			var land := {"leg_l": Vector3(1.2, 0, -0.2), "shin_l": Vector3(-1.9, 0, 0), "leg_r": Vector3(0.6, 0, 0.2), "shin_r": Vector3(-1.6, 0, 0),
				"torso": Vector3(-0.8, 0, 0), "head": Vector3(0.5, 0, 0), "arm_l": Vector3(1.0, 0, -0.2), "fore_l": Vector3(0.1, 0, 0),
				"arm_r": Vector3(1.0, 0, 0.2), "fore_r": Vector3(0.1, 0, 0)}
			lift.y = -0.3 * _ease(u / 0.2) if u < 0.2 else (-0.4 * (1.0 - _ease((u - 0.75) / 0.25)) if u > 0.6 else 0.0)
			return [_keys(u, [[0.0, gm], [0.2, low, "out"], [0.32, leap, "out"], [0.6, leap], [0.7, land, "in"], [0.85, land], [1.0, gm]]), "full", lift]
		"howl":
			var hw := {"head": Vector3(1.0, 0, 0), "torso": Vector3(0.45, 0, 0), "arm_l": Vector3(0.4, 0, -1.0), "fore_l": Vector3(1.4, 0, 0),
				"arm_r": Vector3(0.4, 0, 1.0), "fore_r": Vector3(1.4, 0, 0), "leg_l": Vector3(0.4, 0, -0.2), "shin_l": Vector3(-0.6, 0, 0),
				"leg_r": Vector3(0.4, 0, 0.2), "shin_r": Vector3(-0.6, 0, 0)}
			return [_keys(u, [[0.0, {}], [0.25, hw, "out"], [0.8, hw], [1.0, {}]]), "full", lift]
		# --- body techniques / sword / gun / haki skills ---
		"soru":
			var sp := {"pivot": Vector3(-0.5, 0, 0), "torso": Vector3(-0.3, 0, 0), "arm_l": Vector3(-0.8, 0, -0.3), "arm_r": Vector3(-0.8, 0, 0.3),
				"leg_l": Vector3(1.0, 0, -0.1), "shin_l": Vector3(-1.5, 0, 0), "leg_r": Vector3(-0.6, 0, 0.1), "shin_r": Vector3(-0.6, 0, 0)}
			return [_keys(u, [[0.0, {}], [0.2, sp, "out"], [0.7, sp], [1.0, {}]]), "full", lift]
		"tekkai":
			var tk := {"arm_l": Vector3(1.45, 0.9, 0.5), "fore_l": Vector3(1.9, 0, 0), "arm_r": Vector3(1.45, -0.9, -0.5), "fore_r": Vector3(1.9, 0, 0),
				"torso": Vector3(-0.2, 0, 0), "head": Vector3(-0.25, 0, 0), "leg_l": Vector3(0.45, 0, -0.35), "shin_l": Vector3(-0.8, 0, 0),
				"leg_r": Vector3(0.45, 0, 0.35), "shin_r": Vector3(-0.8, 0, 0)}
			lift.y = -0.18 * _ease(u / 0.15) * (1.0 - _ease((u - 0.9) / 0.1))
			return [_keys(u, [[0.0, {}], [0.12, tk, "out"], [0.9, tk], [1.0, {}]]), "full", lift]
		"flying_slash":
			var gf := _guard()
			var wf := {"arm_r": Vector3(0.6, 0.9, 1.9), "fore_r": Vector3(0.6, 0, 0), "torso": Vector3(0.1, 1.3, 0.1), "arm_l": Vector3(0.9, 0, -0.6), "fore_l": Vector3(1.2, 0, 0),
				"leg_l": Vector3(0.5, 0, -0.2), "shin_l": Vector3(-0.9, 0, 0), "leg_r": Vector3(-0.3, 0, 0.2), "shin_r": Vector3(-0.8, 0, 0)}
			var sf := {"arm_r": Vector3(1.5, -1.0, -1.3), "fore_r": Vector3(0.0, 0, 0), "torso": Vector3(-0.3, -1.2, -0.1), "arm_l": Vector3(0.2, 0, -1.4), "fore_l": Vector3(0.4, 0, 0),
				"leg_l": Vector3(1.0, 0, -0.15), "shin_l": Vector3(-1.0, 0, 0), "leg_r": Vector3(-0.75, 0, 0.1), "shin_r": Vector3(-0.2, 0, 0)}
			lift.y = -0.22 * sin(clampf(u, 0, 1) * PI)
			return [_keys(u, [[0.0, gf], [0.3, wf, "out"], [0.45, sf, "out"], [0.7, sf], [1.0, gf]]), "full", lift]
		"bullet_storm":
			var gb := _guard()
			var fan := sin(_t * 30.0) * 0.08
			var sw := clampf((u - 0.1) / 0.75, 0.0, 1.0)
			var bs := {"arm_r": Vector3(1.55, lerpf(0.7, -0.7, sw), 0.1), "fore_r": Vector3(0.05, 0, 0), "hand_r": Vector3(-1.55, 0, 0),
				"arm_l": Vector3(1.3 + fan, lerpf(0.5, -0.5, sw), -0.2), "fore_l": Vector3(0.6, 0, 0), "torso": Vector3(0, lerpf(0.5, -0.5, sw), 0)}
			return [_keys(u, [[0.0, gb], [0.1, bs, "out"], [0.85, bs], [1.0, gb]]), "upper", lift]
		"coat":
			var ct := {"arm_r": Vector3(1.8, 0, 0.3), "fore_r": Vector3(1.9, 0, 0), "torso": Vector3(-0.1, 0.3, 0), "head": Vector3(-0.2, 0.2, 0),
				"arm_l": Vector3(0.4, 0, -0.4), "fore_l": Vector3(1.0, 0, 0)}
			return [_keys(u, [[0.0, {}], [0.35, ct, "out"], [0.75, ct], [1.0, {}]]), "upper", lift]
		"foresight":
			var fs := {"arm_r": Vector3(2.2, 0.8, -0.4), "fore_r": Vector3(2.3, 0, 0), "head": Vector3(-0.3, 0, 0), "torso": Vector3(0.05, 0, 0)}
			return [_keys(u, [[0.0, {}], [0.3, fs, "out"], [0.75, fs], [1.0, {}]]), "upper", lift]
		# --- vines ---
		"vine_throw", "thorn_whip":
			var vt := {"arm_r": Vector3(2.8, 0.2, 0.6), "fore_r": Vector3(1.4, 0, 0), "torso": Vector3(0.2, 0.6, 0), "arm_l": Vector3(1.1, 0, -0.4), "fore_l": Vector3(0.6, 0, 0),
				"leg_l": Vector3(0.6, 0, -0.1), "shin_l": Vector3(-0.6, 0, 0), "leg_r": Vector3(-0.4, 0, 0.1), "shin_r": Vector3(-0.4, 0, 0)}
			var vr := {"arm_r": Vector3(1.4, -0.3, -0.2), "fore_r": Vector3(0.05, 0, 0), "torso": Vector3(-0.3, -0.5, 0), "arm_l": Vector3(-0.3, 0, -0.6), "fore_l": Vector3(0.5, 0, 0),
				"leg_l": Vector3(0.9, 0, -0.1), "shin_l": Vector3(-0.9, 0, 0), "leg_r": Vector3(-0.6, 0, 0.1), "shin_r": Vector3(-0.2, 0, 0)}
			return [_keys(u, [[0.0, {}], [0.3, vt, "out"], [0.48, vr, "out"], [0.7, vr], [1.0, {}]]), "full", lift]
		"vine_hang":
			# the vine hand straight up the vine (the body is lined up with it);
			# everything else hangs loose and swings with the momentum
			var vh := {"arm_r": Vector3(3.05, 0.0, 0.1), "fore_r": Vector3(0.15, 0, 0), "torso": Vector3(0.08, 0.15, 0.04), "head": Vector3(0.25, -0.1, 0)}
			for j in DANGLE_LIMBS.keys():
				var a: Vector2 = _dg[j][0] if _dg.has(j) else DANGLE_LIMBS[j]
				vh[j] = Vector3(a.x, 0, a.y)
			var lk: Vector2 = _dg["leg_l"][0] if _dg.has("leg_l") else Vector2.ZERO
			var rk: Vector2 = _dg["leg_r"][0] if _dg.has("leg_r") else Vector2.ZERO
			var av: Vector2 = _dg["arm_l"][1] if _dg.has("arm_l") else Vector2.ZERO
			# knees fold as a leg swings forward, the elbow flops with the arm
			vh["shin_l"] = Vector3(-0.35 - maxf(lk.x, 0.0) * 0.8, 0, 0)
			vh["shin_r"] = Vector3(-0.25 - maxf(rk.x, 0.0) * 0.8, 0, 0)
			vh["fore_l"] = Vector3(0.35 + clampf(absf(av.x) * 0.06, 0.0, 0.8), 0, 0)
			return [vh, "full", lift]
		"vine_shoot":
			# fling the vine hand up and out at the anchor
			var aim := {"arm_r": Vector3(2.6, 0.0, 0.35), "fore_r": Vector3(0.05, 0, 0), "torso": Vector3(0.25, 0.45, 0.1), "head": Vector3(0.35, -0.3, 0),
				"arm_l": Vector3(0.6, 0, -0.8), "fore_l": Vector3(0.7, 0, 0)}
			return [_keys(u, [[0.0, {}], [0.4, aim, "out"], [1.0, aim]]), "full", lift]
		"vine_release":
			# let go: arms fling up and out, legs trail, then you tuck to land
			var rel := {"arm_r": Vector3(2.5, 0, 0.7), "fore_r": Vector3(0.35, 0, 0), "arm_l": Vector3(1.9, 0, -1.0), "fore_l": Vector3(0.5, 0, 0),
				"leg_l": Vector3(0.75, 0, -0.18), "shin_l": Vector3(-1.3, 0, 0), "leg_r": Vector3(-0.15, 0, 0.14), "shin_r": Vector3(-0.7, 0, 0),
				"torso": Vector3(0.2, 0, 0), "head": Vector3(0.2, 0, 0)}
			return [_keys(u, [[0.0, rel], [0.55, rel], [1.0, {}]]), "full", lift]
		"vine_zip":
			# reeled along the vine toward a big target: vine arm ahead, knees up
			var zp := {"arm_r": Vector3(1.9, 0.0, 0.1), "fore_r": Vector3(0.05, 0, 0), "arm_l": Vector3(0.4, 0, -0.9), "fore_l": Vector3(0.9, 0, 0),
				"leg_l": Vector3(1.3, 0, -0.12), "shin_l": Vector3(-1.9, 0, 0), "leg_r": Vector3(0.9, 0, 0.12), "shin_r": Vector3(-1.6, 0, 0),
				"torso": Vector3(-0.3, 0, 0), "head": Vector3(0.35, 0, 0)}
			return [_keys(u, [[0.0, {}], [0.15, zp, "out"], [1.0, zp]]), "full", lift]
		"vine_pull":
			# shoot the vine at them, then haul it back hand over fist
			var cast := {"arm_r": Vector3(1.65, -0.1, 0.05), "fore_r": Vector3(0.05, 0, 0), "torso": Vector3(-0.25, -0.3, 0), "head": Vector3(0.1, 0.3, 0),
				"arm_l": Vector3(0.8, 0, -0.5), "fore_l": Vector3(1.1, 0, 0),
				"leg_l": Vector3(0.6, 0, -0.12), "shin_l": Vector3(-0.6, 0, 0), "leg_r": Vector3(-0.4, 0, 0.12), "shin_r": Vector3(-0.3, 0, 0)}
			var haul := {"arm_r": Vector3(0.4, 0.6, 0.35), "fore_r": Vector3(2.1, 0, 0), "torso": Vector3(0.25, 0.6, 0), "head": Vector3(0.0, -0.5, 0),
				"arm_l": Vector3(1.1, 0.3, -0.2), "fore_l": Vector3(1.6, 0, 0),
				"leg_l": Vector3(0.45, 0, -0.14), "shin_l": Vector3(-0.3, 0, 0), "leg_r": Vector3(-0.2, 0, 0.14), "shin_r": Vector3(-0.8, 0, 0)}
			lift.y = -0.1 * sin(clampf(u, 0, 1) * PI)
			return [_keys(u, [[0.0, {}], [0.2, cast, "out"], [0.32, cast], [0.5, haul, "out"], [0.75, haul], [1.0, {}]]), "full", lift]
		"hit":
			var flinch := {"torso": Vector3(0.25, -0.15, 0), "head": Vector3(0.2, 0, 0)}
			return [_keys(u, [[0.0, {}], [0.3, flinch], [1.0, {}]]), "upper", lift]
		"drink":
			var sip := {"arm_l": Vector3(2.0, 0.6, 0.35), "fore_l": Vector3(2.3, 0, 0), "head": Vector3(0.45, 0, 0), "torso": Vector3(0.1, 0, 0)}
			return [_keys(u, [[0.0, {}], [0.25, sip], [0.8, sip], [1.0, {}]]), "upper", lift]
		"wave":
			var wv := {"arm_r": Vector3(0.2, 0, 2.6 + sin(_t * 12.0) * 0.25), "fore_r": Vector3(0.4, 0, 0), "head": Vector3(0.1, -0.2, 0)}
			return [_keys(u, [[0.0, {}], [0.2, wv], [0.85, wv], [1.0, {}]]), "upper", lift]
	return [{}, "upper", lift]


# ==========================================================================
# Locomotion
# ==========================================================================
func _locomotion(delta: float) -> Dictionary:
	var p := {}
	for j in JOINTS:
		p[j] = Vector3.ZERO
	var lift := Vector3.ZERO
	var spd := ground_speed
	if spd <= 0.01 and move_speed > 0.01:
		spd = move_speed * 1.4
	var air_before := _air_time

	if grounded:
		# Gait blends by speed: a real walk at low speed (NPCs, light stick),
		# a relaxed, springy jog at the default 6 m/s, and a long-striding,
		# forward-leaning run when sprinting (12 m/s).
		var walk := clampf(spd / 1.5, 0.0, 1.0)
		var jog := smoothstep(2.0, 5.5, spd)
		var run := smoothstep(6.3, 8.8, spd)
		# Where we're going relative to the facing, eased so a change of keys
		# (or a diagonal) swings the gait round instead of snapping it.
		var want_ang := atan2(local_move.x, local_move.y) if local_move.length() > 0.01 else 0.0
		var ease_k := 1.0 - exp(-(12.0 if spd > 0.1 else 4.0) * delta)
		# (lerp_angle doesn't wrap: past ±PI the backpedal check below would latch on)
		_travel_ang = wrapf(lerp_angle(_travel_ang, want_ang if spd > 0.1 else 0.0, ease_k), -PI, PI)
		# forward stride or backpedal, with some hysteresis so a back-diagonal
		# doesn't flicker between the two
		if _gait_back and absf(_travel_ang) < deg_to_rad(96.0):
			_gait_back = false
		elif not _gait_back and absf(_travel_ang) > deg_to_rad(114.0):
			_gait_back = true
		var dir_sign := -1.0 if _gait_back else 1.0
		# the legs stride along the travel line: the hips turn toward it (the
		# chest counter-turns below, so the guard stays on the target) and
		# whatever the hips can't turn is taken up by a side reach
		var heading := wrapf(_travel_ang + (PI if _gait_back else 0.0), -PI, PI)
		var yaw_want := clampf(heading, -HIP_YAW_MAX, HIP_YAW_MAX) * walk if spd > 0.1 else 0.0
		_hip_yaw = lerp_angle(_hip_yaw, yaw_want, 1.0 - exp(-10.0 * delta))
		var resid := wrapf(heading - _hip_yaw, -PI, PI)
		# cadence (stride cycles per second): unhurried, longer strides when fast
		var cps := (0.75 + spd * 0.1) if spd < 6.0 else maxf(1.35 - (spd - 6.0) * 0.03, 1.1)
		# backpedalling: a touch quicker, much shorter steps (see amp below)
		if _gait_back:
			cps *= 1.08
		if spd > 0.1:
			_phase += delta * TAU * cps * dir_sign
		else:
			_phase = lerpf(_phase, roundf(_phase / PI) * PI, minf(6.0 * delta, 1.0))
		var s := sin(_phase)
		var c := cos(_phase)
		var c2 := cos(2.0 * _phase)
		# footfall each half cycle
		var step_sign := signf(s)
		if step_sign != _last_step_sign and walk > 0.35:
			footstep.emit(clampf(spd / 12.0, 0.2, 1.0))
		_last_step_sign = step_sign

		# legs: knee lifts more in front than the leg trails behind
		var amp := lerpf(lerpf(0.5, 0.62, jog), 0.92, run) * walk * (0.7 if _gait_back else 1.0)
		var lift_bias := lerpf(0.0, 0.14, maxf(jog * 0.75, run)) * walk
		# the jog lifts its knees higher in front (springier, not a shuffle)
		var knee_up := lerpf(1.12, 1.3, jog * (1.0 - run))
		# (the reach toward where you're going is the long one, backpedalling too)
		var swing_l := s * amp * (knee_up if s * dir_sign > 0.0 else 0.9)
		var swing_r := -s * amp * (knee_up if s * dir_sign < 0.0 else 0.9)
		# swing the legs along the direction of travel (strafing / diagonals in
		# combat stance): the stepping foot reaches toward where you're going,
		# and a leg never swings across the other one
		var mv := Vector2(sin(resid), cos(resid))
		var fx := clampf(absf(mv.y) + (1.0 - absf(mv.x)) * 0.0, 0.0, 1.0)
		var lat := mv.x * 0.6
		p["leg_l"] = Vector3((swing_l + lift_bias) * fx, 0, minf(swing_l * lat, 0.08))
		p["leg_r"] = Vector3((swing_r + lift_bias) * fx, 0, maxf(swing_r * lat, -0.08))
		# knee: folds on the forward swing (heel kicks up behind when running),
		# and gives a little under the body while the foot is planted
		var fold := lerpf(lerpf(0.85, 1.7, jog), 1.95, run) * walk
		var kick := lerpf(0.0, 0.55, maxf(jog * 0.6, run))
		var give := lerpf(0.08, 0.32, jog) * walk
		# the leading leg lands soft (knee unlocked), more so at a jog
		var land := lerpf(0.06, 0.3, jog) * walk * (1.0 - run * 0.4)
		# (the lifted leg is the one travelling with you: forward when walking
		# on, backward when backpedalling - which in phase terms is cos > 0
		# either way, since a backpedal runs the cycle in reverse)
		var kk := kick * dir_sign
		var swing_l_t := maxf(0.0, cos(_phase + kk))
		var swing_r_t := maxf(0.0, -cos(_phase + kk))
		p["shin_l"] = Vector3(-fold * swing_l_t * swing_l_t * 0.6 - fold * swing_l_t * 0.4 - give * maxf(0.0, -c) - land * maxf(0.0, s * dir_sign) - 0.08 * walk, 0, 0)
		p["shin_r"] = Vector3(-fold * swing_r_t * swing_r_t * 0.6 - fold * swing_r_t * 0.4 - give * maxf(0.0, c) - land * maxf(0.0, -s * dir_sign) - 0.08 * walk, 0, 0)
		# arms: loose swing opposite the legs; elbows bend more with speed and
		# the forearms trail the upper arm a little (follow-through)
		var arm_amp := lerpf(lerpf(0.4, 0.62, jog), 0.82, run) * walk
		var elbow := lerpf(lerpf(0.22, 1.0, jog), 1.4, run) * walk
		var trail := lerpf(0.22, 0.3, jog) * (1.0 - run * 0.6) * walk
		var lag := sin(_phase - 0.7)
		p["arm_l"] = Vector3(-s * arm_amp, 0, -0.1 - 0.05 * jog)
		p["arm_r"] = Vector3(s * arm_amp, 0, 0.1 + 0.05 * jog)
		p["fore_l"] = Vector3(elbow + 0.12 + maxf(0.0, -lag) * trail + maxf(0.0, -s) * 0.25 * run, 0, 0)
		p["fore_r"] = Vector3(elbow + 0.12 + maxf(0.0, lag) * trail + maxf(0.0, s) * 0.25 * run, 0, 0)
		# torso: forward lean grows with speed, shoulders counter the hips,
		# a small chest bob each step; hips drop on the swinging side
		var lean := lerpf(lerpf(0.07, 0.13, jog), 0.22, run) * walk
		var twist := lerpf(lerpf(0.16, 0.2, jog), 0.14, run) * walk
		var hip_twist := lerpf(0.12, 0.1, run) * walk
		var hip_drop := lerpf(lerpf(0.07, 0.065, jog), 0.035, run) * walk
		p["hips"] = Vector3(0, -s * hip_twist, c * hip_drop)
		p["torso"] = Vector3(-lean - c2 * lerpf(0.015, 0.035, jog) * walk, s * (twist + hip_twist), -c * hip_drop * 0.7)
		p["head"] = Vector3(lean * 0.55, 0, 0)
		# vertical bob: a walk rises over the planted leg, a jog/run dips into
		# the planted leg and floats between steps
		var bob := lerpf(0.022, lerpf(-0.078, -0.07, run), jog) * walk
		# a little extra pop off each step (sharper rise into the float)
		var pop := absf(s) * absf(s) * lerpf(0.03, 0.035, run) * jog * walk
		lift.y = c2 * bob + pop - lerpf(0.0, 0.04, jog) * walk
		# weight shifts over the planted foot
		lift.x = c * lerpf(0.028, 0.012, jog) * walk

		# bouncy idle: a rhythmic knee-bend bob with swinging arms
		var idle := 1.0 - walk
		if idle > 0.0:
			var b := sin(_t * 3.4)
			var b2 := sin(_t * 1.7)
			lift.y += (b * 0.03 - 0.025) * idle
			p["leg_l"] += Vector3(0.1 + b * 0.06, 0, -0.06) * idle
			p["leg_r"] += Vector3(0.1 + b * 0.06, 0, 0.06) * idle
			p["shin_l"] += Vector3(-0.2 - b * 0.12, 0, 0) * idle
			p["shin_r"] += Vector3(-0.2 - b * 0.12, 0, 0) * idle
			p["torso"] += Vector3(-0.04 - b * 0.04, b2 * 0.05, b2 * 0.04) * idle
			p["hips"] += Vector3(0, 0, -b2 * 0.05) * idle
			p["head"] += Vector3(b * 0.03, 0, 0) * idle
			p["arm_l"] += Vector3(sin(_t * 1.7 + 0.5) * 0.1, 0, -0.12 - b * 0.06) * idle
			p["arm_r"] += Vector3(-sin(_t * 1.7 + 0.5) * 0.1, 0, 0.12 + b * 0.06) * idle
			p["fore_l"] += Vector3(0.25 + b * 0.1, 0, 0) * idle
			p["fore_r"] += Vector3(0.25 + b * 0.1, 0, 0) * idle
			# weight on one leg, every several seconds shifting to the other: the
			# standing leg straightens, the other relaxes, the hip drops on the
			# relaxed side and the chest counters it (not in the combat stance)
			if not (armed and not sprinting):
				var w := clampf(sin(_t * 0.35 + _idle_seed) * 3.0, -1.0, 1.0)
				var ws := absf(w) * idle * (1.0 - smoothstep(0.0, 0.3, _land))
				var rs := "l" if w > 0.0 else "r"
				var ss := "r" if w > 0.0 else "l"
				var ro := -1.0 if rs == "l" else 1.0
				p["shin_" + ss] += Vector3(0.12, 0, 0) * ws
				p["shin_" + ss].x = minf(p["shin_" + ss].x, -0.04)
				p["leg_" + ss] += Vector3(-0.04, 0, 0) * ws
				p["shin_" + rs] += Vector3(-0.32, 0, 0) * ws
				p["leg_" + rs] += Vector3(0.16, 0, 0.05 * ro) * ws
				p["hips"] += Vector3(0, 0.05 * ro, -0.07 * ro) * ws
				p["torso"] += Vector3(0, -0.04 * ro, 0.06 * ro) * ws
				lift.x += -0.03 * ro * ws
		# Zoan hybrid: a low feral crouch, claws out at the sides, and a
		# forward-pitched, bounding run
		if armed and stance == "claw":
			lift.y += _feral(p, walk, maxf(jog * 0.6, run), s)
		# combat stance: guard arms, wide knees, boxer-style hop
		elif armed and not sprinting:
			var hop := absf(sin(_t * 4.5))
			var gd := _guard()
			var fist := stance == "fist"
			for j in gd.keys():
				if j == "hips":
					# the bladed hips relax while moving so the legs stride straight
					p[j] = (gd[j] as Vector3) * (1.0 - clampf(walk, 0.0, 1.0) * 0.6)
					continue
				p[j] = gd[j] + Vector3(hop * 0.06, 0, sin(_t * 4.5) * 0.03)
			if walk < 0.5:
				var st := 1.0 - walk * 2.0
				if fist:
					# feet shoulder-width apart; the turned hips put the left foot ahead
					p["leg_l"] += Vector3(0.12, 0, -0.2) * st
					p["leg_r"] += Vector3(-0.12, 0, 0.2) * st
				else:
					p["leg_l"] += Vector3(0.35, 0, -0.14) * st
					p["leg_r"] += Vector3(-0.3, 0, 0.14) * st
				p["shin_l"] += Vector3(-0.45 - hop * 0.15, 0, 0) * st
				p["shin_r"] += Vector3(-0.35 - hop * 0.15, 0, 0) * st
				lift.y += (-0.1 + hop * 0.045) * st
		# strafing: hips (and legs) turned into the travel line, chest square
		# (_hip_yaw is toward +X = the body's right; a positive Y turn is left)
		# (the pelvis and chest are rigid, so a big twist between them shears the
		# waist: the pelvis takes a little, the thighs turn in their sockets for the rest)
		if absf(_hip_yaw) > 0.0005:
			var pel := _hip_yaw * PELVIS_SHARE
			p["hips"] += Vector3(0, -pel, 0)
			p["torso"] += Vector3(0, pel, 0)
			p["leg_l"] += Vector3(0, -(_hip_yaw - pel), 0)
			p["leg_r"] += Vector3(0, -(_hip_yaw - pel), 0)
		var lv := local_move * spd if spd > 0.2 else Vector2.ZERO
		_tip_lag = _tip_lag.lerp(lv, 1.0 - exp(-5.0 * delta))
		if armed and not sprinting and stance != "claw":
			var tip := ((lv - _tip_lag) * TIP_GAIN).limit_length(TIP_MAX)
			# braking leans back less than pushing off leans in
			if tip.y < 0.0:
				tip.y *= 0.6
			p["torso"] += Vector3(-tip.y, 0, -tip.x)
			p["head"] += Vector3(tip.y * 0.4, 0, 0)
			_casual_moves(p, delta, spd, false)
		else:
			_casual_moves(p, delta, spd, true)
			lift.y -= _casual_dip()
		_air_time = 0.0
	else:
		_air_time += delta
		_hip_yaw = lerp_angle(_hip_yaw, 0.0, 1.0 - exp(-8.0 * delta))
		var vy := vertical_speed
		# each take-off (and a double jump's kick) rolls which leg leads and a little
		# per-limb variety, so no two jumps hold the same mirrored pose
		if _was_grounded or vy > _air_vy + 4.0:
			_jside = 1.0 if _rng.randf() < 0.5 else -1.0
			for i in range(_jv.size()):
				_jv[i] = _rng.randf_range(-1.0, 1.0)
		_air_vy = vy
		var rise := _ease((vy + 2.0) / 4.0)
		var ls := "l" if _jside > 0.0 else "r"
		var ts := "r" if _jside > 0.0 else "l"
		var lo := -1.0 if ls == "l" else 1.0
		var to := -lo
		var flail := sin(_t * 13.0) * 0.12
		var fall_k := clampf(-vy / 14.0, 0.35, 1.0)
		# rising: the lead knee tucks, the other leg trails; arms swing up and out
		# to the sides, the one over the trailing leg higher
		var jump := {
			"leg_" + ls: Vector3(0.9 + _jv[0] * 0.15, 0, 0.08 * lo), "shin_" + ls: Vector3(-1.35, 0, 0),
			"leg_" + ts: Vector3(0.22 + _jv[1] * 0.12, 0, 0.1 * to), "shin_" + ts: Vector3(-0.8 - _jv[1] * 0.15, 0, 0),
			"arm_" + ts: Vector3(1.4 + _jv[2] * 0.15, 0, (1.15 + _jv[3] * 0.12) * to), "fore_" + ts: Vector3(0.5, 0, 0),
			"arm_" + ls: Vector3(0.9 + _jv[4] * 0.15, 0, (1.0 + _jv[5] * 0.12) * lo), "fore_" + ls: Vector3(0.75, 0, 0),
			"torso": Vector3(-0.05, 0.08 * _jside, 0.04 * _jv[6]), "head": Vector3(0.12, -0.04 * _jside, 0)}
		# coming down: the lead knee draws up to the chest, the other hangs lower
		var fall := {
			"leg_" + ls: Vector3(1.8 + flail * 0.25, 0, 0.14 * lo), "shin_" + ls: Vector3(-2.2, 0, 0),
			"leg_" + ts: Vector3(1.2 + _jv[7] * 0.15 - flail * 0.25, 0, 0.16 * to), "shin_" + ts: Vector3(-1.7, 0, 0),
			"arm_" + ts: Vector3(0.3, 0, (1.35 * fall_k + flail) * to), "fore_" + ts: Vector3(0.5, 0, 0),
			"arm_" + ls: Vector3(0.65, 0, (1.05 * fall_k + flail) * lo), "fore_" + ls: Vector3(0.75, 0, 0),
			"torso": Vector3(-0.12, 0.06 * _jside, 0.04 * _jv[6]), "head": Vector3(0.22, 0, 0)}
		for j in jump.keys():
			p[j] = (fall[j] as Vector3).lerp(jump[j], rise)
		if armed:
			p["arm_r"] = _guard()["arm_r"] + Vector3(0.5, 0, 0)
			p["fore_r"] = _guard()["fore_r"]

	# landing squash
	if grounded and not _was_grounded:
		_land_strength = clampf(absf(vertical_speed) / 14.0, 0.3, 1.0) if air_before > 0.08 else 0.0
		_land = 1.0 if _land_strength > 0.0 else 0.0
	if _land > 0.0:
		_land = maxf(_land - delta / 0.3, 0.0)
		var k := sin(_land * PI * 0.5) * _land_strength
		# the foot that hung lower in the fall touches down first and takes the
		# weight; the tucked lead foot comes down a beat later
		var late := smoothstep(0.0, 0.2, 1.0 - _land)
		var fs := "r" if _jside > 0.0 else "l"
		var ls := "l" if _jside > 0.0 else "r"
		var fo := 1.0 if fs == "r" else -1.0
		var vary := 1.0 + 0.2 * float(_jv[0])
		lift.y -= 0.34 * k * lerpf(0.8, 1.0, late)
		p["shin_" + fs] += Vector3(-1.4 * k, 0, 0)
		p["leg_" + fs] += Vector3(0.6 * k, 0, 0.1 * k * fo)
		p["shin_" + ls] += Vector3(-0.6 * k * late - 0.7 * (1.0 - late) * _land_strength, 0, 0)
		p["leg_" + ls] += Vector3(0.55 * k * late + 0.45 * (1.0 - late) * _land_strength, 0, -0.12 * k * fo)
		p["torso"] += Vector3(-0.35 * k, 0.08 * k * fo, -0.12 * k * fo * vary)
		p["arm_" + fs] += Vector3(0.3 * k, 0, 0.4 * k * fo)
		p["arm_" + ls] += Vector3(0.35 * k, 0, -0.85 * k * fo * vary)
	_was_grounded = grounded

	if talking:
		p["head"] += Vector3(sin(_t * 7.0) * 0.06, 0, 0)
		p["arm_r"] += Vector3(0.5 + sin(_t * 3.5) * 0.25, 0, 0.2)
		p["fore_r"] += Vector3(0.6, 0, 0)
	if gesture > 0.0:
		p["arm_r"] += Vector3(2.2 * gesture, 0, 0)
	if seated and grounded:
		# thighs level on the seat, shins down, forearms resting forward
		var br := sin(_t * 1.4) * 0.02
		p["leg_l"] = Vector3(1.5, 0, -0.1)
		p["leg_r"] = Vector3(1.45, 0, 0.1)
		p["shin_l"] = Vector3(-1.45, 0, 0)
		p["shin_r"] = Vector3(-1.5, 0, 0)
		p["hips"] = Vector3.ZERO
		p["torso"] = Vector3(-0.08 + br, 0, 0)
		p["arm_l"] = Vector3(0.55, 0, -0.08)
		p["arm_r"] = Vector3(0.6, 0, 0.08)
		p["fore_l"] = Vector3(0.9, 0, 0)
		p["fore_r"] = Vector3(0.95 + (0.6 if talking else 0.0), 0, 0)
		lift = Vector3(0, (seat_y + 0.05 - hip_y) * PIVOT_Y / hip_y, 0)
	if kneeling and grounded and not swimming:
		# right knee on the ground, left foot planted ahead, both hands pressing
		# down on the crewmate in front (pumping)
		var pump := sin(_t * 9.0)
		p["pivot"] = Vector3.ZERO
		p["hips"] = Vector3(0, 0.1, 0)
		p["leg_l"] = Vector3(1.45, 0, -0.14)
		p["shin_l"] = Vector3(-1.5, 0, 0)
		p["leg_r"] = Vector3(-0.05, 0, 0.12)
		p["shin_r"] = Vector3(-1.6, 0, 0)
		p["torso"] = Vector3(-0.55 - pump * 0.06, 0, 0)
		p["head"] = Vector3(0.35, 0, 0)
		p["arm_l"] = Vector3(0.75 + pump * 0.08, 0.1, -0.12)
		p["arm_r"] = Vector3(0.75 + pump * 0.08, -0.1, 0.12)
		p["fore_l"] = Vector3(0.35, 0, 0)
		p["fore_r"] = Vector3(0.35, 0, 0)
		lift = Vector3(0, -0.42 - pump * 0.015, 0)
	elif manning and grounded and not swimming:
		# crouched behind the gun, hands on the carriage
		var br := sin(_t * 2.0) * 0.02
		p["pivot"] = Vector3.ZERO
		p["leg_l"] = Vector3(1.0, 0, -0.22)
		p["shin_l"] = Vector3(-1.3, 0, 0)
		p["leg_r"] = Vector3(0.35, 0, 0.22)
		p["shin_r"] = Vector3(-1.25, 0, 0)
		p["torso"] = Vector3(-0.42 + br, 0, 0)
		p["head"] = Vector3(0.3, 0, 0)
		p["arm_l"] = Vector3(1.0, 0.15, -0.25)
		p["arm_r"] = Vector3(1.0, -0.15, 0.25)
		p["fore_l"] = Vector3(0.5, 0, 0)
		p["fore_r"] = Vector3(0.5, 0, 0)
		lift = Vector3(0, -0.24, 0)
	if carry == "rifle" and grounded and not swimming:
		var bob := sin(_t * 1.6) * 0.03
		p["arm_r"] = Vector3(0.35, 0.1, 0.18)
		p["fore_r"] = Vector3(1.45 + bob, 0, 0)
		p["arm_l"] = Vector3(0.95, 0.35, -0.1)
		p["fore_l"] = Vector3(1.35 - bob, 0, 0)
		p["torso"] += Vector3(0, -0.15, 0)
	if swimming:
		_swim_pose(p, delta)
		lift = Vector3.ZERO
	elif climbing:
		var ph := climb_phase * TAU / 0.68
		var cs := sin(ph)
		p["pivot"] = Vector3.ZERO
		p["hips"] = Vector3(0, 0, cs * 0.04)
		p["torso"] = Vector3(-0.12, cs * 0.1, 0)
		p["head"] = Vector3(0.25, 0, 0)
		p["arm_l"] = Vector3(2.55 + cs * 0.35, 0, -0.18)
		p["arm_r"] = Vector3(2.55 - cs * 0.35, 0, 0.18)
		p["fore_l"] = Vector3(0.7 - cs * 0.4, 0, 0)
		p["fore_r"] = Vector3(0.7 + cs * 0.4, 0, 0)
		p["leg_l"] = Vector3(0.75 - cs * 0.55, 0, -0.08)
		p["leg_r"] = Vector3(0.75 + cs * 0.55, 0, 0.08)
		p["shin_l"] = Vector3(-1.1 + cs * 0.5, 0, 0)
		p["shin_r"] = Vector3(-1.1 - cs * 0.5, 0, 0)
		lift = Vector3.ZERO
	if at_helm and grounded:
		# wide sea-legs stance, leaning into the wheel; the hands work the
		# spokes (one rises as the other drops) and the body follows the turn
		var st := clampf(helm_steer, -1.0, 1.0)
		var sway := sin(_t * 0.9) * 0.03
		p["hips"] = Vector3(0, st * 0.12, st * 0.04 + sway)
		p["leg_l"] = Vector3(0.12, 0, -0.2)
		p["leg_r"] = Vector3(-0.08, 0, 0.2)
		p["shin_l"] = Vector3(-0.22, 0, 0)
		p["shin_r"] = Vector3(-0.12, 0, 0)
		p["torso"] = Vector3(-0.14, st * 0.18, -st * 0.05 - sway)
		p["arm_l"] = Vector3(1.05 + st * 0.4, 0.1, 0.12 - st * 0.1)
		p["arm_r"] = Vector3(1.05 - st * 0.4, -0.1, -0.12 - st * 0.1)
		p["fore_l"] = Vector3(0.55 - st * 0.25, 0, 0)
		p["fore_r"] = Vector3(0.55 + st * 0.25, 0, 0)
		p["head"] = Vector3(0.12, -st * 0.25, 0)
		lift = Vector3(0, -0.04, 0)
	p["_lift"] = lift
	return p


# ==========================================================================
# Per-frame update
# ==========================================================================
func _process(delta: float) -> void:
	if not is_visible_in_tree() or pivot == null:
		return
	_t += delta
	# bare-handed fighting: close the hands while the fist stance is up
	set_fists(stance == "fist" and armed and not weapon_in_hand and ragdoll == null)
	if ragdoll != null:
		_update_physics(delta)  # hair and cloth still swing
		return
	_update_dangle(delta)
	var target := _locomotion(delta)
	var lift: Vector3 = target["_lift"]
	var sharp := 22.0

	if not _action.is_empty():
		_action["t"] += delta
		var u: float = _action["t"] / _action["dur"]
		_base = target
		var res := _action_pose(str(_action["name"]), clampf(u, 0.0, 1.0))
		var pose: Dictionary = res[0]
		var mask: String = res[1]
		_action_w = minf(_action_w + delta / 0.06, 1.0)
		for j in pose.keys():
			if mask == "upper" and not (j in UPPER):
				continue
			target[j] = (target[j] as Vector3).lerp(pose[j], _action_w)
		lift = lift.lerp(res[2], _action_w) if mask == "full" else lift + res[2]
		sharp = 38.0
		if u >= 1.0:
			_finish_action()

	if _soft_t > 0.0:
		_soft_t -= delta
		sharp = lerpf(sharp, 4.0, clampf(_soft_t / maxf(_soft_dur, 0.01), 0.0, 1.0))
	var k := 1.0 - exp(-sharp * delta)
	for j in JOINTS:
		var tv: Vector3 = target[j]
		if j == "pivot" and not _action.is_empty():
			_cur[j] = tv  # spins are applied exactly (no smoothing across 2*PI)
		else:
			_cur[j] = (_cur[j] as Vector3).lerp(tv, k)
	_lift = _lift.lerp(lift, k)

	pivot.rotation = _cur["pivot"]
	pivot.position = Vector3(0, hip_y, 0) + _lift * (hip_y / PIVOT_Y)
	hips.rotation = _cur["hips"]
	torso.rotation = _cur["torso"]
	_update_look(delta)
	# the posed head turn is shared by the neck and the head, the look layer on top
	var hp: Vector3 = _cur["head"]
	if neck:
		neck.rotation = hp * 0.4 + _look_total * 0.45
		head.rotation = hp * 0.6 + _look_total * 0.55
	else:
		head.rotation = hp + _look_total
	arm_l.rotation = _cur["arm_l"]
	arm_r.rotation = _cur["arm_r"]
	fore_l.rotation = _cur["fore_l"]
	fore_r.rotation = _cur["fore_r"]
	leg_l.rotation = _cur["leg_l"]
	leg_r.rotation = _cur["leg_r"]
	shin_l.rotation = _cur["shin_l"]
	shin_r.rotation = _cur["shin_r"]
	_foot_ik(delta)
	# wrist (only the weapon socket turns; e.g. a thrust lines the blade up with the arm)
	if hand_r:
		hand_r.rotation = _cur["hand_r"]
	if _tail and is_instance_valid(_tail):
		var wag := 1.0 + clampf(ground_speed * 0.15, 0.0, 1.0)
		_tail.rotation = Vector3(0.75 + sin(_t * 3.1) * 0.08, sin(_t * 2.3) * 0.35 * wag, 0.0)
	if auto_point_guns:
		point_guns()
	_update_physics(delta)


## Foot IK. The animator poses legs for flat ground at the character's feet;
## here each foot's ground is probed: the hips drop by the lower foot's dip
## and each leg is re-solved (thigh swing + knee bend, in the leg's plane) so
## its ankle lands that far above the real ground. On flat ground nothing
## changes.
func _foot_ik(delta: float) -> void:
	var want := foot_ik and grounded and not swimming and not climbing and not seated and not at_helm and not kneeling and not manning \
		and ragdoll == null and current_action() != "getup" and is_inside_tree()
	_ik_w = move_toward(_ik_w, 1.0 if want else 0.0, delta * 6.0)
	if _ik_w <= 0.0:
		_ik_h = Vector2.ZERO
		_ik_drop = 0.0
		return
	var vp := get_viewport()
	var cam := vp.get_camera_3d() if vp else null
	if cam and cam.global_position.distance_squared_to(global_position) > 40.0 * 40.0:
		return
	if not _ik_body_found:
		_ik_body_found = true
		var n := get_parent()
		while n:
			if n is CollisionObject3D:
				_ik_body = (n as CollisionObject3D).get_rid()
				break
			n = n.get_parent()
	var space := get_world_3d().direct_space_state
	var up := global_basis.y.normalized()
	var sc := global_basis.get_scale().y
	var root := global_position
	var hs := [0.0, 0.0]
	var legs := [[leg_l, shin_l], [leg_r, shin_r]]
	for i in range(2):
		var shin: Node3D = legs[i][1]
		var ankle := shin.global_transform * Vector3(0, shin_l.position.y, 0)
		var from := Vector3(ankle.x, root.y + 0.55 * sc, ankle.z)
		var q := PhysicsRayQueryParameters3D.create(from, Vector3(ankle.x, root.y - 0.6 * sc, ankle.z), 1)
		if _ik_body.is_valid():
			q.exclude = [_ik_body]
		var hit := space.intersect_ray(q)
		var h := 0.0
		if not hit.is_empty() and (hit["normal"] as Vector3).y > 0.5:
			h = clampf((hit["position"] as Vector3).y - root.y, -0.45 * sc, 0.45 * sc)
		hs[i] = h
	var k := 1.0 - exp(-18.0 * delta)
	_ik_h = _ik_h.lerp(Vector2(hs[0], hs[1]), k)
	_ik_drop = lerpf(_ik_drop, minf(minf(_ik_h.x, _ik_h.y), 0.0), k)
	var drop := _ik_drop * _ik_w
	pivot.position.y += drop / sc
	var l1 := shin_l.position.length() * sc
	var l2 := absf(shin_l.position.y) * sc
	for i in range(2):
		var adj := ((_ik_h.x if i == 0 else _ik_h.y) - _ik_drop) * _ik_w
		if absf(adj) < 0.004:
			continue
		var leg: Node3D = legs[i][0]
		var shin: Node3D = legs[i][1]
		var hip := leg.global_position
		var ankle := shin.global_transform * Vector3(0, shin_l.position.y, 0)
		var target := ankle + up * adj
		# work in the thigh's parent frame turned by the thigh's own twist (sagittal plane = its y/z)
		var pb := leg.get_parent_node_3d().global_basis.orthonormalized() * Basis(Vector3.UP, leg.rotation.y)
		var v := pb.inverse() * (target - hip)
		var d := clampf(Vector2(v.y, v.z).length(), absf(l1 - l2) + 0.01, l1 + l2 - 0.005)
		var knee := acos(clampf((l1 * l1 + l2 * l2 - d * d) / (2.0 * l1 * l2), -1.0, 1.0))
		var alpha := acos(clampf((l1 * l1 + d * d - l2 * l2) / (2.0 * l1 * d), -1.0, 1.0))
		var theta := atan2(-v.z, -v.y)
		var r := leg.rotation
		leg.rotation = Vector3(theta + alpha, r.y, r.z)
		shin.rotation = Vector3(-(PI - knee), shin.rotation.y, shin.rotation.z)


## Head and neck life on top of every pose:
## * idle: glances around (yaw), curious head tilts, a slight breathing nod;
## * walking / running: the head counter-rotates the shoulders' twist so the
##   gaze stays forward, nods with each footfall and tilts against the sway;
## * turning: the head leads into the turn.
## Fades out while an action (attack, emote...) poses the head itself.
func _update_look(delta: float) -> void:
	if delta <= 0.0:
		return
	var spd := ground_speed
	if spd <= 0.01 and move_speed > 0.01:
		spd = move_speed * 1.4
	var walk := clampf(spd / 1.5, 0.0, 1.0) if grounded else 0.0
	var idle := (1.0 - walk) if grounded else 0.0
	var free := 1.0 - (_action_w if not _action.is_empty() else 0.0)
	var tgt := Vector3.ZERO
	# idle glances: hold a look for a few seconds, then pick another
	_glance_t -= delta
	if _glance_t <= 0.0:
		_glance_t = _rng.randf_range(1.4, 3.6)
		var wide := 0.35 if (talking or armed) else 1.0
		if _rng.randf() < 0.25:
			_glance = Vector3(_rng.randf_range(-0.06, 0.04), 0.0, 0.0)  # back to ahead
		else:
			_glance = Vector3(_rng.randf_range(-0.22, 0.12), _rng.randf_range(-0.7, 0.7) * wide, _rng.randf_range(-0.2, 0.2) * wide)
	tgt += _glance * idle
	# never quite still: slow drift + breathing
	tgt += Vector3(sin(_t * 1.7) * 0.03 + sin(_t * 0.61) * 0.025, sin(_t * 0.53) * 0.06 + sin(_t * 1.31) * 0.025, sin(_t * 0.43) * 0.035) * idle
	# look target (the player's camera aim): soft, within the neck's range
	if look_weight > 0.0 and is_inside_tree() and head:
		var d := global_basis.orthonormalized().inverse() * (look_target - head.global_position)
		if d.length_squared() > 0.01:
			var ly := clampf(atan2(-d.x, -d.z), -1.15, 1.15)
			var lp := clampf(atan2(d.y, Vector2(d.x, d.z).length()), -0.45, 0.5)
			tgt = tgt * (1.0 - look_weight * 0.85) + Vector3(lp, ly, -ly * 0.08) * look_weight
	# moving: look a little where you're heading, gentle drift
	tgt += Vector3(0.0, -local_move.x * 0.25, 0.0) * walk
	tgt += Vector3(0.0, sin(_t * 0.7) * 0.05, sin(_t * 0.9) * 0.03) * walk
	# turn lead from the body's yaw rate
	var yaw := global_rotation.y if is_inside_tree() else rotation.y
	if _prev_yaw != INF:
		var rate := wrapf(yaw - _prev_yaw, -PI, PI) / delta
		var lead := clampf(rate * 0.09, -0.5, 0.5)
		_turn_lead = lerpf(_turn_lead, lead, 1.0 - exp(-10.0 * delta))
	_prev_yaw = yaw
	tgt += Vector3(0, _turn_lead, _turn_lead * 0.2)
	tgt *= free
	# gaze steadying against the shoulders' twist and sway (partial, so the
	# head still rides the body), applied directly so it stays in phase
	var twist: float = (_cur["hips"] as Vector3).y + (_cur["torso"] as Vector3).y
	var roll: float = (_cur["hips"] as Vector3).z + (_cur["torso"] as Vector3).z
	_gait_look = Vector3(0.0, -twist * 0.7, -roll * 0.5) * walk * free
	# keep the eyes up when the whole body leans (the player's speed lean)
	if is_inside_tree():
		var fy := clampf((-global_basis.z.normalized()).y, -0.9, 0.9)
		_gait_look.x += -asin(fy) * 0.6 * free
	# Springs (fixed substeps so slow frames stay stable):
	#  * the look itself: slightly underdamped, a head turn settles with life
	#  * inertia: the body's angular / vertical acceleration pushes the head
	var body := Vector3((_cur["hips"] as Vector3).x + (_cur["torso"] as Vector3).x, twist, roll)
	var body_w := Vector3.ZERO if _prev_body == Vector3.INF else (body - _prev_body) / delta
	var body_a := ((body_w - _prev_body_w) / delta).clamp(Vector3(-60, -60, -60), Vector3(60, 60, 60))
	_prev_body = body
	_prev_body_w = body_w
	var ly := _lift.y
	var lvy := 0.0 if _prev_lift_y == INF else (ly - _prev_lift_y) / delta
	var lay := clampf((lvy - _prev_lift_vy) / delta, -40.0, 40.0)
	_prev_lift_y = ly
	_prev_lift_vy = lvy
	var force := -body_a * 0.12 + Vector3(-lay * 0.32, 0.0, 0.0)
	force *= free
	var steps := clampi(ceili(delta / (1.0 / 120.0)), 1, 12)
	var h := delta / steps
	for i in range(steps):
		var w1 := 9.5
		_look_v += ((tgt - _look) * w1 * w1 - _look_v * 2.0 * 0.62 * w1) * h
		_look += _look_v * h
		var w2 := 13.0
		_hv += (-_hs * w2 * w2 - _hv * 2.0 * 0.4 * w2 + force) * h
		_hs += _hv * h
	_hs = _hs.clamp(Vector3(-0.35, -0.35, -0.35), Vector3(0.35, 0.35, 0.35))
	_look_total = _look + _gait_look + _hs


## Out of combat (velocity changes instantly, so these are all pose): a lean
## into the first step when you set off, a planted stop with a dip when you
## let go at a jog or run, and a braced skid when you reverse at a run.
func _casual_moves(p: Dictionary, delta: float, spd: float, casual: bool) -> void:
	var wdir := global_basis.orthonormalized() * Vector3(local_move.x, 0.0, -local_move.y) if spd > 0.2 else Vector3.ZERO
	if not casual:
		_start = 0.0
		_stop = 0.0
		_skid = 0.0
	elif spd > 2.5 and _prev_spd < 0.5 and _slow_t > 0.15:
		_start = 1.0
	# (the player brakes over a few ticks, and a reversal often passes through a
	# moment of no input, so both look back over a short window, not one frame)
	if casual and spd < 0.5 and _prev_spd >= 0.5 and _peak_spd > 4.0:
		_stop = 1.0
		_stop_k = clampf(0.5 + (_peak_spd - 4.0) / 8.0, 0.5, 1.0)
		_stop_side = 1.0 if sin(_phase) >= 0.0 else -1.0
		_start = 0.0
	if casual and spd > 4.5 and _fast_t < 0.3 and _skid < 0.5 and _fast_dir.dot(wdir.normalized()) < -0.3:
		_skid = 1.0
		_skid_k = smoothstep(4.5, 9.0, maxf(spd, _peak_spd))
		_start = 0.0
		_stop = 0.0
		if is_inside_tree():
			var fx := get_node_or_null("/root/FX")
			if fx:
				fx.call("dust", global_position - _fast_dir * 0.3, int(6 + 8 * _skid_k), 0.5 + 0.3 * _skid_k)
				fx.call("sfx", "land", global_position, -7.0 + 4.0 * _skid_k, 0.1, 1.35)
	_slow_t = _slow_t + delta if spd < 0.5 else 0.0
	_peak_spd = maxf(spd, _peak_spd - 20.0 * delta)
	_prev_spd = spd
	if spd > 4.0:
		_fast_dir = wdir.normalized()
		_fast_t = 0.0
	else:
		_fast_t += delta
	if _start > 0.0:
		_start = maxf(_start - delta / 0.35, 0.0)
		var e := sin(_start * PI * 0.5)
		p["torso"] += Vector3(-0.28 * e, 0, 0)
		p["head"] += Vector3(0.12 * e, 0, 0)
	if _stop > 0.0:
		_stop = maxf(_stop - delta / 0.4, 0.0)
		var e := sin(_stop * PI * 0.5) * _stop_k
		# the forward foot plants out in front, the back knee folds, the chest
		# carries on a little and the arms swing through
		var fs := "l" if _stop_side > 0.0 else "r"
		var bs := "r" if _stop_side > 0.0 else "l"
		p["leg_" + fs] += Vector3(0.42 * e, 0, 0)
		p["shin_" + fs] += Vector3(-0.25 * e, 0, 0)
		p["leg_" + bs] += Vector3(-0.3 * e, 0, 0)
		p["shin_" + bs] += Vector3(-0.6 * e, 0, 0)
		p["torso"] += Vector3(-0.2 * e, 0, 0)
		p["arm_l"] += Vector3(0.4 * e, 0, -0.1 * e)
		p["arm_r"] += Vector3(0.4 * e, 0, 0.1 * e)
	if _skid > 0.0:
		_skid = maxf(_skid - delta / 0.32, 0.0)
		var e := sin(_skid * PI * 0.5) * _skid_k
		# lean toward the new way (in body space, so it holds while you turn
		# round), knees deep and braced, arms out for balance
		p["torso"] += Vector3(-local_move.y * 0.45 * e, 0, -local_move.x * 0.45 * e)
		p["leg_l"] += Vector3(0.35 * e, 0, -0.12 * e)
		p["leg_r"] += Vector3(0.35 * e, 0, 0.12 * e)
		p["shin_l"] += Vector3(-0.65 * e, 0, 0)
		p["shin_r"] += Vector3(-0.65 * e, 0, 0)
		p["arm_l"] += Vector3(0.3 * e, 0, -0.75 * e)
		p["arm_r"] += Vector3(0.3 * e, 0, 0.75 * e)


## How far the stop / skid drop the hips this frame.
func _casual_dip() -> float:
	return 0.09 * sin(_stop * PI * 0.5) * _stop_k + 0.12 * sin(_skid * PI * 0.5) * _skid_k


# ==========================================================================
# Ragdoll + getting back up
# ==========================================================================
## Brace pose for a living body thrown off its feet (local eulers, rig terms):
## arms flung out to the sides and a little forward, elbows bent, knees
## pulled up, chin tucked.
const BRACE := {
	"chest": Vector3(-0.25, 0, 0), "head": Vector3(-0.15, 0, 0),
	"arm_l": Vector3(0.7, 0, -1.05), "arm_r": Vector3(0.7, 0, 1.05),
	"fore_l": Vector3(0.8, 0, 0), "fore_r": Vector3(0.8, 0, 0),
	"thigh_l": Vector3(0.85, 0, -0.12), "thigh_r": Vector3(0.6, 0, 0.12),
	"shin_l": Vector3(-1.3, 0, 0), "shin_r": Vector3(-1.0, 0, 0),
}
const BRACE_WIGGLE := {
	"arm_l": Vector3(0.35, 0, 0.25), "arm_r": Vector3(0.35, 0, 0.25),
	"fore_l": Vector3(0.3, 0, 0), "fore_r": Vector3(0.3, 0, 0),
	"thigh_l": Vector3(0.2, 0, 0), "thigh_r": Vector3(0.2, 0, 0),
}


## Turn the body into a physics ragdoll launched with `velocity` (the hit).
## The upper body is flung a little harder than the legs, so a hit from the
## front tips the character over backwards.
## alive: the body braces (stiff joints, arms out, knees up); dead goes limp.
func start_ragdoll(velocity: Vector3, spin: Vector3 = Vector3.ZERO, alive: bool = true) -> Ragdoll:
	_net_send("ragdoll", [velocity, spin, alive])
	end_ragdoll()
	if not _action.is_empty():
		_finish_action()
	var r := Ragdoll.create(get_tree())
	var hw := absf(leg_l.position.x) + 0.03
	var neck_y := neck.position.y if neck else 0.5
	var head_node: Node3D = neck if neck else head
	var head_c := Vector3(0, (head.position.y if neck else 0.0) + 0.11, 0)
	var shin_len := shin_l.position.y  # shins are about as long as thighs
	r.add_part("pelvis", hips, {"capsule": [Vector3(-hw, -0.03, 0), Vector3(hw, -0.03, 0), 0.12]}, 12.0)
	r.add_part("chest", torso, {"capsule": [Vector3(0, 0.14, 0), Vector3(0, neck_y * 0.82, 0), 0.14]}, 16.0, "pelvis",
		{"x": [-0.75, 0.45], "y": [-0.6, 0.6], "z": [-0.4, 0.4]})
	r.add_part("head", head_node, {"sphere": [head_c, 0.125]}, 5.0, "chest",
		{"x": [-0.7, 0.6], "y": [-0.9, 0.9], "z": [-0.4, 0.4]})
	for side in [-1.0, 1.0]:
		var sfx := "_l" if side < 0 else "_r"
		var arm: Node3D = arm_l if side < 0 else arm_r
		var fore: Node3D = fore_l if side < 0 else fore_r
		var hand: Node3D = hand_l if side < 0 else hand_r
		var leg: Node3D = leg_l if side < 0 else leg_r
		var shin: Node3D = shin_l if side < 0 else shin_r
		var out_z: Array = [-1.6, 0.3] if side < 0 else [-0.3, 1.6]
		r.add_part("arm" + sfx, arm, {"capsule": [Vector3(0, -0.03, 0), fore.position, 0.055]}, 2.5, "chest",
			{"x": [-1.2, 3.0], "y": [-0.9, 0.9], "z": out_z})
		r.add_part("fore" + sfx, fore, {"capsule": [Vector3.ZERO, hand.position + Vector3(0, -0.06, 0), 0.05]}, 1.8, "arm" + sfx,
			{"x": [0.0, 2.4]})
		var leg_z: Array = [-0.75, 0.2] if side < 0 else [-0.2, 0.75]
		# (starts below the hip so it doesn't already touch the chest: it has to bump it)
		r.add_part("thigh" + sfx, leg, {"capsule": [Vector3(0, -0.1, 0), shin.position, 0.075]}, 7.0, "pelvis",
			{"x": [-0.45, 1.5], "y": [-0.5, 0.5], "z": leg_z})
		r.add_part("shin" + sfx, shin, {"capsule": [Vector3.ZERO, Vector3(0, shin_len * 0.98, 0.0), 0.062]}, 4.0, "thigh" + sfx,
			{"x": [-2.5, 0.0]})
	r.enable_self_collision()
	r.launch(velocity, spin, {"chest": 1.15, "head": 1.25, "arm_l": 1.1, "arm_r": 1.1, "fore_l": 1.1, "fore_r": 1.1,
		"thigh_l": 0.7, "thigh_r": 0.7, "shin_l": 0.55, "shin_r": 0.55})
	r.drive()
	if alive:
		r.set_targets(BRACE, BRACE_WIGGLE)
		r.stiffness = 0.35
		r.stiffness_target = 1.0
	ragdoll = r
	return r


## Drop the ragdoll; the rig keeps the last pose until the animator takes over.
func end_ragdoll() -> void:
	if ragdoll != null and is_instance_valid(ragdoll):
		ragdoll.restore_rig()
		ragdoll.queue_free()
	ragdoll = null


## Where the fallen body is: pelvis position, the direction from the hips to
## the head (flat), whether it lies face up, and the hips' world transform.
func ragdoll_rest_info() -> Dictionary:
	var hg := hips.global_transform
	var cg := torso.global_transform
	var axis := cg.basis.orthonormalized().y
	var d := Vector3(axis.x, 0, axis.z)
	if d.length() < 0.05:
		d = -global_basis.z
	d = d.normalized()
	var front := -cg.basis.orthonormalized().z
	return {"pelvis": hg.origin, "head_dir": d, "face_up": front.y > 0.0, "hips_xform": hg}


## Snap back to a plain standing pose (respawn).
func reset_pose() -> void:
	_net_send("reset_pose", [])
	end_ragdoll()
	if not _action.is_empty():
		_finish_action()
	for j in JOINTS:
		_cur[j] = Vector3.ZERO
	_lift = Vector3.ZERO
	pivot.rotation = Vector3.ZERO
	pivot.position = Vector3(0, hip_y, 0)
	hips.transform = Transform3D.IDENTITY


## Start the get-up animation from wherever the ragdoll left the body.
## The character's root must already stand on the spot and face the right
## way (face up: head behind, face down: head in front). `hips_xform` is the
## hips' world transform captured before the root was turned.
func begin_getup(face_up: bool, duration: float, hips_xform: Transform3D) -> void:
	_net_send("getup", [face_up, duration, hips_xform])
	_capture_ragdoll_pose(face_up, hips_xform)
	_getup_from = _cur.duplicate()
	_getup_lift = _lift
	_getup_face_up = face_up
	play("getup", duration)
	_action_w = 1.0


## Leave the ragdoll without an animation: the body eases from where the
## physics left it into whatever the locomotion wants (e.g. treading water
## after floating back up).
func recover_from_ragdoll(face_up: bool, hips_xform: Transform3D, blend: float = 0.6) -> void:
	_net_send("recover", [face_up, hips_xform, blend])
	_capture_ragdoll_pose(face_up, hips_xform)
	_soft_t = blend
	_soft_dur = blend


func _capture_ragdoll_pose(face_up: bool, hips_xform: Transform3D) -> void:
	end_ragdoll()
	pivot.rotation = Vector3(PI * 0.5 if face_up else -PI * 0.5, 0, 0)
	pivot.position = global_transform.affine_inverse() * hips_xform.origin
	_lift = (pivot.position - Vector3(0, hip_y, 0)) * (PIVOT_Y / hip_y)
	hips.global_transform = hips_xform
	# (only its turn: the pivot already sits where the hips were, and a
	# global transform carries float slack in scale)
	hips.transform = Transform3D(Basis(hips.basis.orthonormalized().get_rotation_quaternion()), Vector3.ZERO)
	_cur["pivot"] = pivot.rotation
	_cur["hips"] = hips.rotation
	for j in ["torso", "arm_l", "fore_l", "arm_r", "fore_r", "leg_l", "shin_l", "leg_r", "shin_r", "hand_r"]:
		var n: Node3D = get(j)
		if n:
			_cur[j] = n.rotation
	_cur["head"] = (neck.rotation / 0.4) if neck else head.rotation
	_look = Vector3.ZERO
	_look_v = Vector3.ZERO
	_hs = Vector3.ZERO
	_hv = Vector3.ZERO


func _lift_for(pelvis_h: float) -> float:
	return (pelvis_h - hip_y) * PIVOT_Y / hip_y


## Get-up keys. Face up: roll the knees up, sit up pushing off one hand, tuck
## into a crouch, stand. Face down: push up, knees under, crouch, stand.
func _getup_pose(u: float) -> Array:
	var keys: Array
	var lifts: Array
	var crouch := {"pivot": Vector3.ZERO, "hips": Vector3.ZERO, "torso": Vector3(-0.55, 0, 0), "head": Vector3(0.3, 0, 0),
		"arm_l": Vector3(0.65, 0, -0.2), "fore_l": Vector3(0.7, 0, 0), "arm_r": Vector3(0.55, 0, 0.2), "fore_r": Vector3(0.7, 0, 0),
		"leg_l": Vector3(1.5, 0, -0.12), "shin_l": Vector3(-2.1, 0, 0), "leg_r": Vector3(1.35, 0, 0.12), "shin_r": Vector3(-1.95, 0, 0),
		"hand_r": Vector3.ZERO}
	if _getup_face_up:
		var flat := {"pivot": Vector3(PI * 0.5, 0, 0), "hips": Vector3.ZERO, "torso": Vector3(-0.2, 0, 0), "head": Vector3(-0.4, 0, 0),
			"arm_l": Vector3(-0.3, 0, -0.45), "fore_l": Vector3(0.3, 0, 0), "arm_r": Vector3(-0.3, 0, 0.45), "fore_r": Vector3(0.3, 0, 0),
			"leg_l": Vector3(1.0, 0, -0.08), "shin_l": Vector3(-1.75, 0, 0), "leg_r": Vector3(0.8, 0, 0.08), "shin_r": Vector3(-1.5, 0, 0),
			"hand_r": Vector3.ZERO}
		var sit := {"pivot": Vector3(0.3, 0, 0), "hips": Vector3.ZERO, "torso": Vector3(-0.5, 0.15, 0), "head": Vector3(-0.1, 0, 0),
			"arm_l": Vector3(-0.75, 0, -0.35), "fore_l": Vector3(0.15, 0, 0), "arm_r": Vector3(0.55, 0, 0.3), "fore_r": Vector3(0.5, 0, 0),
			"leg_l": Vector3(1.6, 0, -0.1), "shin_l": Vector3(-2.25, 0, 0), "leg_r": Vector3(1.25, 0, 0.12), "shin_r": Vector3(-1.4, 0, 0),
			"hand_r": Vector3.ZERO}
		keys = [[0.0, _getup_from], [0.2, flat], [0.46, sit], [0.72, crouch], [1.0, {}]]
		lifts = [[0.0, _getup_lift], [0.2, Vector3(0, _lift_for(0.13), 0)], [0.46, Vector3(0, _lift_for(0.16), 0)],
			[0.72, Vector3(0, _lift_for(0.5), 0)], [1.0, Vector3.ZERO]]
	else:
		var prone := {"pivot": Vector3(-PI * 0.5, 0, 0), "hips": Vector3.ZERO, "torso": Vector3(0.15, 0, 0), "head": Vector3(0.55, 0, 0),
			"arm_l": Vector3(1.35, 0, -0.3), "fore_l": Vector3(1.7, 0, 0), "arm_r": Vector3(1.35, 0, 0.3), "fore_r": Vector3(1.7, 0, 0),
			"leg_l": Vector3(0.0, 0, -0.06), "shin_l": Vector3(-0.2, 0, 0), "leg_r": Vector3(0.0, 0, 0.06), "shin_r": Vector3(-0.2, 0, 0),
			"hand_r": Vector3.ZERO}
		var kneel := {"pivot": Vector3(-1.0, 0, 0), "hips": Vector3.ZERO, "torso": Vector3(0.25, 0, 0), "head": Vector3(0.6, 0, 0),
			"arm_l": Vector3(1.15, 0, -0.15), "fore_l": Vector3(0.2, 0, 0), "arm_r": Vector3(1.15, 0, 0.15), "fore_r": Vector3(0.2, 0, 0),
			"leg_l": Vector3(1.0, 0, -0.1), "shin_l": Vector3(-1.55, 0, 0), "leg_r": Vector3(1.1, 0, 0.1), "shin_r": Vector3(-1.6, 0, 0),
			"hand_r": Vector3.ZERO}
		keys = [[0.0, _getup_from], [0.18, prone], [0.45, kneel], [0.72, crouch], [1.0, {}]]
		lifts = [[0.0, _getup_lift], [0.18, Vector3(0, _lift_for(0.17), 0)], [0.45, Vector3(0, _lift_for(0.44), 0)],
			[0.72, Vector3(0, _lift_for(0.5), 0)], [1.0, Vector3.ZERO]]
	var pose := _keys(u, keys)
	var lift := Vector3.ZERO
	for i in range(lifts.size() - 1):
		if u <= lifts[i + 1][0] or i == lifts.size() - 2:
			var x := clampf((u - lifts[i][0]) / maxf(lifts[i + 1][0] - lifts[i][0], 0.0001), 0.0, 1.0)
			lift = (lifts[i][1] as Vector3).lerp(lifts[i + 1][1], _ease(x))
			break
	return [pose, "full", lift]


## Swimming poses. Moving: breaststroke with the body tipped forward (arms
## sweep out and back, frog kick on the off-beat, head held up). Still:
## upright treading water (sculling hands, cycling legs). Diving: head first.
func _swim_pose(p: Dictionary, delta: float) -> void:
	var move := clampf(ground_speed / 3.0, 0.0, 1.0)
	_swim_move = move_toward(_swim_move, move, delta * 2.5)
	var m := _swim_move
	_swim_phase += delta * lerpf(1.6, 1.15, m) * TAU
	var ph := _swim_phase
	var s1 := sin(ph)
	var pull := maxf(0.0, -s1)
	var tuck := maxf(0.0, s1)
	var kick := maxf(0.0, sin(ph - 1.6))
	# breaststroke
	var b := {
		"pivot": Vector3(-0.95, 0, 0), "hips": Vector3.ZERO, "torso": Vector3(0.15, 0, 0), "head": Vector3(0.75, 0, 0),
		"arm_l": Vector3(2.5 - pull * 1.0 - tuck * 0.9, 0, -(0.2 + pull * 0.9)), "arm_r": Vector3(2.5 - pull * 1.0 - tuck * 0.9, 0, 0.2 + pull * 0.9),
		"fore_l": Vector3(0.15 + tuck * 1.6, 0, 0), "fore_r": Vector3(0.15 + tuck * 1.6, 0, 0),
		"leg_l": Vector3(0.1 + kick * 0.9, 0, -(0.05 + kick * 0.4)), "leg_r": Vector3(0.1 + kick * 0.9, 0, 0.05 + kick * 0.4),
		"shin_l": Vector3(-0.15 - kick * 1.5, 0, 0), "shin_r": Vector3(-0.15 - kick * 1.5, 0, 0)}
	# treading water
	var tw := sin(_t * 3.2)
	var tc := cos(_t * 3.4)
	var tr := {
		"pivot": Vector3(-0.12, 0, 0), "hips": Vector3(0, 0, tw * 0.03), "torso": Vector3(-0.05, tw * 0.06, 0), "head": Vector3(0.1, 0, 0),
		"arm_l": Vector3(0.55, tw * 0.45, -(0.95 + tw * 0.15)), "arm_r": Vector3(0.55, -tw * 0.45, 0.95 - tw * 0.15),
		"fore_l": Vector3(0.45, 0, 0), "fore_r": Vector3(0.45, 0, 0),
		"leg_l": Vector3(0.55 + tc * 0.35, 0, -0.12), "leg_r": Vector3(0.55 - tc * 0.35, 0, 0.12),
		"shin_l": Vector3(-0.95 + tc * 0.4, 0, 0), "shin_r": Vector3(-0.95 - tc * 0.4, 0, 0)}
	for j in b.keys():
		p[j] = (tr[j] as Vector3).lerp(b[j], m)
	if diving:
		var fl := sin(_t * 9.0)
		var d := {"pivot": Vector3(-1.45, 0, 0), "torso": Vector3(0.0, 0, 0), "head": Vector3(0.2, 0, 0),
			"arm_l": Vector3(2.95, 0, -0.12), "arm_r": Vector3(2.95, 0, 0.12), "fore_l": Vector3(0.1, 0, 0), "fore_r": Vector3(0.1, 0, 0),
			"leg_l": Vector3(fl * 0.3, 0, -0.04), "leg_r": Vector3(-fl * 0.3, 0, 0.04), "shin_l": Vector3(-0.3, 0, 0), "shin_r": Vector3(-0.3, 0, 0)}
		for j in d.keys():
			p[j] = d[j]


## Two-bone IK for the left arm: put the left hand on `target` (world), with
## the elbow bending toward `pole` (world direction). Run after the pose has
## been applied (e.g. a rifleman keeping his off hand on the stock).
func reach_left_hand(target: Vector3, pole: Vector3) -> void:
	if ragdoll != null or arm_l == null or fore_l == null or hand_l == null:
		return
	var sc := global_basis.get_scale().x
	var shoulder := arm_l.global_position
	var l1 := fore_l.position.length() * sc
	var l2 := (hand_l.position + Vector3(0, -0.05, 0)).length() * sc
	var to := target - shoulder
	var d := clampf(to.length(), 0.05, (l1 + l2) * 0.999)
	var dir := to.normalized()
	var cos_e := clampf((l1 * l1 + l2 * l2 - d * d) / (2.0 * l1 * l2), -1.0, 1.0)
	var bend := PI - acos(cos_e)
	var cos_a := clampf((l1 * l1 + d * d - l2 * l2) / (2.0 * l1 * d), -1.0, 1.0)
	var a := acos(cos_a)
	# the elbow sits toward the pole, in the plane of (shoulder->target, pole)
	var pp := pole - dir * pole.dot(dir)
	if pp.length() < 0.05:
		pp = Vector3.DOWN - dir * Vector3.DOWN.dot(dir)
	pp = pp.normalized()
	var upper := dir * cos(a) + pp * sin(a)
	var elbow := shoulder + upper * l1
	var fore_dir := (target - elbow).normalized()
	# forearm bends (local +x rotation) from the arm's -Y toward its -Z
	var n := fore_dir - upper * fore_dir.dot(upper)
	n = n.normalized() if n.length() > 0.001 else pp
	var y_axis := -upper
	var z_axis := -n
	var x_axis := y_axis.cross(z_axis).normalized()
	arm_l.global_basis = Basis(x_axis, y_axis, z_axis).scaled(Vector3(sc, sc, sc))
	fore_l.rotation = Vector3(bend, 0, 0)


# ==========================================================================
# Co-op mirroring
# ==========================================================================
func _net_send(what: String, args: Array) -> void:
	if not net_sync or not is_inside_tree():
		return
	var net := get_node_or_null("/root/Net")
	if net and net.active:
		net.event(self, what, args)


## Settle a ragdoll into a limp body (death) - mirrored.
func relax_ragdoll() -> void:
	_net_send("relax", [])
	if ragdoll != null and is_instance_valid(ragdoll):
		ragdoll.relax()


## Another player's copy of this body did something (see _net_send).
func net_event(what: String, args: Array) -> void:
	match what:
		"play":
			play(str(args[0]), float(args[1]))
		"stop":
			stop_action()
		"ragdoll":
			start_ragdoll(args[0], args[1], bool(args[2]))
		"reset_pose":
			reset_pose()
		"getup":
			begin_getup(bool(args[0]), float(args[1]), args[2])
		"recover":
			recover_from_ragdoll(bool(args[0]), args[1], float(args[2]))
		"relax":
			relax_ragdoll()

