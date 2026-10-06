extends PlayerState
## Casting a skill (PowerComponent.try_cast puts you here with {"slot", "id"}).
## Each skill is a short timeline: pose, the moment it goes off, and recovery.
## Body techniques: soru (instant step), tekkai (iron body). Sword:
## flying_slash, tiger_rush. Gun: bullet_storm. Haki: armament_coat,
## foresight. Wolf: rending_fang, pounce, howl. Vine: vine_snare, vine_swing
## (hands off to the Swing state), thorn_whip. Ember Fruit:
##   fire_fist   - throw a fireball where the camera aims
##   flame_dash  - untouchable burst forward through enemies, fire trail
##   fire_ring   - ring of fire around you, knocks enemies down
##   ember_field - set the ground ahead burning
##   inferno     - (ultimate) leap, slam, pillar of fire, burning ground

const DASH_SPEED := 17.0
const DASH_TIME := 0.32

var id: String = ""
var t: float = 0.0
var dur: float = 0.5
var _fired: bool = false
var _dir := Vector3.FORWARD
var _hit: Array = []
var _trail_dist: float = 0.0
var _last_pos := Vector3.ZERO
var _slammed: bool = false
var _airborne: bool = false
var _pc: PowerComponent
var _rakes: int = 0
var _shots: int = 0
var _target: Node3D
var _swing_to := Vector3.INF
var _anchor_fail: bool = false
var _zip_to: Node3D = null
var _pull: Node3D = null
var _rope: VineRope
var _wraps: Array = []


