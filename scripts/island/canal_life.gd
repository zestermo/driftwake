class_name CanalLife
extends Node3D
## The canal city's people (docs/v1_21_plan.md): the Master of the Arsenal (his yard: every refit there is, and in
## 1.21 the ships he builds), his shipwrights, the innkeeper of the Oar and Lantern, the market's vendors, the
## glassworker on the market bridge (the city's rare goods), the chandler, the priest, a fiddler and the café's regulars
## in the piazza, people in the campi, and a boatman at every water taxi landing who rows you to any other (a short
## fade, and you step off there). The inn's rest; three city quests. Every name, look and stock fixed, as the
## capital's (CapitalLife).

const P := preload("res://scripts/island/canal_plan.gd")
const SHOPS := preload("res://scripts/game/shops.gd")
const GOLD := Color(0.86, 0.68, 0.26)
const APRON := {"vest": "jerkin", "vest_color": Color(0.42, 0.32, 0.22), "sleeves": "short"}
## The crowd: how many townsfolk looks, and its lanes ([points, walkers, ring]) along the walkways.
const CROWD_LOOKS := 8
const LANES := [
	[[Vector2(-180.0, 101.0), Vector2(-14.0, 101.0)], 6, false],
	[[Vector2(14.0, 104.0), Vector2(180.0, 104.0)], 6, false],
	[[Vector2(30.0, 62.0), Vector2(98.0, 62.0), Vector2(98.0, 90.0), Vector2(30.0, 90.0)], 5, false],
	[[Vector2(-14.0, -170.0), Vector2(-14.0, 14.0)], 4, false],
	[[Vector2(14.0, 14.0), Vector2(14.0, -170.0)], 4, false],
	[[Vector2(-190.0, 18.0), Vector2(-14.0, 18.0)], 3, false],
	[[Vector2(14.0, 34.0), Vector2(190.0, 34.0)], 3, false],
	[[Vector2(-190.0, -76.0), Vector2(-14.0, -76.0)], 3, false],
	[[Vector2(14.0, -76.0), Vector2(126.0, -76.0)], 3, false],
	[[Vector2(134.0, -55.0), Vector2(166.0, -55.0), Vector2(166.0, 0.0)], 3, false],
]

## The crowd's lanes (1.21's detail pass): LANES with twice their walkers, and a lane down every calle and quay walk
## at least 20 m long (a walker per 28 m of it), so the narrow ways have people in them too.
static func lanes() -> Array:
	var out: Array = []
	for l in LANES:
		out.append([l[0], int(l[1]) * 2, l[2]])
	for f in CanalPlan.floors():
		var nm := str(f[0])
		if nm.begins_with("riva") or nm.ends_with("_campo") or nm.begins_with("piazza"):
			continue
		var r: Rect2 = f[1]
		var along_x := r.size.x >= r.size.y
		var length := r.size.x if along_x else r.size.y
		if length < 20.0 or minf(r.size.x, r.size.y) > 6.0:
			continue
		var c := r.get_center()
		var a := Vector2(r.position.x + 1.0, c.y) if along_x else Vector2(c.x, r.position.y + 1.0)
		var b := Vector2(r.end.x - 1.0, c.y) if along_x else Vector2(c.x, r.end.y - 1.0)
		out.append([[a, b], maxi(1, int(length / 28.0)), false])
	return out


var isl
## (1.27 C4) The smuggling ring, Master Grane's investigation (empty with too few campi).
var smug_q: Dictionary = {}
## (1.27 C4) The canal city's odd jobs, offered by its people: [soup fish, the basket on the roofs, the candles].
var job_qs: Array = []
## (1.27 C4) The drowned bell, Father Anselm's: the belfry, then a dive for the clapper.
var bell_q: Dictionary = {}
var quest_node: KitQuests
var people := {}
var _fader: ColorRect


