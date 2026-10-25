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
		{"name": "Guard Hale", "spot": "palace_guard0", "voice": 0.85, "look": GUARD, "barks": ["The grounds are open to petitioners. Keep to the road; it's steeper than it looks.", "Petitions to the Lord Chamberlain, in the court at the top."]},
		{"name": "Guard Wren", "spot": "palace_guard1", "voice": 1.05, "look": GUARD.merged({"body": "fem"}, true), "barks": ["Up the hill, Captain, and mind the edges.", "The court sits at the top. Her Majesty hears petitions, when the Lord Chamberlain allows it."]},
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
		{"name": "Crier Maddox", "spot": "arena_crier", "voice": 1.0, "barks": ["The Grand Arena is open! Six on the ladder and a champion at the top!",
			"Hear ye! A purse for every bout! See the Arena Master inside!", "Wooden blades, real bruises! Step onto the sand!"]},
		{"name": "Doorman Fenwick", "spot": "bank", "voice": 0.85, "barks": ["The Royal Counting House is shut by decree until the new treasurer is sworn in.",
			"No deposits, no withdrawals, no loitering. Come back when the Crown says so."]},
		{"name": "Mags", "spot": "inn_patron0", "voice": 1.15, "barks": ["Odile's fish pie. Best thing in the city, and I've eaten at the palace. Once. In the kitchens.", "Don't go down Gallows Row with a full purse. Don't go down it at all."]},
		{"name": "Old Corwin", "spot": "inn_patron2", "voice": 0.75, "barks": ["When I was a boy you could walk right up to the palace door. Now look at it.", "They say the arena's built on the old king's dungeons. Lions down there still, they say."]},
		{"name": "Docker Huw", "spot": "porter1", "voice": 0.9, "barks": ["Mind your back, Captain! Crates coming through!", "Forty ships in a morning, some days. Never seen a port like it."]},
		# 1.21: the docks
		{"name": "Marta Coyle", "spot": "shipwright", "voice": 1.0, "dialogue": "shipwright", "look": {"body": "fem", "top": "shirt", "vest": "jerkin", "vest_color": Color(0.32, 0.24, 0.16),
			"legs": "slops", "hat": "none", "gloves": true, "gloves_color": Color(0.42, 0.3, 0.2)}},
		{"name": "Ned Hollin", "spot": "shipwright_hand", "voice": 0.95, "barks": ["Forty ribs to a hull this size. I've counted them twice. Marta's counted them nine times.",
			"Mind the adze, Captain. It's sharper than it looks, and it looks very sharp."]},
		{"name": "Bram Haskett", "spot": "chandler", "voice": 0.85, "shop": "chandler", "barks": ["Rope, canvas, copper sheet, good oak. Everything a ship eats.",
			"Your shipwright will want timber. Marta always wants timber."]},
		{"name": "Vesper Lark", "spot": "fence", "voice": 1.05, "shop": "fence", "look": {"body": "fem", "coat": "longcoat", "coat_color": Color(0.16, 0.14, 0.16), "hat": "tricorn",
			"hat_color": Color(0.1, 0.1, 0.1)}, "barks": ["Whatever it is, I don't want to know where it came from. I want to know what it's worth.",
			"The Watch doesn't come down this end of the wharf. Neither does the Admiralty, if they know what's good for them."]},
		{"name": "Sal Dunnock", "spot": "smuggler0", "voice": 0.8, "look": TOUGH, "barks": ["Keep walking, friend. Nothing to see but crates.", "Vesper's busy. Vesper's always busy."]},
		{"name": "Fitch", "spot": "smuggler1", "voice": 1.15, "look": TOUGH, "barks": ["You didn't see me. I didn't see you. Lovely.", "Ask no questions, buy no lies."]},
		{"name": "Rowe", "spot": "docker0", "voice": 0.9, "barks": ["Up the row, down the row, all day. My back's older than I am.", "Wool for the canal city, wine for the palace. Same crates."]},
		{"name": "Tamsin", "spot": "docker1", "voice": 1.1, "barks": ["Heave! Ho! Don't drop it, it's the duke's!", "They say the canal city builds a ship a week. Show-offs."]},
		{"name": "Big Ollie", "spot": "docker2", "voice": 0.75, "barks": ["Hup.", "Crate. Crate. Barrel. Crate."]},
		{"name": "Gully Bracewell", "spot": "foreman", "voice": 0.9, "dialogue": "foreman", "look": {"body": "masc", "coat": "longcoat", "coat_color": Color(0.36, 0.3, 0.22), "hat": "tricorn"}},
		# 1.21: the noble quarter
		{"name": "Ysolde Ashgrove", "spot": "outfitter", "voice": 1.0, "shop": "outfitter", "look": {"body": "fem", "coat": "frock", "coat_color": Color(0.2, 0.18, 0.4), "trim_color": GOLD,
			"hat": "none"}, "barks": ["Ashgrove & Daughters: outfitters to the court. We don't do 'serviceable'.", "That coat has seen a storm or two. Let me show you one that has seen a ballroom."]},
		{"name": "Lady Corisande Halloway", "spot": "noble0", "voice": 1.15, "dialogue": "lady", "look": {"body": "fem", "top": "blouse", "legs": "skirt", "coat": "frock",
			"coat_color": Color(0.5, 0.18, 0.28), "trim_color": GOLD, "hat": "none"}},
		{"name": "Lord Peregrine Stroud", "spot": "noble1", "voice": 0.85, "look": {"body": "masc", "coat": "frock", "coat_color": Color(0.14, 0.26, 0.2), "trim_color": GOLD, "hat": "bicorne",
			"hat_color": Color(0.1, 0.1, 0.12)}, "barks": ["A pirate? On the terrace? Whatever next.", "The palace has been shut a month. One hears things. One repeats very few of them."]},
		{"name": "Dame Ottilie Fane", "spot": "noble2", "voice": 1.2, "look": {"body": "fem", "top": "blouse", "legs": "skirt", "coat": "frock", "coat_color": Color(0.3, 0.3, 0.46),
			"trim_color": GOLD, "hat": "none"}, "barks": ["Have you seen the arena? Vulgar. Marvellous, but vulgar.", "My nephew went to sea. He came back with a parrot and no manners."]},
		{"name": "Master Lucan Dray", "spot": "noble3", "voice": 0.95, "look": {"body": "masc", "coat": "longcoat", "coat_color": Color(0.36, 0.14, 0.12), "trim_color": GOLD, "hat": "none"},
			"barks": ["I collect captains' stories. Tell me yours. No? Pity.", "Ashgrove's coats are the only thing in this city worth what they cost."]},
		{"name": "Guard Ellery", "spot": "terrace_guard", "voice": 0.9, "look": GUARD, "barks": ["The terrace is open to all, Captain. Behave as though it weren't.", "Keep to the paths. The duchess counts her roses."]},
		# 1.21: the palace
		{"name": "Queen Ilsabet", "spot": "queen", "voice": 1.0, "dialogue": "queen", "look": {"body": "fem", "top": "blouse", "legs": "skirt", "coat": "frock",
			"coat_color": Color(0.32, 0.14, 0.4), "trim_color": GOLD, "hat": "none", "cloak": true, "cloak_color": Color(0.5, 0.1, 0.12)}},
		{"name": "Lord Chamberlain Orme", "spot": "chamberlain", "voice": 0.85, "dialogue": "chamberlain", "look": {"body": "masc", "coat": "frock", "coat_color": Color(0.12, 0.12, 0.16),
			"trim_color": GOLD, "hat": "none"}},
		{"name": "Guard Brisk", "spot": "hall_guard0", "voice": 0.9, "look": GUARD, "barks": ["The throne hall. Mind your manners and your boots.", "Her Majesty hears petitions. Briefly."]},
		{"name": "Guard Talmadge", "spot": "hall_guard1", "voice": 0.8, "look": GUARD.merged({"hat": "morion"}, true), "barks": ["Hands where I can see them, Captain.", "Nobody draws steel in this hall. Nobody."]},
		{"name": "Guard Pryce", "spot": "court_guard0", "voice": 0.95, "look": GUARD, "barks": ["The court's this way. The Lord Chamberlain will see you.", "Keep to the paving."]},
		{"name": "Guard Oakes", "spot": "court_guard1", "voice": 1.0, "look": GUARD.merged({"body": "fem"}, true), "barks": ["Up the steps for the throne hall. Petitions to the Lord Chamberlain first.", "Fine view from up here, isn't it? Don't lean on the wall."]},
		{"name": "Countess Mireille Dorne", "spot": "courtier0", "voice": 1.15, "look": {"body": "fem", "top": "blouse", "legs": "skirt", "coat": "frock", "coat_color": Color(0.16, 0.32, 0.36),
			"trim_color": GOLD, "hat": "none"}, "barks": ["The King hasn't held court since the spring tides. One wonders. One doesn't say.", "A pirate in the throne hall. How thrilling. How unsanitary."]},
		{"name": "Sir Tobias Wrexham", "spot": "courtier1", "voice": 0.8, "look": {"body": "masc", "coat": "frock", "coat_color": Color(0.4, 0.3, 0.12), "trim_color": GOLD, "hat": "none"},
			"barks": ["Her Majesty rules well. Better than some would like.", "Someone took the Queen's signet. In her own palace. Imagine the nerve."]},
		# 1.21: the arena
		{"name": "Arena Master Corvin Bale", "spot": "arena_master", "voice": 0.85, "dialogue": "arena", "look": {"body": "masc", "coat": "frock",
			"coat_color": Color(0.5, 0.12, 0.1), "trim_color": GOLD, "hat": "bicorne", "hat_color": Color(0.1, 0.1, 0.12)}},
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
	# 1.21: the docks' chandler (the shipwright's materials), the fence (rare blades with their traits; full price for
	# plunder, no questions), the terrace's outfitter (the rare-gear merchant: gear a tier above, a rare piece every day)
	SHOPS.extra[_key("chandler")] = {"name": "Haskett's Chandlery", "line": "Rope, canvas, copper sheet and good oak. Everything a ship eats.", "trade": "grocer",
		"stock": [["timber", 4], ["canvas", 4], ["iron", 4], ["rum", 9]], "pool": [["copper"], ["biscuit"], ["tonic"], ["pearl"]], "size": 2,
		"buys": {"ingredient": 0.4, "loot": 0.6}}
	SHOPS.extra[_key("fence")] = {"name": "Vesper's Corner", "line": "No names, no questions, no receipts. Fair prices, mostly.", "trade": "treasure",
		"tier": maxi(t, 3), "stock": SHOPS.with_traits([["rum", 9], ["tonic", 30], ["dagger@%d" % maxi(t, 3)], ["pistol@%d" % maxi(t, 3)], ["spear@%d" % maxi(t - 1, 2)]], _key("fence")),
		"buys": {"loot": 1.15, "gear": 0.5, "weapon": 0.7}}
	SHOPS.extra[_key("outfitter")] = {"name": "Ashgrove & Daughters", "line": "Outfitters to the court. Cut for a duke, priced for one.", "trade": "treasure", "tier": mini(t + 1, 4),
		"stock": [["coat", "frock", {"coat": "frock", "coat_color": Color(0.2, 0.18, 0.4), "trim_color": GOLD}, mini(t + 1, 4)],
			["head", "bicorne", {"hat": "bicorne", "hat_color": Color(0.1, 0.1, 0.12)}, mini(t + 1, 4)],
			["accessory", "cloak", {"cloak": true, "cloak_color": Color(0.36, 0.12, 0.14)}, mini(t + 1, 4)],
			["accessory", "earring", {"earring": true}, mini(t + 1, 4)]],
		"pool": [["feet", "cavalier_boots", {"feet": "cavalier_boots", "feet_color": Color(0.14, 0.1, 0.08)}, mini(t + 1, 4)],
			["hands", "gloves", {"gloves": true, "gloves_color": Color(0.1, 0.1, 0.12)}, mini(t + 1, 4)],
			["coat", "greatcoat", {"coat": "greatcoat", "coat_color": Color(0.16, 0.2, 0.3)}, mini(t + 1, 4)],
			["vest", "corset", {"vest": "corset", "vest_color": Color(0.3, 0.12, 0.16)}, mini(t + 1, 4)]], "size": 2,
		"buys": {"gear": 0.6, "loot": 1.0}}
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
	# 1.21: the foreman's manifest, lost on the wharf; Lady Halloway's invitation, carried to the inn
	var mv: Vector3 = isl.spots["manifest"][0]
	var manifest := {"id": _key("manifest"), "kind": "lost", "giver": "Gully Bracewell", "src": "npc", "title": "The lost manifest",
		"at": isl.from_city(Vector2(mv.x, mv.z)), "yaw": 0.3, "search": "Search behind the timber", "reward": {"gold": 40, "items": [["timber", 2]]},
		"ask": "Trouble, foreman?", "plea": ["Trouble? I've a ship's worth of cargo and no manifest. Blew off my board this morning, somewhere on the wharf.",
			"Without it, the Guild says it's all contraband and takes a third. Vesper's lot would love that. Help me look?"],
		"accept": "I'll look for it.", "decline": "Not my cargo.", "taken": "Try the timber stacks by the hall. The wind always ends up there.",
		"remind_choice": "About your manifest...", "remind": ["The wharf, by the timber stacks. A sheet of paper with the Guild's seal. Hurry, before the clerks come round."],
		"done": "Found your manifest.", "thanks": ["That's the one! Seal and all. You've saved me a third of a hold. Here, take a cut, and some of Marta's good oak."],
		"found": "A sheet of paper with the Merchants' Guild's seal, pinned under a log.",
		"steps": [{"do": "pickup", "goal": "Find the foreman's manifest on the wharf", "said": "The manifest, under the timber. Bring it to Gully Bracewell."},
			{"do": "turnin", "goal": "Bring the manifest back to Gully Bracewell on the wharf"}]}
	manifest.merge(common)
	quest_node.add(manifest, isl)
	var invite := {"id": _key("invite"), "kind": "deliver", "giver": "Lady Corisande Halloway", "src": "npc", "title": "An invitation, by hand",
		"recipient": "Odile Marchbank", "reward": {"gold": 60},
		"ask": "Can I help, my lady?", "plea": ["Help? How novel. I need an invitation carried to Odile Marchbank at the Crown and Compass.",
			"My footman has gone to the arena. Again. Take it down, would you? The seal is the house's. Do not open it."],
		"accept": "I'll carry it.", "decline": "I'm no footman.", "taken": "Splendid. Down the avenue, across the plaza, the inn with the arcade.",
		"remind_choice": "About your invitation...", "remind": ["To Odile Marchbank, at the Crown and Compass. By hand, Captain."],
		"done": "Odile has your invitation.", "thanks": ["She's accepted? Of course she has. Nobody refuses a Halloway supper. Here, for your trouble."],
		"hand": "An invitation from Lady Halloway.", "got": ["From Lady Halloway? To me? Well! I've cooked for her table but never sat at it. Tell her yes. Tell her YES."],
		"steps": [{"do": "talk", "who": "Odile Marchbank", "goal": "Carry Lady Halloway's invitation to Odile Marchbank at the Crown and Compass", "said": "Odile has it. Tell Lady Halloway."},
			{"do": "turnin", "goal": "Tell Lady Halloway on the terrace her invitation was taken"}]}
	invite.merge(common)
	quest_node.add(invite, isl)
	var pal := _palace_quests(common)
	_talk(gallows, ledger, locket, invite, pal[0])
	_talk_docks(manifest, invite)
	_talk_palace(pal[0], pal[1], pal[2])
	_talk_arena()


