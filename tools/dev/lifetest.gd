extends SceneTree
## A chain island's life (IslandLife): 21-31 people (1.23: 2-5 of them traders), villagers on routines that
## follow the world clock (work by day, the inn or the plaza in the evening, home
## at night, walking between), named characters whose dialogue trees talk of the
## island, its beast and the islands ahead, quests of every kind taken, their steps
## done and turned in to the giver (the crew's Journal, ids keyed by the island's
## seed), kept in the save, and the same people and quests from the same seed. The routines again on
## more seeds' first islands (Tikal Atoll's ruins, Mosswater Atoll's walled post).
const SEEDS := [4242, 1, 37]
const TK = preload("res://tools/dev/test_kit.gd")
var more: Array = []
var t := 0.0
var step := 0
var wait := 0.0
var p
var isl
var life
var dlg
var journal
var wx
var fails := 0
var todo: Array = []
var q: Dictionary
var gold0 := 0
var have0 := 0


func _initialize():
	more = TK.seeds_of(SEEDS)
	TK.use_seed(self, int(more.pop_front()))
	change_scene_to_file("res://scenes/world/world.tscn")


func check(name: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + name)
	if not cond: fails += 1


func finish() -> void:
	print("RESULT ", "OK" if fails == 0 else "FAILED (%d)" % fails)
	quit()


func hour_to(h: float) -> void:
	wx.set_world_time(wx.time_at(h))


func put(at: Vector3) -> void:
	p.state_machine.force_state("Idle", {})
	p.global_position = at
	p.velocity = Vector3.ZERO
	p.reset_physics_interpolation()


## Straight to `node` of conversation `id`, as if chosen, then away.
func talk(id: String, node: String) -> void:
	dlg._cooldown = 0.0
	dlg.start(id, null)
	dlg._goto(node)
	dlg._close()
	dlg._cooldown = 0.0


func giver(qq: Dictionary) -> String:
	return life.folk[qq["giver_i"]]["talk"]


func walk_len(v, k: int) -> float:
	var cum: PackedFloat32Array = v.cums[k]
	return cum[cum.size() - 1]


## Its people and their routines (data: no clock runs). Returns those who walk to their lunch.
func _routines(island, tag: String) -> Array:
	var npcs: Array = get_nodes_in_group("npcs").filter(func(x): return x.get_parent() == island)
	print("   %s: %d people: %s" % [island.island_name, npcs.size(), ", ".join(npcs.map(func(x): return x.npc_name))])
	check(tag + "21-31 people on the island, traders included (%d)" % npcs.size(), npcs.size() >= 21 and npcs.size() <= 31)
	check(tag + "each one's name is its own", npcs.all(func(x): return npcs.filter(func(y): return y.name == x.name).size() == 1))
	var vs: Array = island.life.people
	check(tag + "villagers on routines (%d), each with 4-5 stays" % vs.size(), vs.size() >= 11 and vs.all(func(v): return v.stays.size() >= 4 and v.walks.size() == v.stays.size()))
	var kinds := {}
	for v in vs:
		for s in v.stays:
			kinds[s["kind"]] = true
	# (whether the village gives market spots, not the layout's plan: a ruins village plans no market yet can give some)
	var market: bool = island.life.spots.any(func(s): return s["kind"] == "market" and not s.get("poi", false))
	print("   spots used: %s (%s layout, %s market spot)" % [kinds.keys(), island.village_plan["layout"], "a" if market else "no"])
	check(tag + "they work at the market (if the island has one), the nets or the paths, and gather at the plaza and the inn",
		kinds.has("plaza") and kinds.has("inn") and kinds.has("market") == market and (kinds.has("nets") or kinds.has("forage")))
	# day and night, from the routine alone
	var KL = load("res://scripts/island/kit/kit_life.gd")
	var kind_at := func(v, h: float) -> String: return v.stays[KL.stay_at(v.stays, h)[0]]["kind"]
	var shift: Array = vs.filter(func(v): return kind_at.call(v, 10.5) != kind_at.call(v, 23.5))
	var moved := shift.filter(func(v): return (v.spot_at(10.5)[0] as Vector2).distance_to(v.spot_at(23.5)[0]) > 2.0).size()
	print("   the same kind of place day and night: %s" % [vs.filter(func(v): return not shift.has(v)).map(func(v): return kind_at.call(v, 10.5))])
	# (a fifth keep house by day, home day and night, and an owl who works the plaza spends the evening there)
	check(tag + "day and night most are somewhere else (%d of %d; the rest work where they spend the evening)" % [moved, vs.size()], moved == shift.size() and moved > vs.size() / 2)
	var late: Array = vs.filter(func(v): return not (v.spot_at(20.8)[3] and kind_at.call(v, 20.8) in ["inn", "plaza"]))
	print("   not at the inn or the fire at nine: %s" % [late.map(func(v): return "%s (%s, %s, %.0f m from %.1f h)" % [v.npc_name, kind_at.call(v, 20.8), v.spot_at(20.8)[2],
		walk_len(v, KL.stay_at(v.stays, 20.8)[0]), float(v.stays[KL.stay_at(v.stays, 20.8)[0]]["h"])])])
	check(tag + "at nine in the evening they're at the inn or round the plaza's fire (%d of %d)" % [vs.size() - late.size(), vs.size()], late.size() <= 1)
	var home := vs.filter(func(v): return v.spot_at(2.0)[2] == "home").size()
	var up := vs.filter(func(v): return v.spot_at(2.0)[2] == "talk").size()
	check(tag + "at two in the morning most are home and the rest at the inn (%d home, %d up)" % [home, up], home >= vs.size() / 2 and home + up == vs.size())
	var goers: Array = vs.filter(func(v): return walk_len(v, 1) > 2.0)
	var walking := goers.filter(func(v): return v.spot_at(float(v.stays[1]["h"]) + 0.02)[2] == "walk").size()
	check(tag + "just after a stay begins they're walking to it (%d of %d)" % [walking, goers.size()], walking == goers.size() and goers.size() >= vs.size() / 2)
	var lens: Array = []
	for v in vs:
		for k in range(v.walks.size()):
			lens.append(walk_len(v, k))
	print("   walks: up to %.0f m" % lens.max())
	return goers