func enter(data: Dictionary) -> void:
	id = str(data.get("id", ""))
	_pc = player.power
	t = 0.0
	_fired = false
	_slammed = false
	_airborne = false
	_rakes = 0
	_shots = 0
	_swing_to = Vector3.INF
	_anchor_fail = false
	_zip_to = null
	_pull = null
	_rope = null
	_wraps = []
	_target = null
	_hit.clear()
	player.sprinting = false
	player.is_parrying = false
	player.sword_hitbox.deactivate()
	player.reset_combo()
	var fwd := -player.player_model.global_basis.z
	fwd.y = 0.0
	fwd = fwd.normalized() if fwd.length() > 0.01 else Vector3.FORWARD
	_dir = fwd
	var hand_glow := player.global_position + Vector3(0, 1.2, 0)
	match id:
		"fire_fist":
			dur = 0.45
			_dir = get_camera_forward()
			face_direction(_dir, 1.0)
			player.body_model.play("fire_punch", dur)
		"flame_dash":
			dur = 0.5
			var mi := get_movement_input()
			_dir = get_camera_relative_direction(mi) if mi.length() > 0.1 else fwd
			face_direction(_dir, 1.0)
			player.hurtbox.set_deferred("monitorable", false)
			player.body_model.play("flame_dash", dur)
			_last_pos = player.global_position
			_trail_dist = 0.0
			Net.fx("flame", [player.global_position + Vector3(0, 0.8, 0), 14, 0.8, 0.5, 0.4])
			Net.fx("sfx", ["fire_burst", player.global_position, -3.0, 0.1, 1.25])
			CombatManager.apply_camera_shake(player.DASH_SHAKE * 1.5)
		"fire_ring":
			dur = 0.6
			player.body_model.play("fire_ring", dur)
			Net.fx("flame", [hand_glow, 6, 0.5, 0.35, 0.3])
		"ember_field":
			dur = 0.55
			_dir = get_camera_forward()
			face_direction(_dir, 1.0)
			player.body_model.play("fire_plant", dur)
		"inferno":
			dur = 1.15
			player.hurtbox.set_deferred("monitorable", false)
			player.body_model.play("inferno", dur)
			player.velocity = Vector3(0.0, 7.5, 0.0)
			_airborne = true
			Net.fx("flame", [player.global_position + Vector3(0, 0.6, 0), 20, 1.0, 0.6, 0.6])
			Net.fx("sfx", ["fire_burst", player.global_position, 0.0, 0.05, 0.8])
		"soru":
			dur = 0.24
			var mi2 := get_movement_input()
			_dir = get_camera_relative_direction(mi2) if mi2.length() > 0.1 else fwd
			face_direction(_dir, 1.0)
			player.hurtbox.set_deferred("monitorable", false)
			player.body_model.play("soru", dur)
			Net.fx("afterimage", [player.body_model, Color(0.6, 0.85, 1.0)])
			Net.fx("dust_ring", [player.global_position, 10, 0.7])
			Net.fx("sfx", ["whoosh_big", player.global_position, -4.0, 0.05, 1.5])
		"tekkai":
			dur = 0.45
			_pc.add_buff("tekkai", 3.0)
			player.body_model.play("tekkai", 3.0)
			Net.fx("sparkle", [player.global_position + Vector3(0, 1.0, 0), 14, Color(0.7, 0.72, 0.8)])
			Net.fx("sfx", ["hit", player.global_position, -4.0, 0.05, 0.6])
			player.call("_recalc_stats")
		"flying_slash":
			dur = 0.5
			_dir = get_camera_forward()
			face_direction(_dir, 1.0)
			player.body_model.play("flying_slash", dur)
		"tiger_rush":
			dur = 0.55
			_dir = get_camera_forward()
			face_direction(_dir, 1.0)
			player.hurtbox.set_deferred("monitorable", false)
			player.body_model.play("thrust", dur)
			Net.fx("sfx", ["whoosh_big", player.global_position, -3.0, 0.05, 1.2])
		"bullet_storm":
			dur = 0.75
			_dir = get_camera_forward()
			face_direction(_dir, 1.0)
			player.body_model.play("bullet_storm", dur)
		"armament_coat":
			dur = 0.45
			_pc.add_buff("coat", 8.0)
			player.body_model.play("coat", dur)
			player.update_coat_visual()
			Net.fx("sparkle", [player.global_position + Vector3(0, 1.2, 0), 18, Player.HAKI_SPARK])
			Net.fx("sfx", ["haki", player.global_position, -1.0, 0.03, 1.0])
			Net.fx("punch_wind", [player.global_position + Vector3.UP * 1.1, Vector3.UP, 0.4, Player.HAKI_TRAIL, true])
			CombatManager.apply_camera_shake(0.12)
		"foresight":
			dur = 0.4
			_pc.add_buff("foresight", 5.0)
			player.body_model.play("foresight", dur)
			Net.fx("sparkle", [player.global_position + Vector3(0, 1.7, 0), 12, Color(0.95, 0.5, 0.8)])
			Net.fx("sfx", ["blip_high", player.global_position, -6.0, 0.0, 0.8])
		"rending_fang":
			dur = 0.6
			_target = _nearest_enemy(7.0)
			if _target:
				var d := _target.global_position - player.global_position
				d.y = 0.0
				if d.length() > 0.1:
					_dir = d.normalized()
			face_direction(_dir, 1.0)
			player.body_model.play("rending_fang", dur)
			Net.fx("sfx", ["whoosh_big", player.global_position, -4.0, 0.05, 1.1])
		"pounce":
			dur = 1.0
			var aim := _aim_point(14.0)
			var d2 := aim - player.global_position
			var flat := Vector3(d2.x, 0, d2.z)
			_dir = flat.normalized() if flat.length() > 0.2 else fwd
			face_direction(_dir, 1.0)
			var air_t := 0.75
			var hsp := clampf(flat.length() / air_t, 4.0, 18.0)
			player.velocity = _dir * hsp + Vector3.UP * (player.gravity * air_t * 0.5 + clampf(d2.y / air_t, -3.0, 6.0))
			player.body_model.play("pounce", dur)
			Net.fx("dust_ring", [player.global_position, 10, 0.8])
			Net.fx("sfx", ["whoosh_big", player.global_position, -3.0, 0.05, 0.9])
		"howl":
			dur = 0.9
			player.body_model.play("howl", dur)
		"vine_snare":
			dur = 0.45
			_dir = get_camera_forward()
			face_direction(_dir, 1.0)
			player.body_model.play("vine_throw", dur)
			# vines coil up both arms as the seed is flung
			_wraps = Net.fx("arm_vines", [player.body_model, "both", dur + 0.15])
		"thorn_whip":
			dur = 0.55
			_dir = get_camera_forward()
			face_direction(_dir, 1.0)
			player.body_model.play("thorn_whip", dur)
		"vine_swing":
			dur = 0.0
			var tgt := _vine_target()
			match str(tgt.get("kind", "")):
				"enemy":
					var e: Node3D = tgt["node"]
					var weight := str(e.call("vine_weight")) if e.has_method("vine_weight") else "heavy"
					if weight == "light":
						# reel them in
						_pull = e
						dur = 0.55
						var flat := e.global_position - player.global_position
						flat.y = 0.0
						if flat.length() > 0.1:
							face_direction(flat.normalized(), 1.0)
						player.body_model.play("vine_pull", dur)
						_wraps = Net.fx("arm_vines", [player.body_model, "r", dur])
						_rope = VineRope.make(player.get_tree().current_scene, _vine_hand(), _enemy_chest(e), 0.1)
						Net.fx("sfx", ["whoosh", player.global_position, -5.0, 0.1, 1.2])
					else:
						_zip_to = e
				"point":
					_swing_to = tgt["pos"]
				_:
					# nothing to latch onto: give it back
					_pc.energy += float(Skills.get_skill("vine_swing")["cost"])
					_pc.cooldowns["vine_swing"] = 0.0
					player.call("_toast", "Nothing to latch onto")
					_anchor_fail = true
		_:
			dur = 0.1