## The docks' and the terrace's talkers: Marta Coyle (her yard), the foreman (his manifest), Lady Halloway (her invitation).
func _talk_docks(manifest: Dictionary, invite: Dictionary) -> void:
	var ymenu := {"text": "What'll it be, Captain? Refit, paint or just admiring?", "choices": [{"text": "Show me what you can do to my ship.", "next": "yard"},
		{"text": "Whose hull is that?", "next": "hull"}]}
	var ynodes := {"intro": {"text": ["Marta Coyle, shipwright. Tackett at Brinehollow taught me to drive a peg, and I taught him to drive a bargain.",
		"Anything his yard does, mine does, and closer to the deep water."], "next": "menu"}, "menu": ymenu,
		"yard": {"text": ["Let's have a look at her, then."], "event": "shipwright:Coyle", "next": "end"},
		"hull": {"text": ["A merchant's caravel, for the Guild. Pretty thing when she's done. If you want a ship of your own like her, the canal city's yards build them by the dozen."],
			"next": "menu"}}
	ymenu["choices"].append({"text": "Goodbye.", "next": "end"})
	Dialogue.define(_key("shipwright"), {"speaker": "Marta Coyle", "voice": 1.0, "start": "intro", "return": "menu", "nodes": ynodes})
	var gmenu := {"text": "Make it quick, Captain, there's a hold to empty.", "choices": []}
	var gnodes := {"intro": {"text": ["Gully Bracewell, foreman. Everything that comes off a ship on this wharf goes past me."], "next": "menu"}, "menu": gmenu}
	quest_node.offer(manifest, gmenu["choices"], gnodes)
	gmenu["choices"].append({"text": "Goodbye.", "next": "end"})
	Dialogue.define(_key("foreman"), {"speaker": "Gully Bracewell", "voice": 0.9, "start": "intro", "return": "menu", "nodes": gnodes})
	var lmenu := {"text": "You may speak.", "choices": [{"text": "What's the noble quarter like?", "next": "quarter"}]}
	var lnodes := {"intro": {"text": ["Lady Corisande Halloway. You'll have heard of us. No? Well. You will."], "next": "menu"}, "menu": lmenu,
		"quarter": {"text": ["Quiet, mostly. Gardens, suppers, gossip about the palace.", "Ashgrove's on the corner, if you'd like to look less... seaworthy."], "next": "menu"}}
	quest_node.offer(invite, lmenu["choices"], lnodes)
	lmenu["choices"].append({"text": "Good day, my lady.", "next": "end"})
	Dialogue.define(_key("lady"), {"speaker": "Lady Corisande Halloway", "voice": 1.15, "start": "intro", "return": "menu", "nodes": lnodes})


