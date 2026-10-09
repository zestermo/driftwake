extends State
class_name PlayerState

var player: Player
var input_buffer: InputBuffer

## Right-click fatigue: each heavy within FATIGUE_WINDOW s of the last costs
## FATIGUE_STEP more stamina (and stamina waits longer to come back); a light
## attack or a pause resets it. The same heavy again within READ_WINDOW s grows
## predictable: READ_CHANCE[repeats] that a grunt reads it (HitData.predictable).
const FATIGUE_WINDOW := 3.0
const FATIGUE_STEP := 0.5
const READ_WINDOW := 4.0
const READ_CHANCE := [0.0, 0.35, 0.6, 0.8]
## The guns reload after a gun kata.
const KATA_RELOAD := 1.2
static var _heavy_chain := 0
static var _heavy_at := -100.0
static var _repeat := 0
static var _repeat_move := ""
static var _repeat_at := -100.0
static var reload_until := -100.0


static func now_s() -> float:
	return Time.get_ticks_msec() / 1000.0


## A heavy started (`move`: which one): fatigue and repetition.
func _heavy_used(move: String) -> void:
	var t := now_s()
	var chain := _heavy_chain if t - _heavy_at < FATIGUE_WINDOW else 0
	_heavy_chain = chain + 1
	_heavy_at = t
	player._stamina_delay = player.STAMINA_REGEN_DELAY * (1.0 + 0.5 * chain)
	_repeat = mini(_repeat + 1, READ_CHANCE.size() - 1) if move == _repeat_move and t - _repeat_at < READ_WINDOW else 0
	_repeat_move = move
	_repeat_at = t


## How likely a grunt reads the heavy being thrown now.
static func read_chance() -> float:
	return float(READ_CHANCE[_repeat])


## What a right-click costs now (more each time in a row).
func heavy_cost() -> float:
	var chain := _heavy_chain if now_s() - _heavy_at < FATIGUE_WINDOW else 0
	return player.HEAVY_COST * player.attack_cost_k() * pow(1.0 + FATIGUE_STEP, chain)


func _ready() -> void:
	await owner.ready
	player = owner as Player
	input_buffer = player.input_buffer


func get_movement_input() -> Vector2:
	return Input.get_vector("move_left", "move_right", "move_forward", "move_back")


func get_camera_relative_direction(input: Vector2) -> Vector3:
	var camera := player.get_viewport().get_camera_3d()
	if not camera:
		return Vector3.ZERO

	# Use the CameraRig's Y rotation to derive forward/right on XZ plane
	# CameraRig is Camera3D -> SpringArm3D -> CameraRig
	var rig := camera.get_parent().get_parent() as Node3D
	var yaw := rig.global_rotation.y

	# In Godot, rotation.y = 0 means facing -Z. So forward = -Z direction rotated by yaw.
	var forward := Vector3(-sin(yaw), 0.0, -cos(yaw))
	var right := Vector3(cos(yaw), 0.0, -sin(yaw))

	return (forward * -input.y + right * input.x).normalized()


func get_camera_forward() -> Vector3:
	var camera := player.get_viewport().get_camera_3d()
	if not camera:
		return -player.player_model.global_basis.z
	var rig := camera.get_parent().get_parent() as Node3D
	var yaw := rig.global_rotation.y
	return Vector3(-sin(yaw), 0.0, -cos(yaw))


func apply_gravity(delta: float) -> void:
	if not player.is_on_floor():
		var g := player.gravity
		if player.velocity.y < 0.0:
			g *= player.fall_gravity_mult
			player.variable_jump_active = false
		elif player.variable_jump_active and not Input.is_action_pressed("jump"):
			g *= player.short_hop_gravity_mult  # let go early = shorter hop
		player.velocity.y -= g * delta
		player.velocity.y = maxf(player.velocity.y, -34.0)


