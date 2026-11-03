class_name GadgetData
extends RefCounted
## Every gadget number in one place (1.28; docs/gadgets_plan.md is the readable copy). Per-tier arrays are
## [Mk I, Mk II, Mk III]. Data only: ItemDB names Gadgets, which reads this before the autoloads exist.

## The Tinkering level each tier needs to build (or upgrade to).
const TIER_TINKER := [1, 6, 12]
const TIER_NAMES := ["Mk I", "Mk II", "Mk III"]
## (1.28.1, Zach) The captain carries one gadget; a gadget belt (an item, its pouch worn on the back) two; a gadget bag
## (GadgetBag) BAG_SLOTS, with the wheel to pick among them.
const SLOTS := 1
const BELT_SLOTS := 2
const BAG_SLOTS := 4
## The gadget belt item: its id and price.
const BELT_ITEM := "gadget_belt"
const BELT_PRICE := 120
## A hoard rolls a gadget bag (a colour at random) this often, for a captain without one.
const HOARD_BAG := 0.06
## Tinkering xp for building a gadget at a tier (Mk I) or upgrading to it, and for a refill.
const BUILD_XP := [60, 150, 300]
const REFILL_XP := 10
## Blueprints every captain knows from the start.
const STARTER := ["bp_smoke"]

## kind: combat (thrown, charges + cooldown), traversal (cooldown only), utility, ship (fitted to the ship, fired from
## the helm). Each tier: charges (0 = cooldown only), cd (s), the gadget's own effect numbers, and "cost": per tier
## [gold, {part: n}] (Mk I builds it, II and III upgrade it); "refill": what one refill of every charge costs.
## "from": where its blueprint comes from (Gadgets.CHEST_POOLS rolls the chest ones).
const GADGETS := {
	# --- combat tricks ---
	"smoke": {"name": "Smoke Pellet", "kind": "combat", "throw": true, "from": "known from the start",
		"desc": "A clay pellet of blackpowder and soot. It bursts into a thick cloud: foes inside stagger coughing, and nobody can notice or attack you while you're in it.",
		"charges": [3, 4, 5], "cd": [6.0, 5.0, 4.0], "range": [14.0, 16.0, 18.0],
		"radius": [3.5, 4.5, 5.5], "secs": [8.0, 10.0, 12.0], "blind": [1.6, 2.0, 2.6],
		"cost": [[30, {"black_powder": 2, "canvas": 1}], [90, {"black_powder": 3, "springs": 1, "copper": 1}], [240, {"black_powder": 4, "brass": 2, "ember_ore": 1}]],
		"refill": {"black_powder": 1}},
	"tar": {"name": "Tar Bomb", "kind": "combat", "throw": true, "from": "chests (any); the forge town's tinkerer",
		"desc": "A stoppered jar of hot pitch. It smashes into a black pool that glues the feet of every foe in it.",
		"charges": [3, 4, 5], "cd": [7.0, 6.0, 5.0], "range": [13.0, 15.0, 17.0],
		"radius": [2.4, 3.0, 3.6], "secs": [7.0, 9.0, 11.0], "slow": [0.5, 0.38, 0.26],
		"cost": [[30, {"pitch": 2, "timber": 1}], [90, {"pitch": 3, "iron": 1, "springs": 1}], [240, {"pitch": 4, "brass": 1, "ember_ore": 2}]],
		"refill": {"pitch": 1}},
	"flash": {"name": "Flash Pellet", "kind": "combat", "throw": true, "from": "the forge town's tinkerer",
		"desc": "Magnesium and a ground lens: a white burst that dazzles every foe facing it.",
		"charges": [2, 3, 4], "cd": [10.0, 9.0, 8.0], "range": [14.0, 16.0, 18.0],
		"radius": [4.0, 5.0, 6.0], "stun": [2.0, 2.5, 3.0],
		"cost": [[45, {"black_powder": 1, "lens": 1, "copper": 1}], [120, {"black_powder": 2, "lens": 1, "brass": 1}], [300, {"lens": 2, "brass": 2, "ember_ore": 1}]],
		"refill": {"black_powder": 1, "copper": 1}},
	"pepper": {"name": "Pepper Bomb", "kind": "combat", "throw": true, "from": "hidden chests; books",
		"desc": "Ground fire-pepper in a paper shell. A red cloud that stings: foes in it take damage and break off to cough.",
		"charges": [3, 4, 5], "cd": [8.0, 7.0, 6.0], "range": [13.0, 15.0, 17.0],
		"radius": [3.0, 3.8, 4.6], "secs": [5.0, 6.0, 7.0], "dps": [4.0, 6.0, 8.0], "cough_every": [1.6, 1.4, 1.2],
		"cost": [[35, {"black_powder": 1, "pepper": 2}], [100, {"black_powder": 2, "pepper": 3, "springs": 1}], [260, {"pepper": 4, "brass": 1, "ember_ore": 1}]],
		"refill": {"pepper": 1}},
	"star": {"name": "Burst Star", "kind": "combat", "throw": true, "from": "hidden chests; the forge town's tinkerer",
		"desc": "A spiked iron star packed with powder: it bursts where it lands. Mk III knocks foes down.",
		"charges": [3, 4, 5], "cd": [5.0, 4.5, 4.0], "range": [15.0, 17.0, 19.0],
		"radius": [2.5, 3.0, 3.5], "damage": [30.0, 48.0, 72.0], "knockdown": [false, false, true],
		"cost": [[40, {"black_powder": 2, "iron": 1}], [110, {"black_powder": 3, "iron": 2, "springs": 1}], [280, {"black_powder": 4, "brass": 1, "ember_ore": 2}]],
		"refill": {"black_powder": 2}},
	"decoy": {"name": "Decoy", "kind": "combat", "throw": true, "from": "hoard chests; the merchant ship",
		"desc": "A spring-loaded straw captain in your colours. Foes nearby go for it until it falls apart; Mk III goes off when it does.",
		"charges": [2, 2, 3], "cd": [14.0, 12.0, 10.0], "range": [8.0, 9.0, 10.0],
		"secs": [5.0, 7.0, 9.0], "lure": [10.0, 12.0, 14.0], "burst": [0.0, 0.0, 25.0],
		"cost": [[50, {"timber": 2, "canvas": 2}], [130, {"timber": 2, "canvas": 2, "springs": 2}], [320, {"brass": 2, "springs": 2, "black_powder": 3, "plume": 1}]],
		"refill": {"canvas": 1}},
	"caltrops": {"name": "Caltrops", "kind": "combat", "throw": true, "from": "chests (any)",
		"desc": "A fistful of iron spikes scattered on the ground: foes crossing them are slowed and cut. Mk III's draw blood.",
		"charges": [3, 4, 5], "cd": [8.0, 7.0, 6.0], "range": [10.0, 11.0, 12.0],
		"radius": [2.2, 2.8, 3.4], "secs": [8.0, 10.0, 12.0], "dps": [3.0, 5.0, 7.0], "slow": [0.7, 0.6, 0.5], "bleed": [0.0, 0.0, 3.0],
		"cost": [[30, {"iron": 2}], [90, {"iron": 3, "springs": 1}], [240, {"iron": 4, "chitin_shard": 2, "ember_ore": 1}]],
		"refill": {"iron": 1}},
	# --- traversal (cooldown only) ---
	"grapple": {"name": "Grappling Hook", "kind": "traversal", "from": "the forge town's tinkerer",
		"desc": "A folding iron hook on a sprung reel: aim at a ledge, a branch or a mast and it hauls you up to it.",
		"charges": [0, 0, 0], "cd": [4.0, 3.0, 2.0], "range": [14.0, 18.0, 22.0], "pull": [16.0, 20.0, 24.0],
		"cost": [[60, {"iron": 2, "timber": 1, "springs": 1}], [160, {"iron": 3, "springs": 2, "brass": 1}], [380, {"brass": 2, "springs": 3, "snakeskin": 2, "ember_ore": 1}]],
		"refill": {}},
	"spring_boots": {"name": "Spring Boots", "kind": "traversal", "from": "hoard chests",
		"desc": "Coiled springs strapped under your heels: a jump far higher than legs alone.",
		"charges": [0, 0, 0], "cd": [6.0, 5.0, 4.0], "jump": [11.0, 13.0, 15.0],
		"cost": [[60, {"springs": 2, "iron": 1}], [160, {"springs": 3, "brass": 1, "bear_claw": 1}], [380, {"springs": 4, "brass": 2, "ember_ore": 1}]],
		"refill": {}},
	"glider": {"name": "Pocket Glider", "kind": "traversal", "from": "hoard chests; the merchant ship",
		"desc": "A folding wing of oiled canvas: open it falling and you glide instead.",
		"charges": [0, 0, 0], "cd": [8.0, 7.0, 6.0], "fall": [2.5, 2.0, 1.6], "speed": [9.0, 10.0, 11.0], "secs": [6.0, 9.0, 12.0],
		"cost": [[70, {"canvas": 3, "timber": 2}], [180, {"canvas": 4, "brass": 1, "plume": 2}], [400, {"canvas": 4, "brass": 2, "plume": 3, "ember_ore": 1}]],
		"refill": {}},
	"spike": {"name": "Climbing Spike", "kind": "traversal", "from": "hidden chests; books",
		"desc": "A hand spike hammered into rock or timber: hang from it and climb on, where no hold would.",
		"charges": [0, 0, 0], "cd": [6.0, 5.0, 4.0], "hold": [4.0, 6.0, 8.0],
		"cost": [[40, {"iron": 2}], [110, {"iron": 2, "springs": 1, "tusk": 1}], [280, {"brass": 1, "tusk": 2, "ember_ore": 1}]],
		"refill": {}},
	# (1.28.1) atoll-only: its parts and its blueprint come only from a coral atoll (the lead's atoll pass places them)
	"skimmer": {"name": "Skimmer", "kind": "traversal", "region": "atoll", "from": "the atoll's pearl trader; a wreck in an atoll's lagoon",
		"desc": "A coral-spar board under a sea-silk sail. Launch it on the water and ride it standing at the boom: fastest across the wind, slow into it. F stows it.",
		"charges": [0, 0, 0], "cd": [3.0, 2.5, 2.0], "speed": [9.0, 11.0, 13.0], "hop": [0.0, 0.0, 7.0],
		"cost": [[80, {"coral_spar": 4, "sea_silk": 2, "lagoon_pearl": 1}], [200, {"coral_spar": 6, "sea_silk": 3, "lagoon_pearl": 3, "brass": 1}],
			[450, {"coral_spar": 8, "sea_silk": 5, "lagoon_pearl": 5, "brass": 2}]],
		"refill": {}},
	# --- utility ---
	"spyglass": {"name": "Marking Spyglass", "kind": "utility", "from": "the forge town's tinkerer",
		"desc": "A brass glass with a ranging lens: a look round marks every foe and hidden cache in sight on your compass.",
		"charges": [0, 0, 0], "cd": [30.0, 25.0, 20.0], "reach": [40.0, 60.0, 80.0], "secs": [20.0, 30.0, 40.0],
		"cost": [[50, {"lens": 1, "copper": 2}], [140, {"lens": 2, "brass": 1}], [340, {"lens": 3, "brass": 2, "pearl": 1}]],
		"refill": {}},
	"diving_helmet": {"name": "Diving Helmet", "kind": "utility", "from": "hoard chests; books",
		"desc": "A copper helmet with an air bladder: a while of much longer breath underwater.",
		"charges": [2, 3, 4], "cd": [20.0, 20.0, 20.0], "breath": [1.5, 2.0, 3.0], "secs": [60.0, 90.0, 120.0],
		"cost": [[60, {"copper": 3, "lens": 1}], [160, {"copper": 4, "brass": 1, "lens": 1}], [380, {"brass": 3, "lens": 1, "pearl": 2}]],
		"refill": {"pitch": 1}},
	"auto_reel": {"name": "Auto-Reel", "kind": "utility", "from": "hidden chests; books",
		"desc": "A clockwork drum clipped to your rod: for the next few catches it does half the reeling.",
		"charges": [3, 4, 5], "cd": [5.0, 5.0, 5.0], "reel": [0.25, 0.4, 0.6], "catches": [3, 5, 8],
		"cost": [[40, {"springs": 2, "copper": 1}], [110, {"springs": 3, "brass": 1}], [280, {"springs": 3, "brass": 2, "pearl": 1}]],
		"refill": {"springs": 1}},
	"lockpick": {"name": "Lockpick Set", "kind": "utility", "from": "chests (any)",
		"desc": "Picks and a tension wrench: a locked chest or door opens without its key.",
		"charges": [2, 3, 4], "cd": [3.0, 3.0, 3.0], "pick_secs": [3.0, 2.0, 1.0],
		"cost": [[30, {"iron": 1, "springs": 1}], [90, {"springs": 2, "brass": 1}], [240, {"brass": 2, "springs": 2, "ivory": 1}]],
		"refill": {"iron": 1}},
	"lantern_bomb": {"name": "Lantern Bomb", "kind": "utility", "throw": true, "from": "hidden chests; the forge town's tinkerer",
		"desc": "A sealed oil lamp that lights where it lands and burns on: light in a cave, and beasts keep clear of it by night.",
		"charges": [3, 4, 5], "cd": [6.0, 6.0, 6.0], "range": [14.0, 16.0, 18.0], "secs": [30.0, 45.0, 60.0], "light": [8.0, 10.0, 12.0],
		"cost": [[35, {"black_powder": 1, "canvas": 1, "copper": 1}], [100, {"black_powder": 2, "copper": 1, "lens": 1}], [260, {"brass": 1, "lens": 1, "ember_ore": 1}]],
		"refill": {"black_powder": 1}},
	# --- ship gadgets (fitted to the ship at a bench aboard; fired from the helm) ---
	"burst_launcher": {"name": "Burst Launcher", "kind": "ship", "from": "the merchant ship; the forge town's tinkerer",
		"desc": "Powder rockets lashed under her stern: a burst that flings the ship forward.",
		"charges": [2, 3, 4], "cd": [30.0, 25.0, 20.0], "impulse": [12.0, 16.0, 20.0],
		"cost": [[120, {"black_powder": 4, "iron": 4}], [300, {"black_powder": 6, "iron": 4, "brass": 2}], [700, {"black_powder": 8, "brass": 4, "ember_ore": 3}]],
		"refill": {"black_powder": 3}},
	"paddle_boost": {"name": "Paddle Boost", "kind": "ship", "from": "the forge town's tinkerer",
		"desc": "A crank-driven paddle wheel at each side: a spell of speed whatever the wind.",
		"charges": [0, 0, 0], "cd": [40.0, 35.0, 30.0], "boost": [0.25, 0.35, 0.45], "secs": [8.0, 10.0, 12.0],
		"cost": [[100, {"timber": 4, "springs": 2}], [260, {"timber": 4, "springs": 4, "brass": 2}], [600, {"brass": 4, "springs": 4, "ember_ore": 2}]],
		"refill": {}},
	"harpoon": {"name": "Harpoon Cannon", "kind": "ship", "from": "the merchant ship; the forge town's tinkerer",
		"desc": "A swivel gun firing a barbed harpoon on a chain: whatever it bites is reeled in toward the ship.",
		"charges": [4, 6, 8], "cd": [12.0, 10.0, 8.0], "range": [30.0, 40.0, 50.0], "damage": [40.0, 60.0, 90.0], "reel": [3.0, 5.0, 7.0], "hold": [8.0, 10.0, 12.0],
		"cost": [[140, {"iron": 4, "timber": 2, "springs": 2}], [340, {"iron": 6, "brass": 2, "springs": 2}], [800, {"brass": 4, "ember_ore": 3, "leviathan_scale": 1}]],
		"refill": {"iron": 2}},
	"smoke_screen": {"name": "Smoke Screen", "kind": "ship", "from": "the forge town's tinkerer",
		"desc": "Smoke pots along her rails: a bank of smoke round the ship that enemy gunners can't see through.",
		"charges": [2, 2, 3], "cd": [45.0, 40.0, 35.0], "radius": [10.0, 13.0, 16.0], "secs": [10.0, 14.0, 18.0],
		"cost": [[100, {"black_powder": 4, "pitch": 2}], [260, {"black_powder": 6, "pitch": 3, "brass": 1}], [600, {"black_powder": 8, "brass": 2, "ember_ore": 2}]],
		"refill": {"black_powder": 2, "pitch": 1}},
}

