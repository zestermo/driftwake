extends SceneTree
var t := 0.0
var step := 0
var wait := 0.0
var p
var log_lines: Array = []
var fails := 0
func _initialize(): change_scene_to_file("res://scenes/world/world.tscn")
func act(a: String) -> void:
	var e := InputEventAction.new(); e.action = a; e.pressed = true; Input.parse_input_event(e)
	var e2 := InputEventAction.new(); e2.action = a; e2.pressed = false; Input.parse_input_event(e2)
func check(name: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + name)
	if not cond: fails += 1
func st() -> String: return p.current_state_name()
func _process(d: float) -> bool:
	t += d
	if wait > 0.0:
		wait -= d
		return false
	match step:
		0:
			if t < 1.0: return false
			p = root.get_tree().get_first_node_in_group("player")
			var inv = p.inventory_component
			check("starts with cutlass", inv.count("cutlass") == 1)
			check("starts with 3 rum", inv.count("rum") == 3)
			check("quick slots: rum only (no weapons)", inv.hotbar[0] == "rum" and not inv.hotbar.has("cutlass") and inv.hotbar.size() == 3)
			check("cutlass sheathed on hip", p.body_model.weapon != null and not p.body_model.weapon_in_hand and p.body_model.weapon.get_parent() == p.body_model.hip_socket)
			act("ready_weapon"); wait = 0.6
		1:
			check("R draws weapon (armed)", p.armed)
			check("weapon in right hand", p.body_model.weapon_in_hand and p.body_model.weapon.get_parent() == p.body_model.hand_r)
			# stand next to a training dummy, facing it
			var dummy: Node3D = null
			for n in root.get_tree().get_nodes_in_group("") : pass
			var isl = root.get_node("World/Islands/Brinehollow")
			for c in isl.get_children():
				if c.name.begins_with("DummyTarget"): dummy = c; break
			check("found dummy", dummy != null)
			var hc = dummy.get_node("HealthComponent")
			set_meta("dummy_hc", hc)
			set_meta("dummy_hp", hc.current_health)
			p.global_position = dummy.global_position + Vector3(1.4, 0.3, 0)
			p.reset_physics_interpolation()
			for c in root.get_node("World").get_children():
				if c.has_method("shake"): c.rotation.y = PI * 0.5  # look -X toward dummy
			wait = 0.3
		2:
			act("light_attack"); wait = 0.15
		3:
			check("left click attacks when armed", st() == "LightAttack")
			check("slash animation playing", p.body_model.current_action().begins_with("slash"))
			wait = 0.6
		4:
			# (the cutlass's cut and recovery run past 0.6 s: Z only works once free)
			if not p.is_free() or p.body_model.current_action() != "":
				return false
			var hc = get_meta("dummy_hc")
			check("dummy took damage", hc.current_health < get_meta("dummy_hp") or hc.current_health == hc.max_health)
			print("   dummy hp ", get_meta("dummy_hp"), " -> ", hc.current_health)
			act("ready_weapon"); wait = 0.6
		5:
			check("R sheathes", not p.armed and not p.body_model.weapon_in_hand)
			act("light_attack"); wait = 0.5
		6:
			check("click while sheathed draws instead of attacking", p.armed and st() != "LightAttack")
			p.health_component.take_damage(50)
			act("hotbar_1"); wait = 0.2
		7:
			check("quick slot 1 (5) drinks rum", p.body_model.current_action() == "drink" and p.inventory_component.count("rum") == 2)
			wait = 1.0
		8:
			check("rum healed", p.health_component.current_health >= 84.0)
			print("   hp ", p.health_component.current_health)
			act("inventory"); wait = 0.1
		9:
			var gm = root.get_node("GameMenu")
			check("Tab opens inventory + pauses", gm.is_open() and root.get_tree().paused)
			act("inventory"); wait = 0.1
		10:
			var gm = root.get_node("GameMenu")
			check("Tab closes inventory", not gm.is_open() and not root.get_tree().paused)
			act("pause"); wait = 0.1
		11:
			var gm = root.get_node("GameMenu")
			check("Esc opens pause menu", gm.is_open() and gm._current == "pause")
			gm.open("options")
			var old_fov = root.get_node("Settings").get_value("video", "fov")
			root.get_node("Settings").set_value("video", "fov", 90.0)
			var cam = root.get_viewport().get_camera_3d()
			check("FOV setting applies", is_equal_approx(cam.fov, 90.0))
			root.get_node("Settings").set_value("video", "fov", old_fov)
			act("pause"); wait = 0.1
		12:
			var gm = root.get_node("GameMenu")
			check("Esc from options returns to pause", gm._current == "pause")
			act("pause"); wait = 0.2
		13:
			check("Esc closes menu", not root.get_node("GameMenu").is_open())
			check("double jump starts locked", not p.has_ability("double_jump") and p.max_jumps == 1)
			p.set_ability("double_jump", true)
			act("jump"); wait = 0.25
		14:
			check("jumped", st() in ["Jump", "Fall"])
			act("jump"); wait = 0.05
		15:
			check("double jump flips", p.body_model.current_action() == "flip")
			wait = 1.5
		16:
			# loot the ruins chest: treasure + boarding axe
			var isl = root.get_node("World/Islands/Brinehollow")
			var bag = null
			for c in isl.get_children():
				if c.get_class() == "StaticBody3D" and c.has_method("setup") and c.position.distance_to(Vector3(isl.RUINS.x - 1.5, c.position.y, isl.RUINS.y + 2.2)) < 0.5:
					bag = c
			check("ruins chest exists", bag != null)
			bag._on_picked_up(p)
			wait = 0.1
		17:
			var inv = p.inventory_component
			check("picked up axe", inv.count("boarding_axe") == 1)
			check("axe stays off the quick slots", not inv.hotbar.has("boarding_axe"))
			check("loot counted", inv.get_loot_count() == 1)
			p.equip_weapon(inv.find_item("boarding_axe"), true); wait = 0.6
		18:
			check("equipping the axe from the bag", p.equipped_weapon != null and p.equipped_weapon.id == "boarding_axe" and p.armed)
			check("axe damage mult", is_equal_approx(p.damage_multiplier(), 1.4))
			var gm = root.get_node("/root/GameManager")
			var store = root.get_tree().get_first_node_in_group("ship").storage
			var inv = p.inventory_component
			store.store(p, inv.find_index("treasure"), -1)
			check("the treasure goes into the ship's storage", inv.count("treasure") == 0 and gm.stored_count("treasure") == 1)
			check("...the weapons stay in the bag", inv.count("boarding_axe") == 1 and inv.count("cutlass") == 1)
			print("RESULT fails=", fails)
			quit()
	step += 1
	return false
