extends SceneTree
## (1.30, the collision audit) Every building a captain can climb or land on is solid where it's drawn: each builder is
## placed in the air off the stage and rays straight down every 0.5 m over it find the mesh's top and the colliders'
## top. A gap (the drawn top more than 0.35 m over the collider's, or nothing to stand on) and a false ceiling (a
## collider 0.5 m+ over what's drawn) each stay under 4% of the rays: roofs, porch roofs, awnings, canopies, domes,
## chimneys, parapets and tower roofs all have shapes (the kit's jungle houses, Buildings, the snow's and the desert's
## houses, the harbour's warehouse and boathouse, the lookout tower, the stalls).
const TK := preload("res://tools/dev/test_kit.gd")
const STEP := 0.5
const GAP := 0.35
const CEIL := 0.5
const MAX_SHARE := 0.04
var stage
var step := 0
var until := 0
var fails := 0
var models: Array = []


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _make() -> Array:
	var KH = load("res://scripts/island/kit/kit_houses.gd")
	var B = load("res://scripts/props/buildings.gd")
	var SP = load("res://scripts/props/snow_props.gd")
	var HM = load("res://scripts/island/kit/kit_harbour_models.gd")
	var DT = load("res://scripts/props/desert_town.gd")
	var KL = load("res://scripts/island/kit/kit_landmarks.gd")
	return [
		["jungle home (hip)", KH.room({"seed": 1, "roof": "hip"})],
		["jungle cookhouse (gable)", KH.room({"seed": 2, "roof": "gable", "kind": "cook"})],
		["jungle workshop", KH.workshop({"seed": 3})],
		["jungle shrine", KH.shrine({"seed": 4})],
		["jungle granary", KH.storehouse({"seed": 5})],
		["village well", KH.well()],
		["village gate", KH.gate()],
		["house with a porch", B.house({"seed": 7, "porch": 1.6})],
		["house with a lean-to and chimney", B.house({"seed": 8, "lean_to": "left", "chimney": true})],
		["house with an awning", B.house({"seed": 9, "awning": "red"})],
		["two-storey house", B.house({"seed": 10, "floors": 2})],
		["snow round house", SP.round_house(1, 6.0)],
		["snow tall round house", SP.round_house(2, 7.0, 2)],
		["snow store", SP.storehouse(3)],
		["snow workshop", SP.workshop(4)],
		["snow shrine", SP.shrine(5)],
		["harbour warehouse", HM.warehouse({"w": 8.0, "d": 10.0, "h": 4.0, "found": 0.5, "seed": 1, "wall": "planks", "roof": "thatch"})],
		["desert house with a dome", DT.house({"w": 6.0, "d": 5.0, "storeys": 2, "dome": 1.0, "seed": 3, "name": "H"})],
		["desert house (one storey)", DT.house({"w": 7.0, "d": 6.0, "storeys": 1, "dome": 0.0, "seed": 4, "name": "H2"})],
		["desert home", DT.room("home", 4, 6.0)],
		["desert inn", DT.inn(5, 10.0, 8.0)],
		["desert workshop", DT.workshop(6, 7.0)],
		["desert shrine", DT.shrine(7)],
		["desert granary", DT.storehouse(8, 6.0)],
		["desert hall", DT.great_hall(9)],
		["desert watchtower", DT.watchtower(10)],
		["desert hideout", DT.bandit_hut(11)],
		["fish stall", B.stall("fish")],
		["fruit stall", B.stall("fruit")],
		["cloth stall", B.stall("cloth")],
		["pot cart", B.stall("pots")],
		["lookout tower", KL.lookout_tower(6.0)],
	]


## [rays over the mesh, gaps, false ceilings, the first gap's spot]
func _scan(n: Node3D) -> Array:
	var tris := PackedVector3Array()
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var xf: Transform3D = (mi as MeshInstance3D).global_transform
		for v in (mi as MeshInstance3D).mesh.get_faces():
			tris.append(xf * v)
	var box := AABB(tris[0], Vector3.ZERO)
	for v in tris:
		box = box.expand(v)
	var space := root.world_3d.direct_space_state
	var rays := 0
	var ceils := 0
	var open := {}
	var x := box.position.x + STEP * 0.5
	while x < box.end.x:
		var z := box.position.z + STEP * 0.5
		while z < box.end.z:
			var top := -INF
			var from := Vector3(x, box.end.y + 1.0, z)
			for i in range(0, tris.size(), 3):
				var hit = Geometry3D.ray_intersects_triangle(from, Vector3.DOWN, tris[i], tris[i + 1], tris[i + 2])
				if hit != null:
					top = maxf(top, (hit as Vector3).y)
			if top > -INF:
				rays += 1
				var col := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * (box.size.y + 3.0), 2049))
				var cy: float = col["position"].y if not col.is_empty() else -INF
				# (a ray right on a box's edge slips past it: look a hand's width round)
				for o in [Vector3(0.1, 0, 0), Vector3(-0.1, 0, 0), Vector3(0, 0, 0.1), Vector3(0, 0, -0.1)]:
					if top - cy > GAP:
						var c2 := space.intersect_ray(PhysicsRayQueryParameters3D.create(from + o, from + o + Vector3.DOWN * (box.size.y + 3.0), 2049))
						if not c2.is_empty():
							cy = maxf(cy, c2["position"].y)
				if top - cy > GAP:
					open[Vector2i(roundi(x / STEP), roundi(z / STEP))] = "(%.1f, %.1f) drawn %.2f, solid %.2f" % [x - n.global_position.x, z - n.global_position.z,
						top - n.global_position.y, cy - n.global_position.y]
				elif cy - top > CEIL:
					ceils += 1
			z += STEP
		x += STEP
	# (a gap counts when its neighbour is one too: a lone ray is a pole, a finial or a torch's head)
	var gaps := 0
	var first := ""
	for k in open:
		if [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)].any(func(o): return open.has(k + o)):
			gaps += 1
			if first == "":
				first = open[k]
	return [rays, gaps, ceils, first]


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			models = _make()
			for i in range(models.size()):
				var n: Node3D = models[i][1]
				n.position = Vector3(400.0 + (i % 6) * 40.0, 60.0, (i / 6) * 40.0)
				stage.add_child(n)
			until = TK.wait_ticks(4)
		1:
			for m in models:
				var r := _scan(m[1])
				var share := float(r[1]) / maxf(float(r[0]), 1.0)
				var ceil_share := float(r[2]) / maxf(float(r[0]), 1.0)
				check("%s is solid where it's drawn (%d rays: %d gaps%s, %d false ceilings)" % [m[0], r[0], r[1], (" first at " + str(r[3])) if r[1] > 0 else "", r[2]],
					r[0] > 10 and share < MAX_SHARE and ceil_share < MAX_SHARE)
			return TK.done(fails)
	step += 1
	return false
