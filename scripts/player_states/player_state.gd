extends State
class_name PlayerState

var player: Player
var input_buffer: InputBuffer


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
				return "Shoot"
			if not player.spend_stamina(player.LIGHT_COST):
				return ""
			# (out of a sprint: the katana's quick draw, the cutlass's running cut)
			player.quick_draw = player.sprinting and player.style() in ["katana", "sword"]
			return "LightAttack"
		player.draw_weapon()
		return ""
	if input_buffer.consume_action("heavy_attack"):
		if player.can_attack():
			if not player.spend_stamina(player.HEAVY_COST):
				return ""
			return "Iai" if player.style() == "katana" else "HeavyAttack"
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
		if player.style() == "dual_pistol" and player.gun_rains >= 1 + int(player.progression.stat("gun_rain_uses")):
			return ""
		if player.style() == "katana" and player.air_slashes >= 1:
			return ""
		return "Plunge" if player.spend_stamina(player.PLUNGE_COST) else ""
	return ""


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
