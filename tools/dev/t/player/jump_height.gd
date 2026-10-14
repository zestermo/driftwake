extends SceneTree
## A tapped jump is a short hop, a held one the full jump; a jump pressed just before landing is buffered and fires
## on touchdown.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var peak := -999.0
var base_y := 0.0
var peaks := []
var buffered := false
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


func _physics_process(_d: float) -> bool:
	if step in [1, 3]:
		peak = maxf(peak, p.global_position.y - base_y)
	if step == 6 and p.current_state_name() == "Jump":
		buffered = true
	return false


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			base_y = p.global_position.y
			peak = -999.0
			TK.act("jump")
		1:
			if not (p.is_on_floor() and peak > 0.2):
				return false
			peaks.append(peak)
			until = TK.wait_secs(0.3)
		2:
			base_y = p.global_position.y
			peak = -999.0
			TK.press("jump")
		3:
			if not (p.is_on_floor() and peak > 0.2):
				return false
			TK.release("jump")
			peaks.append(peak)
			print("   short hop %.2f m, held jump %.2f m" % [peaks[0], peaks[1]])
			check("tap = short hop, hold = full jump", peaks[0] < peaks[1] * 0.8)
			# drop from height and press jump just before landing
			p.global_position += Vector3(0, 3.0, 0)
			p.velocity = Vector3.ZERO
			p.reset_physics_interpolation()
		4:
			if not (p.current_state_name() == "Fall" and p.velocity.y < -6.0):
				return false
			var q := PhysicsRayQueryParameters3D.create(p.global_position, p.global_position + Vector3(0, -0.6, 0), 1)
			if p.get_world_3d().direct_space_state.intersect_ray(q).is_empty():
				return false
			TK.act("jump")
		5:
			step = 6
			until = TK.wait_secs(0.15)
			return false
		6:
			check("buffered jump fires on landing", buffered)
			return TK.done(fails)
	step += 1
	return false
