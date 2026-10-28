extends SceneTree
## The skills menu's Captain tab (1.24.1, one page): it opens on the Will paths with the Perks button lit while a fork
## waits (and a pip on the tab); P (or a click) opens the perks popup on the lowest fork not picked, every fork drawn;
## up / down walk the forks, left / right the option; Enter picks a reached fork, refuses one not reached yet and a
## change away from the bunk; Esc shuts it. A path tab (or A / D) shows that path; Enter buys Coat's first version and the
## Hardening passive (slotted) once your Edy is read; every tier-3 version draws (the ids no longer hide them).
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


func click(id: String) -> bool:
	var h = sm._drawn.filter(func(x): return x[1] == id)
	if h.is_empty():
		return false
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = (h[0][0] as Rect2).get_center()
	sm._gui_input(ev)
	return true


func drawn(id: String) -> bool:
	return sm._drawn.any(func(h): return h[1] == id)


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
			check("the Captain tab opens on the Will paths (no Will yet: Iron Will, Heavy Coat)", not sm.perks_open and sm.will_path == "iron" and sm.sel == "n:w_coat_heavy")
			check("level 12 with the fork at 10 unpicked: Perks and the tab call for it", sm.perk_ready() and sm.captain_ready())
			until = TK.wait_ticks(3)
		3:
			check("the Perks button is drawn", drawn("perks"))
			key(KEY_P)
			check("P: the perks popup, on the lowest fork not picked (10)", sm.perks_open and sm.sel == "f:talent_10:0")
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
			check("...and nothing waits now", not sm.perk_ready())
			act("ui_up", 6)
			check("up to the top fork (40), same side", sm.sel == "f:talent_40:1")
			until = TK.wait_ticks(3)
		4:
			check("the popup draws every fork, 5 to 40", drawn("f:talent_5:0") and drawn("f:talent_40:1"))
			check("...and only the popup is clickable", not drawn("perks") and not drawn("path:iron"))
			act("ui_cancel")
			check("Esc shuts the popup", not sm.perks_open)
			pr.gift("will", 3)
			check("Edy to spend but not read yet: nothing to buy", not sm.path_ready("iron") and pr.buy_why("w_coat_heavy").begins_with("Your Edy isn't read yet"))
			pr.attune("ember")
			for i in range(pr.passives.size()):
				pr.equip_passive("", i)
			until = TK.wait_ticks(3)
		5:
			check("a click on Tempo's tab shows Tempo", click("path:tempo") and sm.will_path == "tempo")
			key(KEY_A)
			check("A: the path before (Tide)", sm.will_path == "tide")
			check("a click on Iron Will's tab, on its first version to buy (Heavy Coat)", click("path:iron") and sm.will_path == "iron" and sm.sel == "n:w_coat_heavy")
			act("ui_accept")
			check("Enter buys Heavy Coat for 1 Will", pr.has_version("w_coat_heavy") and pr.knows("armament_coat") and pr.pool("will") == 2)
			sm.sel = "n:h_harden"
			act("ui_accept")
			check("Enter on Hardening buys it for 2 and slots it", pr.has_version("h_harden") and pr.passives.has("h_harden") and pr.pool("will") == 0)
			until = TK.wait_ticks(3)
		6:
			check("Iron Will's ladder draws its versions, both tier-3 ones and its passive",
				["n:w_coat_heavy", "n:w_emit_stomp", "n:w_inner_v", "n:w_mirror", "n:h_harden"].all(func(id): return drawn(id)))
			sm._set_path("conq")
			until = TK.wait_ticks(3)
		7:
			check("Captain's Will draws Clash, Rally and Plant the Flag", ["n:w_clash_v", "n:w_rally", "n:w_flag", "n:h_will"].all(func(id): return drawn(id)))
			check("no colour swatches any more (a master reads your Edy)", not sm._drawn.any(func(h): return str(h[1]).begins_with("col:")))
			TK.act("skill_map")
			until = TK.wait_ticks(6)
		8:
			check("K closes it", not gm.is_open())
			return TK.done(fails)
	step += 1
	return false
