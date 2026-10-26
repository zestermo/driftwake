extends SceneTree
## The Will hooks the paths set through Progression stats (1.23): the Sense flash's timing and kinds (flash_early,
## flash_shots, flash_boss), Crowd Read (foes that aren't after you flash within 20 m, anywhere for 4 s after a perfect
## dodge), Slow Sight (a perfect dodge slows time, a Foresight dodge no longer does), Far Roar (roar_reach widens the
## roar) and Inner Strike (a heavy is a breaker). The stats are put straight into the stat cache: buying them is
## will_paths' business.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var pr
var near
var far
var step := 0
var until := 0
var fails := 0
var hp0 := 0.0
var blow := false


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "weapon": "cutlass",
		"grunts": [{"post": Vector3(0, 0, -1.8), "yaw": 0.0, "mode": "stand", "seed": 37, "role": "sword"},
			{"post": Vector3(0, 0, -18.0), "yaw": 0.0, "mode": "stand", "seed": 38, "role": "sword"}]})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func give(key: String, v: float = 1.0) -> void:
	pr.stat(key)
	pr._stats[key] = v


func _physics_process(_d: float) -> bool:
	if blow:
		near.global_position = p.global_position + Vector3(0, 0, -1.5)
		near.hitbox.activate()
		give("foresight_slow", 0.6)
		give("crowd_read")
	return false


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			pr = p.progression
			near = stage.camp.grunts[0]
			far = stage.camp.grunts[1]
			p.health_component.max_health = 99999.0
			p.health_component.current_health = 99999.0
			check("no Sense, no flash", near._sense_delay("melee", true) == -1.0)
			give("observation")
			check("Flash: an attack flashes a moment after it starts (%.2f)" % near._sense_delay("melee", true), is_equal_approx(near._sense_delay("melee", true), near.SENSE_LATE))
			check("...shots and bosses' big moves don't", near._sense_delay("shot", true) == -1.0 and near._sense_delay("big", true) == -1.0)
			give("flash_early")
			check("Long Warning: right at its start", near._sense_delay("melee", true) == 0.0)
			give("flash_shots")
			check("Gunsight: a shot flashes", near._sense_delay("shot", true) == 0.0 and near._sense_delay("big", true) == -1.0)
			give("flash_boss")
			check("Big Moves: a boss's special flashes", near._sense_delay("big", true) == 0.0)
			check("a foe that isn't after you doesn't flash", near._sense_delay("melee", false) == -1.0)
			give("crowd_read")
			check("Crowd Read: one within 20 m flashes", near._sense_delay("melee", false) == 0.0)
			far.global_position = near.global_position + Vector3(0, 0, -30.0)
			check("...a far one doesn't", far._sense_delay("melee", false) == -1.0)
			p.power.add_buff("crowd_sight", 4.0)
			check("...unless a perfect dodge just showed them all", far._sense_delay("melee", false) == 0.0)
			p.power.buffs["crowd_sight"] = 0.0
			give("flash_early", 0.0)
			far.global_position = stage.camp.global_position + Vector3(0, 0, -18.0)
			until = TK.wait_ticks(3)
		1:
			var tech = p.state_machine.get_node("Technique")
			tech._pc = p.power
			hp0 = far.health.current_health
			tech._conquer()
			check("the roar doesn't reach 18 m", far.health.current_health == hp0)
			give("roar_reach", 0.5)
			tech._conquer()
			check("Far Roar: it does (%.0f -> %.0f)" % [hp0, far.health.current_health], far.health.current_health < hp0)
			var heavy = p.state_machine.get_node("HeavyAttack")
			heavy.cfg = heavy.STYLES[heavy.STYLES.keys()[0]]
			check("a heavy isn't a breaker", not heavy._hit(false).breaker)
			give("inner_strike")
			check("Inner Strike: it is", heavy._hit(false).breaker)
			until = TK.wait_ticks(2)
		2:
			if Engine.time_scale < 1.0:
				return false
			p.power.add_buff("foresight", 5.0)
			p.power.foresight_charges = 1
			give("foresight_slow", 0.6)
			check("a Foresight dodge", p.power.use_foresight())
			check("...doesn't slow time any more (%.2f)" % Engine.time_scale, Engine.time_scale == 1.0)
			p.state_machine.force_state("Idle", {})
			blow = true
			TK.act("dodge")
			until = TK.wait_ticks(4)
		3:
			blow = false
			var dd = p.state_machine.get_node("Dodge")
			check("Slow Sight: a perfect dodge slows time (%.2f, %s, perfect %s, near %s, dist %.1f, active %s, timer %.2f)" % [Engine.time_scale, p.current_state_name(), str(dd._perfect), str(dd._blow_near()), near.global_position.distance_to(p.global_position), str(near.hitbox.active), dd.timer], Engine.time_scale < 0.9)
			check("Crowd Read: ...and shows every foe for 4 s", p.power.buff("crowd_sight"))
			return TK.done(fails)
	step += 1
	return false
