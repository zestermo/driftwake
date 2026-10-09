class_name IslandVillage
extends Node3D
## A generated island's outpost village (GenIsland.sites["village"]), from its
## seed: stilt huts round a plaza, an inn to rest in, a trader and a cook
## (Shops.extra at the island's tier), a job board, the village elder and a few
## villagers. Its own dialogues are made here (Dialogue.define).
##
## Jobs (the board offers, the elder pays): the camp's captain, the bug lair,
## (the beast: 6c). Per captain, kept in Dialogue flags "isle<id>_<job>_taken /
## _done / _paid". A deed done before the job was taken counts once it's taken
## ("isle<id>_<job>_beaten" is set whenever it happens).

const ELDERS := ["Elder Mako", "Elder Tavi", "Old Kesi", "Elder Rua", "Grandmother Ilo", "Headman Pakua"]
const COOKS := ["Nalu", "Ama", "Big Teo", "Siri"]
const TRADERS := ["Wiremu", "Lani", "Haku", "Moana"]
const INNKEEPERS := ["Keala", "Pono", "Rangi", "Ulani"]
const VILLAGER_BARKS := [
	"Keep to the paths after dark. The trees have eyes, and some of them are hungry.",
	"We trade fruit for news. You look like you've got news.",
	"Ships come, ships go. Most of them come back lighter.",
	"Don't drink from the green pools. Trust me.",
	"The bugs were never this bold before the pirates came.",
	"Something big walks the far side of the island at night. We don't go there.",
	"If you're heading on, ask the elder about the way. The needle's not the only thing that knows.",
]
const JOB_STEPS := 0.5
const Shops := preload("res://scripts/game/shops.gd")

var isl: GenIsland
## job id -> {"title", "line", "gold", "check": Callable}
var jobs := {}
var elder_name := ""
var _t := 0.0


static func build(gi: GenIsland, rng: RandomNumberGenerator) -> IslandVillage:
	var v := IslandVillage.new()
	v.name = "Village"
	v.isl = gi
	gi.site_node("village").add_child(v)
	v._build(rng)
	return v


func _key(s: String) -> String:
	return isl.save_key(s)


