extends PlayerState
## Jumping attack: attack in the air and you hang for a beat with the sword
## raised, then drop fast in an overhead slash and slam into the ground with
## a little shockwave. Hits on the way down and again on landing.
## Dual pistols instead fire both guns down at once (Gun Rain): a scatter blast
## whose recoil launches you forward, pitched nose-down, righting yourself
## before it ends.
## A katana instead gives a little lift and sweeps one big arc down under you
## (once per jump).
## An axe (Skybreaker) springs higher into a forward somersault, then comes down
## two-handed and splits the ground in a line ahead: everyone along it is
## knocked flat.
## Learned moves for the rest (once per jump unless said):
## * Twin Cyclone (dual swords): a little lift with the blades crossed, then a
##   drill of turns down and forward, both blades out, cutting everyone close
##   on every turn, and a burst on landing that knocks them flat.
## * Meteor Kick (unarmed): a chambered beat, then a dive kick at the aimed
##   enemy that knocks them flat and bounces you back up for another (a few in
##   a row); a miss slams the ground.
## * Hang Shot (one pistol): hang in the air drawing a bead, one heavy shot at
##   the reticle that knocks them flat, and the recoil throws you back.
## * Boarding Dive (cutlass): the blade drawn back, then a point-first dive at
##   the aimed enemy and a backflip off them; a miss lands like the plunge.

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

const AXE_HANG := 0.36                   # s of somersault before the dive
const AXE_LIFT := 4.5                    # m/s up as it springs
const AXE_LINE := 5.5                    # m of ground split ahead on landing
const AXE_LINE_W := 1.6
const AXE_LINE_DAMAGE := 18.0

const CYCLONE_LEN := 0.8                 # the pose; still airborne after it: falling
const CYCLONE_WIND := 0.14               # s, blades crossed
const CYCLONE_LIFT := 3.0
const CYCLONE_DRILL := Vector2(6.0, 8.0) # m/s forward, down while spinning
const CYCLONE_TICK := 0.11               # s between cuts (a turn)
const CYCLONE_R := 2.6
const CYCLONE_DAMAGE := 7.0
const CYCLONE_LAND_R := 3.0
const CYCLONE_LAND_DAMAGE := 12.0

const METEOR_COCK := 0.12
const METEOR_SPEED := 21.0
const METEOR_REACH := 12.0
const METEOR_DAMAGE := 20.0
const METEOR_BOUNCE := Vector2(3.5, 9.0) # m/s back, up off the one you kicked
const METEOR_MAX := 1.0                  # s of dive before giving up

const HANGSHOT_LEN := 0.62
const HANGSHOT_FIRE := 0.3
const HANGSHOT_RANGE := 40.0
const HANGSHOT_DAMAGE := 30.0
const HANGSHOT_RECOIL := Vector2(5.0, 3.0)

const DIVE_COCK := 0.16
const DIVE_LUNGE := 19.0
const DIVE_DAMAGE := 26.0
const DIVE_VAULT := Vector2(4.5, 7.5)
const DIVE_MAX := 1.0

## Which: "" (the plain plunge), "rain", "air_slash", "skybreaker",
## "twin_cyclone", "meteor_kick", "hang_shot", "boarding_dive".
var _mode := ""
var phase: int = 0   # 0 hang/wind-up, 1 dive, 2 land, 3 off (bounced / vaulted / fired)
var timer: float = 0.0
var _dir := Vector3.ZERO
var _fired := false
var _target: Node3D = null
var _line := Vector3.ZERO
var _ticks := 0
var _struck: Array = []


