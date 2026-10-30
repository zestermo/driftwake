extends SceneTree
## A wipe in the stronghold (1.27, StrongholdScouring._wipe): every captain on it down at once and the crew wakes in
## the Admiralty's brig (kit kept); breaking out brings them back to the Lower Ward.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var w
var isl
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	var p = stage.player
	match step:
		0:
			w = load("res://tools/dev/t/capital/_world.gd").take_over(stage, 4242)
			until = TK.wait_ticks(2)
		1:
			isl = w.build_stronghold(Vector3(900, 0, 900))
			p.global_position = Vector3(900, 2, 1400)
			p.reset_physics_interpolation()
			until = TK.wait_secs(8.0)
		2:
			check("no brig before anyone falls", load("res://scripts/ai/admiralty_brig.gd").of(self) == null)
			p.global_position = isl.city_global(Vector2(0, 30), 12.4)
			p.reset_physics_interpolation()
			p.health_component.take_damage(p.health_component.max_health * 3.0)
			until = TK.wait_secs(2.0)
		3:
			var brig = load("res://scripts/ai/admiralty_brig.gd").of(self)
			check("the whole crew down on the stronghold: the brig (%s)" % str(brig != null), brig != null)
			if brig:
				var ward: Rect2 = load("res://scripts/island/stronghold_plan.gd").DISTRICTS[1][1]
				check("...breaking out brings you back to the Lower Ward", brig.return_to.distance_to(isl.city_global(ward.get_center(), 12.5)) < 1.0)
			return TK.done(fails)
	step += 1
	return false
