extends PlayerState
## Airborne and descending. Coyote time lets you still jump just after
## running off a ledge; a jump pressed just before landing is buffered.
## A long freefall (FREEFALL_TUMBLE s since the last jump, air step, ability or attack) goes limp and tumbles:
## DownedState with "tumble".

const FREEFALL_TUMBLE := 3.5
## Not when the ground is this close anyway.
const TUMBLE_CLEAR := 3.0
## Crash Landing (Acrobatics, the landing variant): down at this speed or more (a fall of ~4 m) you land in it.
const CRASH_SPEED := 16.0
const CRASH_DAMAGE := 10.0
const CRASH_DAMAGE_MAX := 30.0
const CRASH_R := 2.6
const CRASH_R_MAX := 4.6


func enter(data: Dictionary) -> void:
	if not data.get("from_jump", false):
		player.freefall_from = now_s()


func physics_update(delta: float) -> void:
	apply_gravity(delta)

	var input := get_movement_input()
	# (an air step chasing a juggled foe carries you: JumpState._chase)
	if input.length() > 0.1 and now_s() >= float(player.get_meta("chase_until", 0.0)):
		var direction := get_camera_relative_direction(input)
		var spd := air_speed()
		player.velocity.x = direction.x * spd
		player.velocity.z = direction.z * spd
		if player.armed:
			face_camera(delta)
		else:
			face_direction(direction, delta)

	player.move_and_slide()

	var air := air_attack_input()
	if air != "":
		transitioned.emit(self, air, {})
		return

	if player.skyward_dash and wants_dodge():
		transitioned.emit(self, "Dodge", {"air": true})
		return

	if wants_moonstep():
		transitioned.emit(self, "Jump", {"moon": true})
		return

	if now_s() - player.freefall_from > FREEFALL_TUMBLE and player.height_above_ground() > TUMBLE_CLEAR:
		transitioned.emit(self, "Downed", {"tumble": true, "velocity": player.velocity})
		return

	# ran off a ledge and coyote time is over: the ground jump is gone, only
	# air jumps (double jump, once unlocked) are left
	if not player.can_coyote_jump() and player.jumps_remaining == player.max_jumps:
		player.jumps_remaining -= 1

	if player.inp.just_pressed("jump"):
		if player.can_coyote_jump():
			transitioned.emit(self, "Jump", {"coyote": true})
			return
		if player.jumps_remaining > 0:
			transitioned.emit(self, "Jump", {})
			return

	if player.is_on_floor():
		player.jumps_remaining = player.max_jumps
		player.air_speed = 0.0
		if player.consume_jump_buffer():
			transitioned.emit(self, "Jump", {})
			return
		var move_input := get_movement_input()
		if move_input.length() > 0.1:
			transitioned.emit(self, "Move", {})
		else:
			transitioned.emit(self, "Idle", {})


## Crash Landing, down at `speed`: one knee and a fist to the ground, the ground cracks, and a ring thrown out
## knocks the foes round you off their feet (harder and wider the longer the drop). The fall hurts half as much.
func crash(speed: float) -> void:
	var k := clampf((speed - CRASH_SPEED) / 16.0, 0.0, 1.0)
	var at := player.global_position
	player.body_model.play("crash_land", ActionSpecs.length("crash_land"))
	player.squash(-8.0)
	if speed > Player.SAFE_FALL_SPEED:
		player._fall_damage(speed, 0.5, false)
	var r := lerpf(CRASH_R, CRASH_R_MAX, k)
	var fist := at - player.player_model.global_basis.z * 0.35
	Net.fx("puff_ring", [at + Vector3(0, 0.05, 0), "dust_low", 8 + int(6 * k), 0.4, 1.0 + 0.5 * k, 0.9, Color(0.85, 0.8, 0.7, 0.9), 4.0 + 4.0 * k])
	Net.fx("ring", [at, Vector3.UP, r, Color(1.0, 0.96, 0.9, 0.85), 0.32, 0.14])
	Net.fx("debris", [fist + Vector3(0, 0.1, 0), Vector3.UP, 4 + int(5 * k), Color(0.42, 0.36, 0.3), 4.0 + 2.0 * k])
	Net.fx("impact", [fist + Vector3(0, 0.15, 0), Color(1.0, 0.92, 0.75)])
	if player.ground_surface() not in ["wood", "water"]:
		var s := randi()
		for i in 4:
			var a := TAU * (float(i) + randf_range(-0.25, 0.25)) / 4.0
			Net.fx("ground_crack", [fist, Vector3(cos(a), 0.0, sin(a)), 1.0 + 1.2 * k, Color(0, 0, 0, 0), s + i, 0.1])
	Net.fx("sfx", ["rock_crash", at, -6.0 + 3.0 * k, 0.06, 1.2])
	Net.fx("sfx", ["thud", at, -3.0, 0.05, 0.8])
	player.cam_shake(0.16 + 0.16 * k)
	var wave := HitData.new()
	wave.damage = lerpf(CRASH_DAMAGE, CRASH_DAMAGE_MAX, k) * player.damage_multiplier()
	wave.knockdown = true
	wave.knockback_force = 6.0 + 5.0 * k
	wave.stagger_duration = 0.5
	wave.hitstop_duration = 0.06
	wave.camera_shake_intensity = 0.0
	wave.impact = "punch_heavy"
	var q := PhysicsShapeQueryParameters3D.new()
	var sph := SphereShape3D.new()
	sph.radius = r
	q.shape = sph
	q.transform = Transform3D(Basis.IDENTITY, at + Vector3(0, 0.6, 0))
	q.collision_mask = player.foe_mask()
	q.collide_with_areas = true
	q.collide_with_bodies = false
	var struck: Array = []
	for res in player.get_world_3d().direct_space_state.intersect_shape(q, 16):
		var area := res["collider"] as Hurtbox
		if area and area.owner and area.owner != player and not (area.owner in struck) and not area.owner.is_in_group("players"):
			struck.append(area.owner)
			area.take_hit(wave, player)
	player.progression.add_life("acrobatics", 6)
