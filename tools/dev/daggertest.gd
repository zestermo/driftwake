extends SceneTree
## The daggers. One dagger: the style, the combo (stab, slash, rising cut; the fourth,
## Gutting Strike, only once learned, and it bleeds), Shadow Lunge (out from behind
## them), Fang Dive (a sure crit that bleeds), a blade in the back hits harder.
## Two daggers: their own style and tree, each combo hit lands, Fang Whirl gated,
## Scissor Rip's two blows, Knife Rain. Sword + dagger: dual wield with the dagger
## reversed in the off hand. The trees (nodes, one ultimate, the element behind
## mastery), the items (every design at every tier builds, sheathed with a sheath).
## Balance: combo damage per second against the cutlass's.
const STAGGER := 9; const DOWN := 11; const GETUP := 12; const DEAD := 14
var t := 0.0
var step := 0
var wait := 0.0
var fails := 0
var p
var pr
var camp
var g
var hp0 := 0.0
var saw := {}
var downed := false
var idx := 0


func _initialize(): load("res://tools/dev/test_kit.gd").seed_of(self); change_scene_to_file("res://scenes/world/world.tscn")


func check(n: String, c: bool) -> void:
	print(("PASS " if c else "FAIL ") + n)
	if not c:
		fails += 1


func item(id: String):
	return ItemDB.get_item(id)


func rig():
	var cam: Camera3D = root.get_viewport().get_camera_3d()
	return cam.get_parent().get_parent() as Node3D


func face(target: Vector3) -> void:
	var d: Vector3 = target - p.global_position
	d.y = 0
	rig().rotation.y = atan2(-d.x, -d.z)
	p.player_model.rotation.y = atan2(-d.x, -d.z)
	var arm: Node3D = root.get_viewport().get_camera_3d().get_parent()
	arm.rotation.x = 0.0


func ground(at: Vector3) -> Vector3:
	var q := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 30.0, at + Vector3.DOWN * 60.0, 1)
	var h: Dictionary = p.get_world_3d().direct_space_state.intersect_ray(q)
	return h["position"] if not h.is_empty() else at


func park(x, at: Vector3) -> void:
	x.humanoid.seated = false
	x.global_position = at + Vector3.UP * 0.3
	x.velocity = Vector3.ZERO
	x.reset_physics_interpolation()


## A grunt that's up `dist` m in front, held reeling at 900 health, facing `look`
## (1: toward you, -1: away); the rest well away.
func target(dist: float, look: float = 1.0) -> void:
	p.state_machine.force_state("Idle", {})
	p.global_position = get_meta("home")
	p.velocity = Vector3.ZERO
	p.reset_physics_interpolation()
	g = null
	for x in camp.grunts:
		if is_instance_valid(x) and not (x.state in [DOWN, GETUP, DEAD]):
			g = x
			break
	var i := 0
	for x in camp.grunts:
		if is_instance_valid(x) and x != g and x.state != DEAD:
			i += 1
			park(x, ground(p.global_position + Vector3(40 + i * 3, 0, 40)))
	park(g, ground(p.global_position + Vector3(0, 0, -dist)))
	g._stagger_len = 30.0
	g._set_state(STAGGER)
	g.health.current_health = 900.0
	g._yaw = 0.0 if look < 0.0 else PI
	g.facing.rotation.y = g._yaw
	for c in g.get_children():
		if str(c.name).begins_with("Bleed"):
			c.name = "BleedGone"
			c.queue_free()
	hp0 = 900.0
	downed = false
	face(g.global_position)
	p.stamina = p.max_stamina


func arm(main: String, off: String) -> void:
	p.state_machine.force_state("Idle", {})
	p.set_offhand(null)
	p.unequip_weapon()
	p.equip_weapon(item(main), false)
	if off != "":
		p.set_offhand(item(off))
	p.sheathe_weapon(true)
	p.draw_weapon(true)


func hit_n(i: int) -> void:
	saw = {}
	p.state_machine.force_state("LightAttack", {"combo_index": i, "chain": true})


func lost() -> float:
	return hp0 - g.health.current_health


func bleeding() -> bool:
	return g.get_node_or_null("Bleed") != null


