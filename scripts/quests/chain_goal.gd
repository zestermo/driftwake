class_name ChainGoal
extends RefCounted
## The chain's next step (1.30 guidance): what the objective box shows when no quest is followed, and the Captain's
## Log's always-on chain lead. Brinehollow's story while it's on; then Morrow (his log pose), the level the needle
## waits for, "Sail to <island>" along the log pose, and on a chain island its elder's trouble (the arc, untaken),
## the arc's own step (taken), the beast (its fall sets the needle), or the wait. Read from shared state (the chain's
## place and needle, the crew's journal), so every captain sees the same step.
## {"kind": "story" / "chain", "goal", "sub", "who" (the marker's label), "pos" (Vector3.INF: none), "person",
## "head" (what the box calls it), "id" (an arc's journal key, else "")}; {} outside the world.

const DIRS := ["north", "north-east", "east", "south-east", "south", "south-west", "west", "north-west"]


static func next(tree: SceneTree) -> Dictionary:
	var story: Node = tree.root.get_node("Story")
	if story.active():
		var c: Dictionary = story.current()
		return _goal("story", story.goal(), "Brinehollow's tale", str(c.get("who", "")), story.target_pos(), c.has("npc"), "OBJECTIVE")
	var gm: Node = tree.root.get_node("GameManager")
	var chain: Chain = gm.chain()
	var me := tree.get_first_node_in_group("player") as Player
	if chain == null or me == null:
		return {}
	var at := int(gm.chain_at)
	if at < 0 and not me.has_log_pose():
		return _goal("chain", "Defeat Captain Morrow at Redtide Rock", "His log pose points the way past Brinehollow", "Redtide Rock",
			story.place_pos("redtide"), false)
	if at < 0 and me.progression.level < gm.LOG_POSE_LEVEL:
		return _goal("chain", "Grow stronger: the log pose waits for Lv %d" % gm.LOG_POSE_LEVEL,
			"You're Lv %d. Fight, explore and take work round Brinehollow" % me.progression.level, "", Vector3.INF, false)
	if gm.log_pose_set():
		return _sail(chain, at, me.global_position)
	return _on_island(tree, chain.node(at), gm)


static func _sail(chain: Chain, at: int, from: Vector3) -> Dictionary:
	var ids: Array = chain.next_of(at)
	if ids.is_empty():
		return _goal("chain", "The sea's end: the log pose points nowhere further", "", "", Vector3.INF, false)
	var here := Vector2(from.x, from.z)
	var best: Dictionary = chain.node(ids[0])
	for id in ids:
		var n: Dictionary = chain.node(id)
		if here.distance_to(n["pos"]) < here.distance_to(best["pos"]):
			best = n
	var names: Array = ids.map(func(id): return str(chain.node(id)["name"]))
	var p: Vector2 = best["pos"]
	var lead := "Follow the log pose %s  -  %s" % [bearing(here, p), Chain.describe(best)]
	return _goal("chain", "Sail to %s" % " or ".join(names), lead, str(best["name"]), Vector3(p.x, 0.0, p.y), false)


static func _on_island(tree: SceneTree, n: Dictionary, gm: Node) -> Dictionary:
	var name := str(n["name"])
	var wait := "The lodestone sets in %d min" % ceili(gm.log_pose_wait() / 60.0)
	var wg := tree.get_first_node_in_group("world_gen")
	var isl: Node = wg.chain_islands.get(int(n["id"])) if wg else null
	if isl == null or not is_instance_valid(isl):
		return _goal("chain", "Explore %s" % name, wait, name, Vector3.INF, false)
	var arc = isl.life.arc if isl.get("life") != null and isl.life.get("arc") != null else null
	var journal: Node = tree.root.get_node("Journal")
	if arc != null and is_instance_valid(arc) and not journal.has(arc.key):
		return _goal("chain", "Ask %s what troubles %s" % [arc.village.elder_name, name], "Every island has its trouble  -  " + wait.to_lower(),
			arc.village.elder_name, _npc_at(tree, arc.village.elder_name), true)
	if arc != null and is_instance_valid(arc) and not journal.is_done(arc.key):
		var g := _goal("chain", journal.goal(arc.key), "%s  -  %s's trouble" % [arc.def["title"], name], str(arc.def["title"]),
			journal.target(arc.key), journal.target_is_person(arc.key))
		g["id"] = arc.key
		return g
	var arena := isl.get_node_or_null("Site_boss/Arena") as Node3D
	if arena:
		var b = arena.get("boss")
		var who: String = str(b.boss_name) if b != null and is_instance_valid(b) and b.get("boss_name") != null else "the island's beast"
		return _goal("chain", "Slay %s" % who, "Its fall sets the log pose on  -  " + wait.to_lower(), who.capitalize(), arena.global_position, false)
	return _goal("chain", "Explore %s" % name, wait, name, Vector3.INF, false)


static func _npc_at(tree: SceneTree, who: String) -> Vector3:
	for p in tree.get_nodes_in_group("npcs"):
		if (p as NPC).npc_name == who:
			return (p as Node3D).global_position + Vector3.UP * KitQuests.HEAD
	return Vector3.INF


## A compass word for the way from `from` to `to` (world x/z; north is -z).
static func bearing(from: Vector2, to: Vector2) -> String:
	var d := to - from
	return DIRS[int(round(fposmod(atan2(d.x, -d.y), TAU) / (TAU / 8.0))) % 8]


static func _goal(kind: String, goal: String, sub: String, who: String, pos: Vector3, person: bool, head := "OBJECTIVE  -  THE CHAIN") -> Dictionary:
	return {"kind": kind, "goal": goal, "sub": sub, "who": who, "pos": pos, "person": person, "head": head, "id": ""}
