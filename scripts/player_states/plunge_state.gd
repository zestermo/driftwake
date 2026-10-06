extends PlayerState
## Jumping attack: attack in the air and you hang for a beat with the sword
## raised, then drop fast in an overhead slash and slam into the ground with
## a little shockwave. Hits on the way down and again on landing.
## Dual pistols instead fire both guns down at once (Gun Rain): a scatter blast
## whose recoil launches you forward, pitched nose-down, righting yourself
## before it ends.
## A katana instead gives a little lift and sweeps one big arc down under you
## (once per jump).

const HANG := 0.16
const DIVE_SPEED := 22.0
const RECOVER := 0.38

const RAIN_DUR := 0.6
const RAIN_LAUNCH := Vector2(7.5, 5.5)   # m/s forward, up from the recoil
const RAIN_PITCH := 0.85                 # rad tipped forward at the blast, easing back upright
const RAIN_CONE := 0.55                  # rad around the shot line an enemy is caught in
const RAIN_DEPTH := 10.0
const RAIN_PELLETS := 4                  # per gun (for show; enemies are judged by the cone)
const RAIN_DAMAGE := 20.0

const SLASH_DUR := 0.6
const SLASH_BOOST := 4.0                 # m/s up as the slash starts
const SLASH_HIT := Vector2(0.17, 0.34)   # s: hitbox on..off (the arc under you)
const SLASH_DAMAGE := 24.0

var phase: int = 0   # 0 hang, 1 dive, 2 land
var timer: float = 0.0
var _dir := Vector3.ZERO
var _rain := false
var _slash := false
var _fired := false


func enter(_data: Dictionary) -> void:
	phase = 0
	timer = 0.0
	player.reset_combo()
	var f := get_camera_forward()
	player.player_model.rotation.y = atan2(-f.x, -f.z)
	_dir = f
	_rain = player.style() == "dual_pistol"
	_slash = false
	_fired = false
	if _rain:
		player.gun_rains += 1
		player.velocity = Vector3(player.velocity.x * 0.4, maxf(player.velocity.y, 0.0) * 0.3, player.velocity.z * 0.4)
		player.body_model.play("gun_rain", RAIN_DUR)
		return
	_slash = player.style() == "katana"
	if _slash:
		player.air_slashes += 1
		player.variable_jump_active = false
		player.velocity = Vector3(player.velocity.x * 0.5, maxf(player.velocity.y, 0.0) * 0.3 + SLASH_BOOST, player.velocity.z * 0.5)
		player.body_model.play("air_slash", SLASH_DUR)
		player.set_reach("under")
		player.squash(1.5)
		Net.fx("sfx", ["whoosh", player.global_position, -8.0, 0.06, 0.9])
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
	if _slash:
		_slash_update(delta)
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
				hit.sever = player.weapon_class() == "sword"
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
	var blast_t := Humanoid.GUN_RAIN_AT * RAIN_DUR
	if not _fired:
		# a beat to point the guns down, hanging
		player.velocity.y = move_toward(player.velocity.y, 0.0, 40.0 * delta)
		if timer >= blast_t:
			_fired = true
			_rain_blast()
			player.velocity = _dir * RAIN_LAUNCH.x + Vector3.UP * RAIN_LAUNCH.y
	else:
		apply_gravity(delta)
	player.move_and_slide()
	# pitched forward by the blast, swinging back upright before it ends
	var k := 0.0
	if _fired:
		var since := timer - blast_t
		var back := RAIN_DUR - blast_t
		k = clampf(since / 0.05, 0.0, 1.0) * (1.0 - smoothstep(back * 0.35, back * 0.95, since))
	player.align_hold = true
	player.align_up = (Vector3.UP + _dir * tan(RAIN_PITCH * k)).normalized()
	player.align_w = 1.0
	if player.is_on_floor() and _fired and timer > blast_t + 0.1:
		transitioned.emit(self, "Idle", {})
	elif timer >= RAIN_DUR:
		transitioned.emit(self, "Fall", {})