## The tinker's parts that are new items (the rest are salvage and trophies already in the game: iron, copper, timber,
## canvas, pepper, chitin_shard, snakeskin, bear_claw, tusk, plume, pearl, ivory). id -> [name, value, description].
const PARTS := {
	"black_powder": ["Blackpowder", 3, "A twist of coarse gunpowder. A tinker's first ingredient."],
	"pitch": ["Pitch", 2, "A cake of pine pitch, black and sticky. Caulkers and tinkers both want it."],
	"springs": ["Springs & Cogs", 6, "A tin of coiled springs, cogs and pins salvaged from clocks and locks."],
	"brass": ["Brass Fittings", 10, "Hinges, collars and bands of good brass: what makes a gadget a Mk II."],
	"lens": ["Ground Lens", 16, "A clear lens ground by a glassmaker. Spyglasses and flash powder want one."],
	"ember_ore": ["Ember Ore", 18, "A warm red ore from the fire islands' forges. Mk III work needs it."],
	"leviathan_scale": ["Leviathan Scale", 60, "A scale the size of a shield, harder than iron. Only the great beasts of the deep shed them."],
	"coral_spar": ["Coral Spar", 8, "A straight, light branch of white coral, broken off a coral head under an atoll's lagoon. A skimmer's board and mast."],
	"sea_silk": ["Sea-silk", 12, "A bolt of shimmering cloth spun from the threads of lagoon clams. Sold by an atoll's pearl trader: a skimmer's sail."],
	"lagoon_pearl": ["Lagoon Pearl", 30, "A big rose-white pearl from a giant clam in an atoll's lagoon. Set in a skimmer's mast foot, it keeps her trim."],
}
## The parts only an atoll gives (not in ALL_PARTS: loot tables and merchants roll from that).
const ATOLL_PARTS := ["coral_spar", "sea_silk", "lagoon_pearl"]
## Every part a gadget asks for (new and old): Gadgets.part_ids.
const ALL_PARTS := ["black_powder", "pitch", "springs", "brass", "lens", "ember_ore", "leviathan_scale",
	"iron", "copper", "timber", "canvas", "pepper", "chitin_shard", "snakeskin", "bear_claw", "tusk", "plume", "pearl", "ivory"]