## Everyone named: {"name", "spot", "voice", "look" over the city's folk look, "barks" / "shop" / "dialogue"}.
static func cast() -> Array:
	return [
		# 1.27 C3: the Doge of the lagoon, on the dais of the council chamber (the Doge's line comes with C5)
		{"name": "Doge Benedetto Vael", "spot": "doge", "voice": 0.85, "dialogue": "doge", "look": {"body": "masc", "coat": "frock", "coat_color": Color(0.55, 0.1, 0.12), "trim_color": Color(0.9, 0.72, 0.25),
			"hat": "none", "cloak": true, "cloak_color": Color(0.62, 0.12, 0.14)},
			"barks": ["The lagoon elected me to keep its ships safe. Someone is making that very difficult.", "The guilds argue, the arsenal builds, and I sign. That is the Republic.",
				"A pirate taxes our waters as if he were the Doge. He is not the Doge."]},
		# 1.27 C3: the same hooded stranger as the capital's bell tower, up in the campanile
		{"name": "The Hooded Stranger", "spot": "informant", "voice": 0.92, "dialogue": "stranger", "look": {"body": "masc", "coat": "greatcoat", "coat_color": Color(0.14, 0.13, 0.16), "hat": "hood",
			"cloak": true, "cloak_color": Color(0.1, 0.09, 0.12), "legs_color": Color(0.12, 0.12, 0.14)},
			"barks": ["You again. Or me again. Hard to say who's following whom.", "The lagoon keeps secrets better than the capital. Not better than me.",
				"There's a pirate who taxes these waters. The Doge would pay to know where he sleeps.", "Ring the bell if you like. Nobody comes up here."]},
		{"name": "Master Ottavio Grane", "spot": "arsenal_master", "voice": 0.8, "dialogue": "master", "look": {"body": "masc", "coat": "longcoat", "coat_color": Color(0.36, 0.14, 0.12),
			"trim_color": GOLD, "hat": "none", "gloves": true, "gloves_color": Color(0.3, 0.22, 0.16)}},
		{"name": "Pia Calder", "spot": "shipwright0", "voice": 1.1, "look": APRON.merged({"body": "fem"}, true), "barks": ["Forty-two ribs on this one. I've numbered every one in chalk.",
			"Mind the adze. Mind the saw. Mind everything, really."]},
		{"name": "Bruno Sacca", "spot": "shipwright1", "voice": 0.8, "look": APRON, "barks": ["We launch on the spring tide. Or the one after. Never the one before.", "Oak from the hills, pitch from the south, sweat from me."]},
		{"name": "Teo", "spot": "shipwright2", "voice": 1.25, "look": APRON, "barks": ["I'm an apprentice. I carry things. Big things.", "The Master says I'll build my first hull at twenty. I'm nineteen!"]},
		{"name": "Old Lucca", "spot": "shipwright3", "voice": 0.75, "look": APRON, "barks": ["Fifty years on these slips. Every ship in the harbour knows my hands.",
			"A caravel's a lovely thing. Light on the water. Like a gull that's had a drink."]},
		{"name": "Carlotta Vere", "spot": "innkeeper", "voice": 1.05, "dialogue": "inn", "look": {"body": "fem", "top": "blouse", "vest": "corset", "vest_color": Color(0.3, 0.42, 0.34)}},
		{"name": "Fen", "spot": "inn_patron0", "voice": 0.95, "barks": ["The Oar and Lantern. Best fish soup on the water. Only fish soup on the water.", "I row a taxi by day. By night I sit here and complain about rowing."]},
		{"name": "Marisa", "spot": "inn_patron1", "voice": 1.15, "barks": ["The arsenal's working night and day. Somebody's ordered a fleet.", "Saw a pirate captain buy a whole ship last spring. Paid in pearls."]},
		{"name": "Gianna", "spot": "stall0", "voice": 1.1, "shop": "grocer", "barks": ["Artichokes! Lemons! Lagoon crab, still cross about it!", "Fresh from the gardens on the outer isles this morning."]},
		{"name": "Rocco", "spot": "stall1", "voice": 0.9, "shop": "fish", "barks": ["Eels, sardines, cuttlefish! The ink's free!", "If it swims in the lagoon, I sell it. If it swims fast, I sell it dearer."]},
		{"name": "Nella", "spot": "stall2", "voice": 1.2, "barks": ["Figs and melons! Sweet as a sailor's promise!", "Two figs for a copper. Three if you smile."]},
		{"name": "Ilaria Fiore", "spot": "bridge_seller", "voice": 1.05, "shop": "glass", "look": {"body": "fem", "top": "blouse", "coat": "jacket", "coat_color": Color(0.24, 0.3, 0.5)},
			"barks": ["Glass from the furnaces of the north quarter. Blown by my own breath, and my mother's before me.", "Rare things, Captain. For a captain with rare taste and a full purse."]},
		{"name": "Nico Salt", "spot": "chandler", "voice": 0.9, "shop": "chandler", "barks": ["Rope, pitch, canvas, copper. Everything the arsenal doesn't hoard.", "Timber? Ask the Master. He sells to captains he likes."]},
		{"name": "Father Anselm", "spot": "priest", "voice": 0.8, "dialogue": "priest", "look": {"body": "masc", "coat": "greatcoat", "coat_color": Color(0.12, 0.12, 0.14), "hat": "none"}},
		{"name": "Fiddler Joss", "spot": "piazza0", "voice": 1.0, "barks": ["A tune for the lagoon! Three verses about a mermaid and none of them true!", "Coins in the hat make the fiddle go faster."]},
		{"name": "Little Bea", "spot": "piazza1", "voice": 1.4, "barks": ["Are you a real pirate? Have you got a parrot? A small one?", "I'm going to be a boatman. Or a queen. Or both."]},
		{"name": "Signora Pell", "spot": "piazza2", "voice": 1.15, "barks": ["The bells ring every hour. I've lived here sixty years and they've never once been on time.", "Feed the pigeons and they'll follow you home. Ask me how I know."]},
		{"name": "Dario", "spot": "piazza3", "voice": 0.95, "barks": ["Best coffee on the riva, and the worst prices. That's how you know it's good.", "Sit. Watch the boats. That's what the piazza's for."]},
		{"name": "Old Mirto", "spot": "cafe0", "voice": 0.8, "barks": ["I've been sitting at this table since the old Master built his first ship.", "The trick with lagoon wine is to drink it before you taste it."]},
		{"name": "Nonna Rosa", "spot": "cafe1", "voice": 0.9, "barks": ["Sit, sit. The waiter's slow but the view's free.", "In my day the canals were cleaner. And the boatmen handsomer."]},
		{"name": "Marco and Ilde", "spot": "cafe2", "voice": 1.0, "barks": ["Our anniversary. Thirty years and he still can't order wine.", "Ask her about the time I fell in the Grand Canal. Go on."]},
		{"name": "Brother Tadeo", "spot": "cafe4", "voice": 0.85, "barks": ["Father Anselm thinks I'm at prayer. The coffee here is a kind of prayer.", "Bless you, Captain. Now move, you're in my sun."]},
		{"name": "Ottone the Clerk", "spot": "cafe5", "voice": 0.95, "barks": ["The arsenal's ledgers don't add up. They never have. Nobody minds.", "Ten minutes for lunch. I've been here an hour."]},
		{"name": "Lena", "spot": "cafe3", "voice": 1.1, "barks": ["The glassworker on the bridge made my earrings. Don't let her charge you full price.", "My brother's a shipwright. Smells of pitch, every day."]},
	]


