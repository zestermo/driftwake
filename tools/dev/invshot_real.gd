extends SceneTree
## Inventory screenshots: at rest, hovering a bag weapon (tooltip), dragging it, the
## character tab and a chest's loot window. Args: <out_prefix> [window WxH, e.g. 1920x1080]
var t := 0.0
var stage := 0
var out := ""
var win := Vector2i.ZERO
var gm
var inv
var p
var cell


func _initialize():
	var a := OS.get_cmdline_user_args()
	out = a[0]
	if a.size() > 1:
		var wh := a[1].split("x")
		win = Vector2i(int(wh[0]), int(wh[1]))
	change_scene_to_file("res://scenes/world/world.tscn")


func snap(n: String) -> void:
	root.get_texture().get_image().save_png("%s_%s.png" % [out, n])
	print("shot ", n, " window ", root.size, " canvas ", inv._canvas)


## A slot's centre in window pixels (the inventory's canvas is drawn k times larger from the corner).
func px(s: Control) -> Vector2:
	var k: float = float(root.size.y) / inv._canvas.y
	return ((s.global_position + s.size * 0.5) * floorf(k)).round()


var last := Vector2.ZERO


func mouse(at: Vector2, button := MOUSE_BUTTON_NONE, pressed := false) -> void:
	if button == MOUSE_BUTTON_NONE:
		var e := InputEventMouseMotion.new()
		e.position = at
		e.global_position = at
		e.relative = at - last
		last = at
		e.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		Input.parse_input_event(e)
	else:
		var b := InputEventMouseButton.new()
		b.position = at
		b.global_position = at
		b.button_index = button
		b.pressed = pressed
		b.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		Input.parse_input_event(b)


func _process(d: float) -> bool:
	t += d
	match stage:
		0:
			if t < 2.0:
				return false
			if win != Vector2i.ZERO:
				DisplayServer.window_set_size(win)
				root.size = win
			for n in root.find_children("*", "CharacterCreator", true, false):
				n._finish(true)
			p = root.get_tree().get_first_node_in_group("player")
			gm = root.get_node("GameMenu")
			inv = gm._inventory
			var bag = p.inventory_component
			bag.add_item(ItemDB.get_item("boarding_axe@2"), 1)
			bag.add_item(ItemDB.get_item("dagger@3"), 1)
			bag.add_item(Gear.make("hands", "gloves", {"gloves": true, "gloves_color": CharacterLook.LEATHER[2]}), 1)
			bag.add_item(Gear.make("head", "bandana", {"hat": "bandana", "hat_color": CharacterLook.CLOTH[13]}, "Red Bandana", 1), 1)
			bag.add_item(Gear.make("accessory", "pauldron", {"pauldron": true}, "Ruin-Warden's Pauldron", 4), 1)
			bag.add_item(ItemDB.get_item("rum"), 3)
			bag.add_item(ItemDB.get_item("gold"), 140)
			bag.add_item(ItemDB.get_item("treasure"), 2)
			gm.open("inventory")
			stage = 1; t = 0
		1:
			if t < 1.4:
				return false
			snap("rest")
			for b in inv._bag:
				if b.item and b.item.is_weapon() and cell == null:
					cell = b
			mouse(px(cell))
			stage = 2; t = 0
		2:
			if t < 0.6:
				return false
			snap("tooltip")
			mouse(px(cell), MOUSE_BUTTON_LEFT, true)
			stage = 3; t = 0
		3:
			if t < 0.1:
				return false
			for i in range(1, 9):
				mouse(px(cell) + Vector2(i * 14, -i * 10), MOUSE_BUTTON_NONE, true)
			stage = 4; t = 0
		4:
			if t < 0.4:
				return false
			snap("drag")
			mouse(px(cell), MOUSE_BUTTON_NONE, true)
			mouse(px(cell), MOUSE_BUTTON_LEFT, false)
			stage = 5; t = 0
		5:
			if t < 0.3:
				return false
			inv.show_tab("character")
			stage = 6; t = 0
		6:
			if t < 0.4:
				return false
			snap("char")
			inv.show_tab("inventory")
			gm.close()
			stage = 7; t = 0
		7:
			if t < 0.4:
				return false
			gm.open_container(root.get_tree().get_first_node_in_group("ship").storage)
			stage = 8; t = 0
		8:
			if t < 1.2:
				return false
			if not inv._loot_slots.is_empty():
				mouse(px(inv._loot_slots[0]))
			stage = 9; t = 0
		9:
			if t < 0.5:
				return false
			snap("loot")
			quit()
	return false
