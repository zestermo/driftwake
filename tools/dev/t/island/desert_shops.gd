extends SceneTree
## 1.26: in a theme with its own store model (the desert), the village traders' shops and the unique place are that
## store dressed for their trade (KitShops: forge, armour stands, bolts of cloth, lutes, bottles; the place's own room),
## not the general store's shelves; the trader stands behind their counter.
const TK := preload("res://tools/dev/test_kit.gd")
const WORLD := "extends Node\nvar c\nvar chain_islands := {}\nvar starter_island = null\nfunc _ready():\n\tadd_to_group(\"world_gen\")\nfunc chain():\n\treturn c\nfunc chain_ready():\n\treturn true\nfunc standing(_i):\n\treturn true\n"
var stage
var world
var isl
var v
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _verts(n: Node) -> int:
	var m: Mesh = (n.get_node("Furnishing") as MeshInstance3D).mesh
	var c := 0
	for s in range(m.get_surface_count()):
		c += (m.surface_get_arrays(s)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	return c


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			var DT = load("res://scripts/props/desert_town.gd")
			var store = DT.room("trade", 7, 6.0)
			var plain := _verts(store)
			var differ := []
			for k in load("res://scripts/island/kit/kit_shops.gd").KINDS:
				var room = DT.room(k, 7, 6.0)
				if _verts(room) != plain and room.has_node("Vendor") and room.has_node("Customer"):
					differ.append(k)
				room.free()
			store.free()
			check("every trade and place has its own desert room, dressed, with its keeper's spot (%d of 13)" % differ.size(), differ.size() == 13)
			var U = load("res://scripts/island/unique_places.gd")
			U.force = "dojo"
			load("res://scripts/island/village_layouts.gd").force = "town"
			isl = _island()
			U.force = ""
			load("res://scripts/island/village_layouts.gd").force = ""
			v = isl.get_node("Site_village/Village")
			until = TK.wait_secs(1.0)
		1:
			var shops: Array = v.buildings.filter(func(b): return b["kind"] == "vshop")
			print("   theme %s, shops %s" % [isl.theme, shops.map(func(b): return b["trade"])])
			check("a desert village with trader shops (%d)" % shops.size(), isl.theme == "desert" and shops.size() > 0)
			var kept := 0
			for b in shops:
				var vend: Vector3 = b["node"].get_node("Vendor").global_position
				for p in isl.life.people:
					if str(p.npc_name).begins_with(load("res://scripts/island/village_vendors.gd").TRADES[b["trade"]]["title"]) and p.global_position.distance_to(vend) < 2.0:
						kept += 1
			check("...each trader behind their own counter (%d)" % kept, kept == shops.size())
			var place: Array = v.buildings.filter(func(b): return b["kind"] == "unique")
			check("...and the dojo in a desert room of its own", place.size() == 1 and place[0]["node"].has_node("Furnishing") and place[0]["node"].has_node("RoomMesh"))
			return TK.done(fails)
	step += 1
	return false


func _island():
	var stub: Node = stage.get_node("NoIslands")
	stub.remove_from_group("world_gen")
	var s := GDScript.new()
	s.source_code = WORLD
	s.reload()
	world = Node.new()
	world.set_script(s)
	world.name = "Islands"
	stage.add_child(world)
	world.c = load("res://scripts/world/chain.gd").make(77, Vector2.ZERO, Vector2(0, -1))
	var n: Dictionary = world.c.node(int(world.c.start_next[0])).duplicate(true)
	n["theme"] = "desert"
	n["seed"] = 9300
	var t = load("res://scripts/island/themes/island_themes.gd").of("desert")
	n.merge({"beast": t.bosses[0], "beast_look": 0, "beast_name": "Old Grumble", "minis": [t.minis[0]], "roamer": t.roamers[0], "landmarks": [], "landmark_count": 0}, true)
	load("res://scripts/island/island_theme.gd").meshes("desert")
	var gi = load("res://scripts/island/gen_island.gd").new()
	gi.name = "DesertShops"
	gi.position = Vector3(5000.0, 0, 0)
	world.add_child(gi)
	gi.build(n)
	return gi