func enter(_data: Dictionary) -> void:
	phase = 0
	timer = 0.0
	player.reset_combo()
	var f := get_camera_forward()
	player.player_model.rotation.y = atan2(-f.x, -f.z)
	_dir = f
	_fired = false
	_ticks = 0
	_struck = []
	_target = null
	_mode = "rain" if player.style() == "dual_pistol" else air_move()
	if _mode in ["twin_cyclone", "meteor_kick", "hang_shot", "boarding_dive"]:
		player.air_uses[_mode] = int(player.air_uses.get(_mode, 0)) + 1
	match _mode:
		"rain":
			player.gun_rains += 1
			player.velocity = Vector3(player.velocity.x * 0.4, maxf(player.velocity.y, 0.0) * 0.3, player.velocity.z * 0.4)
			player.body_model.play("gun_rain", RAIN_DUR)
		"air_slash":
			player.air_slashes += 1
			player.variable_jump_active = false
			player.velocity = Vector3(player.velocity.x * 0.5, maxf(player.velocity.y, 0.0) * 0.3 + SLASH_BOOST, player.velocity.z * 0.5)
			player.body_model.play("air_slash", SLASH_DUR)
			player.set_reach("under")
			player.squash(1.5)
			Net.fx("sfx", ["whoosh", player.global_position, -8.0, 0.06, 0.9])
		"skybreaker":
			player.velocity = Vector3(player.velocity.x * 0.3, AXE_LIFT, player.velocity.z * 0.3)
			player.body_model.play("axe_flip", AXE_HANG / 0.62)
			player.squash(2.5)
			Net.fx("sfx", ["whoosh_big", player.global_position, -6.0, 0.06, 0.7])
		"twin_cyclone":
			player.variable_jump_active = false
			player.velocity = Vector3(player.velocity.x * 0.3, maxf(player.velocity.y, 0.0) * 0.2 + CYCLONE_LIFT, player.velocity.z * 0.3)
			player.body_model.play("twin_cyclone", CYCLONE_LEN)
			player.squash(1.5)
			Net.fx("sfx", ["whoosh", player.global_position, -8.0, 0.06, 0.8])
		"meteor_kick", "boarding_dive":
			player.variable_jump_active = false
			player.velocity = Vector3(player.velocity.x * 0.2, maxf(player.velocity.y, 0.0) * 0.2, player.velocity.z * 0.2)
			_target = _aimed(METEOR_REACH)
			if _target:
				var to := _target.global_position - player.global_position
				player.player_model.rotation.y = atan2(-to.x, -to.z)
			player.body_model.play(_mode, 0.6)
			player.squash(1.5)
			if _mode == "boarding_dive":
				Net.fx("sfx", ["parry", player.global_position, -14.0, 0.05, 1.4])
		"hang_shot":
			player.variable_jump_active = false
			player.velocity = Vector3(player.velocity.x * 0.3, maxf(player.velocity.y, 0.0) * 0.2, player.velocity.z * 0.3)
			var cam := player.get_viewport().get_camera_3d()
			if cam:
				player.body_model.aim_pitch = clampf(asin(clampf(-cam.global_basis.z.y, -1.0, 1.0)), -0.9, 0.6)
			player.body_model.play("hang_shot", HANGSHOT_LEN)
			Net.fx("sfx", ["blip", player.global_position, -10.0, 0.05, 0.6])
		_:
			player.velocity = Vector3(player.velocity.x * 0.3, 2.5, player.velocity.z * 0.3)
			player.body_model.play("plunge_air", 0.6)
			player.squash(2.0)
			Net.fx("sfx", ["whoosh", player.global_position, -6.0, 0.06, 0.8])


func physics_update(delta: float) -> void:
	timer += delta
	match _mode:
		"rain":
			_rain_update(delta)
			return
		"air_slash":
			_slash_update(delta)
			return
		"twin_cyclone":
			_cyclone_update(delta)
			return
		"meteor_kick", "boarding_dive":
			_dive_update(delta)
			return
		"hang_shot":
			_hang_update(delta)
			return
	var axe := _mode == "skybreaker"
	match phase:
		0:
			# brief hang at the top (the axe: rising through its somersault)
			player.velocity.y = move_toward(player.velocity.y, 0.0, (12.0 if axe else 30.0) * delta)
			player.move_and_slide()
			if timer >= (AXE_HANG if axe else HANG):
				phase = 1
				timer = 0.0
				player.velocity = _dir * 3.5 + Vector3.DOWN * DIVE_SPEED
				if axe:
					Net.fx("slash", [player.player_model, "overhead", 0.3, _axe_col()])
				else:
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
			_recover(delta)


