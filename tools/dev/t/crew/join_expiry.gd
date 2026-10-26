extends SceneTree
## With a crewmate close, C in stance opens the join zone (drawn round you; you stay free to fight) instead of the self
## version; nobody joining in 6 s closes it and costs nothing.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"crew": [{"name": "Mate", "at": Vector3(5, 0, 0)}]})


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
			TK.act("crouch")
			until = TK.wait_ticks(3)
		2:
			var ct = p.crew_tech
			check("a crewmate near: the zone opens (%.1f s)" % ct.offer, ct.offer > 5.5 and ct.offer_id == "skyward_kick")
			check("the zone is drawn", ct._ring != null and ct._ring.visible)
			check("you stay free while it's open (%s)" % p.current_state_name(), p.is_free())
			check("nothing spent yet", ct.cooldown <= 0.0)
			until = TK.wait_secs(6.3)
		3:
			var ct = p.crew_tech
			check("nobody joined: the zone closed", ct.offer <= 0.0 and not ct._ring.visible)
			check("and it cost nothing", ct.cooldown <= 0.0)
			check("C opens it again", ct.trigger() == "offer")
			check("C again while it's open goes alone (%s)" % ct.trigger(), p.current_state_name() == "CrewTechnique" and ct.offer <= 0.0)
			return TK.done(fails)
	step += 1
	return false
