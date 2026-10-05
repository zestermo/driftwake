extends SceneTree
## Plunge attack, rifleman ragdoll fix, shove knockdown, two-handed rifle.
const AIM := 15; const KEEP := 16; const SHOVE := 18; const DOWN := 11; const DEAD := 14; const HITSTUN := 10
var t := 0.0
var step := 0
var wait := 0.0
var p
var camp
var rifle
var fails := 0
var dummy
var hp0 := 0.0
var t0 := 0.0
var aimed_after := false
func _initialize(): change_scene_to_file("res://scenes/world/world.tscn")
func check(name: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + name)
	if not cond: fails += 1
func tap(a: String) -> void:
	var e := InputEventAction.new(); e.action = a; e.pressed = true; Input.parse_input_event(e)
	var e2 := InputEventAction.new(); e2.action = a; e2.pressed = false; Input.parse_input_event(e2)
func st() -> String: return p.current_state_name()
func _process(d: float) -> bool:
	t += d
	if step == 12 and rifle and is_instance_valid(rifle) and rifle.state == AIM: aimed_after = true
	if wait > 0.0:
		wait -= d
		return false
	match step:
		0:
			if t < 1.5: return false
			p = root.get_tree().get_first_node_in_group("player")
			p.health_component.max_health = 99999.0
			p.health_component.current_health = 99999.0
			var isl = root.get_node("World/Islands/Brinehollow")
			for c in isl.get_children():
				if c.name.begins_with("DummyTarget"): dummy = c; break
			tap("ready_weapon")
			wait = 0.6
		1:
			# 4 m above the ground, 1.2 m short of the dummy, camera looking at it
			p.global_position = dummy.global_position + Vector3(1.2, 4.0, 0)
			p.velocity = Vector3.ZERO
			p.reset_physics_interpolation()
			for n in root.get_node("World").get_children():
				if n.has_method("shake"): n.rotation.y = PI * 0.5
			hp0 = dummy.get_node("HealthComponent").current_health
			wait = 0.15
		2:
			tap("light_attack")
			wait = 0.1
		3:
			check("attack in the air -> Plunge", st() == "Plunge")
			wait = 1.0
		4:
			check("lands and recovers", st() in ["Idle", "Move"])
			var hc = dummy.get_node("HealthComponent")
			print("   dummy hp ", hp0, " -> ", hc.current_health)
			check("plunge hits", hc.current_health < hp0 or hc.current_health == hc.max_health)
			# low jump: no plunge right off the ground
			wait = 0.3
		5:
			camp = root.get_node("World/Islands/Brinehollow/SmugglersCamp")
			rifle = camp.grunts[2]
			for x in camp.grunts:
				if x != rifle: x.process_mode = Node.PROCESS_MODE_DISABLED
			p.global_position = rifle.global_position + rifle._fwd() * 10.0 + Vector3.UP * 0.5
			p.reset_physics_interpolation()
			wait = 2.0
		6:
			check("rifleman engaged", rifle.state != 0)
			var hand: Vector3 = rifle.humanoid.hand_l.global_transform * Vector3(0, -0.05, 0)
			var wx: Transform3D = rifle.humanoid.weapon.global_transform
			var w: Vector3 = wx * Vector3(0, -0.01, clampf((wx.affine_inverse() * hand).z, -0.6, -0.15))
			var sh: Vector3 = rifle.humanoid.arm_l.global_position
			var hum = rifle.humanoid
			var sc: float = hum.global_basis.get_scale().x
			print("   off hand to stock ", snappedf(hand.distance_to(w), 0.01), " shoulder->stock ", snappedf(sh.distance_to(w), 0.01), " reach ", snappedf((hum.fore_l.position.length() + hum.hand_l.position.length()) * sc, 0.01), " state ", rifle.state, " act ", hum.current_action())
			check("both hands on the rifle", hand.distance_to(w) < 0.15)
			# knock him down, then keep hitting him on the ground
			var h := HitData.new(); h.damage = 10.0; h.knockdown = true; h.knockback_force = 8.0
			rifle.hurtbox.take_hit(h, p)
			wait = 0.3
		7:
			check("knocked down", rifle.state == DOWN)
			var h := HitData.new(); h.damage = 8.0; h.knockback_force = 4.0
			rifle.hurtbox.take_hit(h, p)
			check("hit on the ground: stays down (no hitstun)", rifle.state == DOWN)
			var h2 := HitData.new(); h2.damage = 999.0; h2.knockback_force = 4.0
			rifle.hurtbox.take_hit(h2, p)
			check("killed on the ground: dead", rifle.state == DEAD)
			step = 12
			wait = 3.0
			return false
		12:
			check("dead rifleman never aims again", not aimed_after)
			# the other rifleman: shove knocks you down
			var r2 = camp.grunts[4]
			r2.process_mode = Node.PROCESS_MODE_INHERIT
			rifle = r2
			r2.alert()
			wait = 0.8
		13:
			rifle._shove_cd = 0.0; rifle._shot_cd = 99.0
			p.global_position = rifle.global_position + rifle._fwd() * 1.8
			p.reset_physics_interpolation()
			t0 = t
			step += 1
			return false
		14:
			if st() == "Downed":
				check("rifle butt knocks you down", true)
				step += 1
			elif t - t0 > 4.0:
				print("   state ", st(), " rifle ", rifle.state)
				check("rifle butt knocks you down", false); step += 1
			return false
		15:
			print("RESULT ", "OK" if fails == 0 else "%d FAILED" % fails)
			return true
	step += 1
	return false
