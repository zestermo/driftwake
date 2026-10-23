class_name CapitalLife
extends Node3D
## The royal capital's people (docs/capital_plan.md, piece 3): its named folk at the places the district left for them
## (CapitalDistrict's spots): the innkeeper of the Crown and Compass and her patrons, the curio dealer (the treasure
## merchant: a tier above the islands'), the market's vendors (a grocer, a clothier and a fishmonger among them), the
## Watch's sergeant and the royal guards at the gates, the guild's clerk, the harbourmaster, a flower seller, the arena's
## crier and the counting house's doorman; the inn's rest, the notice board, three city quests through the journal
## with these people's own lines, and the toughs of Gallows Row (a GruntCamp: the host fights them, guests see puppets).
## The walking crowd is CapitalCrowd. Lives under the City node; every name, look, stock and post is fixed (or from the
## world's chain seed), so every screen has the same city.

const P := preload("res://scripts/island/capital_plan.gd")
const SHOPS := preload("res://scripts/game/shops.gd")
const BLUE := Color(0.16, 0.22, 0.5)
const GOLD := Color(0.86, 0.68, 0.26)
const GUARD := {"coat": "frock", "coat_color": Color(0.16, 0.22, 0.5), "trim_color": Color(0.86, 0.68, 0.26), "hat": "cavalier", "hat_color": Color(0.12, 0.12, 0.14),
	"legs": "breeches", "legs_color": Color(0.92, 0.9, 0.84), "feet": "tall_boots", "feet_color": Color(0.1, 0.08, 0.07), "belt": "belt", "vest": "none", "top": "shirt",
	"top_color": Color(0.94, 0.93, 0.9), "sleeves": "long", "eyepatch": false}
const TOUGH := {"hat": "none", "coat": "none", "vest": "jerkin", "legs": "slops", "belt": "belt", "sash_color": Color(0.3, 0.26, 0.22)}
const RUFFIANS := 4
## The yard's middle (the toughs' fire) and how far their fight reaches (the nav zone).
const YARD_R := 34.0

var isl
var quest_node: KitQuests
var ruffians: GruntCamp
var people := {}
var notices: Array = []


