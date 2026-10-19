extends SceneTree
## Tinkering aboard (anchored): mallet and lock in hand, each interval tunes your kit a while longer: a spare
## shot loaded, quicker reloads, a little more bite, wearing off in game time; saved with the captain.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var pr
var ship
var DT
var shots0 := 0
var reload0 := 0.0
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "ship": true, "weapon": "pistol"})


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
			ship = stage.ship
			DT = load("res://scripts/game/downtime.gd")
			ship.set_anchored(true)
			p.global_position = ship.global_transform * Vector3(0, ship.DECK_Y + 0.3, 0.0)
			p.reset_physics_interpolation()
			until = TK.wait_ticks(10)
		1:
			shots0 = p.max_ammo()
			reload0 = p.reload_time()
			DT.start(p, "tinker")
			until = TK.wait_ticks(20)
		2:
			check("tinkering: sat with mallet and lock (%s)" % p.body_model.current_action(), p.current_state_name() == "Downtime" and p.body_model.current_action() == "dt_tinker")
			p.state_machine.current_state._earned = DT.every(p, "tinker") - 0.1
			until = TK.wait_secs(0.3)
		3:
			check("an interval of tinkering tunes the kit (%.0f s)" % pr.kit_left, absf(pr.kit_left - DT.KIT_PER) < 1.0)
			check("...a spare shot (%d -> %d)" % [shots0, p.max_ammo()], p.max_ammo() == shots0 + 1)
			check("...quicker reloads (%.2f -> %.2f)" % [reload0, p.reload_time()], p.reload_time() < reload0 - 0.05)
			var d: Dictionary = pr.to_dict()
			pr.from_dict({})
			check("...forgotten on a blank load", pr.kit_left == 0.0)
			pr.from_dict(d)
			check("...and saved with the captain", absf(pr.kit_left - DT.KIT_PER) < 1.0)
			p.state_machine.force_state("Idle", {})
			pr.kit_left = 0.2
			until = TK.wait_secs(0.5)
		4:
			check("it wears off in game time", pr.kit_left == 0.0 and p.max_ammo() == shots0)
			return TK.done(fails)
	step += 1
	return false
