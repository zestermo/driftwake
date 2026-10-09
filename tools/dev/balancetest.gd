extends SceneTree
## Spam limits and weapon mastery: right-clicks in a row cost more (a light
## attack resets it), the same one repeated grows predictable and a grunt reads
## it (no damage), the gun kata shoots at most 3 and then reloads, a full iai
## draw costs extra, a hit breaks the iai charge, a bullet flinches a grunt at
## most once a second, the XP curve; the element's mastery passives (tier 1
## level 8, tier 2 level 16 after tier 1).
const CIRCLE := 3
const BLOCK := 8
const HITSTUN := 10
var t := 0.0
var step := 0
var wait := 0.0
var fails := 0
var p
var st
var camp
var g
var hp0 := 0.0


func _initialize():
	change_scene_to_file("res://scenes/world/world.tscn")


func check(n: String, c: bool) -> void:
	print(("PASS " if c else "FAIL ") + n)
	if not c:
		fails += 1


func item(id: String):
	return load("res://resources/items/%s.tres" % id)


func ground(at: Vector3) -> Vector3:
	var q := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 30.0, at + Vector3.DOWN * 60.0, 1)
	var h: Dictionary = p.get_world_3d().direct_space_state.intersect_ray(q)
	return h["position"] if not h.is_empty() else at


func hit(dmg: float):
	var hd = load("res://scripts/combat/hit_data.gd").new()
	hd.damage = dmg
	hd.knockback_force = 3.0
	return hd


