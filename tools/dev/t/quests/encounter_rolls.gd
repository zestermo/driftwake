extends SceneTree
## Encounters on generated islands (IslandEncounters): every theme's pool has every kind with all its text; an
## island's roll is the same from the same seed (guests build what the host built), 0-3 kinds, never one twice,
## never a kind its theme weighs 0, and across many seeds every kind turns up and some islands get none. Then a
## jungle island built with every kind forced: each that finds its place is built (its people, its quest in the
## crew's journal, turned in to whoever gave it), and two builds of it place them the same.
const TK := preload("res://tools/dev/test_kit.gd")
const KEYS := {
	"traveller": ["weight", "who", "intro", "menu", "talk_menu", "talk", "rumour_menu", "rumours", "gift_ask", "gift", "gift_none"],
	"ambush": ["weight", "crew", "banner", "shouts"],
	"festival": ["weight", "who", "intro", "menu", "talk_menu", "talk", "name", "barks", "ask", "plea", "remind_choice", "remind", "done", "thanks", "wants"],
	"shipwreck": ["weight", "who", "intro", "menu", "talk_menu", "talk", "ask", "plea", "remind_choice", "remind", "thing", "search", "said", "done", "thanks"],
	"merchant": ["weight", "who", "intro", "menu", "talk_menu", "talk", "ask", "plea", "remind_choice", "remind", "thing", "search", "said", "done", "thanks"],
	"lost_child": ["weight", "parent", "child", "intro", "menu", "talk_menu", "talk", "ask", "plea", "remind_choice", "remind", "child_intro", "child_hand",
		"child_got", "said", "done", "thanks"],
	"hermit": ["weight", "who", "intro", "menu", "talk_menu", "talk", "rumour_menu", "rumours", "ask", "plea", "remind_choice", "remind", "said", "done", "thanks"],
	"wounded": ["weight", "who", "intro", "menu", "talk_menu", "talk", "ask", "plea", "remind_choice", "remind", "done", "thanks"],
	"note": ["weight", "search", "notes", "things", "done", "thanks"],
	"duelist": ["weight", "who", "intro", "menu", "talk_menu", "talk", "ask", "plea", "decline", "taunts", "remind_choice", "beaten", "done"],
}
const WORLD := "extends Node\nvar c\nvar chain_islands := {}\nvar starter_island = null\nfunc _ready():\n\tadd_to_group(\"world_gen\")\nfunc chain():\n\treturn c\nfunc chain_ready():\n\treturn true\nfunc standing(_i):\n\treturn true\n"
var stage
var fails := 0
var step := 0
var until := 0
var world
var places := []


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
			_pools()
			_rolls()
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
			places.append(_island(0))
		1:
			places.append(_island(1))
			check("two builds of the same island place every encounter the same", places[0] == places[1])
			return TK.done(fails)
	step += 1
	until = TK.wait_ticks(2)
	return false


func _pools() -> void:
	var IT = load("res://scripts/island/themes/island_themes.gd")
	for t in IT.all():
		var pool: Dictionary = t.encounters
		var bad: Array = []
		for k in KEYS.keys():
			if not pool.has(k):
				bad.append(k)
				continue
			for key in KEYS[k]:
				var v = pool[k].get(key)
				if v == null or (v is Array and (v as Array).is_empty()) or (v is String and v == ""):
					bad.append("%s.%s" % [k, key])
		check("[%s] its encounter pool has every kind and all their text (missing: %s)" % [t.name, bad], bad.is_empty())
		var weighed: Array = KEYS.keys().filter(func(k): return float(pool[k]["weight"]) > 0.0)
		check("[%s] 8+ kinds it can roll (%d)" % [t.name, weighed.size()], weighed.size() >= 8)
		var items_ok: bool = (pool["festival"]["wants"] as Array).all(func(w): return ItemDB.get_item(str(w["item"])) != null)
		check("[%s] the festival's feast wants real items" % t.name, items_ok)


