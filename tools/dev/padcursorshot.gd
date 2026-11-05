extends SceneTree
## (1.31) The pad's pointer (PadCursor) over menus at 1920x1080: the pause menu over Options (pause.png),
## A held there (pressed.png), the inventory over the bag (inventory.png), Options over a toggle (options.png)
## and a shop over a bag slot (shop.png). Args: <out dir> [WxH]. Opens a window.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var gm
var cur
var step := 0
var until := 0
var out := "res://tools/dev/out/padcursor"


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		out = a[0]
	var wh := (a[1] if a.size() > 1 else "1920x1080").split("x")
	root.size = Vector2i(int(wh[0]), int(wh[1]))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	TK.seed_of(self)
	stage = TK.stage(self, {})


func button(b: int, down: bool) -> void:
	var e := InputEventJoypadButton.new()
	e.device = 0
	e.button_index = b
	e.pressed = down
	Input.parse_input_event(e)


func axis(ax: int, v: float) -> void:
	var e := InputEventJoypadMotion.new()
	e.device = 0
	e.axis = ax
	e.axis_value = v
	Input.parse_input_event(e)


func shot(n: String) -> void:
	var path := ProjectSettings.globalize_path(out.path_join(n))
	root.get_texture().get_image().save_png(path)
	print("SAVED ", path)


## A control inside a PixelCanvas, in the root's canvas.
func root_point(pc, c: Control, frac := Vector2(0.5, 0.5)) -> Vector2:
	var r := c.get_global_rect()
	return pc.get_global_transform() * ((r.position + r.size * frac) * float(pc.stretch_shrink))


func find_button(n: Node, text: String) -> Button:
	for b in n.find_children("*", "Button", true, false):
		if (b as Button).text == text:
			return b
	return null


## Show the ring (a nudge of the stick), then put it on `at`.
func aim(at: Vector2) -> void:
	cur.mode = cur.CURSOR
	cur.point_at(at)


func _process(_d: float) -> bool:
	for c in root.find_children("*", "CharacterCreator", true, false):
		c._finish(true)
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			gm = root.get_node("GameMenu")
			cur = root.get_node("Pad").cursor
			button(JOY_BUTTON_START, true)
			button(JOY_BUTTON_START, false)
			until = TK.wait_ticks(6)
		1:
			aim(root_point(gm._pc, find_button(gm._screens["pause"], "Options"), Vector2(0.7, 0.55)))
			until = TK.wait_ticks(4)
		2:
			shot("pause.png")
			button(JOY_BUTTON_A, true)
			until = TK.wait_ticks(2)
		3:
			shot("pressed.png")
			cur._let_go()
			gm.open("inventory")
			until = TK.wait_secs(0.8)
		4:
			aim(Vector2(610, 250))
			until = TK.wait_secs(1.0)
		5:
			shot("inventory.png")
			gm.open("options")
			until = TK.wait_secs(0.5)
		6:
			var ws := find_button(gm._screens["options"], "On")
			aim(root_point(gm._pc, ws, Vector2(0.4, 0.6)) if ws else Vector2(560, 250))
			until = TK.wait_ticks(4)
		7:
			shot("options.png")
			gm.close()
			gm.open_shop("nessa")
			until = TK.wait_secs(0.8)
		8:
			aim(Vector2(420, 230))
			until = TK.wait_secs(0.8)
		9:
			shot("shop.png")
			quit()
	step += 1
	return false
