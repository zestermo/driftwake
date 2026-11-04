extends SceneTree
## The cooking game (1.28): the galley's Cook opens it in first person (a CookScene's camera is current, the
## captain's body hidden) and takes nothing yet; presses on the marks (stir x3, flip in the band, plate centred)
## grade it Perfect: a "Perfect Fisherman's Stew" (fish_stew@3) in the bag, the ingredients gone, the first
## Perfect cook's XP x4, then back to the galley with the camera and body back. Eating it gives x1.3 the
## buff and minutes. Esc mid-game cooks nothing. CookTiming alone: no presses grade Burnt; mid scores Good.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var pr
var inv
var gm
var scr
var step := 0
var until := 0
var fails := 0
var cam0: Camera3D
var xp0 := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func cook_xp() -> int:
	var t := int(pr.mastery_of("cook")["xp"])
	for lv in range(1, pr.mastery_level("cook")):
		t += int(pr.mastery_to_next(lv, "cook"))
	return t


## Press right on the mark of the beat that's on.
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
			# the logic alone
			var tm := CookTiming.new()
			for i in range(2000):
				tm.tick(1.0 / 60.0)
			check("no presses at all: every beat runs out, Burnt (q %.2f)" % tm.quality(), tm.done() and CookTiming.grade_of(tm.quality()) == 0)
			check("grades: 0.5 Fair, 0.7 Good, 0.9 Perfect", CookTiming.grade_of(0.5) == 1 and CookTiming.grade_of(0.7) == 2 and CookTiming.grade_of(0.9) == 3)
			var tf := CookTiming.new({"beats": ["flip"]})
			tf.t = tf.rise_secs() * 0.5
			check("a flip at half heat scores between 0 and 1 (%.2f)" % tf.flip_score(), tf.flip_score() > 0.0 and tf.flip_score() < 1.0)
			p = stage.player
			pr = p.progression
			inv = p.inventory_component
			for st in inv.items.duplicate():
				if st.item.ingredient in ["fish", "grain"] or st.item.meal != "":
					inv.remove_item(st.item, st.quantity)
			inv.add_item(ItemDB.get_item("fish"), 2)
			inv.add_item(ItemDB.get_item("rice"), 2)
			gm = root.get_node("GameMenu")
			gm.open_galley(1)
			until = TK.wait_ticks(2)
			step = 1
		1:
			scr = gm._cook
			cam0 = root.get_viewport().get_camera_3d()
			gm._galley._pick("fish_stew")
			gm._galley.play_selected()
			until = TK.wait_ticks(3)
			step = 2
		2:
			check("Cook opens the cooking game", gm._current == "cook" and scr.timing != null)
			check("...in first person: the counter's camera is current", scr.scene != null and root.get_viewport().get_camera_3d() == scr.scene.cam)
			check("...the captain's body hidden", not p.body_model.visible)
			check("...nothing taken yet", inv.count("fish") == 2 and inv.count("rice") == 2)
			xp0 = cook_xp()
			for i in range(5):
				press_true()
			check("five true presses: the game's done, Perfect (q %.2f)" % scr.timing.quality(), scr.timing.done() and CookTiming.grade_of(scr.timing.quality()) == 3)
			until = TK.wait_secs(2.2)
			step = 3
		3:
			check("back at the galley", gm._current == "galley" and scr.scene == null)
			check("...the camera and the body back", root.get_viewport().get_camera_3d() == cam0 and p.body_model.visible)
			check("a Perfect Fisherman's Stew in the bag", inv.count("fish_stew@3") == 1 and ItemDB.get_item("fish_stew@3").display_name == "Perfect Fisherman's Stew")
			check("...the fish and rice used", inv.count("fish") == 1 and inv.count("rice") == 1)
			var want := 2 * 4 * (Food.COOK_XP + 2 * Food.COOK_XP_PER)
			check("a first Perfect cook: x4 XP, twice for Cooking (1.30) (+%d, want %d)" % [cook_xp() - xp0, want], cook_xp() - xp0 == want)
			gm.close()
			p.state_machine.force_state("Idle", {})
			p.heal_cd = 0.0
			p.use_item(ItemDB.get_item("fish_stew@3"))
			until = TK.wait_secs(1.6)
			step = 4
		4:
			var k := Food.strength(pr) * 1.3
			check("eaten: x1.3 the buff (k %.2f)" % pr.meal_k, pr.meal == "fish_stew" and is_equal_approx(pr.meal_k, k))
			check("...and x1.3 the minutes (%.0f s)" % pr.meal_left, pr.meal_left > Food.seconds(pr, "fish_stew") * 1.25)
			gm.open_galley(1)
			until = TK.wait_ticks(2)
			step = 41
		41:
			gm._galley._pick("fish_stew")
			gm._galley.play_selected()
			until = TK.wait_ticks(3)
			step = 5
		5:
			var ev := InputEventAction.new()
			ev.action = "pause"
			ev.pressed = true
			Input.parse_input_event(ev)
			until = TK.wait_ticks(3)
			step = 6
		6:
			check("Esc mid-game: back at the galley, nothing cooked (%s, fish %d)" % [gm._current, inv.count("fish")], gm._current == "galley" and inv.count("fish") == 1 and inv.count("fish_stew@3") == 0 and inv.count("fish_stew") == 0 and scr.scene == null)
			gm.close()
			print("RESULT OK" if fails == 0 else "RESULT FAILED (%d)" % fails)
			quit(1 if fails else 0)
			step = 99
	return false
