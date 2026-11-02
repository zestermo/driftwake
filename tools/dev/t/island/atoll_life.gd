extends SceneTree
## The coral atoll's life (atoll_theme.gd's roster, atoll_shoals.gd, AtollSpots): its rolls bring coconut crabs and
## boobies (nothing guaranteed) on top of the shore crabs; both build and stand; built on an atoll, shoals of fish
## circle under the lagoon's water (a GPU MultiMesh each, ranged, unshadowed) and gulls wheel over it; the coral heads'
## spear spots are deep enough for spearfishing (SpearSchool.DEEP_M).
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var fails := 0
var step := 0
var until := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			var FS = load("res://scripts/island/fauna_spawner.gd")
			var crabs := 0
			var big := 0
			var birds := 0
			for s in range(30):
				var r: Dictionary = FS.roll("atoll", s * 101)
				crabs += 1 if r.has("crab") else 0
				big += 1 if r.has("coconut_crab") else 0
				birds += 1 if r.has("toucan") else 0
			check("shore crabs on nearly every atoll, coconut crabs and boobies on most, not all (%d, %d, %d of 30)" % [crabs, big, birds], crabs >= 27 and big > 15 and big < 30 and birds > 12 and birds < 30)
			var cc = FS.make("atoll", "coconut_crab")
			cc.setup(Vector3(4, 0.5, -6), {"lead": true, "pack": 1})
			cc.name = "CoconutCrab"
			stage.add_child(cc)
			var bb = FS.make("atoll", "toucan")
			bb.setup(Vector3(-4, 0.5, -6), {"anchor": Vector3(-4, 4.0, -6)})
			bb.name = "Booby"
			stage.add_child(bb)
			until = TK.wait_ticks(10)
		1:
			var cc = stage.get_node("CoconutCrab")
			var bb = stage.get_node("Booby")
			check("a coconut crab and a booby build and stand (%s, %s)" % [cc.kind, bb.kind], cc.kind == "coconut_crab" and bb.kind == "booby"
				and cc.model.get_child_count() > 0 and bb.model.get_child_count() > 0)
			var v = load("res://scripts/island/themes/island_themes.gd").of("atoll")
			var c = load("res://scripts/world/chain.gd").make(11, Vector2.ZERO, Vector2(0, -1))
			var n: Dictionary = c.node(int(c.start_next[0])).duplicate(true)
			n["theme"] = "atoll"
			n.merge({"beast": v.bosses[0], "beast_look": 0, "beast_name": "x", "minis": [v.minis[0]], "roamer": v.roamers[0]}, true)
			load("res://scripts/island/island_theme.gd").meshes("atoll")
			var isl = load("res://scripts/island/gen_island.gd").new()
			isl.prepare(n)
			isl.name = "AtollLife"
			stage.add_child(isl)
			for s in isl._theme.steps(isl):
				s[1].call()
			var shoals: Node3D = isl.get_node("AtollShoals")
			var fish: Array = shoals.get_children().filter(func(m): return m.name.begins_with("Shoal"))
			var wet := fish.filter(func(m): return m.position.y < 0.0 and float(isl.hv(Vector2(m.position.x, m.position.z))) < m.position.y - 0.4)
			check("shoals of fish circle under the lagoon's water (%d, %d under)" % [fish.size(), wet.size()], fish.size() >= 5 and wet.size() == fish.size())
			check("...each a ranged, unshadowed MultiMesh", fish.all(func(m): return m is MultiMeshInstance3D and m.visibility_range_end > 0.0 and m.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF))
			check("gulls wheel over the lagoon", shoals.get_children().any(func(m): return m.name.begins_with("Gulls") and m.position.y > 8.0))
			var heads: Array = get_nodes_in_group("spear_spots").filter(func(mk): return mk.get_meta("where") == "heads")
			var deep := heads.filter(func(mk): return float(mk.get_meta("depth")) > 2.5)
			check("the coral heads' spear spots are deep enough to spearfish (%d of %d)" % [deep.size(), heads.size()], heads.is_empty() or deep.size() >= heads.size() - 1)
			isl.queue_free()
			return TK.done(fails)
	step += 1
	return false
