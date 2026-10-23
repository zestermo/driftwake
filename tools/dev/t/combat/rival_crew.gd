extends SceneTree
## A rival crew's visit (RivalEncounter, RivalCrews): the crew turns up (mates, the captain last, tougher), the meeting
## plays as a cutscene and skips; duels in turn (one on the captain, the rest resting; alone, a short gauntlet: one mate
## of two, then the captain); their
## captain hurt badly enough calls the retreat (they flee, the record says won, they're gone after); met again it
## picks the grudge lines, and beating the captain spares them (downed, not dead), plunders a quarter of the gold and
## they get back up once the crew's gone.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var e
var first
var gold0 := 0
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


func enc() -> Script:
	return load("res://scripts/ai/rival_encounter.gd")


func gm() -> Node:
	return root.get_node("GameManager")


func fighting() -> Array:
	return e.rivals.filter(func(r): return is_instance_valid(r) and r.get_node("Brain").order == "fight")


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			gm().rivals.clear()
			e = enc().start(p, "brine_wolves")
			until = TK.wait_secs(0.4)
		1:
			var cap = e.rivals[-1]
			check("the crew turns up: %d rivals, the captain last (%s)" % [e.rivals.size(), cap.net_profile.get("name", "")],
				e.rivals.size() == 3 and str(cap.net_profile.get("name", "")) == "Haskel Rourke" and cap.is_in_group("rivals"))
			check("...their captain's the toughest (%.0f vs %.0f)" % [cap.health_component.max_health, e.rivals[0].health_component.max_health],
				cap.health_component.max_health > e.rivals[0].health_component.max_health)
			var c = load("res://scripts/dialogue/cutscene.gd").active
			check("the meeting plays as a cutscene (%d shots)" % (c.shots.size() if c else 0), c != null and c.kind == "rival_meet" and c.shots.size() >= 4)
			check("...the first meeting's lines, and it's on the record", e.moment == "meet" and int(gm().rivals["brine_wolves"]["met"]) == 1)
			TK.act("interact")
			until = TK.wait_ticks(4)
		2:
			var f := fighting()
			check("skipped, the duels begin: one rival on the captain (%d), the rest watching" % f.size(),
				e.phase == "fight" and f.size() == 1 and f[0].get_node("Brain").target == p and f[0] != e.rivals[-1])
			first = f[0]
			first.health_component.take_damage(99999.0)
			until = TK.wait_secs(0.6)
		3:
			var f := fighting()
			# (alone, a shorter gauntlet: with two mates, one of them, then their captain; the other stays at their work)
			var other = e.rivals[0] if e.rivals[0] != first else e.rivals[1]
			check("one down: alone, their captain's next (first %s %.0f hp, fighting %s), the other mate still resting (%s)" % [first.current_state_name(),
				first.health_component.current_health, str(f.map(func(r): return r.name)), other.get_node("Brain").order],
				first.current_state_name() == "Downed" and f.size() == 1 and f[0] == e.rivals[-1] and other.get_node("Brain").order == "rest")
			until = TK.wait_ticks(2)
		4:
			var f := fighting()
			check("their captain comes last", f.size() == 1 and f[0] == e.rivals[-1])
			var cap = e.rivals[-1]
			cap.health_component.take_damage(cap.health_component.max_health * 0.75)
			until = TK.wait_ticks(3)
		5:
			check("hurt badly, their captain calls the retreat: they flee", e.phase == "retreat" and e.result == "won"
				and e.rivals.all(func(r): return r.get_node("Brain").order == "flee"))
			check("...on the record as won", int(gm().rivals["brine_wolves"]["won"]) == 1)
			check("...and the captain's bounty rose (%d)" % p.bounty, p.bounty >= 3000)
			until = TK.wait_secs(6.5)
		6:
			check("...and they're gone", get_nodes_in_group("rivals").is_empty() and get_first_node_in_group("rival_encounter") == null)
			p.inventory_component.add_item(ItemDB.get_item("gold"), 100)
			gold0 = p.inventory_component.count("gold")
			p.bounty = 25000
			e = enc().start(p, "brine_wolves")
			until = TK.wait_secs(0.3)
		7:
			check("met again after a loss of theirs: the grudge lines (%s)" % e.moment, e.moment == "grudge_lost")
			var c = load("res://scripts/dialogue/cutscene.gd").active
			var said: Array = c.shots.filter(func(s): return s.has("say")).map(func(s): return str(s["say"]["text"]))
			check("...a notorious captain: they come stronger (%d of them) and talk about the bounty" % e.rivals.size(),
				e.rivals.size() == 4 and said.any(func(t): return "25,000" in t or "poster" in t))
			TK.act("interact")
			until = TK.wait_ticks(4)
		8:
			var hd := HitData.new()
			hd.damage = 99999.0
			p.hurtbox.take_hit(hd, fighting()[0] if not fighting().is_empty() else e.rivals[0])
			until = TK.wait_secs(0.6)
		9:
			check("beaten by a rival crew: downed, not dead (%s)" % p.current_state_name(), p.current_state_name() == "Downed")
			var g: int = p.inventory_component.count("gold")
			check("...they plunder a quarter of the gold (%d -> %d)" % [gold0, g], g == gold0 - int(floor(gold0 * 0.25)))
			check("...on the record as lost", e.phase == "plunder" and int(gm().rivals["brine_wolves"]["lost"]) == 1)
			until = TK.wait_secs(7.5)
		10:
			check("they go, and the captain gets back up (%.0f hp, %s)" % [p.health_component.current_health, p.current_state_name()],
				get_nodes_in_group("rivals").is_empty() and p.health_component.current_health > 0.0)
			return TK.done(fails)
	step += 1
	return false
