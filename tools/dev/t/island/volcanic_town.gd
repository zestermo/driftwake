extends SceneTree
## The volcanic isle's forge town (scripts/island/themes/volcanic_town.gd, volcanic_tinkerer.gd, volcanic_anvil.gd):
## its traders always count a smith and a parts dealer (the roll fills the rest; other themes' rolls unchanged); built,
## the smiths' yard out of the village toward the mountain, with its forge, two ringing anvils with a smith at each, a
## gadget Workbench and the master tinkerer; he turns a captain without the gold away, and with it teaches a blueprint
## they don't know for his price (Gadgets.teach) and never the same one twice.
const TK := preload("res://tools/dev/test_kit.gd")
const WORLD := "extends Node\nvar c\nvar chain_islands := {}\nvar starter_island = null\nfunc _ready():\n\tadd_to_group(\"world_gen\")\nfunc chain():\n\treturn c\nfunc chain_ready():\n\treturn true\nfunc standing(_i):\n\treturn true\n"
var stage
var fails := 0
var step := 0
var until := 0
var isl


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
			var VV = load("res://scripts/island/village_vendors.gd")
			var KS = load("res://scripts/island/kit/kit_style.gd")
			var r: Array = VV.roll(77, 2, KS.of("volcanic")["vendors_always"])
			check("the forge town's traders start with a smith and a parts dealer %s" % [r], r.slice(0, 2) == ["smith", "parts"] and r.size() >= 2 and r.count("smith") == 1)
			check("...other themes' rolls as before", VV.roll(77, 2) == VV.roll(77, 2, KS.of("jungle")["vendors_always"]))
			var shop: Dictionary = VV.shop("parts", "Gilda")
			check("the parts dealer sells iron and copper (%s)" % [shop["stock"]], (shop["stock"] as Array).any(func(e): return e[0] == "iron"))
			var v = load("res://scripts/island/themes/island_themes.gd").of("volcanic")
			var stub: Node = stage.get_node("NoIslands")
			stub.remove_from_group("world_gen")
			var s := GDScript.new()
			s.source_code = WORLD
			s.reload()
			var world := Node.new()
			world.set_script(s)
			world.name = "Islands"
			stage.add_child(world)
			world.c = load("res://scripts/world/chain.gd").make(5, Vector2.ZERO, Vector2(0, -1))
			var n: Dictionary = world.c.node(int(world.c.start_next[0])).duplicate(true)
			n["theme"] = "volcanic"
			n.merge({"beast": v.bosses[0], "beast_look": 0, "beast_name": v.beasts[v.bosses[0]]["names"][0], "minis": [v.minis[0]], "roamer": v.roamers[0]}, true)
			load("res://scripts/island/island_theme.gd").meshes("volcanic")
			isl = load("res://scripts/island/gen_island.gd").new()
			isl.name = "VolcanicIsland"
			world.add_child(isl)
			isl.position = Vector3(0, 0, -2000)
			isl.prepare(n)
			var forge: Array = isl.places.filter(func(pl): return pl["kind"] == "volcanic_forge")
			check("the smiths' yard is planned", forge.size() == 1)
			if forge.is_empty():
				return TK.done(fails)
			var at: Vector2 = forge[0]["at"]
			var vil: Vector2 = isl.sites["village"]
			var cone: Vector2 = isl.land_plan["cone"]["c"]
			check("...out of the village (%.0f m) on the mountain's side" % at.distance_to(vil), at.distance_to(vil) > 60.0 and at.distance_to(vil) < 130.0
				and (at - vil).dot(cone - vil) > 0.0)
			check("the village life counts a parts dealer and a smith", isl.life.folk.any(func(f): return str(f["role"]) == "vendor:parts")
				and isl.life.folk.any(func(f): return str(f["role"]) == "vendor:smith"))
			isl.make_beasts(n)
			isl._prebuild_beasts()
			isl.finish()
			until = TK.wait_ticks(6)
		1:
			var place: Node3D = isl.get_node("Place_volcanic_forge")
			check("built: the forge, two anvils, a workbench in the forge style, the tinkerer",
				place.get_node_or_null("Forge") != null and place.get_node_or_null("Anvil0") != null and place.get_node_or_null("Anvil1") != null
				and place.find_children("*", "Workbench", false, false).size() == 1 and place.get_node_or_null("Tinkerer") != null)
			var wb = place.find_children("*", "Workbench", false, false)[0]
			check("...the workbench is the forge's", wb.get_meta("opts", {}).get("style", "") == "forge")
			var npcs := place.find_children("*", "NPC", false, false)
			check("...three people: two smiths and the master tinkerer (%s)" % [npcs.map(func(x): return x.npc_name)], npcs.size() == 3
				and npcs.any(func(x): return str(x.npc_name).begins_with("Master Tinkerer")))
			var t = place.get_node("Tinkerer")
			var p = stage.player
			var gold: int = p.inventory_component.count("gold")
			if gold > 0:
				p.inventory_component.remove_item(ItemDB.get_item("gold"), gold)
			var said: String = t.teach(p)
			check("no gold, no blueprint: \"%s\"" % said, said.contains("Come back") and p.inventory_component.count("gold") == 0)
			p.inventory_component.add_item(ItemDB.get_item("gold"), t.price * 3)
			var ids: Array = Gadgets.blueprint_ids()
			var first: String = t.teach(p)
			var paid: int = t.price * 3 - p.inventory_component.count("gold")
			if ids.is_empty():
				check("(no blueprints yet) he has nothing to teach: \"%s\"" % first, first.contains("everything") and paid == 0)
			else:
				check("with the gold he teaches one for %d (paid %d): \"%s\"" % [t.price, paid, first], first.contains("Watch closely") and paid == t.price)
				var second: String = t.teach(p)
				var paid2: int = t.price * 3 - p.inventory_component.count("gold")
				check("...and another one, never the same twice (paid %d)" % paid2, (ids.size() > 1 and paid2 == t.price * 2) or (ids.size() == 1 and second.contains("everything")))
			return TK.done(fails)
	step += 1
	return false