func _build(rng: RandomNumberGenerator) -> void:
	var c: Vector2 = isl.sites["village"]
	var site := isl.site_node("village")
	var to_dock: Vector2 = (isl.sites["dock"] - c).normalized()
	var side := Vector2(-to_dock.y, to_dock.x)
	var at := func(fw: float, sd: float) -> Vector2: return c + to_dock * fw + side * sd
	var t := IslandContent.tier(isl)
	var lvl := int(isl.node["level"])
	# the plaza: a fire pit, lanterns, a light
	IslandContent._fire(isl, site, c)
	for lp in [at.call(5.0, 5.5), at.call(-5.0, -5.5)]:
		var post := Props.lantern_post(2.4)
		isl.place(post, site, lp)
		var nl := NightLight.make(Color(1.0, 0.72, 0.4), 1.4, 12.0)
		nl.position = Vector3(0.55, 2.2, 0)
		post.add_child(nl)
	# huts on stilts round it, doors to the plaza (a gap toward the dock path)
	var roofs := ["gable", "gable", "hip", "gable_front"]
	var walls := ["planks", "planks_weathered", "planks"]
	var n_huts := rng.randi_range(5, 7)
	for i in range(n_huts):
		var a := atan2(to_dock.y, to_dock.x) + PI * 0.3 + i * (TAU - PI * 0.6) / float(n_huts - 1)
		var p := c + Vector2.from_angle(a) * rng.randf_range(16.0, 21.0)
		isl.house({"w": rng.randf_range(4.0, 5.5), "d": rng.randf_range(3.5, 4.5), "h": 2.3, "roof": roofs[rng.randi() % roofs.size()],
			"wall": walls[rng.randi() % walls.size()], "roof_tex": "thatch", "porch": 1.2 if rng.randf() < 0.5 else 0.0,
			"flowers": rng.randf() < 0.4, "trim": Color(0.42, 0.3, 0.2), "seed": rng.randi()}, site, p, c - p, true)
	# the inn: the biggest, across the plaza from the dock path
	var inn_p: Vector2 = at.call(-24.0, 0.0)
	var inn := isl.house({"w": 8.0, "d": 6.0, "h": 2.8, "roof": "hip", "wall": "planks_weathered", "roof_tex": "thatch", "porch": 2.0,
		"lantern": true, "lamp_light": true, "trim": Color(0.42, 0.3, 0.2), "seed": rng.randi(), "name": "Inn"}, site, inn_p, to_dock, true)
	var rest := Interactable.new()
	rest.name = "Rest"
	rest.collision_layer = 512
	rest.collision_mask = 0
	rest.prompt_text = "Rest at the inn"
	var cs := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 2.4
	cs.shape = sph
	rest.add_child(cs)
	site.add_child(rest)
	var door: Vector2 = inn_p + to_dock * 4.4
	rest.global_position = isl.to_global(Vector3(door.x, isl._ground_max(inn_p, 4.8) + 1.0, door.y))
	rest.interacted.connect(func(player: Player): player.call("_toast", GameManager.rest(player)))
	# stalls: the trader's and the cook's, facing the plaza
	var trade_id := _key("trader")
	var food_id := _key("cook")
	var w := IslandContent.LOOT_WEAPONS
	Shops.extra[trade_id] = {"name": "%s's Trade Goods" % TRADERS[rng.randi() % TRADERS.size()],
		"line": "Shells, steel and sea-gems. I'll take your loot at a fair price.",
		"stock": [["rum", 9], ["biscuit", 3], ["%s@%d" % [w[rng.randi() % w.size()], t], 60 + t * 40],
			["%s@%d" % [w[rng.randi() % w.size()], maxi(t - 1, 0)], 40 + t * 25], ["pistol@%d" % maxi(t - 1, 0), 70 + t * 30]],
		"buys": {"loot": 0.9, "gear": 0.5, "weapon": 0.5}}
	Shops.extra[food_id] = {"name": "%s's Cookpot" % COOKS[rng.randi() % COOKS.size()],
		"line": "Fish from the reef, fruit from the trees, something in the pot. Eat.",
		"stock": [["fish", 5], ["stew", 16], ["rum", 8]], "buys": {"consumable": 0.4}}
	var stall_a: Vector2 = at.call(9.0, -8.0)
	var stall_b: Vector2 = at.call(9.0, 8.0)
	var s1 := isl.place(Props.market_stall("cloth_red", Color(0.7, 0.55, 0.3)), site, stall_a, StarterIsland.face_yaw(c - stall_a), 1.6)
	var s2 := isl.place(Props.market_stall("canvas", Color(0.85, 0.5, 0.25)), site, stall_b, StarterIsland.face_yaw(c - stall_b), 1.6)
	# the job board by the path in
	var board_p: Vector2 = at.call(11.0, 0.0)
	var board := isl.place(StarterIsland._notice_board(rng), site, board_p, StarterIsland.face_yaw(c - board_p))
	var read := Interactable.new()
	read.name = "Read"
	read.collision_layer = 512
	read.collision_mask = 0
	read.prompt_text = "Read the job board"
	var rcs := CollisionShape3D.new()
	var rsph := SphereShape3D.new()
	rsph.radius = 1.8
	rcs.shape = rsph
	rcs.position = Vector3(0, 1.2, 0.6)
	read.add_child(rcs)
	board.add_child(read)
	read.interacted.connect(func(_p): Dialogue.start(_key("board"), board))
	# the people
	var lks := looks(isl)
	elder_name = ELDERS[rng.randi() % ELDERS.size()]
	_npc({"name": elder_name, "dialogue": _key("elder"), "voice": 0.8, "look": lks[0]}, at.call(-3.0, 3.0), to_dock)
	_npc({"name": "Innkeeper " + INNKEEPERS[rng.randi() % INNKEEPERS.size()], "voice": 1.1, "look": lks[1],
		"barks": ["A hammock, a roof and a dry night. Rest when you like.", "We don't get many ships. We get fewer that leave."]},
		inn_p + to_dock * 5.5 + side * 2.0, to_dock)
	_npc({"name": str(Shops.extra[trade_id]["name"]).trim_suffix("'s Trade Goods"), "voice": 0.95, "shop": trade_id, "look": lks[2],
		"barks": ["Have a look. Everything's for sale, and most of it's for sale cheap."]},
		_stall_front(s1), c - stall_a)
	_npc({"name": str(Shops.extra[food_id]["name"]).trim_suffix("'s Cookpot"), "voice": 1.15, "shop": food_id, "look": lks[3],
		"barks": ["Sit, eat. You look like a ship's biscuit with legs."]},
		_stall_front(s2), c - stall_b)
	for i in range(4, lks.size()):
		var p := c + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(6.0, 11.0)
		_npc({"name": "Villager", "voice": rng.randf_range(0.85, 1.2), "look": lks[i],
			"barks": [VILLAGER_BARKS[rng.randi() % VILLAGER_BARKS.size()], VILLAGER_BARKS[rng.randi() % VILLAGER_BARKS.size()]]},
			p, c - p)
	# the jobs and the talk
	var camp = isl.get_node("Site_camp/Camp")
	var cap_title := str(camp.specs.filter(func(s): return s.get("captain", false))[0]["title"])
	jobs["camp"] = {"title": "Bounty: %s" % cap_title, "gold": 40 + t * 20,
		"line": "WANTED: %s. Raids our gardens, burns our boats. Bring word of his end to %s." % [cap_title, elder_name],
		"check": func() -> bool: return camp.grunts.any(func(g): return is_instance_valid(g) and g.captain and g.state == PirateGrunt.S.DEAD)}
	var burrows = isl.get_node("Site_lair/Burrows")
	jobs["lair"] = {"title": "Clear the bug lair", "gold": 30 + t * 15,
		"line": "The burrows inland have spilled into the gardens. Clear every bug from the lair and see %s." % elder_name,
		"check": func() -> bool: return burrows.alive_count() == 0}
	_define_board()
	_define_elder(lvl)
	Dialogue.dialogue_event.connect(_on_event)


