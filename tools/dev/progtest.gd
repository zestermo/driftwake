extends SceneTree
## Progression + skill map + fighting styles + fruit types + save/load.
const STAGGER := 9; const HITSTUN := 10; const DOWN := 11; const DEAD := 14
var t := 0.0
var step := 0
var wait := 0.0
var p
var pr
var pc
var camp
var fails := 0
var g
var t0 := 0.0
var v0 := 0.0
var pos0 := Vector3.ZERO
var saw := {}
var SG
func _initialize(): change_scene_to_file("res://scenes/world/world.tscn")
func check(name: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + name)
	if not cond: fails += 1
func rig():
	var cam: Camera3D = root.get_viewport().get_camera_3d()
	return cam.get_parent().get_parent() as Node3D
func face(target: Vector3) -> void:
	var d: Vector3 = target - p.global_position; d.y = 0
	rig().rotation.y = atan2(-d.x, -d.z)
	p.player_model.rotation.y = atan2(-d.x, -d.z)
## Put the crosshair on `target` (turn the camera like the mouse would).
func aim_at(target: Vector3) -> void:
	var arm: Node3D = root.get_viewport().get_camera_3d().get_parent()
	for i in range(8):
		var ray: Array = p.reticle_ray()
		var want: Vector3 = (target - (ray[0] as Vector3)).normalized()
		var have: Vector3 = ray[1]
		rig().rotation.y += wrapf(atan2(-want.x, -want.z) - atan2(-have.x, -have.z), -PI, PI)
		arm.rotation.x += asin(clampf(want.y, -1.0, 1.0)) - asin(clampf(have.y, -1.0, 1.0))
	p.player_model.rotation.y = rig().rotation.y
func put(pos: Vector3) -> void:
	p.global_position = pos
	p.velocity = Vector3.ZERO
	p.reset_physics_interpolation()
func ground(at: Vector3) -> Vector3:
	var q := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 30.0, at + Vector3.DOWN * 60.0, 1)
	var h: Dictionary = p.get_world_3d().direct_space_state.intersect_ray(q)
	return h["position"] if not h.is_empty() else at
func park(x, at: Vector3) -> void:
	x.humanoid.seated = false
	x.global_position = at + Vector3.UP * 0.3
	x.velocity = Vector3.ZERO
	x.reset_physics_interpolation()
## Park every other grunt far away so only `keep` is near.
func clear_others(keep) -> void:
	var i := 0
	for x in camp.grunts:
		if is_instance_valid(x) and x != keep and x.state != DEAD:
			i += 1
			if x.state == DOWN:
				continue
			park(x, ground(p.global_position + Vector3(40 + i * 3, 0, 40)))
func item(id: String):
	return load("res://resources/items/%s.tres" % id)
func attack(action: String) -> void:
	p.input_buffer.buffer_action(action)
var kata_vy := -99.0
var kata_hv := 0.0
var kata_tilt := 0.0
var kata_from := Vector3.ZERO
func _physics_process(_d: float) -> bool:
	if p and p.current_state_name() == "HeavyAttack":
		kata_vy = maxf(kata_vy, p.velocity.y)
		kata_hv = maxf(kata_hv, Vector2(p.velocity.x, p.velocity.z).length())
		kata_tilt = maxf(kata_tilt, p.lean.global_basis.y.normalized().angle_to(Vector3.UP))
	return false
