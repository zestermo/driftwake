extends SceneTree
## One map that zooms: on an island the wheel goes in round the captain (x2, x3.5, no further), back
## out to the whole island, then out to the sea chart; in again comes back to the island.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var page
var fit := 0.0
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _wheel(up: bool, n := 1) -> void:
	for i in range(n):
		page.press(MOUSE_BUTTON_WHEEL_UP if up else MOUSE_BUTTON_WHEEL_DOWN, Vector2(200, 120))


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			var isle = load("res://tools/dev/map_stub_isle.gd").new()
			isle.setup(8, 110.0)
			isle.add_to(self)
			# (the captain off to one side of the island)
			p.global_position = Vector3(40, p.global_position.y, 20)
			p.reset_physics_interpolation()
			p.get_node("MapHold").preview(true)
			page = p.get_node("MapHold").page
			until = TK.wait_ticks(3)
		1:
			check("it opens on the whole island", page.on_isle and page.isle.zoom == 0)
			fit = page.isle.k
			_wheel(true)
			until = TK.wait_secs(0.6)
		2:
			var iv = page.isle
			check("wheel up: twice as close (%.3f -> %.3f px/m)" % [fit, iv.k], iv.zoom == 1 and absf(iv.k - fit * 2.0) < fit * 0.05)
			check("...round the captain", iv.to_frame(Vector2(40, 20)).distance_to(iv.frame.size * 0.5) < 6.0)
			_wheel(true, 3)
			until = TK.wait_secs(0.6)
		3:
			check("closer, and no further than the last zoom", page.isle.zoom == 2 and absf(page.isle.k - fit * 3.5) < fit * 0.1)
			_wheel(false, 2)
			until = TK.wait_secs(0.6)
		4:
			check("wheel down: back to the whole island", page.on_isle and page.isle.zoom == 0 and absf(page.isle.k - fit) < fit * 0.05)
			_wheel(false)
			until = TK.wait_ticks(2)
		5:
			check("...and out again: the sea chart", not page.on_isle)
			_wheel(true)
			until = TK.wait_ticks(2)
		6:
			check("in from the chart: the island again", page.on_isle and page.isle.zoom == 0)
			p.get_node("MapHold").preview(false)
			return TK.done(fails)
	step += 1
	return false
