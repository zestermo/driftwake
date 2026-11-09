extends SceneTree
## (1.31) Lock-on (Targeting): locks the foe nearest the view's centre, the camera turns to keep it ahead, aimed
## things (get_camera_forward) point at it, the chevron sits over it, a second press lets go.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var tg
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"dummy": Vector3(1.0, 0, -6.0), "weapon": "cutlass"})


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
			tg = p.get_node_or_null("Targeting")
			check("the captain has targeting", tg != null)
			if tg == null:
				return TK.done(fails)
			stage.camera_rig.rotation.y = 0.0
			until = TK.wait_ticks(3)
		1:
			tg.toggle()
			check("it locks the foe in view", tg.locked() and tg.lock == stage.dummy)
			# look away: the lock turns the camera back
			stage.camera_rig.rotation.y = 1.4
			until = TK.wait_secs(1.0)
		2:
			var d: Vector3 = stage.dummy.global_position - p.global_position
			var want := atan2(d.x, d.z) + PI
			var off: float = absf(wrapf(stage.camera_rig.rotation.y - want, -PI, PI))
			print("  camera off the lock ", snappedf(off, 0.01))
			check("the camera keeps the locked foe ahead", off < 0.15)
			var f: Vector3 = p.state_machine.current_state.get_camera_forward()
			d.y = 0.0
			check("aimed things point at it", f.dot(d.normalized()) > 0.98)
			check("the chevron is over it", tg._chev.visible and tg._chev.global_position.distance_to(stage.dummy.global_position) < 3.0)
			tg.toggle()
			check("a second press lets go", not tg.locked())
			return TK.done(fails)
	step += 1
	return false