func dps(st: String, n: int) -> float:
	var ls = load("res://scripts/player_states/light_attack_state.gd")
	var c: Dictionary = ls.STYLES[st]
	var d := 0.0
	var s := 0.0
	for i in range(n):
		d += float(c["damages"][i]) + (float(c["shots"][i]) if c.has("shots") else 0.0)
		s += float(AnimLab.spec(str(c["anims"][i])).get("chain", c["durations"][i]))
	return d / s


func tree_ok(tr: String) -> bool:
	var n := 0
	var ults := 0
	for k in SkillTree.nodes().keys():
		if SkillTree.nodes()[k]["tree"] == tr:
			n += 1
			ults += 1 if SkillTree.nodes()[k]["kind"] == "ult" else 0
	print("   %s tree: %d nodes" % [tr, n])
	return n >= 20 and ults == 1


func _physics_process(_d: float) -> bool:
	if p:
		saw[p.body_model.current_action()] = true
	if g and is_instance_valid(g) and g.state == DOWN:
		downed = true
	return false


func _process(d: float) -> bool:
	t += d
	if t > 150.0:
		check("timed out at step %d" % step, false)
		print("RESULT FAILED (%d)" % fails)
		quit(1)
		return true
	if camp:
		for x in camp.grunts:
			if is_instance_valid(x):
				x._cooldown = 99.0; x._pistol_cd = 99.0; x._shot_cd = 99.0; x._shove_cd = 99.0
	if wait > 0.0:
		wait -= d
		return false
	match step:
		0:
			if t < 1.5:
				return false
			for c in root.find_children("*", "CharacterCreator", true, false):
				c._finish(true)
			p = root.get_tree().get_first_node_in_group("player")
			pr = p.progression
			camp = root.get_node("World/Islands/Brinehollow/SmugglersCamp")
			p.health_component.max_health = 99999.0
			p.health_component.current_health = 99999.0
			pr.level = 10
			pr.owned.erase("h_instinct")
			for id in ["dagger", "dagger", "kris", "cutlass"]:
				p.inventory_component.add_item(item(id), 1)
			set_meta("home", ground(camp.grunts[1].global_position + Vector3(14, 0, 0)) + Vector3.UP * 0.2)
			# --- the items
			var built := true
			for id in WeaponDesigns.item_ids("dagger"):
				for tier in range(7):
					var it: ItemData = ItemDB.tiered(str(id), tier)
					built = built and it != null and it.icon != null and Props.weapon_mesh(it.model()).get_surface_count() > 0
			check("every dagger design builds at every tier, with an icon (%d designs)" % WeaponDesigns.item_ids("dagger").size(), built and WeaponDesigns.item_ids("dagger").size() >= 6)
			# --- styles
			arm("dagger", "")
			check("one dagger: the dagger style (%s)" % p.style(), p.style() == "dagger" and SkillTree.style_tree("dagger") == "dagger")
			p.sheathe_weapon(true)
			var sheath = p.body_model.hip_socket.get_node_or_null("DaggerSheath")
			check("sheathed: it hangs on the hip in a sheath", sheath != null and p.body_model.weapon.get_parent() == p.body_model.hip_socket)
			p.draw_weapon(true)
			check("drawn: the sheath stays on the hip", p.body_model.hip_socket.get_node_or_null("DaggerSheath") != null and p.body_model.weapon.get_parent() == p.body_model.hand_r)
			arm("dagger", "kris")
			check("two daggers: their own style and tree (%s)" % p.style(), p.style() == "dual_dagger" and SkillTree.style_tree("dual_dagger") == "dual_dagger")
			check("...the left one held reversed, the right one not", p.body_model.offhand.transform.basis.z.z < -0.9 and p.body_model.weapon.transform.basis.z.z > 0.9)
			arm("cutlass", "dagger")
			check("a cutlass and a dagger: dual wield, a dagger in the off hand (%s, %s)" % [p.style(), p.offhand_kind()],
				p.style() == "dual_sword" and p.offhand_kind() == "dagger" and WieldMoves.offhand_kind(p.body_model) == "dagger")
			check("...reversed in the off hand", p.body_model.offhand.transform.basis.z.z < -0.9)
			# --- trees
			check("the dagger tree: 20+ nodes and one ultimate", tree_ok("dagger"))
			check("the twin-dagger tree: 20+ nodes and one ultimate", tree_ok("dual_dagger"))
			check("both have a tab", "dagger" in SkillTree.TAB_ORDER and "dual_dagger" in SkillTree.TAB_ORDER)
			pr.mastery_of("dagger")["pts"] = 99
			pr.level = 5
			pr.owned["dg_fan"] = true
			check("Nightfall needs level 8 (%s)" % pr.can_learn("dg_elem"), pr.can_learn("dg_elem").contains("level"))
			pr.level = 20
			check("Nightfall wakes the element", pr.learn("dg_elem") and pr.elemental("dagger") and not pr.elemental("dagger", 2))
			pr.owned.erase("dg_fan")
			pr.owned.erase("dg_elem")
			pr._stat_n = -1
			pr.level = 10
			# --- balance
			var cut := dps("sword", 3)
			var dg3 := dps("dagger", 3)
			var dg4 := dps("dagger", 4)
			var dd3 := dps("dual_dagger", 3)
			var dd4 := dps("dual_dagger", 4)
			var ax := dps("axe", 3)
			print("   combo dps: cutlass %.1f, dagger %.1f (4 hits %.1f), twin daggers %.1f (4 hits %.1f), axe %.1f" % [cut, dg3, dg4, dd3, dd4, ax])
			check("the daggers sit between the cutlass and the axe (their crits and wounds on top)", dg3 > cut and dd4 <= ax and dd3 > dg3)
			arm("dagger", "")
			idx = 0
			step = 10
		# --- the dagger combo
		10:
			target(1.3)
			wait = 0.3
			step = 11
		11:
			hp0 = g.health.current_health
			hit_n(idx)
			wait = 0.6
			step = 12
		12:
			var anim: String = ["dg_stab", "dg_slash", "dg_rise"][idx]
			check("dagger hit %d: %s played and lands (%.0f)" % [idx + 1, anim, lost()], saw.has(anim) and lost() > 0.0)
			g._set_state(STAGGER)
			idx += 1
			step = 11 if idx < 3 else 13
		13:
			check("three hits until Gutting Strike is learned", p.state_machine.get_node("LightAttack").combo_count == 3)
			pr._own("dg_gut")
			target(1.3)
			wait = 0.3
			step = 14
		14:
			hit_n(3)
			wait = 0.9
			step = 15
		15:
			check("Gutting Strike: played, lands and bleeds (%.0f)" % lost(), saw.has("dg_gut") and lost() > 10.0 and bleeding())
			set_meta("hp", float(g.health.current_health))
			wait = 1.6
			step = 16
		16:
			check("...the wound keeps bleeding (%.0f -> %.0f)" % [get_meta("hp"), g.health.current_health], g.health.current_health < float(get_meta("hp")))
			# a blade in the back (crits and chance wounds off while it's measured)
			pr.stat("crit_dagger")
			pr._stats["crit_dagger"] = 0.0
			pr._stats["bleed_dagger"] = 0.0
			target(1.3, -1.0)
			check("facing away: you're behind them", p.power.behind(g))
			wait = 0.3
			step = 17
		17:
			hp0 = g.health.current_health
			hit_n(0)
			wait = 0.6
			step = 18
		18:
			set_meta("back", lost())
			target(1.3, 1.0)
			check("facing you: you're not behind them", not p.power.behind(g))
			wait = 0.3
			step = 19
		19:
			hp0 = g.health.current_health
			hit_n(0)
			wait = 0.6
			step = 20
		20:
			check("a stab in the back hits harder (%.0f vs %.0f)" % [float(get_meta("back")), lost()], float(get_meta("back")) > lost() * 1.3)
			# --- Shadow Lunge
			target(3.0)
			set_meta("pos", p.global_position)
			wait = 0.3
			step = 21
		21:
			saw = {}
			p.stamina = p.max_stamina
			set_meta("side", (p.global_position - g.global_position).dot(Vector3(0, 0, 1)))
			p.state_machine.force_state("HeavyAttack", {})
			wait = 0.9
			step = 22
		22:
			var side: float = (p.global_position - g.global_position).dot(Vector3(0, 0, 1))
			check("Shadow Lunge: played and lands (%.0f)" % lost(), saw.has("dg_shadow") and lost() > 15.0)
			check("...out from behind them (%.1f -> %.1f m along)" % [float(get_meta("side")), side], float(get_meta("side")) > 0.5 and side < -0.3)
			check("...and the hurtbox is back on", p.hurtbox.monitorable)
			# --- Fang Dive
			pr._own("dg_fang")
			target(3.2)
			wait = 0.3
			step = 23
		23:
			p.global_position += Vector3.UP * 3.0
			p.velocity = Vector3.ZERO
			p.reset_physics_interpolation()
			saw = {}
			p.stamina = p.max_stamina
			wait = 0.12
			step = 24
		24:
			p.input_buffer.buffer_action("light_attack")
			wait = 1.2
			step = 25
		25:
			# (it dives at whoever's nearest the aim: a grunt left lying here counts too)
			var struck: Array = p.state_machine.get_node("Plunge")._struck
			var hit_one = struck[0] if not struck.is_empty() else null
			check("Fang Dive: played, strikes and bleeds them (%s)" % str(saw.keys()),
				saw.has("fang_dive") and hit_one != null and hit_one.get_node_or_null("Bleed") != null)
			# --- two daggers
			arm("dagger", "dagger")
			pr._own("dd_whirl")
			target(1.3)
			idx = 0
			wait = 0.3
			step = 30
		30:
			hp0 = g.health.current_health
			hit_n(idx)
			wait = 0.7
			step = 31
		31:
			var anim: String = ["dd_1", "dd_2", "dd_3", "dd_4"][idx]
			check("twin-dagger hit %d: %s played and lands (%.0f)" % [idx + 1, anim, lost()], saw.has(anim) and lost() > 0.0)
			g._set_state(STAGGER)
			idx += 1
			step = 30 if idx < 4 else 32
		32:
			check("Fang Whirl bleeds", bleeding())
			pr.owned.erase("dd_whirl")
			pr._stat_n = -1
			hit_n(0)
			check("no Fang Whirl without the move (%d hits)" % p.state_machine.get_node("LightAttack").combo_count, p.state_machine.get_node("LightAttack").combo_count == 3)
			wait = 0.6
			step = 33
		33:
			target(1.8)
			wait = 0.3
			step = 34
		34:
			saw = {}
			p.stamina = p.max_stamina
			p.state_machine.force_state("HeavyAttack", {})
			wait = 1.0
			step = 35
		35:
			check("Scissor Rip: played, both blows land and bleed (%.0f)" % lost(), saw.has("dd_heavy") and lost() > 30.0 and bleeding())
			pr._own("dd_knives")
			target(3.0)
			wait = 0.3
			step = 36
		36:
			p.global_position += Vector3.UP * 3.0
			p.velocity = Vector3.ZERO
			p.reset_physics_interpolation()
			saw = {}
			p.stamina = p.max_stamina
			wait = 0.12
			step = 37
		37:
			p.input_buffer.buffer_action("light_attack")
			wait = 1.0
			step = 38
		38:
			check("Knife Rain: played and the knives land, bleeding (%.0f)" % lost(), saw.has("knife_rain") and lost() > 0.0 and bleeding())
			# --- sword + dagger: the off-hand stab is the dagger's
			arm("cutlass", "dagger")
			target(1.5)
			wait = 0.3
			step = 40
		40:
			hp0 = g.health.current_health
			hit_n(1)
			wait = 0.8
			step = 41
		41:
			check("cutlass + dagger: the off-hand backhand lands (%.0f)" % lost(), saw.has("dual_2") and lost() > 0.0)
			# Bleeding Edge: every hit bleeds for a while
			arm("dagger", "dagger")
			pr._own("dd_edge")
			p.power.equip("bleeding_edge", 0)
			p.power.energy = p.power.max_energy()
			check("cast Bleeding Edge", p.power.try_cast(0))
			wait = 0.8
			step = 42
		42:
			check("...the edge is on for 8 s", p.power.buff("bleeding_edge"))
			target(1.3)
			wait = 0.3
			step = 43
		43:
			hit_n(0)
			wait = 0.6
			step = 44
		44:
			check("...and a plain stab opens a wound", bleeding())
			print("RESULT ", "OK" if fails == 0 else "FAILED (%d)" % fails)
			quit(1 if fails else 0)
	return false
