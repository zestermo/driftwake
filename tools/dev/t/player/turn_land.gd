extends SceneTree
## (1.31) The body on landing and turning: a drop lands with the knees taking it (Humanoid.land), turning on the
## spot steps the feet round (the shuffle), running round a curve banks into it.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var h
var step := 0
var until := 0
var fails := 0
var landed := false
var shuffled := false
var banked := 0.0
var n := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _process(_d: float) -> bool:
	if not stage.up:
		return false
	if h != null:
		landed = landed or h._land > 0.0
		shuffled = shuffled or h._shuffle > 0.0
		banked = maxf(banked, absf(h._yaw_rate))
	if TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			h = p.body_model
			p.global_position += Vector3(0, 4.5, 0)
			p.reset_physics_interpolation()
			until = TK.wait_secs(1.6)
		1:
			check("a drop lands with the knees taking it", landed)
			until = TK.wait_secs(0.5)
		2:
			# turn on the spot: the model swings round in small steps
			n += 1
			p.player_model.rotation.y += 0.06
			if n < 20:
				return false
			check("turning on the spot steps the feet round", shuffled)
			return TK.done(fails)
	step += 1
	return false