func physics_update(delta: float) -> void:
	t += delta
	if id == "vine_swing":
		if _pull != null:
			_pull_update(delta)
			return
		if _zip_to != null:
			transitioned.emit(self, "Swing", {"zip": _zip_to})
		elif _swing_to != Vector3.INF:
			transitioned.emit(self, "Swing", {"anchor": _swing_to})
		else:
			_finish()
		return
	match id:
		"soru":
			player.velocity = _dir * (32.0 if t < 0.2 else 4.0)
			player.move_and_slide()
			if int(t * 40.0) % 3 == 0:
				Net.fx("afterimage", [player.body_model, Color(0.6, 0.85, 1.0), 0.2])
			if t >= 0.2 and not player.hurtbox.monitorable:
				player.hurtbox.set_deferred("monitorable", true)
		"tekkai":
			_rooted(delta, 0.0)
		"flying_slash":
			_rooted(delta, 0.0)
			if not _fired and t >= dur * 0.42:
				_fired = true
				var from := player.global_position + Vector3(0, 1.1, 0) + _dir * 0.6
				var d := _dir
				d.y = 0.0
				Projectile.launch(player.get_tree(), "slash", from, d.normalized(), player, 26.0)
				Net.fx("slash", [player.player_model, "spin", 0.3, Color(0.75, 0.9, 1.0)])
				Net.fx("sfx", ["whoosh_big", from, -2.0, 0.05, 1.3])
		"tiger_rush":
			_tiger(delta)
		"bullet_storm":
			_rooted(delta, 0.3)
			var due := int((t - 0.08) / 0.085) + 1
			while _shots < mini(due, 7) and t >= 0.08:
				_shots += 1
				# a sweep across the front, one shot dead ahead
				var a := lerpf(0.45, -0.45, float(_shots - 1) / 6.0)
				_shot(_dir.rotated(Vector3.UP, a), 9.0)
		"armament_coat", "foresight":
			_rooted(delta, 0.3)
		"rending_fang":
			_fang(delta)
		"pounce":
			_pounce(delta)
		"howl":
			_rooted(delta, 0.0)
			if not _fired and t >= dur * 0.3:
				_fired = true
				_howl()
		"vine_snare":
			_rooted(delta, 0.2)
			if not _fired and t >= dur * 0.45:
				_fired = true
				var hand := player.body_model.hand_r.global_position if player.body_model.hand_r else player.global_position + Vector3(0, 1.4, 0)
				var aim := _aim_point(24.0)
				var d3 := (aim - hand).normalized()
				d3.y = clampf(d3.y, -0.3, 0.4)
				Projectile.launch(player.get_tree(), "seed", hand + d3 * 0.3, d3.normalized(), player, 8.0)
				Net.fx("sfx", ["whoosh", hand, -5.0, 0.1, 1.3])
		"thorn_whip":
			_rooted(delta, 0.0)
			if not _fired and t >= dur * 0.48:
				_fired = true
				_whip()
		"fire_fist":
			_rooted(delta, 0.25)
			if not _fired and t >= dur * 0.36:
				_fired = true
				_throw_fireball()
		"flame_dash":
			_dash(delta)
		"fire_ring":
			_rooted(delta, 0.0)
			if not _fired and t >= dur * 0.4:
				_fired = true
				_ring()
		"ember_field":
			_rooted(delta, 0.0)
			if not _fired and t >= dur * 0.5:
				_fired = true
				_field()
		"inferno":
			_inferno(delta)
	if t >= dur:
		_finish()