func _recover(delta: float, secs: float = RECOVER) -> void:
	player.velocity.x = move_toward(player.velocity.x, 0.0, 30.0 * delta)
	player.velocity.z = move_toward(player.velocity.z, 0.0, 30.0 * delta)
	apply_gravity(delta)
	player.move_and_slide()
	if timer >= secs:
		transitioned.emit(self, "Idle", {})
	elif timer > secs * 0.5 and wants_dodge():
		transitioned.emit(self, "Dodge", {})


func _land() -> void:
	phase = 2
	timer = 0.0
	player.sword_hitbox.deactivate()
	player.velocity = Vector3.ZERO
	if _mode == "skybreaker":
		_split_ground()
		return
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
	_burst(at, 2.4, wave, player.sword_hitbox.hit_targets.duplicate())


## Everyone within `r` of `at` (not in `already`) takes `hit`.
func _burst(at: Vector3, r: float, hit: HitData, already: Array) -> void:
	var q := PhysicsShapeQueryParameters3D.new()
	var sph := SphereShape3D.new()
	sph.radius = r
	q.shape = sph
	q.transform = Transform3D(Basis.IDENTITY, at + Vector3(0, 0.6, 0))
	q.collision_mask = 32
	q.collide_with_areas = true
	q.collide_with_bodies = false
	for res in player.get_world_3d().direct_space_state.intersect_shape(q, 16):
		var area := res["collider"] as Hurtbox
		if area and area.owner and area.owner != player and not (area.owner in already):
			already.append(area.owner)
			area.take_hit(hit, player)


## Skybreaker's colour: the axe's own, its tree's once the element is on every blow.
func _axe_col() -> Color:
	if player.power.buff("coat"):
		return Player.HAKI_TRAIL
	return FX.tree_col("axe", FX.EDGE) if player.progression.elemental("axe", 2) else Color(1.0, 0.78, 0.5)


## Skybreaker's landing: the axe bites into the ground and splits it in a line
## ahead; everyone along the line (not already struck on the way down) is
## knocked flat.
func _split_ground() -> void:
	player.body_model.play("axe_land", RECOVER + 0.15)
	player.squash(-4.5)
	var f := -player.player_model.global_basis.z
	f.y = 0.0
	f = f.normalized()
	var start := player.global_position + f * 0.8
	# (molten, with embers, once the axe's element is on every blow)
	var elem := player.progression.elemental("axe", 2)
	Net.fx("ground_crack", [start, f, AXE_LINE, FX.tree_col("axe", FX.ACCENT) if elem else Color(0, 0, 0, 0), randi() % 10000, 0.15])
	for i in range(6):
		var p := start + f * (i * AXE_LINE / 5.0)
		Net.fx("dust", [p + Vector3(0, 0.05, 0), 6, 0.6 + i * 0.08])
		if i % 2 == 0:
			Net.fx("debris", [p + Vector3(0, 0.1, 0), Vector3.UP + f * 0.3, 4, Color(0.35, 0.3, 0.25), 5.0])
		if elem:
			Net.fx("embers", [p + Vector3(0, 0.2, 0), Vector3.UP, 4, FX.tree_col("axe", FX.ACCENT), 3.0])
	Net.fx("dust_ring", [start, 14, 0.9])
	Net.fx("ring", [start, Vector3.UP, 2.2, _axe_col(), 0.28, 0.12])
	Net.fx("impact", [start + Vector3(0, 0.2, 0), Color(1.0, 0.85, 0.55)])
	Net.fx("sfx", ["thud", start, 2.0, 0.05, 0.7])
	Net.fx("sfx", ["crunch", start + f * 2.0, -2.0, 0.05, 0.6])
	CombatManager.apply_camera_shake(0.3)
	CombatManager.apply_camera_kick(0.18, 0.3)
	var wave := player.melee_hit(AXE_LINE_DAMAGE)
	wave.knockdown = true
	wave.knockback_force = 9.0
	wave.stagger_duration = 0.6
	wave.hitstop_duration = 0.06
	wave.camera_shake_intensity = 0.0
	var already: Array = player.sword_hitbox.hit_targets.duplicate()
	var q := PhysicsShapeQueryParameters3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(AXE_LINE_W, 1.8, AXE_LINE)
	q.shape = box
	q.transform = Transform3D(Basis.looking_at(f, Vector3.UP), start + f * (AXE_LINE * 0.5) + Vector3(0, 0.8, 0))
	q.collision_mask = 32
	q.collide_with_areas = true
	q.collide_with_bodies = false
	for r in player.get_world_3d().direct_space_state.intersect_shape(q, 16):
		var area := r["collider"] as Hurtbox
		if area and area.owner and area.owner != player and not (area.owner in already):
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


