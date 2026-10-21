extends SceneTree
## The skills menu buys big nodes too: at katana mastery 3 with a new captain's 2 Combat points, Quick Draw can be bought,
## a click picks it, a second buys it (its move unlocked, the pool on the beam at 0); Cut the Shot is refused with the
## reason; hovering a node draws its one-line tip; a weapon not found yet (the pistol) isn't on the rail or the chart.
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
			check("mastery 3, 2 Combat points: Quick Draw can be bought", pr.tree_level("katana") == 3 and pr.pool("combat") == 2 and pr.buy_why("k_draw") == "")
			click("n:k_draw")
			check("a click picks it", sm.sel == "n:k_draw" and not pr.owns("k_draw"))
			click("n:k_draw")
			check("a second click buys it: its move unlocked, the pool spent", pr.owns("k_draw") and pr.has_move("quick_draw") and pr.pool("combat") == 0)
			click("n:k_deflect")
			click("n:k_deflect")
			check("Cut the Shot refused with the reason", not pr.owns("k_deflect") and sm._msg == "Needs 2 Combat points")
			var ev := InputEventMouseMotion.new()
			ev.position = sm._rect_of("n:k_wind").get_center()
			sm._gui_input(ev)
			check("hovering Wind Severer picks it for the tip", sm.hover == "n:k_wind")
			check("the pistol isn't found: not on the rail", not sm._drawn.any(func(h): return h[1] == "w:pistol") and sm._drawn.any(func(h): return h[1] == "w:katana"))
			sm.chart = true
			until = TK.wait_ticks(3)
		2:
			check("...nor on the chart", not sm._drawn.any(func(h): return h[1] == "w:pistol") and sm._drawn.any(func(h): return h[1] == "w:katana"))
			return TK.done(fails)
	step += 1
	return false