func _process(d: float) -> bool:
	t += d
	if t > 200.0:
		check("timed out at step %d" % step, false)
		finish()
		return true
	if wait > 0.0:
		wait -= d
		return false
	match step:
		0:
			if t < 1.5: return false
			var w = root.get_node("World/Islands")
			if not w.chain_ready():
				return false
			p = get_first_node_in_group("player")
			dlg = root.get_node("Dialogue")
			journal = root.get_node("Journal")
			wx = root.get_node("Weather")
			var c = w.chain()
			isl = w.chain_islands[c.start_next[0]]
			life = isl.life
			var goers := _routines(isl, "")
			# a captain in the village; a walker moves
			var hub: Vector2 = isl.sites["village"]
			var to_dock: Vector2 = (isl.sites["dock"] - hub).normalized()
			var at: Vector2 = hub + to_dock * 13.0 + Vector2(-to_dock.y, to_dock.x) * 4.0
			put(isl.to_global(Vector3(at.x, isl.height_at(at.x, at.y) + 1.0, at.y)))
			# (one walking near the village: farther off, past ActorSleep's range, villagers sleep)
			var v0 = goers.filter(func(v): return walk_len(v, 1) > 20.0 and (v.spot_at(float(v.stays[1]["h"]) + 0.02)[0] as Vector2).distance_to(at) < 90.0)[0]
			set_meta("v0", v0)
			hour_to(float(v0.stays[1]["h"]) + 0.02)
			wait = 0.8
			step = 1
		1:
			var v0 = get_meta("v0")
			set_meta("at0", v0.position)
			wait = 2.0
			step = 2
		2:
			var v0 = get_meta("v0")
			var dist: float = (v0.position as Vector3).distance_to(get_meta("at0"))
			check("a villager walks its route in play (%.1f m in 2 s, %.0f m from the camera)" % [dist, v0.global_position.distance_to(p.global_position)], dist > 1.5 and dist < 4.0)
			check("...on the ground, legs going", absf(v0.position.y - isl.walk_height(v0.position.x, v0.position.z)) < 0.05 and v0.humanoid.ground_speed > 0.5)
			hour_to(2.0)
			wait = 0.8
			step = 3
		3:
			var home: Array = life.people.filter(func(v): return v.spot_at(2.0)[2] == "home")
			check("at night those at home are indoors: hidden, no collider, no talk (%d)" % home.size(), not home.is_empty() and home.all(func(v): return not v.visible and v.get_node("Body").collision_layer == 0 and v.interactable.collision_layer == 0))
			hour_to(11.0)
			wait = 0.8
			step = 4
		4:
			check("by day they're out again", life.people.all(func(v): return v.get_node("Body").collision_layer == 1))
			var near: Array = life.people.filter(func(v): return v.global_position.distance_to(p.global_position) < 60.0)
			check("...and those in the village are seen (%d)" % near.size(), not near.is_empty() and near.all(func(v): return v.visible))
			# named characters and their talk
			var named: Array = life.folk.filter(func(f): return f["named"])
			# (1.23: plus the village's 2-5 traders, VillageVendors, named folk with a shop on their menu)
			var traders: Array = named.filter(func(f): return str(f["role"]).begins_with("vendor:"))
			check("three named characters and 2-5 traders, each with their own dialogue tree (%d named, %d traders)" % [named.size(), traders.size()],
				named.size() - traders.size() == 3 and traders.size() >= 2 and traders.size() <= 5 and named.all(func(f): return dlg._load(f["talk"])["nodes"].has("ahead")))
			named = named.filter(func(f): return not traders.has(f))
			var c = root.get_node("World/Islands").chain()
			var ahead: Array = c.next_of(int(isl.node["id"])).map(func(id): return c.node(id)["name"])
			var lines: Array = dlg._load(named[0]["talk"])["nodes"]["ahead"]["text"]
			print("   %s on the way ahead: %s" % [named[0]["name"], lines])
			check("...rumours of the islands ahead (%s)" % [ahead], ahead.any(func(n): return " ".join(lines).contains(n)))
			var isle: Array = dlg._load(named[1]["talk"])["nodes"]["isle"]["text"]
			print("   %s on the island: %s" % [named[1]["name"], isle])
			check("...and of this island (two rumours, tokens filled)", isle.size() == 2 and not " ".join(isle).contains("{"))
			var nv = life.people.filter(func(v): return v.npc_name == named[0]["name"])[0]
			dlg._cooldown = 0.0
			nv.interactable.interacted.emit(p)
			check("talking to one opens its tree", dlg.active and dlg._id == named[0]["talk"])
			dlg._close()
			dlg._cooldown = 0.0
			var amb = life.people.filter(func(v): return not v.barks.is_empty())[0]
			amb.say("Testing, testing.")
			check("an ordinary villager has lines when talked to, and says things over its head", amb.barks.size() >= 2 and amb.get_node("Bubble").visible)
			# quests: every kind
			print("   quests: %s" % [life.quest_node.quests.map(func(x): return "%s (%s)" % [x["title"], x["kind"]])])
			check("2-3 quests from the island's POIs, the board's notices and its encounters' quests in the journal's source too",
				life.given.size() >= 2 and life.given.size() <= 3 and (life.given + life.notices).all(func(x): return life.quest_node.quests.has(x)))
			check("quests keyed by the island's id and seed (%s)" % life.quest_node.quests[0]["id"], life.quest_node.quests.all(func(x): return str(x["id"]).begins_with("isle%d_%d_" % [int(isl.node["id"]), int(isl.node["seed"])])))
			var H = load("res://scripts/npc/humanoid.gd")
			var looks: Array = life.folk.map(func(f): return f["look"])
			check("the island's people took the bodies built for them on the worker", not H.prebuilt_for(looks))
			# the same seed, the same people and quests
			var again = load("res://scripts/island/gen_island.gd").new()
			again.prepare(isl.node)
			var a = again.life
			var same: bool = a.folk.size() == life.folk.size() and a.quests == life.quests.slice(0, a.quests.size()) and a.quest_count == life.quest_count
			for i in range(a.folk.size()):
				for k in ["name", "look", "pref", "wpick", "role", "eve", "owl", "jit"]:
					same = same and a.folk[i][k] == life.folk[i][k]
			check("the same island's seed plans the same people and quests", same)
			# whatever the island has: no village, POIs only, two hamlets
			a.spots = []
			a.arrange()
			check("an island with nothing to live in has no people and no quests", a.placed.is_empty() and a.given.is_empty())
			a.spots = life.spots.filter(func(s): return s.get("poi", false)).map(func(s): return s.duplicate())
			a.arrange()
			check("...nor one with only wild places", a.placed.is_empty() and a.given.is_empty())
			a.spots = life.spots.map(func(s): return s.duplicate())
			var far := Vector2(400.0, 400.0)
			for s in a.spots.duplicate():
				if not s.get("poi", false) and s["kind"] in ["plaza", "home", "market"] and int(s["idx"]) % 2 == 0:
					var hamlet: Dictionary = s.duplicate()
					hamlet["hub"] = far
					a.spots.append(hamlet)
			a.arrange()
			var in_far: int = a.folk.filter(func(f): return f["hub"] == far).size()
			var own := true
			for f in a.folk:
				for st in f["stays"]:
					own = own and a.spots.any(func(s): return s.get("hub") == f["hub"] and s["kind"] == st["kind"])
			check("two hamlets share the people (%d of %d in the second), each keeping to its own" % [in_far, a.folk.size()], in_far > 0 and in_far < a.folk.size() and own)
			check("...their bodies built ahead on the worker", H.prebuilt_for(looks))
			a = null
			again.free()
			check("...and let go with it, unused", not H.prebuilt_for(looks))
			# every kind, a roost to clear among them (as a fauna POI would feed it)
			var roost := {"kind": "roost", "at": isl.sites["ruins"] + Vector2(12, 0), "poi": true, "name": "the bat roost", "verb": "Clear", "clear": func(): return has_meta("roost_clear")}
			life.spots.append(roost)
			for k in ["lost", "scout", "deliver", "fetch", "clear"]:
				if not life.quest_node.quests.any(func(x): return x["kind"] == k):
					life.add_quest(k, 0.99 if k == "clear" else 0.3, 0.6)
			# (the villagers' own: the board's notices and the encounters' quests have their own tests)
			todo = life.given.duplicate()
			step = 10
		10:
			if todo.is_empty():
				step = 20
				return false
			q = todo.pop_front()
			var nodes: Dictionary = dlg._load(giver(q))["nodes"]
			var offer: Array = nodes["menu"]["choices"].filter(func(ch): return ch.get("next", "") == "q_%s_offer" % q["id"])
			check("%s: offered in %s's talk" % [q["title"], life.folk[q["giver_i"]]["name"]], offer.size() == 1 and (offer[0]["if"] as Callable).call())
			talk(giver(q), "q_%s_take" % q["id"])
			check("%s: taken, in the crew's journal on its first step (%d steps)" % [q["title"], q["steps"].size()], journal.has(q["id"]) and journal.step_of(q["id"]) == 0 and q["steps"].size() >= (1 if q["kind"] == "fetch" else 2))
			check("...its offer gone from the talk", not (offer[0]["if"] as Callable).call())
			gold0 = p.inventory_component.count("gold")
			match str(q["kind"]):
				"lost":
					wait = 0.7
				"scout":
					put(q["point"])
					wait = 0.8
				"deliver":
					talk(life.folk[q["recipient_i"]]["talk"], "q_%s_got" % q["id"])
				"fetch":
					var want: Array = q["cost"][0]
					have0 = p.inventory_component.count(str(want[0]))
					p.inventory_component.add_item(load("res://scripts/loot/item_db.gd").get_item(str(want[0])), int(want[1]))
					wait = 0.7
				"clear":
					wait = 0.7
					step = 12
					return false
			step = 11
		11:
			var qn = life.quest_node
			if q["kind"] == "lost":
				var m: Node3D = qn.mark(q)
				check("%s: the lost thing shows once it's asked for, %.0f m from the village" % [q["title"], Vector2(m.position.x, m.position.z).distance_to(isl.sites["village"])], m.visible)
				m.get_node("Search").interacted.emit(p)
				check("...and goes once it's picked up", not m.visible)
			check("%s: its steps done, on to the turn-in" % q["title"], journal.at_turnin(q["id"]))
			var bag: Dictionary = {}
			for e in q["reward"].get("items", []):
				bag[e[0]] = p.inventory_component.count(str(e[0]))
			talk(giver(q), "q_%s_pay" % q["id"])
			var paid: int = p.inventory_component.count("gold") - gold0
			check("%s: turned in to the giver, paid %s (%d gold)" % [q["title"], q["reward"], paid], journal.is_done(q["id"]) and paid >= int(q["reward"]["gold"]))
			check("...with the reward's items", q["reward"].get("items", []).all(func(e): return p.inventory_component.count(str(e[0])) >= int(bag[e[0]]) + int(e[1])))
			if q["kind"] == "fetch":
				check("...who takes the %s" % q["cost"][0][0], p.inventory_component.count(str(q["cost"][0][0])) == have0)
			step = 10
		12:
			check("%s: not done while it stands" % q["title"], journal.step_of(q["id"]) == 0)
			set_meta("roost_clear", true)
			wait = 0.7
			step = 11
		20:
			# kept in the save
			var SG = load("res://scripts/game/save_game.gd")
			SG.use_test_dir("user://lifetest")
			SG.slot = 1
			SG.save(p)
			var qs: Array = life.given
			journal.reset()
			SG.load_into(p)
			check("the journal's quests, done, are kept in the save", qs.all(func(x): return journal.is_done(x["id"])))
			root.get_node("World/Islands").set_process(false)
			step = 30
		30:
			# the routines on the other seeds' first islands, each built far out (ruins with no market, a post's long walks)
			if more.is_empty():
				finish()
				return true
			var w = root.get_node("World/Islands")
			TK.use_seed(self, int(more.pop_front()))
			var c = w.chain()
			isl = load("res://scripts/island/gen_island.gd").new()
			isl.name = "LifeTestIsle%d" % more.size()
			isl.position = Vector3(50000.0, 0.0, 50000.0 + more.size() * 3000.0)
			w.add_child(isl)
			isl.build(c.node(int(c.start_next[0])))
			wait = 0.2
			step = 31
		31:
			_routines(isl, "[%s] " % isl.island_name)
			isl.queue_free()
			step = 30
	return false
