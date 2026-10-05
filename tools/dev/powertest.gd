extends SceneTree
## Devil Fruit (Ember) + skill bar + bindings + braced ragdolls + foot IK + parry sound.
const IDLE := 0; const HITSTUN := 10; const DOWN := 11; const GETUP := 12; const DEAD := 14
var t := 0.0
var step := 0
var wait := 0.0
var p
var pc
var camp
var isl
var ocean
var fails := 0
var g
var g2
var t0 := 0.0
var v0 := 0.0
var pos0 := Vector3.ZERO
var saw := {}
var failed := []
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
func put(pos: Vector3) -> void:
	p.global_position = pos
	p.velocity = Vector3.ZERO
	p.reset_physics_interpolation()
func ground(at: Vector3) -> Vector3:
	var q := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 30.0, at + Vector3.DOWN * 60.0, 1)
	var h: Dictionary = p.get_world_3d().direct_space_state.intersect_ray(q)
	return h["position"] if not h.is_empty() else at
func park_grunt(x, at: Vector3) -> void:
	x.humanoid.seated = false
	x.global_position = at + Vector3.UP * 0.3
	x.velocity = Vector3.ZERO
	x.reset_physics_interpolation()
func key_of(action: String) -> int:
	var evs := InputMap.action_get_events(action)
	return (evs[0] as InputEventKey).physical_keycode if evs.size() > 0 and evs[0] is InputEventKey else -1
