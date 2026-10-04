extends PlayerState
## Three-hit light combo: right slash -> backhand -> spinning finisher.
## The chain is remembered for a moment after each hit, so you can reposition
## (move, even jump) and the next click continues the combo instead of restarting.

@export var combo_count: int = 3
## Time after the chain opens during which another click continues instantly.
@export var combo_window: float = 0.45
@export var hitbox_start: float = 0.08
@export var hitbox_end: float = 0.24

## Per-hit timing (index = combo step)
var attack_durations: Array[float] = [0.3, 0.3, 0.46]   # before you can chain / move
var anim_lengths: Array[float] = [0.48, 0.48, 0.62]
var forward_impulses: Array[float] = [4.5, 4.5, 6.5]
var combo_damages: Array[float] = [10.0, 12.0, 22.0]
var combo_hitstops: Array[float] = [0.045, 0.045, 0.09]
var combo_shakes: Array[float] = [0.09, 0.09, 0.18]
const ANIMS := ["slash_r", "slash_l", "spin_slash"]
const TRAILS := ["right", "left", "spin"]

var combo_index: int = 0
var timer: float = 0.0
var can_combo: bool = false
var combo_timer: float = 0.0
var hitbox_activated: bool = false
var hitbox_deactivated: bool = false
var chained: bool = false


func enter(data: Dictionary) -> void:
	# Continue the remembered chain unless this attack came straight from a chain.
	combo_index = int(data.get("combo_index", 0)) if data.get("chain", false) else player.next_combo_index()
	combo_index = clampi(combo_index, 0, combo_count - 1)
	player.reset_combo()
	timer = 0.0
	can_combo = false
	combo_timer = 0.0
	hitbox_activated = false
	hitbox_deactivated = false
	chained = false

	var forward := get_camera_forward()
	player.player_model.rotation.y = atan2(-forward.x, -forward.z)
	player.velocity.x = forward.x * forward_impulses[combo_index]
	player.velocity.z = forward.z * forward_impulses[combo_index]
	player.body_model.play(ANIMS[combo_index], anim_lengths[combo_index])
	player.squash(-1.5 if combo_index < 2 else -2.5)


func physics_update(delta: float) -> void:
	apply_gravity(delta)
	player.velocity.x = move_toward(player.velocity.x, 0.0, 15.0 * delta)
	player.velocity.z = move_toward(player.velocity.z, 0.0, 15.0 * delta)
	player.move_and_slide()

	timer += delta

	if timer >= hitbox_start and not hitbox_activated:
		hitbox_activated = true
		var hit := HitData.new()
		hit.damage = combo_damages[combo_index] * player.damage_multiplier()
		hit.hitstop_duration = combo_hitstops[combo_index]
		hit.camera_shake_intensity = combo_shakes[combo_index]
		hit.knockback_force = 8.0 if combo_index == combo_count - 1 else 4.0
		player.sword_hitbox.activate(hit)
		# swoosh!
		var trail_len := 0.26 if combo_index < 2 else 0.4
		FX.slash(player.player_model, TRAILS[combo_index], trail_len)
		FX.sfx("whoosh", player.global_position, -6.0, 0.12, 1.0 + combo_index * 0.08)
		player.squash(1.5)
		if combo_index == combo_count - 1:
			FX.dust_ring(player.global_position, 8, 0.6)

	if timer >= hitbox_end and not hitbox_deactivated:
		hitbox_deactivated = true
		player.sword_hitbox.deactivate()

	var duration := attack_durations[combo_index]
	if timer >= duration and not can_combo:
		can_combo = true
		combo_timer = combo_window

	if can_combo:
		combo_timer -= delta
		if input_buffer.consume_action("light_attack") and player.spend_stamina(player.LIGHT_COST):
			chained = true
			transitioned.emit(self, "LightAttack", {"combo_index": (combo_index + 1) % combo_count, "chain": true})
			return
		if wants_dodge():
			transitioned.emit(self, "Dodge", {})
			return
		# reposition between hits without losing the chain
		if get_movement_input().length() > 0.1:
			transitioned.emit(self, "Move", {})
			return
		if Input.is_action_just_pressed("jump"):
			transitioned.emit(self, "Jump", {})
			return
		if combo_timer <= 0.0:
			transitioned.emit(self, "Idle", {})
			return


func exit() -> void:
	player.sword_hitbox.deactivate()
	player.sword_pivot.rotation_degrees.z = 0.0
	if not chained:
		if combo_index < combo_count - 1:
			player.remember_combo(combo_index + 1)
		else:
			player.reset_combo()