## The boatmen at the water taxi landings: one each, named.
const BOATMEN := ["Beppe", "Tonio", "Rina", "Matteo", "Sandro", "Agnese"]


static func look_of(c: Dictionary) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(c["name"]))
	var lk := KitStyle.folk_look(KitStyle.of("canal"), rng)
	lk.merge(c.get("look", {}), true)
	lk["name"] = c["name"]
	return lk


static func boatman_look(i: int) -> Dictionary:
	return look_of({"name": "Boatman " + str(BOATMEN[i]), "look": {"top": "shirt", "top_color": Color(0.94, 0.94, 0.9), "vest": "none", "hat": "straw", "sash_color": Color(0.62, 0.16, 0.14)}})


static func looks() -> Array:
	var out: Array = cast().map(func(c): return look_of(c))
	for i in range(BOATMEN.size()):
		out.append(boatman_look(i))
	return out


static func crowd_looks() -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261024
	var st := KitStyle.of("canal")
	var out: Array = []
	for i in range(CROWD_LOOKS):
		var lk := KitStyle.folk_look(st, rng)
		lk["name"] = "Canalfolk%d" % i
		out.append(lk)
	return out


func setup(island) -> CanalLife:
	name = "Life"
	isl = island
	return self


func steps() -> Array:
	return [["life", _shops], ["life", _people], ["life", _inn], ["life", _quests], ["life", _boatmen]]


func _key(what: String) -> String:
	return isl.save_key("canal_" + what)


func _spot(spot: String) -> Array:
	var sp: Array = isl.spots[spot]
	var v: Vector3 = sp[0]
	var p: Vector2 = isl.from_city(Vector2(v.x, v.z))
	return [Vector3(p.x, v.y, p.y), float(sp[1]) + float(isl.yaw)]


# --------------------------------------------------------------------------
func _shops() -> void:
	var t := mini(Levels.tier(int(isl.node["level"])) + 1, 4)
	SHOPS.extra[_key("grocer")] = {"name": "Gianna's Greens", "line": "From the outer isles' gardens this morning.", "trade": "grocer",
		"stock": [["flour", 3], ["salt", 3], ["egg", 3]], "pool": [["pepper"], ["rice"], ["mushroom"], ["jungle_fruit"], ["seaweed"], ["coconut"]], "size": 3,
		"buys": {"ingredient": 0.5}}
	SHOPS.extra[_key("fish")] = {"name": "Rocco's Catch", "line": "If it swims in the lagoon, it's here.", "trade": "grocer",
		"stock": [["fish", 6], ["bait_worm"], ["bait_shrimp"]], "pool": [["crab_meat"], ["oyster"], ["seaweed"], ["rod_bamboo"]], "size": 2, "buys": {"ingredient": 0.5}}
	SHOPS.extra[_key("glass")] = {"name": "Fiore Glass", "line": "Blown by hand on the north quarter's furnaces. Rare, and priced like it.", "trade": "treasure",
		"tier": mini(t + 1, 4), "stock": [["accessory", "earring", {"earring": true}, mini(t + 1, 4)], ["accessory", "cloak", {"cloak": true, "cloak_color": Color(0.2, 0.36, 0.5)}, mini(t + 1, 4)],
			["tonic", 30], ["rum", 9]], "buys": {"loot": 1.0, "gear": 0.5}}
	SHOPS.extra[_key("chandler")] = {"name": "Salt's Chandlery", "line": "Rope, pitch, canvas and copper. Everything the arsenal doesn't hoard.", "trade": "grocer",
		"stock": [["timber", 4], ["canvas", 4], ["iron", 4], ["copper", 4]], "pool": [["rum"], ["biscuit"], ["tonic"]], "size": 2, "buys": {"ingredient": 0.4, "loot": 0.6}}
	SHOPS.extra[_key("inn")] = {"name": "The Oar and Lantern", "line": "Fish soup, bread, and wine from the hills.", "trade": "cook",
		"stock": [["fish_stew", 12], ["stew", 16], ["rum", 8]], "pool": [["porridge"], ["island_skewers"]], "size": 1, "buys": {"consumable": 0.4}}


func _people() -> void:
	var lks := looks()
	var c := cast()
	for i in range(c.size()):
		var e: Dictionary = c[i]
		if not isl.spots.has(e["spot"]):
			push_error("CanalLife: no spot %s" % e["spot"])
			continue
		var sp: Array = _spot(e["spot"])
		var cfg := {"name": e["name"], "voice": e["voice"], "look": lks[i], "yaw": float(sp[1]) + PI}
		if e.has("barks"):
			cfg["barks"] = e["barks"]
		if e.has("shop"):
			cfg["shop"] = _key(e["shop"])
		if e.has("dialogue"):
			cfg["dialogue"] = _key(e["dialogue"])
		var n := NPC.new()
		n.setup(cfg)
		n.ground_func = isl.walk_height
		add_child(n)
		n.position = sp[0]
		people[e["name"]] = n


func _inn() -> void:
	var rest := Interactable.new()
	rest.name = "Rest"
	rest.collision_layer = 512
	rest.collision_mask = 0
	rest.prompt_text = "Rest at the Oar and Lantern  (K: switch your build here)"
	rest.gesture = "push"
	var cs := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 2.2
	cs.shape = sph
	rest.add_child(cs)
	add_child(rest)
	rest.position = (_spot("inn_door")[0] as Vector3) + Vector3(0, 1.3, 0)
	rest.interacted.connect(func(player: Player): player.call("_toast", GameManager.rest(player)))
	rest.add_to_group("rest_spots")


