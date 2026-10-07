extends PlayerState
## Katana heavy (iaijutsu). Hold heavy: the blade slips back into its scabbard
## and you sink into a low forward lunge, one hand on the scabbard and one on the
## hilt, charging through two levels (you can still creep about). Attack while
## holding: the blade leaves the scabbard in one short dashing cut, harder and
## further the higher the charge. Let go of heavy first to stand down.

## Seconds of holding to reach charge levels 1 and 2.
const LEVELS := [0.5, 1.2]
const DAMAGE := [20.0, 34.0, 55.0]
const DASH_SPEED := [11.0, 15.0, 20.0]
const DASH_TIME := 0.18
const RECOVER := 0.42
const CREEP := 0.2          # x move speed while charging
const COLORS := [Color(0.85, 0.92, 1.0), Color(0.55, 0.8, 1.0), Color(1.0, 0.82, 0.35)]

var phase: int = 0   # 0 charging, 1 dashing cut, 2 recovering, 3 standing down
var timer: float = 0.0
var level: int = 0
var _top: int = 2
var _dir := Vector3.ZERO


func enter(_data: Dictionary) -> void:
	phase = 0
	timer = 0.0
	level = 0
	# the second charge level is Full Draw on the katana tree
	_top = LEVELS.size() if player.progression.has_move("iai_full") else 1
	player.reset_combo()
	face_direction(get_camera_forward(), 1.0)
	player.body_model.play("iai_ready", 600.0)
	Net.fx("sfx", ["whoosh", player.global_position, -12.0, 0.08, 0.75])


func physics_update(delta: float) -> void:
	timer += delta
	apply_gravity(delta)
	match phase:
		0:
			var mi := get_movement_input()
			var want := get_camera_relative_direction(mi) * player.move_speed * CREEP if mi.length() > 0.1 else Vector3.ZERO
			player.velocity.x = move_toward(player.velocity.x, want.x, 30.0 * delta)
			player.velocity.z = move_toward(player.velocity.z, want.z, 30.0 * delta)
			player.move_and_slide()
			face_camera(delta)
			while level < _top and timer >= float(LEVELS[level]):
				level += 1
				_charged()
			if input_buffer.consume_action("light_attack"):
				_release()
			elif not Input.is_action_pressed("heavy_attack"):
				phase = 3
				timer = 0.0
				player.body_model.play("draw", 0.3)
			elif wants_dodge():
				transitioned.emit(self, "Dodge", {})
		1:
			player.velocity.x = _dir.x * float(DASH_SPEED[level])
			player.velocity.z = _dir.z * float(DASH_SPEED[level])
			player.move_and_slide()
			if timer >= DASH_TIME:
				phase = 2
				timer = 0.0
				player.set_collision_mask_value(12, true)
		2, 3:
			player.velocity.x = move_toward(player.velocity.x, 0.0, 40.0 * delta)
			player.velocity.z = move_toward(player.velocity.z, 0.0, 40.0 * delta)
			player.move_and_slide()
			if phase == 2 and timer >= 0.06:
				player.sword_hitbox.deactivate()
			if timer >= (RECOVER if phase == 2 else 0.3):
				transitioned.emit(self, "Idle", {})
			elif phase == 2 and timer > RECOVER * 0.5 and wants_dodge():
				transitioned.emit(self, "Dodge", {})


## A charge level reached: a glint off the guard and a rising ring.
func _charged() -> void:
	var at := player.global_position + Vector3.UP * 0.95
	var w: Node3D = player.body_model.weapon
	if w and is_instance_valid(w) and w.is_inside_tree():
		at = w.global_position
	Net.fx("sparkle", [at, 8 + 6 * level, COLORS[level]])
	Net.fx("sfx", ["blip_high", at, -8.0, 0.0, 0.9 + 0.25 * level])
	if level == _top:
		Net.fx("impact", [at, COLORS[level]])


## Out of the scabbard in one cut, driving forward.
func _release() -> void:
	phase = 1
	timer = 0.0
	_dir = get_camera_forward()
	player.player_model.rotation.y = atan2(-_dir.x, -_dir.z)
	player.set_collision_mask_value(12, false)   # the cut carries you through them
	player.body_model.play("iai_slash", DASH_TIME + RECOVER)
	player.set_reach("iai")
	var hit := player.melee_hit(float(DAMAGE[level]))
	hit.hitstop_duration = 0.06 + 0.03 * level
	hit.camera_shake_intensity = 0.12 + 0.06 * level
	hit.knockback_force = 8.0 + 3.0 * level
	hit.stagger_duration = 0.4 + 0.15 * level
	# full charge: everything you cut through crumples where it stands
	hit.knockdown = level == LEVELS.size()
	hit.crumple = hit.knockdown
	hit.sever = true
	if player.progression.has_flag("armament"):
		hit.unblockable = true
		hit.haki = true
	player.sword_hitbox.activate(hit)
	var col: Color = Player.HAKI_TRAIL if player.power.buff("coat") else COLORS[level]
	Net.fx("slash", [player.player_model, "iai", 0.3 + 0.06 * level, col])
	Net.fx("sfx", ["whoosh_big", player.global_position, -3.0, 0.05, 1.35])
	Net.fx("sfx", ["parry", player.global_position, -10.0 + 3.0 * level, 0.05, 1.5])
	if level > 0:
		Net.fx("afterimage", [player.body_model, col, 0.2 + 0.08 * level])
	Net.fx("dust", [player.global_position + Vector3(0, 0.05, 0), 6 + 3 * level, 0.6])
	player.squash(-2.0 - level)
	CombatManager.apply_camera_shake(0.06 + 0.04 * level)


func exit() -> void:
	player.set_collision_mask_value(12, true)
	player.sword_hitbox.deactivate()
	player.set_reach("katana")
	if player.body_model.current_action() == "iai_ready":
		player.body_model.stop_action()
