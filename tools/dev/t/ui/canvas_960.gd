extends SceneTree
## The UI canvas (1.30, PSX.UI_SIZE 960x540): at 1920x1080 the HUD and the menus draw on 960x540 at 2x (whole screen
## pixels), the root's stretch is 960x540 and the 3D's pixel grid matches; a 1280x720 window gets 1280x720 at 1x; a
## window under 540 tall still lays out at least 540 tall (shrunk to fit).
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": true})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	var hud = get_first_node_in_group("hud")
	var gm = root.get_node("GameMenu")
	match step:
		0:
			root.size = Vector2i(1920, 1080)
			until = TK.wait_ticks(3)
		1:
			check("the root's canvas is 960x540 (%s)" % str(root.content_scale_size), root.content_scale_size == Vector2i(960, 540))
			check("the HUD's canvas is 960x540 at 2x (%s x%d)" % [str(hud._pc.canvas), hud._pc.stretch_shrink], hud._pc.canvas == Vector2(960, 540) and hud._pc.stretch_shrink == 2)
			check("...the menus' too", gm._pc.canvas == Vector2(960, 540) and gm._pc.stretch_shrink == 2)
			var shown: Vector2 = hud._pc.size * hud._pc.scale
			check("...drawn over the whole window (%s)" % str(shown), shown.distance_to(root.get_visible_rect().size) < 1.0)
			check("the 3D's pixel grid is 960x540 too (%s)" % str(root.get_node("PSX").pixel_res()), root.get_node("PSX").pixel_res() == Vector2(960, 540))
			root.size = Vector2i(1280, 720)
			until = TK.wait_ticks(3)
		2:
			check("a 1280x720 window: 1280x720 at 1x (%s)" % str(hud._pc.canvas), hud._pc.canvas == Vector2(1280, 720) and hud._pc.stretch_shrink == 1)
			root.size = Vector2i(960, 400)
			until = TK.wait_ticks(3)
		3:
			check("a window under 540 tall still lays out 540 tall (%s)" % str(hud._pc.canvas), hud._pc.canvas.y == 540.0 and hud._pc.canvas.x >= 960.0)
			root.size = Vector2i(1920, 1080)
			return TK.done(fails)
	step += 1
	return false
