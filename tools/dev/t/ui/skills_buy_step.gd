extends SceneTree
## The skills menu's stat steps: at katana mastery 3 (two points) a click picks the Keen Edge step and a second click
## buys a step (its counter and the free points follow), Enter buys the next, and with no points left it's refused
## with the reason.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var gm
var sm
var pr
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"weapon": "katana"})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func click(id: String) -> void:
	for h in sm._drawn:
		if h[1] == id:
			var ev := InputEventMouseButton.new()
			ev.button_index = MOUSE_BUTTON_LEFT
			ev.pressed = true
			ev.position = (h[0] as Rect2).get_center()
			sm._gui_input(ev)
			return
	check("%s is on screen" % id, false)


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			pr = stage.player.progression
			pr.mastery_of("katana")["lv"] = 2
			pr.add_mastery("katana", pr.mastery_to_next(2))
			# (the runner's window is tiny: the menu lays out for a 640x360 canvas)
			root.size = Vector2i(1280, 720)
			root.get_node("Story").step = "done"
			gm = root.get_node("GameMenu")
			gm.open("skills")
			sm = gm._skills
			sm.set_tab("combat", "katana")
			until = TK.wait_ticks(4)
		1:
			check("mastery 3: two points", pr.tree_level("katana") == 3 and pr.points_free("katana") == 2)
			click("n:k_keen")
			check("a click picks the step", sm.sel == "n:k_keen" and pr.steps_of("k_keen") == 0)
			click("n:k_keen")
			check("a second click buys a step", pr.steps_of("k_keen") == 1 and pr.points_free("katana") == 1)
			var ev := InputEventKey.new()
			ev.keycode = KEY_ENTER
			ev.pressed = true
			sm._input(ev)
			check("Enter buys another", pr.steps_of("k_keen") == 2 and pr.points_free("katana") == 0)
			sm._input(ev)
			check("no points: refused, nothing bought", pr.steps_of("k_keen") == 2)
			check("the refusal says why", sm._msg == pr.step_why("k_keen") and sm._msg != "")
			until = TK.wait_ticks(3)
		2:
			check("the counter redraws (2/5 on the step)", sm._drawn.any(func(h): return h[1] == "n:k_keen"))
			return TK.done(fails)
	step += 1
	return false
