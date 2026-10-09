extends SceneTree
## Round 6: skill keys after closing the map, map tabs + framing, menus fit
## the screen, quick items, power auras, vine dash trail, Haki look, block,
## red unblockable grunt heavy, fall damage.
const STAGGER := 9; const WIND := 5
var t := 0.0
var step := 0
var wait := 0.0
var p
var pc
var camp
var g
var fails := 0
var hp0 := 0.0
var st0 := 0.0
var saw := {}


func _initialize():
	change_scene_to_file("res://scenes/world/world.tscn")


func check(name: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + name)
	if not cond:
		fails += 1


func gm():
	return root.get_node("GameMenu")


func ground(at: Vector3) -> Vector3:
	var q := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 30.0, at + Vector3.DOWN * 60.0, 1)
	var h: Dictionary = p.get_world_3d().direct_space_state.intersect_ray(q)
	return h["position"] if not h.is_empty() else at


func put(pos: Vector3) -> void:
	p.global_position = pos
	p.velocity = Vector3.ZERO
	p.reset_physics_interpolation()


func key(k: int, pressed: bool) -> void:
	var ev := InputEventKey.new()
	ev.keycode = k
	ev.physical_keycode = k
	ev.pressed = pressed
	Input.parse_input_event(ev)


func inside(c: Control) -> bool:
	var vis: Rect2 = root.get_visible_rect()
	var r := c.get_global_rect()
	# scale from fit_to_screen
	var sz := r.size * c.scale
	var pos := r.position + (r.size - sz) * 0.5 if c.scale != Vector2.ONE else r.position
	return pos.x >= 0.0 and pos.y >= 0.0 and pos.x + sz.x <= vis.size.x and pos.y + sz.y <= vis.size.y