# --------------------------------------------------------------------------
# The learned air attacks
# --------------------------------------------------------------------------
## The tree's colours once its element is awakened, plain steel before.
func _look(tree: String, which: int) -> Color:
	return FX.tree_col(tree if player.progression.elemental(tree) else "plain", which)


func _trail(tree: String) -> Color:
	return Player.HAKI_TRAIL if player.power.buff("coat") else _look(tree, FX.EDGE)


## The enemy the camera's looking at within `reach`, out in front and not above
## you (the one a dive goes for), or null.
func _aimed(reach: float) -> Node3D:
	var best: Node3D = null
	var best_a := 0.7
	for e in player.power.enemies_in(player.global_position, reach):
		var hb := (e as Node).get("hurtbox") as Node3D
		if hb == null or hb.global_position.y > player.global_position.y + 1.0:
			continue
		var to := hb.global_position - player.global_position
		to.y = 0.0
		if to.length() < 0.5:
			continue
		var a := _dir.angle_to(to)
		if a < best_a:
			best_a = a
			best = hb
	return best


func _hit_one(hb: Hurtbox, hd: HitData) -> void:
	_struck.append(hb.owner)
	hb.take_hit(hd, player)
	player.power.on_sword_hit(hb.owner, hd)


## Twin Cyclone: crossed blades and a little lift, then the drill; a cut for
## everyone close on every turn, a burst on landing.
func _cyclone_update(delta: float) -> void:
	if phase == 2:
		_recover(delta)
		return
	var chest := player.global_position + Vector3(0, 1.0, 0)
	if phase == 0:
		player.velocity.y = move_toward(player.velocity.y, 0.0, 14.0 * delta)
		player.move_and_slide()
		if timer >= CYCLONE_WIND:
			phase = 1
			_line = _dir * CYCLONE_DRILL.x + Vector3.DOWN * CYCLONE_DRILL.y
			player.velocity = _line
			Net.fx("blade_swoosh", [player.body_model, CYCLONE_LEN - CYCLONE_WIND, _trail("dual")])
			Net.fx("sfx", ["whoosh_big", chest, -3.0, 0.06, 1.3])
		return
	player.velocity = _line
	player.move_and_slide()
	var since := timer - CYCLONE_WIND
	if since >= _ticks * CYCLONE_TICK:
		_ticks += 1
		# (the two colours turn and turn about, a ring of steel each turn)
		Net.fx("ring", [chest, Vector3.UP, CYCLONE_R * 0.9, _look("dual", FX.EDGE if _ticks % 2 == 0 else FX.ACCENT), 0.2, 0.1])
		Net.fx("sfx", ["whoosh", chest, -10.0, 0.08, 1.4 + 0.05 * _ticks])
		for e in player.power.enemies_in(chest, CYCLONE_R):
			var hb := (e as Node).get("hurtbox") as Hurtbox
			if hb == null:
				continue
			var hd := player.melee_hit(CYCLONE_DAMAGE)
			hd.knockback_force = 2.5
			hd.stagger_duration = 0.3
			hd.hitstop_duration = 0.02
			hd.camera_shake_intensity = 0.0
			_hit_one(hb, hd)
	if player.is_on_floor():
		phase = 2
		timer = 0.0
		player.velocity = Vector3.ZERO
		player.body_model.play("cyclone_land", RECOVER + 0.1)
		player.squash(-4.0)
		var at := player.global_position
		Net.fx("ring", [at + Vector3(0, 0.15, 0), Vector3.UP, CYCLONE_LAND_R, _look("dual", FX.EDGE), 0.32, 0.16])
		Net.fx("dust_ring", [at, 18, 1.1])
		Net.fx("impact", [at + Vector3(0, 0.5, 0), _look("dual", FX.CORE)])
		Net.fx("sfx", ["thud", at, 0.0, 0.05, 0.9])
		Net.fx("sfx", ["parry", at, -8.0, 0.05, 1.2])
		CombatManager.apply_camera_shake(0.22)
		var wave := player.melee_hit(CYCLONE_LAND_DAMAGE)
		wave.knockdown = true
		wave.knockback_force = 8.0
		wave.stagger_duration = 0.5
		wave.hitstop_duration = 0.06
		wave.camera_shake_intensity = 0.0
		_burst(at, CYCLONE_LAND_R, wave, [])
	elif timer >= CYCLONE_LEN:
		transitioned.emit(self, "Fall", {})