# --------------------------------------------------------------------------
# Helpers
# --------------------------------------------------------------------------
## Where the reticle points (first world hit within `reach`), else that far.
func _aim_point(reach: float) -> Vector3:
	var ray: Array = player.reticle_ray()
	if ray.is_empty():
		return player.global_position + _dir * reach
	var from: Vector3 = ray[0]
	var cf: Vector3 = ray[1]
	var extra := from.distance_to(player.global_position)
	var q := PhysicsRayQueryParameters3D.create(from, from + cf * (reach + extra), 1 | 4)
	q.exclude = [player.get_rid()]
	var h := player.get_world_3d().direct_space_state.intersect_ray(q)
	return (h["position"] as Vector3) if not h.is_empty() else from + cf * (reach + extra)


func _nearest_enemy(reach: float) -> Node3D:
	var best: Node3D = null
	var bd := INF
	for e in _pc.enemies_in(player.global_position + Vector3(0, 0.9, 0), reach):
		var d := (e as Node3D).global_position - player.global_position
		d.y = 0.0
		var facing := d.normalized().dot(get_camera_forward()) > -0.2
		if facing and d.length() < bd:
			bd = d.length()
			best = e
	return best


## What a Vine Swing latches onto, from the reticle (up to 24 m):
##   {"kind": "enemy", "node": e}  an enemy close to the aim line
##   {"kind": "point", "pos": p}   a tree crown near the aim, or whatever
##                                 solid the reticle is on (cliff, roof, wall)
##                                 if it's above you
##   {}                            nothing
func _vine_target() -> Dictionary:
	var ray: Array = player.reticle_ray()
	if ray.is_empty():
		return {}
	var from: Vector3 = ray[0]
	var cf: Vector3 = ray[1]
	var reach := 24.0
	var extra := from.distance_to(player.global_position)
	var space := player.get_world_3d().direct_space_state
	var hand := _vine_hand()
	# 1. an enemy within a few degrees of the aim line (and in sight)
	var best_e: Node3D = null
	var best_a := 0.16
	for e in _pc.enemies_in(player.global_position + Vector3(0, 1.0, 0), 20.0):
		var c := _enemy_chest(e as Node3D)
		var to := c - from
		var a := acos(clampf(to.normalized().dot(cf), -1.0, 1.0))
		if a < best_a and (_clear_line(hand, c, e as Node3D) or _clear_line(player.global_position + Vector3.UP * 1.7, c + Vector3.UP * 0.35, e as Node3D)):
			best_a = a
			best_e = e
	if best_e:
		return {"kind": "enemy", "node": best_e}
	# 2. a tree crown close to the aim
	var crown := GrapplePoints.best(from, cf, player.global_position, reach, 0.2, player.global_position.y + 2.0)
	if crown != Vector3.INF:
		return {"kind": "point", "pos": crown}
	# 3. whatever the reticle is on, if it's above you
	var q := PhysicsRayQueryParameters3D.create(from, from + cf * (reach + extra), 1)
	q.exclude = [player.get_rid()]
	var h := space.intersect_ray(q)
	if not h.is_empty():
		var p: Vector3 = h["position"]
		if p.y >= player.global_position.y + 1.5 and p.distance_to(player.global_position) >= 2.5 \
				and p.distance_to(player.global_position) <= reach + 2.0:
			return {"kind": "point", "pos": p}
	# 4. a crown a bit further off the aim
	crown = GrapplePoints.best(from, cf, player.global_position, reach, 0.42, player.global_position.y + 2.0)
	if crown != Vector3.INF:
		return {"kind": "point", "pos": crown}
	return {}


func _vine_hand() -> Vector3:
	var hr: Node3D = player.body_model.hand_r if player.body_model else null
	return hr.global_position if hr else player.global_position + Vector3(0, 1.4, 0)


func _enemy_chest(e: Node3D) -> Vector3:
	var hb := e.get("hurtbox") as Node3D
	return hb.global_position if hb else e.global_position + Vector3.UP * 0.9