func _process(d: float) -> bool:
	t += d
	if camp:
		for x in camp.grunts:
			if is_instance_valid(x):
				x._cooldown = 99.0; x._pistol_cd = 99.0; x._shot_cd = 99.0; x._shove_cd = 99.0
	if p and root.find_children("GroundVines*", "", true, false).size() > 0:
		saw["ground_vines"] = true
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
			var fruit: ItemData = load("res://resources/items/vine_fruit.tres")
			p.inventory_component.add_item(fruit, 1)
			p.use_item(fruit)
			wait = 2.2
			step += 1
		1:
			# --- the skill map no longer eats skill keys once closed
			var lo0: Array = pc.loadout.duplicate()
			p.sheathe_weapon(true)
			gm().open("skills")
			var sm = gm()._skills
			var home := Vector2(0, -sm.HEADER_H * 0.5)
			check("map opens on the base tree, centered", sm._tab == "base" and sm._pan == home)
			sm._pan = Vector2(900, 900)
			sm._sel = "e_root" if false else sm._fruit_root()
			gm().close()
			gm().open("skills")
			check("reopening re-centers the map", sm._pan == home)
			sm.set_tab("fruit")
			var only_fruit := true
			var any := false
			for id in SkillTree.nodes().keys():
				if sm._shown(id):
					any = true
					if str(SkillTree.nodes()[id]["req"].get("fruit", "")) != "vine":
						only_fruit = false
			check("Devil Fruit tab shows only your fruit's tree", any and only_fruit)
			sm.set_tab("base")
			var none_fruit := true
			for id in SkillTree.nodes().keys():
				if sm._shown(id) and str(SkillTree.nodes()[id]["req"].get("fruit", "")) != "":
					none_fruit = false
			check("base tab has no fruit nodes", none_fruit)
			sm.set_tab("katana")
			var only_katana := true
			for id in SkillTree.nodes().keys():
				if sm._shown(id) and str(SkillTree.nodes()[id]["tree"]) != "katana":
					only_katana = false
			check("a weapon tab shows only its tree", only_katana and sm._shown("k_full") and sm._sel == "k_root")
			# select a learned active, close, then press 1 in the world
			sm._sel = SkillTree.node_for_skill(pc.loadout[0])
			gm().close()
			saw["casts"] = 0
			pc.cast.connect(func(_s): saw["casts"] = int(saw["casts"]) + 1)
			pc.cast_failed.connect(func(_s, _w): saw["casts"] = int(saw["casts"]) + 1)
			saw["lo0"] = lo0
			key(KEY_1, true)
			wait = 0.05
			step += 1
		2:
			key(KEY_1, false)
			check("closed map doesn't reassign skills on 1", pc.loadout == saw["lo0"])
			check("1 reaches the skill bar after closing the map", int(saw["casts"]) > 0)
			# --- menus fit
			root.get_node("Settings").set_value("video", "psx_preset", 2)
			check("320x180 preset keeps the 800x450 UI canvas", root.content_scale_size == Vector2i(800, 450))
			check("...and pixelates the 3D in the post pass", root.get_node("PSX")._post_rect.material.get_shader_parameter("pixelate") == true)
			root.get_node("Settings").set_value("video", "psx_preset", 0)
			saw["scr_i"] = 0
			gm().open("pause")
			wait = 0.15
			step = 20
		20:
			var scrs := ["pause", "options", "controls", "load"]
			var i: int = saw["scr_i"]
			check("%s fits the screen" % scrs[i], inside(gm()._screens[scrs[i]]))
			i += 1
			saw["scr_i"] = i
			if i < scrs.size():
				gm().open(scrs[i])
				wait = 0.15
			else:
				gm().close()
				step = 3
		3:
			# --- quick items
			var inv = p.inventory_component
			check("3 quick slots, rum first, no weapons", inv.hotbar.size() == 3 and inv.hotbar[0] == "rum" and not inv.hotbar.has("cutlass"))
			inv.add_item(load("res://resources/items/pistol.tres"), 1)
			check("picked-up weapons don't take a quick slot", not inv.hotbar.has("pistol"))
			# --- power aura after a fruit skill
			var slot: int = pc.loadout.find("vine_snare")
			pc.energy = pc.max_energy()
			pc.cooldowns.clear()
			p.state_machine.force_state("Idle", {})
			check("cast Vine Snare", pc.try_cast(slot))
			wait = 0.8
			step += 1
		4:
			var aura = p.body_model.get_node_or_null("PowerAura")
			check("power aura lingers after a vine skill", aura != null and aura.get_child_count() > 0)
			check("vines linger on the legs", p.body_model.leg_l.find_children("ArmVines*", "", false, false).size() > 0)
			# --- vine dash trail
			p.state_machine.force_state("Idle", {})
			Input.action_press("move_forward")
			p.state_machine.force_state("Dodge", {})
			wait = 0.4
			step += 1
		5:
			Input.action_release("move_forward")
			check("dashing with the Vine Fruit sprouts vines on the ground", saw.get("ground_vines", false))
			# --- Armament: Coat
			p.progression.level = 12
			p.progression.skill_points = 20
			for nid in ["c_spirit", "h_arm", "h_coat"]:
				p.progression.learn(nid)
			check("learned Armament: Coat", p.progression.knows("armament_coat"))
			pc.equip("armament_coat", 3)
			pc.energy = pc.max_energy()
			check("haki sound loaded", root.get_node("FX")._streams.has("haki"))
			check("cast Armament: Coat", pc.try_cast(3))
			wait = 0.6
			step += 1
		6:
			var blackened := false
			var ab = p.body_model.torso.get_node("ArmBody")
			blackened = ab.arm_mesh(true).material_override != null and (p.weapon_class() in ["fist", "claw"] or ab.arm_mesh(false).material_override == null)
			check("the weapon arm turns haki black", blackened)
			var h = p.melee_hit(10.0)
			check("coated hits are haki + unblockable", h.haki and h.unblockable)
			# --- block
			p.state_machine.force_state("Idle", {})
			wait = 0.2
			step += 1
		7:
			g = camp.grunts[0]
			var spot: Vector3 = ground(g.global_position + Vector3(6, 0, 0))
			put(spot + Vector3.UP * 0.2)
			g.humanoid.seated = false
			g.global_position = ground(spot + Vector3(-1.8, 0, 0)) + Vector3.UP * 0.3
			g.reset_physics_interpolation()
			var to_g: Vector3 = g.global_position - p.global_position
			p.player_model.rotation.y = atan2(-to_g.x, -to_g.z)
			var rig = root.get_viewport().get_camera_3d().get_parent().get_parent()
			rig.rotation.y = atan2(-to_g.x, -to_g.z)
			Input.action_press("parry")
			p.state_machine.force_state("Parry", {})
			wait = 0.5
			step += 1
		8:
			check("holding parry settles into a block", p.current_state_name() == "Block" and p.is_blocking)
			hp0 = p.health_component.current_health
			st0 = p.stamina
			var hd := HitData.new()
			hd.damage = 12.0
			p.hurtbox.take_hit(hd, g)
			check("a frontal hit glances off the guard", p.health_component.current_health == hp0 and p.stamina < st0)
			var hd2 := HitData.new()
			hd2.damage = 12.0
			hd2.unblockable = true
			p.hurtbox.take_hit(hd2, g)
			check("an unblockable hit gets through the block", p.health_component.current_health < hp0)
			Input.action_release("parry")
			wait = 0.3
			step += 1
		9:
			check("letting go drops the block", p.current_state_name() != "Block")
			# --- the red unblockable grunt heavy
			p.state_machine.force_state("Idle", {})
			g._attack = "peril"
			g._start_wind()
			check("red wind-up: flashing, unblockable hit data", g._peril_on and g.hitbox.hit_data.unblockable and g.state == WIND)
			var red := false
			for mi in g.humanoid.find_children("*", "MeshInstance3D", true, false):
				if mi.material_overlay != null:
					red = true
			check("the grunt flashes red", red)
			var hd := HitData.new()
			hd.damage = 5.0
			g.hurtbox.take_hit(hd, p)
			check("normal hits don't stop the red wind-up", g.state == WIND)
			var hk := HitData.new()
			hk.damage = 5.0
			hk.haki = true
			g.hurtbox.take_hit(hk, p)
			check("a haki hit breaks it (staggered, no longer red)", g.state == STAGGER and not g._peril_on)
			# parry can't stop it either
			p.is_parrying = true
			hp0 = p.health_component.current_health
			var hp := HitData.new()
			hp.damage = 20.0
			hp.unblockable = true
			p._on_hit_received(hp, g)
			check("a parry can't stop an unblockable hit", p.health_component.current_health < hp0)
			p.is_parrying = false
			wait = 1.0
			step += 1
		10:
			# --- fall damage
			p.state_machine.force_state("Fall", {})
			p.health_component.max_health = 200.0
			p.health_component.current_health = 200.0
			put(ground(p.global_position + Vector3(4, 0, 0)) + Vector3.UP * 12.0)
			hp0 = 200.0
			wait = 0.2
			step += 1
		11:
			if not p.is_on_floor() and t < 120.0:
				saw["vy"] = p.velocity.y
				saw["st"] = p.current_state_name()
				return false
			if not saw.has("landed_wait"):
				saw["landed_wait"] = true
				wait = 0.25
				return false
			var dmg: float = hp0 - p.health_component.current_health
			check("a 12 m fall hurts (%.0f)" % dmg, dmg > 25.0 and dmg < 90.0)
			p.health_component.current_health = 200.0
			put(ground(p.global_position) + Vector3.UP * 3.0)
			wait = 0.1
			step += 1
		12:
			if not p.is_on_floor() and t < 120.0:
				return false
			if not saw.has("landed_wait2"):
				saw["landed_wait2"] = true
				wait = 0.25
				return false
			check("a 3 m drop is free", p.health_component.current_health == 200.0)
			print("RESULT ", "OK" if fails == 0 else "FAILED (%d)" % fails)
			quit()
	return false
