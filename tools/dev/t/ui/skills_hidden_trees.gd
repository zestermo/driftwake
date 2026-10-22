extends SceneTree
## Trees you haven't got never show in the skills menu: with only the cutlass and katana found there's no Adventure
## or Driftfruit sign, the weapon rail, the chart and A / D hold only found weapons (no polearm, no black-leg). Being
## taught black-leg puts it on the chart and rail; a swim's first level brings the Adventure sign.
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


func key(k: int) -> void:
	var ev := InputEventKey.new()
	ev.keycode = k
	ev.pressed = true
	sm._input(ev)


func weapons_drawn() -> Array:
	return sm._drawn.filter(func(h): return str(h[1]).begins_with("w:")).map(func(h): return str(h[1]).substr(2))


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			pr = stage.player.progression
			pr.add_mastery("katana", 200)
			root.size = Vector2i(1280, 720)
			root.get_node("Story").step = "done"
			gm = root.get_node("GameMenu")
			gm.open("skills")
			sm = gm._skills
			sm.set_tab("combat", "katana")
			until = TK.wait_ticks(4)
		1:
			var found: Array = pr.visible_trees("combat")
			check("found: the cutlass and the katana only", found.size() == 2 and "sword" in found and "katana" in found)
			check("no Adventure or Driftfruit sign", sm.tabs().map(func(x): return x[0]) == ["captain", "combat", "loadout"])
			check("the rail holds only found weapons", weapons_drawn().all(func(t): return t in found) and weapons_drawn().size() == 2)
			var seen := {}
			for i in range(4):
				key(KEY_D)
				seen[sm.tree] = true
			check("A / D walk only found weapons", seen.keys().all(func(t): return t in found))
			key(KEY_TAB)
			until = TK.wait_ticks(3)
		2:
			check("the chart: found weapons only", sm.chart and weapons_drawn().size() == 2 and not "polearm" in weapons_drawn() and not "black_leg" in weapons_drawn())
			pr.discover("black_leg")
			pr.add_life("swim", pr.mastery_to_next(1))
			until = TK.wait_ticks(3)
		3:
			check("taught black-leg: on the chart", "black_leg" in weapons_drawn())
			check("a swim level: the Adventure sign", "adventure" in sm.tabs().map(func(x): return x[0]))
			check("Adventure lists only Swimming", pr.visible_trees("adventure") == ["swim"])
			return TK.done(fails)
	step += 1
	return false
