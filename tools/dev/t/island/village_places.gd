extends SceneTree
## 1.25.5 villages: the village traders have shops of their own (a room dressed for the trade, the trader behind the
## counter at every hour), the village has its unique place (its keeper inside: the hot spring heals and buffs for gold,
## the library's Edy point once) and the inn its games (dice for a stake, three wins running: the crew's discount).
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
	stage = TK.stage(self, {})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			var U = load("res://scripts/island/unique_places.gd")
			var seen := {}
			for id in range(8):
				seen[U.roll(77, id)] = true
			check("a chain's first eight villages each have a different place (%d)" % seen.size(), seen.size() == 8)
			U.force = "onsen"
			load("res://scripts/island/village_layouts.gd").force = "town"
			isl = _island()
			U.force = ""
			load("res://scripts/island/village_layouts.gd").force = ""
			v = isl.get_node("Site_village/Village")
			until = TK.wait_secs(1.0)
		1:
			var shops: Array = v.buildings.filter(func(b): return b["kind"] == "vshop")
			var trades: Array = load("res://scripts/island/village_vendors.gd").roll(int(isl.node["seed"]), load("res://scripts/island/island_content.gd").tier(isl))
			print("   traders %s, shops %s" % [trades, shops.map(func(b): return b["trade"])])
			check("every trader has a shop of their own (%d)" % shops.size(), shops.size() == trades.size() and trades.size() > 0)
			var kept := 0
			for b in shops:
				var vend: Vector3 = b["node"].get_node("Vendor").global_position
				for p in isl.life.people:
					if str(p.npc_name).begins_with(load("res://scripts/island/village_vendors.gd").TRADES[b["trade"]]["title"]) and p.global_position.distance_to(vend) < 2.0:
						kept += 1
			check("...each trader behind their counter (%d)" % kept, kept == shops.size())
			check("...the room dressed (a furnishing mesh, a counter to bump)", shops.all(func(b): return b["node"].has_node("Furnishing")))
			var place: Array = v.buildings.filter(func(b): return b["kind"] == "unique")
			check("the village's unique place: the hot spring", place.size() == 1 and place[0]["trade"] == "onsen" and v.unique == "onsen")
			var keeper = null
			for n in isl.get_children():
				if n.get("npc_name") != null and str(n.npc_name).begins_with("Bath-keeper"):
					keeper = n
			check("...its keeper inside", keeper != null and keeper.global_position.distance_to(place[0]["node"].get_node("Vendor").global_position) < 1.0)
			var me = stage.player
			me.inventory_component.add_item(ItemDB.get_item("gold"), 200)
			me.health_component.take_damage(me.health_component.max_health * 0.5)
			var said: String = load("res://scripts/island/unique_places.gd").act(isl, "onsen", "soak", me)
			check("a soak heals and buffs for gold (%s)" % said, me.health_component.current_health >= me.health_component.max_health - 0.5 and str(me.progression.meal) == "hot_spring")
			var w0: int = me.progression.will_earned
			load("res://scripts/island/unique_places.gd").act(isl, "library", "read", me)
			load("res://scripts/island/unique_places.gd").act(isl, "library", "read", me)
			check("the library's Edy point, once", me.progression.will_earned == w0 + 1)
			var tav = v.get_node("Tavern")
			check("the inn's two regulars", tav != null and tav._npcs.size() == 2)
			var rng := RandomNumberGenerator.new()
			rng.seed = 12
			var g0: int = me.inventory_component.count("gold")
			var won: bool = tav.dice(10, rng)
			check("dice for 10 gold: won or lost, the gold follows", me.inventory_component.count("gold") == g0 + (10 if won else -10))
			tav._streak = 0
			for k in range(3):
				tav._settle(true, 10)
			check("three wins running: the crew's discount at the traders", root.get_node("Journal").discount(isl.save_key("trader")) >= 0.1)
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
	n["theme"] = "jungle"
	n["seed"] = 9300
	var t = load("res://scripts/island/themes/island_themes.gd").of("jungle")
	n.merge({"beast": t.bosses[0], "beast_look": 0, "beast_name": "Old Grumble", "minis": [t.minis[0]], "roamer": t.roamers[0], "landmarks": [], "landmark_count": 0}, true)
	var gi = load("res://scripts/island/gen_island.gd").new()
	gi.name = "PlacesIsle"
	gi.position = Vector3(5000.0, 0, 0)
	world.add_child(gi)
	gi.build(n)
	return gi