## Everyone named, in the order they're made: {"name", "spot", "voice", "look" (over the capital's folk look), and
## "barks" / "shop" / "dialogue" / "seated"}.
static func cast() -> Array:
	return [
		{"name": "Odile Marchbank", "spot": "innkeeper", "voice": 1.1, "dialogue": "inn", "look": {"body": "fem", "top": "blouse", "vest": "corset", "vest_color": Color(0.4, 0.16, 0.14)}},
		{"name": "Severin Quayle", "spot": "curio", "voice": 0.9, "shop": "curio", "look": {"body": "masc", "coat": "frock", "coat_color": Color(0.18, 0.3, 0.24), "trim_color": GOLD, "hat": "none"},
			"barks": ["Curios, rarities and things that ought to be in a museum. Mind the glass.", "Sea-gems? I pay what they're worth, which is more than anyone else in this city will tell you.",
				"Everything on this counter came off a ship that didn't come home. Don't ask which."]},
		{"name": "Sergeant Brannoch", "spot": "gate_guard0", "voice": 0.8, "dialogue": "sergeant", "look": GUARD.merged({"hat": "morion", "body": "masc"}, true)},
		{"name": "Guard Osric", "spot": "gate_guard1", "voice": 0.9, "look": GUARD, "barks": ["Welcome to the capital. Keep your blade sheathed inside the walls.", "The market's straight up the street. Mind your purse past the alley."]},
		{"name": "Guard Hale", "spot": "palace_guard0", "voice": 0.85, "look": GUARD, "barks": ["The palace is closed to visitors. By order of the Crown.", "No petitions today. Nor tomorrow, I shouldn't wonder."]},
		{"name": "Guard Wren", "spot": "palace_guard1", "voice": 1.05, "look": GUARD.merged({"body": "fem"}, true), "barks": ["Halt. Nobody goes up the hill without a royal seal.", "The court sits behind these gates. Not for the likes of us, Captain."]},
		{"name": "Ambrose Pell", "spot": "guild", "voice": 0.95, "dialogue": "clerk", "look": {"body": "masc", "coat": "frock", "coat_color": Color(0.22, 0.2, 0.18), "hat": "none", "eyepatch": false}},
		{"name": "Tobin Rook", "spot": "harbourmaster", "voice": 0.85, "dialogue": "harbour", "look": {"body": "masc", "coat": "longcoat", "coat_color": Color(0.14, 0.18, 0.32), "hat": "tricorn"}},
		{"name": "Mirela", "spot": "flower", "voice": 1.25, "dialogue": "flower", "look": {"body": "fem", "top": "blouse", "legs": "skirt", "hat": "straw"}},
		{"name": "Hesper", "spot": "stall0", "voice": 1.1, "shop": "grocer", "barks": ["Oranges from the south islands! Sweeter than the gossip!", "Flour, salt, pepper, eggs. Everything a ship's cook forgets."]},
		{"name": "Gilly", "spot": "stall1", "voice": 1.15, "shop": "fish", "barks": ["Caught this morning, sold this morning. That's the rule.", "Bait and tackle too, if you're the sort who'd rather do it yourself."]},
		{"name": "Lorne", "spot": "stall2", "voice": 0.95, "shop": "tailor", "barks": ["Dressed like that, you'll never see the inside of the palace. Let me help.", "City cuts! Frock coats, bicornes, gloves. You'll pass for a duke."]},
		{"name": "Old Bettany", "spot": "stall3", "voice": 1.3, "barks": ["Pots, jugs, pitchers! Thrown on the wheel, not at your head!", "This jug held wine at the old king's wedding. Probably."]},
		{"name": "Pim", "spot": "stall5", "voice": 1.2, "barks": ["Silks from the canal city! Well. From a man who's been there.", "Ribbon by the yard! Two yards for a crown!"]},
		{"name": "Joss", "spot": "barrow0", "voice": 1.0, "barks": ["Apples! Pears! A melon you could row home in!", "Fruit for the voyage. Keeps the teeth in your head."]},
		{"name": "Wynn", "spot": "barrow1", "voice": 1.1, "barks": ["Scarves and shawls, warm for the sea-winds!", "Feel that cloth. Go on. Softer than an Admiralty man's heart."]},
		{"name": "Dace", "spot": "fish0", "voice": 0.9, "barks": ["Eels! Live eels! Don't touch the bucket.", "The harbour's full of ships and every one of them wants fish."]},
		{"name": "Crier Maddox", "spot": "arena_crier", "voice": 1.0, "barks": ["Next season, the Grand Arena opens its gates! Champions from every sea!",
			"Hear ye! The arena seeks fighters! Next season, mind. Today they're still sweeping out the lions.", "Glory, gold and a royal purse! Next season, at the Grand Arena!"]},
		{"name": "Doorman Fenwick", "spot": "bank", "voice": 0.85, "barks": ["The Royal Counting House is shut by decree until the new treasurer is sworn in.",
			"No deposits, no withdrawals, no loitering. Come back when the Crown says so."]},
		{"name": "Mags", "spot": "inn_patron0", "voice": 1.15, "barks": ["Odile's fish pie. Best thing in the city, and I've eaten at the palace. Once. In the kitchens.", "Don't go down Gallows Row with a full purse. Don't go down it at all."]},
		{"name": "Old Corwin", "spot": "inn_patron2", "voice": 0.75, "barks": ["When I was a boy you could walk right up to the palace door. Now look at it.", "They say the arena's built on the old king's dungeons. Lions down there still, they say."]},
		{"name": "Docker Huw", "spot": "porter1", "voice": 0.9, "barks": ["Mind your back, Captain! Crates coming through!", "Forty ships in a morning, some days. Never seen a port like it."]},
	]


## A person's look: the capital's townsfolk look from their name (the same on every screen), with their own over it.
static func look_of(c: Dictionary) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(c["name"]))
	var lk := KitStyle.folk_look(KitStyle.of("capital"), rng)
	lk.merge(c.get("look", {}), true)
	lk["name"] = c["name"]
	return lk


## Every body this builds (CapitalIsland.prepare stocks them on its worker).
static func looks() -> Array:
	return cast().map(func(c): return look_of(c))


func setup(island) -> CapitalLife:
	name = "Life"
	isl = island
	return self


