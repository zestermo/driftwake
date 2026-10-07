extends SceneTree
## The gameplay loop (step 2b): the ship's storage chest (store, take back,
## saved), resting in the bunk, restocking at the galley, dying (your bag on a
## grave where you fell, worn gear and weapons in hand kept; waking by the
## bunk), the grave saved and loaded, dying again (the old grave sinks), getting
## your things back, and summoning the ship (refused inland; to the water by
## the dock, fading in, sailing up, anchoring).
var t := 0.0
var step := 0
var t0 := 0.0
var fails := 0
var SG
var p
var ship
var gm
var HB
var death_at := Vector3.ZERO
var old_grave


func check(msg: String, c: bool) -> void:
	print(("PASS " if c else "FAIL ") + msg)
	if not c:
		fails += 1


func _initialize():
	SG = load("res://scripts/game/save_game.gd")
	HB = load("res://scripts/ship/hull_builder.gd")
	SG.use_test_dir("user://test_loop")
	for i in range(1, 4):
		SG.delete_slot(i)
	change_scene_to_file("res://scenes/ui/title_screen.tscn")


func wait(secs: float) -> bool:
	return t - t0 >= secs


func next() -> void:
	step += 1
	t0 = t


func grab() -> void:
	p = root.get_tree().get_first_node_in_group("player")
	ship = root.get_tree().get_first_node_in_group("ship")
	gm = root.get_node("GameManager")


func give(id: String, n: int) -> void:
	p.inventory_component.add_item(load("res://resources/items/%s.tres" % id), n)


## On dry land: the village, or (inland) the middle of the island.
func stand_ashore(inland: bool = false) -> void:
	var isl = root.get_node("World/Islands/Brinehollow")
	p.state_machine.force_state("Idle", {})
	p.global_position = isl.to_global(Vector3(-20, 0, 10) if inland else Vector3(0, 0, -62)) + Vector3.UP * 30.0
	var q := PhysicsRayQueryParameters3D.create(p.global_position, p.global_position + Vector3.DOWN * 80.0, 1)
	var hit: Dictionary = p.get_world_3d().direct_space_state.intersect_ray(q)
	p.global_position = (hit["position"] as Vector3) + Vector3.UP * 0.2
	p.velocity = Vector3.ZERO
	p.reset_physics_interpolation()


