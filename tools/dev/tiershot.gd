extends SceneTree
## Item tiers: a cutlass at every tier (white to black) in the bag, the
## description of a purple one, and Vey's stall. Args: <out_prefix>
var t := 0.0
var out := ""
var step := 0
var t0 := 0.0
var menu
func _initialize():
	out = OS.get_cmdline_user_args()[0]
	change_scene_to_file("res://scenes/world/world.tscn")
func snap(n: String) -> void:
	root.get_texture().get_image().save_png("%s_%s.png" % [out, n])
	print("shot ", n)
func _process(d: float) -> bool:
	t += d
	if t < 2.0 or (step > 0 and t - t0 < 1.0): return false
	t0 = t
	match step:
		0:
			root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
			for c in root.find_children("*", "CharacterCreator", true, false): c._finish(true)
			var p = get_first_node_in_group("player")
			menu = root.get_node("GameMenu")
			var db = load("res://scripts/loot/item_db.gd")
			for tier in range(7):
				p.inventory_component.add_item(db.get_item("cutlass@%d" % tier), 1)
			p.inventory_component.add_item(db.get_item("treasure"), 5)
			p.inventory_component.add_item(db.get_item("gold"), 300)
			menu.open("inventory")
		1:
			var inv = menu._inventory
			for i in range(inv._bag.size()):
				var st = get_first_node_in_group("player").inventory_component.items
				if i < st.size() and st[i].item.id == "cutlass@3":
					inv._select(i)
		2:
			snap("bag")
			menu.close()
			menu.open_shop("vey")
		3:
			snap("vey")
			quit()
	step += 1
	return false