func _rolls() -> void:
	var IE = load("res://scripts/quests/island_encounters.gd")
	var IT = load("res://scripts/island/themes/island_themes.gd")
	for t in IT.all():
		var seen := {}
		var sizes := {}
		var same := true
		var twice := false
		var zero_w := false
		for sd in range(300):
			var a: Array = IE.roll(sd, t.name)
			same = same and a == IE.roll(sd, t.name)
			sizes[a.size()] = int(sizes.get(a.size(), 0)) + 1
			var kinds: Array = a.map(func(e): return e["kind"])
			for k in kinds:
				seen[k] = true
				twice = twice or kinds.count(k) > 1
				zero_w = zero_w or float(t.encounters[k]["weight"]) <= 0.0
		var weighed: Array = IE.KINDS.filter(func(k): return float(t.encounters[k]["weight"]) > 0.0)
		check("[%s] the same seed rolls the same encounters" % t.name, same)
		check("[%s] 0-3 an island, some none and some three (%s)" % [t.name, sizes], sizes.keys().all(func(n): return n <= 3) and sizes.has(0) and sizes.has(3))
		check("[%s] never a kind twice on one island, never one it weighs 0" % t.name, not twice and not zero_w)
		check("[%s] every kind it weighs turns up over 300 seeds (%d of %d)" % [t.name, seen.size(), weighed.size()], seen.size() == weighed.size())


## A jungle island with every kind forced; returns where each encounter went.
func _island(k: int) -> Array:
	var IE = load("res://scripts/quests/island_encounters.gd")
	IE.force = IE.KINDS.duplicate()
	var IT = load("res://scripts/island/themes/island_themes.gd")
	var t = IT.of("jungle")
	var n: Dictionary = world.c.node(int(world.c.start_next[0])).duplicate(true)
	n["theme"] = "jungle"
	n["seed"] = 9300
	n.merge({"beast": t.bosses[0], "beast_look": 0, "beast_name": "Old Grumble", "minis": [t.minis[0]], "roamer": t.roamers[0], "landmarks": [], "landmark_count": 0}, true)
	var isl = load("res://scripts/island/gen_island.gd").new()
	isl.name = "EncIsle%d" % k
	isl.position = Vector3(5000.0 * (k + 1), 0, 0)
	world.add_child(isl)
	isl.build(n)
	IE.force = []
	var enc = isl.life.encounters
	var built: Array = enc.built.map(func(e): return e["kind"])
	print("   built: %s" % [built])
	var dlg = root.get_node("Dialogue")
	if k == 0:
		check("most kinds find a place on the island (%d of 10: %s)" % [built.size(), built], built.size() >= 8)
		check("...wild places among them (a hermit or a lost child)", built.has("hermit") or built.has("lost_child"))
		for e in enc.built:
			var kind: String = e["kind"]
			var q: Dictionary = isl.life.quest_node.find(isl.life.key("enc_" + kind))
			match kind:
				"ambush":
					check("ambush: a crew of 3-4 lying in wait by the trail", e["crew"].specs.size() >= 3 and e["crew"].specs.size() <= 4)
				"traveller":
					var tn: Dictionary = dlg._load(isl.life.key("enc_traveller"))["nodes"]
					check("traveller: rumours and a gift to offer", tn.has("rumours") and tn.has("gift") and not " ".join(tn["rumours"]["text"]).contains("{"))
				_:
					var giver_ok: bool = not q.is_empty() and isl.find_children("*", "NPC", true, false).any(func(x): return x.npc_name == q["giver"])
					check("%s: its quest (%s) turned in to %s, who is on the island" % [kind, q.get("title", "none"), q.get("giver", "nobody")], giver_ok)
					var said: Array = []
					for key in ["title", "ask", "remind", "done", "search", "plea", "thanks", "got", "hand"]:
						var v = q.get(key, "")
						said.append_array(v if v is Array else [v])
					for s in q.get("steps", []):
						said.append_array([s["goal"], s.get("said", "")])
					print("   %s: %s" % [kind, q.get("steps", []).map(func(s): return s["goal"])])
					check("%s: no token left unfilled in its quest" % kind, not said.any(func(l): return str(l).contains("{")))
	var out: Array = enc.built.map(func(e): return [e["kind"], e["at"]])
	isl.queue_free()
	return out