func _talk(gallows: Dictionary, ledger: Dictionary, locket: Dictionary, invite: Dictionary, petition: Dictionary) -> void:
	var board: Array = []
	var bnodes := {"start": {"text": "Notices pinned three deep: a reward from the Watch, a lost goat answering to Bartholomew, the arena's ladder (fighters wanted), a room to let above the bakery.", "choices": board}}
	quest_node.post(gallows, board, bnodes)
	board.append({"text": "Leave it.", "next": "end"})
	Dialogue.define(_key("board"), {"speaker": "Notice board", "voice": 1.0, "start": "start", "nodes": bnodes})
	var smenu := {"text": "Something you need, Captain?", "choices": [{"text": "What's the city like?", "next": "city"}, {"text": "What's down Gallows Row?", "next": "row"}]}
	var snodes := {"intro": {"text": ["Sergeant Brannoch, the Watch. Welcome to %s." % isl.island_name, "Sheathe that blade inside the walls and we'll get on fine."], "next": "menu"},
		"menu": smenu, "city": {"text": ["Biggest port in the sea. Market's up the street, palace on the hill, arena east of the plaza. The palace grounds are open to petitioners again; the arena's open at last."], "next": "menu"},
		"row": {"text": ["The slums, west off the market street. There's a yard at the end the toughs have taken. I've a notice up on the board, if you've the stomach."], "next": "menu"}}
	quest_node.report(gallows, smenu["choices"], snodes)
	smenu["choices"].append({"text": "Goodbye.", "next": "end"})
	Dialogue.define(_key("sergeant"), {"speaker": "Sergeant Brannoch", "voice": 0.8, "start": "intro", "return": "menu", "nodes": snodes})
	var cmenu := {"text": "The guild's business, Captain?", "choices": []}
	var cnodes := {"intro": {"text": ["Ambrose Pell, clerk to the Merchants' Guild. If you've a cargo to register, the queue starts on the steps."], "next": "menu"}, "menu": cmenu}
	quest_node.offer(ledger, cmenu["choices"], cnodes)
	quest_node.hand_over(petition, cmenu["choices"], cnodes)
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
		"news": {"text": ["The arena's open at last. Half the sea's come to fight in it.", "And the palace has been shut a month. Nobody's seen the king since the spring tides. Don't repeat that."], "next": "menu"}}
	quest_node.hand_over(invite, imenu["choices"], inodes)
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


