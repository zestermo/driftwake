extends SceneTree
## Gear / paper doll / character sheet / abilities.
var t := 0.0
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
			check("no double jump while locked", p.body_model.current_action() != "flip")
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
			check("gear doesn't land on the hotbar", not p.inventory_component.hotbar.has(gloves.id))
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
			p.inventory_component.assign_hotbar(0, "rum")
			scr.refresh()
			check("a quick-slot item shows in its slot, not the bag", not shown.call(rum) and scr._quick[0].item == rum)
			scr._clear_quick(0)
			check("clearing the quick slot puts it back in the bag", shown.call(rum) and p.inventory_component.hotbar[0] == "")
			p.inventory_component.assign_hotbar(0, "rum")
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
			var st: Button = gm._screens["options"].find_child("psx_preset", true, false)
			var settings = root.get_node("Settings")
			var n: int = root.get_node("PSX").PRESETS.size()
			var v0 := int(settings.get_value("video", "psx_preset"))
			var click := InputEventMouseButton.new()
			click.button_index = MOUSE_BUTTON_LEFT
			click.pressed = true
			click.position = Vector2(2, st.size.y * 0.5)
			st.gui_input.emit(click)
			check("selector's left half steps back (%d -> %d of %d)" % [v0, int(settings.get_value("video", "psx_preset")), n],
				int(settings.get_value("video", "psx_preset")) == posmod(v0 - 1, n))
			var left := InputEventAction.new()
			left.action = "ui_left"
			left.pressed = true
			st.gui_input.emit(left)
			check("left on a keyboard / pad steps back again", int(settings.get_value("video", "psx_preset")) == posmod(v0 - 2, n))
			click.position.x = st.size.x - 2.0
			st.gui_input.emit(click)
			st.gui_input.emit(click)
			check("right half steps forward to where it was (%s)" % st.text, int(settings.get_value("video", "psx_preset")) == v0)
			gm.close()
			print("RESULT fails=", fails); quit()
	return false
