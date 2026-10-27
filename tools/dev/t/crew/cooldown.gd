extends SceneTree
## A crew technique used can't be used again until its cooldown (90 s; 60 s for the quick ones) runs out; the HUD
## badge shows it; once it's out C works again.
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


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			p.unequip_weapon()
			p.learn_black_leg()
			TK.act("ready_weapon")
			until = TK.wait_secs(0.7)
		1:
			check("used: %s" % p.crew_tech.trigger(), p.current_state_name() == "CrewTechnique")
			check("black leg's is a 90 s one", is_equal_approx(p.crew_tech.cooldown_len, 90.0))
			check("Pincer and Covering Fire are quick (60 s)", p.crew_tech.cooldown_of("pincer") == 60.0 and p.crew_tech.cooldown_of("covering_fire") == 60.0)
			until = TK.wait_secs(3.5)
		2:
			var cd: float = p.crew_tech.cooldown
			check("the cooldown runs on game time (%.1f)" % cd, cd < 87.0 and cd > 80.0)
			check("again while cooling: refused (%s)" % p.crew_tech.trigger(), p.current_state_name() != "CrewTechnique")
			p.crew_tech.cooldown = 0.05
			until = TK.wait_secs(0.6)
		3:
			check("cooled down: C works again (%s)" % p.crew_tech.trigger(), p.current_state_name() == "CrewTechnique")
			return TK.done(fails)
	step += 1
	return false
