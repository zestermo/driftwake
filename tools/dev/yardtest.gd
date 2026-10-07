extends SceneTree
## The shipwright: Tackett by the dock opens his yard; refits cost gold (refused
## when short) and change the ship (iron straps + 40% hull, a third pair of guns,
## a bigger, faster sail, a sharper rudder); paint, sails, flag and figurehead
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
			check("a plain sloop to start: 4 guns, 400 hull, no figurehead", ship.cannons.size() == 4 and ship.max_hull == 400.0 and ship._figure_node.get_child_count() == 0 and not ship._armour_node.visible)
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
			check("no gold, no refit", not gm.ship_kit["armour"] and ship.max_hull == 400.0)
			p.inventory_component.add_item(load("res://resources/items/gold.tres"), 1000)
			yard.buy("armour")
			print("   gold %d, hull %.0f / %.0f" % [gold(), ship.hull, ship.max_hull])
			check("iron straps: 220 gold, 40% more hull (topped up), straps on her sides", gold() == 780 and ship.max_hull == 560.0 and ship.hull == 560.0 and ship._armour_node.visible)
			yard.buy("armour")
			check("...and only once", gold() == 780)
			yard.buy("guns")
			check("a third pair of guns aft", ship.cannons.size() == 6 and ship.side_cannons(1.0).size() == 3 and gold() == 600)
			yard.buy("sails")
			check("a larger sail: faster, and it shows", ship._top_k > 1.1 and ship._rig.scale.x > 1.1)
			yard.buy("rudder")
			check("a balanced rudder: sharper turns", ship._turn_k > 1.2 and gold() == 330)
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
			check("looks are free", gold() == 330)
			for i in range(KIT.FIGURES.size()):
				yard.cycle("figure")
			check("every figurehead builds (back to the mermaid)", ship._figure_node.get_child_count() == 1 and gm.ship_kit["figure"] == 1)
			menu.close()
			# saved with the purchase; a fresh kit is replaced by the saved one on load
			gm.ship_kit = KIT.fresh()
			SG.load_into(p)
			check("the kit is saved and loaded back", gm.ship_kit["armour"] and gm.ship_kit["guns"] and gm.ship_kit["rudder"] and gm.ship_kit["figure"] == 1 and gm.ship_kit["emblem"] == 1)
			check("...and on her after the load", ship.cannons.size() == 6 and ship.max_hull == 560.0)
			# --- sea polish: shallows, wake, rain on deck
			var oc = root.get_node("Ocean")
			var fine: Image = oc.shoal_fine.get_image()
			var coarse: Image = oc.shoal_map.get_image()
			check("the shallows are baked: Brinehollow's middle is dry, the open sea deep", oc.fine_rect.w == 1.0 and oc.shoal_rect.w == 1.0
				and fine.get_pixel(fine.get_width() / 2, fine.get_height() / 2).r < 0.05 and coarse.get_pixel(2, 2).r > 0.95)
			var sc: Vector2 = root.get_node("World/Islands").starter_center
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