func _clear_line(a: Vector3, b: Vector3, e: Node3D) -> bool:
	var q := PhysicsRayQueryParameters3D.create(a, b, 1)
	q.exclude = [player.get_rid()]
	if e is CollisionObject3D:
		q.exclude.append((e as CollisionObject3D).get_rid())
	return player.get_world_3d().direct_space_state.intersect_ray(q).is_empty()


## Reeling a light enemy in: the vine flies out, latches, and hauls.
func _pull_update(delta: float) -> void:
	_rooted(delta, 0.0)
	var alive := is_instance_valid(_pull) and BurnStatus.alive(_pull)
	if _rope:
		_rope.set_ends(_vine_hand(), _enemy_chest(_pull) if alive else _vine_hand())
	if not _fired and alive and t >= dur * 0.3 and (_rope == null or _rope.arrived()):
		_fired = true
		var dmg := roundf(4.0 * _pc.power_multiplier())
		if _pull.has_method("vine_yank"):
			_pull.call("vine_yank", player.global_position + player.player_model.global_basis.z * -0.2, dmg)
		_pc.add_ult(dmg)
		Net.fx("sparkle", [_enemy_chest(_pull), 8, Color(0.5, 0.95, 0.35)])
		Net.fx("sfx", ["whoosh_big", player.global_position, -3.0, 0.05, 1.5])
	if t >= dur * 0.8 and _rope:
		_rope.retract()
		_rope = null
	if t >= dur or not alive and t > 0.2:
		_finish()


## One hitscan pistol shot along `d` (Bullet Storm).
func _shot(d: Vector3, base: float) -> void:
	var muzzle := player.global_position + Vector3(0, 1.3, 0) + d * 0.5
	var end := muzzle + d * 30.0
	var space := player.get_world_3d().direct_space_state
	var wq := PhysicsRayQueryParameters3D.create(muzzle, end, 1)
	wq.exclude = [player.get_rid()]
	var wall := space.intersect_ray(wq)
	if not wall.is_empty():
		end = wall["position"]
	var eq := PhysicsRayQueryParameters3D.create(muzzle, end, 32)
	eq.collide_with_areas = true
	eq.collide_with_bodies = false
	var hit := space.intersect_ray(eq)
	if not hit.is_empty() and hit["collider"] is Hurtbox:
		end = hit["position"]
		var hd := player.melee_hit(base)
		hd.knockback_force = 3.0
		hd.ranged = true
		(hit["collider"] as Hurtbox).take_hit(hd, player)
		_pc.add_ult(hd.damage)
		Net.fx("impact", [end, Color(1.0, 0.75, 0.45)])
	Net.fx("tracer", [muzzle, end])
	Net.fx("muzzle_sparks", [muzzle, d, 5])
	Net.fx("sfx", ["gunshot", muzzle, -6.0, 0.1, 1.3])


func _tiger(delta: float) -> void:
	apply_gravity(delta)
	var spd := 17.0 if t < 0.38 else move_toward(Vector2(player.velocity.x, player.velocity.z).length(), 0.0, 40.0 * delta)
	player.velocity.x = _dir.x * spd
	player.velocity.z = _dir.z * spd
	player.move_and_slide()
	if t >= 0.38 and not player.hurtbox.monitorable:
		player.hurtbox.set_deferred("monitorable", true)
	if t < 0.42:
		for e in _pc.enemies_in(player.global_position + Vector3(0, 0.9, 0), 1.5):
			if e in _hit:
				continue
			_hit.append(e)
			var hb := (e as Node).get("hurtbox") as Hurtbox
			if hb:
				var hd := player.melee_hit(30.0)
				hd.unblockable = true
				hd.knockback_force = 8.0
				hd.stagger_duration = 0.5
				hd.hitstop_duration = 0.07
				hd.camera_shake_intensity = 0.15
				hb.take_hit(hd, player)
				_pc.add_ult(hd.damage)
				Net.fx("slash", [player.player_model, "right", 0.2])
		if int(t * 30.0) % 2 == 0:
			Net.fx("afterimage", [player.body_model, Color(0.75, 0.9, 1.0), 0.18])