func _process(d: float) -> bool:
	t += d
	if wait > 0.0:
		wait -= d
		return false
	match step:
		0:
			if t < 2.0:
				return false
			for c in root.find_children("*", "CharacterCreator", true, false):
				c._finish(true)
			p = root.get_tree().get_first_node_in_group("player")
			camp = root.get_node("World/Islands/Brinehollow/SmugglersCamp")
			p.health_component.max_health = 9999.0
			p.health_component.current_health = 9999.0
			st = p.state_machine.current_state
			# --- fatigue
			st._heavy_chain = 0
			var c0: float = st.heavy_cost()
			st._heavy_used("HeavyAttack:sword")
			var c1: float = st.heavy_cost()
			st._heavy_used("HeavyAttack:sword")
			var c2: float = st.heavy_cost()
			check("right-clicks in a row cost more (%.0f, %.0f, %.0f)" % [c0, c1, c2], c1 > c0 * 1.4 and c2 > c1 * 1.4)
			check("the same heavy again grows predictable (%.2f)" % st.read_chance(), st.read_chance() > 0.3)
			st._heavy_used("HeavyAttack:sword")
			check("...more so each time (%.2f)" % st.read_chance(), st.read_chance() > 0.5)
			st._heavy_chain = 0
			check("a light attack (or a pause) resets the cost", is_equal_approx(st.heavy_cost(), c0))
			st._heavy_used("Iai:katana")
			check("a different heavy isn't predictable", st.read_chance() == 0.0)
			# --- a grunt reads a predictable heavy
			var land: Vector3 = ground(camp.grunts[0].global_position + Vector3(14, 0, 0))
			set_meta("land", land)
			p.global_position = land + Vector3.UP * 0.2
			p.reset_physics_interpolation()
			for x in camp.grunts:
				if is_instance_valid(x) and x.role == "sword":
					g = x
					break
			g.humanoid.seated = false
			g.global_position = land + Vector3(0, 0.3, -2.0)
			g.reset_physics_interpolation()
			g.facing.rotation.y = 0.0  # facing -Z... toward the player at +Z: turn round
			g.facing.rotation.y = PI
			g._set_state(CIRCLE)
			hp0 = g.health.current_health
			var hd = hit(30.0)
			hd.predictable = 1.0
			g.hurtbox.take_hit(hd, p)
			check("a grunt reads a heavy it saw coming (no damage, guards: state %d)" % g.state, is_equal_approx(g.health.current_health, hp0) and g.state == BLOCK)
			g._set_state(CIRCLE)
			var hd2 = hit(30.0)
			hd2.unblockable = true
			g.hurtbox.take_hit(hd2, p)
			check("...but not one it didn't (%.0f -> %.0f)" % [hp0, g.health.current_health], g.health.current_health < hp0)
			# (out of the way: its counter-slash would interrupt what follows)
			g.global_position = land + Vector3(40, 0.3, 40)
			g.reset_physics_interpolation()
			g._stagger_len = 60.0
			g._set_state(9)
			# (the camp held still: a rifleman's shot would break the charge first)
			for x in camp.grunts:
				if is_instance_valid(x) and x.state != 14:
					x._stagger_len = 60.0
					x._set_state(9)
			# --- the iai: a hit breaks the charge; a full draw costs extra
			p.inventory_component.add_item(item("katana"), 1)
			p.equip_weapon(item("katana"), false)
			p.sheathe_weapon(true)
			p.draw_weapon(true)
			p.state_machine.force_state("Iai", {})
			step = 1
			wait = 0.2
		1:
			check("charging the iai (%s)" % p.current_state_name(), p.current_state_name() == "Iai")
			p.hurtbox.take_hit(hit(2.0), g)
			wait = 0.05
			step = 2
		2:
			check("a hit breaks the charge (state %s)" % p.current_state_name(), p.current_state_name() == "Stagger")
			wait = 1.0
			step = 3
		3:
			p.progression.owned["k_full"] = true
			# (the camp's held still: a blow would break the charge, as it should)
			for x in camp.grunts:
				if is_instance_valid(x) and x.state != 14:
					x._stagger_len = 60.0
					x._set_state(9)
			p.state_machine.force_state("Idle", {})
			p.stamina = p.max_stamina
			var e := InputEventAction.new()
			e.action = "heavy_attack"
			e.pressed = true
			Input.parse_input_event(e)
			Input.action_press("heavy_attack")
			p.state_machine.force_state("Iai", {})
			wait = 1.5
			step = 4
		4:
			var ia = p.state_machine.current_state
			var charged: bool = p.current_state_name() == "Iai" and ia.level == 2
			check("fully charged (%s)" % p.current_state_name(), charged)
			if charged:
				var s0: float = p.stamina
				ia._release()
				check("a full draw costs extra stamina (%.0f -> %.0f)" % [s0, p.stamina], p.stamina <= s0 - 15.0)
			Input.action_release("heavy_attack")
			wait = 1.2
			step = 5
		5:
			# --- the gun kata: 3 at most, then a reload (back on the beach: the
			# full draw's dash carried us off it)
			p.state_machine.force_state("Idle", {})
			p.global_position = get_meta("land") + Vector3.UP * 0.2
			p.velocity = Vector3.ZERO
			p.reset_physics_interpolation()
			p.inventory_component.add_item(item("pistol"), 2)
			p.unequip_weapon()
			p.equip_weapon(item("pistol"), false)
			p.set_offhand(item("pistol"))
			p.progression.owned["g_kata"] = true
			check("two pistols (%s)" % p.style(), p.style() == "dual_pistol")
			var near: Array = []
			for x in camp.grunts:
				if is_instance_valid(x) and x.state != 14:
					near.append(x)
			for i in range(near.size()):
				near[i].global_position = p.global_position + Vector3(cos(i * 1.3) * 2.5, 0.3, sin(i * 1.3) * 2.5)
				near[i].reset_physics_interpolation()
				near[i].health.current_health = 900.0
				near[i]._stagger_len = 30.0
				near[i]._set_state(9)
			set_meta("near", near)
			p.state_machine.force_state("HeavyAttack", {})
			wait = 1.2
			step = 6
		6:
			var hurt := 0
			for x in get_meta("near"):
				if is_instance_valid(x) and x.health.current_health < 900.0:
					hurt += 1
			check("the gun kata shoots at most 3 (%d of %d hurt)" % [hurt, (get_meta("near") as Array).size()], hurt > 0 and hurt <= 3)
			check("then the guns reload", st.reload_until > st.now_s())
			# --- rapid fire can't hold a grunt in hitstun
			var x = get_meta("near")[0]
			x._set_state(CIRCLE)
			x._shot_flinch_t = 0.0
			var h0: float = x.health.current_health
			var shot = hit(8.0)
			shot.ranged = true
			x.hurtbox.take_hit(shot, p)
			check("a bullet flinches a grunt (state %d)" % x.state, x.state == HITSTUN)
			x._set_state(CIRCLE)
			var shot2 = hit(8.0)
			shot2.ranged = true
			x.hurtbox.take_hit(shot2, p)
			check("...but the next one straight after only hurts (state %d, %.0f -> %.0f)" % [x.state, h0, x.health.current_health], x.state == CIRCLE and x.health.current_health <= h0 - 15.0)
			var to5 := 0
			for lv in range(1, 5):
				to5 += p.progression.xp_to_next(lv)
			check("level 5 (the log pose) takes about Brinehollow's worth of XP (%d)" % to5, to5 > 3000 and to5 < 3800)
			# --- mastery: the element locked behind its passives
			var pr = p.progression
			pr.owned.erase("s_elem")
			pr.owned.erase("s_elem2")
			check("no element at first", not pr.elemental("sword") and not pr.elemental("sword", 2))
			pr.level = 5
			pr.owned["s_flying"] = true
			pr.mastery_of("sword")["pts"] = 10
			check("tier 1 needs level 8 (%s)" % pr.can_learn("s_elem"), pr.can_learn("s_elem").contains("level"))
			pr.level = 20
			pr.owned["s_captain"] = true
			check("tier 2 needs tier 1 (%s)" % pr.can_learn("s_elem2"), pr.can_learn("s_elem2").contains("Call of the Tide"))
			check("tier 1 learned", pr.learn("s_elem") and pr.elemental("sword") and not pr.elemental("sword", 2))
			check("tier 2 learned", pr.learn("s_elem2") and pr.elemental("sword", 2))
			print("RESULT ", "OK" if fails == 0 else "FAILED (%d)" % fails)
			quit()
			return true
	return false
