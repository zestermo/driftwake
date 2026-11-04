extends SceneTree
## 1.30 the stronghold's objective indicator: standing in a district, the objective box tells what to do there (the
## Landing: up the stair; the Arsenal: Kesh for its seal, then "yours"; the Keep: the gate holds until both seals); the
## muster flag while it's down; nothing off the stronghold.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var w
var isl
var hud
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


func _put(key: String) -> void:
	for d in StrongholdPlan.DISTRICTS:
		if str(d[0]) == key:
			stage.player.global_position = isl.city_global((d[1] as Rect2).get_center(), float(d[2]) + 1.0)
			stage.player.reset_physics_interpolation()


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	var p = stage.player
	match step:
		0:
			hud = stage.hud._objective
			w = load("res://tools/dev/t/capital/_world.gd").take_over(stage, 4242)
			until = TK.wait_ticks(2)
		1:
			isl = w.build_stronghold(Vector3(900, 0, 900))
			p.global_position = Vector3(900, 2, 1400)
			p.reset_physics_interpolation()
			until = TK.wait_secs(8.0)
		2:
			check("off the stronghold: no district line", not hud._district.visible)
			_put("landing")
			until = TK.wait_ticks(20)
		3:
			check("the Landing: up the grand stair (%s)" % hud._district.text, hud._district.visible and hud._district.text.begins_with("THE LANDING") and hud._district.text.contains("stair"))
			_put("arsenal")
			until = TK.wait_ticks(20)
		4:
			check("the Arsenal: Kesh for its seal, the banner to cut (%s)" % hud._district.text, hud._district.text.begins_with("THE ARSENAL") and hud._district.text.contains("Kesh") and hud._district.text.contains("banner"))
			root.get_node("Net").world_flag("sh_seal_arsenal")
			root.get_node("Net").world_flag("sh_muster_arsenal")
			until = TK.wait_ticks(20)
		5:
			check("...its seal taken, the flag ours (%s)" % hud._district.text, hud._district.text.contains("is yours") and not hud._district.text.contains("banner"))
			_put("keep")
			until = TK.wait_ticks(20)
		6:
			check("the Keep: the gate holds, 1 of 2 seals (%s)" % hud._district.text, hud._district.text.begins_with("THE KEEP") and hud._district.text.contains("1 of 2"))
			return TK.done(fails)
	step += 1
	return false