func _fang(delta: float) -> void:
	apply_gravity(delta)
	if t < 0.18:
		var spd := 13.0
		if _target and is_instance_valid(_target):
			var d := _target.global_position - player.global_position
			d.y = 0.0
			if d.length() < 1.3:
				spd = 0.0
		player.velocity.x = _dir.x * spd
		player.velocity.z = _dir.z * spd
	else:
		player.velocity.x = move_toward(player.velocity.x, 0.0, 40.0 * delta)
		player.velocity.z = move_toward(player.velocity.z, 0.0, 40.0 * delta)
	player.move_and_slide()
	var due := int((t - 0.16) / 0.11) + 1
	while _rakes < mini(due, 3) and t >= 0.16:
		_rakes += 1
		var front := player.global_position + Vector3(0, 0.9, 0) + _dir * 1.0
		var base := 12.0 * (1.4 if player.hybrid else 1.0)
		for e in _pc.enemies_in(front, 1.5):
			var hb := (e as Node).get("hurtbox") as Hurtbox
			if hb:
				var hd := player.melee_hit(base)
				hd.knockback_force = 3.0 if _rakes < 3 else 8.0
				hd.hitstop_duration = 0.04
				hd.camera_shake_intensity = 0.08
				hb.take_hit(hd, player)
				_pc.add_ult(hd.damage)
		Net.fx("slash", [player.player_model, "right" if _rakes % 2 == 1 else "left", 0.18, Color(1.0, 0.35, 0.3)])
		Net.fx("sfx", ["whoosh", player.global_position, -6.0, 0.1, 1.3 + _rakes * 0.1])


func _pounce(delta: float) -> void:
	player.velocity.y -= player.gravity * delta
	player.move_and_slide()
	if not _slammed and t > 0.2 and player.is_on_floor():
		_slammed = true
		var c := player.global_position
		var hd := HitData.new()
		hd.damage = 22.0 * (1.3 if player.hybrid else 1.0)
		hd.knockback_force = 8.0
		hd.knockdown = true
		hd.stagger_duration = 0.4
		hd.hitstop_duration = 0.08
		hd.camera_shake_intensity = 0.2
		_pc.blast(c + Vector3(0, 0.8, 0), 2.6, hd)
		Net.fx("dust_ring", [c, 16, 1.1])
		Net.fx("sfx", ["thud", c, 0.0, 0.05, 0.9])
		CombatManager.apply_camera_shake(0.2)
		player.velocity.x *= 0.2
		player.velocity.z *= 0.2
		t = maxf(t, dur * 0.7)
	if _slammed:
		player.velocity.x = move_toward(player.velocity.x, 0.0, 30.0 * delta)
		player.velocity.z = move_toward(player.velocity.z, 0.0, 30.0 * delta)
	elif t > 1.6:
		_slammed = true


func _howl() -> void:
	_pc.add_buff("howl", 8.0)
	player.call("_recalc_stats")
	Net.fx("sfx", ["howl", player.global_position, 0.0, 0.03])
	Net.fx("dust_ring", [player.global_position, 18, 1.2])
	CombatManager.apply_camera_shake(0.15)
	for e in _pc.enemies_in(player.global_position + Vector3(0, 0.9, 0), 8.0):
		var hb := (e as Node).get("hurtbox") as Hurtbox
		if hb:
			var hd := HitData.new()
			hd.damage = 2.0
			hd.knockback_force = 5.0
			hd.stagger_duration = 0.8
			hd.hitstop_duration = 0.0
			hd.camera_shake_intensity = 0.0
			hd.unblockable = true
			hb.take_hit(hd, player)


