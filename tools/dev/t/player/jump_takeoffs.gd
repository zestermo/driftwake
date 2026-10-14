extends SceneTree
## Each pace has its own take-off and landing: standing (two-footed), running (in stride), sprinting (the long bound).
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var seen := {}
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


func home() -> void:
	p.global_position = Vector3(0, stage.GROUND_Y + 0.05, 0)
	p.reset_physics_interpolation()


func _process(_d: float) -> bool:
	if p != null:
		var a: String = p.body_model.current_action()
		if a != "":
			seen[a] = true
		if p.body_model._land > 0.0:
			seen["land:" + p.body_model._land_kind] = true
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			until = TK.wait_secs(0.3)
		1:
			seen.clear()
			TK.act("jump")
			until = TK.wait_secs(1.1)
		2:
			check("standing still: the standing take-off (%s)" % [seen.keys()], seen.has("jump_stand"))
			check("...and a two-footed landing", seen.has("land:stand"))
			home()
			TK.press("move_forward")
			until = TK.wait_secs(0.5)
		3:
			seen.clear()
			TK.act("jump")
			until = TK.wait_secs(1.0)
		4:
			check("on the move: the running take-off (%s)" % [seen.keys()], seen.has("jump_run") and not seen.has("jump_stand"))
			check("...landing in stride (the staggered landing)", seen.has("land:run"))
			TK.release("move_forward")
			home()
			TK.press("move_forward")
			TK.press("sprint")
			until = TK.wait_secs(0.8)
		5:
			seen.clear()
			check("sprinting before the jump (%.1f m/s)" % Vector2(p.velocity.x, p.velocity.z).length(), p.sprinting)
			TK.act("jump")
			until = TK.wait_secs(1.0)
		6:
			check("sprinting: the long bound (%s)" % [seen.keys()], seen.has("jump_sprint"))
			check("...and a running landing", seen.has("land:sprint"))
			TK.release("sprint")
			TK.release("move_forward")
			return TK.done(fails)
	step += 1
	return false
