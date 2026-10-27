extends SceneTree
## Gear stats (1.24) in the inventory: a purple morion's card against the kettle helm you wear (weight, stats, its
## second stat, the compare), then a corsair piece's card with two of the set on. Args: <out_prefix>
var t := 0.0
var out := ""
var step := 0
var t0 := 0.0
var menu
var helm
var coat


func _initialize():
	out = OS.get_cmdline_user_args()[0]
	change_scene_to_file("res://scenes/world/world.tscn")


func snap(n: String) -> void:
	root.get_texture().get_image().save_png("%s_%s.png" % [out, n])
	print("shot ", n)


func _process(d: float) -> bool:
	t += d
	if t < 2.0 or (step > 0 and t - t0 < 1.0):
		return false
	t0 = t
	var p = get_first_node_in_group("player")
	var gear = load("res://scripts/loot/gear.gd")
	match step:
		0:
			root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
			for c in root.find_children("*", "CharacterCreator", true, false):
				c._finish(true)
			menu = root.get_node("GameMenu")
			p.equipment.equip(gear.make("head", "kettle", {"hat": "kettle"}, "", 0))
			helm = gear.make("head", "morion", {"hat": "morion"}, "", 3, 41)
			p.inventory_component.add_item(helm, 1)
			p.equipment.equip(gear.make("feet", "tall_boots", {"feet": "tall_boots", "feet_color": Color(0.1, 0.09, 0.09)}, "", 1))
			coat = gear.make("coat", "captain", {"coat": "captain", "coat_color": Color(0.36, 0.1, 0.12), "trim_color": Color(0.9, 0.75, 0.3)}, "", 2)
			p.inventory_component.add_item(coat, 1)
			p.inventory_component.add_item(gear.make("head", "tricorn", {"hat": "tricorn", "hat_color": Color(0.1, 0.09, 0.09)}, "", 1), 1)
			p.refresh_look()
			menu.open("inventory")
		1:
			menu._inventory._sel = helm
			menu._inventory._show_details()
		2:
			snap("helm")
			menu._inventory._sel = coat
			menu._inventory._show_details()
		3:
			snap("corsair")
			menu._inventory.show_tab("character")
		4:
			snap("sheet")
			quit()
	step += 1
	return false
