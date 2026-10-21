extends SceneTree
## The pad's skill list (bottom left) on the light stage's HUD, four skills and an ultimate on the bar:
## playing (pad.png, dim) and LB held with X down (layer.png). Args: <out dir> [WxH] (default 1280x720).
## Opens a window.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var step := 0
var until := 0
var out := "res://tools/dev/out/padshot"


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		out = a[0]
	var wh := (a[1] if a.size() > 1 else "1280x720").split("x")
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


func _process(_d: float) -> bool:
	# (a windowed run opens the creator first)
	for c in root.find_children("*", "CharacterCreator", true, false):
		c._finish(true)
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			var p = stage.player
			var plain := []
			var ult := ""
			for id in Skills.ALL:
				if Skills.is_ult(id):
					ult = id if ult == "" else ult
				elif plain.size() < 4:
					plain.append(id)
			for i in range(plain.size()):
				p.power.loadout[i] = plain[i]
			p.power.loadout[4] = ult
			button(JOY_BUTTON_A, true)
			button(JOY_BUTTON_A, false)
			until = TK.wait_secs(0.6)
		1:
			shot("pad.png")
			button(JOY_BUTTON_LEFT_SHOULDER, true)
			until = TK.wait_ticks(4)
		2:
			button(JOY_BUTTON_X, true)
			until = TK.wait_ticks(2)
		3:
			shot("layer.png")
			quit()
	step += 1
	return false
