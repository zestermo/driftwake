extends SceneTree
## A named Admiralty hunter (RivalCrews.ADMIRALTY, RivalEncounter's squad): the officer and marines in the grey turn up,
## the meeting plays and skips, then the whole squad fights at once (no duels); the officer hurt badly withdraws
## (they never die: they'll be back), the captain's bounty rises by a hunter's, and it's on the record.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var e
var b0 := 0
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
	var p = stage.player
	var gm := root.get_node("GameManager")
	match step:
		0:
			gm.rivals.clear()
			p.bounty = 70000
			p.health_component.max_health = 99999.0
			p.health_component.current_health = 99999.0
			e = load("res://scripts/ai/rival_encounter.gd").start(p, "vael")
			until = TK.wait_secs(0.4)
		1:
			var off = e.rivals[-1]
			var marines: Array = e.rivals.slice(0, e.rivals.size() - 1)
			check("Commander Vael and a squad of marines turn up (%d)" % e.rivals.size(),
				str(off.net_profile.get("name", "")) == "Commander Idris Vael" and marines.size() >= 2 and e.squad())
			check("...the marines in the grey", marines.all(func(m): return str(m.net_profile.get("name", "")).begins_with("Marine") and m.body_model.look["top_color"].r < 0.5))
			check("...the meeting plays", load("res://scripts/dialogue/cutscene.gd").active != null)
			TK.act("interact")
			until = TK.wait_ticks(4)
		2:
			check("then the whole squad at once (no duels)", e.phase == "fight" and e.rivals.all(func(r): return r.get_node("Brain").order == "fight"))
			b0 = p.bounty
			var off = e.rivals[-1]
			off.health_component.take_damage(off.health_component.max_health * 0.75)
			until = TK.wait_ticks(3)
		3:
			check("the officer hurt badly withdraws (they'll be back)", e.phase == "retreat" and e.result == "won" and e.rivals[-1].get_node("Brain").order == "flee")
			check("...the captain's bounty up a hunter's (%d)" % (p.bounty - b0), p.bounty - b0 == 12000)
			check("...on the record", int(gm.rivals["vael"]["won"]) == 1 and int(gm.rivals["vael"]["met"]) == 1)
			gm.rivals.clear()
			return TK.done(fails)
	step += 1
	return false
