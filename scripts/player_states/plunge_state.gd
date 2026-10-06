extends PlayerState
## Jumping attack: attack in the air and you hang for a beat with the sword
## raised, then drop fast in an overhead slash and slam into the ground with
## a little shockwave. Hits on the way down and again on landing.
## Dual pistols instead fire straight down (Gun Rain): a quick spinning volley,
## each shot's recoil holding you up in the air, the last one from both guns.

const HANG := 0.16
const DIVE_SPEED := 22.0
const RECOVER := 0.38

const RAIN_DUR := 0.31
const RAIN_KICK := 1.6        # m/s up from each shot's recoil
const RAIN_GRAVITY := 0.45    # x gravity between shots
const RAIN_REACH := 2.6       # m sideways from under you that a shot can find
const RAIN_DEPTH := 14.0
const RAIN_DAMAGE := 5.0

var phase: int = 0   # 0 hang, 1 dive, 2 land
var timer: float = 0.0
var _dir := Vector3.ZERO
var _rain := false
var _shots := 0


func enter(_data: Dictionary) -> void:
	phase = 0
	timer = 0.0
	player.reset_combo()
	var f := get_camera_forward()
	player.player_model.rotation.y = atan2(-f.x, -f.z)
	_dir = f
	_rain = player.style() == "dual_pistol"
	_shots = 0
	if _rain:
		player.gun_rains += 1
		player.velocity =Vector3(player.velocity.x * 0.4, maxf(player.velocity.y, 0.0) * 0.3 + 2.0, player.velocity.z * 0.4)
		player.body_model.play("gun_rain", RAIN_DUR)
		player.squash(1.5)
		Net.fx("sfx", ["whoosh", player.global_position, -6.0, 0.06, 1.3])
		return
	player.velocity = Vector3(player.velocity.x * 0.3, 2.5, player.velocity.z * 0.3)
	player.body_model.play("plunge_air", 0.6)
	player.squash(2.0)
	Net.fx("sfx", ["whoosh", player.global_position, -6.0, 0.06, 0.8])


func physics_update(delta: float) -> void:
	timer += delta
	if _rain:
		_rain_update(delta)
		return
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


func _rain_update(delta: float) -> void:
	player.velocity.y = maxf(player.velocity.y - player.gravity * RAIN_GRAVITY * delta, -8.0)
	var mi := get_movement_input()
	var want := get_camera_relative_direction(mi) * player.move_speed * 0.4 if mi.length() > 0.1 else Vector3.ZERO
	player.velocity.x = move_toward(player.velocity.x, want.x, 20.0 * delta)
	player.velocity.z = move_toward(player.velocity.z, want.z, 20.0 * delta)
	player.move_and_slide()
	while _shots < Humanoid.GUN_RAIN_SHOTS and timer >= (Humanoid.GUN_RAIN_FIRST + Humanoid.GUN_RAIN_STEP * _shots) * RAIN_DUR:
		var last := _shots == Humanoid.GUN_RAIN_SHOTS - 1
		if last or _shots % 2 == 0:
			_rain_shot(player.body_model.weapon, last)
		if last or _shots % 2 == 1:
			_rain_shot(player.body_model.offhand, last)
		player.velocity.y = maxf(player.velocity.y, RAIN_KICK * (1.8 if last else 1.0))
		_shots += 1
	if player.is_on_floor() and timer > 0.1:
		transitioned.emit(self, "Idle", {})
	elif timer >= RAIN_DUR:
		transitioned.emit(self, "Fall", {})


## One shot straight down from a gun's muzzle: it finds an enemy below you
## (the nearest under that gun) or hits the ground.
func _rain_shot(gun: Node3D, last: bool) -> void:
	if gun == null or not is_instance_valid(gun):
		return
	var muzzle := gun.global_transform * Vector3(0, 0.06, -0.24)
	var space := player.get_world_3d().direct_space_state
	var gq := PhysicsRayQueryParameters3D.create(muzzle, muzzle + Vector3.DOWN * RAIN_DEPTH, 1)
	gq.exclude = [player.get_rid()]
	var ground := space.intersect_ray(gq)
	var end: Vector3 = ground["position"] if not ground.is_empty() else muzzle + Vector3.DOWN * RAIN_DEPTH
	var best: Hurtbox = null
	var best_d := RAIN_REACH
	for e in player.power.enemies_in(muzzle + Vector3.DOWN * RAIN_DEPTH * 0.5, RAIN_DEPTH * 0.5 + RAIN_REACH):
		var hb := (e as Node).get("hurtbox") as Hurtbox
		if hb == null or hb.global_position.y > muzzle.y:
			continue
		var d := Vector2(hb.global_position.x - muzzle.x, hb.global_position.z - muzzle.z).length()
		if d < best_d:
			best_d = d
			best = hb
	if best:
		end = best.global_position
		var hd := player.melee_hit(RAIN_DAMAGE * (1.5 if last else 1.0))
		hd.ranged = true
		hd.knockback_force = 6.0 if last else 2.0
		hd.stagger_duration = 0.3
		hd.hitstop_duration = 0.03
		hd.camera_shake_intensity = 0.05
		hd.knockdown = last
		best.take_hit(hd, player)
		player.power.on_sword_hit(best.owner, hd)
		Net.fx("impact", [end, Color(1.0, 0.75, 0.45)])
	else:
		Net.fx("dust", [end + Vector3(0, 0.05, 0), 4 if last else 2, 0.4])
	Net.fx("tracer", [muzzle, end])
	Net.fx("muzzle_sparks", [muzzle, Vector3.DOWN, 10 if last else 7])
	Net.fx("smoke", [muzzle + Vector3.DOWN * 0.2, 3, 0.45, 0.9])
	Net.fx("sfx", ["gunshot", muzzle, -5.0, 0.1, 1.2 if last else 1.35])
	CombatManager.apply_camera_shake(0.08 if last else 0.04)
	if last and not ground.is_empty() and muzzle.y - end.y < 6.0:
		Net.fx("dust_ring", [end, 10, 0.7])


func exit() -> void:
	player.sword_hitbox.deactivate()
