extends SceneTree
## Inventory overlay screenshots. Args: <out_prefix>
var t := 0.0
var stage := 0
var out := ""
func _initialize():
	out = OS.get_cmdline_user_args()[0]
	change_scene_to_file("res://scenes/world/world.tscn")
func _process(d: float) -> bool:
	t += d
	var gm = root.get_node_or_null("GameMenu")
	match stage:
		0:
			if t > 1.5:
				root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
				for n in root.get_children():
					if n is CharacterCreator: n._finish(true)
				var p = root.get_tree().get_first_node_in_group("player")
				# a few extra items to show off
				p.inventory_component.add_item(ItemDB.get_item("boarding_axe"), 1)
				p.inventory_component.add_item(Gear.make("hands", "gloves", {"gloves": true, "gloves_color": CharacterLook.LEATHER[2]}), 1)
				p.inventory_component.add_item(Gear.make("head", "bandana", {"hat": "bandana", "hat_color": CharacterLook.CLOTH[13]}), 1)
				p.inventory_component.add_item(Gear.make("accessory", "pauldron", {"pauldron": true}, "Ruin-Warden's Pauldron"), 1)
				gm.open("inventory")
				stage = 1; t = 0
		1:
			if t > 1.6:
				root.get_texture().get_image().save_png(out + "_inv.png")
				gm._inventory.show_tab("character")
				stage = 2; t = 0
		2:
			if t > 0.3:
				root.get_texture().get_image().save_png(out + "_char.png")
				print("SAVED"); quit()
	return false
