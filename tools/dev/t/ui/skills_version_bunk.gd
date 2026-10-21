extends SceneTree
## A variant in the skills menu: at katana mastery 12 the Iai Upgrade is drawn split in two with its first version
## active; Enter (or a click on the other half) away from the ship's bunk is refused and says to switch at the bunk,
## and nothing changes.
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


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			pr = stage.player.progression
			pr.mastery_of("katana")["lv"] = 11
			pr.add_mastery("katana", pr.mastery_to_next(11))
			# (the runner's window is tiny: the menu lays out for a 640x360 canvas)
			root.size = Vector2i(1280, 720)
			root.get_node("Story").step = "done"
			gm = root.get_node("GameMenu")
			gm.open("skills")
			sm = gm._skills
			sm.set_tab("combat", "katana")
			until = TK.wait_ticks(4)
		1:
			check("the variant is reached and owned", pr.owns("k_iai") and pr.version_of("k_iai") == 0)
			check("drawn as two halves", sm._drawn.any(func(h): return h[1] == "v:k_iai:0") and sm._drawn.any(func(h): return h[1] == "v:k_iai:1"))
			check("away from the bunk", not pr.can_respec())
			sm.sel = "n:k_iai"
			var ev := InputEventKey.new()
			ev.keycode = KEY_ENTER
			ev.pressed = true
			sm._input(ev)
			check("Enter is refused: the same version", pr.version_of("k_iai") == 0)
			check("it says to switch at the bunk", sm._msg.contains("bunk"))
			for h in sm._drawn:
				if h[1] == "v:k_iai:1":
					var mb := InputEventMouseButton.new()
					mb.button_index = MOUSE_BUTTON_LEFT
					mb.pressed = true
					mb.position = (h[0] as Rect2).get_center()
					sm._gui_input(mb)
			check("a click on the other half is refused too", pr.version_of("k_iai") == 0 and sm.sel == "n:k_iai")
			return TK.done(fails)
	step += 1
	return false