## Attack/parry input: first press draws the weapon, later presses attack.
## Returns the state to enter, or "" if nothing should happen.
func combat_input() -> String:
	if input_buffer.consume_action("light_attack"):
		if player.can_attack():
			if player.weapon_class() == "gun":
				return "Shoot" if now_s() >= reload_until else ""
			if not player.spend_stamina(player.LIGHT_COST * player.attack_cost_k()):
				return ""
			_heavy_chain = 0
			# (out of a sprint: the katana's quick draw, the cutlass's running cut)
			var st := player.style()
			player.quick_draw = player.sprinting and ((st == "katana" and player.progression.has_move("quick_draw"))
				or (st == "sword" and player.progression.has_move("dash_cut")))
			return "LightAttack"
		player.draw_weapon()
		return ""
	if input_buffer.consume_action("heavy_attack"):
		if player.can_attack():
			if player.style() == "dual_pistol" and now_s() < reload_until:
				return ""
			if not player.spend_stamina(heavy_cost()):
				return ""
			var next := "Iai" if player.style() == "katana" else "HeavyAttack"
			_heavy_used(next + ":" + player.style())
			return next
		player.draw_weapon()
		return ""
	if input_buffer.consume_action("parry"):
		if player.can_attack():
			return "Parry"
		player.draw_weapon()
		return ""
	return ""


## Attack pressed in the air: the plunging jump attack (needs a drawn weapon,
## a bit of height under you and the stamina); unarmed it draws the weapon.
func air_attack_input() -> String:
	# too close to the ground: leave the press buffered for a landing attack
	if player.can_attack() and player.height_above_ground() < 0.9:
		return ""
	if input_buffer.consume_action("light_attack") or input_buffer.consume_action("heavy_attack"):
		if not player.can_attack():
			player.draw_weapon()
			return ""
		var pr := player.progression
		if player.style() == "dual_pistol" and (not pr.has_move("gun_rain") or player.gun_rains >= 1 + int(pr.stat("gun_rain_uses"))):
			return ""
		if player.style() == "katana" and pr.has_move("air_slash") and player.air_slashes >= 1:
			return ""
		var mv := air_move()
		var used := int(player.air_uses.get(mv, 0))
		if mv in ["twin_cyclone", "hang_shot", "boarding_dive"] and used >= 1:
			return ""
		# (a Meteor Kick that connects bounces you up for another, a few in a row)
		if mv == "meteor_kick" and (used > int(player.air_uses.get("bounce", 0)) or used >= METEOR_CHAIN):
			return ""
		if mv == "hang_shot" and (player.reloading() or player.ammo[0] <= 0):
			return ""
		return "Plunge" if player.spend_stamina(player.PLUNGE_COST * player.attack_cost_k()) else ""
	return ""


## Each style's own air attack once its move is learned ("" = the plain plunge;
## dual pistols' Gun Rain is handled on its own).
const AIR_MOVES := {"katana": "air_slash", "axe": "skybreaker", "dual_sword": "twin_cyclone",
	"fist": "meteor_kick", "pistol": "hang_shot", "sword": "boarding_dive"}
const METEOR_CHAIN := 3

func air_move() -> String:
	var mv: String = AIR_MOVES.get(player.style(), "")
	return mv if mv != "" and player.progression.has_move(mv) else ""


## Dodge pressed (or buffered) and there's stamina for it.
func wants_dodge() -> bool:
	return input_buffer.consume_action("dodge") and player.spend_stamina(player.dodge_cost())


## Combat stance keeps the character facing where the camera looks.
func face_camera(delta: float) -> void:
	face_direction(get_camera_forward(), delta)


func face_direction(direction: Vector3, delta: float) -> void:
	if direction.length_squared() < 0.01:
		return
	var target_angle := atan2(-direction.x, -direction.z)
	player.player_model.rotation.y = lerp_angle(player.player_model.rotation.y, target_angle, minf(player.turn_speed * delta, 1.0))


## Jump pressed now, or buffered just before landing.
func wants_jump() -> bool:
	return Input.is_action_just_pressed("jump") or player.consume_jump_buffer()


## Horizontal air speed keeps your running momentum.
func air_speed() -> float:
	return maxf(player.move_speed, player.air_speed)