## Meteor Kick and Boarding Dive: a cocked beat, a straight dive at the aimed
## enemy (or down ahead), off them on contact.
func _dive_update(delta: float) -> void:
	var kick := _mode == "meteor_kick"
	var tree := "unarmed" if kick else "sword"
	match phase:
		0:
			player.velocity.y = move_toward(player.velocity.y, 0.0, 40.0 * delta)
			player.velocity.x = move_toward(player.velocity.x, 0.0, 20.0 * delta)
			player.velocity.z = move_toward(player.velocity.z, 0.0, 20.0 * delta)
			player.move_and_slide()
			var cock := METEOR_COCK if kick else DIVE_COCK
			if not kick and not _fired and timer >= cock - 0.06:
				_fired = true
				var w: MeshInstance3D = player.body_model.weapon
				if w and w.mesh:
					Net.fx("glint", [w.global_transform * Vector3(0, 0, w.mesh.get_aabb().position.z * 0.85), Color.WHITE, 0.6])
			if timer >= cock:
				phase = 1
				timer = 0.0
				var from := player.global_position + Vector3(0, 0.6, 0)
				if _target and is_instance_valid(_target):
					_line = (_target.global_position - from).normalized()
					# (always down: a dive, not a flight across)
					if _line.y > -0.25:
						_line = (Vector3(_line.x, 0.0, _line.z).normalized() * 0.97 + Vector3.DOWN * 0.25).normalized()
				else:
					_line = (_dir * cos(0.7) + Vector3.DOWN * sin(0.7)).normalized()
				player.velocity = _line * (METEOR_SPEED if kick else DIVE_LUNGE)
				player.squash(3.0)
				Net.fx("ring", [from, _line, 0.9, _look(tree, FX.EDGE), 0.22, 0.1])
				Net.fx("sfx", ["whoosh_big", from, -4.0, 0.06, 1.25 if kick else 1.0])
				if kick:
					Net.fx("punch_wind", [from, _line, 1.8, _look("unarmed", FX.CORE), true])
				else:
					Net.fx("blade_swoosh", [player.body_model, 0.35, _trail("sword")])
				set_meta("from", from)
		1:
			player.velocity = _line * (METEOR_SPEED if kick else DIVE_LUNGE)
			player.move_and_slide()
			var front := player.global_position + Vector3(0, 0.7, 0) + _line * (0.5 if kick else 0.9)
			for e in player.power.enemies_in(front, 1.4):
				var hb := (e as Node).get("hurtbox") as Hurtbox
				if hb == null or hb.owner in _struck:
					continue
				_dive_hit(hb, kick, tree)
				return
			if player.is_on_floor() or timer > (METEOR_MAX if kick else DIVE_MAX) or player.is_on_wall():
				Net.fx("streak", [get_meta("from"), player.global_position + Vector3(0, 0.6, 0), _look(tree, FX.EDGE), 0.12, 0.25])
				_dive_land(kick, tree)
		2:
			_recover(delta, 0.34)
		3:
			# off them, flipping back: then it's an ordinary fall (another kick allowed)
			apply_gravity(delta)
			player.move_and_slide()
			if timer >= 0.35:
				transitioned.emit(self, "Fall", {})


