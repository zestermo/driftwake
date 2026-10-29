extends SceneTree
## (1.26) In the air the buttons split: left-click is the weapon's aerial (Boarding Dive once bought, its alternate when
## switched on), right-click the plain plunge until the aerial heavy is bought at mastery 10, then the aerial heavy.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var pr
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "weapon": "cutlass"})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func to_level(tree: String, lv: int) -> void:
	while pr.mastery_level(tree) < lv:
		var m: Dictionary = pr.mastery_of(tree)
		pr.add_mastery(tree, pr.mastery_to_next(int(m["lv"])) - int(m["xp"]))


## Up in the air, falling, free to attack; then `button` pressed.
func lift(button: String) -> void:
	p.global_position += Vector3(0, 4.0, 0)
	p.reset_physics_interpolation()
	p.velocity = Vector3.ZERO
	p.air_uses.clear()
	p.stamina = 999.0
	p.state_machine.force_state("Fall", {})
	TK.act(button)


func mode() -> String:
	var st = p.state_machine.current_state
	return str(st.id) if p.current_state_name() == "Technique" else (str(st._mode) if p.current_state_name() == "Plunge" else "")


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			pr = p.progression
			pr.discover("sword")
			to_level("sword", 9)
			pr.gift("sword", 30)
			check("Boarding Dive bought", pr.buy("s_dive"))
			check("mastery 9: the aerial heavy not yet (%s)" % pr.buy_why("s_airheavy"), pr.buy_why("s_airheavy") == "Needs Cutlass 10")
			lift("heavy_attack")
			until = TK.wait_ticks(4)
		1:
			check("right-click in the air before it: the plain plunge (%s '%s')" % [p.current_state_name(), mode()], p.current_state_name() == "Plunge" and mode() == "")
			until = TK.wait_secs(1.5)
		2:
			if not p.is_free() or not p.is_on_floor():
				return false
			lift("light_attack")
			until = TK.wait_ticks(4)
		3:
			check("left-click in the air: Boarding Dive (%s '%s')" % [p.current_state_name(), mode()], p.current_state_name() == "Plunge" and mode() == "boarding_dive")
			until = TK.wait_secs(1.5)
		4:
			if not p.is_free() or not p.is_on_floor():
				return false
			to_level("sword", 10)
			check("mastery 10: the aerial heavy bought", pr.buy("s_airheavy"))
			lift("heavy_attack")
			until = TK.wait_ticks(4)
		5:
			check("right-click in the air: Whirlpool Descent (%s '%s')" % [p.current_state_name(), mode()], mode() == "whirlpool_descent")
			until = TK.wait_secs(1.5)
		6:
			if not p.is_free() or not p.is_on_floor():
				return false
			lift("light_attack")
			until = TK.wait_ticks(4)
		7:
			check("left-click still Boarding Dive (%s '%s')" % [p.current_state_name(), mode()], mode() == "boarding_dive")
			until = TK.wait_secs(1.5)
		8:
			if not p.is_free() or not p.is_on_floor():
				return false
			to_level("sword", 8)
			check("the aerial alternate switched on", pr.set_version("s_alt_air", 1))
			lift("light_attack")
			until = TK.wait_ticks(4)
		9:
			check("left-click: the alternate, Anchor Drop (%s '%s')" % [p.current_state_name(), mode()], mode() == "anchor_drop")
			until = TK.wait_secs(1.5)
		10:
			if not p.is_free() or not p.is_on_floor():
				return false
			to_level("sword", 20)
			check("the right-click alternate switched on", pr.set_version("s_alt_heavy", 1))
			p.stamina = 999.0
			TK.act("heavy_attack")
			until = TK.wait_ticks(4)
		11:
			check("right-click: Broadside Sweep (%s '%s')" % [p.current_state_name(), mode()], mode() == "broadside_sweep")
			return TK.done(fails)
	step += 1
	return false
