extends SceneTree
## Gear / paper doll / character sheet / abilities; from the retired r7test: inventory drag and drop (move,
## merge, equip, quick slots, drop on the ground), chests open a loot window (take one, take all, store),
## pickup feed, interaction prompt clears after pickup, wolf stance poses, PSX default preset.
var t := 0.0
var saw := {}
var step := 0
var wait := 0.0
var p
var gm
var fails := 0
func _initialize(): load("res://tools/dev/test_kit.gd").seed_of(self); change_scene_to_file("res://scenes/world/world.tscn")
func act(a: String) -> void:
	var e := InputEventAction.new(); e.action = a; e.pressed = true; Input.parse_input_event(e)
	var e2 := InputEventAction.new(); e2.action = a; e2.pressed = false; Input.parse_input_event(e2)
func check(n: String, c: bool) -> void:
	print(("PASS " if c else "FAIL ") + n); if not c: fails += 1
func inv():
	return p.inventory_component
func bag_index(it) -> int:
	var items = p.inventory_component.items
	for i in range(items.size()):
		if items[i].item == it: return i
	return -1
func _process(d: float) -> bool:
	t += d
	if wait > 0.0:
		wait -= d
		return false
	match step:
		0:
			if t < 1.0: return false
			p = root.get_tree().get_first_node_in_group("player")
			gm = root.get_node("GameMenu")
			var lk: Dictionary = p.body_model.look
			check("starting outfit is worn as gear (legs %s)" % str(p.equipment.get_item("legs")), p.equipment.get_item("legs") != null)
			var comp: Dictionary = Gear.compose(p.appearance, p.equipment.slots)
			var same := true
			for k in ["hat", "top", "coat", "legs", "feet", "belt", "coat_color", "legs_color"]:
				if str(comp.get(k)) != str(lk.get(k)): same = false
			check("worn gear reproduces the look", same)
			check("gear icons generated", p.equipment.get_item("legs").icon != null)
			check("defense from gear (%d)" % int(p.defense()), p.defense() > 0.0)
			check("double jump locked by default", not p.has_ability("double_jump") and p.max_jumps == 1)
			act("jump"); wait = 0.25; step = 1
		1:
			act("jump"); wait = 0.08; step = 2
		2:
			check("no double jump while locked", p.body_model.current_action() != "double_jump")
			wait = 1.2; step = 3
		3:
			p.set_ability("double_jump", true)
			check("unlocking gives a second jump", p.max_jumps == 2)
			var gloves = Gear.make("hands", "gloves", {"gloves": true, "gloves_color": CharacterLook.LEATHER[2]})
			p.inventory_component.add_item(gloves, 1)
			set_meta("gloves", gloves)
			var band = Gear.make("head", "bandana", {"hat": "bandana", "hat_color": CharacterLook.CLOTH[13]})
			p.inventory_component.add_item(band, 1)
			set_meta("band", band)
			check("gear isn't the quick item", p.inventory_component.quick != gloves.id)
			gm.open("inventory")
			wait = 0.8; step = 4
		4:
			check("inventory pauses the game", root.get_tree().paused)
			check("camera swings round to show the captain", gm._inventory._rig() != null and gm._inventory._rig().is_showcasing())
			check("world isn't dimmed behind the inventory", not gm._dim.visible)
			var gloves = get_meta("gloves")
			var d0: float = p.defense()
			gm._inventory._use(bag_index(gloves))
			check("click wears gloves", p.equipment.get_item("hands") == gloves and bool(p.body_model.look.get("gloves")))
			check("worn gloves leave the bag", bag_index(gloves) == -1)
			check("defense goes up (%.0f -> %.0f)" % [d0, p.defense()], p.defense() > d0)
			var old_hat = p.equipment.get_item("head")
			var band = get_meta("band")
			var bi := bag_index(band)
			gm._inventory._use(bi)
			check("bandana replaces the hat", p.equipment.get_item("head") == band and p.body_model.look.get("hat") == "bandana")
			if old_hat:
				check("old hat goes back into the bag slot", bag_index(old_hat) == bi)
			gm._inventory._on_doll_pressed("hands")
			check("click a worn slot to take it off", p.equipment.get_item("hands") == null and not bool(p.body_model.look.get("gloves")) and bag_index(gloves) >= 0)
			var scr = gm._inventory
			var shown := func(it) -> bool: return scr._bag.any(func(s): return s.item == it)
			check("worn gloves back in the bag grid", shown.call(gloves))
			var w = p.equipped_weapon
			check("the weapon in hand isn't in the bag grid (%s)" % str(w.display_name if w else null), w != null and not shown.call(w) and scr._weapon_slot.item == w)
			check("...but it's still carried (saves, grave)", p.inventory_component.count(w.id) >= 1)
			scr._put_away(false)
			check("putting it away puts it back in the bag", p.equipped_weapon == null and shown.call(w) and scr._weapon_slot.item == null)
			scr._use(bag_index(w))
			check("equipping it again takes it out of the bag grid", p.equipped_weapon == w and not shown.call(w))
			var rum = ItemDB.get_item("rum")
			p.inventory_component.add_item(rum, 2)
			p.inventory_component.select_quick("rum")
			scr.refresh()
			check("the quick item shows in its slot, not the bag", not shown.call(rum) and scr._quick[0].item == rum)
			scr._clear_quick()
			check("clearing the quick item puts it back in the bag", shown.call(rum) and p.inventory_component.quick == "")
			p.inventory_component.select_quick("rum")
			scr.refresh()
			check("held stacks take no bag space (%d of %d stacks)" % [p.inventory_component.used_slots(), p.inventory_component.items.size()],
				p.inventory_component.used_slots() == scr._view.size() and p.inventory_component.used_slots() <= p.inventory_component.items.size() - 2)
			var blade = ItemDB.get_item("katana")
			p.inventory_component.add_item(blade, 1)
			scr.refresh()
			var cell = scr._bag[scr._view.find(bag_index(blade))]
			scr._on_hover(cell)
			var txt := ""
			for l in scr._tip_box.find_children("*", "Label", true, false):
				txt += l.text + " | "
			var dmg := str(int(round(scr.weapon_stats(blade)["damage"])))
			check("tooltip shows the item's name and stats (%s)" % txt, txt.contains(blade.display_name) and txt.contains("DAMAGE | " + dmg) and txt.contains("SPEED") and txt.contains("WORTH"))
			check("...and compares it with the weapon in hand", scr._tip_box.find_children("*", "TextureRect", true, false).size() > 0)
			p.inventory_component.remove_item(blade, 1)
			gm._inventory.show_tab("character")
			check("character sheet filled (%d rows)" % gm._inventory._sheet.get_child_count(), gm._inventory._sheet.get_child_count() > 12)
			p.body_model.look_weight = 0.0
			wait = 0.2; step = 5
		5:
			gm.close()
			wait = 1.0; step = 6
		6:
			check("closing unpauses and the camera returns", not root.get_tree().paused and not gm._inventory._rig().is_showcasing())
			var hd := HitData.new(); hd.damage = 40.0
			var h0: float = p.health_component.current_health
			p._on_hit_received(hd, null)
			var taken: float = h0 - p.health_component.current_health
			check("armor soaks damage (took %.1f of 40)" % taken, taken < 40.0 and taken > 20.0)
			gm.open("options")
			wait = 0.3; step = 7
		7:
			var px: Button = gm._screens["options"].find_child("pixelate", true, false)
			var settings = root.get_node("Settings")
			var v0 := bool(settings.get_value("video", "pixelate"))
			px.pressed.emit()
			check("the Pixelation toggle flips it (%s)" % px.text, bool(settings.get_value("video", "pixelate")) == not v0)
			px.pressed.emit()
			check("...and back (%s)" % px.text, bool(settings.get_value("video", "pixelate")) == v0)
			gm.close()
			wait = 0.3; step = 20
		20:
			check("PSX default: pixelated on the sharper 960x540 grid", root.get_node("Settings").DEFAULTS["video"]["pixelate"] == true and root.get_node("PSX").GRID == Vector2i(960, 540))
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
			gm.open("inventory")
			var scr = gm._inventory
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
			inv().select_quick("")
			check("consumables can go on the quick slot", scr._can_drop_on({"src": "quick", "idx": 0}, {"src": "bag", "idx": ri, "item": rum}))
			check("weapons can't", not scr._can_drop_on({"src": "quick", "idx": 0}, {"src": "bag", "idx": pi, "item": pistol}))
			scr._drop_on({"src": "quick", "idx": 0}, {"src": "bag", "idx": ri, "item": rum})
			check("rum is the quick item", inv().quick == "rum")
			scr._drop_on({"src": "bag", "idx": 0}, {"src": "quick", "idx": 0, "item": rum})
			check("dragging it off the quick slot clears it", inv().quick == "")
			# --- drop the pistol on the ground (it's equipped: put away first)
			pi = -1
			for i in range(inv().items.size()):
				if inv().items[i].item == pistol:
					pi = i
			saw["bags0"] = current_scene.find_children("Drop_*", "", false, false).size()
			scr._drop_world(Vector2.ZERO, {"src": "bag", "idx": pi, "item": pistol})
			check("dropping it leaves the bag", inv().count("pistol") == 0)
			check("...and you stop holding it", p.equipped_weapon != pistol)
			gm.close()
			wait = 0.2
			step += 1
		21:
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
		22:
			var hud = get_first_node_in_group("hud")
			check("pick-up prompt shows next to it", hud.interact_panel.visible)
			p.interaction_component.current_interactable.interact(p)
			wait = 0.15
			step += 1
		23:
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
			# (what's in it as it is: the economy's roll is t/economy's)
			bag.rolled = true
			current_scene.add_child(bag)
			bag.global_position = p.global_position + Vector3(1.5, 0, 0)
			saw["chest"] = bag
			gm.open_container(bag)
			var scr = gm._inventory
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
		24:
			check("take all empties it", not is_instance_valid(saw["chest"]))
			check("...and it's remembered as opened", root.get_node("GameManager").opened.has("test_chest"))
			check("...and the window closed", not gm.is_open())
			# --- the wolf: low crouch with the claws out
			p.set_hybrid(true)
			p.velocity = Vector3.ZERO
			wait = 0.6
			step += 1
		25:
			var h = p.body_model
			check("wolf crouch: hips drop", h.pivot.position.y < h.hip_y - 0.15)
			check("...arms held out at the sides", absf(h.arm_l.rotation.z) > 0.5 and absf(h.arm_r.rotation.z) > 0.5)
			h.play("claw_r", 0.44)
			wait = 0.2
			step += 1
		26:
			var h = p.body_model
			check("claw rake lunges low and forward", h.pivot.rotation.x < -0.1)
			p.set_hybrid(false)
			print("RESULT ", "OK" if fails == 0 else "FAILED (%d)" % fails)
			quit()

	return false