# --------------------------------------------------------------------------
# The city's quests and talk
# --------------------------------------------------------------------------
func _quests() -> void:
	quest_node = KitQuests.new()
	quest_node.name = "Quests"
	add_child(quest_node)
	var common := {"isle": isl.island_name, "pos": isl.position, "favour_ask": "", "favour_thanks": []}
	var blessing := {"id": _key("blessing"), "kind": "deliver", "giver": "Father Anselm", "src": "npc", "title": "A blessing for the hull",
		"recipient": "Master Ottavio Grane", "reward": {"gold": 50},
		"ask": "Anything I can do, Father?", "plea": ["Every hull on the slips gets a blessing before it touches water. The Master asked for this one, and my knees won't take the arsenal's cobbles today.",
			"Take him the blessing? It's written out. He reads it to the ribs himself. Don't laugh. It works."],
		"accept": "I'll take it.", "decline": "Not today, Father.", "taken": "Bless you. Over the bridge, past the market, to the arsenal at the end.",
		"remind_choice": "About the blessing...", "remind": ["To Master Grane at the arsenal. By the slips."],
		"done": "The Master has the blessing.", "thanks": ["Then the hull will float, and so will the crew. Thank you. Take this for your trouble."],
		"hand": "A blessing for the hull, from Father Anselm.", "got": ["Anselm's blessing! Good. I'll read it to her tonight. Ships like to be spoken to, Captain. Remember that."],
		"steps": [{"do": "talk", "who": "Master Ottavio Grane", "goal": "Take Father Anselm's blessing to Master Grane at the arsenal", "said": "The Master has it. Tell Father Anselm."},
			{"do": "turnin", "goal": "Tell Father Anselm at the church his blessing was delivered"}]}
	blessing.merge(common)
	quest_node.add(blessing, isl)
	var oar := {"id": _key("oar"), "kind": "lost", "giver": "Carlotta Vere", "src": "npc", "title": "The lucky oar",
		"at": isl.from_city(Vector2(-108.0, -26.0)), "yaw": 0.5, "search": "Look under the well's rim", "reward": {"gold": 40, "items": [["fish_stew", 2]]},
		"ask": "You look worried, signora.", "plea": ["My grandfather's lucky oar-blade hung over this bar forty years. Some joker took it last night for a dare.",
			"They'll have left it in a campo somewhere, the west one, I'd bet. Bring it back and supper's on me."],
		"accept": "I'll find it.", "decline": "Can't help, sorry.", "taken": "The campo west of here, across the lanes. Mind the boys there: they're the jokers.",
		"remind_choice": "About your oar...", "remind": ["The west campo, by the well. A small blade, painted blue and red."],
		"done": "Your oar-blade, signora.", "thanks": ["That's it! Back over the bar where it belongs. Sit, eat, and don't you dare pay."],
		"found": "A small oar-blade painted blue and red, wedged under the well's rim.",
		"steps": [{"do": "pickup", "goal": "Find Carlotta's lucky oar-blade in the west campo", "said": "The oar-blade, by the well. Back to Carlotta at the inn."},
			{"do": "turnin", "goal": "Bring the oar-blade back to Carlotta at the Oar and Lantern"}]}
	oar.merge(common)
	quest_node.add(oar, isl)
	var glass := {"id": _key("glass"), "kind": "deliver", "giver": "Ilaria Fiore", "src": "npc", "title": "Glass for the inn",
		"recipient": "Carlotta Vere", "reward": {"gold": 45},
		"ask": "Busy day on the bridge?", "plea": ["Busy and stuck. Carlotta at the Oar and Lantern ordered new lamp glass, and I can't leave the stall with this crowd.",
			"Carry it down for me? It's packed in straw. Don't run. Don't trip. Don't sit on it."],
		"accept": "I'll carry it.", "decline": "I'd break it.", "taken": "Down the walkway on the west side of the bridge, the inn with the lanterns.",
		"remind_choice": "About the lamp glass...", "remind": ["To Carlotta Vere at the Oar and Lantern. Gently."],
		"done": "Carlotta has her glass.", "thanks": ["Not a crack? You've steadier hands than my apprentice. Here."],
		"hand": "Lamp glass from Ilaria Fiore.", "got": ["Ilaria's glass! Oh, it's lovely. The lanterns will glow like the old days."],
		"steps": [{"do": "talk", "who": "Carlotta Vere", "goal": "Carry Ilaria's lamp glass to Carlotta at the Oar and Lantern", "said": "Carlotta has it. Tell Ilaria on the bridge."},
			{"do": "turnin", "goal": "Tell Ilaria Fiore on the market bridge it's delivered"}]}
	glass.merge(common)
	quest_node.add(glass, isl)
	_smugglers(common)
	_jobs(common)
	_drowned_bell(common)
	CityFavour.apply("canal", self, favour_shops())
	_talk(blessing, oar, glass)


