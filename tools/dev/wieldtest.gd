extends SceneTree
## The two-weapon movesets. Sword and pistol (Corsair): the style and what the off
## hand may hold, the combo (cut, point-blank shot using a ball, rising cut; the
## fourth hit, Powder Finale, only once learned: a spin cut and a shot that knocks
## flat), a shot with the pistol reloading is a butt-strike and the reload refills
## it, Powder Lunge (thrust, then a shot that knocks flat), Dead Man's Drop (the
## jump attack: a shot down, a dive, the landing knocks flat), the Corsair tree
## (nodes, ultimate, its element behind the mastery passives). Dual wield: each hit
## of the combo lands, Twin Spin only once learned, an off-hand axe hits harder than
## a second cutlass, the crashing heavy. Balance: each style's combo damage per
## second against the cutlass's.
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
var dmg_sword := 0.0
var dmg_axe := 0.0


func _initialize(): load("res://tools/dev/test_kit.gd").seed_of(self); change_scene_to_file("res://scenes/world/world.tscn")


func check(n: String, c: bool) -> void:
	print(("PASS " if c else "FAIL ") + n)
	if not c:
		fails += 1


func item(id: String):
	return load("res://resources/items/%s.tres" % id)


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


## A grunt that's up (not down or dead) `dist` m in front, held reeling at 900 health;
## the rest well away.
func target(dist: float) -> void:
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
	p._reset_ammo()


func hit_n(i: int) -> void:
	saw = {}
	p.state_machine.force_state("LightAttack", {"combo_index": i, "chain": true})


func lost() -> float:
	return hp0 - g.health.current_health


## Damage per second over a full combo (each hit's damage over the time until the next can chain).
func dps(st: String, n: int) -> float:
	var ls = load("res://scripts/player_states/light_attack_state.gd")
	var c: Dictionary = ls.STYLES[st]
	var d := 0.0
	var s := 0.0
	for i in range(n):
		d += float(c["damages"][i]) + (float(c["shots"][i]) if c.has("shots") else 0.0)
		s += float(AnimLab.spec(str(c["anims"][i])).get("chain", c["durations"][i]))
	return d / s


func _physics_process(_d: float) -> bool:
	if p:
		saw[p.body_model.current_action()] = true
	if g and is_instance_valid(g) and g.state == DOWN:
		downed = true
	return false


