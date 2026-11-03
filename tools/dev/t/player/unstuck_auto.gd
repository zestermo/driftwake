extends SceneTree
## (1.30) The warp out from under the ground: a captain fallen through under the island's ground, with nothing under
## their feet, is put back on the last safe ground after about a second (not at once), and stands there.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var a: Vector3
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
	match step:
		0:
			p = stage.player
			# (off the stage's ground, above the sea: the island's ground stands at 100 m over a hollow)
			load("res://scripts/world/ground_net.gd").height_override = func(at: Vector3) -> float: return 100.0 if absf(at.x) > 70.0 else 3.0
			until = TK.wait_secs(0.5)
		1:
			a = p.global_position
			p.global_position = Vector3(200, 80, 0)
			p.velocity = Vector3.ZERO
			p.reset_physics_interpolation()
			until = TK.wait_secs(0.4)
		2:
			check("fallen under the ground, not warped at once (x %.0f y %.1f)" % [p.global_position.x, p.global_position.y], p.global_position.x > 150.0)
			until = TK.wait_secs(1.2)
		3:
			check("...after a second, back where they last stood (%.2f m off)" % p.global_position.distance_to(a), p.global_position.distance_to(a) < 0.6)
			until = TK.wait_secs(0.4)
		4:
			check("...standing there", p.is_on_floor() and p.global_position.distance_to(a) < 0.6)
			load("res://scripts/world/ground_net.gd").height_override = Callable()
			return TK.done(fails)
	step += 1
	return false
