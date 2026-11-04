extends SceneTree
## 1.30 (round 9): the notice board's island record counts from the crew's shared state: explored % from the held
## map's fog (land cells only), places found of all from the map's spots, side missions done of all the island's
## quests, and the main mission (the island's trouble) by the journal. Nothing of it is per captain.
const TK := preload("res://tools/dev/test_kit.gd")
const ISLE := preload("res://tools/dev/t/quests/_isle.gd")
var stage
var isl
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
			root.get_node("Journal").reset()
			isl = ISLE.build(stage, 9101)
			# (the stage's captain stands far from the island: nothing is seen or found by walking)
			var R = load("res://scripts/quests/island_record.gd")
			var r: Dictionary = R.of(isl)
			var qs: Array = isl.life.quest_node.quests
			print("   fresh: ", r["explored"], " ", r["pois"], " ", r["side"], " ", r["main"].get("state"), " ", r["bounties"].size(), " bounties, ", r["folk"].size(), " folk")
			check("nothing explored yet", r["explored"] == 0.0)
			check("places: none found of several (%s)" % [r["pois"]], r["pois"][0] == 0 and r["pois"][1] >= 4)
			check("side missions: none done of every quest on the island (%s of %d)" % [r["side"], qs.size()], r["side"] == [0, qs.size()] and qs.size() >= 5)
			check("the main mission is the island's trouble, not started (%s)" % r["main"].get("title"), r["main"].get("state") == "ask")
			check("three bounties, each with a place and a reward", r["bounties"].size() == 3 and r["bounties"].all(func(b): return str(b["place"]) != "" and str(b["reward"]).contains("gold")))
			check("the people with work are listed (%d)" % r["folk"].size(), r["folk"].size() >= 2 and r["folk"].all(func(f): return str(f["who"]) != ""))
			var d = load("res://scripts/map/map_isles.gd").of(isl)
			var land: PackedInt32Array = R.land_cells(d)
			var half := PackedInt32Array()
			for i in range(0, land.size(), 2):
				half.append(land[i])
			var net = root.get_node("Net")
			net.fog_reveal(str(d["key"]), int(d["n"]), half)
			net.spot_found(str(d["key"]), str(d["spots"][0]["id"]), str(d["spots"][0]["name"]))
			var j = root.get_node("Journal")
			var q: Dictionary = isl.life.given[0]
			j.take(q["id"])
			j.settle(q["id"])
			j.take(isl.life.arc.key)
			until = TK.wait_ticks(5)
		1:
			var r: Dictionary = load("res://scripts/quests/island_record.gd").of(isl)
			print("   after: ", r["explored"], " ", r["pois"], " ", r["side"], " ", r["main"].get("state"))
			check("half the land seen: about half explored (%.2f)" % r["explored"], absf(r["explored"] - 0.5) < 0.02)
			check("one place found (%s), its name listed" % [r["pois"]], r["pois"][0] == 1 and r["found"].size() == 1)
			check("one side mission done (%s)" % [r["side"]], r["side"][0] == 1)
			check("the main mission under way", r["main"]["state"] == "on")
			var me := isl.life.folk[isl.life.given[0]["giver_i"]]["name"] as String
			check("its giver's row says done", r["folk"].any(func(f): return f["who"] == me and f["state"] == "done"))
			return TK.done(fails)
	step += 1
	return false