func _talk(blessing: Dictionary, oar: Dictionary, glass: Dictionary) -> void:
	# (1.27 C4) the dice den in a campo: a dicer and an arm-wrestler (TavernGames.make_at)
	var campi: Array = P.floors().filter(func(f): return str(f[0]).ends_with("_campo"))
	if campi.size() > 2 and get_node_or_null("Den_campo") == null:
		var cr: Rect2 = campi[2][1]
		var q: Vector2 = cr.position + Vector2(3.0, cr.size.y - 3.0)
		TavernGames.make_at(self, isl, isl.from_city(q), isl.from_city_dir((cr.get_center() - q).normalized()), P.QUAY_Y, "campo")
	# (1.27 C5) the Doge: where you stand with the Lagoon (CityFavour); asking applies its perks
	var dnodes := {"intro": {"text": ["Benedetto Vael, Doge of this Republic by the grace of its guilds and its boatmen.", "Speak plainly. The council is waiting, and it hates waiting."], "next": "menu"},
		"menu": {"text": "Well, Captain?", "choices": [{"text": "How does the Lagoon regard me?", "next": "favour"}, {"text": "Your pirate problem?", "next": "pirate"}, {"text": "Good day, Doge.", "next": "end"}]},
		"favour": {"text": ["{canal_favour}"], "event": "favour:canal", "next": "menu"},
		"pirate": {"text": ["A captain who calls himself a prince taxes every hull that leaves this lagoon. My ships, my guilds, my people.", "When you're trusted here, Captain, we'll speak of where he sleeps."], "next": "menu"}}
	# (1.27 C5) the Doge's line, its first step the smuggling ring (Master Grane's); the convoy waits for the pirate's hideout
	if not smug_q.is_empty():
		CityFavour.ruler_line("canal", self, smug_q, dnodes["menu"]["choices"], dnodes, {
			"ask": "Can I serve the Republic?",
			"point": ["Serve it? Then stop it bleeding. The arsenal's stores leave by night on boats nobody owns.",
				"Master Grane builds my galleys and counts my nails. He knows which crates go missing. Ask him, and follow where it leads."],
			"done_ask": "Grane's smugglers are broken, Doge.",
			"done": ["So the council tells me, and for once it's pleased. Copper and oak stay in the Republic's yards.", "The Lagoon pays its friends. Not lavishly. Promptly."],
			"next_ask": "And the pirate prince?",
			"next": ["Those smugglers sold to his ships. He'll need new suppliers, and he'll come for my convoys to find them.", "When we know where he moors, I'll want an escort, and then I'll want him gone."]})
	Dialogue.define(_key("doge"), {"speaker": "Doge Benedetto Vael", "voice": 0.85, "start": "intro", "return": "menu", "nodes": dnodes})
	Dialogue.register_token("canal_favour", func(): return CityFavour.line("canal", CityFavour.done(self)))
	if not Dialogue.dialogue_event.is_connected(_on_favour):
		Dialogue.dialogue_event.connect(_on_favour)
	# (1.27 C4) the Hooded Stranger sells leads: a cache in this city for gold, marked on the map (CityCaches)
	Dialogue.define(_key("stranger"), {"speaker": "The Hooded Stranger", "voice": 0.92, "start": "intro", "return": "menu", "nodes": CityCaches.stranger_nodes("canal", isl)})
	if not Dialogue.dialogue_event.is_connected(_on_lead):
		Dialogue.dialogue_event.connect(_on_lead)
	var mmenu := {"text": "The arsenal's business, Captain. Quickly.", "choices": [{"text": "Show me what your yard can do to my ship.", "next": "yard"},
		{"text": "Do you build ships to sell?", "next": "ships"}]}
	var mnodes := {"intro": {"text": ["Ottavio Grane, Master of the Arsenal. Every hull on this lagoon has passed under my eye, and most of them under my hand."], "next": "menu"},
		"menu": mmenu, "yard": {"text": ["Let's see her, then. Whatever Brinehollow's yard does, mine does better."], "event": "shipwright:Grane", "next": "end"},
		"ships": {"text": ["We do. Caravels: light, quick, a bow chaser and a bigger hold, though she'll take a broadside worse than your sloop.", "Yours for %s, the materials my yard eats." % ShipClasses.price_text("caravel")], "next": "menu"},
		"buy": {"text": ["Done! I'll have her at your berth by the time you're down the steps. Your sloop stays here, looked after."], "event": "ship:buy:caravel", "next": "end"}}
	_ship_choices(mmenu["choices"], mnodes, true)
	quest_node.hand_over(blessing, mmenu["choices"], mnodes)
	for j in job_qs.filter(func(q): return str(q.get("recipient", "")) == "Master Ottavio Grane"):
		quest_node.hand_over(j, mmenu["choices"], mnodes)
	mmenu["choices"].append({"text": "Goodbye.", "next": "end"})
	if not smug_q.is_empty():
		quest_node.offer(smug_q, mmenu["choices"], mnodes)
	Dialogue.define(_key("master"), {"speaker": "Master Ottavio Grane", "voice": 0.8, "start": "intro", "return": "menu", "nodes": mnodes})
	var pmenu := {"text": "Peace on you, Captain.", "choices": []}
	var pnodes := {"intro": {"text": ["Father Anselm. I bless the hulls, the boats and, when they let me, the sailors."], "next": "menu"}, "menu": pmenu}
	quest_node.offer(blessing, pmenu["choices"], pnodes)
	for j in job_qs.filter(func(q): return str(q["giver"]) == "Father Anselm"):
		quest_node.offer(j, pmenu["choices"], pnodes)
	if not bell_q.is_empty():
		quest_node.offer(bell_q, pmenu["choices"], pnodes)
	pmenu["choices"].append({"text": "Goodbye, Father.", "next": "end"})
	Dialogue.define(_key("priest"), {"speaker": "Father Anselm", "voice": 0.8, "start": "intro", "return": "menu", "nodes": pnodes})
	var imenu := {"text": "What'll it be, Captain?", "choices": [{"text": "Something to eat.", "next": "eat"}, {"text": "What's the news?", "next": "news"}]}
	var inodes := {"intro": {"text": ["Welcome to the Oar and Lantern! Fish soup, hill wine, and a bed that doesn't rock. Much."], "next": "menu"}, "menu": imenu,
		"eat": {"text": ["Soup's on. Sit anywhere that isn't wet."], "event": "shop:" + _key("inn"), "next": "end"},
		"news": {"text": ["The arsenal's got a caravel on the slips that'll be the prettiest thing on the water.", "And they say the capital's arena has a champion again. Pirates everywhere, these days."], "next": "menu"}}
	quest_node.offer(oar, imenu["choices"], inodes)
	for j in job_qs.filter(func(q): return str(q["giver"]) == "Carlotta Vere"):
		quest_node.offer(j, imenu["choices"], inodes)
	quest_node.hand_over(glass, imenu["choices"], inodes)
	imenu["choices"].append({"text": "Goodbye.", "next": "end"})
	Dialogue.define(_key("inn"), {"speaker": "Carlotta Vere", "voice": 1.05, "start": "intro", "return": "menu", "nodes": inodes})
	# Ilaria's quest on her stall: she has a shop, so her talk is the glass quest's offer (her shop's own button opens the stall)
	var gmenu := {"text": "Glass, Captain? Or a favour?", "choices": [{"text": "Show me your glass.", "next": "shop"}]}
	var gnodes := {"intro": {"text": ["Ilaria Fiore. Glass from the north quarter's furnaces."], "next": "menu"}, "menu": gmenu,
		"shop": {"text": ["Look, then. Don't touch the blue ones."], "event": "shop:" + _key("glass"), "next": "end"}}
	quest_node.offer(glass, gmenu["choices"], gnodes)
	gmenu["choices"].append({"text": "Goodbye.", "next": "end"})
	Dialogue.define(_key("glassworker"), {"speaker": "Ilaria Fiore", "voice": 1.05, "start": "intro", "return": "menu", "nodes": gnodes})
	if people.has("Ilaria Fiore"):
		people["Ilaria Fiore"].set("dialogue_id", _key("glassworker"))


