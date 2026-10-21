extends SceneTree
## FX.warm_up (the loading screen's last moment): every kind of effect drawn once in front of the camera, and
## gone again a few seconds later (nothing left lying where the captain wakes: no blood splat on the ground).
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var step := 0
var until := 0
var fails := 0
var before := 0
var fx


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
			fx = root.get_node("FX")
			before = current_scene.get_child_count() if current_scene else root.get_child_count()
			var splats: int = fx._splats.size()
			fx.warm_up()
			var made: int = (current_scene.get_child_count() if current_scene else root.get_child_count()) - before
			check("every kind of effect made at once (%d nodes)" % made, made >= 40)
			check("...no blood left lying about", fx._splats.size() == splats)
			until = TK.wait_secs(4.0)
		1:
			var left: int = (current_scene.get_child_count() if current_scene else root.get_child_count()) - before
			check("...and gone a few seconds later (%d left)" % left, left <= 0)
			return TK.done(fails)
	step += 1
	return false
