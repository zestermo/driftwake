extends SceneTree
## The skills menu's Captain tab: C / W switch the fork page and the Will chart (a click on the strip too); it opens on
## the lowest fork not picked; up / down walk the forks (scrolling the top one into view), left / right the option;
## Enter picks a reached fork, refuses one not reached yet and a change away from the bunk; Enter on a won Will slots
## its passive.
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
	stage = TK.stage(self, {})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func key(k: int) -> void:
	var ev := InputEventKey.new()
	ev.keycode = k
	ev.pressed = true
	sm._input(ev)


func act(a: String, n: int = 1) -> void:
	for i in range(n):
		var ev := InputEventAction.new()
		ev.action = a
		ev.pressed = true
		sm._input(ev)


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			pr = stage.player.progression
			var xp := 0
			for lv in range(1, 12):
				xp += pr.xp_to_next(lv)
			pr.add_xp(xp)
			pr.pick_talent(5, 0)
			root.size = Vector2i(1280, 720)
			root.get_node("Story").step = "done"
			gm = root.get_node("GameMenu")
			until = TK.wait_ticks(10)
		1:
			TK.act("skill_map")
			until = TK.wait_ticks(6)
		2:
			sm = gm._skills
			sm.set_tab("captain")
			check("level 12: the Captain tab opens on the lowest fork not picked (10)", sm.sel == "f:talent_10:0" and not sm.will_page)
			key(KEY_W)
			check("W: the Will page, on a Will", sm.will_page and sm.sel.begins_with("n:h_"))
			key(KEY_C)
			check("C: back to the forks", not sm.will_page and sm.sel == "f:talent_10:0")
			act("ui_up")
			check("up: the next fork (15)", sm.sel == "f:talent_15:0")
			act("ui_right")
			check("right: its second option", sm.sel == "f:talent_15:1")
			act("ui_accept")
			check("Enter on a fork not reached yet picks nothing", pr.talent_at(15) == -1)
			act("ui_down", 2)
			check("down twice: the first fork, same side", sm.sel == "f:talent_5:1")
			act("ui_accept")
			check("Enter can't change a picked talent away from the bunk", pr.talent_at(5) == 0)
			act("ui_up")
			act("ui_accept")
			check("Enter on the reached fork picks that option (Sea Dog)", pr.talent_at(10) == 1)
			act("ui_left")
			check("left: the first option", sm.sel == "f:talent_10:0")
			act("ui_up", 6)
			check("up to the top fork (40)", sm.sel == "f:talent_40:0")
			until = TK.wait_ticks(3)
		3:
			check("the top fork scrolled into view and drawn", sm._first + sm._rows >= 8 and sm._drawn.any(func(h): return h[1] == "f:talent_40:1"))
			check("the fork at 5 scrolled out", not sm._drawn.any(func(h): return h[1] == "f:talent_5:0"))
			pr.grant_will("h_arm")
			for i in range(pr.passives.size()):
				pr.equip_passive("", i)
			var strip = sm._drawn.filter(func(h): return h[1] == "page:w")
			var ev := InputEventMouseButton.new()
			ev.button_index = MOUSE_BUTTON_LEFT
			ev.pressed = true
			ev.position = (strip[0][0] as Rect2).get_center()
			sm._gui_input(ev)
			check("a click on W · WILL opens the Will page on the won Will", sm.will_page and sm.sel == "n:h_arm")
			act("ui_accept")
			check("Enter on a won Will puts its passive in a slot", pr.passives.has("h_harden"))
			until = TK.wait_ticks(3)
		4:
			check("the Will chart draws a star per Will and their moons", sm._drawn.any(func(h): return h[1] == "n:h_conq") and sm._drawn.any(func(h): return h[1] == "n:h_harden"))
			TK.act("skill_map")
			until = TK.wait_ticks(6)
		5:
			check("K closes it", not gm.is_open())
			return TK.done(fails)
	step += 1
	return false
