extends SceneTree
## Skill trees round 2: every tree's nodes can all be learned (the webs are connected),
## each weapon / unarmed technique and ultimate lands on a grunt with the right weapon
## in hand, grapples carry their target, blades deflect shots, Riposte answers a blow,
## Conqueror's Haki fells the weak, and a few base passives do their thing.
const STAGGER := 9; const DOWN := 11; const GETUP := 12; const DEAD := 14; const SWIM := 19
var t := 0.0
var step := 0
var wait := 0.0
var p
var pr
var pc
var camp
var fails := 0
var g
var v0 := 0.0
var pos0 := Vector3.ZERO
var gpos0 := Vector3.ZERO
var moved := 0.0
var went_down := false
var guard := 0
var idx := 0
var phase := 0
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
	var arm: Node3D = root.get_viewport().get_camera_3d().get_parent()
	arm.rotation.x = 0.0
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
func item(id: String):
	return load("res://resources/items/%s.tres" % id)
## A grunt that's up and about (not down, getting up or dead).
func fresh():
	for x in camp.grunts:
		if is_instance_valid(x) and not (x.state in [DOWN, GETUP, DEAD]):
			return x
	return null
func clear_others(keep) -> void:
	var i := 0
	for x in camp.grunts:
		if is_instance_valid(x) and x != keep and x.state != DEAD:
			i += 1
			if x.state == DOWN:
				continue
			park(x, ground(p.global_position + Vector3(40 + i * 3, 0, 40)))
func arm(style: String) -> void:
	p.state_machine.force_state("Idle", {})
	p.unequip_weapon()
	match style:
		"sword":
			p.equip_weapon(item("cutlass"), false)
		"katana":
			p.equip_weapon(item("katana"), false)
		"axe":
			p.equip_weapon(item("boarding_axe"), false)
		"dual_sword":
			p.equip_weapon(item("cutlass"), false)
			p.set_offhand(item("cutlass"))
		"pistol":
			p.equip_weapon(item("pistol"), false)
	p.sheathe_weapon(true)
	p.draw_weapon(true)

