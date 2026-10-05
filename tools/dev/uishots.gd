extends SceneTree
## Screenshots of every menu at the current window size.
## Args: <out_prefix> [psx_preset_index]
var t := 0.0
var p
var out := ""
var step := 0
var t0 := 0.0
var screens := ["pause", "options", "controls", "inventory", "inventory_char", "skills", "skills_fruit", "load", "dialogue", "hud"]
var si := 0


func _initialize():
	var a := OS.get_cmdline_user_args()
	out = a[0]
	if a.size() > 1:
		root.get_node("Settings").set_value("video", "psx_preset", int(a[1]))
	change_scene_to_file("res://scenes/world/world.tscn")


func gm():
	return root.get_node("GameMenu")


func _process(d: float) -> bool:
	t += d
	match step:
		0:
			if t < 3.0: return false
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
			match s:
				"inventory_char":
					gm().open("inventory")
					var inv = gm()._inventory
					if inv.has_method("show_tab"):
						inv.show_tab("character")
				"skills_fruit":
					gm().open("skills")
					if gm()._skills.has_method("set_tab"):
						gm()._skills.set_tab(1)
				"dialogue":
					root.get_node("Dialogue").say("Odile", ["Welcome to Brinehollow, captain. Mind the smugglers down at the cove, they've been bold of late and the lighthouse keeper swears he saw lights on the water."])
				"hud":
					pass
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