## The palace's quest line (1.21): three errands for the Lord Chamberlain, each opening after the last ("after"): a
## petition carried to the Guild for its seal, the Queen's stolen signet found on the wharf, and the audience.
func _palace_quests(common: Dictionary) -> Array:
	var petition := {"id": _key("petition"), "kind": "deliver", "giver": "Lord Chamberlain Orme", "src": "npc", "title": "A petition to the Crown",
		"recipient": "Ambrose Pell", "reward": {"gold": 40},
		"ask": "I'd like an audience with the Queen.", "plea": ["An audience. Of course you would. Everyone would. Her Majesty sees petitioners with the Merchants' Guild's seal on their petition.",
			"Here is the form. Take it to the Guild's clerk on the plaza, Ambrose Pell, and have it sealed. Then we shall see."],
		"accept": "I'll get it sealed.", "decline": "Another time.", "taken": "Pell, at the Guild's hall on the plaza. He will complain. Let him.",
		"remind_choice": "About my petition...", "remind": ["The Guild's seal, from Ambrose Pell on the plaza. Then come back to me."],
		"done": "My petition, sealed.", "thanks": ["Sealed, and in a clerk's hand that is almost legible. Very well. Her Majesty may yet see you.", "But first, a delicate matter."],
		"hand": "A petition for the Guild's seal.", "got": ["A petition to the Crown? From a pirate? I've seen everything now. There. Sealed. Don't tell the Guild I didn't charge you."],
		"steps": [{"do": "talk", "who": "Ambrose Pell", "goal": "Have Ambrose Pell at the Guild's hall seal your petition", "said": "Sealed. Take it back to the Lord Chamberlain."},
			{"do": "turnin", "goal": "Bring the sealed petition to the Lord Chamberlain in the palace court"}]}
	petition.merge(common)
	var sv: Vector3 = isl.spots["signet"][0]
	var signet := {"id": _key("signet"), "kind": "lost", "giver": "Lord Chamberlain Orme", "src": "npc", "title": "The Queen's signet", "after": petition["id"],
		"at": isl.from_city(Vector2(sv.x, sv.z)), "yaw": 0.0, "search": "Open the cellar hatch", "reward": {"gold": 90},
		"ask": "What delicate matter?", "plea": ["Her Majesty's signet ring was taken from her chamber a week ago. Without it, nothing she signs is law, and some at court like that very much.",
			"A ring like that can't be sold in a shop. It went to the docks. To the kind of people who don't ask questions. Find it. Quietly."],
		"accept": "I'll find it.", "decline": "Not my business.", "taken": "Quietly, Captain. If the court hears you're looking, the ring will be at the bottom of the harbour by nightfall.",
		"remind_choice": "About the signet...", "remind": ["The docks. The wharf at the end of the warehouse row. Someone there buys what can't be sold."],
		"done": "I found the Queen's signet.", "thanks": ["Under a hatch on the wharf? Of course it was. You have done the Crown a service it will not forget.",
			"Her Majesty will see you now. Take the ring to her yourself."],
		"found": "A heavy gold ring with the royal crest, wrapped in a rag under the hatch.",
		"steps": [{"do": "pickup", "goal": "Find the Queen's signet on the docks' wharf", "said": "The signet, under the fence's hatch. Back to the Lord Chamberlain."},
			{"do": "turnin", "goal": "Bring the signet back to the Lord Chamberlain"}]}
	signet.merge(common)
	var audience := {"id": _key("audience"), "kind": "deliver", "giver": "Lord Chamberlain Orme", "src": "npc", "title": "An audience with the Queen", "after": signet["id"],
		"recipient": "Queen Ilsabet", "reward": {"gold": 250, "items": [["tonic", 3]]},
		"ask": "I'm ready to see the Queen.", "plea": ["The throne hall is through the porch. Bow, speak when spoken to, and give Her Majesty her ring with your own hand.",
			"She has asked to thank you herself. That is rarer than you know."],
		"accept": "I'll go in.", "decline": "In a moment.", "taken": "Go on, then. And Captain: do try to look less like you came in on a tide.",
		"remind_choice": "About the audience...", "remind": ["The throne hall, through the porch. The ring, to the Queen's own hand."],
		"done": "I've seen the Queen.", "thanks": ["She's pleased. I can tell, because she said so, which she never does. The Crown's purse, as she asked. Spend it somewhere I needn't hear about."],
		"hand": "Your Majesty. Your signet.", "got": ["My signet. Found by a pirate on my own wharf, while my court looked the other way. Thank you, Captain.",
			"My husband the King is very ill. Some at court would rather he died and I did not rule. With this ring, I rule. Remember that this city owes you one."],
		"steps": [{"do": "talk", "who": "Queen Ilsabet", "goal": "Give the Queen her signet in the throne hall", "said": "The Queen has her ring. Back to the Lord Chamberlain."},
			{"do": "turnin", "goal": "Tell the Lord Chamberlain you've seen the Queen"}]}
	audience.merge(common)
	for q in [petition, signet, audience]:
		quest_node.add(q, isl)
	return [petition, signet, audience]


