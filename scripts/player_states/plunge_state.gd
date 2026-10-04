extends PlayerState
## Jumping attack: attack in the air and you hang for a beat with the sword
## raised, then drop fast in an overhead slash and slam into the ground with
## a little shockwave. Hits on the way down and again on landing.

const HANG := 0.16
const DIVE_SPEED := 22.0
const RECOVER := 0.38

var phase: int = 0   # 0 hang, 1 dive, 2 land
var timer: float = 0.0
var _dir := Vector3.ZERO


func enter(_data: Dictionary) -> void:
	phase = 0
	timer = 0.0
	player.reset_combo()
	var f := get_camera_forward()
	player.player_model.rotation.y = atan2(-f.x, -f.z)
	_dir = f
	player.velocity = Vector3(player.velocity.x * 0.3, 2.5, player.velocity.z * 0.3)
	player.body_model.play("plunge_air", 0.6)
	player.squash(2.0)
	Net.fx("sfx", ["whoosh", player.global_position, -6.0, 0.06, 0.8])


func physics_update(delta: float) -> void:
	timer += delta
	match phase:
		0:
			# brief hang at the top
			player.velocity.y = move_toward(player.velocity.y, 0.0, 30.0 * delta)
			player.move_and_slide()
			if timer >= HANG:
				phase = 1
				timer = 0.0
				player.velocity = _dir * 3.5 + Vector3.DOWN * DIVE_SPEED
				Net.fx("slash", [player.player_model, "overhead", 0.3])
				Net.fx("sfx", ["whoosh_big", player.global_position, -4.0, 0.06, 1.1])
				var hit := HitData.new()
				hit.damage = 22.0 * player.damage_multiplier()
				hit.knockback_force = 7.0
				hit.stagger_duration = 0.45
				hit.hitstop_duration = 0.07
				hit.camera_shake_intensity = 0.16
				player.sword_hitbox.activate(hit)
		1:
			player.velocity.y = -DIVE_SPEED
			player.move_and_slide()
			if player.is_on_floor() or timer > 2.5:
				_land()
		2:
			player.velocity.x = move_toward(player.velocity.x, 0.0, 30.0 * delta)
			player.velocity.z = move_toward(player.velocity.z, 0.0, 30.0 * delta)
			apply_gravity(delta)
			player.move_and_slide()
			if timer >= RECOVER:
				transitioned.emit(self, "Idle", {})
			elif timer > RECOVER * 0.5 and wants_dodge():
				transitioned.emit(self, "Dodge", {})


func _land() -> void:
	phase = 2
	timer = 0.0
	player.sword_hitbox.deactivate()
	player.velocity = Vector3.ZERO
	player.body_model.play("plunge_land", RECOVER + 0.1)
	player.squash(-4.0)
	var at := player.global_position - player.player_model.global_basis.z * 0.9
	Net.fx("dust_ring", [at, 18, 1.0])
	Net.fx("impact", [at + Vector3(0, 0.2, 0), Color(1.0, 0.9, 0.6)])
	Net.fx("sfx", ["thud", at, 0.0, 0.05, 0.8])
	get_node("/root/CombatManager").apply_camera_shake(0.2)
	# shockwave: everything close gets a smaller hit and a shove
	var wave := HitData.new()
	wave.damage = 8.0 * player.damage_multiplier()
	wave.knockback_force = 8.0
	wave.stagger_duration = 0.4
	wave.hitstop_duration = 0.05
	wave.camera_shake_intensity = 0.0
	var already: Array = player.sword_hitbox.hit_targets.duplicate()
	var space := player.get_world_3d().direct_space_state
	var q := PhysicsShapeQueryParameters3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 2.4
	q.shape = sph
	q.transform = Transform3D(Basis.IDENTITY, at + Vector3(0, 0.6, 0))
	q.collision_mask = 32
	q.collide_with_areas = true
	q.collide_with_bodies = false
	for r in space.intersect_shape(q, 16):
		var area := r["collider"] as Hurtbox
		if area and area.owner and not (area.owner in already):
			already.append(area.owner)
			area.take_hit(wave, player)


func exit() -> void:
	player.sword_hitbox.deactivate()
