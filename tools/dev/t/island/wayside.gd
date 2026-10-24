extends SceneTree
## What lies along the way between places (KitWayside, 1.20), on a chain island of each theme: things beside the paths
## (enough of them to give the ways shape), none of their solid parts on a path (walkers keep their ways), a lone chest
## or more on the island, and the same seed lays the same wayside.
const TK := preload("res://tools/dev/test_kit.gd")
## [chain seed whose first island is that theme (smoketest -- list), the theme]
const THEMES := [["snow", 1], ["desert", 2], ["forest", 5], ["any", 12]]
var stage
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _island(theme: String, seed_v: int):
	var c = load("res://scripts/world/chain.gd").make(seed_v, Vector2.ZERO, Vector2(0, -1))
	var n: Dictionary = c.node(int(c.start_next[0])).duplicate(true)
	var gi = load("res://scripts/island/gen_island.gd").new()
	gi.prepare(n)
	return gi


## [collider centres (island space), vertex count, chests] of the island's wayside, built.
func _wayside(gi) -> Array:
	load("res://scripts/island/kit/kit_wayside.gd").build(gi)
	var cols: Array = []
	var body: Node = gi.get_node("WaysideBody")
	for cs in body.get_children():
		if cs is CollisionShape3D:
			cols.append(Vector2((cs as CollisionShape3D).position.x, (cs as CollisionShape3D).position.z))
	var mi: MeshInstance3D = gi.get_node("Wayside")
	var verts := 0
	if mi.mesh:
		for s in range(mi.mesh.get_surface_count()):
			verts += (mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	var chests: int = gi.find_children("*", "LootBag", true, false).size()
	return [cols, verts, chests]


func _process(_d: float) -> bool:
	if not stage.up:
		return false
	for e in THEMES:
		var gi = _island(e[0], e[1])
		var w := _wayside(gi)
		var cols: Array = w[0]
		var on_path := 0
		for q in cols:
			for path in gi.paths:
				for pt in (path as PackedVector2Array):
					if pt.distance_to(q) < 1.8:
						on_path += 1
						break
		check("%s: things beside its ways (%d solid, %d verts), none on a path (%d)" % [gi.theme, cols.size(), w[1], on_path], cols.size() >= 8 and on_path == 0)
		check("%s: a lone chest or more (%d)" % [e[0], w[2]], w[2] >= 1)
		var again := _wayside(_island(e[0], e[1]))
		check("%s: the same seed lays the same wayside" % e[0], again[1] == w[1] and (again[0] as Array).size() == cols.size())
		gi.free()
	return TK.done(fails)
