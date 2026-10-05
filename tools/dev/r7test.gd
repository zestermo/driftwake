extends SceneTree
## Round 7: inventory drag and drop (move, merge, equip, quick slots, drop
## on the ground), chests open a loot window (take one, take all, store),
## pickup feed, interaction prompt clears after pickup, wolf stance poses,
## PSX default preset.
var t := 0.0
var step := 0
var wait := 0.0
var p
var fails := 0
var saw := {}


func _initialize():
	change_scene_to_file("res://scenes/world/world.tscn")


func check(name: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + name)
	if not cond:
		fails += 1


func gm():
	return root.get_node("GameMenu")


func inv():
	return p.inventory_component


func item(id: String):
	return root.get_node("/root/GameManager").get_script() and load("res://resources/items/%s.tres" % id)


func _process(d: float) -> bool:
	t += d
	if wait > 0.0:
		wait -= d
		return false
	match step:
		0:
			if t < 1.5:
				return false
			p = get_first_node_in_group("player")
			check("PSX default is the sharper 960x540 grid", int(root.get_node("Settings").DEFAULTS["video"]["psx_preset"]) == 4)
			var rum = load("res://resources/items/rum.tres")
			var gold = load("res://resources/items/gold.tres")
			var pistol = load("res://resources/items/pistol.tres")
			inv().add_item(pistol, 1)
			inv().add_item(gold, 5)
			check("pickup feed shows rows", root.get_tree().get_first_node_in_group("hud")._feed.get_child_count() >= 1)
			# --- move / merge
			var n0: int = inv().items.size()
			var a = inv().items[0].item
			var b = inv().items[1].item
			inv().move_stack(0, 1)
			check("drag a stack onto another: they swap", inv().items[0].item == b and inv().items[1].item == a)
			inv().move_stack(0, 99)
			check("drag onto an empty slot: moves to the end", inv().items[n0 - 1].item == b and inv().items.size() == n0)
			# --- the inventory screen's drop targets
			gm().open("inventory")
			var scr = gm()._inventory
			var pi := -1
			for i in range(inv().items.size()):
				if inv().items[i].item == pistol:
					pi = i
			scr._drop_on({"src": "weapon"}, {"src": "bag", "idx": pi, "item": pistol})
			check("drop a bag weapon on the weapon slot: equipped", p.equipped_weapon == pistol)
			var ri := -1
			for i in range(inv().items.size()):
				if inv().items[i].item == rum:
					ri = i
			inv().clear_hotbar_slot(0)
			inv().clear_hotbar_slot(1)
			inv().clear_hotbar_slot(2)
			check("consumables can go on a quick slot", scr._can_drop_on({"src": "quick", "idx": 1}, {"src": "bag", "idx": ri, "item": rum}))
			check("weapons can't", not scr._can_drop_on({"src": "quick", "idx": 1}, {"src": "bag", "idx": pi, "item": pistol}))
			scr._drop_on({"src": "quick", "idx": 1}, {"src": "bag", "idx": ri, "item": rum})
			check("rum on quick slot 6", inv().hotbar[1] == "rum")
			scr._drop_on({"src": "bag", "idx": 0}, {"src": "quick", "idx": 1, "item": rum})
			check("dragging it off the quick slot clears it", inv().hotbar[1] == "")
			# --- drop the pistol on the ground (it's equipped: put away first)
			pi = -1
			for i in range(inv().items.size()):
				if inv().items[i].item == pistol:
					pi = i
			saw["bags0"] = current_scene.find_children("Drop_*", "", false, false).size()
			scr._drop_world(Vector2.ZERO, {"src": "bag", "idx": pi, "item": pistol})
			check("dropping it leaves the bag", inv().count("pistol") == 0)
			check("...and you stop holding it", p.equipped_weapon != pistol)
			gm().close()
			wait = 0.2
			step += 1
		1:
			var drops: Array = current_scene.find_children("Drop_*", "", false, false)
			check("a bag lies on the ground", drops.size() == int(saw["bags0"]) + 1)
			var bag = drops[-1]
			check("...with the pistol in it", bag.contents.size() == 1 and bag.contents[0].item.id == "pistol")
			check("...in front of you", bag.global_position.distance_to(p.global_position) < 2.5)
			# walk up: the prompt shows; pick it up: the prompt goes away
			p.global_position = bag.global_position + Vector3(0, 0.3, 0.4)
			p.reset_physics_interpolation()
			saw["bag"] = bag
			wait = 0.4
			step += 1
		2:
			var hud = get_first_node_in_group("hud")
			check("pick-up prompt shows next to it", hud.interact_panel.visible)
			p.interaction_component.current_interactable.interact(p)
			wait = 0.15
			step += 1
		3:
			var hud = get_first_node_in_group("hud")
			check("picked it back up", inv().count("pistol") == 1)
			check("the prompt goes away right after", not hud.interact_panel.visible)
			# --- a chest with several things: the loot window
			var bag = (load("res://scenes/loot/loot_bag.tscn") as PackedScene).instantiate()
			var items: Array[ItemStack] = []
			for e in [["gold", 4], ["treasure", 2], ["rum", 1]]:
				var st := ItemStack.new()
				st.item = load("res://resources/items/%s.tres" % e[0])
				st.quantity = e[1]
				items.append(st)
			bag.setup(items, false)
			bag.save_id = "test_chest"
			current_scene.add_child(bag)
			bag.global_position = p.global_position + Vector3(1.5, 0, 0)
			saw["chest"] = bag
			gm().open_container(bag)
			var scr = gm()._inventory
			check("opening a chest shows its contents beside the bag", scr.has_container() and scr._loot_panel.visible and not scr._doll_nodes[0].visible)
			var g0: int = inv().count("gold")
			bag.take(0, p, 1)
			check("take one", inv().count("gold") == g0 + 1 and bag.contents[0].quantity == 3)
			var ri := -1
			for i in range(inv().items.size()):
				if inv().items[i].item.id == "rum":
					ri = i
			var r0: int = inv().count("rum")
			scr._drop_on({"src": "loot"}, {"src": "bag", "idx": ri, "item": inv().items[ri].item})
			check("drag a bag item into the chest: stored", inv().count("rum") == 0 and bag.contents.any(func(s): return s.item.id == "rum" and s.quantity == r0 + 1))
			scr.take_all()
			wait = 0.2
			step += 1
		4:
			check("take all empties it", not is_instance_valid(saw["chest"]))
			check("...and it's remembered as opened", root.get_node("GameManager").opened.has("test_chest"))
			check("...and the window closed", not gm().is_open())
			# --- the wolf: low crouch with the claws out
			p.set_hybrid(true)
			p.velocity = Vector3.ZERO
			wait = 0.6
			step += 1
		5:
			var h = p.body_model
			check("wolf crouch: hips drop", h.pivot.position.y < h.hip_y - 0.15)
			check("...arms held out at the sides", absf(h.arm_l.rotation.z) > 0.5 and absf(h.arm_r.rotation.z) > 0.5)
			h.play("claw_r", 0.44)
			wait = 0.2
			step += 1
		6:
			var h = p.body_model
			check("claw rake lunges low and forward", h.pivot.rotation.x < -0.1)
			p.set_hybrid(false)
			print("RESULT ", "OK" if fails == 0 else "FAILED (%d)" % fails)
			quit()
	return false
