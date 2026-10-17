extends SceneTree
## The forest's set pieces on islands made forest: the chain's volcano vent is a ruined castle (its curtain wall and
## towers solid, a gate toward its trail, the keep you climb inside to its chest, outlaws camped in the courtyard),
## its great tree the hollow giant tree (the trunk solid round its hollow, a doorway, a cavern of three chambers
## behind it with its rock solid, what lives there, a hoard in the end chamber and a chest on the perch up its
## bracket-fungus stair), and its cenote the waterfall gorge (big falls on the island's first river, a pool, the
## cave beside the curtain with its hoard, rope bridges rim to rim). The jungle keeps the chain's own; the same node
## plans the same places.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _node(setpiece: String, landmarks: Array) -> Dictionary:
	var f = load("res://scripts/island/themes/island_themes.gd").of("forest")
	var c = load("res://scripts/world/chain.gd").make(5, Vector2.ZERO, Vector2(0, -1))
	var n: Dictionary = c.node(int(c.start_next[0])).duplicate(true)
	n["theme"] = "forest"
	n.merge({"beast": f.bosses[0], "beast_look": 0, "beast_name": "x", "minis": [f.minis[0]], "roamer": f.roamers[0],
		"setpiece": setpiece, "landmarks": landmarks, "landmark_count": landmarks.size()}, true)
	return n


func _built(n: Dictionary, label: String):
	var isl = load("res://scripts/island/gen_island.gd").new()
	isl.prepare(n)
	isl.name = label
	stage.add_child(isl)
	for s in load("res://scripts/island/fauna_spawner.gd").steps(isl):
		s[1].call()
	for s in load("res://scripts/island/kit/kit_landmarks.gd").steps(isl):
		s[1].call()
	return isl


func _solid(node: Node) -> int:
	return node.find_children("*", "CollisionShape3D", true, false).size()


func _process(_d: float) -> bool:
	if not stage.up:
		return false
	var IT = load("res://scripts/island/themes/island_themes.gd")
	var f = IT.of("forest")
	check("the forest stands its own in for the chain's: castle, gorge, hollow tree; the jungle keeps the chain's",
		f.place_kind("volcano_vent") == "forest_castle" and f.place_kind("old_fort") == "forest_castle" and f.place_kind("cenote") == "forest_gorge"
		and f.place_kind("great_tree") == "forest_hollow_tree" and IT.of("jungle").place_kind("great_tree") == "")
	load("res://scripts/island/island_theme.gd").meshes("forest")
	# the castle and the hollow tree
	var n := _node("volcano_vent", ["great_tree"])
	var a = load("res://scripts/island/gen_island.gd").new()
	a.prepare(n.duplicate(true))
	var kinds: Array = a.places.map(func(pl): return str(pl["kind"]))
	print("places %s" % [kinds])
	check("the vent is a ruined castle, the great tree the hollow tree %s" % [kinds], kinds.has("forest_castle") and kinds.has("forest_hollow_tree")
		and not kinds.has("volcano_vent") and not kinds.has("great_tree"))
	var b = load("res://scripts/island/gen_island.gd").new()
	b.prepare(n.duplicate(true))
	check("the same node plans the same places and ground", str(b.places.map(func(pl): return [pl["kind"], pl["at"]])) == str(a.places.map(func(pl): return [pl["kind"], pl["at"]])) and b.heights == a.heights)
	a.free()
	b.free()
	var isl = _built(n, "CastleIsland")
	var castle: Node3D = isl.get_node("Place_forest_castle")
	var walls: Node3D = castle.get_node("CastleWalls")
	var keep: Node3D = castle.get_node("Keep")
	var crew = castle.get_node("Outlaws")
	check("the castle: its wall and towers solid (%d), the keep climbable with its chest, outlaws in the courtyard (%d)" % [_solid(walls), crew.specs.size() if crew else 0],
		_solid(walls) > 20 and _solid(keep) > 25 and not castle.find_children("*", "LootBag", true, false).is_empty() and crew.specs.size() >= 4)
	var tree: Node3D = isl.get_node("Place_forest_hollow_tree")
	var cav: Node3D = tree.get_node("RootCavern")
	var chests := tree.find_children("*", "LootBag", true, false).size()
	var creatures: int = cav.find_children("*", "Creature", true, false).size() + isl.get_node("Fauna").find_children("*", "Creature", true, false).filter(func(c): return (c as Node3D).global_position.distance_to(tree.global_position) < 30.0).size()
	check("the hollow tree: its trunk solid (%d), the cavern's rock solid, a hoard below and a chest on the perch (%d), what lives there (%d)" % [_solid(tree.get_node("HollowTree")), chests, creatures],
		_solid(tree.get_node("HollowTree")) > 30 and _solid(cav.get_node("CavernRock")) == 1 and chests == 2 and creatures >= 2)
	isl.queue_free()
	# the gorge
	var g = _built(_node("cenote", []), "GorgeIsland")
	var pls: Array = g.places.filter(func(pl): return pl["kind"] == "forest_gorge")
	check("the cenote is the waterfall gorge, on falls the land made for it (%s)" % [g.places.map(func(pl): return pl["kind"])], pls.size() == 1 and g.land_plan["gorge"])
	if pls.size() == 1:
		var pl: Dictionary = pls[0]
		var gn: Node3D = g.get_node("Place_forest_gorge")
		var cave: Node3D = gn.get_node("GorgeCave")
		check("the falls drop %.1f m into their pool; the cave beside them solid with its hoard; %d rope bridges" % [float(pl["falls"]["drop"]), (pl["bridges"] as Array).size()],
			float(pl["falls"]["drop"]) >= 5.0 and _solid(cave.get_node("CaveRock")) == 1 and gn.find_children("*", "LootBag", true, false).size() >= 1
			and not (pl["bridges"] as Array).is_empty() and _solid(gn.get_node("GorgeBridges")) > 0)
	g.queue_free()
	return TK.done(fails)