# --------------------------------------------------------------------------
# The water taxis
# --------------------------------------------------------------------------
## A boatman at every landing; talking to one offers a ride to each of the others ("canal_taxi:<i>"): the screen fades,
## the captain steps off at that landing, it clears.
func _boatmen() -> void:
	for i in range(P.LANDINGS.size()):
		var sp: Array = _spot("landing%d" % i)
		var nm := "Boatman " + str(BOATMEN[i % BOATMEN.size()])
		var menu := {"text": "Where to, Captain?", "choices": []}
		var nodes := {"intro": {"text": ["%s, at your service. Any landing in the city, a copper's worth of oar." % nm.get_slice(" ", 1)], "next": "menu"}, "menu": menu}
		for j in range(P.LANDINGS.size()):
			if j == i:
				continue
			menu["choices"].append({"text": "Row me to %s." % str(P.LANDINGS[j][0]).to_lower(), "next": "go%d" % j})
			nodes["go%d" % j] = {"text": ["Off we go. Mind your head under the bridges."], "event": "canal_taxi:%d" % j, "next": "end"}
		menu["choices"].append({"text": "Not now.", "next": "end"})
		var did := _key("taxi%d" % i)
		Dialogue.define(did, {"speaker": nm, "voice": 0.9 + 0.05 * i, "start": "intro", "return": "menu", "nodes": nodes})
		var n := NPC.new()
		n.setup({"name": nm, "voice": 0.9 + 0.05 * i, "look": boatman_look(i), "dialogue": did, "yaw": float(sp[1]) + PI})
		n.ground_func = isl.walk_height
		add_child(n)
		n.position = sp[0]
		people[nm] = n
	if not Dialogue.dialogue_event.is_connected(_on_event):
		Dialogue.dialogue_event.connect(_on_event)


func _on_event(ev: String) -> void:
	if not ev.begins_with("canal_taxi:") or not is_inside_tree():
		return
	ride(int(ev.get_slice(":", 1)))


## Our captain rowed to landing `to`: a fade, then they're standing at it, facing the walkway.
func ride(to: int) -> void:
	var me := get_tree().get_first_node_in_group("player") as Node3D
	if me == null:
		return
	var sp: Array = _spot("landing%d" % to)
	var dest: Vector3 = isl.to_global(sp[0]) + Vector3.UP * 0.4
	if _fader == null:
		var cl := CanvasLayer.new()
		cl.layer = 90
		add_child(cl)
		_fader = ColorRect.new()
		_fader.color = Color(0, 0, 0, 0)
		_fader.set_anchors_preset(Control.PRESET_FULL_RECT)
		_fader.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cl.add_child(_fader)
	var tw := create_tween()
	tw.tween_property(_fader, "color:a", 1.0, 0.45)
	tw.tween_callback(func():
		me.global_position = dest
		me.reset_physics_interpolation()
		get_tree().call_group("hud", "show_toast", "The boatman rows you to %s." % str(P.LANDINGS[to][0]).to_lower()))
	tw.tween_interval(0.35)
	tw.tween_property(_fader, "color:a", 0.0, 0.5)