## Everything (CapitalIsland's last steps, in order): the shops, the people, the inn, the quests and the board, the toughs.
func steps() -> Array:
	return [["life", _shops], ["life", _people], ["life", _inn], ["life", _quests], ["life", _ruffians]]


func _key(what: String) -> String:
	return isl.save_key("capital_" + what)


## A spot the district left (frame) in island space: [Vector3, the yaw facing its way].
func _spot(spot: String) -> Array:
	var sp: Array = isl.spots[spot]
	var v: Vector3 = sp[0]
	var p: Vector2 = isl.from_city(Vector2(v.x, v.z))
	return [Vector3(p.x, v.y, p.y), float(sp[1]) + float(isl.yaw)]


# --------------------------------------------------------------------------
func _shops() -> void:
	var t := mini(Levels.tier(int(isl.node["level"])) + 1, 4)
	var curio := _key("curio")
	SHOPS.extra[curio] = {"name": "Quayle's Curios", "line": "Rarities for the discerning captain. Better than anything you'll find on an island, and priced like it.",
		"trade": "treasure", "tier": maxi(t, 3),
		"stock": SHOPS.with_traits([["tonic", 30], ["rum", 9], ["cutlass@%d" % maxi(t, 3)], ["katana@%d" % maxi(t - 1, 2)], ["pistol@%d" % maxi(t - 1, 2)],
			["accessory", "earring", {"earring": true}, 2, 60], ["accessory", "cloak", {"cloak": true, "cloak_color": Color(0.16, 0.2, 0.42)}, maxi(t - 1, 2), 220]], curio),
		"buys": {"loot": 1.0, "gear": 0.5, "weapon": 0.55}}
	SHOPS.extra[_key("grocer")] = {"name": "Hesper's Greengrocery", "line": "Fresh from the south islands this morning. Mostly.", "trade": "grocer",
		"stock": [["flour", 3], ["salt", 3], ["egg", 3], ["rum", 9]], "pool": [["pepper"], ["rice"], ["mushroom"], ["coconut"], ["jungle_fruit"], ["seaweed"]], "size": 3,
		"buys": {"ingredient": 0.5}}
	SHOPS.extra[_key("fish")] = {"name": "Gilly's Fish", "line": "Caught this morning. Sold by noon.", "trade": "grocer",
		"stock": [["fish", 5], ["bait_worm"], ["bait_shrimp"]], "pool": [["crab_meat"], ["oyster"], ["seaweed"], ["salt"], ["rod_bamboo"]], "size": 2,
		"buys": {"ingredient": 0.5}}
	SHOPS.extra[_key("tailor")] = {"name": "Lorne & Daughters", "line": "City cuts. You'll pass for a duke, if nobody looks at your boots.", "trade": "tailor", "size": 4,
		"stock": [["head", "bicorne", {"hat": "bicorne", "hat_color": BLUE}, 1, 85], ["coat", "frock", {"coat": "frock", "coat_color": Color(0.36, 0.12, 0.1), "trim_color": GOLD}, 1, 140],
			["hands", "gloves", {"gloves": true, "gloves_color": Color(0.92, 0.9, 0.85)}, 0, 25]],
		"pool": [["head", "cavalier", {"hat": "cavalier", "hat_color": Color(0.14, 0.12, 0.12)}, 1, 95], ["coat", "longcoat", {"coat": "longcoat", "coat_color": BLUE, "trim_color": GOLD}, 1, 120],
			["vest", "corset", {"vest": "corset", "vest_color": Color(0.24, 0.17, 0.12)}, 1, 70], ["legs", "breeches", {"legs": "breeches", "legs_color": Color(0.92, 0.9, 0.84)}, 0, 30],
			["feet", "cavalier_boots", {"feet": "cavalier_boots", "feet_color": Color(0.24, 0.12, 0.08)}, 1, 110], ["coat", "greatcoat", {"coat": "greatcoat", "coat_color": Color(0.2, 0.2, 0.22)}, 1, 160]],
		"buys": {"gear": 0.5}}
	SHOPS.extra[_key("inn")] = {"name": "The Crown and Compass", "line": "Fish pie, stew and a decent wine. Rooms upstairs.", "trade": "cook",
		"stock": [["stew", 16], ["rum", 8], ["fish_stew"]], "pool": [["porridge"], ["peppered_boar"], ["island_skewers"]], "size": 1, "buys": {"consumable": 0.4}}


