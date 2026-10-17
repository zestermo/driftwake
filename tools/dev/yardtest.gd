extends SceneTree
## The shipwright: Tackett by the dock opens his yard; upgrade levels cost gold
## (refused when short) and change the ship (plating + 8% hull a level, a third
## pair of guns at gun deck 2, faster sails, a sharper rudder); paint, sails, flag and figurehead
## change her looks; the kit is saved and loaded back. Then the sea polish:
## shallows baked, a wake laid under way, rain soaking and pooling on deck.
var SG
var KIT
var t := 0.0
var step := 0
var wait := 0.0
var p
var ship
var menu
var yard
var gm
var fails := 0
var t_mark := 0.0
func _initialize():
	load("res://tools/dev/test_kit.gd").seed_of(self)
	change_scene_to_file("res://scenes/world/world.tscn")
func check(name: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + name)
	if not cond: fails += 1
func finish() -> void:
	print("RESULT ", "OK" if fails == 0 else "FAILED (%d)" % fails)
	quit()
func gold() -> int:
	return p.inventory_component.count("gold")
func _process(d: float) -> bool:
	t += d
	if t > 60.0:
		check("timed out at step %d" % step, false)
		finish()
		return true
	if wait > 0.0:
		wait -= d
		return false
	match step:
		0:
			if t < 1.5: return false
			SG = load("res://scripts/game/save_game.gd")
			KIT = load("res://scripts/ship/ship_kit.gd")
			SG.use_test_dir("user://yardtest")
			SG.slot = 1
			SG.delete_slot(1)
			p = get_first_node_in_group("player")
			ship = get_first_node_in_group("ship")
			menu = root.get_node("GameMenu")
			gm = root.get_node("GameManager")
			yard = menu._yard
			var tackett = null
			for n in current_scene.find_children("*", "NPC", true, false):
				if n.dialogue_id == "tackett":
					tackett = n
			check("Shipwright Tackett is at the foot of the dock", tackett != null)
			check("a plain sloop to start: 4 guns, 400 hull, no figurehead", ship.cannons.size() == 4 and ship.max_hull == 400.0 and ship._figure_node.get_child_count() == 0 and ship.parts.pieces("armour") == 0)
			# talking it through to the yard
			var dlg = root.get_node("Dialogue")
			dlg.dialogue_event.emit("shipwright")
			dlg.dialogue_ended.emit("tackett")
			wait = 0.3
			step = 1
		1:
			check("his talk ends in the yard", menu._current == "yard" and yard.visible)
			p.inventory_component.remove_item(load("res://resources/items/gold.tres"), gold())
			yard.buy("armour")
			check("no gold, no refit", int(gm.ship_kit["armour"]) == 0 and ship.max_hull == 400.0)
			p.inventory_component.add_item(load("res://resources/items/gold.tres"), 1000)
			yard.buy("armour")
			print("   gold %d, hull %.0f / %.0f" % [gold(), ship.hull, ship.max_hull])
			check("hull plating 1: 60 gold, 8% more hull (topped up), wales on her sides", gold() == 940 and is_equal_approx(ship.max_hull, 432.0) and is_equal_approx(ship.hull, 432.0) and ship.parts.pieces("armour") == 1)
			yard.buy("armour")
			check("...level 2: another 100 gold, another 8%", gold() == 840 and is_equal_approx(ship.max_hull, 464.0) and ship.parts.pieces("armour") == 2)
			yard.buy("guns")
			yard.buy("guns")
			check("gun deck 2: a third pair of guns aft", ship.cannons.size() == 6 and ship.side_cannons(1.0).size() == 3 and gold() == 610)
			yard.buy("sails")
			check("sails 1: faster, and it shows", ship._top_k > 1.02 and ship.rig_scale.x > 1.02 and gold() == 560)
			yard.buy("rudder")
			check("rudder 1: sharper turns", ship._turn_k > 1.05 and gold() == 520)
			# looks
			var tex0 = ship._flag_node.material_override.get_shader_parameter("albedo_tex")
			yard.cycle("hull")
			yard.cycle("sail")
			yard.cycle("emblem")
			yard.cycle("figure")
			var painted := false
			for i in range(ship._psx_model.mesh.get_surface_count()):
				var m = ship._psx_model.get_surface_override_material(i)
				if m and m.get_shader_parameter("albedo_color") == KIT.HULL_PAINT[1][1]:
					painted = true
			check("hull paint goes on her planks", painted and gm.ship_kit["hull"] == 1)
			check("the sails take their colour", ship._sail_node.material_override.get_shader_parameter("albedo_color") == KIT.SAILS[1][1])
			check("the flag is repainted with an emblem", ship._flag_node.material_override.get_shader_parameter("albedo_tex") != tex0 and gm.ship_kit["emblem"] == 1)
			check("a figurehead under the bowsprit", ship._figure_node.get_child_count() == 1)
			check("looks are free", gold() == 520)
			for i in range(KIT.FIGURES.size()):
				yard.cycle("figure")
			check("every figurehead builds (back to the mermaid)", ship._figure_node.get_child_count() == 1 and gm.ship_kit["figure"] == 1)
			menu.close()
			# saved with the purchase; a fresh kit is replaced by the saved one on load
			gm.ship_kit = KIT.fresh()
			SG.load_into(p)
			check("the kit is saved and loaded back", gm.ship_kit["armour"] == 2 and gm.ship_kit["guns"] == 2 and gm.ship_kit["rudder"] == 1 and gm.ship_kit["figure"] == 1 and gm.ship_kit["emblem"] == 1)
			check("...and on her after the load", ship.cannons.size() == 6 and is_equal_approx(ship.max_hull, 464.0))
			# --- sea polish: shallows, wake, rain on deck
			var oc = root.get_node("Ocean")
			var coarse: Image = oc.shoal_map.get_image()
			var sc: Vector2 = root.get_node("World/Islands").starter_center
			check("the shallows are baked: Brinehollow's middle is dry, the open sea deep", oc.shores.has("brinehollow") and oc.shoal_rect.w == 1.0
				and oc.shore_at(sc.x, sc.y).x < 0.0 and coarse.get_pixel(2, 2).r > 0.95)
			ship.place(Vector3(sc.x + 330.0, 0.0, sc.y + 120.0), 0.6)
			p.global_position = ship.global_transform * Vector3(0, 0.8, 2.0)
			p.reset_physics_interpolation()
			root.get_node("Weather").force(2)
			t_mark = t
			step = 2
		2:
			ship.speed = 10.0
			if t - t_mark < 2.5:
				return false
			var oc = root.get_node("Ocean")
			var trail: Array = oc._wakes.get(ship.get_instance_id(), [])
			check("under way she lays a wake (%d points)" % trail.size(), trail.size() >= 4)
			check("rain soaks the deck (wet %.3f)" % ship.wet, ship.wet > 0.0)
			check("...not yet pooled", not ship._puddles.get_child(0).visible)
			ship.wet = 1.0
			wait = 0.2
			step = 3
		3:
			check("soaked through, the rain pools on deck", ship._puddles.get_child(0).visible and ship._puddles.get_child(5).visible)
			finish()
	return false