func _stall_front(stall: Node3D) -> Vector2:
	var p := isl.to_local(stall.to_global(Vector3(0, 0, -0.5)))
	return Vector2(p.x, p.z)


## Everyone's looks, from their own seed (GenIsland.prepare builds the bodies
## ahead on its worker thread): elder, innkeeper, trader, cook, then villagers.
static func looks(gi: GenIsland) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(gi.node["seed"]) + 77
	var out: Array = []
	for i in range(4 + rng.randi_range(2, 3)):
		out.append(_villager_look(rng))
	out[0].merge({"marks": "age_lines", "hair_color": CharacterLook.HAIR_COLORS[8], "height": 0.95, "hat": "none"}, true)
	return out


static func _villager_look(rng: RandomNumberGenerator) -> Dictionary:
	var lk := CharacterLook.random_look(rng)
	lk.merge({"coat": "none", "hat": ["straw", "none", "none", "bandana"][rng.randi() % 4], "feet": "barefoot" if rng.randf() < 0.5 else "shoes",
		"top": ["tunic", "shirt", "blouse"][rng.randi() % 3], "sleeves": "short", "vest": "none", "eyepatch": false, "gloves": false}, true)
	return lk


func _npc(cfg: Dictionary, p: Vector2, face: Vector2) -> NPC:
	var npc := NPC.new()
	cfg["yaw"] = atan2(-face.x, -face.y)
	npc.setup(cfg)
	npc.ground_func = isl.walk_height
	isl.add_child(npc)
	npc.position = Vector3(p.x, isl.hv(p), p.y)
	return npc


func _flag(job: String, state: String) -> String:
	return "%s_%s" % [_key(job), state]


