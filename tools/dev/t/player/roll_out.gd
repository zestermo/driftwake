extends SceneTree
## (1.31) Roll Out, the landing's third version: a drop tall enough to hurt lands in a long roll (the Dodge state's
## land_roll: further than a dodge), unhurt under Feather Fall's height; a short drop doesn't roll; without the
## skill a tall drop hurts and doesn't roll.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var pr
var step := 0
var until := 0
var fails := 0
var hp0 := 0.0
var from := Vector3.ZERO
var rolled := false


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func drop(h: float) -> void:
	p.health_component.current_health = p.health_component.max_health
	hp0 = p.health_component.current_health
	p.global_position = Vector3(0, stage.GROUND_Y + h, 0)
	p.reset_physics_interpolation()
	p.velocity = Vector3.ZERO
	from = p.global_position
	rolled = false
	p.state_machine.force_state("Fall", {})


func _process(_d: float) -> bool:
	if not stage.up:
		return false
	if p != null and p.current_state_name() == "Dodge":
		rolled = true
	if TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			pr = p.progression
			pr.owned["ac_feather"] = true
			pr.versions["ac_feather"] = 2
			pr._own("ac_rollout")
			check("Roll Out picked", pr.has_flag("land_roll") and not pr.has_flag("crash_landing"))
			until = TK.wait_secs(0.3)
		1:
			drop(11.0)
			until = TK.wait_secs(2.4)
		2:
			var lost: float = hp0 - p.health_component.current_health
			var went := Vector2(p.global_position.x - from.x, p.global_position.z - from.z).length()
			print("  roll: lost %.1f, carried %.1f m" % [lost, went])
			check("a tall drop rolls out", rolled)
			check("...unhurt", lost < 0.5)
			check("...and carries further than a dodge roll (%.1f m)" % went, went > 6.0)
			drop(2.5)
			until = TK.wait_secs(1.4)
		3:
			check("a short drop doesn't roll", not rolled)
			pr.owned.erase("ac_rollout")
			pr.owned.erase("ac_feather")
			pr.versions.erase("ac_feather")

			check("without the skill (roll %s, feather %s)" % [pr.has_flag("land_roll"), pr.has_flag("featherfall")], not pr.has_flag("land_roll") and not pr.has_flag("featherfall"))
			drop(11.0)
			until = TK.wait_secs(2.4)
		4:
			var lost: float = hp0 - p.health_component.current_health
			check("without it a tall drop doesn't roll", not rolled)
			check("...and it hurts (%.1f)" % lost, lost > 1.0)
			return TK.done(fails)
	step += 1
	return false
