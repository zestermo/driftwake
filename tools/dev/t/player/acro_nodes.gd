extends SceneTree
## The Acrobatics map's smaller nodes (1.30) do what they say: Twin Dash a second air dash, Air Control faster steering
## in the air (+10% a step), Aerial Combo a longer air combo, Hang Time half the fall while attacking in the air, Wall
## Kick a second wall jump, Feather Fall no hurt under 12 m, Swift Step's steps a cheaper dodge, and the Footwork nodes
## wait for Swift Step or Long Stride.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var pr
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


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			pr = p.progression
			var st = p.state_machine.states["fall"]
			pr.owned["ac_airdash"] = true
			pr._dirty()
			check("Air Dash: one dash", st.air_dashes_left() == 1)
			pr.owned["ac_twindash"] = true
			pr._dirty()
			check("Twin Dash: two", st.air_dashes_left() == 2)
			var a0: float = st.air_speed()
			pr.steps["ac_aircontrol"] = 2
			pr._dirty()
			check("Air Control x2: +20%% steering in the air (%.2f -> %.2f)" % [a0, st.air_speed()], is_equal_approx(st.air_speed(), a0 * 1.2))
			var c0: int = st.air_combo_max()
			pr.owned["ac_aircombo"] = true
			pr._dirty()
			check("Aerial Combo: one hit longer", st.air_combo_max() == c0 + 1)
			pr.owned["ac_walljump"] = true
			pr.owned["ac_wallkick"] = true
			pr._dirty()
			check("Wall Jump and Wall Kick: two wall jumps", int(pr.stat("wall_jumps")) == 2)
			var d0: float = p.dodge_cost()
			pr.gift("adventure", 10)
			while pr.mastery_level("acrobatics") < 12:
				pr.add_mastery("acrobatics", pr.mastery_to_next(pr.mastery_level("acrobatics"), "acrobatics"))
			check("Breakfall waits for Swift Step or Long Stride (%s)" % pr.buy_why("ac_breakfall"), pr.buy_why("ac_breakfall") == "Needs Swift Step or Long Stride first")
			check("...Swift Step's steps: a cheaper dodge, then Breakfall opens", pr.buy("m_swift") and pr.buy("m_swift") and p.dodge_cost() < d0 and pr.buy("ac_breakfall"))
			check("Rebound needs Wall Kick and Air Dash (%s)" % pr.parent_why("ac_rebound"), pr.parent_why("ac_rebound") == "")
			pr.owned["ac_feather"] = true
			pr._own("ac_featherfall")
			p.global_position.y += 9.0
			p.reset_physics_interpolation()
			p.state_machine.force_state("Fall", {})
			until = TK.wait_secs(0.15)
		1:
			pr.owned["ac_hangtime"] = true
			pr._dirty()
			p.state_machine.force_state("Plunge", {})
			check("Hang Time: on", p.state_machine.states["plunge"]._hang_time())
			until = TK.wait_secs(2.5)
		2:
			var hp: float = p.health_component.current_health
			check("Feather Fall: a 9 m drop doesn't hurt (%.0f / %.0f)" % [hp, p.health_component.max_health], is_equal_approx(hp, p.health_component.max_health))
			return TK.done(fails)
	step += 1
	return false