func _whip() -> void:
	var from := player.global_position + Vector3(0, 1.1, 0)
	var d := _dir
	d.y = 0.0
	d = d.normalized()
	var end := from + d * 7.0
	Net.fx("tracer", [from, end, Color(0.4, 0.9, 0.3)])
	Net.fx("sparkle", [end, 8, Color(0.5, 0.95, 0.35)])
	Net.fx("sfx", ["whoosh_big", from, -3.0, 0.05, 1.4])
	for e in _pc.enemies_in(from + d * 3.5, 3.8):
		var ep := (e as Node3D).global_position
		var rel := ep - player.global_position
		rel.y = 0.0
		var along := rel.dot(d)
		var off := (rel - d * along).length()
		if along < 0.0 or along > 7.5 or off > 1.4:
			continue
		var hb := (e as Node).get("hurtbox") as Hurtbox
		if hb == null:
			continue
		var hd := HitData.new()
		hd.damage = roundf(18.0 * _pc.power_multiplier())
		hd.knockback_force = clampf(along * 1.4, 4.0, 10.0)
		hd.stagger_duration = 0.4
		hd.hitstop_duration = 0.05
		hd.camera_shake_intensity = 0.1
		hd.unblockable = true
		# the "attacker" stands beyond them, so the knockback drags them in
		_pc._proxy.global_position = ep + d * 2.0
		hb.take_hit(hd, _pc._proxy)
		_pc.add_ult(hd.damage)


func _finish() -> void:
	if not player.is_on_floor():
		transitioned.emit(self, "Fall", {})
	elif get_movement_input().length() > 0.1:
		transitioned.emit(self, "Move", {})
	else:
		transitioned.emit(self, "Idle", {})


## Stand your ground (a little drift allowed so it doesn't feel glued).
func _rooted(delta: float, keep: float) -> void:
	apply_gravity(delta)
	var mi := get_movement_input()
	var want := get_camera_relative_direction(mi) * player.move_speed * keep if mi.length() > 0.1 else Vector3.ZERO
	player.velocity.x = move_toward(player.velocity.x, want.x, 30.0 * delta)
	player.velocity.z = move_toward(player.velocity.z, want.z, 30.0 * delta)
	player.move_and_slide()


# --------------------------------------------------------------------------
# Fire Fist
# --------------------------------------------------------------------------
func _throw_fireball() -> void:
	var from := player.global_position + Vector3(0, 1.3, 0) + _dir * 0.55
	if player.body_model.hand_r:
		from = player.body_model.hand_r.global_position + _dir * 0.25
	# aim where the screen center points (the reticle)
	var target := from + _dir * 30.0
	var ray: Array = player.reticle_ray()
	if not ray.is_empty():
		var o: Vector3 = ray[0]
		var cf: Vector3 = ray[1]
		var q := PhysicsRayQueryParameters3D.create(o, o + cf * 60.0, 1 | 4)
		q.exclude = [player.get_rid()]
		var hit := player.get_world_3d().direct_space_state.intersect_ray(q)
		target = (hit["position"] as Vector3) if not hit.is_empty() else o + cf * 60.0
	var d := target - from
	if d.length() < 1.0 or d.normalized().dot(_dir) < 0.2:
		d = _dir
	# keep it mostly level so it doesn't plough into the ground at your feet
	d = d.normalized()
	d.y = clampf(d.y, -0.25, 0.5)
	Fireball.launch(player.get_tree(), from, d.normalized(), player)
	Net.fx("flame", [from, 8, 0.5, 0.3, 0.15])
	Net.fx("sfx", ["fire_burst", from, -3.0, 0.1, 1.3])
	CombatManager.apply_camera_shake(0.05)


# --------------------------------------------------------------------------
# Flame Dash
# --------------------------------------------------------------------------
func _dash(delta: float) -> void:
	apply_gravity(delta)
	var u := t / DASH_TIME
	var spd := DASH_SPEED * (1.15 - 0.4 * u) if t < DASH_TIME else move_toward(Vector2(player.velocity.x, player.velocity.z).length(), 0.0, 40.0 * delta)
	player.velocity.x = _dir.x * spd
	player.velocity.z = _dir.z * spd
	player.move_and_slide()
	if t >= DASH_TIME and player.hurtbox.monitorable == false:
		player.hurtbox.set_deferred("monitorable", true)
	if t < DASH_TIME + 0.05:
		var chest := player.global_position + Vector3(0, 0.9, 0)
		var hd := HitData.new()
		hd.damage = 14.0
		hd.knockback_force = 5.0
		hd.stagger_duration = 0.3
		hd.hitstop_duration = 0.03
		hd.camera_shake_intensity = 0.06
		hd.unblockable = true
		_hit.append_array(_pc.blast(chest, 1.4, hd, 2.5, 6.0, _hit))
		_pc.ignite_burnables(player.global_position, 1.4)
		Net.fx("flame", [chest - _dir * 0.3, 3, 0.7, 0.4, 0.3])
		# a trail of burning ground
		_trail_dist += player.global_position.distance_to(_last_pos)
		_last_pos = player.global_position
		if _trail_dist > 1.3 and player.is_on_floor():
			_trail_dist = 0.0
			FireZone.spawn(player.get_tree(), player.global_position, 0.9, 2.5, 8.0, player)


