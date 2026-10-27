extends SceneTree
## Stamina gates the heavies (each costs more while fatigued, an empty bar refuses one), regenerates, and a dodge
## costs it; each weapon has its own heavy (the cutlass a thrust, the axe the whirlwind).
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var heavies := 0
var seen := {}
var s0 := 0.0
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


func _process(_d: float) -> bool:
	if p != null and p.body_model.current_action() != "":
		seen[p.body_model.current_action()] = true
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			check("stamina starts full (%.0f of %.0f: worn gear adds to it)" % [p.stamina, p.max_stamina], is_equal_approx(p.stamina, p.max_stamina))
			until = TK.wait_secs(0.3)
		1:
			# spam heavies until the bar can't pay for the next one
			if p.current_state_name() == "HeavyAttack":
				return false
			if heavies < 6:
				TK.act("heavy_attack")
				heavies += 1
				until = TK.wait_ticks(7)
				return false
		2:
			check("cutlass heavy is a thrust", seen.has("thrust") and not seen.has("heavy"))
			var cost: float = p.state_machine.current_state.heavy_cost()
			check("stamina ran out (%.1f, a heavy costs %.1f now)" % [p.stamina, cost], p.stamina < cost)
			# (regen may have crept back to half the cost, which is enough to try)
			p.stamina = minf(p.stamina, cost * 0.4)
			TK.act("heavy_attack")
			until = TK.wait_ticks(6)
		3:
			check("empty bar refuses a heavy (state %s)" % p.current_state_name(), p.current_state_name() != "HeavyAttack")
			until = TK.wait_secs(3.5)
		4:
			check("stamina regenerates (%.1f)" % p.stamina, p.stamina > 90.0)
			s0 = p.stamina
			TK.act("dodge")
			until = TK.wait_ticks(3)
		5:
			check("dodge costs stamina (%.1f -> %.1f)" % [s0, p.stamina], p.stamina <= s0 - p.DODGE_COST + 0.5)
			until = TK.wait_secs(3.0)
		6:
			var axe = ItemDB.get_item("boarding_axe")
			p.inventory_component.add_item(axe, 1)
			p.equip_weapon(axe, true)
			seen.clear()
			until = TK.wait_secs(0.8)
		7:
			TK.act("heavy_attack")
			until = TK.wait_secs(1.2)
		8:
			check("axe heavy is the whirlwind", seen.has("axe_whirl"))
			return TK.done(fails)
	step += 1
	return false
