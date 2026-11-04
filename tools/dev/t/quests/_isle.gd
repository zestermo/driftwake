extends RefCounted
## t/quests' generated island (1.30 landing and board tests, boardshot): the stage's world stand-in taken over with a
## real chain (t/capital/_world.gd), the chain's first island built whole far off as a jungle isle of seed `seed_`,
## registered as standing, and the crew put on it (GameManager.chain_at, the needle unset).


static func build(stage: Node, seed_: int, at := Vector3(3000, 0, 0)) -> Node3D:
	var w: Node = load("res://tools/dev/t/capital/_world.gd").take_over(stage, 4242)
	var t = load("res://scripts/island/themes/island_themes.gd").of("jungle")
	var id := int(w.c.start_next[0])
	var n: Dictionary = w.c.node(id)
	n["theme"] = "jungle"
	n["seed"] = seed_
	n.merge({"beast": t.bosses[0], "beast_look": 0, "beast_name": "Old Grumble", "minis": [t.minis[0]], "roamer": t.roamers[0], "landmarks": [], "landmark_count": 0}, true)
	var isl = load("res://scripts/island/gen_island.gd").new()
	isl.name = "Isle%d" % id
	isl.position = at
	stage.add_child(isl)
	isl.build(n)
	w.chain_islands[id] = isl
	var gm: Node = stage.get_node("/root/GameManager")
	gm.chain_at = id
	gm.chain_set = false
	gm.chain_since = stage.get_node("/root/Weather").world_time()
	return isl


## World point of island point p (on its ground).
static func world(isl: Node3D, p: Vector2) -> Vector3:
	return isl.to_global(Vector3(p.x, isl.hv(p), p.y))