## Both guns at once, down and a little behind: a scatter of shot that catches
## every enemy inside the cone below, the rest kicking up dirt.
func _rain_blast() -> void:
	var line := (Vector3.DOWN - _dir * 0.3).normalized()
	var side := line.cross(_dir).normalized()
	var across := line.cross(side).normalized()
	var space := player.get_world_3d().direct_space_state
	var muzzles: Array = []
	for gun in [player.body_model.weapon, player.body_model.offhand]:
		if gun != null and is_instance_valid(gun):
			muzzles.append((gun as Node3D).global_transform * Vector3(0, 0.06, -0.24))
	var centre := player.global_position + Vector3.UP * 0.9
	if muzzles.is_empty():
		muzzles.append(centre)
	for m in muzzles:
		var muzzle: Vector3 = m
		for i in range(RAIN_PELLETS):
			var a := randf() * TAU
			var r := sqrt(randf()) * tan(RAIN_CONE * 0.8)
			var d := (line + side * cos(a) * r + across * sin(a) * r).normalized()
			var q := PhysicsRayQueryParameters3D.create(muzzle, muzzle + d * RAIN_DEPTH, 1)
			q.exclude = [player.get_rid()]
			var h := space.intersect_ray(q)
			var end: Vector3 = h["position"] if not h.is_empty() else muzzle + d * RAIN_DEPTH
			Net.fx("tracer", [muzzle, end])
			if not h.is_empty():
				Net.fx("dust", [end + Vector3(0, 0.05, 0), 2, 0.35])
		Net.fx("muzzle_sparks", [muzzle, line, 14])
		Net.fx("smoke", [muzzle + line * 0.2, 6, 0.6, 1.1])
		Net.fx("sfx", ["gunshot", muzzle, -2.0, 0.08, 0.9])
	for e in player.power.enemies_in(centre + line * RAIN_DEPTH * 0.5, RAIN_DEPTH * 0.5 + 1.0):
		var hb := (e as Node).get("hurtbox") as Hurtbox
		if hb == null:
			continue
		var to := hb.global_position - centre
		if to.length() > RAIN_DEPTH or line.angle_to(to) > RAIN_CONE:
			continue
		var hd := player.melee_hit(RAIN_DAMAGE)
		hd.ranged = true
		hd.knockback_force = 7.0
		hd.stagger_duration = 0.4
		hd.hitstop_duration = 0.05
		hd.camera_shake_intensity = 0.0
		hd.knockdown = true
		hb.take_hit(hd, player)
		player.power.on_sword_hit(hb.owner, hd)
		Net.fx("tracer", [muzzles[0], hb.global_position])
		Net.fx("impact", [hb.global_position, Color(1.0, 0.75, 0.45)])
	player.squash(-2.5)
	CombatManager.apply_camera_shake(0.14)


func _slash_update(delta: float) -> void:
	apply_gravity(delta)
	var mi := get_movement_input()
	var want := get_camera_relative_direction(mi) * player.move_speed * 0.5 if mi.length() > 0.1 else Vector3.ZERO
	player.velocity.x = move_toward(player.velocity.x, want.x, 10.0 * delta)
	player.velocity.z = move_toward(player.velocity.z, want.z, 10.0 * delta)
	player.move_and_slide()
	if not _fired and timer >= SLASH_HIT.x:
		_fired = true
		var hit := player.melee_hit(SLASH_DAMAGE)
		hit.sever = true
		hit.knockback_force = 7.0
		hit.stagger_duration = 0.5
		hit.hitstop_duration = 0.06
		hit.camera_shake_intensity = 0.14
		player.sword_hitbox.activate(hit)
		var col: Color = Player.HAKI_TRAIL if player.power.buff("coat") else Color(0.85, 0.92, 1.0)
		Net.fx("slash", [player.player_model, "under", 0.3, col])
		Net.fx("sfx", ["whoosh_big", player.global_position, -4.0, 0.06, 1.2])
	if _fired and timer >= SLASH_HIT.y:
		player.sword_hitbox.deactivate()
	if player.is_on_floor() and timer > 0.15:
		transitioned.emit(self, "Idle", {})
	elif timer >= SLASH_DUR:
		transitioned.emit(self, "Fall", {})


func exit() -> void:
	if _rain:
		player.align_hold = false
		player.align_w = 0.0
	player.sword_hitbox.deactivate()