func _people() -> void:
	var lks := looks()
	var c := cast()
	for i in range(c.size()):
		var e: Dictionary = c[i]
		var sp: Array = _spot(e["spot"])
		var cfg := {"name": e["name"], "voice": e["voice"], "look": lks[i], "seated": e.get("seated", false), "yaw": float(sp[1]) + PI}
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


## Resting at the inn: at its door, as a village's (heal, refill, save).
func _inn() -> void:
	var rest := Interactable.new()
	rest.name = "Rest"
	rest.collision_layer = 512
	rest.collision_mask = 0
	rest.prompt_text = "Rest at the Crown and Compass"
	rest.gesture = "push"
	var cs := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 2.2
	cs.shape = sph
	rest.add_child(cs)
	add_child(rest)
	rest.position = (_spot("inn_door")[0] as Vector3) + Vector3(0, 1.3, 0)
	rest.interacted.connect(func(player: Player): player.call("_toast", GameManager.rest(player)))
	var board_at: Vector3 = _spot("board")[0]
	var read := Interactable.new()
	read.name = "Read"
	read.collision_layer = 512
	read.collision_mask = 0
	read.prompt_text = "Read the notice board"
	read.gesture = "reach"
	var rcs := CollisionShape3D.new()
	var rsph := SphereShape3D.new()
	rsph.radius = 1.8
	rcs.shape = rsph
	read.add_child(rcs)
	add_child(read)
	read.position = board_at + Vector3(0, 1.2, 0.8)
	read.interacted.connect(func(_p): Dialogue.start(_key("board"), read))
	for k in range(4):
		var bench := Props.bench()
		bench.name = "Bench%d" % k
		add_child(bench)
		bench.position = _spot("bench%d" % k)[0]
		bench.rotation.y = float(_spot("bench%d" % k)[1])