const BLUEPRINT_VALUE := 25

## Chests (Loot.chest, their own stream): the chance of a few tinker's parts and which, and of a blueprint from the
## kind of chest's pool (one the captain doesn't know yet).
const CHEST_PARTS := {"ordinary": [0.25, ["black_powder", "pitch", "springs"], 2], "hidden": [0.4, ["black_powder", "springs", "brass"], 2],
	"hoard": [0.6, ["springs", "brass", "lens"], 3]}
const CHEST_BLUEPRINT := {"ordinary": 0.03, "hidden": 0.08, "hoard": 0.2}
const CHEST_POOLS := {"ordinary": ["tar", "caltrops", "lockpick"], "hidden": ["pepper", "star", "spike", "lantern_bomb", "auto_reel"],
	"hoard": ["spring_boots", "glider", "decoy", "diving_helmet"]}
## Stalls that sell parts (Shops ids -> [[item id, stock]]), added to their stock.
const SHOP_PARTS := [["black_powder", 6], ["pitch", 4], ["springs", 3]]

## (1.30) Ready-made packs ("kit_<gadget>", an item): carried, a pack of a gadget the captain hasn't built makes it Mk I
## on the belt (its blueprint learned); one of a gadget they have refills it when it runs dry (GadgetBelt). Sold by
## chandlers and Nessa's Notions, found in Admiralty supply crates (Gadgets.supply_crate). gadget id -> [pack name,
## item value (a trader asks x3: Economy), what's in it].
const KITS := {
	"smoke": ["Smoke Pellets", 12, "A paper twist of three clay smoke pellets, fuses ready."],
	"flash": ["Flash Pellets", 18, "Two magnesium flash pellets in a tin, packed in sawdust."],
	"grapple": ["Grappling Hook", 50, "A ready-made folding hook on a sprung reel."],
}
## The packs a stall sells (Shops stock entries).
const SHOP_KITS := [["kit_smoke"], ["kit_flash"], ["kit_grapple"]]
## A supply crate's packs: how many (min, max) and the weights of each kind.
const CRATE_N := [1, 2]
const CRATE_KITS := {"smoke": 3.0, "flash": 2.0}


static func tier_val(gid: String, key: String, tier: int) -> Variant:
	return (GADGETS[gid][key] as Array)[tier]
