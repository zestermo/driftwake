extends SceneTree
## The skills menu (K): opens on the tree of the weapon in hand under the Captain / Combat / Adventure / Loadout signs
## (no Driftfruit sign before a fruit), Q / E walk the tabs, Tab shows the combat chart with every found weapon,
## A / D change weapon, a click on a sign opens its tab, and eating a fruit adds the Driftfruit sign.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var gm
var sm
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


func key(k: int) -> void:
	var ev := InputEventKey.new()
	ev.keycode = k
	ev.pressed = true
	sm._input(ev)


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			var p = stage.player
			if not p.armed:
				TK.act("ready_weapon")
			p.progression.add_mastery("sword", 200)
			p.progression.add_mastery("katana", 200)
			p.progression.add_life("swim", p.progression.mastery_to_next(1))
			# (the runner's window is tiny: the menu lays out for a 640x360 canvas)
			root.size = Vector2i(1280, 720)
			root.get_node("Story").step = "done"
			gm = root.get_node("GameMenu")
			until = TK.wait_ticks(30)
		1:
			TK.act("skill_map")
			until = TK.wait_ticks(6)
		2:
			sm = gm._skills
			check("K opens the skills menu", gm._current == "skills")
			check("it opens on the katana's tree", sm.tab == "combat" and sm.tree == "katana" and not sm.chart)
			check("four signs, no Driftfruit yet", sm.tabs().map(func(x): return x[0]) == ["captain", "combat", "adventure", "loadout"])
			check("a hanging sign drawn per tab", sm._tab_rects.size() == 4)
			check("the katana's nodes are drawn with hits", sm._drawn.any(func(h): return h[1] == "n:k_root"))
			key(KEY_E)
			check("E: the next tab (Adventure)", sm.tab == "adventure")
			key(KEY_Q)
			key(KEY_Q)
			check("Q twice: the Captain", sm.tab == "captain")
			key(KEY_E)
			key(KEY_TAB)
			until = TK.wait_ticks(3)
		3:
			check("Tab: the combat chart", sm.tab == "combat" and sm.chart)
			check("the chart has the katana and the cutlass", sm._drawn.any(func(h): return h[1] == "w:katana") and sm._drawn.any(func(h): return h[1] == "w:sword"))
			key(KEY_D)
			check("D: the next weapon's tree", not sm.chart and sm.tree != "katana" and sm.tree in stage.player.progression.visible_trees("combat"))
			var ev := InputEventMouseButton.new()
			ev.button_index = MOUSE_BUTTON_LEFT
			ev.pressed = true
			ev.position = (sm._tab_rects[3] as Rect2).get_center()
			sm._gui_input(ev)
			check("a click on the fourth sign opens the Loadout", sm.tab == "loadout")
			stage.player.power.eat("vine")
			until = TK.wait_ticks(3)
		4:
			check("a fruit eaten: the Driftfruit sign", sm.tabs().size() == 5 and sm._tab_rects.size() == 5)
			TK.act("skill_map")
			until = TK.wait_ticks(6)
		5:
			check("K closes it", not gm.is_open())
			return TK.done(fails)
	step += 1
	return false
