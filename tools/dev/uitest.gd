extends SceneTree
## The crisp UI (v1.11): at 1280x720 every screen draws on a 640x360 canvas shown at 2x, and each
## one opens and fits it: pause, options, controls, skill map (with a node's tooltip), sea chart,
## yard, a shop (stock, bag, card, tooltip), save slots, the inventory, a dialogue with choices,
## the HUD (skill bar, boss bar, prompt), the emote wheel and the creator.
const TK := preload("res://tools/dev/test_kit.gd")
var t := 0.0
var step := 0
var until := 0
var p
var fails := 0
var screens := ["pause", "options", "controls", "skills", "chart", "yard", "shop", "load"]
var si := 0


func _initialize():
	TK.seed_of(self)
	change_scene_to_file("res://scenes/world/world.tscn")


func check(name: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + name)
	if not cond:
		fails += 1


func gm():
	return root.get_node("GameMenu")


## `c` (its scale included) inside its canvas.
func fits(c: Control) -> bool:
	var vs := c.get_viewport_rect().size
	var r := c.get_global_rect()
	r.size *= c.scale
	return r.position.x >= -0.5 and r.position.y >= -0.5 and r.end.x <= vs.x + 0.5 and r.end.y <= vs.y + 0.5 and c.scale == Vector2.ONE


func crisp(pc: PixelCanvas) -> bool:
	return pc.canvas == Vector2(640, 360) and pc.stretch_shrink == 2


func _process(d: float) -> bool:
	t += d
	if TK.ticking(until):
		return false
	match step:
		0:
			if t < 2.0:
				return false
			root.size = Vector2i(1280, 720)
			p = get_first_node_in_group("player")
			p.progression.level = 8
			p.progression.skill_points = 4
			until = TK.wait_ticks(10)
			step = 1
		1:
			check("the menus' canvas is 640x360 at 2x", crisp(gm()._pc))
			check("the HUD's too", crisp(get_first_node_in_group("hud")._pc))
			check("the dialogue's too", crisp(root.get_node("Dialogue")._box._canvas))
			step = 2
		2:
			if si >= screens.size():
				gm().close()
				step = 4
				return false
			var s: String = screens[si]
			if s == "shop":
				gm().open_shop("vey")
			else:
				gm().open(s)
			until = TK.wait_ticks(8)
			step = 3
		3:
			var s: String = screens[si]
			var c: Control = gm()._screens[s]
			match s:
				"skills":
					check("skill map fills the canvas", c.size == Vector2(640, 360))
					var id := ""
					for nid in SkillTree.nodes().keys():
						if id == "" and c._shown(nid) and SkillTree.nodes()[nid]["kind"] == "passive":
							id = nid
					c._hover = id
					check("a node's tooltip says what it is and whether you can learn it", c._status(id, p.progression)[0] != "" and c._kind_name(SkillTree.get_node_def(id)) != "")
				"shop":
					check("Vey's stall: his stock in slots with prices", c._stock_slots.size() >= c._stock.size() and c._stock_slots[0].count.text == str(c.SHOPS.price_of(c._stock[0][0])))
					c._pick("shop", 0)
					check("...the picked blade's card with a Buy button", c._buy_btn.visible and c._card.get_child_count() > 2)
					check("shop fits the canvas", fits(c._panel))
				_:
					check("%s fits the canvas" % s, fits(c))
			si += 1
			step = 2
		4:
			gm().open("inventory")
			until = TK.wait_ticks(8)
			step = 5
		5:
			var inv = gm()._inventory
			check("inventory canvas 640x360", inv._canvas == Vector2(640, 360))
			check("inventory panel fits", fits(inv._panel))
			gm().close()
			var box = root.get_node("Dialogue")._box
			box.open()
			box.show_line("Nessa", "Sea-gems, captain? Or are you after something else?", [{"text": "Let's trade."}, {"text": "Heard any rumours?"}, {"text": "Another time."}], 1.0)
			box.finish_typing()
			until = TK.wait_ticks(8)
			step = 6
		6:
			var box = root.get_node("Dialogue")._box
			check("dialogue choices are planks", box._choice_labels.size() == 3 and box._choice_labels[0] is Button and box._choice_labels[0].text.begins_with(">"))
			check("dialogue page fits", fits(box._panel) and fits(box._name_panel))
			box.close()
			var hud = get_first_node_in_group("hud")
			hud.show_boss("Grell", 0.5, 1)
			hud._on_prompt_changed("Talk to Odile")
			until = TK.wait_ticks(8)
			step = 7
		7:
			var hud = get_first_node_in_group("hud")
			check("skill bar fits", fits(hud._skill_bar))
			check("boss bar fits", fits(hud._boss_box))
			check("the prompt has its key cap", fits(hud.interact_panel) and (hud._interact_key.get_child(0) as Label).text == "F")
			hud.hide_boss()
			var w = p.emote_wheel
			w._k = 1.0
			w._root.visible = true
			w._layout()
			var inside := crisp(w._canvas)
			for c in w._plates + [w._root.get_node("Centre")]:
				inside = inside and fits(c)
			check("the emote wheel's planks are on a crisp canvas, inside it", inside)
			w._k = 0.0
			w._root.visible = false
			p.open_creator(false)
			until = TK.wait_ticks(10)
			step = 8
		8:
			var cc = root.find_children("*", "CharacterCreator", true, false)
			var pc: PixelCanvas = cc[0].get_child(1) if not cc.is_empty() else null
			check("the creator is on a crisp canvas and fits it", pc != null and crisp(pc) and (pc.ui.get_child(0) as Control).get_combined_minimum_size().x <= 640.0 and (pc.ui.get_child(0) as Control).get_combined_minimum_size().y <= 360.0)
			if not cc.is_empty():
				cc[0]._finish(false)
			print("RESULT ", "OK" if fails == 0 else "FAILED (%d)" % fails)
			quit()
	return false