func _process(d: float) -> bool:
	t += d
	# keep the crew from attacking (they still react to hits)
	if camp:
		for x in camp.grunts:
			if is_instance_valid(x):
				x._cooldown = 99.0; x._pistol_cd = 99.0; x._shot_cd = 99.0; x._shove_cd = 99.0
	if failed.size() > 0 and not has_meta("pf%d" % failed.size()):
		set_meta("pf%d" % failed.size(), true)
		print("   cast refused: ", failed[failed.size() - 1], " state ", p.current_state_name())
	if wait > 0.0:
		wait -= d
		return false
	match step:
		0:
			if t < 1.5: return false
			p = root.get_tree().get_first_node_in_group("player")
			p.health_component.max_health = 99999.0
			p.health_component.current_health = 99999.0
			pc = p.power
			camp = root.get_node("World/Islands/Brinehollow/SmugglersCamp")
			isl = root.get_node("World/Islands/Brinehollow")
			ocean = root.get_node("Ocean")
			p.power.cast_failed.connect(func(slot, why): failed.append([slot, why]))
			# bindings
			check("skills on 1-4, ultimate on R", key_of("skill_1") == KEY_1 and key_of("skill_4") == KEY_4 and key_of("ultimate") == KEY_R)
			check("quick items on 5-7, ready weapon on Z", key_of("hotbar_1") == KEY_5 and key_of("hotbar_3") == KEY_7 and not InputMap.has_action("hotbar_4") and key_of("ready_weapon") == KEY_Z)
			# the fruit is in the smugglers' strongbox
			var found := false
			for b in root.find_children("*", "LootBag", true, false):
				for st in b.contents:
					if st.item and st.item.id == "ember_fruit": found = true
			check("Ember Fruit is in the smugglers' strongbox", found)
			var hud = root.get_tree().get_first_node_in_group("hud")
			var bar = hud.get_node_or_null("SkillBar")
			check("skill bar on the HUD", bar != null and bar.visible)
			check("old health row hidden", not hud.get_node("Top/VBox/HealthRow").visible)
			check("no skills at level 1", not pc.has_fruit() and pc.can_cast(0) == "Empty" and p.progression.level == 1)
			check("parry sound loaded", root.get_node("FX")._streams.has("parry"))
			# eat it
			var fruit: ItemData = load("res://resources/items/ember_fruit.tres")
			p.inventory_component.add_item(fruit, 1)
			p.use_item(fruit)
			wait = 2.2
			step += 1
		1:
			check("ate the Ember Fruit", pc.has_fruit() and pc.fruit == "ember" and p.inventory_component.count("ember_fruit") == 0)
			check("energy full after eating", pc.energy > 95.0)
			check("logia starts with Fire Fist + Blazing Ring", pc.loadout[0] == "fire_fist" and pc.loadout[1] == "fire_ring")
			# learn the rest of the Ember tree
			var pr = p.progression
			pr.level = 10
			pr.skill_points = 99
			for nid in ["e_dash", "e_field", "e_kindled", "e_smolder", "e_heat", "e_inferno"]:
				pr.learn(nid)
			check("learned the Ember tree", pr.knows("flame_dash") and pr.knows("inferno") and pr.has_flag("kindled_blade"))
			check("auto-equipped onto the bar", pc.loadout[2] == "flame_dash" and pc.loadout[3] == "ember_field" and pc.loadout[4] == "inferno")
			# fire fist at a grunt 7 m away
			g = camp.grunts[0]
			g2 = camp.grunts[3]
			var spot: Vector3 = ground(g.global_position + Vector3(9, 0, 0))
			put(spot + Vector3.UP * 0.2)
			park_grunt(g, ground(spot + Vector3(-6.5, 0, 0)))
			park_grunt(g2, ground(spot + Vector3(0, 0, 30)))
			wait = 0.6
			step += 1
		2:
			face(g.global_position)
			v0 = g.health.current_health
			var e0: float = pc.energy
			check("cast Fire Fist", pc.try_cast(0))
			check("energy spent, cooldown set", pc.energy < e0 - 15.0 and pc.cooldown_left(0) > 2.0)
			check("in the Skill state", p.current_state_name() == "Skill")
			check("can't recast while cooling down", pc.can_cast(0) != "")
			wait = 1.0
			step += 1
		3:
			print("   grunt hp ", v0, " -> ", g.health.current_health)
			check("fireball hits and burns", g.health.current_health < v0 - 15.0)
			check("target set ablaze", g.get_node_or_null("Burn") != null or g.health.current_health < v0 - 24.0)
			v0 = g.health.current_health
			wait = 1.6
			step += 1
		4:
			print("   burn ticks: ", v0, " -> ", g.health.current_health)
			check("burning deals damage over time", g.health.current_health < v0)
			check("burn ticks don't flinch", g.state != HITSTUN)
			# Ember Field right on the grunt
			g.health.current_health = 110.0
			v0 = g.health.current_health
			var z = load("res://scripts/powers/fire_zone.gd").spawn(root.get_tree(), g.global_position, 3.0, 4.0, 10.0, p)
			check("fire zone in group", root.get_tree().get_nodes_in_group("fire_zones").size() >= 1)
			check("zone reports what it covers", z.contains(g.global_position) and not z.contains(g.global_position + Vector3(6, 0, 0)))
			wait = 1.6
			step += 1
		5:
			print("   in the fire: ", v0, " -> ", g.health.current_health)
			check("standing in the fire hurts", g.health.current_health < v0)
			# fire ring: two grunts close by
			for z in root.get_tree().get_nodes_in_group("fire_zones"): z.queue_free()
			g.health.current_health = 110.0
			g2.health.current_health = 110.0
			var here: Vector3 = p.global_position
			park_grunt(g, ground(here + Vector3(2.2, 0, 0)))
			park_grunt(g2, ground(here + Vector3(-1.5, 0, 1.8)))
			pc.cooldowns["fire_ring"] = 0.0
			pc.energy = 100.0
			wait = 0.3
			step += 1
		6:
			check("cast Blazing Ring", pc.try_cast(1))
			saw.clear()
			t0 = t
			step += 1
		7:
			saw[g.state] = true
			saw[100 + g2.state] = true
			if t - t0 < 1.0: return false
			check("ring knocks both down", saw.has(DOWN) and saw.has(100 + DOWN))
			check("ring burns (unblockable)", g.health.current_health < 100.0 and g2.health.current_health < 100.0)
			wait = 3.5
			step += 1
		8:
			# flame dash: untouchable, fast, leaves fire
			if p.current_state_name() != "Idle" and p.current_state_name() != "Move":
				return false
			pos0 = p.global_position
			var nz = root.get_tree().get_nodes_in_group("fire_zones").size()
			set_meta("nz", nz)
			pc.cooldowns["flame_dash"] = 0.0
			pc.energy = 100.0
			face(p.global_position + Vector3(0, 0, -10))
			check("cast Flame Dash", pc.try_cast(2))
			wait = 0.12
			step += 1
		9:
			check("untouchable mid-dash", not p.hurtbox.monitorable)
			wait = 0.6
			step += 1
		10:
			var dist = Vector2(p.global_position.x - pos0.x, p.global_position.z - pos0.z).length()
			print("   dash distance ", snappedf(dist, 0.1))
			check("dash covers ground (>4 m)", dist > 4.0)
			check("dash leaves a fire trail", root.get_tree().get_nodes_in_group("fire_zones").size() > int(get_meta("nz")))
			check("vulnerable again after", p.hurtbox.monitorable)
			# Kindled Blade: sword hits sear and charge the ultimate
			pc.ult = 0.0
			var hd := HitData.new(); hd.damage = 20.0
			g.health.current_health = 110.0
			var old = g.get_node_or_null("Burn")
			if old: old.free()
			p.sword_hitbox.hit_landed.emit(g, hd)
			check("sword hit charges the ultimate", pc.ult > 0.0)
			check("sword hit sears", g.get_node_or_null("Burn") != null)
			# ultimate refused until charged
			failed.clear()
			pc.try_cast(4)
			check("ultimate needs charge", failed.size() == 1 and str(failed[0][1]) == "Ultimate not charged")
			step += 1
			wait = 2.5
		11:
			if p.current_state_name() not in ["Idle", "Move"]:
				return false
			for z in root.get_tree().get_nodes_in_group("fire_zones"): z.queue_free()
			var here: Vector3 = p.global_position
			for x in [g, g2]:
				x.health.current_health = 110.0
			park_grunt(g, ground(here + Vector3(3.5, 0, 0)))
			park_grunt(g2, ground(here + Vector3(-2.0, 0, -4.0)))
			wait = 1.5
			step += 1
		12:
			pc.ult = pc.ULT_MAX
			pc.cooldowns["inferno"] = 0.0
			v0 = g.health.current_health + g2.health.current_health
			check("cast Great Inferno", pc.try_cast(4))
			check("ult charge spent", pc.ult == 0.0)
			wait = 1.6
			step += 1
		13:
			var dealt = v0 - (maxf(g.health.current_health, 0.0) + maxf(g2.health.current_health, 0.0))
			print("   inferno dealt ", dealt)
			check("inferno hits everything around (>=80 total)", dealt >= 80.0)
			var big := false
			for z in root.get_tree().get_nodes_in_group("fire_zones"):
				if z.radius >= 5.0: big = true
			check("inferno leaves the ground burning", big)
			# dodge = flame step
			for z in root.get_tree().get_nodes_in_group("fire_zones"): z.queue_free()
			wait = 1.5
			step += 1
		14:
			if p.current_state_name() not in ["Idle", "Move"]:
				return false
			set_meta("nz", root.get_tree().get_nodes_in_group("fire_zones").size())
			p.state_machine.force_state("Dodge", {})
			wait = 0.5
			step += 1
		15:
			check("dodge leaves burning embers", root.get_tree().get_nodes_in_group("fire_zones").size() > int(get_meta("nz")))
			# thornbrush around the jungle stash burns away
			var thorn = isl.get_node("Thornbrush0")
			check("thornbrush blocks the stash", thorn != null and not thorn.burned)
			pc.ignite_burnables(thorn.global_position + Vector3(0, 1, 0), 1.0)
			wait = 4.5
			step += 1
		16:
			var thorn = isl.get_node("Thornbrush0")
			var other = isl.get_node("Thornbrush2")
			check("fire burns the thornbrush away", thorn.burned)
			check("collision gone once burned", thorn.get_child(0).disabled)
			check("other walls untouched", not other.burned)
			# the sea's curse
			var ship = root.get_tree().get_first_node_in_group("ship")
			put(ship.global_transform * Vector3(7.0, 2.0, 0.6))
			p.health_component.max_health = 200.0
			p.health_component.current_health = 200.0
			wait = 1.5
			step += 1
		17:
			check("deep water: swim state (sinking)", p.current_state_name() == "Swim")
			var head: Vector3 = p.body_model.head.global_position
			print("   head below surface ", snappedf(ocean.get_wave_height(head) - head.y, 0.01))
			check("Devil Fruit user sinks", ocean.get_wave_height(head) - head.y > 0.5)
			check("powers fizzle in the sea", pc.can_cast(0) == "Your power fizzles in the sea")
			v0 = p.health_component.current_health
			wait = 3.0
			step += 1
		18:
			print("   drowning hp ", v0, " -> ", p.health_component.current_health)
			check("drowning drains health", p.health_component.current_health < v0 - 10.0)
			# out again: on the deck
			var ship = root.get_tree().get_first_node_in_group("ship")
			p.health_component.max_health = 99999.0
			p.health_component.current_health = 99999.0
			p.state_machine.force_state("Idle", {})
			put(ship.global_transform * Vector3(0, 2.0, 0))
			wait = 1.5
			step += 1
		19:
			# braced ragdoll while alive, limp when dead
			p.knock_down(Vector3(0, 3, 4))
			wait = 0.3
			step += 1
		20:
			var rag = p.body_model.ragdoll
			check("living ragdoll braces", rag != null and rag.stiffness_target == 1.0 and rag.stiffness > 0.3)
			check("Devil Fruit user's ragdoll doesn't float", rag != null and rag.buoyancy < 0.5)
			p.health_component.take_damage(999999.0)
			wait = 0.3
			step += 1
		21:
			var rag = p.body_model.ragdoll
			check("dead goes limp", rag != null and rag.stiffness_target == 0.0)
			print("RESULT ", "OK" if fails == 0 else "FAILED %d" % fails)
			quit(1 if fails else 0)
	return false
