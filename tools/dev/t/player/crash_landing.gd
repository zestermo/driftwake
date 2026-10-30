extends SceneTree
## Acrobatics' landing variant (15): Crash Landing slams you down on a knee and a fist from a long drop, knocks the
## foe beside you off its feet and halves the fall's hurt with no stagger; switched to Featherfall, the same drop
## hurts a quarter as much and knocks nobody down.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var pr
var g
var hp0 := 0.0
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false,
		"grunts": [{"post": Vector3(1.8, 0, 0), "yaw": 0.0, "mode": "stand", "seed": 37, "role": "sword"}]})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func drop() -> void:
	hp0 = p.health_component.current_health
	p.global_position.y += 8.0
	p.reset_physics_interpolation()
	p.velocity = Vector3.ZERO
	p.state_machine.force_state("Fall", {})


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			pr = p.progression
			g = stage.camp.grunts[0]
			g.set_physics_process(false)   # (stands still, but its hurtbox stays in the world)
			pr.owned["ac_feather"] = true
			pr.versions["ac_feather"] = 1
			pr._own("ac_crash")
			until = TK.wait_secs(0.3)
		1:
			drop()
			until = TK.wait_secs(1.2)
		2:
			var lost: float = hp0 - p.health_component.current_health
			print("   crash: lost %.1f; grunt hp %.1f/%.1f, at %s, me %s" % [lost, g.health.current_health, g.health.max_health, g.global_position, p.global_position])
			check("landed in the crash (%s)" % p.body_model.current_action(), p.body_model.current_action() == "crash_land")
			check("the fall hurt half as much (%.1f)" % lost, lost > 8.0 and lost < 16.0)
			check("no stagger", p.current_state_name() != "Stagger")
			check("the grunt beside you is knocked down or reels (1.25.1 poise) (state %d)" % g.state, g.state in [9, 10, 11])
			pr._switch("ac_feather", 0)
			check("switched to Featherfall", pr.has_flag("featherfall") and not pr.has_flag("crash_landing"))
			until = TK.wait_secs(2.5)
		3:
			drop()
			until = TK.wait_secs(1.2)
		4:
			var lost: float = hp0 - p.health_component.current_health
			print("   featherfall: lost %.1f" % lost)
			check("Featherfall: a quarter of the hurt (%.1f)" % lost, lost > 3.0 and lost < 8.0)
			check("no crash", p.body_model.current_action() != "crash_land")
			return TK.done(fails)
	step += 1
	return false
