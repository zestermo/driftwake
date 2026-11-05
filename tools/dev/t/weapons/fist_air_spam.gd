extends SceneTree
## The fists in the air (1.30.2): attack mashed after a held jump next to a foe, Diving Fist chains twice at most (its
## bounces lower each time) so the captain comes down, and the dives turn onto the foe and land.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var taken := 0.0
var step := 0
var until := 0
var fails := 0
var air_t := 0.0
var max_air := 0.0
var plunges := 0
var last_state := ""
var landed_at := -1


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "dummy": Vector3(0, 0, -3.0)})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _physics_process(delta: float) -> bool:
	if p == null or step < 2:
		return false
	var st: String = p.current_state_name()
	if st == "Plunge" and last_state != "Plunge":
		plunges += 1
	last_state = st
	air_t = 0.0 if p.is_on_floor() else air_t + delta
	max_air = maxf(max_air, air_t)
	if step >= 3 and (air_t > 0.25 or plunges > 0) and Engine.get_physics_frames() % 5 == 0:
		TK.act("light_attack")
	return false


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			stage.camera_rig.rotation.y = 0.0
			p.unequip_weapon()
			p.progression.owned["u_meteor"] = true
			stage.dummy.get_node("Hurtbox").hit_received.connect(func(h, _a): taken += h.damage)
			until = TK.wait_secs(0.6)
		1:
			p.global_position = stage.dummy.global_position + Vector3(0, 0, 3.5)
			p.reset_physics_interpolation()
			p.player_model.rotation.y = 0.0
			TK.act("ready_weapon")
			until = TK.wait_secs(0.5)
		2:
			TK.press("jump")
			until = TK.wait_ticks(1)
		3:
			until = TK.wait_ticks(20)
		4:
			TK.release("jump")
			until = TK.wait_secs(6.0)
		5:
			print("   plunges %d  longest in the air %.2f s  damage %.0f" % [plunges, max_air, taken])
			check("mashing attack in the air, you still land soon (%.2f s up at most)" % max_air, max_air < 2.6)
			check("the air attacks reach the foe (%.0f)" % taken, taken > 0.0)
			return TK.done(fails)
	step += 1
	return false
