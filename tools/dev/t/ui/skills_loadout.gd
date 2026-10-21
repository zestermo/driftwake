extends SceneTree
## The skills menu's Loadout tab: at katana mastery 13 the library lists Tiger Rush and the Clean Line passive; with
## Clean Line picked, 2 puts it in passive slot 2; with Tiger Rush picked, 3 puts it on the bar's key 3; right-click
## clears that bar slot; an ultimate not learned yet is refused with PowerComponent's reason.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var gm
var sm
var pr
var p
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
			p = stage.player
			pr = p.progression
			pr.mastery_of("katana")["lv"] = 12
			pr.add_mastery("katana", pr.mastery_to_next(12))
			p.loadouts[0] = ["katana", ""]
			# (the runner's window is tiny: the menu lays out for a 640x360 canvas)
			root.size = Vector2i(1280, 720)
			root.get_node("Story").step = "done"
			gm = root.get_node("GameMenu")
			gm.open("skills")
			sm = gm._skills
			sm.set_tab("loadout")
			until = TK.wait_ticks(4)
		1:
			check("the library lists Tiger Rush", sm._drawn.any(func(h): return h[1] == "lib:tiger_rush"))
			check("and the Clean Line passive", sm._drawn.any(func(h): return h[1] == "lib:k_clean"))
			check("a bar slot per key and the passive slots", sm._drawn.filter(func(h): return str(h[1]).begins_with("bar:")).size() == 6
				and sm._drawn.filter(func(h): return str(h[1]).begins_with("pas:")).size() == pr.passive_slots())
			sm.sel = "lib:k_clean"
			key(KEY_2)
			check("2 puts Clean Line in passive slot 2", pr.passives[1] == "k_clean")
			sm.sel = "lib:tiger_rush"
			key(KEY_3)
			check("3 puts Tiger Rush on key 3", p.power.loadout[2] == "tiger_rush")
			until = TK.wait_ticks(3)
		2:
			for h in sm._drawn:
				if h[1] == "bar:2":
					var mb := InputEventMouseButton.new()
					mb.button_index = MOUSE_BUTTON_RIGHT
					mb.pressed = true
					mb.position = (h[0] as Rect2).get_center()
					sm._gui_input(mb)
			check("right-click clears the slot", p.power.loadout[2] == "")
			sm.sel = "lib:petal_storm"
			key(KEY_1)
			check("an ultimate not learned yet is refused with the bar's reason", p.power.loadout[0] != "petal_storm"
				and sm._msg == p.power.equip_why("petal_storm", 0) and sm._msg != "")
			return TK.done(fails)
	step += 1
	return false