func _talk_palace(petition: Dictionary, signet: Dictionary, audience: Dictionary) -> void:
	var cmenu := {"text": "The Crown's business. Briefly, please.", "choices": []}
	var cnodes := {"intro": {"text": ["Aldous Orme, Lord Chamberlain. Every door in this palace opens because I allow it, and most of them don't."], "next": "menu"}, "menu": cmenu}
	for q in [petition, signet, audience]:
		quest_node.offer(q, cmenu["choices"], cnodes)
	cmenu["choices"].append({"text": "Good day, my lord.", "next": "end"})
	Dialogue.define(_key("chamberlain"), {"speaker": "Lord Chamberlain Orme", "voice": 0.85, "start": "intro", "return": "menu", "nodes": cnodes})
	var qmenu := {"text": "You may speak, Captain.", "choices": [{"text": "How fares the King?", "next": "king"}]}
	var qnodes := {"intro": {"text": ["Ilsabet, Queen of this city. You've a petitioner's look, and a sailor's. One of them is honest."], "next": "menu"}, "menu": qmenu,
		"king": {"text": ["Ill. Since the spring tides. The physicians shake their heads in Latin.", "Until he wakes, I hold the city. Not everyone at court likes that."], "next": "menu"}}
	quest_node.hand_over(audience, qmenu["choices"], qnodes)
	qmenu["choices"].append({"text": "Your Majesty.", "next": "end"})
	Dialogue.define(_key("queen"), {"speaker": "Queen Ilsabet", "voice": 1.0, "start": "intro", "return": "menu", "nodes": qnodes})


