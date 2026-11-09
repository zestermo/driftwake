extends SceneTree
## A Hooded Stranger's lead (2026-11-09): buying it puts "The Stranger's Secret" in the crew's journal, followed at
## once, its marker on the strongbox from anywhere (the city unloaded, out at sea), and it's done when the strongbox
## is opened. A second lead for the same strongbox adds nothing; an opened one gets no quest.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var step := 0
var until := 0
var fails := 0
const KEY := "test_cache_7"
const AT := Vector3(420.0, 12.0, -380.0)


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
	var j: Node = root.get_node("Journal")
	var gm: Node = root.get_node("GameManager")
	var id := "cache_lead_" + KEY
	match step:
		0:
			p = stage.player
			CityCaches._journal(self, KEY, AT, "Port Regal", -1)
			until = TK.wait_ticks(4)
		1:
			check("the lead is a quest in the journal", j.has(id) and not j.is_done(id))
			check("...followed at once", j.tracked == id)
			check("its marker on the strongbox (%s)" % j.target(id), j.target(id).distance_to(AT) < 0.01)
			check("its goal names the city: %s" % j.goal(id), "Port Regal" in j.goal(id))
			CityCaches._journal(self, KEY, AT, "Port Regal", -1)
			until = TK.wait_ticks(4)
		2:
			check("a second lead adds nothing (%d)" % j.active().filter(func(e): return e["id"] == id).size(),
				j.active().filter(func(e): return e["id"] == id).size() == 1)
			gm.opened[KEY] = true
			until = TK.wait_secs(2.5)
		3:
			check("the strongbox opened: the quest's done", j.is_done(id))
			CityCaches._journal(self, "test_cache_8", AT, "", -1)
			gm.opened["test_cache_9"] = true
			CityCaches._journal(self, "test_cache_9", AT, "", -1)
			until = TK.wait_ticks(4)
		4:
			check("a lead with no city still reads (%s)" % j.goal("cache_lead_test_cache_8"), j.has("cache_lead_test_cache_8"))
			check("an opened strongbox gets no quest", not j.has("cache_lead_test_cache_9"))
			return TK.done(fails)
	step += 1
	return false
