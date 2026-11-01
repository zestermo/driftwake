extends SceneTree
## The burst launcher (1.28, a ship gadget): built, it takes no belt slot; at the wheel U fires it (a charge, its
## cooldown), flinging her forward by the tier's speed, which the drag bleeds back off in a few seconds; fired again
## on its cooldown it's refused.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var ship
var v0 := 0.0
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "ship": true})


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
			ship = stage.ship
			p.gadgets.give("burst_launcher", 1)
			check("fitted to the ship, not on the belt", not "burst_launcher" in p.gadgets.slots)
			p.global_position = ship.to_global(Vector3(0.5, 0.6, 3.0))
			p.reset_physics_interpolation()
			until = TK.wait_ticks(5)
		1:
			p.current_ship = ship
			p.state_machine.force_state("Helm", {})
			ship.sail = 1.0
			ship.sail_shown = 1.0
			until = TK.wait_secs(4.0)
		2:
			v0 = ship.speed
			TK.act("gadget_fire")
			until = TK.wait_ticks(2)
		3:
			var imp: float = GadgetData.tier_val("burst_launcher", "impulse", 1)
			check("at the wheel U fires it: flung forward (%.1f -> %.1f m/s)" % [v0, ship.speed], ship.speed > v0 + imp * 0.85)
			check("...a charge spent, its cooldown running", p.gadgets.charges("burst_launcher") == GadgetData.tier_val("burst_launcher", "charges", 1) - 1 and p.gadgets.cooldown_left("burst_launcher") > 0.0)
			TK.act("gadget_fire")
			until = TK.wait_ticks(2)
		4:
			check("fired again on its cooldown: refused", p.gadgets.charges("burst_launcher") == GadgetData.tier_val("burst_launcher", "charges", 1) - 1)
			until = TK.wait_secs(5.0)
		5:
			check("the drag bleeds the burst off (%.1f m/s)" % ship.speed, ship.speed < ship.MAX_SPEED * 1.3)
			return TK.done(fails)
	step += 1
	return false
