extends SceneTree
## Another captain (a stand-in): F with their name only within 2.5 m and facing them; F opens Trade, Inspect,
## Duel; 2 shows their kit (weapon, worn gear, quick item, level and style); Esc steps back, then closes;
## walking off closes it.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var mate
var menu
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"crew": [{"name": "Stand-in", "at": Vector3(0, 0, -2)}]})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func key(k: Key) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = k
	ev.keycode = k
	ev.pressed = true
	menu._input(ev)


func esc() -> void:
	var ev := InputEventAction.new()
	ev.action = "pause"
	ev.pressed = true
	menu._input(ev)


func meet():
	return mate.get_node_or_null("Meet")


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			mate = stage.crew[0]
			menu = p.get_node("PlayerMenu")
			# their kit: a cutlass, the default outfit, rum as the quick item
			mate.equipped_weapon = ItemDB.get_item("cutlass")
			var gear: Dictionary = Gear.items_from_look(p.appearance)
			for slot in gear.keys():
				if slot != "extra":
					mate.equipment.equip(gear[slot], slot)
			mate.inventory_component.add_item(ItemDB.get_item("rum"), 2)
			mate.inventory_component.quick = "rum"
			p.player_model.rotation.y = 0.0
			until = TK.wait_secs(0.4)
		1:
			var it = p.interaction_component.current_interactable
			check("2 m off, facing them: the prompt names them (%s)" % (it.prompt_text if it else "none"), it != null and it == meet() and it.prompt_text == "Stand-in")
			check("...on the HUD: F Stand-in", stage.hud.interact_panel.visible and stage.hud.interact_label.text == "Stand-in")
			p.player_model.rotation.y = PI
			until = TK.wait_secs(0.3)
		2:
			check("back to them: no prompt", p.interaction_component.current_interactable == null)
			p.player_model.rotation.y = 0.0
			mate.global_position = p.global_position + Vector3(0, 0, -3.0)
			until = TK.wait_secs(0.3)
		3:
			check("3 m off: no prompt", p.interaction_component.current_interactable == null)
			mate.global_position = p.global_position + Vector3(0.4, 0, -2.0)
			until = TK.wait_secs(0.3)
		4:
			check("back in reach: the prompt again", p.interaction_component.current_interactable == meet())
			TK.act("interact")
			until = TK.wait_ticks(3)
		5:
			check("F opens the menu on them", menu.is_open() and menu.target == mate)
			var names: Array = menu.ENTRIES.map(func(e): return menu._buttons[e].text)
			check("...Trade, Inspect, Duel (%s)" % [names], names == ["Trade", "Inspect", "Duel"] and menu._panel.visible)
			key(KEY_2)
			until = TK.wait_ticks(3)
		6:
			var ins = menu._inspect
			check("2: Inspect", ins != null and ins.visible and not menu._panel.visible)
			var it: Dictionary = ins.items if ins else {}
			check("...their cutlass in the main hand", it.get("weapon") != null and it["weapon"].id == "cutlass" and it.get("offhand") == null)
			var worn := 0
			var same := true
			for slot in mate.equipment.slots.keys():
				worn += 1
				same = same and it.get(slot) != null and it[slot].display_name == mate.equipment.slots[slot].display_name
			check("...their %d worn pieces" % worn, worn > 0 and same)
			check("...rum x2 as their quick item", it.get("quick0") != null and it["quick0"].id == "rum" and int(it.get("quick0_n", 0)) == 2)
			check("...level and style (%s)" % ins._line.text, ins._line.text.begins_with("LV 1") and "CUTLASS" in ins._line.text)
			esc()
			until = TK.wait_ticks(2)
		7:
			check("Esc: back to the menu", menu.is_open() and menu._panel.visible and not menu._inspect.visible)
			esc()
			until = TK.wait_ticks(2)
		8:
			check("Esc again: closed (and the pause menu stays shut)", not menu.is_open() and not root.get_node("GameMenu").is_open())
			TK.act("interact")
			until = TK.wait_ticks(3)
		9:
			check("F opens it again", menu.is_open())
			mate.global_position = p.global_position + Vector3(0, 0, -5.0)
			until = TK.wait_ticks(3)
		10:
			check("they walk off: it closes", not menu.is_open())
			return TK.done(fails)
	step += 1
	return false
