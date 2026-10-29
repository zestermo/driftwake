extends SceneTree
## A captain's own poise (1.26, docs/v1_26_plan.md "Combat knockback"): a knockdown blow drains it and staggers you;
## only when it runs out are you floored, and then nothing floors you again for Poise.IMMUNE s; a grunt's red-glow
## blow (poise 999) floors you whole. The throw is soft (a few m/s), not across the yard.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func blow(poise := -1.0) -> void:
	var hd = load("res://scripts/combat/hit_data.gd").new()
	hd.damage = 1.0
	hd.knockdown = true
	hd.knockback_force = 9.0
	hd.poise = poise
	p.hurtbox.take_hit(hd, null)


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			p.health_component.max_health = 99999.0
			p.health_component.current_health = 99999.0
			blow()
			until = TK.wait_ticks(2)
		1:
			check("one knockdown blow: staggered, still on your feet (%s)" % p.current_state_name(), p.current_state_name() == "Stagger")
			until = TK.wait_secs(0.6)
		2:
			blow()
			until = TK.wait_ticks(2)
		3:
			check("a second before it refills: poise broken, floored (%s)" % p.current_state_name(), p.current_state_name() == "Downed")
			check("...thrown softly (%.1f m/s across)" % Vector2(p._last_hit_velocity.x, p._last_hit_velocity.z).length(), Vector2(p._last_hit_velocity.x, p._last_hit_velocity.z).length() <= 4.6)
			until = TK.wait_secs(2.5)
		4:
			blow(999.0)
			until = TK.wait_ticks(2)
		5:
			check("up again inside the grace: even the red glow doesn't floor you (%s)" % p.current_state_name(), p.current_state_name() != "Downed")
			until = TK.wait_secs(4.5)
		6:
			blow(999.0)
			until = TK.wait_ticks(2)
		7:
			check("after the grace: the red glow floors you outright (%s)" % p.current_state_name(), p.current_state_name() == "Downed")
			return TK.done(fails)
	step += 1
	return false