func _process(d: float) -> bool:
	t += d
	if t > 150.0:
		check("timed out at step %d" % step, false)
		print("RESULT FAILED (%d)" % fails)
		quit()
		return true
	match step:
		0:
			if not wait(1.0): return false
			var ts = root.get_tree().get_first_node_in_group("title_screen")
			ts._start(1, true)
			next()
		1:
			if not wait(3.0): return false
			grab()
			for c in root.find_children("*", "CharacterCreator", true, false): c._finish(true)
			p.health_component.max_health = 500.0
			p.health_component.current_health = 500.0
			# --- storage
			give("treasure", 2)
			give("gold", 30)
			var store = ship.storage
			check("the storage chest is in the cabin", HB.in_cabin(ship.to_local(store.global_position)))
			store.store(p, p.inventory_component.find_index("treasure"), -1)
			check("treasure goes into the ship's storage", p.inventory_component.count("treasure") == 0 and gm.stored_count("treasure") == 2)
			store.store(p, p.inventory_component.find_index("gold"), 20)
			check("...part of a stack too (20 of 30 gold)", p.inventory_component.count("gold") == 10 and gm.stored_count("gold") == 20)
			store.take(store.find_stack(load("res://resources/items/gold.tres")), p, 5)
			check("taking some back out (5 gold)", p.inventory_component.count("gold") == 15 and gm.stored_count("gold") == 15)
			check("an empty chest stays (it's the ship's)", is_instance_valid(store) and store.persistent)
			# --- the bunk
			p.health_component.current_health = 40.0
			var msg: String = gm.rest(p)
			check("resting in the bunk: back to full (%s)" % msg, p.health_component.current_health == p.health_component.max_health)
			# --- the galley
			var inv = p.inventory_component
			while inv.count("rum") > 0:
				inv.take_amount(inv.find_index("rum"), 1)
			inv.assign_hotbar(0, "rum")
			msg = gm.restock(p)
			check("the galley restocks the quick-slot rum to %d (%s)" % [gm.RESTOCK_CAP, msg], inv.count("rum") == gm.RESTOCK_CAP)
			msg = gm.restock(p)
			check("...and not past it (%s)" % msg, inv.count("rum") == gm.RESTOCK_CAP and msg.contains("full"))
			# --- dying ashore
			give("pistol", 1)
			stand_ashore()
			death_at = p.global_position
			set_meta("worn", p.equipment.slots.size())
			next()
		2:
			if not wait(0.5): return false
			p.health_component.take_damage(99999.0)
			next()
		3:
			if not wait(0.5): return false
			var g = gm.grave
			check("dying leaves a grave where you fell", g != null and is_instance_valid(g) and g.global_position.distance_to(death_at) < 2.5)
			var held: bool = p.equipped_weapon != null and p.inventory_component.count(p.equipped_weapon.id) == 1
			check("...your bag on it (gold, rum, the spare pistol)", g != null and g.find_stack(load("res://resources/items/pistol.tres")) >= 0 and g.find_stack(load("res://resources/items/gold.tres")) >= 0)
			check("...the weapon in your hand stays with you", held)
			check("...and what you wear (%d pieces)" % p.equipment.slots.size(), p.equipment.slots.size() == int(get_meta("worn")))
			check("...the storage keeps its things (15 gold, 2 treasure)", gm.stored_count("gold") == 15 and gm.stored_count("treasure") == 2)
			next()
		4:
			if not wait(3.5): return false
			check("you wake in the cabin by the bunk", HB.in_cabin(ship.to_local(p.global_position)) and p.health_component.current_health > 0.0)
			# --- save and load: the storage and the grave come back
			check("saved", SG.save(p))
			root.get_node("GameMenu")._load_slot(1)
			next()
		5:
			if not wait(3.0): return false
			grab()
			check("loaded: the storage is as it was (15 gold, 2 treasure)", gm.stored_count("gold") == 15 and gm.stored_count("treasure") == 2)
			check("...the chest holds it", ship.storage.find_stack(load("res://resources/items/treasure.tres")) >= 0)
			var g = gm.grave
			check("...your grave is still there, still holding your things", g != null and is_instance_valid(g) and g.global_position.distance_to(death_at) < 2.5 and g.find_stack(load("res://resources/items/pistol.tres")) >= 0)
			# --- dying again before you get back to it
			old_grave = g
			p.health_component.max_health = 500.0
			give("biscuit", 1)
			stand_ashore()
			p.global_position += Vector3(4, 0, 0)
			p.reset_physics_interpolation()
			next()
		6:
			if not wait(0.5): return false
			p.health_component.take_damage(99999.0)
			next()
		7:
			if not wait(0.6): return false
			check("dying again: the old grave shakes and sinks away", is_instance_valid(old_grave) and not old_grave.interactable.enabled)
			check("...a new grave takes its place", gm.grave != null and gm.grave != old_grave)
			next()
		8:
			if not wait(3.6): return false
			check("...the old one is gone (with what it held)", not is_instance_valid(old_grave))
			# --- getting it back
			var g = gm.grave
			g.take_all(p)
			check("taking everything off the grave: it's gone, your things are back", gm.grave == null and p.inventory_component.count("biscuit") == 1)
			# --- summoning: refused inland, then from the end of the dock
			ship.place(ship.global_position + Vector3(260, 0, 260), 0.0)
			stand_ashore(true)
			p._summon_cd = 0.0
			var msg: String = p.try_summon()
			check("inland: no water near enough (%s)" % msg, msg.contains("Cannot summon"))
			var isl = root.get_node("World/Islands/Brinehollow")
			var dock_end: Vector3 = isl.to_global(Vector3(isl._dock_point(isl.DOCK_LENGTH).x, isl.DOCK_DECK_Y + 0.3, isl._dock_point(isl.DOCK_LENGTH).y))
			p.global_position = dock_end
			p.reset_physics_interpolation()
			next()
		9:
			if not wait(0.5): return false
			var msg: String = p.try_summon()
			check("on the dock: she's coming (%s)" % msg, msg.contains("coming"))
			check("...fading in (dissolving surfaces: %d)" % ship._faded.size(), ship._faded.size() > 20 and ship.summoning())
			check("...and can't be called again at once", p.try_summon().contains("yet"))
			next()
		10:
			# (a moving body's new place shows from the next physics step)
			if not wait(0.2): return false
			check("...she appears near you (%.0f m off)" % ship.global_position.distance_to(p.global_position), ship.global_position.distance_to(p.global_position) < 80.0)
			set_meta("d0", Vector2(ship.global_position.x - p.global_position.x, ship.global_position.z - p.global_position.z).length())
			next()
		11:
			if ship.summoning() and not wait(30.0):
				return false
			var d1 := Vector2(ship.global_position.x - p.global_position.x, ship.global_position.z - p.global_position.z).length()
			print("   summoned: %.0f m off -> %.0f m off, anchored %s, after %.1f s" % [get_meta("d0"), d1, ship.anchored, t - t0])
			check("she sails in and anchors near you", ship.anchored and d1 < float(get_meta("d0")) and d1 < 75.0)
			check("...solid again (her own materials back)", ship._faded.is_empty())
			for i in range(1, 4):
				SG.delete_slot(i)
			print("RESULT OK" if fails == 0 else "RESULT FAILED (%d)" % fails)
			quit()
	return false