# --------------------------------------------------------------------------
# The city's quests: the Watch's notice on the board, the clerk's sealed ledger, the flower seller's locket
# --------------------------------------------------------------------------
func _quests() -> void:
	quest_node = KitQuests.new()
	quest_node.name = "Quests"
	add_child(quest_node)
	var yard := P.FLOORS[7][1] as Rect2
	var yard_c: Vector2 = yard.get_center()
	var common := {"isle": isl.island_name, "pos": isl.position, "favour_ask": "", "favour_thanks": []}
	var gallows := {"id": _key("gallows"), "kind": "bounty", "giver": "Sergeant Brannoch", "src": "board", "title": "Clear out Gallows Row",
		"notice": "BY ORDER OF THE WATCH: toughs have taken the yard at the end of Gallows Row and are robbing honest folk. Eighty crowns to whoever clears them out. Report to Sergeant Brannoch at the sea gate.",
		"posted": "Cleared the whole yard? Ha! The Watch has been trying for a month. Here, as promised, and a drink on me next time.",
		"clear": func(): return ruffians != null and ruffians.alive_count() == 0, "poi_at": isl.from_city(yard_c), "reward": {"gold": 80},
		"steps": [{"do": "clear", "goal": "Clear the toughs out of Gallows Row's yard", "said": "Gallows Row: cleared. Report to Sergeant Brannoch."},
			{"do": "turnin", "goal": "Report to Sergeant Brannoch at the sea gate"}]}
	gallows.merge(common)
	quest_node.add(gallows, isl)
	notices.append(gallows)
	var ledger := {"id": _key("ledger"), "kind": "deliver", "giver": "Ambrose Pell", "src": "npc", "title": "Sealed with wax",
		"recipient": "Tobin Rook", "reward": {"gold": 45},
		"ask": "You look busy, clerk.", "plea": ["Busy? I'm drowning. The harbourmaster wants the guild's tariff ledger by noon and I can't leave the hall.",
			"Take it down to Tobin Rook on the quay? Don't break the seal. Don't read it. Don't drop it in the harbour."],
		"accept": "I'll take it down.", "decline": "Not my errand.", "taken": "Bless you. Rook's booth is by the berths, past the cranes.",
		"remind_choice": "About that ledger...", "remind": ["Tobin Rook, on the quay, by the berths. Seal unbroken, please."],
		"done": "Rook has his ledger.", "thanks": ["He signed for it? Without a single complaint? You must have caught him on a good day.", "Here. The guild pays its runners. Eventually. Today, as it happens."],
		"hand": "A ledger from the Merchants' Guild.", "got": ["Pell's ledger? About time. Seal's intact, too. Tell the clerk I'll forgive him. This once."],
		"steps": [{"do": "talk", "who": "Tobin Rook", "goal": "Take the guild's ledger to Tobin Rook on the quay", "said": "The ledger's with the harbourmaster. Tell Ambrose Pell."},
			{"do": "turnin", "goal": "Tell Ambrose Pell at the guild hall it's delivered"}]}
	ledger.merge(common)
	quest_node.add(ledger, isl)
	var locket_at: Vector2 = yard_c + Vector2(-9.0, 12.0)
	var locket := {"id": _key("locket"), "kind": "lost", "giver": "Mirela", "src": "npc", "title": "My mother's locket",
		"at": isl.from_city(locket_at), "yaw": 0.6, "search": "Search the rubbish", "reward": {"gold": 30, "items": [["tonic", 1]]},
		"ask": "Something the matter? You've been crying.", "plea": ["A cutpurse snatched my mother's locket this morning, right off my neck. He ran down Gallows Row.",
			"The Watch won't go down there. Nobody will. It's silver, with a picture inside. It's all I have of her."],
		"accept": "I'll find it.", "decline": "I'm sorry. I can't.", "taken": "Oh! Thank you! Be careful. They say the toughs keep what they steal in the yard at the end.",
		"remind_choice": "About your locket...", "remind": ["Down Gallows Row, past the washing lines, in the yard at the end. Please be careful."],
		"done": "I found your locket.", "thanks": ["That's it! That's her! I... thank you. I haven't much, but take this. And a flower. Take a flower."],
		"found": "A silver locket in the rubbish. A tiny portrait inside.",
		"steps": [{"do": "pickup", "goal": "Find Mirela's locket in Gallows Row's yard", "said": "A silver locket in the rubbish. Bring it back to Mirela."},
			{"do": "turnin", "goal": "Bring the locket back to Mirela by the fountain"}]}
	locket.merge(common)
	quest_node.add(locket, isl)
	_talk(gallows, ledger, locket)