## A shipwright's ship choices (ShipClasses): buy the caravel (the arsenal's master only) while she isn't the crew's,
## and take out whichever ship is laid up. Shown only when they apply (read off the crew's kit as you talk).
static func _ship_choices(choices: Array, nodes: Dictionary, sells: bool) -> void:
	var kit := func() -> Dictionary: return ShipKit.merged((Engine.get_main_loop() as SceneTree).root.get_node("GameManager").ship_kit)
	if sells:
		choices.insert(0, {"text": "I'll buy the caravel (%s)." % ShipClasses.price_text("caravel"), "next": "buy",
			"if": func(): return not ShipClasses.owns(kit.call(), "caravel")})
	for cls in ShipClasses.CLASSES:
		var c: String = cls
		choices.insert(0, {"text": "I'll sail the %s." % str(ShipClasses.CLASSES[c]["name"]).to_lower(), "next": "sail_" + c,
			"if": func(): return ShipClasses.owns(kit.call(), c) and ShipClasses.class_of(kit.call()) != c})
		nodes["sail_" + c] = {"text": ["Right you are. I'll have her brought round."], "event": "ship:switch:" + c, "next": "end"}


func _on_lead(ev: String) -> void:
	if is_instance_valid(isl):
		CityCaches.sell_lead(ev, "canal", isl)


## (1.27 C4, docs/v1_27_plan.md "Investigations") The smuggling ring, Master Grane's: the arsenal's stores go missing
## by night; three crates chalked with the smugglers' mark in the calli, spread over the city, then back to
## Grane. Half again a quest's XP.
func _smugglers(common: Dictionary) -> void:
	var calli: Array = P.floors().filter(func(f): return str(f[0]).contains("_c") and not str(f[0]).ends_with("_campo"))
	if calli.size() < 3:
		return
	var marks := [["Look at the chalked crate", "A crate of the arsenal's own copper nails, chalked with a hook-and-eye. Someone's sorting stolen goods.", "a crate chalked with a hook-and-eye"],
		["Look at the second crate", "Pitch, the arsenal's, under a sailcloth. The same chalk mark, and a boatman's tally scratched beside it.", "a second chalked crate"],
		["Search the last crate", "Empty but for a scrap of a ledger: 'the glassworks' back door, Thursdays'. Grane will want to see this.", "the last chalked crate"]]
	var steps: Array = []
	for k in range(3):
		var r: Rect2 = calli[[0, calli.size() / 2, calli.size() - 1][k]][1]
		var q: Vector2 = r.get_center()
		steps.append({"do": "pickup", "at": isl.from_city(q), "yaw": 0.0, "search": marks[k][0], "goal": "Find %s in the calli" % marks[k][2], "said": marks[k][1]})
	steps.append({"do": "turnin", "goal": "Bring the ledger scrap to Master Grane at the arsenal"})
	smug_q = {"id": _key("inv_smugglers"), "kind": "lost", "giver": "Master Ottavio Grane", "src": "npc", "title": "The smuggling ring",
		"ask": "You look like a man missing something.", "plea": ["Copper, pitch, good oak. The arsenal's stores walk out of the gates by night and come back on other men's ships.",
			"The smugglers chalk what they take, so their boatmen know which crates to row away. Find their crates in the lanes. Follow the chalk."],
		"accept": "I'll follow the chalk.", "decline": "Not my stores.", "taken": "Hook-and-eye, they mark it. Start in the lanes; they leave them where nobody minds a crate.",
		"remind_choice": "About the smugglers...", "remind": ["Crates chalked with a hook-and-eye, in the lanes. Bring me what they lead to."],
		"done": "I followed the chalk.", "thanks": ["The glassworks' back door, Thursdays. So it's one of my own, selling out through the furnaces.",
			"I'll deal with him. You've earned this, and the arsenal's thanks."],
		"at": steps[0]["at"], "yaw": 0.0, "search": marks[0][0], "reward": {"gold": 150, "xp": 1.5}, "steps": steps}
	smug_q.merge(common)
	quest_node.add(smug_q, isl)


