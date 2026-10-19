extends SceneTree
## Screenshots of every menu.
## Args: <out_prefix> [pixelate 1|0] [window WxH, e.g. 1280x1024, or 0] [only these screens, e.g. emotes,loadouts]
var t := 0.0
var p
var out := ""
var step := 0
var t0 := 0.0
var screens := ["pause", "options", "controls", "inventory", "inventory_char", "container", "skills", "skills_sword", "skills_fruit",
	"skills_tip", "yard", "shop", "shop_tip", "load", "dialogue", "dialogue_choice", "hud", "emotes", "items", "loadouts", "chat"]
var si := 0


func _initialize():
	var a := OS.get_cmdline_user_args()
	out = a[0]
	if a.size() > 1:
		root.get_node("Settings").set_value("video", "pixelate", a[1] != "0")
	if a.size() > 2 and a[2] != "0":
		var wh := a[2].split("x")
		win_size = Vector2i(int(wh[0]), int(wh[1]))
	if a.size() > 3:
		screens = Array(a[3].split(","))
	change_scene_to_file("res://scenes/world/world.tscn")


var win_size := Vector2i.ZERO


func gm():
	return root.get_node("GameMenu")


## The menu canvas's mouse at `at` (canvas pixels) without moving the real cursor.
func hover(at: Vector2) -> void:
	var ev := InputEventMouseMotion.new()
	ev.position = at
	ev.global_position = at
	gm()._pc._vp.push_input(ev, true)


func _process(d: float) -> bool:
	t += d
	match step:
		0:
			if t < 3.0: return false
			if win_size != Vector2i.ZERO:
				DisplayServer.window_set_size(win_size)
				root.size = win_size
			for n in root.find_children("*", "CharacterCreator", true, false): n._finish(true)
			p = root.get_tree().get_first_node_in_group("player")
			p.progression.level = 12
			p.progression.skill_points = 9
			p.power.eat("vine")
			for i in range(3): p.inventory_component.add_item(load("res://resources/items/rum.tres"), 1)
			step = 1
			t0 = t
		1:
			if t - t0 < 0.5: return false
			if si >= screens.size():
				quit()
				return false
			var s: String = screens[si]
			gm().close()
			root.get_node("Dialogue").call("_close") if root.get_node("Dialogue").has_method("_close") and root.get_node("Dialogue").active else null
			root.get_node("Dialogue")._box.close()
			match s:
				"inventory_char":
					gm().open("inventory")
					var inv = gm()._inventory
					if inv.has_method("show_tab"):
						inv.show_tab("character")
				"skills_fruit":
					gm().open("skills")
					gm()._skills.set_tab("fruit")
				"skills_sword":
					gm().open("skills")
					gm()._skills.set_tab("sword")
				"container":
					gm().open_container(root.get_tree().get_first_node_in_group("ship").storage)
				"shop":
					gm().open_shop("nessa")
				"skills_tip":
					gm().open("skills")
					var sm = gm()._skills
					sm.set_tab("sword")
					var id := ""
					for nid in SkillTree.nodes().keys():
						if id == "" and SkillTree.nodes()[nid]["tree"] == "sword" and SkillTree.nodes()[nid]["kind"] == "passive":
							id = nid
					sm._hover = id
					hover(sm._to_screen(SkillTree.get_node_def(id)["pos"]))
				"shop_tip":
					p.inventory_component.add_item(load("res://resources/items/cutlass.tres"), 1)
					gm().open_shop("vey")
					var shop = gm()._shop
					var slot = shop._stock_slots[3]
					shop._pick("shop", 3)
					shop._hover = slot
					hover(slot.get_global_rect().get_center())
				"dialogue_choice":
					var box = root.get_node("Dialogue")._box
					box.open()
					box.show_line("Nessa", "Sea-gems, captain? I pay full price. Or are you after something else?",
						[{"text": "Let's trade."}, {"text": "Heard any rumours?"}, {"text": "Another time."}], 1.0)
					box.finish_typing()
				"dialogue":
					root.get_node("Dialogue").say("Odile", ["Welcome to Brinehollow, captain. Mind the smugglers down at the cove, they've been bold of late and the lighthouse keeper swears he saw lights on the water."])
				"hud":
					pass
				"emotes":
					# the emote wheel held open, pointing at the fourth (Laugh)
					Input.action_press("emote")
					p.emote_wheel._open = true
					p.emote_wheel._pick = 3
					p.emote_wheel._restyle()
				"items":
					p.inventory_component.add_item(load("res://resources/items/biscuit.tres"), 2)
					p.inventory_component.add_item(load("res://resources/items/stew.tres"), 1)
					p.item_wheel._open_now()
					p.item_wheel.point_at(1)
				"loadouts":
					var dg = load("res://resources/items/dagger.tres")
					p.inventory_component.add_item(dg, 2)
					p.loadouts[1] = ["dagger", "dagger"]
					p.loadout_wheel._open_now()
					p.loadout_wheel.point_at(1)
				"chat":
					var net = root.get_node("Net")
					net._all_chat(1, "Land ho! The island off the port bow.")
					net._all_chat(2, "Aye. Bring her round, I'll take the guns.")
					net._all_chat(3, "Wait for me, I'm still up the mast with a very long line of text that wraps")
					p.chat_box.open()
					p.chat_box._line.text = "On my way"
				_:
					gm().open(s)
			step = 2
			t0 = t
		2:
			if t - t0 < 0.6: return false
			var vs: Vector2 = root.get_visible_rect().size
			root.get_texture().get_image().save_png("%s_%02d_%s.png" % [out, si, screens[si]])
			print("shot ", screens[si], " canvas ", vs)
			si += 1
			step = 1
			t0 = t
	return false
