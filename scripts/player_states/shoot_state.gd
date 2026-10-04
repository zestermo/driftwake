extends PlayerState
## Pistols: a quick aimed shot where the camera points (the reticle). One
## pistol fires from the right hand; two alternate right / left, faster.
## Each pistol holds a couple of shots (more with Extra Powder); when both are
## empty you reload automatically (Quick Hands speeds it up). You can keep
## moving while you shoot, a little slower.

const RANGE := 45.0
const SINGLE_DAMAGE := 14.0
const DUAL_DAMAGE := 11.0

var timer: float = 0.0
var dur: float = 0.3
var _hand: int = 0
static var _next_hand: int = 0


func enter(_data: Dictionary) -> void:
	timer = 0.0
	var dual := player.style() == "dual_pistol"
	dur = 0.22 if dual else 0.34
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
	var cam := player.get_viewport().get_camera_3d()
	var hand_node: Node3D = player.body_model.hand_r if _hand == 0 else player.body_model.hand_l
	var fwd := get_camera_forward()
	var muzzle := (hand_node.global_position if hand_node else player.global_position + Vector3(0, 1.3, 0)) + fwd * 0.45 + Vector3(0, 0.05, 0)
	# where the reticle points
	var target := muzzle + fwd * RANGE
	var space := player.get_world_3d().direct_space_state
	if cam:
		var cf := -cam.global_basis.z
		var q := PhysicsRayQueryParameters3D.create(cam.global_position, cam.global_position + cf * (RANGE + 8.0), 1)
		q.exclude = [player.get_rid()]
		var h := space.intersect_ray(q)
		target = (h["position"] as Vector3) if not h.is_empty() else cam.global_position + cf * (RANGE + 8.0)
	# aim assist: an enemy close to the reticle's heading gets the shot
	var best: Node3D = null
	var best_a := 0.2
	for e in player.power.enemies_in(player.global_position, RANGE):
		var hb := (e as Node).get("hurtbox") as Hurtbox
		if hb == null:
			continue
		var to := hb.global_position - muzzle
		var flat := Vector3(to.x, 0, to.z)
		if flat.length() < 0.5:
			continue
		var a := absf(fwd.signed_angle_to(flat.normalized(), Vector3.UP))
		if a < best_a:
			best_a = a
			best = hb
	if best:
		target = best.global_position
	var dir := (target - muzzle).normalized()
	# aim pose follows the pitch
	player.body_model.aim_pitch = clampf(asin(clampf(dir.y, -1.0, 1.0)), -0.6, 0.6)
	player.body_model.play("shoot_r" if _hand == 0 else "shoot_l", dur + 0.15)
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
		hd.knockback_force = 3.0
		hd.hitstop_duration = 0.03
		hd.camera_shake_intensity = 0.05
		hd.ranged = true
		hb.take_hit(hd, player)
		player.power.on_sword_hit(hb.owner, hd)
		Net.fx("impact", [end, Color(1.0, 0.75, 0.45)])
	else:
		Net.fx("dust", [end, 3, 0.35])
	Net.fx("tracer", [muzzle, end])
	Net.fx("muzzle_sparks", [muzzle, dir, 8])
	Net.fx("smoke", [muzzle + dir * 0.2, 3, 0.45, 0.9])
	Net.fx("sfx", ["gunshot", muzzle, -5.0, 0.08, 1.25 if dual else 1.15])
	CombatManager.apply_camera_shake(0.04)


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
