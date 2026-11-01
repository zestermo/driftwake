extends SceneTree
## The smoke screen (1.28, a ship gadget): fired from the wheel, a cloud bank is laid astern and she's hidden in it;
## an enemy ship hunting her loses her (drops the chase) and doesn't take it up again while she's in the smoke; once
## the screen's time is up she can be seen again.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var ship
var es
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
	var SG = load("res://scripts/ship/ship_gadgets.gd")
	match step:
		0:
			p = stage.player
			ship = stage.ship
			ship.hull = 99999.0
			p.health_component.max_health = 99999.0
			p.health_component.current_health = 99999.0
			p.gadgets.give("smoke_screen", 0)
			p.global_position = ship.to_global(Vector3(0.5, 0.6, 3.0))
			p.reset_physics_interpolation()
			until = TK.wait_ticks(5)
		1:
			p.current_ship = ship
			p.state_machine.force_state("Helm", {})
			var ES = load("res://scripts/ship/enemy_ship.gd")
			es = ES.new().setup(ship.global_position + Vector3(70, 0, 0), 30.0, 0.0, 13, "sloop")
			stage.add_child(es)
			es.set_meta("no_sleep", true)
			until = TK.wait_ticks(5)
		2:
			es._set_state(es.S.HUNT)
			check("an enemy ship hunts her (state %d)" % es.state, es.state == es.S.HUNT)
			TK.act("gadget_fire")
			until = TK.wait_secs(0.5)
		3:
			check("the smoke screen's laid: she's hidden in it", SG.hidden(ship))
			check("...the hunter loses her (state %d)" % es.state, es.state != es.S.HUNT and es.state != es.S.BROADSIDE)
			until = TK.wait_secs(2.0)
		4:
			check("...and doesn't take the chase up again in the smoke (state %d)" % es.state, es.state != es.S.HUNT and es.state != es.S.BROADSIDE)
			until = TK.wait_secs(GadgetData.tier_val("smoke_screen", "secs", 0))
		5:
			check("its time up, she can be seen again", not SG.hidden(ship))
			return TK.done(fails)
	step += 1
	return false
