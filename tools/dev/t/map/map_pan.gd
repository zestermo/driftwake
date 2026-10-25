extends SceneTree
## Panning the map with middle mouse held (1.22): on an island page the view's centre moves against the drag, the
## pen stays where it was; a zoom puts the view back.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var page
var hold
var c0 := Vector2.ZERO
var pen0 := Vector2.ZERO
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


func _motion(rel: Vector2) -> void:
	var m := InputEventMouseMotion.new()
	m.screen_relative = rel
	m.relative = rel
	hold._input(m)


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			var isle = load("res://tools/dev/map_stub_isle.gd").new()
			isle.setup(8, 110.0)
			isle.add_to(self)
			hold = p.get_node("MapHold")
			hold.preview(true)
			page = hold.page
			until = TK.wait_ticks(3)
		1:
			# (held up, as the sea_chart key does)
			hold._up = true
			c0 = page.isle.centre
			pen0 = hold.cursor
			var b := InputEventMouseButton.new()
			b.button_index = MOUSE_BUTTON_MIDDLE
			b.pressed = true
			hold._input(b)
			_motion(Vector2(40, 0))
			b = InputEventMouseButton.new()
			b.button_index = MOUSE_BUTTON_MIDDLE
			b.pressed = false
			hold._input(b)
			until = TK.wait_secs(1.0)
		2:
			print("   centre %s -> %s, pan %s" % [c0, page.isle.centre, page.isle.pan_off])
			check("middle drag right: the view moves west (%.1f m)" % (c0.x - page.isle.centre.x), page.isle.centre.x < c0.x - 1.0)
			check("...the pen stays put", hold.cursor == pen0)
			page.press(MOUSE_BUTTON_WHEEL_UP, Vector2(200, 120))
			check("a zoom puts the view back", page.isle.pan_off == Vector2.ZERO)
			return TK.done(fails)
	step += 1
	return false
