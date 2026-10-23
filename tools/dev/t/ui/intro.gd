extends SceneTree
## A new game's opening (Intro): the narration plays as a cutscene in a forced storm at night with the captain aboard
## Holt's ship; skipped, two marines come over the rail; beaten, Holt's last order plays; skipped, a fade to black,
## then the done callback (the beach), the weather and time put back and the stage gone.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var intro
var done := false
var forced0 := -1
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"weather": true, "water": true})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func cut():
	return load("res://scripts/dialogue/cutscene.gd").active


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	var p = stage.player
	var w := root.get_node("Weather")
	match step:
		0:
			forced0 = int(w.forced)
			intro = load("res://scripts/game/intro.gd").play(p, func(): done = true)
			until = TK.wait_secs(0.5)
		1:
			var c = cut()
			check("the narration plays (%d lines)" % (c.shots.size() if c else 0), c != null and c.kind == "intro" and c.shots.size() == 6)
			check("...in a storm at night (%.1f h)" % w.hour(), int(w.forced) == 3 and (w.hour() > 20.0 or w.hour() < 5.0))
			check("...the captain aboard Holt's ship", p.global_position.distance_to(intro._deck.global_position) < 8.0)
			TK.act("interact")
			until = TK.wait_secs(0.6)
		2:
			check("skipped: two marines over the rail", intro.phase == "fight" and intro.marines.size() == 2)
			for m in intro.marines:
				m.health_component.take_damage(99999.0)
			until = TK.wait_secs(0.5)
		3:
			var c = cut()
			check("beaten: Holt's last order", intro.phase == "ending" and c != null and c.kind == "intro_end")
			TK.act("interact")
			until = TK.wait_secs(2.0)
		4:
			check("then black, and on to the beach (the callback)", done)
			check("...the weather put back, the stage gone", int(w.forced) == forced0 and get_first_node_in_group("rivals") == null and root.find_child("Intro", true, false) == null)
			return TK.done(fails)
	step += 1
	return false
