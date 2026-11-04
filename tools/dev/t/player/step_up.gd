extends SceneTree
## (1.30) The ground step-up: walking into a 0.3 m and a 0.6 m ledge the captain goes up and over with no jump, lifted
## smoothly (never more than the step rate a tick: no pop) and never leaving Move for Fall on the way; a 0.9 m ledge
## stops them; on the flat the walk speed is exactly the stick's (6 m/s) the whole time.
const TK := preload("res://tools/dev/test_kit.gd")
const HEIGHTS := [0.3, 0.6, 0.9]
var stage
var p
var step := 0
var until := 0
var fails := 0
var k := 0
var ledge: StaticBody3D
var last_y := 0.0
var last_tick := 0
var worst_rate := 0.0
var fell := false
var speeds: Array = []


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _forward() -> Vector3:
	var yaw: float = stage.camera_rig.global_rotation.y
	return Vector3(-sin(yaw), 0, -cos(yaw))


## Every frame while walking: the fastest climb a tick, whether Fall came up, the speed on the flat.
func _watch() -> void:
	var t := Engine.get_physics_frames()
	if t > last_tick:
		worst_rate = maxf(worst_rate, (p.global_position.y - last_y) / float(t - last_tick))
		last_tick = t
		last_y = p.global_position.y
	fell = fell or p.current_state_name() == "Fall"


func _process(_d: float) -> bool:
	if TK.ticking(until):
		if step == 3:
			_watch()
		return false
	if not stage.up:
		return false
	match step:
		0:
			p = stage.player
			p.global_position = Vector3(0, stage.GROUND_Y + 0.05, 0)
			p.reset_physics_interpolation()
			until = TK.wait_ticks(20)
		1:
			var h: float = HEIGHTS[k]
			ledge = StaticBody3D.new()
			var cs := CollisionShape3D.new()
			var b := BoxShape3D.new()
			b.size = Vector3(6.0, h, 4.0)
			cs.shape = b
			ledge.add_child(cs)
			var f := _forward()
			ledge.transform = Transform3D(Basis.looking_at(f, Vector3.UP), Vector3(0, stage.GROUND_Y + h * 0.5, 0) + f * 3.2)
			stage.add_child(ledge)
			p.global_position = Vector3(0, stage.GROUND_Y + 0.05, 0)
			p.velocity = Vector3.ZERO
			p.reset_physics_interpolation()
			until = TK.wait_ticks(10)
		2:
			last_y = p.global_position.y
			last_tick = Engine.get_physics_frames()
			worst_rate = 0.0
			fell = false
			TK.press("move_forward")
			until = TK.wait_ticks(40)
		3:
			TK.release("move_forward")
			var h: float = HEIGHTS[k]
			var on: float = p.global_position.y - stage.GROUND_Y
			var ahead: float = (p.global_position - Vector3(0, p.global_position.y, 0)).dot(_forward())
			var step_tick: float = p.STEP_RATE / float(Engine.physics_ticks_per_second)
			if h < 0.7:
				check("into a %.1f m ledge: up and over with no jump (feet %.2f m up, %.1f m on)" % [h, on, ahead], absf(on - h) < 0.12 and ahead > 2.2)
				check("...lifted smoothly (worst %.3f m a tick, the lift %.3f a tick plus the capsule riding the edge), never falling (fell: %s)" % [worst_rate, step_tick, fell], worst_rate <= step_tick * 1.8 and not fell)
			else:
				check("into a %.1f m ledge: stopped at its foot (feet %.2f m up, %.1f m on)" % [h, on, ahead], on < 0.2 and ahead < 2.4)
			ledge.queue_free()
			k += 1
			if k < HEIGHTS.size():
				step = 1
				until = TK.wait_ticks(3)
				return false
			p.global_position = Vector3(0, stage.GROUND_Y + 0.05, 0)
			p.reset_physics_interpolation()
			until = TK.wait_ticks(10)
		4:
			TK.press("move_forward")
			until = TK.wait_ticks(15)
		5:
			speeds.append(Vector2(p.velocity.x, p.velocity.z).length())
			if speeds.size() < 20:
				until = TK.wait_ticks(1)
				return false
			TK.release("move_forward")
			var lo: float = speeds.min()
			var hi: float = speeds.max()
			check("on the flat the walk is exactly the stick's speed (%.3f..%.3f, move speed %.1f)" % [lo, hi, p.move_speed], absf(lo - p.move_speed) < 0.001 and absf(hi - p.move_speed) < 0.001)
			return TK.done(fails)
	step += 1
	return false
