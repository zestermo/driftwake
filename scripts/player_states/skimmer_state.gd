extends PlayerState
## Riding the skimmer (1.28.1; GadgetBelt.fire forces it with {"tier", "at"}). Added to the captain's state machine at
## runtime by GadgetBelt ("Skimmer"). Numbers in GadgetData ("skimmer") and below.
## Launched from the shore or the ship's side (a hop out onto the water at "at") or from swimming (right where you
## are). The captain stands side-on at the boom (the board runs to their left); WASD steers it toward that way,
## camera-relative, turning at TURN; the sail drives it at the tier's top speed times wind_k (the wind's angle: a
## beam reach is fastest, into the wind slowest), and with no steer held it eases off to COAST of that. It rides the
## real swell (Ocean.surface_at on the wave clock), banks into turns and throws spray. Mk III hops off the swell on
## Space. A blow, a rock or a shore it runs into, or running aground throws you off into the water (Swim); F stows it.
## Co-op: the board rides on the captain's lean node (synced with the snapshot); the flag NF_SKIM tells a crewmate's
## screen to build the board on the puppet; spray and the wake are drawn on every screen from the snapshot (ride_fx).

const TURN := 2.6
const ACCEL := 5.0
const DECEL := 3.5
const COAST := 0.35
## How fast the board starts from a launch.
const PUSH := 3.0
## The board's deck rides this far above the water.
const RIDE_H := 0.14
const HOP_GRAVITY := 20.0
## A launch from the shore or a deck reaches the water in this long.
const LAUNCH_T := 0.45
## Running into something faster than this throws you off; slower, you just stop against it.
const CRASH_SPEED := 2.5
## Water shallower than this under the board: aground.
const AGROUND := 0.3
## Launching needs water at least this deep.
const LAUNCH_DEPTH := 0.8
## (1.31) Out of a jump or a fall, the skimmer comes out under you over water this far below or nearer.
const AIR_MOUNT_H := 12.0
## (1.31) Jumping off: up this fast, carrying this share of the ride's speed.
const JUMP_OFF_UP := 8.5
const JUMP_OFF_CARRY := 0.8
const BANK_MAX := 0.42
const BANK_K := 0.045
const FX_EVERY := 0.08

var tier := 0
## The board's travel direction (yaw: forward = (-sin, -cos)); the captain faces 90 degrees right of it.
var heading := 0.0
var speed := 0.0
var _turn := 0.0
var _vy := 0.0
var _air := false
var _launch_t := -1.0
var _launch_from := Vector3.ZERO
var _launch_to := Vector3.ZERO
var _fx_t := 0.0
var _aground_t := 0
var _board: Node3D
## Why the ride ended last ("stow", "crash", "aground", "hit"): tests read it.
var last_end := ""


func _ready() -> void:
	pass


## Where `p` would put the skimmer on the water now (["", point]) or why not ([reason, ZERO]).
static func launch_point(p: Player) -> Array:
	# (1.31) in the air over open water: down onto it right below you, carrying the jump on
	if p.current_state_name() in ["Jump", "Fall"] and not p.is_on_floor():
		var below := Vector3(p.global_position.x, p.water_surface(), p.global_position.z)
		if p.global_position.y > below.y + 0.4 and p.global_position.y < below.y + AIR_MOUNT_H and p.water_depth_at(below) >= LAUNCH_DEPTH:
			return ["", below]
	if p.current_state_name() == "Swim":
		var here := Vector3(p.global_position.x, p.water_surface(), p.global_position.z)
		if p.water_depth_at(here) < LAUNCH_DEPTH:
			return ["Too shallow here for the skimmer", Vector3.ZERO]
		return ["", here]
	var fwd: Vector3 = -p.player_model.global_basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var space := p.get_world_3d().direct_space_state
	var chest := p.global_position + Vector3.UP * 1.2
	for d in [2.0, 3.5, 5.0, 6.5]:
		var q: Vector3 = p.global_position + fwd * d
		q.y = p.water_surface(q)
		if q.y > p.global_position.y + 0.5 or p.water_depth_at(q) < LAUNCH_DEPTH:
			continue
		var ray := PhysicsRayQueryParameters3D.create(chest, q + Vector3.UP * 0.6, 1, [p.get_rid()])
		if not space.intersect_ray(ray).is_empty():
			continue
		return ["", q]
	return ["No open water ahead: face the sea to launch the skimmer", Vector3.ZERO]