func _process(d: float) -> bool:
	t += d
	if camp:
		for x in camp.grunts:
			if is_instance_valid(x):
				x._cooldown = 99.0; x._pistol_cd = 99.0; x._shot_cd = 99.0; x._shove_cd = 99.0
	if wait > 0.0:
		wait -= d
		return false
	match step:
		0:
			if t < 1.5: return false
			p = root.get_tree().get_first_node_in_group("player")
			pr = p.progression
			pc = p.power
			camp = root.get_node("World/Islands/Brinehollow/SmugglersCamp")
			p.health_component.max_health = 99999.0
			p.health_component.current_health = 99999.0
			check("start at level 1 with nothing learned", pr.level == 1 and pr.skill_points == 0 and pr.owned.keys() == ["origin"])
			check("empty skill bar", pc.loadout == ["", "", "", "", ""])
			check("no double jump at the start", p.max_jumps == 1)
			check("everyone has energy", pc.max_energy() >= 100.0)
			# a grunt kill gives experience
			g = camp.grunts[0]
			var hd := HitData.new(); hd.damage = 9999.0
			g.hurtbox.take_hit(hd, p)
			check("grunt kill gives XP", pr.xp == 45)
			step += 1
		1:
			var need: int = pr.xp_to_next(1)
			pr.add_xp(need)
			check("level up to 2 with 2 skill points", pr.level == 2 and pr.skill_points == 2)
			check("can't learn an unlinked node", pr.can_learn("m_geppo") == "Learn a linked node first")
			check("Haki locked until level 10", pr.can_learn("h_arm") != "" )
			check("fruit nodes need the fruit", pr.can_learn("e_root").begins_with("Needs the"))
			var hp0: float = p.health_component.max_health
			check("learn Agility", pr.learn("c_agility"))
			check("learn Geppo", pr.learn("m_geppo"))
			check("Geppo gives an air jump", p.max_jumps == 2)
			check("Agility speeds you up", p.move_speed > 6.0)
			pr.skill_points = 20
			pr.level = 6
			check("learn Soru (active)", pr.learn("m_soru"))
			check("Soru goes on the bar", pc.loadout[0] == "soru")
			for nid in ["c_vitality", "v_hardy", "v_tekkai", "v_steadfast", "c_strength", "w_blade", "w_flying", "c_endurance", "g_marks", "g_storm"]:
				pr.learn(nid)
			check("skills fill the bar", pc.loadout[1] == "tekkai" and pc.loadout[2] == "flying_slash" and pc.loadout[3] == "bullet_storm")
			check("stats add up", pr.stat("max_hp") >= 40.0 and pr.has_flag("steadfast"))
			# reslot
			check("move a skill to another slot", pc.equip("soru", 3) and pc.loadout[3] == "soru" and pc.loadout[0] == "")
			pc.equip("bullet_storm", 0)
			check("ultimate slot refuses normal skills", not pc.equip("tekkai", 4))
			var spot: Vector3 = ground(camp.grunts[1].global_position + Vector3(12, 0, 0))
			set_meta("land", spot)
			put(spot + Vector3.UP * 0.2)
			p.state_machine.force_state("Idle", {})
			wait = 0.8
			step += 1
		2:
			# Soru
			face(p.global_position + Vector3(0, 0, -10))
			pos0 = p.global_position
			check("cast Soru", pc.try_cast(3))
			wait = 0.1
			step += 1
		3:
			check("untouchable during Soru", not p.hurtbox.monitorable)
			wait = 0.4
			step += 1
		4:
			var dist = Vector2(p.global_position.x - pos0.x, p.global_position.z - pos0.z).length()
			print("   soru distance ", snappedf(dist, 0.1))
			check("Soru covers ground fast (>5 m)", dist > 5.0)
			# fists: punch a grunt
			p.unequip_weapon()
			check("no weapon = fists", p.style() == "fist")
			p.draw_weapon()
			g = camp.grunts[1]
			park(g, ground(p.global_position + Vector3(0, 0, -1.0)))
			face(g.global_position)
			v0 = g.health.current_health
			wait = 0.5
			step += 1
		5:
			face(g.global_position)
			# keep its guard down (a guarding grunt blocks light hits from the front)
			g._stagger_len = 30.0
			g._set_state(STAGGER)
			attack("light_attack")
			wait = 0.12
			step += 1
		6:
			print("   action ", p.body_model.current_action(), " state ", p.current_state_name(), " dist ", snappedf((g.global_position - p.global_position).length(), 0.01), " gstate ", g.state, " hb active ", p.sword_hitbox.active, " g hurt ", g.hurtbox.monitorable, " gpos ", g.global_position, " ppos ", p.global_position)
			check("unarmed light attack is a jab", p.body_model.current_action() == "jab")
			wait = 0.4
			step += 1
		7:
			print("   punch: ", v0, " -> ", g.health.current_health)
			check("punches hurt", g.health.current_health < v0)
			# dual swords: picking up a second cutlass
			p.inventory_component.add_item(item("cutlass"), 1)
			p.equip_weapon(p.inventory_component.find_item("cutlass"), false)
			if p.offhand_weapon == null:
				p.set_offhand(item("cutlass"))
			check("two cutlasses = dual wield", p.style() == "dual_sword" and p.offhand_weapon != null)
			check("off-hand blade in the left hand or on the hip", p.body_model.offhand != null)
			wait = 0.6
			step += 1
		8:
			face(g.global_position)
			p.reset_combo()
			attack("light_attack")
			wait = 0.12
			step += 1
		9:
			print("   dual action ", p.body_model.current_action())
			check("dual swords swing differently", p.body_model.current_action() == "dual_1")
			wait = 0.8
			step += 1
		10:
			attack("heavy_attack")
			wait = 0.1
			step += 1
		11:
			check("dual heavy attack", p.body_model.current_action() == "dual_heavy")
			wait = 1.2
			step += 1
		12:
			# pistols
			p.inventory_component.add_item(item("pistol"), 1)
			p.equip_weapon(item("pistol"), false)
			check("pistol style", p.style() == "pistol" and p.offhand_weapon == null)
			g = camp.grunts[2]
			g._stagger_len = 30.0
			g._set_state(STAGGER)
			clear_others(g)
			g.health.current_health = 110.0
			park(g, ground(p.global_position + Vector3(0, 0, -6.0)))
			face(g.global_position)
			wait = 0.6
			step += 1
		13:
			face(g.global_position)
			aim_at(g.hurtbox.global_position)
			v0 = g.health.current_health
			set_meta("ammo", p.ammo[0])
			attack("light_attack")
			wait = 0.25
			step += 1
		14:
			print("   shot dist ", snappedf((g.global_position - p.global_position).length(), 0.01), " gstate ", g.state, " cam fwd ", -root.get_viewport().get_camera_3d().global_basis.z)
			print("   shot: ", v0, " -> ", g.health.current_health, " ammo ", p.ammo)
			check("pistol shot uses a round", p.ammo[0] == int(get_meta("ammo")) - 1)
			check("pistol shot hits", g.health.current_health < v0)
			# the over-the-shoulder camera is shifted by h/v_offset: the shot ray must
			# still go through the crosshair (screen centre)
			var cam: Camera3D = root.get_viewport().get_camera_3d()
			var centre: Vector2 = root.get_viewport().get_visible_rect().size * 0.5
			var ray: Array = p.reticle_ray()
			var on_px: float = cam.unproject_position(ray[0] + ray[1] * 20.0).distance_to(centre)
			var old_px: float = cam.unproject_position(cam.global_position - cam.global_basis.z * 20.0).distance_to(centre)
			print("   reticle ray lands %.2f px off centre (camera-node ray: %.1f px; h_offset %.2f)" % [on_px, old_px, cam.h_offset])
			check("the shot ray goes through the crosshair (%.2f px off)" % on_px, on_px < 1.0)
			# crosshair well beside him: the shot goes where it points, not into him
			var side: Vector3 = p.player_model.global_basis.x
			aim_at(g.hurtbox.global_position + side * 1.5)
			set_meta("hp1", g.health.current_health)
			attack("light_attack")
			wait = 0.5
			step += 1
		15:
			check("a shot with the crosshair off the enemy misses", g.health.current_health == float(get_meta("hp1")))
			check("empty pistol reloads", p.reloading() or p.ammo[0] == p.max_ammo())
			p.inventory_component.add_item(item("pistol"), 1)
			check("second pistol = dual pistols", p.style() == "dual_pistol")
			wait = 1.8
			step += 1
		16:
			check("reloaded", p.ammo[0] == p.max_ammo() and p.ammo[1] == p.max_ammo())
			face(g.global_position)
			aim_at(g.hurtbox.global_position)
			attack("light_attack")
			wait = 0.3
			step += 1
		17:
			face(g.global_position)
			attack("light_attack")
			wait = 0.3
			step += 1
		18:
			print("   dual ammo ", p.ammo)
			check("dual pistols alternate hands", p.ammo[0] == p.max_ammo() - 1 and p.ammo[1] == p.max_ammo() - 1)
			# drawn pistols point where we face (not up the wrist)
			p.sheathe_weapon(true)   # (equipped mid-test: make sure they're really drawn)
			p.draw_weapon(true)
			wait = 0.5
			step = 179
		179:
			var fwd: Vector3 = -p.player_model.global_basis.z
			var worst := 1.0
			var grip := 1.0
			for w in [p.body_model.weapon, p.body_model.offhand]:
				var barrel := -(w as Node3D).global_basis.z.normalized()
				worst = minf(worst, barrel.dot(fwd))
				grip = minf(grip, barrel.dot(-((w as Node3D).get_parent() as Node3D).global_basis.y.normalized()))
			check("both pistols ride along the forearms (worst %.2f)" % grip, grip > 0.95)
			check("both pistols point ahead in the guard (worst %.2f)" % worst, worst > 0.6)
			# gun kata: a hop into the spin, on the move, tipped into the travel
			kata_vy = -99.0
			kata_hv = 0.0
			kata_tilt = 0.0
			kata_from = p.global_position
			Input.action_press("move_right")
			attack("heavy_attack")
			wait = 1.1
			step = 180
		180:
			Input.action_release("move_right")
			check("the gun kata hops into the air (up %.1f m/s)" % kata_vy, kata_vy > 3.0)
			check("the gun kata keeps moving (%.1f m/s)" % kata_hv, kata_hv > 4.0)
			check("the gun kata leans into the move (%.2f rad)" % kata_tilt, kata_tilt > 0.35)
			p.global_position = kata_from   # (the kata carried us off toward the shore)
			p.velocity = Vector3.ZERO
			p.reset_physics_interpolation()
			wait = 0.4
			step = 181
		181:
			# Bullet Storm (needs a gun)
			pc.energy = 100.0
			g = camp.grunts[4]
			clear_others(g)
			park(g, ground(p.global_position + Vector3(0, 0, -5.0)))
			g._stagger_len = 30.0
			g._set_state(STAGGER)
			face(g.global_position)
			g.health.current_health = 110.0
			v0 = g.health.current_health
			check("cast Bullet Storm", pc.try_cast(0))
			wait = 1.0
			step = 19
		19:
			var mz: Vector3 = p.global_position + Vector3(0, 1.3, 0) + Vector3(0, 0, -0.5)
			var eq := PhysicsRayQueryParameters3D.create(mz, mz + Vector3(0, 0, -30), 32)
			eq.collide_with_areas = true
			eq.collide_with_bodies = false
			var hh: Dictionary = p.get_world_3d().direct_space_state.intersect_ray(eq)
			print("   ray: ", hh.get("collider"), " owner ", (hh["collider"].owner.name if not hh.is_empty() else "-"), " at ", hh.get("position"))
			var wq := PhysicsRayQueryParameters3D.create(mz, mz + Vector3(0, 0, -30), 1)
			wq.exclude = [p.get_rid()]
			var ww: Dictionary = p.get_world_3d().direct_space_state.intersect_ray(wq)
			print("   wall: ", ww.get("collider"), " at ", ww.get("position"))
			print("   storm shots ", p.state_machine.get_node("Skill")._shots, " id ", p.state_machine.get_node("Skill").id, " t ", p.state_machine.get_node("Skill").t, " dir ", p.state_machine.get_node("Skill")._dir)
			print("   storm probe ", pc.enemies_in(g.global_position + Vector3(0, 1, 0), 1.0).size(), " hb mon ", g.hurtbox.monitorable, " layer ", g.hurtbox.collision_layer, " hb pos ", g.hurtbox.global_position, " shapes ", g.hurtbox.get_child_count(), " disabled ", g.hurtbox.get_child(0).disabled if g.hurtbox.get_child_count() > 0 else "-")
			print("   storm dist ", snappedf((g.global_position - p.global_position).length(), 0.01), " gstate ", g.state, " gname ", g.name, " ppos ", p.global_position, " gpos ", g.global_position, " pstate ", p.current_state_name())
			print("   storm: ", v0, " -> ", g.health.current_health)
			check("Bullet Storm hits", g.health.current_health < v0)
			check("sword skill refused with pistols", pc.can_cast(2) == "Needs a sword")
			# save + load
			SG = load("res://scripts/game/save_game.gd")
			SG.use_test_file("user://progtest_save.dat")
			check("save", SG.save(p))
			set_meta("lv", pr.level); set_meta("owned", pr.owned.size()); set_meta("bar", pc.loadout.duplicate())
			pr.level = 1; pr.owned = {"origin": true}
			for i in range(5): pc.loadout[i] = ""
			p.unequip_weapon()
			p.inventory_component.items.clear()
			check("load", SG.load_into(p))
			check("level and skill map restored", pr.level == int(get_meta("level" if false else "lv")) and pr.owned.size() == int(get_meta("owned")))
			check("skill bar restored", pc.loadout == get_meta("bar"))
			check("weapons restored (dual pistols)", p.style() == "dual_pistol")
			check("inventory restored", p.inventory_component.count("pistol") == 2 and p.inventory_component.count("cutlass") == 2)
			SG.delete()
			# Zoan: Wolf Fruit
			p.inventory_component.add_item(item("wolf_fruit"), 1)
			p.state_machine.force_state("Idle", {})
			p.use_item(item("wolf_fruit"))
			wait = 2.2
			step += 1
		20:
			check("ate the Wolf Fruit (Zoan)", pc.fruit == "wolf" and pc.fruit_type() == "zoan")
			check("Zoan starts with Rending Fang + Pounce", pr.knows("rending_fang") and pr.knows("pounce"))
			var sp0: float = p.move_speed
			p.toggle_hybrid()
			check("V: hybrid form", p.hybrid and p.style() == "claw")
			check("hybrid is faster", p.move_speed > sp0)
			check("wolf parts on", p.body_model._tail != null)
			g = camp.grunts[3]
			clear_others(g)
			g.health.current_health = 110.0
			park(g, ground(p.global_position + Vector3(0, 0, -3.5)))
			g._stagger_len = 30.0
			g._set_state(STAGGER)
			wait = 0.6
			step += 1
		21:
			face(g.global_position)
			v0 = g.health.current_health
			var slot: int = pc.loadout.find("rending_fang")
			if slot < 0:
				pc.equip("rending_fang", 0); slot = 0
			pc.energy = 100.0
			check("cast Rending Fang", pc.try_cast(slot))
			wait = 0.9
			step += 1
		22:
			print("   fang dist ", snappedf((g.global_position - p.global_position).length(), 0.01), " gstate ", g.state, " pstate ", p.current_state_name())
			print("   fang: ", v0, " -> ", g.health.current_health)
			check("Rending Fang rakes", g.health.current_health < v0 - 20.0)
			p.toggle_hybrid()
			check("back to human", not p.hybrid and p.style() != "claw")
			# Paramecia + Logia behaviour (swap the fruit directly)
			pc.fruit = "vine"
			pr.grant_fruit("vine")
			check("Vine starts with Snare + Swing", pr.knows("vine_snare") and pr.knows("vine_swing"))
			g.health.current_health = 110.0
			pc.root_enemy(g, 2.0)
			check("Vine Snare roots", g.state == STAGGER and g.get_node_or_null("VineWrap") != null)
			pos0 = p.global_position
			p.state_machine.force_state("Swing", {"anchor": p.global_position + Vector3(4, 7, 0)})
			wait = 0.6
			step += 1
		23:
			print("   swing state ", p.current_state_name(), " moved ", snappedf(p.global_position.distance_to(pos0), 0.1))
			check("swinging moves you", p.global_position.distance_to(pos0) > 1.0)
			wait = 3.0
			step += 1
		24:
			check("swing ends", p.current_state_name() != "Swing")
			pc.fruit = "ember"
			p.state_machine.force_state("Idle", {})
			put(get_meta("land") + Vector3.UP * 0.3)
			wait = 0.3
			step += 1
		25:
			p.state_machine.force_state("Dodge", {})
			wait = 0.2
			step += 1
		26:
			print("   dodge state ", p.current_state_name(), " hurt ", p.hurtbox.monitorable, " vis ", p.body_model.visible, " mask12 ", p.get_collision_mask_value(12), " type ", pc.fruit_type(), " supp ", pc.suppressed(), " depth ", p.water_depth())
			check("logia dodge: intangible", not p.hurtbox.monitorable and not p.body_model.visible and not p.get_collision_mask_value(12))
			wait = 0.4
			step += 1
		27:
			check("re-forms after", p.hurtbox.monitorable and p.body_model.visible and p.get_collision_mask_value(12))
			print("RESULT ", "OK" if fails == 0 else "FAILED %d" % fails)
			quit(1 if fails else 0)
	return false