# --------------------------------------------------------------------------
# Blazing Ring
# --------------------------------------------------------------------------
func _ring() -> void:
	var c := player.global_position
	var hd := HitData.new()
	hd.damage = 20.0
	hd.knockback_force = 9.0
	hd.knockdown = true
	hd.stagger_duration = 0.4
	hd.hitstop_duration = 0.07
	hd.camera_shake_intensity = 0.2
	hd.unblockable = true
	_pc.blast(c + Vector3(0, 0.8, 0), 4.2, hd, 3.0, 6.0)
	_pc.ignite_burnables(c, 4.2)
	Net.fx("fire_ring", [c, 4.2, 44])
	Net.fx("sfx", ["fire_blast", c, -5.0, 0.08, 1.35])
	CombatManager.apply_camera_shake(0.22)


# --------------------------------------------------------------------------
# Ember Field
# --------------------------------------------------------------------------
func _field() -> void:
	var fwd := _dir
	fwd.y = 0.0
	fwd = fwd.normalized()
	var spot := player.global_position + fwd * 4.5
	var space := player.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(spot + Vector3.UP * 3.0, spot + Vector3.DOWN * 6.0, 1)
	q.exclude = [player.get_rid()]
	var hit := space.intersect_ray(q)
	if not hit.is_empty():
		spot = hit["position"]
	FireZone.spawn(player.get_tree(), spot, 3.0, 6.0, 10.0, player)
	Net.fx("flame", [spot + Vector3(0, 0.3, 0), 22, 1.0, 0.6, 1.6])
	Net.fx("sfx", ["fire_burst", spot, -1.0, 0.1, 0.75])
	CombatManager.apply_camera_shake(0.08)


# --------------------------------------------------------------------------
# Great Inferno (ultimate)
# --------------------------------------------------------------------------
func _inferno(delta: float) -> void:
	if not _slammed:
		if t < 0.36:
			# rising, wreathed in flame
			player.velocity.y -= player.gravity * 0.6 * delta
			player.velocity.x = 0.0
			player.velocity.z = 0.0
			if int(t * 30.0) % 2 == 0:
				Net.fx("flame", [player.global_position + Vector3(0, 0.9, 0), 3, 0.7, 0.4, 0.4])
		else:
			# drive down
			player.velocity.y = -22.0
		player.move_and_slide()
		if t > 0.38 and (player.is_on_floor() or t > 0.9):
			_slammed = true
			_slam()
	else:
		apply_gravity(delta)
		player.velocity.x = 0.0
		player.velocity.z = 0.0
		player.move_and_slide()
	if t > 0.95 and not player.hurtbox.monitorable:
		player.hurtbox.set_deferred("monitorable", true)


func _slam() -> void:
	var c := player.global_position
	var hd := HitData.new()
	hd.damage = 55.0
	hd.knockback_force = 11.0
	hd.knockdown = true
	hd.stagger_duration = 0.6
	hd.hitstop_duration = 0.12
	hd.camera_shake_intensity = 0.5
	hd.unblockable = true
	_pc.blast(c + Vector3(0, 0.8, 0), 7.0, hd, 4.0, 8.0)
	_pc.ignite_burnables(c, 7.0)
	Net.fx("fire_pillar", [c, 7.0])
	Net.fx("dust_ring", [c, 16, 1.2])
	Net.fx("sfx", ["fire_blast", c, 2.0, 0.05, 0.9])
	CombatManager.apply_camera_shake(0.5)
	CombatManager.apply_hitstop(0.08, [player])
	FireZone.spawn(player.get_tree(), c, 5.0, 5.0, 12.0, player)
	player.squash(-3.0)


func exit() -> void:
	player.hurtbox.set_deferred("monitorable", true)
	# the power's colors linger on you (a swing does it when it ends)
	if not _anchor_fail and _swing_to == Vector3.INF and _zip_to == null:
		_pc.linger(id)
	if _rope:
		_rope.retract()
		_rope = null