func _dive_hit(hb: Hurtbox, kick: bool, tree: String) -> void:
	var at := hb.global_position
	var hd := player.melee_hit(METEOR_DAMAGE if kick else DIVE_DAMAGE)
	hd.knockback_force = 9.0 if kick else 7.5
	hd.stagger_duration = 0.6
	hd.hitstop_duration = 0.09
	hd.camera_shake_intensity = 0.2
	hd.knockdown = kick
	hd.sever = not kick
	_hit_one(hb, hd)
	Net.fx("streak", [get_meta("from"), at, _look(tree, FX.EDGE), 0.14, 0.28])
	Net.fx("impact", [at, _look(tree, FX.ACCENT)])
	Net.fx("ring", [at, _line, 1.4, _look(tree, FX.EDGE), 0.25, 0.14])
	if player.progression.elemental(tree):
		if kick:
			Net.fx("punch_wind", [at, _line, 1.6, _look(tree, FX.CORE), true])
		else:
			Net.fx("spray", [at, _line + Vector3.UP * 0.3, 12, _look(tree, FX.ACCENT), 6.0])
	Net.fx("sfx", ["hit", at, 0.0, 0.05, 0.65 if kick else 0.85])
	CombatManager.apply_camera_kick(0.2, 0.25)
	if kick:
		player.air_uses["bounce"] = int(player.air_uses.get("bounce", 0)) + 1
	var back := Vector3(_line.x, 0.0, _line.z).normalized()
	var off := METEOR_BOUNCE if kick else DIVE_VAULT
	player.velocity = -back * off.x + Vector3.UP * off.y
	player.body_model.play("vault_back", 0.45)
	phase = 3
	timer = 0.0


func _dive_land(kick: bool, tree: String) -> void:
	phase = 2
	timer = 0.0
	player.velocity = Vector3.ZERO
	var at := player.global_position
	player.squash(-4.0)
	Net.fx("dust_ring", [at, 16 if kick else 12, 1.0])
	Net.fx("sfx", ["thud", at, 0.0 if kick else -3.0, 0.05, 0.8])
	CombatManager.apply_camera_shake(0.18 if kick else 0.12)
	if kick:
		# the heel into the ground: a small shockwave
		player.body_model.play("meteor_land", 0.44)
		Net.fx("ring", [at + Vector3(0, 0.12, 0), Vector3.UP, 2.4, _look(tree, FX.EDGE), 0.28, 0.14])
		var wave := player.melee_hit(8.0)
		wave.knockback_force = 7.0
		wave.stagger_duration = 0.4
		wave.hitstop_duration = 0.04
		wave.camera_shake_intensity = 0.0
		_burst(at, 2.2, wave, _struck.duplicate())
	else:
		player.body_model.play("plunge_land", 0.44)


## Hang Shot: hang drawing a bead, one heavy ball at the reticle, the recoil
## throwing you back.
func _hang_update(delta: float) -> void:
	if not _fired:
		player.velocity.y = move_toward(player.velocity.y, -0.8, 8.0 * delta)
		player.velocity.x = move_toward(player.velocity.x, 0.0, 10.0 * delta)
		player.velocity.z = move_toward(player.velocity.z, 0.0, 10.0 * delta)
		face_direction(get_camera_forward(), 1.0)
		if timer >= HANGSHOT_FIRE - 0.08 and phase == 0:
			phase = 1
			var gun := player.body_model.weapon as Node3D
			Net.fx("glint", [gun.global_transform * Vector3(0, 0.06, -0.24) if gun else player.global_position + Vector3(0, 1.3, 0), _look("pistol", FX.CORE), 0.5])
		if timer >= HANGSHOT_FIRE:
			_fired = true
			_hang_fire()
	else:
		apply_gravity(delta)
	player.move_and_slide()
	if _fired and player.is_on_floor() and timer > HANGSHOT_FIRE + 0.1:
		transitioned.emit(self, "Idle", {})
	elif timer >= HANGSHOT_LEN:
		transitioned.emit(self, "Fall", {})