## (1.27 C4, docs/v1_27_plan.md "City jobs") The canal city's odd jobs, offered by its people (no board here): three
## fish for Carlotta's soup, her washing basket blown onto a roof, Father Anselm's blessed candles to Master Grane for a
## launch. Half a quest's XP each.
func _jobs(common: Dictionary) -> void:
	var soup := {"id": _key("job_soup"), "kind": "fetch", "giver": "Carlotta Vere", "src": "npc", "title": "Fish for the soup",
		"ask": "Short of anything?", "plea": ["Fish! The boats came in empty and I've a pot of soup and no soup in it. Three good fish, Captain. I'll pay."],
		"accept": "Three fish. Done.", "decline": "Not today.", "taken": "Fresh as you can. The lagoon's sardines, a bream, anything with fins.",
		"remind_choice": "About the fish...", "remind": ["Three fish, for the pot."], "done": "Three fish for the pot.",
		"thanks": ["Beautiful. The soup lives! A bowl's on the house tonight, and this."], "cost": [["fish", 3]], "reward": {"gold": 35, "xp": 0.5},
		"steps": [{"do": "turnin", "goal": "Bring three fish to Carlotta at the Oar and Lantern"}]}
	soup.merge(common)
	job_qs.append(soup)
	var flats: Array = P.lots().filter(func(l): return l.has("top_y") and str(l["roof"]) == "flat" and not l.has("hatch"))
	flats.sort_custom(func(a, b): return int(a["seed"]) < int(b["seed"]))
	if not flats.is_empty():
		var l: Dictionary = flats[0]
		var t: Transform3D = l["frame"]
		var wd: Vector2 = l["wd"]
		var p: Vector3 = t * Vector3(wd.x * 0.2, float(l["top_y"]), 0.0)
		var basket := {"id": _key("job_basket"), "kind": "lost", "giver": "Carlotta Vere", "src": "npc", "title": "The basket on the roofs",
			"ask": "You look windswept.", "plea": ["The wind! It took my whole basket of washing off the line and up onto the roofs. Sheets, aprons, the lot.",
				"You look like you climb things. Fetch it down?"],
			"accept": "I'll fetch it.", "decline": "Not my laundry.", "taken": "Over the lanes somewhere. The ladders go up from the calli.",
			"remind_choice": "About the basket...", "remind": ["On a roof over the lanes. Up a ladder."], "done": "Your washing, Carlotta.",
			"thanks": ["Every sheet! You're a treasure. Take this."], "at": isl.from_city(Vector2(p.x, p.z)), "yaw": 0.0, "search": "Take the basket",
			"reward": {"gold": 25, "xp": 0.5},
			"steps": [{"do": "pickup", "at": isl.from_city(Vector2(p.x, p.z)), "y": p.y + 0.05, "yaw": 0.0, "search": "Take the basket",
				"goal": "Find Carlotta's washing basket on the roofs", "said": "Sheets and aprons, a little gull-trodden. Back to Carlotta."},
				{"do": "turnin", "goal": "Bring the basket back to Carlotta at the Oar and Lantern"}]}
		basket.merge(common)
		job_qs.append(basket)
	var candles := {"id": _key("job_candles"), "kind": "deliver", "giver": "Father Anselm", "src": "npc", "title": "Candles for a launch",
		"ask": "Can I help, Father?", "plea": ["The arsenal launches a hull on the tide. Master Grane asked for blessed candles for her bow. My knees won't take me there and back."],
		"accept": "I'll take them.", "decline": "Not today, Father.", "taken": "Master Grane, at the arsenal. Mind you don't drop them in a canal.",
		"remind_choice": "About the candles...", "remind": ["To Master Grane at the arsenal."], "done": "Grane has the candles.",
		"thanks": ["Then she'll sail lucky. Bless you, Captain."], "recipient": "Master Ottavio Grane",
		"hand": "Blessed candles, from Father Anselm.", "got": ["Candles for her bow. The old man remembered. Good."],
		"reward": {"gold": 20, "xp": 0.5},
		"steps": [{"do": "talk", "who": "Master Ottavio Grane", "goal": "Take Father Anselm's candles to Master Grane at the arsenal", "said": "Delivered. Back to Father Anselm."},
			{"do": "turnin", "goal": "Tell Father Anselm the candles are delivered"}]}
	candles.merge(common)
	job_qs.append(candles)
	for j in job_qs:
		quest_node.add(j, isl)


## (1.27 C4, docs/v1_27_plan.md "Investigations": the drowned bell) Father Anselm's: the campanile's bell has lost its
## clapper. Up to the belfry to see the bell hanging dumb, then a dive to the Grand Canal's bed below the campanile for
## the clapper (a thing searched while swimming), and back to Anselm.
func _drowned_bell(common: Dictionary) -> void:
	var bt := CapitalBellTower.top((P.SPECIAL["campanile"][0] as Rect2).get_center(), P.QUAY_Y)
	var bed := Vector2(0.0, 61.5)
	var steps: Array = [{"do": "reach", "at": isl.from_city(Vector2(bt.x, bt.z)), "y": bt.y + 1.0, "r": 4.0,
			"goal": "Climb the campanile to the bell", "said": "The bell hangs dumb, its clapper gone. Below, in the Grand Canal, something glints."},
		{"do": "pickup", "at": isl.from_city(bed), "y": P.CANAL_BED + 0.15, "yaw": 0.0, "water": true, "search": "Haul up the clapper",
			"goal": "Dive for the clapper in the Grand Canal below the campanile", "said": "The clapper, heavy as an anchor, out of the silt. Back to Father Anselm."},
		{"do": "turnin", "goal": "Bring the clapper to Father Anselm at the church"}]
	bell_q = {"id": _key("inv_bell"), "kind": "lost", "giver": "Father Anselm", "src": "npc", "title": "The drowned bell",
		"ask": "The bells were quiet today.", "plea": ["Quiet! They haven't rung in three days. The ringer swears the clapper fell when the storm took the louvres.",
			"If it fell, it fell in the canal. My knees won't climb the stair, and my lungs won't dive. Would yours?"],
		"accept": "I'll find your clapper.", "decline": "Not today, Father.", "taken": "Climb up and look first. Then the canal, if it's there. God keep you dry. Or not.",
		"remind_choice": "About the bell...", "remind": ["The campanile, then the canal below it."],
		"done": "Your clapper, Father.", "thanks": ["Ha! Wet as a fish and twice as welcome. The ringer will have it hung by vespers.",
			"The lagoon will hear its hours again. Take this, with my blessing."],
		"at": isl.from_city(bed), "yaw": 0.0, "search": "Haul up the clapper", "reward": {"gold": 80}, "steps": steps}
	bell_q.merge(common)
	quest_node.add(bell_q, isl)


## (1.27 C5) The Lagoon's favour applied (asked of the Doge, and on every build so a loaded save keeps it).
func _on_favour(ev: String) -> void:
	if ev == "favour:canal":
		CityFavour.apply("canal", self, favour_shops())
	elif ev == "ruler:canal":
		CityFavour.thank("canal", self)


func favour_shops() -> Array:
	var out: Array = cast().filter(func(e): return e.has("shop")).map(func(e): return _key(str(e["shop"])))
	out.append(_key("inn"))
	return out
