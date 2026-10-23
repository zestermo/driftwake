extends SceneTree
## Fighting in the water (SwimState's strikes, docs/v1_19_plan.md: your own weapon, slowed): treading water, attack
## draws the weapon and strikes a foe in front (a rival who followed you in); heavy strikes harder and lunges you
## forward; a while after, the weapon goes back.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var r
var hp0 := 0.0
var hp1 := 0.0
var x0 := 0.0
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"water": true, "hud": false})


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
			p.global_position = Vector3(stage.SHORE_X + 10.0, 1.0, 0)
			p.reset_physics_interpolation()
			p.state_machine.force_state("Swim", {"entry_vy": 0.0, "quiet": true})
			p.player_model.rotation.y = -PI * 0.5   # facing +x, out to sea
			until = TK.wait_secs(0.8)
		1:
			check("swimming, the weapon away", p.current_state_name() == "Swim" and not p.armed)
			r = load("res://scripts/ai/rival_duel.gd").spawn(p, 0.0, "cutlass")
			r.global_position = p.global_position + Vector3(1.3, 0.0, 0.0)
			r.reset_physics_interpolation()
			r.get_node("Brain").order = "hold"
			r.health_component.max_health = 500.0
			r.health_component.current_health = 500.0
			until = TK.wait_secs(0.6)
		2:
			r.global_position = p.global_position + Vector3(1.3, 0.0, 0.0)
			r.reset_physics_interpolation()
			hp0 = r.health_component.current_health
			TK.act("light_attack")
			until = TK.wait_secs(0.6)
		3:
			hp1 = r.health_component.current_health
			var sw = p.state_machine.get_node("Swim")
			check("attack in the water: the weapon out, the strike lands (%.0f damage)" % (hp0 - hp1), p.armed and hp1 < hp0 and sw.strikes_landed == 1)
			r.global_position = p.global_position + Vector3(1.3, 0.0, 0.0)
			r.reset_physics_interpolation()
			x0 = p.global_position.x
			TK.act("heavy_attack")
			until = TK.wait_secs(0.7)
		4:
			var hp2: float = r.health_component.current_health
			check("heavy: a harder blow (%.0f vs %.0f)" % [hp1 - hp2, hp0 - hp1], hp1 - hp2 > hp0 - hp1)
			check("...lunging forward (%.2f m)" % (p.global_position.x - x0), p.global_position.x - x0 > 1.0)
			r.queue_free()
			until = TK.wait_secs(3.5)
		5:
			check("a while after: the weapon goes back", not p.armed and p.current_state_name() == "Swim")
			return TK.done(fails)
	step += 1
	return false
