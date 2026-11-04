extends SceneTree
## The floating restaurant's cook-off (1.28): the table opens the cooking game on the judge's dish (no ingredients
## needed, at COOKOFF_SPEED); played Perfect it pays 300 gold and A Cook's Atlas with Cooking XP; one go a visit
## (a second try doesn't open the game). A raided restaurant's table waits until the raiders are beaten.
const TK := preload("res://tools/dev/test_kit.gd")
var SeaStops
var stage
var p
var r
var gm
var scr
var step := 0
var until := 0
var fails := 0
var g0 := 0
var xp0 := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "water": true})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _seed_for(attacked: bool) -> int:
	var R = load("res://scripts/sea/floating_restaurant.gd")
	for s in range(1, 200):
		if R.new().setup(Vector3.ZERO, 12, s).attacked == attacked:
			return s
	return -1


func cook_xp() -> int:
	var pr = p.progression
	var t := int(pr.mastery_of("cook")["xp"])
	for lv in range(1, pr.mastery_level("cook")):
		t += int(pr.mastery_to_next(lv, "cook"))
	return t


func press_true() -> void:
	var tm: CookTiming = scr.timing
	match tm.current():
		"stir":
			tm.t = tm.mark_angle() / (TAU * CookTiming.STIR_TURNS * tm.speed)
		"flip":
			tm.t = tm.rise_secs() * 0.79
		"plate":
			tm.t = CookTiming.PLATE_SWEEP * 0.5 / tm.speed
	scr.press()


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			SeaStops = load("res://scripts/sea/sea_stops.gd")
			p = stage.player
			r = SeaStops.build(stage, "restaurant", Vector2(140, 0), 12, _seed_for(false))
			r.set_meta("no_sleep", true)
			until = TK.wait_ticks(10)
			step = 1
		1:
			p.global_position = r.to_global(Vector3(-6.2, 0.5, -8.6))
			p.reset_physics_interpolation()
			until = TK.wait_secs(1.0)
			step = 2
		2:
			gm = root.get_node("GameMenu")
			scr = gm._cook
			g0 = p.inventory_component.count("gold")
			xp0 = cook_xp()
			r._cook_off(p)
			check("the cook-off opens the cooking game (%s)" % gm._current, gm._current == "cook" and scr.timing != null)
			check("at the cook-off's speed", scr.timing != null and absf(scr.timing.speed - r.COOKOFF_SPEED) < 0.001)
			until = TK.wait_ticks(4)
			step = 3
		3:
			press_true()
			if scr.timing.done():
				until = TK.wait_secs(2.2)
				step = 4
			else:
				until = TK.wait_ticks(3)
		4:
			var inv = p.inventory_component
			check("a Perfect cook-off pays 300 gold (%d)" % (inv.count("gold") - g0), inv.count("gold") - g0 == 300)
			check("and A Cook's Atlas", inv.count("book_atlas") == 1)
			check("and Cooking XP", cook_xp() > xp0)
			check("the menu's closed again", not gm.visible or gm._current != "cook")
			r._cook_off(p)
			check("one go a visit: a second try opens nothing", gm._current != "cook")
			# a raided restaurant waits for the raiders to be beaten
			var raided = SeaStops.build(stage, "restaurant", Vector2(-140, 0), 12, _seed_for(true))
			raided.set_meta("no_sleep", true)
			raided._cook_off(p)
			check("a raided restaurant's table waits for the raiders", gm._current != "cook" and not raided._cooked_off)
			print("RESULT OK" if fails == 0 else "RESULT FAILED (%d)" % fails)
			quit(1 if fails else 0)
			step = 5
	return false