# [skill, style, distance in front (m), extra check]
const CASES := [
	["swordfish", "sword", 1.8, ""],
	["kraken_wake", "sword", 5.0, "down"],
	["wind_sever", "katana", 6.0, ""],
	["phantom_step", "katana", 6.0, "blink"],
	["petal_storm", "katana", 5.0, ""],
	["axe_throw", "axe", 7.0, "axe_back"],
	["earthsplitter", "axe", 4.0, "down"],
	["maelstrom", "axe", 2.0, ""],
	["blade_dance", "dual_sword", 3.0, ""],
	["cross_fang", "dual_sword", 3.5, ""],
	["steel_tempest", "dual_sword", 2.0, ""],
	["deadeye", "pistol", 10.0, ""],
	["point_blank", "pistol", 2.5, ""],
	["deaths_waltz", "pistol", 8.0, ""],
	["suplex", "fist", 1.4, "carried"],
	["hip_toss", "fist", 1.4, "carried"],
	["giant_swing", "fist", 1.4, "carried"],
	["hundred_fists", "fist", 1.4, ""],
	["rising_dragon", "fist", 1.4, ""],
	["palm_strike", "fist", 2.5, ""],
	["sea_king_fist", "fist", 6.0, "down"],
]
func _process(d: float) -> bool:
	t += d
	if camp:
		for x in camp.grunts:
			if is_instance_valid(x):
				x._cooldown = 99.0; x._pistol_cd = 99.0; x._shot_cd = 99.0; x._shove_cd = 99.0
	if g and is_instance_valid(g) and phase == 2:
		moved = maxf(moved, g.global_position.distance_to(gpos0))
		went_down = went_down or g.state in [DOWN, DEAD, SWIM]
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
			# learn everything: every node of every tree (but the fruit) should be reachable
			pr.level = 30
			pr.skill_points = 999
			for tr in SkillTree.TREES.keys():
				if SkillTree.is_mastery_tree(tr):
					pr.mastery_of(tr)["pts"] = 999
			var grew := true
			while grew:
				grew = false
				for k in SkillTree.nodes().keys():
					if pr.can_learn(k) == "":
						pr.learn(k)
						grew = true
			var missing: Array = []
			for k in SkillTree.nodes().keys():
				if SkillTree.nodes()[k]["tree"] != "fruit" and not pr.owns(k):
					missing.append(k)
			check("every node in every tree can be learned (missing: %s)" % str(missing), missing.is_empty())
			var trees_ok := true
			for tr in ["unarmed", "sword", "katana", "axe", "dual", "pistol"]:
				var n := 0
				var ults := 0
				for k in SkillTree.nodes().keys():
					if SkillTree.nodes()[k]["tree"] == tr:
						n += 1
						if SkillTree.nodes()[k]["kind"] == "ult":
							ults += 1
				print("   %s: %d nodes" % [tr, n])
				trees_ok = trees_ok and n >= 18 and ults == 1
			check("each weapon tree has 18+ nodes and one ultimate", trees_ok)
			var icons := true
			for sk in Skills.ALL.keys():
				icons = icons and Skills.icon(sk) != null
			check("every skill has an icon", icons)
			check("an ultimate from a weapon tree goes on R", pc.equip("kraken_wake", 4) and not pc.equip("kraken_wake", 0))
			# (Instinct's random sidestep would make the hits below flaky)
			pr.owned.erase("h_instinct")
			for id in ["cutlass", "cutlass", "katana", "boarding_axe", "pistol"]:
				p.inventory_component.add_item(item(id), 1)
			var land: Vector3 = ground(camp.grunts[0].global_position + Vector3(14, 0, 0))
			set_meta("land", land)
			idx = 0
			phase = 0
			step = 1
		1:
			# the technique cases, one at a time
			if idx >= CASES.size():
				step = 10
				return false
			var c: Array = CASES[idx]
			match phase:
				0:
					g = fresh()
					if g == null:
						wait = 0.5
						return false
					put(get_meta("land") + Vector3.UP * 0.2)
					arm(str(c[1]))
					check("%s: style %s" % [c[0], c[1]], p.style() == str(c[1]))
					clear_others(g)
					var at: Vector3 = ground(p.global_position + Vector3(0, 0, -float(c[2])))
					park(g, at)
					g._stagger_len = 30.0
					g._set_state(STAGGER)
					g.health.current_health = 400.0
					face(g.global_position)
					phase = 1
					wait = 0.3
				1:
					face(g.global_position)
					aim_at(g.hurtbox.global_position + Vector3.UP * 0.95)
					v0 = g.health.current_health
					pos0 = p.global_position
					gpos0 = g.global_position
					moved = 0.0
					went_down = false
					var ult := Skills.is_ult(str(c[0]))
					var slot := 4 if ult else 0
					pc.equip(str(c[0]), slot)
					pc.energy = pc.max_energy()
					pc.ult = 100.0
					pc.cooldowns.clear()
					check("cast %s" % c[0], pc.try_cast(slot))
					phase = 2
					wait = 3.4 if str(c[0]) in ["maelstrom", "steel_tempest", "deaths_waltz", "giant_swing"] else 1.8
				2:
					var hurt: bool = not is_instance_valid(g) or g.health.current_health < v0
					check("%s lands (%.0f -> %.0f)" % [c[0], v0, g.health.current_health if is_instance_valid(g) else 0.0], hurt)
					match str(c[3]):
						"down":
							# (thrown far enough, they land in the sea and swim)
							check("%s knocks them down" % c[0], went_down)
						"blink":
							check("Phantom Step blinks you behind them (moved %.1f m)" % p.global_position.distance_to(pos0), p.global_position.distance_to(pos0) > 4.0)
						"axe_back":
							check("the thrown axe comes back to your hand", p.body_model.weapon.visible)
						"carried":
							check("%s carries them (moved %.1f m)" % [c[0], moved], moved > 0.8)
					p.state_machine.force_state("Idle", {})
					idx += 1
					phase = 0
					wait = 0.3
		10:
			# a blade deflects a shot from the front (and Return to Sender sends it back)
			g = fresh()
			if g == null:
				wait = 0.5
				return false
			arm("sword")
			clear_others(g)
			put(get_meta("land") + Vector3.UP * 0.2)
			park(g, ground(p.global_position + Vector3(0, 0, -8.0)))
			g._stagger_len = 30.0
			g._set_state(STAGGER)
			g.health.current_health = 400.0
			face(g.global_position)
			wait = 0.3
			step += 1
		11:
			face(g.global_position)
			v0 = g.health.current_health
			var hp0: float = p.health_component.current_health
			var shot := HitData.new()
			shot.ranged = true
			shot.damage = 10.0
			p._deflect_cd = 0.0
			p.hurtbox.take_hit(shot, g)
			check("Return to Sender: a cutlass cuts a shot by itself", p.health_component.current_health == hp0)
			check("...and sends it back at the shooter", g.health.current_health < v0)
			var hp1: float = p.health_component.current_health
			p.hurtbox.take_hit(shot, g)
			check("the next shot right after isn't deflected", p.health_component.current_health < hp1)
			# the early upgrade: a parry cuts shots (Arrow Cutting); without it, it doesn't
			p._deflect_cd = 99.0
			p.is_parrying = true
			var hp2: float = p.health_component.current_health
			p._on_hit_received(shot, g)
			check("Arrow Cutting: a cutlass parry cuts a shot", p.health_component.current_health == hp2)
			pr.owned.erase("s_deflect")
			p._on_hit_received(shot, g)
			check("without Arrow Cutting a parry doesn't stop a shot", p.health_component.current_health < hp2)
			pr.owned["s_deflect"] = true
			p.is_parrying = false
			p._deflect_cd = 0.0
			guard = 0
			step = 30
		30:
			# the guard skills (Riposte, Iai Counter, Crossed Counter) turn a blow aside and answer it
			var gs: Array = [["riposte", "sword"], ["iai_counter", "katana"], ["cross_counter", "dual_sword"]][guard]
			arm(str(gs[1]))
			face(g.global_position)
			pc.equip(str(gs[0]), 0)
			pc.energy = pc.max_energy()
			pc.cooldowns.clear()
			check("cast %s" % gs[0], pc.try_cast(0))
			wait = 0.25
			step = 31
		31:
			v0 = g.health.current_health
			var hp0: float = p.health_component.current_health
			var blow := HitData.new()
			blow.damage = 12.0
			park(g, ground(p.global_position - p.player_model.global_basis.z * 1.5))
			p.hurtbox.take_hit(blow, g)
			check("the guard turns the blow aside", p.health_component.current_health == hp0)
			check("...into its counter", p.current_state_name() == "Technique" and p.state_machine.get_node("Technique").id == "riposte_counter")
			wait = 0.6
			step = 32
		32:
			check("...which cuts them (%s)" % p.style(), g.health.current_health < v0)
			if p.style() == "katana":
				check("the katana is back in hand after the counter", p.body_model.weapon_in_hand)
			guard += 1
			step = 30 if guard < 3 else 33
		33:
			# a guard that nobody tests: Iai Counter draws the blade again
			arm("katana")
			pc.equip("iai_counter", 0)
			pc.energy = pc.max_energy()
			pc.cooldowns.clear()
			pc.try_cast(0)
			wait = 1.6
			step = 34
		34:
			check("an unanswered Iai Counter draws the katana again", p.body_model.weapon_in_hand)
			step = 13
		13:
			# Berserk / Smoke Bomb buffs
			arm("axe")
			pc.equip("berserk", 0)
			pc.energy = pc.max_energy()
			pc.cooldowns.clear()
			v0 = p.damage_multiplier()
			check("cast Berserk", pc.try_cast(0))
			wait = 0.6
			step += 1
		14:
			check("Berserk: hit harder", pc.buff("berserk") and p.damage_multiplier() > v0)
			arm("pistol")
			pc.equip("smoke_bomb", 0)
			pc.energy = pc.max_energy()
			pc.cooldowns.clear()
			check("cast Smoke Bomb", pc.try_cast(0))
			wait = 0.35
			step += 1
		15:
			check("Smoke Bomb: you vanish", p.vanished() and not p.body_model.visible)
			wait = 1.6
			step += 1
		16:
			check("...and come back", not p.vanished() and p.body_model.visible)
			# grapples won't lift a boss-sized foe; nobody in reach = the cast is given back
			arm("fist")
			clear_others(null)
			pc.equip("suplex", 0)
			pc.energy = 50.0
			pc.cooldowns.clear()
			pc.try_cast(0)
			check("a grapple with nobody in reach gives the energy back", pc.energy >= 50.0 - 0.01 and pc.cooldown_left(0) == 0.0)
			# base passives
			check("Featherfall and Quick Learner learned", pr.has_flag("featherfall") and pr.stat("xp_pct") > 0.0)
			var xp0: int = pr.xp
			var lv0: int = pr.level
			pr.add_xp(100)
			check("Quick Learner: +10% experience", pr.level > lv0 or pr.xp - xp0 == 110)
			var m0: float = p.damage_multiplier()
			p.health_component.current_health = p.health_component.max_health * 0.2
			check("Adrenaline: hurt badly, hit harder", p.damage_multiplier() > m0)
			p.health_component.current_health = p.health_component.max_health
			step += 1
		17:
			# Conqueror's Haki: the weak faint, the rest reel
			g = fresh()
			if g == null:
				wait = 0.5
				return false
			clear_others(g)
			put(get_meta("land") + Vector3.UP * 0.2)
			park(g, ground(p.global_position + Vector3(0, 0, -5.0)))
			g.health.current_health = g.health.max_health * 0.2
			pc.equip("conquerors_haki", 4)
			pc.ult = 100.0
			pc.cooldowns.clear()
			p.state_machine.force_state("Idle", {})
			check("cast Conqueror's Haki", pc.try_cast(4))
			wait = 1.0
			step += 1
		18:
			check("Conqueror's Haki fells the weak (state %d)" % g.state, g.state == DEAD)
			print("RESULT ", "OK" if fails == 0 else "FAILED %d" % fails)
			quit(1 if fails else 0)
	return false