func _talk(gallows: Dictionary, ledger: Dictionary, locket: Dictionary) -> void:
	var board: Array = []
	var bnodes := {"start": {"text": "Notices pinned three deep: a reward from the Watch, a lost goat answering to Bartholomew, the arena's season (next spring), a room to let above the bakery.", "choices": board}}
	quest_node.post(gallows, board, bnodes)
	board.append({"text": "Leave it.", "next": "end"})
	Dialogue.define(_key("board"), {"speaker": "Notice board", "voice": 1.0, "start": "start", "nodes": bnodes})
	var smenu := {"text": "Something you need, Captain?", "choices": [{"text": "What's the city like?", "next": "city"}, {"text": "What's down Gallows Row?", "next": "row"}]}
	var snodes := {"intro": {"text": ["Sergeant Brannoch, the Watch. Welcome to %s." % isl.island_name, "Sheathe that blade inside the walls and we'll get on fine."], "next": "menu"},
		"menu": smenu, "city": {"text": ["Biggest port in the sea. Market's up the street, palace on the hill, arena east of the plaza. Palace and arena are shut to the likes of us, for now."], "next": "menu"},
		"row": {"text": ["The slums, west off the market street. There's a yard at the end the toughs have taken. I've a notice up on the board, if you've the stomach."], "next": "menu"}}
	quest_node.report(gallows, smenu["choices"], snodes)
	smenu["choices"].append({"text": "Goodbye.", "next": "end"})
	Dialogue.define(_key("sergeant"), {"speaker": "Sergeant Brannoch", "voice": 0.8, "start": "intro", "return": "menu", "nodes": snodes})
	var cmenu := {"text": "The guild's business, Captain?", "choices": []}
	var cnodes := {"intro": {"text": ["Ambrose Pell, clerk to the Merchants' Guild. If you've a cargo to register, the queue starts on the steps."], "next": "menu"}, "menu": cmenu}
	quest_node.offer(ledger, cmenu["choices"], cnodes)
	cmenu["choices"].append({"text": "Goodbye.", "next": "end"})
	Dialogue.define(_key("clerk"), {"speaker": "Ambrose Pell", "voice": 0.95, "start": "intro", "return": "menu", "nodes": cnodes})
	var hmenu := {"text": "Berth fees are paid, Captain. Something else?", "choices": [{"text": "Busy harbour.", "next": "busy"}]}
	var hnodes := {"intro": {"text": ["Tobin Rook, harbourmaster. Your sloop's berthed and logged. No fee for a captain the Crown's heard of. Which you aren't. Yet."], "next": "menu"},
		"menu": hmenu, "busy": {"text": ["Forty ships a morning in the season. Merchantmen, navy, the odd pirate pretending to be a merchantman. I log them all."], "next": "menu"}}
	quest_node.hand_over(ledger, hmenu["choices"], hnodes)
	hmenu["choices"].append({"text": "Goodbye.", "next": "end"})
	Dialogue.define(_key("harbour"), {"speaker": "Tobin Rook", "voice": 0.85, "start": "intro", "return": "menu", "nodes": hnodes})
	var fmenu := {"text": "Flowers, Captain? For someone special?", "choices": []}
	var fnodes := {"intro": {"text": ["Flowers! Fresh flowers!"], "next": "menu"}, "menu": fmenu}
	quest_node.offer(locket, fmenu["choices"], fnodes)
	fmenu["choices"].append({"text": "Not today.", "next": "end"})
	Dialogue.define(_key("flower"), {"speaker": "Mirela", "voice": 1.25, "start": "intro", "return": "menu", "nodes": fnodes})
	var imenu := {"text": "What'll it be, love?", "choices": [{"text": "Something to eat.", "next": "eat"}, {"text": "A room?", "next": "room"}, {"text": "What's the news?", "next": "news"}]}
	var inodes := {"intro": {"text": ["Welcome to the Crown and Compass! Best beds in the capital and the only honest wine."], "next": "menu"}, "menu": imenu,
		"eat": {"text": ["Fish pie, stew, whatever's in the pot. Sit, sit."], "event": "shop:" + _key("inn"), "next": "end"},
		"room": {"text": ["Rest at the door whenever you like. A bed, a bath, and I'll keep your things dry."], "next": "menu"},
		"news": {"text": ["The arena opens next season, they say. Half the sea's coming to fight in it.", "And the palace has been shut a month. Nobody's seen the king since the spring tides. Don't repeat that."], "next": "menu"}}
	imenu["choices"].append({"text": "Goodbye.", "next": "end"})
	Dialogue.define(_key("inn"), {"speaker": "Odile Marchbank", "voice": 1.1, "start": "intro", "return": "menu", "nodes": inodes})


# --------------------------------------------------------------------------
## The toughs of Gallows Row round their fire: a GruntCamp in the yard (every machine builds it; the host runs it).
func _ruffians() -> void:
	var fire: Array = _spot("fire")
	var camp := GruntCamp.new()
	camp.name = "Ruffians"
	camp.warm_start = true
	camp.respawn_time = 900.0
	camp.level = int(isl.node["level"])
	camp.position = fire[0]
	for i in range(RUFFIANS):
		var sp: Array = _spot("ruffian%d" % i)
		var rng := RandomNumberGenerator.new()
		rng.seed = 8801 + i
		var lk := PirateGrunt.crew_look(rng)
		lk.merge(TOUGH, true)
		lk["name"] = "Tough"
		camp.add_grunt({"post": (sp[0] as Vector3) - (fire[0] as Vector3), "yaw": float(sp[1]) + PI, "mode": "stand", "look": lk,
			"title": "Gallows Row Tough", "seed": 8801 + i, "role": "rifle" if i == RUFFIANS - 1 else "sword"})
	add_child(camp)
	ruffians = camp
	var baker: Node = isl.get_parent().get_node_or_null("NavBaker")
	if baker:
		baker.add_zone(camp, YARD_R, false, isl.nav_faces)
