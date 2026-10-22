extends SceneTree
## Surface Sprint (Swimming): a sprint on top of the water is plain, then Dolphin Kick (~1.3x the speed, 1.3x the drain,
## the butterfly shown on the body) or Long Glide (a touch faster, about half the drain, the streamline shown); switching
## the version at the bunk swaps them; under water the plain dolphin kick is untouched and the style clears.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var pr
var step := 0
var until := 0
var fails := 0
var x0 := 0.0
var st0 := 0.0
var plain_v := 0.0
var plain_d := 0.0
var dolphin_v := 0.0
var dolphin_d := 0.0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"water": true, "hud": false})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func begin_run() -> void:
	TK.release("sprint")
	p.stamina = p.max_stamina
	p.global_position = Vector3(stage.SHORE_X + 4.0, 1.0, 30.0)
	p.reset_physics_interpolation()
	p.state_machine.force_state("Swim", {"entry_vy": 0.0, "quiet": true})
	TK.press("move_right")
	until = TK.wait_secs(0.8)


func start_sprint() -> void:
	TK.press("sprint")
	until = TK.wait_secs(0.8)


func start_measure() -> void:
	x0 = p.global_position.x
	st0 = p.stamina
	until = TK.wait_secs(1.6)


func speed() -> float:
	return (p.global_position.x - x0) / 1.6


func drain() -> float:
	return (st0 - p.stamina) / 1.6


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			pr = p.progression
			begin_run()
		1:
			start_sprint()
		2:
			check("a plain sprint shows no style", p.body_model.swim_style == "")
			start_measure()
		3:
			plain_v = speed()
			plain_d = drain()
			print("   plain ", plain_v, " m/s, ", plain_d, " st/s")
			check("plain sprint ~4.6 m/s (%.2f)" % plain_v, plain_v > 4.0 and plain_v < 5.2)
			pr.owned["sw_sprint"] = true
			pr._own("sw_dolphin")
			begin_run()
		4:
			start_sprint()
		5:
			check("Dolphin Kick: the butterfly shows (%s)" % p.body_model.swim_style, p.body_model.swim_style == "dolphin")
			start_measure()
		6:
			dolphin_v = speed()
			dolphin_d = drain()
			print("   dolphin ", dolphin_v, " m/s, ", dolphin_d, " st/s")
			check("...about 1.3x faster at least (%.2f vs %.2f)" % [dolphin_v, plain_v], dolphin_v > plain_v * 1.28)
			check("...for ~1.3x the drain (%.1f vs %.1f)" % [dolphin_d, plain_d], dolphin_d > plain_d * 1.2 and dolphin_d < plain_d * 1.45)
			pr._switch("sw_sprint", 1)
			check("switched to Long Glide", pr.has_flag("long_glide") and not pr.has_flag("dolphin_kick"))
			begin_run()
		7:
			start_sprint()
		8:
			check("Long Glide: the streamline shows (%s)" % p.body_model.swim_style, p.body_model.swim_style == "glide")
			start_measure()
		9:
			var v := speed()
			var d := drain()
			print("   glide ", v, " m/s, ", d, " st/s")
			check("...a touch faster than plain (%.2f vs %.2f)" % [v, plain_v], v > plain_v * 1.05 and v < dolphin_v)
			check("...at about half the drain (%.1f vs %.1f)" % [d, plain_d], d < plain_d * 0.7 and d > plain_d * 0.4)
			TK.release("sprint")
			until = TK.wait_secs(0.4)
		10:
			check("let go of sprint: the style clears", p.body_model.swim_style == "")
			return TK.done(fails)
	step += 1
	return false
