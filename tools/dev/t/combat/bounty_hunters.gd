extends SceneTree
## Bounty hunters (RivalEncounter.start_ambush, RivalCrews.HUNTERS): no meeting, a shout, and they're all on the
## captain at once; beaten (each one down for good, no retreat), the captain's bounty rises by theirs a hunter and
## they're cleared away a while after.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var e
var b0 := 0
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	# (the meeting and fight, not the walk in: t/combat/rival_walk_in)
	load("res://scripts/ai/rival_encounter.gd").walk_in = false
	stage = TK.stage(self, {})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	var p = stage.player
	match step:
		0:
			p.bounty = 25000
			p.health_component.max_health = 99999.0
			p.health_component.current_health = 99999.0
			b0 = p.bounty
			e = load("res://scripts/ai/rival_encounter.gd").start_ambush(p, 2)
			until = TK.wait_ticks(5)
		1:
			check("an ambush: no meeting, %d hunters all fighting" % e.rivals.size(),
				load("res://scripts/dialogue/cutscene.gd").active == null and e.rivals.size() == 2 and e.phase == "fight"
				and e.rivals.all(func(r): return r.get_node("Brain").order == "fight"))
			check("...named hunters (%s)" % str(e.rivals.map(func(r): return r.net_profile.get("name", ""))), e.rivals.all(func(r): return str(r.net_profile.get("name", "")) in load("res://scripts/ai/rival_crews.gd").HUNTERS["mate_names"]))
			e.rivals[0].health_component.take_damage(99999.0)
			until = TK.wait_secs(0.5)
		2:
			check("one down stays down (no retreat), the fight goes on", e.phase == "fight" and e.rivals[0].current_state_name() == "Downed")
			e.rivals[1].health_component.take_damage(99999.0)
			until = TK.wait_secs(0.5)
		3:
			check("all down: won, the captain's bounty up 1,500 a hunter (%d)" % (p.bounty - b0), e.result == "won" and p.bounty - b0 == 3000)
			until = TK.wait_secs(8.5)
		4:
			check("...and they're cleared away", get_nodes_in_group("rivals").is_empty() and get_first_node_in_group("rival_encounter") == null)
			return TK.done(fails)
	step += 1
	return false