## The arena master (1.21): your ladder's next fighter and their purse (by your own captain's rank: each captain's
## own), the title's defence once a day after, and the bout asked for through Net (the host runs it).
func _talk_arena() -> void:
	var me := func() -> Player: return get_tree().get_first_node_in_group("player") as Player
	var amenu := {"text": "Here to fight, or to watch?", "choices": []}
	var anodes := {"intro": {"text": ["Corvin Bale, Master of the Grand Arena. Six fighters on the ladder, a champion at the top, and a purse for every bout.",
		"Wooden blades, nobody dies, and the crowd decides who's a hero. Usually the one still standing."], "next": "menu"}, "menu": amenu}
	for i in range(ArenaBout.FIGHTERS.size()):
		var at := i
		amenu["choices"].append({"text": "Fight %s (%d gold)" % [ArenaBout.fighter_name("ladder", i), ArenaBout.purse("ladder", i)], "next": "fight%d" % i,
			"if": func(): return me.call() != null and int(me.call().arena_rank) == at})
		anodes["fight%d" % i] = {"text": ["%s! On the sand!" % ArenaBout.fighter_name("ladder", i).get_slice(",", 0), "Out you go, Captain. They're waiting."],
			"event": "arena:ladder:%d" % i, "next": "end"}
	amenu["choices"].append({"text": "Defend my title (%d gold)" % ArenaBout.DEFEND_PURSE, "next": "defend",
		"if": func(): return me.call() != null and int(me.call().arena_rank) >= ArenaBout.FIGHTERS.size() and int(me.call().arena_defended_day) != int(Weather.day())})
	anodes["defend"] = {"text": ["A challenger, fresh off the boat, and they want your crown. On the sand, Champion!"], "event": "arena:defend:%d" % ArenaBout.FIGHTERS.size(), "next": "end"}
	amenu["choices"].append({"text": "Any more challengers today?", "next": "rested",
		"if": func(): return me.call() != null and int(me.call().arena_rank) >= ArenaBout.FIGHTERS.size() and int(me.call().arena_defended_day) == int(Weather.day())})
	anodes["rested"] = {"text": ["Not today, Champion. You've had your bout. Come back tomorrow and someone will want your title."], "next": "menu"}
	amenu["choices"].append({"text": "How does the ladder work?", "next": "how"})
	anodes["how"] = {"text": ["Six fighters, weakest first. Beat one and the next will see you. Lose and you can try again whenever you like.",
		"Beat the Champion and the title's yours: the purse, the Champion's Sabre, and a challenger a day after that."], "next": "menu"}
	amenu["choices"].append({"text": "Just watching.", "next": "end"})
	Dialogue.define(_key("arena"), {"speaker": "Arena Master Corvin Bale", "voice": 0.85, "start": "intro", "return": "menu", "nodes": anodes})
	if not Dialogue.dialogue_event.is_connected(_on_arena_event):
		Dialogue.dialogue_event.connect(_on_arena_event)


## "arena:<kind>:<rank>" from the master's talk: the bout asked of the host.
func _on_arena_event(ev: String) -> void:
	if not ev.begins_with("arena:") or not is_inside_tree():
		return
	var parts := ev.split(":")
	Net.request_arena(parts[1], int(parts[2]))