func _define_board() -> void:
	var nodes := {"start": {"text": "Notices, nailed up and curling in the damp.", "choices": []}}
	for job in jobs.keys():
		var j: Dictionary = jobs[job]
		nodes["start"]["choices"].append({"text": "%s  (%d gold)" % [j["title"], j["gold"]], "next": job, "hide_if": _flag(job, "taken")})
		nodes[job] = {"text": [j["line"], "You tear the notice down and pocket it."], "event": "isle_job:%s:take" % _key(job), "set_flag": _flag(job, "taken"), "next": "end"}
	nodes["start"]["choices"].append({"text": "Leave it.", "next": "end"})
	Dialogue.define(_key("board"), {"speaker": "Job board", "voice": 1.0, "start": "start", "nodes": nodes})


func _define_elder(lvl: int) -> void:
	var c: Chain = get_tree().get_first_node_in_group("world_gen").chain()
	var ahead: Array = c.next_of(int(isl.node["id"])).map(func(id): return c.node(id))
	var beyond := "Past us? %s." % " or ".join(ahead.map(func(n): return "%s, %s" % [n["name"], Chain.THEMES[n["theme"]]["blurb"]])) if not ahead.is_empty() else "Past us? The end of this sea, they say."
	var menu := {"text": "What do you need, Captain?", "choices": [
		{"text": "Tell me about this island.", "next": "about"},
		{"text": "Where does the log pose point from here?", "next": "beyond"},
	]}
	var nodes := {
		"intro": {"text": ["Visitors! It's been a long season. Welcome to %s." % isl.island_name,
			"I'm %s. The board by the path has work, if you're the sort who takes it." % elder_name], "next": "menu"},
		"menu": menu,
		"about": {"text": ["The jungle feeds us and the jungle eats us. Pirates squat in the old camp, bugs nest inland, and the ruins are older than anyone remembers.",
			"And something walks the far side of the island at night. Big. We don't go there."], "next": "menu"},
		"beyond": {"text": [beyond, "Your needle needs time on an island before it sets on the next, or something to happen here worth remembering."], "next": "menu"},
	}
	for job in jobs.keys():
		var j: Dictionary = jobs[job]
		menu["choices"].append({"text": "About the job: %s" % j["title"], "next": "pay_" + job, "requires": _flag(job, "done"), "hide_if": _flag(job, "paid")})
		nodes["pay_" + job] = {"text": ["It's done? Truly? The whole village owes you, Captain.", "Here: %d gold, as promised." % j["gold"]],
			"event": "isle_job:%s:pay" % _key(job), "set_flag": _flag(job, "paid"), "next": "menu"}
	menu["choices"].append({"text": "Goodbye.", "next": "end"})
	Dialogue.define(_key("elder"), {"speaker": elder_name, "voice": 0.8, "start": "intro", "return": "menu", "nodes": nodes})


func _on_event(ev: String) -> void:
	if not ev.begins_with("isle_job:"):
		return
	var parts := ev.split(":")
	for job in jobs.keys():
		if parts[1] != _key(job):
			continue
		match parts[2]:
			"take":
				_t = 0.0
			"pay":
				var me := get_tree().get_first_node_in_group("player") as Player
				me.inventory_component.add_item(ItemDB.get_item("gold"), int(jobs[job]["gold"]))
				GameManager.award_xp(60 + IslandContent.tier(isl) * 30, me.global_position)


## Twice a second: a deed done is remembered; a job taken and done says so.
func _process(delta: float) -> void:
	_t -= delta
	if _t > 0.0:
		return
	_t = JOB_STEPS
	for job in jobs.keys():
		if not Dialogue.has_flag(_flag(job, "beaten")) and (jobs[job]["check"] as Callable).call():
			Dialogue.set_flag(_flag(job, "beaten"))
		if Dialogue.has_flag(_flag(job, "taken")) and Dialogue.has_flag(_flag(job, "beaten")) and not Dialogue.has_flag(_flag(job, "done")):
			Dialogue.set_flag(_flag(job, "done"))
			get_tree().call_group("hud", "show_toast", "Job done: %s. %s will pay." % [jobs[job]["title"], elder_name])
