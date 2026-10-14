extends SceneTree
## The HUD with everything up: stamina spent, a drink on the shared cooldown, a boss bar, the
## interact prompt, the loot feed, a toast, the island banner. Args: <out.png> [WxH]
var t := 0.0
var step := 0


func _initialize():
	var a := OS.get_cmdline_user_args()
	if a.size() > 1:
		var wh := a[1].split("x")
		root.size = Vector2i(int(wh[0]), int(wh[1]))
	change_scene_to_file("res://scenes/world/world.tscn")


func _process(d: float) -> bool:
	t += d
	if step == 0 and t > 3.0:
		step = 1
		var a := OS.get_cmdline_user_args()
		if a.size() > 1:
			var wh := a[1].split("x")
			DisplayServer.window_set_size(Vector2i(int(wh[0]), int(wh[1])))
		var p = root.get_tree().get_first_node_in_group("player")
		var hud = root.get_tree().get_first_node_in_group("hud")
		p.spend_stamina(45.0)
		p.inventory_component.add_item(load("res://resources/items/tonic.tres"), 2)
		p.inventory_component.assign_hotbar(1, "tonic")
		p.heal_cd = 5.2
		p.health_component.current_health = 61.0
		hud.show_boss("Grell the Tide-Breaker", 0.55, 2)
		hud._on_prompt_changed("Talk to Odile")
		hud.show_toast("+30 health")
		hud.show_banner("Brinehollow", "A quiet fishing village")
		hud._feed_add(load("res://resources/items/gold.tres"), 25)
		hud._feed_add(load("res://resources/items/rum.tres"), 2)
	if step == 1 and t > 5.2:
		step = 2
		root.get_texture().get_image().save_png(OS.get_cmdline_user_args()[0])
		print("SAVED")
		quit()
	return false