## How the wind drives a sail on `yaw` (a beam reach 1.0, running before it 0.8, into it 0.55), by its strength.
static func wind_k(yaw: float, wx: Node) -> float:
	var wd: Vector2 = wx.wind_dir() if wx else Vector2(1, 0)
	var a := rad_to_deg(absf(Vector2(-sin(yaw), -cos(yaw)).angle_to(wd)))
	var pts := [[0.0, 0.8], [45.0, 0.95], [90.0, 1.0], [135.0, 0.7], [180.0, 0.55]]
	var k := 1.0
	for i in range(pts.size() - 1):
		if a <= float(pts[i + 1][0]):
			k = lerpf(float(pts[i][1]), float(pts[i + 1][1]), (a - float(pts[i][0])) / (float(pts[i + 1][0]) - float(pts[i][0])))
			break
	var w: float = float(wx.get("wind")) if wx else 0.3
	return k * lerpf(0.85, 1.0, clampf(w, 0.0, 1.0))


func top_speed() -> float:
	return float(GadgetData.tier_val("skimmer", "speed", tier)) * wind_k(heading, get_node_or_null("/root/Weather"))


func enter(data: Dictionary) -> void:
	tier = int(data["tier"])
	var at: Vector3 = data["at"]
	last_end = ""
	player.sheathe_weapon(true)
	player.sprinting = false
	player.reset_combo()
	player.body_model.swimming = false
	player.body_model.diving = false
	var fwd: Vector3 = -player.player_model.global_basis.z
	var to := at - player.global_position
	to.y = 0.0
	if to.length() > 0.3:
		fwd = to.normalized()
	heading = atan2(-fwd.x, -fwd.z)
	player.player_model.rotation.y = heading - PI * 0.5
	speed = PUSH
	_turn = 0.0
	_vy = 0.0
	_air = false
	_fx_t = 0.0
	_aground_t = 0
	_launch_t = -1.0
	if player.global_position.distance_to(at) > 0.6:
		_launch_t = 0.0
		_launch_from = player.global_position
		_launch_to = at + Vector3.UP * RIDE_H
	else:
		player.global_position = at + Vector3.UP * RIDE_H
		player.reset_physics_interpolation()
		_splash_down(0.6)
	_board = SkimmerModel.make(tier)
	player.lean.add_child(_board)
	_board.scale = Vector3(0.2, 0.2, 0.2)
	_board.create_tween().tween_property(_board, "scale", Vector3.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	player.body_model.play("gd_skim", 3600.0)
	player.align_hold = true
	player.align_w = 1.0
	player.align_up = Vector3.UP
	Net.fx("sfx", ["flap", player.global_position + Vector3.UP * 2.0, -4.0, 0.05, 0.9])
	Net.fx("sfx", ["whoosh", player.global_position, -10.0, 0.1, 1.2])


func exit() -> void:
	player.body_model.skim_lean = 0.0
	if _board and is_instance_valid(_board):
		_board.queue_free()
	_board = null
	player.align_hold = false
	player.align_w = 0.0
	if player.body_model.current_action() == "gd_skim":
		player.body_model.stop_action()


func physics_update(delta: float) -> void:
	if _launch_t >= 0.0:
		_launch(delta)
		return
	if player.inp.just_pressed("interact"):
		_end("stow", false)
		return
	var input := get_movement_input()
	var steer := input.length() > 0.1
	var prev := heading
	if steer:
		var d := get_camera_relative_direction(input)
		heading = rotate_toward(heading, atan2(-d.x, -d.z), TURN * delta)
	_turn = lerpf(_turn, angle_difference(prev, heading) / maxf(delta, 0.001), clampf(8.0 * delta, 0.0, 1.0))
	var target := top_speed() * (1.0 if steer else COAST)
	speed = move_toward(speed, target, (ACCEL if target > speed else DECEL) * delta)
	var fwd := Vector3(-sin(heading), 0.0, -cos(heading))
	var surf := player.water_surface() + RIDE_H
	if _air and tier == 2 and player.inp.just_pressed("jump"):
		# (1.31) Mk III: Space in the hop leaps off the board
		_jump_off()
		return
	if _air:
		_vy -= HOP_GRAVITY * delta
		if _vy < 0.0 and player.global_position.y <= surf:
			_air = false
			_splash_down(0.9)
			player.squash(5.0)
	elif tier < 2 and player.inp.just_pressed("jump"):
		_jump_off()
		return
	elif tier == 2 and player.inp.just_pressed("jump"):
		_air = true
		_vy = float(GadgetData.tier_val("skimmer", "hop", tier)) + maxf(player.velocity.y, 0.0) * 0.5
		Net.fx("spray", [player.global_position, Vector3.UP, 14, Color(0.9, 0.96, 1.0), 5.0])
		Net.fx("sfx", ["splash", player.global_position, -6.0, 0.08, 1.3])
		player.squash(-4.0)
	else:
		_vy = clampf((surf - player.global_position.y) * 14.0, -6.0, 6.0)
	var before := speed
	player.velocity = fwd * speed + Vector3.UP * _vy
	player.move_and_slide()
	for i in range(player.get_slide_collision_count()):
		var n := player.get_slide_collision(i).get_normal()
		if absf(n.y) < 0.7 and fwd.dot(-n) > 0.3:
			if before > CRASH_SPEED:
				_end("crash", true)
				return
			speed = 0.0
	if not _air and Engine.get_physics_frames() % 3 == 0:
		var depth := player.water_depth_at(player.global_position)
		_aground_t = _aground_t + 1 if depth < AGROUND else 0
		if _aground_t >= 2:
			_end("aground", speed > CRASH_SPEED)
			return
	player.player_model.rotation.y = heading - PI * 0.5
	var n_up := Vector3.UP if _air else (player.get_node("/root/Ocean").get_wave_normal(player.global_position) as Vector3).slerp(Vector3.UP, 0.4)
	var bank := clampf(-_turn * speed * BANK_K, -BANK_MAX, BANK_MAX)
	player.align_up = n_up.rotated(fwd, bank).normalized()
	# (1.31) the rider leans into the turn: forward over the toes turning right, back on the heels pulling it round left
	player.body_model.skim_lean = lerpf(player.body_model.skim_lean, clampf(-_turn * 0.75, -1.0, 1.0), clampf(10.0 * delta, 0.0, 1.0))
	if _board and is_instance_valid(_board):
		(_board.get_node("Rig") as Node3D).rotation = Vector3(0.0, 0.0, clampf(_turn * 0.12, -0.25, 0.25))
	player.freefall_from = now_s()
	_fx_t -= delta
	if _fx_t <= 0.0:
		_fx_t = FX_EVERY
		if not _air:
			SkimmerModel.ride_fx(player, speed)


func _launch(delta: float) -> void:
	_launch_t += delta
	var u := clampf(_launch_t / LAUNCH_T, 0.0, 1.0)
	var to := _launch_to
	to.y = player.water_surface(to) + RIDE_H
	var at := _launch_from.lerp(to, u) + Vector3.UP * sin(u * PI) * 1.2
	player.velocity = (at - player.global_position) / maxf(delta, 0.001)
	player.global_position = at
	if u >= 1.0:
		_launch_t = -1.0
		player.velocity = Vector3(-sin(heading), 0.0, -cos(heading)) * speed
		_splash_down(1.0)
		player.squash(6.0)


func _splash_down(size: float) -> void:
	var at := Vector3(player.global_position.x, player.water_surface(), player.global_position.z)
	Net.fx("splash", [at, int(8 * size), 0.7 * size])
	Net.fx("water_ring", [at, 1.6 * size, 0.8])
	Net.fx("sfx", ["splash", at, -6.0, 0.08, 1.1])


## Thrown off (a blow from `dir`, or a crash) into the water.
func throw_off(why: String) -> void:
	_end(why, true)


func _end(why: String, thrown: bool) -> void:
	last_end = why
	var at := Vector3(player.global_position.x, player.water_surface(), player.global_position.z)
	var fwd := Vector3(-sin(heading), 0.0, -cos(heading))
	if thrown:
		player.velocity = fwd * minf(speed, 6.0) * 0.6 + Vector3.UP * 2.0
		Net.fx("splash", [at + fwd * 0.6, 14, 1.0])
		Net.fx("spray", [at + fwd * 0.8, (fwd + Vector3.UP).normalized(), 18, Color(0.9, 0.96, 1.0), 6.0])
		Net.fx("sfx", ["splash", at, -1.0, 0.08, 0.85])
		player.cam_shake(0.25, 0.25)
		player.call("_toast", {"crash": "Crashed! Thrown off the skimmer", "aground": "Run aground! Thrown off the skimmer", "hit": "Knocked off the skimmer"}.get(why, "Thrown off the skimmer"))
	else:
		Net.fx("puff", [at + Vector3.UP * 0.4, "dust", 2, 0.6, 0.5, Color(1, 1, 1, 0.6), 0.6])
		Net.fx("sfx", ["flap", at + Vector3.UP, -6.0, 0.05, 1.2])
	var deep: bool = player.water_depth_at(player.global_position) > 1.2
	if deep or thrown:
		transitioned.emit(self, "Swim", {"entry_vy": -7.0 if thrown else 0.0, "quiet": not thrown})
	else:
		transitioned.emit(self, "Idle", {})


## (1.31) Jump off: the board stowed under you, up and on with the ride's way.
func _jump_off() -> void:
	last_end = "jump"
	var fwd := Vector3(-sin(heading), 0.0, -cos(heading))
	var at := Vector3(player.global_position.x, player.water_surface(), player.global_position.z)
	Net.fx("spray", [at, (Vector3.UP - fwd * 0.4).normalized(), 12, Color(0.9, 0.96, 1.0), 4.5])
	Net.fx("sfx", ["splash", at, -6.0, 0.08, 1.3])
	Net.fx("sfx", ["jump", player.global_position, -4.0, 0.05, 1.0])
	player.squash(-4.0)
	player.velocity = fwd * speed * JUMP_OFF_CARRY + Vector3.UP * JUMP_OFF_UP
	player.body_model.skim_lean = 0.0
	transitioned.emit(self, "Fall", {})
