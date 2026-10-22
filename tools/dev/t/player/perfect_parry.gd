extends SceneTree
## Defense: a parry staggers a grunt 1.5 s; with Clean Parry a perfect one (the moment the guard goes up) staggers it
## 2.4 s, a late one still 1.5. The perfect-parry variant (16): Disarm flings its blade (hidden, 7 s with no guard,
## a spare after), Shove throws it off its feet.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var pr
var g
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "weapon": "cutlass",
		"grunts": [{"post": Vector3(0, 0, -1.6), "yaw": 0.0, "mode": "stand", "seed": 37, "role": "sword"}]})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func reset() -> void:
	g._set_state(3)  # CIRCLE
	g._disarm_t = 0.0
	g._stagger_len = 0.0
	g.humanoid.weapon.visible = true
	p.state_machine.force_state("Idle", {})


## Parry, and the grunt's blow lands `late` s after the guard went up.
func parry() -> void:
	p.state_machine.force_state("Parry", {})


func blow() -> void:
	p.hurtbox.take_hit(g._hit_light, g)


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			pr = p.progression
			g = stage.camp.grunts[0]
			g.set_physics_process(false)
			p.health_component.max_health = 99999.0
			p.health_component.current_health = 99999.0
			until = TK.wait_secs(0.4)
		1:
			reset()
			parry()
			blow()
			check("a parry staggers it 1.5 s (state %d, %.1f)" % [g.state, g._stagger_len], g.state == 9 and absf(g._stagger_len - 1.5) < 0.01)
			reset()
			pr._own("df_clean")
			parry()
			blow()
			check("Clean Parry: a perfect parry staggers it 2.4 s (%.1f)" % g._stagger_len, g.state == 9 and absf(g._stagger_len - 2.4) < 0.01)
			check("...no disarm without the variant", g._disarm_t <= 0.0)
			reset()
			parry()
			until = TK.wait_secs(0.2)
		2:
			p.state_machine.current_state.timer = 0.2
			blow()
			check("a late parry: the usual 1.5 s (%.1f)" % g._stagger_len, absf(g._stagger_len - 1.5) < 0.01)
			reset()
			pr.owned["df_perfect"] = true
			pr._own("df_disarm")
			until = TK.wait_ticks(2)
		3:
			parry()
			blow()
			check("Disarm: its blade flies (%.1f s, hidden %s)" % [g._disarm_t, not g.humanoid.weapon.visible], g._disarm_t > 6.0 and not g.humanoid.weapon.visible)
			check("...the disarm flick plays (%s)" % p.body_model.current_action(), p.body_model.current_action() == "parry_disarm")
			var hp0: float = g.health.current_health
			g._set_state(3)
			p.state_machine.force_state("Idle", {})
			g.hurtbox.take_hit(p.melee_hit(10.0), p)
			check("...and it can't guard bare-handed (%.0f -> %.0f)" % [hp0, g.health.current_health], g.health.current_health < hp0)
			g._disarm_tick(8.0)
			check("...a spare blade after", g._disarm_t <= 0.0 and g.humanoid.weapon.visible)
			until = TK.wait_secs(0.6)
		4:
			reset()
			g.humanoid.end_ragdoll()
			pr._switch("df_perfect", 1)
			check("switched to Shove", pr.has_flag("parry_shove") and not pr.has_flag("parry_disarm"))
			parry()
			blow()
			check("Shove: thrown off its feet (state %d)" % g.state, g.state == 11)
			check("...the shove plays (%s)" % p.body_model.current_action(), p.body_model.current_action() == "parry_shove")
			return TK.done(fails)
	step += 1
	return false
