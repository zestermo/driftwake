extends GenIsland
## A chain island for the map's tests on the light stage: no build, just what MapIsles reads (a flat
## disc of land at the stage's height, a camp, a village, a waterfall, a cave) at the stage's origin.
## Put it in the stage's world_gen with `add_to(tree)`.


func setup(id: int, r: float) -> void:
	name = "Isle%d" % id
	node = {"id": id, "name": "Stubrock", "theme": "jungle"}
	radius = r
	extent = ceilf((r + MARGIN) * 2.0 / CELL) * CELL
	half = extent * 0.5
	res = int(extent / CELL)
	heights.resize((res + 1) * (res + 1))
	for z in range(res + 1):
		for x in range(res + 1):
			var p := Vector2(x * CELL - half, z * CELL - half)
			heights[z * (res + 1) + x] = 3.0 if p.length() < r else -6.0
	sites = {"village": Vector2(-50, 0), "camp": Vector2(60, 0)}
	places = [{"kind": "waterfall", "at": Vector2(0, 70), "r": 10.0}]
	interiors = [{"kind": "bat_roost", "title": "The Roost", "mouth": Vector2(0, -70)}]
	paths = [PackedVector2Array([Vector2(-50, 0), Vector2(0, 0), Vector2(60, 0)])]


func add_to(tree: SceneTree) -> void:
	var w := tree.get_first_node_in_group("world_gen")
	w.add_child(self)
	w.chain_islands[int(node["id"])] = self
