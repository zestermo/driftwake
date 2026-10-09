extends PlayerState
## Pistols: a quick aimed shot where the camera points (the reticle). One
## pistol fires from the right hand; two alternate right / left, faster.
## Each pistol holds a couple of shots (more with Extra Powder); when both are
## empty you reload automatically (Quick Hands speeds it up). You can keep
## moving while you shoot, a little slower.

const RANGE := 45.0
const SINGLE_DAMAGE := 14.0
const DUAL_DAMAGE := 10.0
## Full damage out to FALLOFF_NEAR m, down to FALLOFF_MIN of it at RANGE.
const FALLOFF_NEAR := 12.0
const FALLOFF_MIN := 0.55
## The arms stay up this long after the shot before lowering.
const LINGER := 1.0

var timer: float = 0.0
var dur: float = 0.3
var _hand: int = 0
static var _next_hand: int = 0


func enter(_data: Dictionary) -> void:
	timer = 0.0
	var dual := player.style() == "dual_pistol"
	dur = 0.28 if dual else 0.34
	face_direction(get_camera_forward(), 1.0)
	if player.reloading():
		return
	# pick a hand with a shot in it
	_hand = _next_hand if dual else 0
	if player.ammo[_hand] <= 0 and dual:
		_hand = 1 - _hand
	if player.ammo[_hand] <= 0:
		player.start_reload()
		return
	_next_hand = 1 - _hand
	player.ammo[_hand] -= 1
	_fire(dual)
	if player.ammo[0] <= 0 and (not dual or player.ammo[1] <= 0):
		player.call_deferred("start_reload")


func _fire(dual: bool) -> void:
	var shoulder_node: Node3D = player.body_model.arm_r if _hand == 0 else player.body_model.arm_l
	var shoulder := shoulder_node.global_position if shoulder_node else player.global_position + Vector3(0, 1.35, 0)
	var fwd := get_camera_forward()
	var space := player.get_world_3d().direct_space_state
	# where the reticle points: the first enemy or solid on the screen-centre ray
	# (starting level with the player, so nothing behind you catches it)
	var target := shoulder + fwd * RANGE
	var ray := player.reticle_ray()
	var on_enemy := false
	if not ray.is_empty():
		var cd: Vector3 = ray[1]
		var from: Vector3 = ray[0]
		from += cd * maxf((player.global_position - from).dot(cd), 0.0)
		var q := PhysicsRayQueryParameters3D.create(from, from + cd * RANGE, 1 | 4 | 2048)
		q.exclude = [player.get_rid()]
		var h := space.intersect_ray(q)
		target = (h["position"] as Vector3) if not h.is_empty() else from + cd * RANGE
		on_enemy = not h.is_empty() and (h["collider"] as CollisionObject3D).collision_layer & 4 != 0
		# aim assist: only when the reticle is just off an enemy in clear view
		if not on_enemy:
			var best_a := 0.06
			for e in player.power.enemies_in(player.global_position, RANGE):
				var hb := (e as Node).get("hurtbox") as Hurtbox
				if hb == null:
					continue
				var a := cd.angle_to(hb.global_position - from)
				if a >= best_a:
					continue
				var los := PhysicsRayQueryParameters3D.create(shoulder, hb.global_position, 1)
				los.exclude = [player.get_rid()]
				if space.intersect_ray(los).is_empty():
					best_a = a
					target = hb.global_position
	# the gun is at the end of the arm, pointed along the shot
	var dir := (target - shoulder).normalized()
	var muzzle := shoulder + dir * 0.7
	dir = (target - muzzle).normalized()
	# aim pose follows the pitch
	player.body_model.aim_pitch = clampf(asin(clampf(dir.y, -1.0, 1.0)), -0.6, 0.6)
	player.body_model.play("shoot_r" if _hand == 0 else "shoot_l", dur + LINGER)
	# what's on the line: walls, or the first enemy hurtbox
	var end := muzzle + dir * RANGE
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
		var hb := hit["collider"] as Hurtbox
		end = hit["position"]
		var hd := player.melee_hit(DUAL_DAMAGE if dual else SINGLE_DAMAGE)
		var far := muzzle.distance_to(end)
		hd.damage *= lerpf(1.0, FALLOFF_MIN, clampf((far - FALLOFF_NEAR) / (RANGE - FALLOFF_NEAR), 0.0, 1.0))
		# Point Blank (pistol tree): close shots hit harder
		if far < 5.0:
			hd.damage *= 1.0 + player.progression.stat("pointblank_pct")
		hd.knockback_force = 3.0
		hd.hitstop_duration = 0.0 if dual else 0.03   # (rapid dual fire: a freeze per hit reads as stutter)
		hd.camera_shake_intensity = 0.0 if dual else 0.05
		hd.ranged = true
		hb.take_hit(hd, player)
		player.power.on_sword_hit(hb.owner, hd)
		Net.fx("impact", [end, Color(1.0, 0.75, 0.45)])
		if player.progression.has_flag("ricochet"):
			_ricochet(end, hb.owner, hd.damage)
	else:
		Net.fx("dust", [end, 3, 0.35])
	Net.fx("tracer", [muzzle, end])
	Net.fx("muzzle_sparks", [muzzle, dir, 8])
	Net.fx("smoke", [muzzle + dir * 0.2, 3, 0.45, 0.9])
	Net.fx("sfx", ["gunshot", muzzle, -5.0, 0.08, 1.25 if dual else 1.15])
	# (a shake this small lasts one frame: with rapid dual fire it's a hitch, not a kick)
	if not dual:
		CombatManager.apply_camera_shake(0.04)


## Ricochet (pistol tree): the ball glances off into the nearest other enemy.
func _ricochet(at: Vector3, first: Node, dmg: float) -> void:
	var best: Node3D = null
	var bd := 9.0
	for e in player.power.enemies_in(at, 9.0):
		if e == first:
			continue
		var d := (e as Node3D).global_position.distance_to(at)
		if d < bd:
			bd = d
			best = e
	if best == null:
		return
	var hb := best.get("hurtbox") as Hurtbox
	if hb == null:
		return
	var hd := HitData.new()
	hd.ranged = true
	hd.damage = roundf(dmg * 0.6)
	hd.knockback_force = 2.0
	hb.take_hit(hd, player)
	Net.fx("tracer", [at, hb.global_position])
	Net.fx("impact", [hb.global_position, Color(1.0, 0.75, 0.45)])


func physics_update(delta: float) -> void:
	timer += delta
	apply_gravity(delta)
	var mi := get_movement_input()
	var want := get_camera_relative_direction(mi) * player.move_speed * 0.6 if mi.length() > 0.1 else Vector3.ZERO
	player.velocity.x = move_toward(player.velocity.x, want.x, 40.0 * delta)
	player.velocity.z = move_toward(player.velocity.z, want.z, 40.0 * delta)
	player.move_and_slide()
	face_camera(delta)
	if timer >= dur:
		if input_buffer.consume_action("light_attack") and not player.reloading():
			enter({})
			return
		var next := combat_input()
		if next != "":
			transitioned.emit(self, next, {})
			return
		if wants_dodge():
			transitioned.emit(self, "Dodge", {})
			return
		transitioned.emit(self, "Move" if mi.length() > 0.1 else "Idle", {})