func _hang_fire() -> void:
	var gun := player.body_model.weapon as Node3D
	var muzzle: Vector3 = gun.global_transform * Vector3(0, 0.06, -0.24) if gun else player.global_position + Vector3(0, 1.35, 0)
	var space := player.get_world_3d().direct_space_state
	var target := muzzle + get_camera_forward() * HANGSHOT_RANGE
	var ray := player.reticle_ray()
	if not ray.is_empty():
		var cd: Vector3 = ray[1]
		var from: Vector3 = ray[0]
		from += cd * maxf((player.global_position - from).dot(cd), 0.0)
		var q := PhysicsRayQueryParameters3D.create(from, from + cd * HANGSHOT_RANGE, 1 | 4 | 2048)
		q.exclude = [player.get_rid()]
		var h := space.intersect_ray(q)
		target = (h["position"] as Vector3) if not h.is_empty() else from + cd * HANGSHOT_RANGE
		# (aim assist, a touch wider than a plain shot's: you're in the air)
		var best_a := 0.1
		for e in player.power.enemies_in(player.global_position, HANGSHOT_RANGE):
			var hb := (e as Node).get("hurtbox") as Hurtbox
			if hb == null:
				continue
			var a := cd.angle_to(hb.global_position - from)
			if a < best_a:
				best_a = a
				target = hb.global_position
	var dir := (target - muzzle).normalized()
	player.body_model.aim_pitch = clampf(asin(clampf(dir.y, -1.0, 1.0)), -0.9, 0.6)
	var end := muzzle + dir * HANGSHOT_RANGE
	var wq := PhysicsRayQueryParameters3D.create(muzzle, end, 1)
	wq.exclude = [player.get_rid()]
	var wall := space.intersect_ray(wq)
	if not wall.is_empty():
		end = wall["position"]
	var eq := PhysicsRayQueryParameters3D.create(muzzle, end, 32)
	eq.collide_with_areas = true
	eq.collide_with_bodies = false
	var hit := space.intersect_ray(eq)
	if not hit.is_empty() and hit["collider"] is Hurtbox and (hit["collider"] as Hurtbox).owner != player:
		var hb := hit["collider"] as Hurtbox
		end = hit["position"]
		var hd := player.melee_hit(HANGSHOT_DAMAGE)
		hd.ranged = true
		hd.knockdown = true
		hd.knockback_force = 9.0
		hd.stagger_duration = 0.6
		hd.hitstop_duration = 0.08
		hd.camera_shake_intensity = 0.18
		_hit_one(hb, hd)
		Net.fx("impact", [end, _look("pistol", FX.ACCENT)])
		Net.fx("ring", [end, -dir, 1.1, _look("pistol", FX.EDGE), 0.22, 0.12])
	else:
		Net.fx("dust", [end, 5, 0.5])
	player.ammo[0] -= 1
	if player.ammo[0] <= 0:
		player.call_deferred("start_reload")
	Net.fx("tracer", [muzzle, end])
	Net.fx("muzzle_sparks", [muzzle, dir, 16])
	Net.fx("smoke", [muzzle + dir * 0.2, 8, 0.7, 1.2])
	Net.fx("ring", [muzzle + dir * 0.3, dir, 0.8, _look("pistol", FX.EDGE), 0.2, 0.1])
	if player.progression.elemental("pistol"):
		Net.fx("sparkle", [muzzle + dir * 0.4, 10, _look("pistol", FX.ACCENT)])
	Net.fx("sfx", ["gunshot", muzzle, 0.0, 0.05, 0.85])
	CombatManager.apply_camera_shake(0.16)
	var back := Vector3(dir.x, 0.0, dir.z).normalized()
	player.velocity = -back * HANGSHOT_RECOIL.x + Vector3.UP * HANGSHOT_RECOIL.y
	player.squash(-2.0)


func exit() -> void:
	if _mode == "rain":
		player.align_hold = false
		player.align_w = 0.0
	player.sword_hitbox.deactivate()
