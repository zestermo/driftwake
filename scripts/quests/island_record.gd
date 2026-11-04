class_name IslandRecord
extends RefCounted
## (1.30, docs/v1_30_plan.md round 9) What a generated island offers and how much of it the crew has done: the notice
## board's page (NoticeBoardScreen) and its tests. Read from the crew's shared state only (the held map's fog and found
## spots, the crew's journal, world flags), so every captain, host or guest, reads the same numbers.
##   "explored" 0..1: the share of the island's land fog cells the crew has seen (MapFog)
##   "main": {"title", "giver", "state" (ask / on / report / done), "goal", "poster"} the island's arc ({} without one)
##   "side": [done, total] every other quest of the island (people's, the board's bounties, encounters, finds)
##   "pois": [found, total] and "found": the names found (MapIsles' spots)
##   "bounties": [{"id", "title", "poster", "place", "reward", "notice", "state" (open / on / report / done), "at"}],
##   newest first
##   "folk": [{"who", "where", "what", "wants", "state" (has / on / report / done)}] the people with work or wanting things

const LAND_Y := 0.5


static func of(isl: GenIsland) -> Dictionary:
	var gm: Node = isl.get_node("/root/GameManager")
	var j: Node = isl.get_node("/root/Journal")
	var d := MapIsles.of(isl)
	var land := land_cells(d)
	var grid := MapFog.grid(gm, d)
	var seen := 0
	for c in land:
		if grid[c] != 0:
			seen += 1
	var found: Array = (d["spots"] as Array).filter(func(s): return MapFog.found(gm, str(d["key"]), str(s["id"]))).map(func(s): return str(s["name"]))
	var out := {"explored": float(seen) / float(maxi(land.size(), 1)), "pois": [found.size(), (d["spots"] as Array).size()], "found": found,
		"main": {}, "side": [0, 0], "bounties": [], "folk": []}
	var life = isl.life
	if life == null or life.quest_node == null:
		return out
	var arc = life.arc
	if arc != null and is_instance_valid(arc):
		var k: String = arc.key
		out["main"] = {"title": str(arc.def["title"]), "giver": str(arc.def["giver"]), "state": _state(j, k, "ask"), "poster": arc.fill(arc.T["poster"]),
			"goal": j.goal(k) if j.has(k) else "Ask %s what troubles %s" % [arc.def["giver"], isl.island_name]}
	var qs: Array = life.quest_node.quests
	out["side"] = [qs.filter(func(q): return j.is_done(str(q["id"]))).size(), qs.size()]
	for i in range(life.notices.size() - 1, -1, -1):
		var q: Dictionary = life.notices[i]
		out["bounties"].append({"id": q["id"], "title": q["title"], "poster": q["giver"], "place": _place(life, q), "reward": QuestRewards.text(q["reward"]),
			"notice": q["notice"], "state": _state(j, str(q["id"]), "open"), "at": q["poi"]})
	for q in qs:
		if str(q["src"]) == "board" or (str(q["src"]) == "found" and not j.has(str(q["id"]))):
			continue
		var cost: Array = q.get("cost", [])
		var e := {"who": str(q["giver"]), "where": life._where(life.folk[q["giver_i"]]) if q.has("giver_i") else "", "what": str(q["title"]),
			"wants": "Wants %s" % QuestRewards._item_text(cost[0]) if not cost.is_empty() else "", "state": _state(j, str(q["id"]), "has")}
		out["folk"].append(e)
	return out


## A quest's state for the board: `fresh` (not taken yet), "on", "report" (to whoever gave it), "done".
static func _state(j: Node, id: String, fresh: String) -> String:
	if not j.has(id):
		return fresh
	if j.is_done(id):
		return "done"
	return "report" if j.at_turnin(id) else "on"


## Where a bounty is, by the map's name for the place nearest it.
static func _place(life, q: Dictionary) -> String:
	var d := MapIsles.of(life.isl)
	var at: Vector2 = q["poi_at"]
	var best := ""
	var bd := INF
	for s in d["spots"]:
		var dd := at.distance_to(s["at"])
		if dd < bd:
			bd = dd
			best = str(s["name"])
	return best


## The island's land under the held map's fog (cell indices whose middles are above the sea), worked out once.
static func land_cells(d: Dictionary) -> PackedInt32Array:
	if d.has("land"):
		return d["land"]
	var isl: Island = d["isl"]
	var n := int(d["n"])
	var o: Vector2 = (d["rect"] as Rect2).position
	var out := PackedInt32Array()
	for z in range(n):
		for x in range(n):
			if isl.hv(o + Vector2(x + 0.5, z + 0.5) * MapIsles.FOG_CELL) > LAND_Y:
				out.append(z * n + x)
	d["land"] = out
	return out
