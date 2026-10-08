extends SceneTree
## Screenshots of every menu.
## Args: <out_prefix> [psx_preset_index] [window WxH, e.g. 1280x1024]
var t := 0.0
var p
var out := ""
var step := 0
var t0 := 0.0
var screens := ["pause", "options", "controls", "inventory", "inventory_char", "container", "skills", "skills_sword", "skills_fruit",
	"chart", "yard", "shop", "load", "dialogue", "hud"]
var si := 0


func _initialize():
	var a := OS.get_cmdline_user_args()
	out = a[0]
	if a.size() > 1:
		root.get_node("Settings").set_value("video", "psx_preset", int(a[1]))
	if a.size() > 2:
		var wh := a[2].split("x")
		win_size = Vector2i(int(wh[0]), int(wh[1]))
	change_scene_to_file("res://scenes/world/world.tscn")


var win_size := Vector2i.ZERO


func gm():
	return root.get_node("GameMenu")


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