func _process(d: float) -> bool:
	t += d
	if t > 120.0:
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
			for id in ["cutlass", "cutlass", "pistol", "boarding_axe", "katana"]:
				p.inventory_component.add_item(item(id), 1)
			set_meta("home", ground(camp.grunts[1].global_position + Vector3(14, 0, 0)) + Vector3.UP * 0.2)
			# --- what the off hand may hold
			arm("cutlass", "pistol")
			check("a cutlass and a pistol: sword and pistol (%s)" % p.style(), p.style() == "sword_pistol" and p.offhand_kind() == "pistol")
			check("its tree is the Corsair's", SkillTree.style_tree(p.style()) == "corsair" and "corsair" in SkillTree.TAB_ORDER)
			arm("boarding_axe", "")
			check("no pistol beside an axe", not p.set_offhand(item("pistol")))
			arm("katana", "")
			check("no pistol beside a katana", not p.set_offhand(item("pistol")))
			arm("cutlass", "boarding_axe")
			check("a cutlass and an axe: dual wield, an axe in the off hand (%s, %s)" % [p.style(), p.offhand_kind()], p.style() == "dual_sword" and p.offhand_kind() == "axe")
			check("...the body knows it too", WieldMoves.offhand_kind(p.body_model) == "axe")
			# --- the Corsair tree
			var n := 0
			var ults := 0
			for k in SkillTree.nodes().keys():
				if SkillTree.nodes()[k]["tree"] == "corsair":
					n += 1
					ults += 1 if SkillTree.nodes()[k]["kind"] == "ult" else 0
			check("the Corsair tree has 16-19 nodes and one ultimate (%d)" % n, n >= 16 and n <= 19 and ults == 1)
			pr.mastery_of("corsair")["pts"] = 99
			check("no element at first", not pr.elemental("corsair"))
			pr.owned["cs_grape"] = true
			pr.level = 5
			check("Black Powder needs level 8 (%s)" % pr.can_learn("cs_elem"), pr.can_learn("cs_elem").contains("level"))
			pr.level = 20
			pr.owned["cs_captain"] = true
			check("Powder Keg needs Black Powder (%s)" % pr.can_learn("cs_elem2"), pr.can_learn("cs_elem2").contains("Black Powder"))
			check("Black Powder wakes the element on its skills", pr.learn("cs_elem") and pr.elemental("corsair") and not pr.elemental("corsair", 2))
			check("Powder Keg puts it on every blow", pr.learn("cs_elem2") and pr.elemental("corsair", 2))
			pr.level = 10
			# --- balance: combo damage per second against the cutlass's
			var cut := dps("sword", 3)
			var sp4 := dps("sword_pistol", 4)
			var sp3 := dps("sword_pistol", 3)
			var du4 := dps("dual_sword", 4)
			var ka := dps("katana", 3)
			var ax := dps("axe", 3)
			print("   combo dps: cutlass %.1f, katana %.1f, axe %.1f, sword+pistol %.1f (3 hits %.1f), dual %.1f" % [cut, ka, ax, sp4, sp3, du4])
			check("sword and pistol between the cutlass and the axe", sp4 > cut and sp4 <= ax * 1.05)
			check("dual wield between the cutlass and the axe", du4 > cut and du4 <= ax * 1.05)
			arm("cutlass", "pistol")
			step = 10
		# --- the sword-and-pistol combo, hit by hit
		10:
			target(1.7)
			wait = 0.3
			idx = 0
			step = 11
		11:
			set_meta("ammo", p.ammo[0])
			hp0 = g.health.current_health
			hit_n(idx)
			wait = 0.8
			step = 12
		12:
			var anim: String = ["sp_cut", "sp_shot", "sp_rise"][idx]
			check("combo hit %d: %s played (%s)" % [idx + 1, anim, str(saw.keys())], saw.has(anim))
			check("...and lands (%.0f)" % lost(), lost() > 0.0)
			if idx == 1:
				check("...the shot used a ball (%d -> %d)" % [get_meta("ammo"), p.ammo[0]], p.ammo[0] == int(get_meta("ammo")) - 1)
			g._set_state(STAGGER)
			idx += 1
			step = 11 if idx < 3 else 13
		13:
			check("three hits until Powder Finale is learned (%d)" % p.state_machine.get_node("LightAttack").combo_count, p.state_machine.get_node("LightAttack").combo_count == 3)
			pr._own("cs_finale")
			target(1.7)
			p._reset_ammo()
			wait = 0.3
			step = 14
		14:
			hit_n(3)
			wait = 1.3
			step = 15
		15:
			check("Powder Finale: played (%s)" % str(saw.keys()), saw.has("sp_finale") and p.state_machine.get_node("LightAttack").combo_count == 4)
			check("...the spin and the shot land (%.0f)" % lost(), lost() > 20.0)
			check("...and knock them flat", downed)
			# empty the pistol: it reloads by itself; a shot meanwhile is a butt-strike
			target(1.7)
			p.ammo[0] = 1
			wait = 0.3
			step = 16
		16:
			hit_n(1)
			wait = 0.7
			step = 17
		17:
			check("the last ball fired: reloading (%s)" % str(p.ammo), p.reloading() and p.ammo[0] == 0)
			g._set_state(STAGGER)
			hp0 = g.health.current_health
			hit_n(1)
			wait = 0.7
			step = 18
		18:
			check("a shot while reloading is a butt-strike: it lands (%.0f) without a ball" % lost(), lost() > 0.0 and p.ammo[0] == 0)
			wait = 1.6
			step = 19
		19:
			check("...and the pistol's loaded again (%s)" % str(p.ammo), not p.reloading() and p.ammo[0] == p.max_ammo())
			# --- Powder Lunge
			target(2.4)
			wait = 0.3
			step = 20
		20:
			saw = {}
			p.stamina = p.max_stamina
			p.state_machine.force_state("HeavyAttack", {})
			set_meta("ammo", p.ammo[0])
			wait = 1.2
			step = 21
		21:
			check("Powder Lunge: played (%s)" % str(saw.keys()), saw.has("sp_lunge"))
			check("...the thrust and the shot land (%.0f)" % lost(), lost() > 25.0)
			check("...knocking them flat", downed)
			check("...with a ball (%d -> %d)" % [get_meta("ammo"), p.ammo[0]], p.ammo[0] < int(get_meta("ammo")) or p.reloading())
			# --- Dead Man's Drop
			pr._own("cs_drop")
			target(3.2)
			p._reset_ammo()
			wait = 0.3
			step = 22
		22:
			p.global_position += Vector3.UP * 3.0
			p.velocity = Vector3.ZERO
			p.reset_physics_interpolation()
			saw = {}
			p.stamina = p.max_stamina
			wait = 0.12
			step = 23
		23:
			p.input_buffer.buffer_action("light_attack")
			wait = 1.4
			step = 24
		24:
			check("Dead Man's Drop: played (%s)" % str(saw.keys()), saw.has("sp_drop") and saw.has("sp_drop_land"))
			check("...the shot and the dive land (%.0f)" % lost(), lost() > 20.0)
			check("...the landing knocks them flat", downed)
			step = 30
		# --- dual wield
		30:
			arm("cutlass", "cutlass")
			pr._own("d_spin")
			target(1.7)
			idx = 0
			wait = 0.3
			step = 31
		31:
			hp0 = g.health.current_health
			hit_n(idx)
			wait = 0.85
			step = 32
		32:
			var anim: String = ["dual_1", "dual_2", "dual_cross", "dual_spin"][idx]
			check("dual hit %d: %s played and lands (%.0f)" % [idx + 1, anim, lost()], saw.has(anim) and lost() > 0.0)
			if idx == 1:
				dmg_sword = lost()
			g._set_state(STAGGER)
			idx += 1
			step = 31 if idx < 4 else 33
		33:
			pr.owned.erase("d_spin")
			pr._stat_n = -1
			hit_n(0)
			check("no Twin Spin without the move (%d hits)" % p.state_machine.get_node("LightAttack").combo_count, p.state_machine.get_node("LightAttack").combo_count == 3)
			wait = 0.8
			step = 34
		34:
			arm("cutlass", "boarding_axe")
			target(1.7)
			wait = 0.3
			step = 35
		35:
			hp0 = g.health.current_health
			hit_n(1)
			wait = 0.85
			step = 36
		36:
			dmg_axe = lost()
			check("an off-hand axe hacks harder than a second cutlass (%.1f vs %.1f)" % [dmg_axe, dmg_sword], dmg_axe > dmg_sword * 1.15)
			arm("cutlass", "cutlass")
			target(2.2)
			wait = 0.3
			step = 37
		37:
			saw = {}
			p.stamina = p.max_stamina
			p.state_machine.force_state("HeavyAttack", {})
			wait = 1.1
			step = 38
		38:
			check("the dual heavy: played and lands (%.0f)" % lost(), saw.has("dual_heavy") and lost() > 20.0)
			print("RESULT ", "OK" if fails == 0 else "FAILED (%d)" % fails)
			quit(1 if fails else 0)
	return false
