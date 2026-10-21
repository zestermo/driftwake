class_name WeaponDesigns
extends RefCounted
## Every look a cutlass, katana, axe, pistol, dagger, polearm or hammer comes in, built from a handful of
## numbers (blade length and curve, guard, head, barrels, colours), and its
## tier worn on it: blued fittings at rare, a purple gem at epic, gold at
## legendary, a crimson blade at ultra, an obsidian one at supreme.
##
## A weapon's model is "<kind>:<design>:<tier>" (ItemData.model()), the same
## string the mesh carries (co-op rebuilds it from that). Each design is an
## item of its own (id DESIGNS[kind][design]["id"]: ItemDB makes them from
## the kind's base item); tiers come on top (ItemDB.tiered).

const BASE_ITEM := {"cutlass": "cutlass", "katana": "katana", "axe": "boarding_axe", "pistol": "pistol", "dagger": "dagger", "polearm": "spear",
	"hammer": "warhammer", "greatsword": "greatsword"}

## design -> {id, name, desc, dmg (x the base item's), worth (x its value), build numbers...}
const DESIGNS := {
	"cutlass": {
		"sabre": {"id": "naval_sabre", "name": "Naval Sabre", "desc": "A long, slim officer's blade with a steel stirrup guard. Reach over weight.",
			"dmg": 1.0, "worth": 1.5, "len": 0.66, "tip": 0.3, "w": 0.055, "curve": 0.16, "guard": "stirrup",
			"fit": Color(0.8, 0.83, 0.88), "grip": Color(0.92, 0.88, 0.78), "grip_tex": "leather", "pommel": "cap"},
		"scimitar": {"id": "scimitar", "name": "Scimitar", "desc": "A broad blade sweeping into a deep curve. Cuts like a wave breaking.",
			"dmg": 1.05, "worth": 1.6, "len": 0.42, "tip": 0.36, "w": 0.075, "taper": 1.35, "curve": 0.55, "guard": "cross", "guard_size": 0.15,
			"fit": Color(1.0, 0.78, 0.4), "grip": Color(0.62, 0.12, 0.1), "grip_tex": "fabric", "pommel": "ball"},
		"broadsword": {"id": "broadsword", "name": "Broadsword", "desc": "Straight, wide and heavy, with a basket of iron round the hand.",
			"dmg": 1.12, "worth": 1.8, "len": 0.74, "tip": 0.1, "w": 0.075, "curve": 0.0, "guard": "basket",
			"fit": Color(0.55, 0.55, 0.58), "grip": Color(0.3, 0.2, 0.12), "grip_tex": "leather", "pommel": "ball"},
		"rapier": {"id": "rapier", "name": "Rapier", "desc": "A needle of a sword behind a steel cup. Quick to the point, slow to break.",
			"dmg": 0.95, "worth": 1.7, "len": 0.88, "tip": 0.08, "w": 0.024, "th": 0.016, "curve": 0.0, "guard": "cup",
			"fit": Color(0.82, 0.84, 0.9), "grip": Color(0.18, 0.14, 0.12), "grip_tex": "leather", "pommel": "ball"},
		"falchion": {"id": "falchion", "name": "Falchion", "desc": "Short and wide with a clipped point. Chops through rope, oars and pirates.",
			"dmg": 1.1, "worth": 1.4, "len": 0.44, "tip": 0.14, "w": 0.095, "taper": 1.15, "curve": 0.1, "clip": true, "guard": "cross", "guard_size": 0.18,
			"fit": Color(0.5, 0.48, 0.45), "grip": Color(0.35, 0.22, 0.12), "grip_tex": "planks_dark", "pommel": "cap"},
		"hanger": {"id": "hunting_hanger", "name": "Hunting Hanger", "desc": "A short hunting sword with a shell guard and a stag-horn grip.",
			"dmg": 0.95, "worth": 1.2, "len": 0.36, "tip": 0.16, "w": 0.06, "curve": 0.18, "guard": "shell",
			"fit": Color(1.0, 0.78, 0.4), "grip": Color(0.86, 0.8, 0.66), "grip_tex": "bark", "pommel": "cap"},
		"dao": {"id": "dao", "name": "Dao", "desc": "A broad single-edged sabre from far-off waters, a red tassel at the ring.",
			"dmg": 1.05, "worth": 1.6, "len": 0.46, "tip": 0.24, "w": 0.07, "taper": 1.3, "curve": 0.3, "guard": "disc",
			"fit": Color(1.0, 0.78, 0.4), "grip": Color(0.14, 0.12, 0.12), "grip_tex": "fabric", "pommel": "ring", "tassel": Color(0.8, 0.12, 0.1)},
		# (unique: only the brood queen's hoard has it)
		"chitin": {"id": "queens_fang", "name": "Queen's Fang", "desc": "A blade of the brood queen's own chitin, its edge still weeping venom. Every cut poisons.",
			"dmg": 1.15, "worth": 3.0, "len": 0.5, "tip": 0.34, "w": 0.08, "taper": 1.25, "curve": 0.45, "guard": "cross", "guard_size": 0.17,
			"blade": Color(0.45, 0.32, 0.55), "venom": Color(0.5, 1.0, 0.25), "fit": Color(0.3, 0.2, 0.35), "grip": Color(0.2, 0.32, 0.18),
			"grip_tex": "leather", "pommel": "ball", "unique": true, "poison": 5.0},
	},
	"katana": {
		"uchigatana": {"id": "uchigatana", "name": "Uchigatana", "desc": "A fighting katana in red cord, a square guard edged in brass.",
			"dmg": 1.03, "worth": 1.4, "tsuba": "square", "wrap": Color(0.62, 0.1, 0.1), "fit": Color(1.0, 0.78, 0.4)},
		"nodachi": {"id": "nodachi", "name": "Nodachi", "desc": "A field sword half again as long as a katana. Reach that ends arguments.",
			"dmg": 1.12, "worth": 1.8, "len": 1.08, "curve": 0.42, "wrap": Color(0.16, 0.13, 0.17), "fit": Color(0.45, 0.42, 0.42)},
		"tachi": {"id": "tachi", "name": "Tachi", "desc": "An old court blade with a deep curve and a flowered guard, wrapped in white.",
			"dmg": 1.05, "worth": 1.6, "curve": 0.5, "tsuba": "flower", "wrap": Color(0.9, 0.88, 0.82), "fit": Color(1.0, 0.78, 0.4)},
		# (dark blued steel, not black: a black blade is Supreme's alone)
		"kuro": {"id": "kuro_katana", "name": "Kuro Katana", "desc": "Dark blued steel with a pale edge, in black cord. It drinks the light.",
			"dmg": 1.08, "worth": 1.9, "blade": Color(0.42, 0.5, 0.68), "wrap": Color(0.08, 0.08, 0.09), "fit": Color(0.35, 0.33, 0.35)},
		"wakizashi": {"id": "wakizashi", "name": "Wakizashi", "desc": "The short companion blade. Quick in close quarters below decks.",
			"dmg": 0.95, "worth": 1.0, "len": 0.58, "curve": 0.22, "wrap": Color(0.18, 0.22, 0.4), "fit": Color(0.45, 0.42, 0.42)},
		"ninjato": {"id": "ninjato", "name": "Ninjato", "desc": "A straight blade with a square guard. Made for the dark, not for show.",
			"dmg": 1.0, "worth": 1.3, "len": 0.74, "curve": 0.0, "tsuba": "square", "wrap": Color(0.1, 0.1, 0.11), "fit": Color(0.3, 0.3, 0.3)},
	},
	# (two axes in hand fight as twin axes: "speed" x how fast that style's moves play, "hook" x how far its hooks
	# reach; a pair's numbers are the two axes' average, DualAxeArts.pair. "pair": found and sold two at a time)
	"axe": {
		"hatchet": {"id": "hatchet", "name": "Hatchet", "desc": "A carpenter's axe. Short, light, and it's seen more pirates than planks.",
			"dmg": 0.92, "worth": 0.6, "haft": 0.58, "head": "hatchet", "wood": Color(0.78, 0.6, 0.4), "speed": 1.1, "hook": 0.9},
		"bearded": {"id": "bearded_axe", "name": "Bearded Axe", "desc": "Its long beard hooks a shield or a rail and pulls.",
			"dmg": 1.04, "worth": 1.2, "head": "bearded", "wood": Color(0.55, 0.38, 0.24), "hook": 1.3},
		"double": {"id": "double_axe", "name": "Double Axe", "desc": "Two heads, back to back. Every swing is a forehand.",
			"dmg": 1.1, "worth": 1.5, "head": "double", "wood": Color(0.45, 0.3, 0.2), "bands": true, "speed": 0.92, "hook": 0.8},
		"cleaver": {"id": "ships_cleaver", "name": "Ship's Cleaver", "desc": "The cook's, once. A slab of iron on a short handle.",
			"dmg": 1.0, "worth": 0.9, "haft": 0.62, "head": "cleaver", "wood": Color(0.3, 0.22, 0.16), "speed": 1.04, "hook": 0.85},
		"war": {"id": "war_axe", "name": "War Axe", "desc": "A crescent blade, a spike behind and a spike ahead, on a banded haft.",
			"dmg": 1.12, "worth": 1.8, "haft": 1.0, "head": "war", "wood": Color(0.35, 0.24, 0.16), "bands": true, "speed": 0.88, "hook": 1.1},
		"tomahawk": {"id": "tomahawk", "name": "Tomahawk", "desc": "A raider's light axe, a spike behind the bit. Carried in pairs and never still.",
			"dmg": 0.96, "worth": 0.9, "haft": 0.64, "head": "tomahawk", "wood": Color(0.62, 0.44, 0.28), "speed": 1.16, "hook": 0.9, "pair": true,
			"fit": Color(0.5, 0.48, 0.46)},
		"reaver": {"id": "reavers_axe", "name": "Reaver's Axe", "desc": "Its beard sweeps back into a hook. Made to catch a guard or a collar and haul it in. Carried in pairs.",
			"dmg": 1.06, "worth": 1.5, "haft": 0.78, "head": "reaver", "wood": Color(0.3, 0.22, 0.17), "bands": true, "speed": 0.98, "hook": 1.4,
			"pair": true, "fit": Color(0.42, 0.42, 0.44)},
	},
	"pistol": {
		"duelling": {"id": "duelling_pistol", "name": "Duelling Pistol", "desc": "A long, true barrel and a silver lock. Made for one shot that counts.",
			"dmg": 1.05, "worth": 1.6, "barrel": 0.46, "r": 0.017, "sides": 8, "wood": Color(0.4, 0.24, 0.14), "fit": Color(0.85, 0.87, 0.9)},
		"blunderbuss": {"id": "blunderbuss_pistol", "name": "Blunderbuss Pistol", "desc": "A brass bell of a muzzle. Aiming is a suggestion.",
			"dmg": 1.12, "worth": 1.5, "barrel": 0.34, "r": 0.024, "flare": 0.055, "brass_barrel": true, "wood": Color(0.62, 0.4, 0.22)},
		"double": {"id": "double_pistol", "name": "Double-Barrel Pistol", "desc": "Two barrels side by side. Twice the argument.",
			"dmg": 1.08, "worth": 1.7, "barrel": 0.34, "r": 0.017, "barrels": 2, "wood": Color(0.5, 0.3, 0.18)},
		"pepperbox": {"id": "pepperbox", "name": "Pepperbox", "desc": "A cluster of short barrels turning round the lock.",
			"dmg": 1.0, "worth": 1.6, "barrel": 0.2, "r": 0.011, "barrels": 5, "wood": Color(0.3, 0.2, 0.14)},
		"dragon": {"id": "dragon_pistol", "name": "Dragon Pistol", "desc": "Brass from lock to muzzle, the muzzle a dragon's open jaws.",
			"dmg": 1.1, "worth": 2.0, "barrel": 0.32, "r": 0.022, "brass_barrel": true, "dragon": true, "wood": Color(0.25, 0.14, 0.1), "fit": Color(1.15, 0.9, 0.4)},
	},
	# (the base is a plain sailor's dirk: len 0.21, a small cross guard)
	"dagger": {
		"stiletto": {"id": "stiletto", "name": "Stiletto", "desc": "A needle of steel behind a ring guard. It finds the gap between ribs.",
			"dmg": 1.0, "worth": 1.4, "len": 0.22, "tip": 0.08, "w": 0.018, "th": 0.014, "taper": 0.55, "guard": "ring",
			"fit": Color(0.8, 0.82, 0.88), "grip": Color(0.16, 0.12, 0.12), "grip_tex": "leather", "pommel": "ball"},
		"kris": {"id": "kris", "name": "Kris", "desc": "A wavy blade from the spice islands, its edge rippling like a sea snake.",
			"dmg": 1.05, "worth": 1.7, "len": 0.25, "tip": 0.07, "w": 0.042, "taper": 0.7, "wave": 0.22, "guard": "flare",
			"fit": Color(1.0, 0.78, 0.4), "grip": Color(0.42, 0.24, 0.12), "grip_tex": "planks_dark", "pommel": "hook"},
		"kukri": {"id": "kukri", "name": "Kukri", "desc": "Bent forward like a broken wing and heavy at the tip. It chops like a little axe.",
			"dmg": 1.1, "worth": 1.5, "len": 0.24, "tip": 0.09, "w": 0.05, "taper": 1.5, "curve": -0.4, "guard": "bolster",
			"fit": Color(0.55, 0.5, 0.45), "grip": Color(0.3, 0.2, 0.14), "grip_tex": "planks_dark", "pommel": "cap"},
		"main_gauche": {"id": "main_gauche", "name": "Main Gauche", "desc": "A duellist's left-hand dagger, a broad shell to catch the other man's blade.",
			"dmg": 0.95, "worth": 1.6, "len": 0.27, "tip": 0.08, "w": 0.032, "taper": 0.8, "guard": "shell",
			"fit": Color(0.82, 0.84, 0.9), "grip": Color(0.2, 0.15, 0.12), "grip_tex": "leather", "pommel": "ball"},
		"sharktooth": {"id": "sharktooth_knife", "name": "Sharktooth Knife", "desc": "A bone grip and a blade set with shark's teeth. It doesn't cut, it tears.",
			"dmg": 1.08, "worth": 1.3, "len": 0.2, "tip": 0.07, "w": 0.046, "taper": 0.85, "teeth": true, "guard": "none",
			"fit": Color(0.9, 0.86, 0.74), "grip": Color(0.95, 0.9, 0.78), "grip_tex": "bark", "pommel": "cap"},
	},
	# (the base is a boarding spear: a leaf head on an ash shaft). Polearms add "reach" (x the hitbox's length),
	# "speed" (x how fast its moves play), "sweep" (x a sweep's width) and "pierce" (thrusts can't be blocked);
	# "rare" drops less often (Loot)
	"polearm": {
		"trident": {"id": "trident", "name": "Trident", "desc": "Three barbed prongs on a long shaft. What it skewers, it holds; its thrusts go through a guard.",
			"dmg": 1.04, "worth": 1.5, "head": "trident", "pierce": true, "fit": Color(0.62, 0.66, 0.7), "wood": Color(0.42, 0.3, 0.2)},
		"naginata": {"id": "naginata", "name": "Naginata", "desc": "A curved blade on a lacquered pole. Quick, wide sweeps that keep a crowd at the edge.",
			"dmg": 1.05, "worth": 1.6, "head": "naginata", "speed": 1.06, "sweep": 1.12, "fit": Color(1.0, 0.78, 0.4), "wood": Color(0.3, 0.1, 0.09),
			"grip": Color(0.12, 0.1, 0.12)},
		"bisento": {"id": "bisento", "name": "Bisento", "desc": "A great broad blade on a heavy shaft. Slow, and every sweep clears the deck.",
			"dmg": 1.24, "worth": 2.4, "head": "bisento", "speed": 0.84, "sweep": 1.35, "reach": 1.05, "rare": true,
			"fit": Color(0.5, 0.48, 0.46), "wood": Color(0.22, 0.17, 0.13), "tassel": Color(0.75, 0.12, 0.1)},
		"halberd": {"id": "halberd", "name": "Halberd", "desc": "An axe, a spike and a hook on one shaft. It chops, it stabs, it pulls men off rails.",
			"dmg": 1.12, "worth": 1.8, "head": "halberd", "speed": 0.92, "reach": 1.05, "fit": Color(0.55, 0.55, 0.58), "wood": Color(0.36, 0.25, 0.16)},
		"pitchfork": {"id": "pitchfork", "name": "Pitchfork", "desc": "A farmer's fork, three tines and an ash handle. It's held a village gate before.",
			"dmg": 0.88, "worth": 0.5, "head": "fork", "reach": 0.95, "fit": Color(0.45, 0.42, 0.4), "wood": Color(0.72, 0.56, 0.38)},
	},
	# (the base is an iron warhammer: a square face and a back spike). Hammers add "haft" (m from the right hand
	# to the head), "speed" (x how fast its moves play), "reach" (x the hitbox's length) and "weight" (x the
	# knockback and the shockwaves' size); "rare" drops less often (Loot)
	"hammer": {
		"kanabo": {"id": "kanabo", "name": "Kanabo", "desc": "An iron-studded oak club as long as a man's leg. It doesn't cut armour; it folds it.",
			"dmg": 1.06, "worth": 1.5, "head": "kanabo", "haft": 1.08, "reach": 1.08, "speed": 0.96, "wood": Color(0.2, 0.15, 0.13),
			"fit": Color(0.55, 0.53, 0.5)},
		"mallet": {"id": "shipwrights_mallet", "name": "Shipwright's Mallet", "desc": "A barrel of oak bound in iron on a stout handle. Built to drive pegs; drives pirates just as well.",
			"dmg": 0.86, "worth": 0.5, "head": "mallet", "haft": 0.82, "reach": 0.94, "speed": 1.1, "weight": 0.9, "wood": Color(0.66, 0.5, 0.33),
			"fit": Color(0.42, 0.4, 0.38)},
		"maul": {"id": "maul", "name": "Iron Maul", "desc": "A long sledge of black iron, a face at each end. Every swing is a door being kicked in.",
			"dmg": 1.14, "worth": 1.8, "head": "maul", "haft": 1.0, "speed": 0.9, "weight": 1.15, "wood": Color(0.36, 0.26, 0.18),
			"blade": Color(0.48, 0.47, 0.47), "fit": Color(0.55, 0.53, 0.5)},
		"anchor": {"id": "anchor_hammer", "name": "Anchor Hammer", "desc": "A ship's anchor on a chain-wrapped shank. Only the strongest lift it; nothing stands where it lands.",
			"dmg": 1.26, "worth": 2.4, "head": "anchor", "haft": 1.08, "reach": 1.06, "speed": 0.82, "weight": 1.3, "rare": true,
			"blade": Color(0.5, 0.52, 0.55), "fit": Color(0.62, 0.6, 0.56), "grip": Color(0.8, 0.72, 0.55), "grip_tex": "fabric"},
	},
	# (the base is a plain greatsword: a broad straight blade and a cross guard). Greatswords add "len" (the blade's
	# length), "speed" (x how fast its moves play), "reach" (x the hitbox), "sweep" (x a sweep's width), "weight" (x the
	# knockback and a guard break's stagger) and "bleed" (s: its cuts open a wound); "rare" drops less often (Loot)
	"greatsword": {
		"black": {"id": "black_greatblade", "name": "Black Greatblade", "desc": "Dark steel from guard to point, a long cross guard edged in old gold. It cuts the air before it cuts you.",
			"dmg": 1.12, "worth": 2.0, "len": 1.22, "w": 0.1, "taper": 0.8, "curve": 0.05, "guard": "long", "pommel": "drop",
			"blade": Color(0.34, 0.35, 0.42), "fit": Color(0.86, 0.68, 0.32), "grip": Color(0.12, 0.1, 0.12), "speed": 0.96, "reach": 1.06},
		"claymore": {"id": "claymore", "name": "Claymore", "desc": "A highlander's two-hander, its quillons swept forward to quatrefoils. Wide sweeps that clear a deck.",
			"dmg": 1.04, "worth": 1.5, "len": 1.14, "w": 0.1, "taper": 0.85, "guard": "claymore", "pommel": "wheel",
			"fit": Color(0.62, 0.62, 0.66), "grip": Color(0.42, 0.18, 0.12), "speed": 1.02, "reach": 1.04, "sweep": 1.12},
		"saw": {"id": "sawtooth_greatblade", "name": "Sawtooth Greatblade", "desc": "A broad blade with teeth filed into its edge. It doesn't cut so much as rip, and the wounds bleed.",
			"dmg": 1.0, "worth": 1.6, "len": 1.06, "w": 0.13, "taper": 0.9, "teeth": true, "guard": "block", "pommel": "disc",
			"fit": Color(0.42, 0.4, 0.38), "grip": Color(0.3, 0.22, 0.15), "grip_tex": "planks_dark", "speed": 0.98, "bleed": 3.0},
		"cleaver": {"id": "greatcleaver", "name": "Butcher's Greatcleaver", "desc": "A slab of iron with a square end and a handle for two. Slow; whatever it meets, it goes through.",
			"dmg": 1.16, "worth": 1.8, "len": 0.98, "w": 0.21, "taper": 1.12, "clip": true, "guard": "block", "pommel": "disc",
			"blade": Color(0.58, 0.57, 0.56), "fit": Color(0.4, 0.38, 0.36), "grip": Color(0.36, 0.25, 0.16), "grip_tex": "planks_dark",
			"speed": 0.88, "reach": 0.96, "weight": 1.25},
		# (rare: kept a third of the times it's rolled)
		"fang": {"id": "sea_kings_fang", "name": "Sea King's Fang", "desc": "A Sea King's tooth as long as a man, bound to a whalebone grip. Nothing on the waves has a longer reach.",
			"dmg": 1.26, "worth": 2.6, "len": 1.3, "w": 0.15, "taper": 0.42, "curve": 0.34, "guard": "bone", "pommel": "drop",
			"blade": Color(1.12, 1.05, 0.88), "fit": Color(0.92, 0.88, 0.78), "grip": Color(0.25, 0.4, 0.42), "grip_tex": "fabric",
			"speed": 0.86, "reach": 1.12, "weight": 1.15, "rare": true},
	},
}

## Each tier's fittings (guards, bands, locks) and gem; ultra and supreme
## colour the blade itself.
const TIER_FIT := [Color(), Color(), Color(0.55, 0.72, 1.15), Color(0.42, 0.38, 0.5), Color(1.35, 1.05, 0.35),
	Color(0.32, 0.12, 0.12), Color(1.35, 1.35, 1.42)]
const TIER_GEM := [Color(), Color(), Color(), Color(0.7, 0.3, 1.0), Color(1.0, 0.82, 0.25), Color(1.0, 0.18, 0.15), Color(0.85, 0.75, 1.0)]
const TIER_BLADE := [Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE, Color(1.25, 0.42, 0.4), Color(0.17, 0.16, 0.21)]

static var _icons: Dictionary = {}


## The designs anyone might carry, find or buy (unique ones left out).
static func designs_of(kind: String) -> Array:
	var d: Dictionary = DESIGNS.get(kind, {})
	return d.keys().filter(func(k): return not bool((d[k] as Dictionary).get("unique", false)))


## A design of `kind` picked at random (the base included: key "").
static func random_design(kind: String, rng: RandomNumberGenerator) -> String:
	var all: Array = [""] + designs_of(kind)
	return str(all[rng.randi() % all.size()])


## Every design's item id (to drop, stock or roll loot from), the base's too.
static func item_ids(kind: String) -> Array:
	var out: Array = [str(BASE_ITEM[kind])]
	for d in designs_of(kind):
		out.append(str(DESIGNS[kind][d]["id"]))
	return out


## Where an axe's head sits along its haft (z in the weapon's frame).
static func axe_head_z(model: String) -> float:
	var p: Dictionary = (DESIGNS["axe"] as Dictionary).get(model.get_slice(":", 1), {})
	return -(_f(p, "haft", 0.9) - 0.22)


## An axe design's number ("speed", "hook"; `def` for the base boarding axe).
static func axe(design: String, key: String, def: float = 1.0) -> float:
	return float((DESIGNS["axe"] as Dictionary).get(design, {}).get(key, def))


## Found and sold two at a time (an item id of any kind).
static func comes_paired(id: String) -> bool:
	for d in (DESIGNS["axe"] as Dictionary).values():
		if str(d["id"]) == id:
			return bool(d.get("pair", false))
	return false


## A polearm design's number ("reach", "speed", "sweep"; `def` for the base spear and other kinds).
static func pole(design: String, key: String, def: float = 1.0) -> float:
	return float((DESIGNS["polearm"] as Dictionary).get(design, {}).get(key, def))


## How far the shaft runs ahead of the right hand (the head starts there) and behind it (the butt).
const POLE_AHEAD := 1.32
const POLE_BEHIND := 0.42


## A hammer design's number ("speed", "reach", "weight"; `def` for the base warhammer).
static func hammer(design: String, key: String, def: float = 1.0) -> float:
	return float((DESIGNS["hammer"] as Dictionary).get(design, {}).get(key, def))


static func hammer_haft(design: String) -> float:
	return hammer(design, "haft", HAMMER_HAFT)


## The warhammer's haft from the right hand to the head's middle (the butt runs HAMMER_BUTT behind the hand).
const HAMMER_HAFT := 0.95
const HAMMER_BUTT := 0.12


## A greatsword design's number ("speed", "reach", "sweep", "weight", "bleed"; `def` for the base greatsword).
static func great(design: String, key: String, def: float = 1.0) -> float:
	return float((DESIGNS["greatsword"] as Dictionary).get(design, {}).get(key, def))


## A greatsword's blade length (m from the guard to the point).
static func great_len(design: String) -> float:
	return great(design, "len", GREAT_LEN)


## The base greatsword's blade, and where its guard sits ahead of the right hand (the hand rides at the pommel end
## of a long grip; the left slides up it toward the guard).
const GREAT_LEN := 1.12
const GREAT_GUARD := 0.36


## A katana's scabbard in the blade's own frame: the same chain of segments
## as its blade (length and curve), a little roomier, past the point.
static func saya(model: String) -> ArrayMesh:
	var p: Dictionary = (DESIGNS["katana"] as Dictionary).get(model.get_slice(":", 1), {})
	var lacquer := PSXMat.lit("leather", Color(0.13, 0.11, 0.12))
	var horn := PSXMat.lit("metal", Color(0.85, 0.72, 0.45))
	var cord := PSXMat.lit("fabric", Color(0.7, 0.14, 0.12))
	var mb := MeshBuilder.new()
	var curve := _f(p, "curve", 0.32)
	var segs := 5
	var seg := _f(p, "len", 0.82) / segs
	var h := _f(p, "w", 0.033) + 0.018
	var at := Vector3(0, 0, -0.06)
	var b := Basis()
	for i in range(segs):
		b = Basis(Vector3.RIGHT, curve * pow((i + 0.5) / segs, 1.6))
		mb.add_box(lacquer, Transform3D(b, at + b * Vector3(0, 0, -seg * 0.5)), Vector3(0.03, h - 0.002 * i, seg + 0.012), 2.0)
		at += b * Vector3(0, 0, -seg)
	mb.add_box(lacquer, Transform3D(b, at + b * Vector3(0, 0, -0.06)), Vector3(0.028, h - 0.012, 0.12), 2.0)
	mb.add_box(horn, Transform3D(b, at + b * Vector3(0, 0, -0.13)), Vector3(0.032, h - 0.008, 0.03), 2.0)
	mb.add_box(horn, Transform3D(Basis(), Vector3(0, 0, -0.052)), Vector3(0.036, h + 0.005, 0.024), 2.0)
	mb.add_box(cord, Transform3D(Basis(), Vector3(0, 0, -0.13)), Vector3(0.036, h + 0.005, 0.02), 2.0)
	return mb.commit()


## Any weapon's item id: a kind, then one of its designs.
static func random_item(rng: RandomNumberGenerator) -> String:
	return pick_id(str(BASE_ITEM.keys()[rng.randi() % BASE_ITEM.size()]), rng)


## How often a "rare" design (the bisento) stays when it's rolled; otherwise a common design of its kind.
const RARE_KEEP := 0.35


## One of `kind`'s item ids at random (the base's too), a "rare" design kept only RARE_KEEP of the times it comes
## up. (Kinds with no rare design draw once, as they always did.)
static func pick_id(kind: String, rng: RandomNumberGenerator) -> String:
	var ids := item_ids(kind)
	var id := str(ids[rng.randi() % ids.size()])
	if is_rare(kind, id) and rng.randf() > RARE_KEEP:
		var common := ids.filter(func(x): return not is_rare(kind, str(x)))
		id = str(common[rng.randi() % common.size()])
	return id


static func is_rare(kind: String, id: String) -> bool:
	for d in (DESIGNS.get(kind, {}) as Dictionary).values():
		if str(d["id"]) == id:
			return bool(d.get("rare", false))
	return false


## (ItemDB, loading) the design items, made from each kind's base item.
static func make_items(items: Dictionary) -> void:
	for kind in DESIGNS.keys():
		var base: ItemData = items[BASE_ITEM[kind]]
		base.icon = icon(base.model())
		for d in (DESIGNS[kind] as Dictionary).keys():
			var spec: Dictionary = DESIGNS[kind][d]
			var it := base.duplicate() as ItemData
			it.id = str(spec["id"])
			it.display_name = str(spec["name"])
			it.description = str(spec["desc"])
			it.design = d
			it.damage_mult = base.damage_mult * float(spec["dmg"])
			it.value = maxi(int(round(base.value * float(spec["worth"]))), 1)
			it.poison = float(spec.get("poison", 0.0))
			it.weapon_trait = "venomous" if it.poison > 0.0 else ""
			it.icon = icon(it.model())
			items[it.id] = it


# --------------------------------------------------------------------------
# Building one
# --------------------------------------------------------------------------
static func _f(p: Dictionary, key: String, def: float) -> float:
	return float(p.get(key, def))


static func _c(p: Dictionary, key: String, def: Color) -> Color:
	return p.get(key, def)


## Materials for a design at a tier: blade, edge, fittings, grip, gem (or null).
static func _mats(p: Dictionary, tier: int, fit_def: Color, grip_def: Color, grip_tex: String) -> Dictionary:
	var blade_tint: Color = _c(p, "blade", Color.WHITE) * TIER_BLADE[tier] if tier >= 5 else _c(p, "blade", Color.WHITE)
	var fit: Color = TIER_FIT[tier] if tier >= 2 else _c(p, "fit", fit_def)
	var edge: Material
	if tier >= 5:
		edge = PSXMat.glow(TIER_GEM[tier], 2.5)
	elif p.has("venom"):
		edge = PSXMat.glow(p["venom"], 1.8)
	else:
		edge = PSXMat.lit("metal", blade_tint.lightened(0.35) * 1.15)
	return {
		"blade": PSXMat.lit("metal", blade_tint),
		"edge": edge,
		"fit": PSXMat.lit("metal", fit),
		"grip": PSXMat.lit(str(p.get("grip_tex", grip_tex)), _c(p, "grip", grip_def)),
		"gem": PSXMat.glow(TIER_GEM[tier], 2.0) if tier >= 3 else null,
	}


## The mesh for a model string ("<kind>:<design>:<tier>", or just "<kind>").
static func build(model: String) -> ArrayMesh:
	var parts := model.split(":")
	var kind := parts[0]
	var design := parts[1] if parts.size() > 1 else ""
	var tier := clampi(int(parts[2]), 0, 6) if parts.size() > 2 else 0
	var p: Dictionary = (DESIGNS.get(kind, {}) as Dictionary).get(design, {})
	var mb := MeshBuilder.new()
	match kind:
		"katana":
			_katana(mb, p, tier)
		"axe":
			_axe(mb, p, tier)
		"pistol":
			_pistol(mb, p, tier)
		"dagger":
			_dagger(mb, p, tier)
		"polearm":
			_polearm(mb, p, tier)
		"hammer":
			_hammer(mb, p, tier)
		"greatsword":
			_greatsword(mb, p, tier)
		_:
			_sword(mb, p, tier)
	var m := mb.commit()
	m.set_meta("model", model)
	return m


## A blade as a chain of segments from `start` along -Z, curving toward +Y
## (the spine) as it goes, its edge strip along -Y. Returns the tip point.
static func _blade(mb: MeshBuilder, m: Dictionary, start: Vector3, length: float, w: float, th: float, curve: float,
		taper: float, segs: int, clip: bool, wave: float = 0.0) -> Vector3:
	var at := start
	var seg := length / segs
	var a := 0.0
	for i in range(segs):
		var k := (i + 0.5) / segs
		# (a wavy blade zigzags segment to segment: ripples, not a bend)
		a = curve * pow(k, 1.6) + wave * (1.0 if i % 2 == 0 else -1.0)
		var b := Basis(Vector3.RIGHT, a)
		var dir := b * Vector3(0, 0, -1)
		var bw := w * lerpf(1.0, taper, k)
		var c := at + dir * seg * 0.5
		mb.add_box(m["blade"], Transform3D(b, c), Vector3(th, bw, seg + 0.012), 2.0)
		mb.add_box(m["edge"], Transform3D(b, c + b * Vector3(0, -bw * 0.5, 0)), Vector3(th * 0.6, bw * 0.16, seg + 0.012), 2.0)
		at += dir * seg
	# the point: two narrowing steps on along the same line, the edge sweeping
	# up to the spine (a clipped point: the spine coming down to the edge)
	var b := Basis(Vector3.RIGHT, a)
	var dir := b * Vector3(0, 0, -1)
	var side := -1.0 if clip else 1.0
	var tw := w * taper
	for step in [[0.55, 0.05], [0.25, 0.04]]:
		var sw := tw * float(step[0])
		var sl := float(step[1])
		var c := at + dir * sl * 0.5 + b * Vector3(0, side * (tw - sw) * 0.5, 0)
		mb.add_box(m["blade"], Transform3D(b, c), Vector3(th, sw, sl + 0.006), 2.0)
		at += dir * sl
	return at


## Cutlasses and their kin: one-handed, grip at the origin, knuckles toward -Y.
static func _sword(mb: MeshBuilder, p: Dictionary, tier: int) -> void:
	var m := _mats(p, tier, Color(1.0, 0.78, 0.4), Color.WHITE, "planks_dark")
	var w := _f(p, "w", 0.07)
	var th := _f(p, "th", 0.025)
	_blade(mb, m, Vector3(0, 0, -0.09), _f(p, "len", 0.56) + _f(p, "tip", 0.28), w, th, _f(p, "curve", 0.2),
		_f(p, "taper", 1.0), 4, bool(p.get("clip", false)))
	var fit: Material = m["fit"]
	match str(p.get("guard", "knuckle")):
		"cross":
			var gs := _f(p, "guard_size", 0.2)
			mb.add_box(fit, Transform3D(Basis(), Vector3(0, 0, -0.08)), Vector3(0.035, gs, 0.035), 2.0)
			for s in [-1.0, 1.0]:
				mb.add_box(fit, Transform3D(Basis(), Vector3(0, s * gs * 0.5, -0.09)), Vector3(0.045, 0.03, 0.05), 2.0)
		"stirrup":
			mb.add_box(fit, Transform3D(Basis(), Vector3(0, -0.01, -0.08)), Vector3(0.03, 0.13, 0.03), 2.0)
			mb.add_box(fit, Transform3D(Basis(), Vector3(0, -0.075, 0.03)), Vector3(0.02, 0.02, 0.2), 2.0)
			mb.add_box(fit, Transform3D(Basis(), Vector3(0, -0.04, 0.13)), Vector3(0.02, 0.07, 0.02), 2.0)
		"cup":
			mb.add_cylinder(fit, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 0, -0.12)), 0.03, 0.065, 0.05, 8, 2.0)
			mb.add_box(fit, Transform3D(Basis(), Vector3(0, 0, -0.06)), Vector3(0.02, 0.2, 0.02), 2.0)
			mb.add_box(fit, Transform3D(Basis(Vector3.RIGHT, 0.5), Vector3(0, -0.07, 0.0)), Vector3(0.018, 0.018, 0.16), 2.0)
		"shell":
			mb.add_cylinder(fit, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, -0.02, -0.1)), 0.02, 0.045, 0.025, 7, 2.0)
			mb.add_box(fit, Transform3D(Basis(), Vector3(0, 0, -0.08)), Vector3(0.03, 0.11, 0.03), 2.0)
		"basket":
			mb.add_box(fit, Transform3D(Basis(), Vector3(0, 0, -0.085)), Vector3(0.1, 0.15, 0.02), 2.0)
			for x in [-0.045, 0.045]:
				for y in [-0.06, 0.06]:
					mb.add_box(fit, Transform3D(Basis(), Vector3(x, y, 0.02)), Vector3(0.012, 0.012, 0.2), 2.0)
			mb.add_box(fit, Transform3D(Basis(), Vector3(0, -0.06, 0.12)), Vector3(0.1, 0.012, 0.012), 2.0)
		"disc":
			mb.add_cylinder(fit, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 0, -0.1)), 0.05, 0.05, 0.015, 8, 2.0)
		_:
			# the knuckle bow
			mb.add_box(fit, Transform3D(Basis(), Vector3(0, 0, -0.08)), Vector3(0.05, 0.16, 0.05), 2.0)
			mb.add_box(fit, Transform3D(Basis(), Vector3(0, -0.07, 0.03)), Vector3(0.04, 0.03, 0.2), 2.0)
	mb.add_box(m["grip"], Transform3D(Basis(), Vector3(0, 0, 0.04)), Vector3(0.042, 0.048, 0.17), 2.0)
	var end := Vector3(0, 0, 0.13)
	match str(p.get("pommel", "cap")):
		"ball":
			mb.add_cylinder(fit, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), end - Vector3(0, 0, 0.0)), 0.03, 0.03, 0.045, 6, 2.0)
		"ring":
			for s in [-1.0, 1.0]:
				mb.add_box(fit, Transform3D(Basis(), end + Vector3(0, s * 0.03, 0.03)), Vector3(0.012, 0.012, 0.07), 2.0)
			mb.add_box(fit, Transform3D(Basis(), end + Vector3(0, 0, 0.065)), Vector3(0.012, 0.07, 0.012), 2.0)
			if p.has("tassel"):
				mb.add_box(PSXMat.lit("fabric", p["tassel"]), Transform3D(Basis(), end + Vector3(0, -0.06, 0.07)), Vector3(0.02, 0.1, 0.02), 2.0)
		_:
			mb.add_box(fit, Transform3D(Basis(), end), Vector3(0.05, 0.055, 0.025), 2.0)
	if m["gem"]:
		mb.add_box(m["gem"], Transform3D(Basis(), Vector3(0.0, 0, -0.08)), Vector3(0.055, 0.03, 0.03), 2.0)


## Katanas: the right hand at the origin behind the guard, a long wrapped
## hilt back to the pommel (the left hand at +0.17), the blade along -Z.
static func _katana(mb: MeshBuilder, p: Dictionary, tier: int) -> void:
	var m := _mats(p, tier, Color(1.0, 0.78, 0.4), Color.WHITE, "fabric")
	var wrap := PSXMat.lit("fabric", _c(p, "wrap", Color(0.16, 0.13, 0.17)))
	var fit: Material = m["fit"]
	var iron: Material = PSXMat.lit("metal", Color(0.32, 0.3, 0.3)) if tier < 2 else fit
	mb.add_box(wrap, Transform3D(Basis(), Vector3(0, 0, 0.115)), Vector3(0.034, 0.04, 0.27), 2.0)
	# the cord's diamonds down the hilt
	for z in [0.03, 0.09, 0.15, 0.21]:
		mb.add_box(fit, Transform3D(Basis(Vector3.BACK, PI * 0.25), Vector3(0, 0, z)), Vector3(0.024, 0.024, 0.012), 2.0)
	mb.add_box(fit, Transform3D(Basis(), Vector3(0, 0, 0.255)), Vector3(0.038, 0.044, 0.02), 2.0)
	match str(p.get("tsuba", "round")):
		"square":
			mb.add_box(iron, Transform3D(Basis(), Vector3(0, 0, -0.03)), Vector3(0.075, 0.08, 0.012), 2.0)
		"flower":
			mb.add_cylinder(iron, Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(0, 0, -0.024)), 0.04, 0.04, 0.012, 8, 2.0)
			for k in range(4):
				var b := Basis(Vector3.BACK, PI * 0.5 * k + PI * 0.25)
				mb.add_box(fit, Transform3D(b, Vector3(0, 0, -0.03) + b * Vector3(0, 0.045, 0)), Vector3(0.022, 0.022, 0.012), 2.0)
		_:
			mb.add_cylinder(iron, Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(0, 0, -0.024)), 0.046, 0.046, 0.012, 8, 2.0)
	mb.add_box(fit, Transform3D(Basis(), Vector3(0, 0, -0.05)), Vector3(0.016, 0.04, 0.025), 2.0)
	_blade(mb, m, Vector3(0, 0, -0.06), _f(p, "len", 0.82), _f(p, "w", 0.033), 0.012, _f(p, "curve", 0.32), 0.92, 5, false)
	if m["gem"]:
		mb.add_box(m["gem"], Transform3D(Basis(), Vector3(0, 0, 0.268)), Vector3(0.02, 0.024, 0.012), 2.0)


## Daggers and knives: one-handed, the grip at the origin, a short blade along
## -Z with its edge toward -Y (the knuckle side, as a cutlass's).
static func _dagger(mb: MeshBuilder, p: Dictionary, tier: int) -> void:
	var m := _mats(p, tier, Color(0.62, 0.6, 0.56), Color(0.36, 0.25, 0.16), "leather")
	var w := _f(p, "w", 0.038)
	var th := _f(p, "th", 0.016)
	_blade(mb, m, Vector3(0, 0, -0.058), _f(p, "len", 0.21) + _f(p, "tip", 0.07), w, th, _f(p, "curve", 0.0), _f(p, "taper", 0.75),
		7 if p.has("wave") else 4, false, _f(p, "wave", 0.0))
	if bool(p.get("teeth", false)):
		var tooth := PSXMat.lit("metal", Color(1.05, 1.0, 0.9))
		for i in range(5):
			var z := -0.085 - i * 0.038
			mb.add_box(tooth, Transform3D(Basis(Vector3.RIGHT, 0.45), Vector3(0, -w * 0.5 - 0.006, z)), Vector3(th * 0.9, 0.02, 0.014), 2.0)
	var fit: Material = m["fit"]
	match str(p.get("guard", "cross")):
		"ring":
			mb.add_box(fit, Transform3D(Basis(), Vector3(0, 0, -0.05)), Vector3(0.022, 0.08, 0.018), 2.0)
			mb.add_cylinder(fit, Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(0, -0.055, -0.045)), 0.02, 0.02, 0.01, 8, 2.0)
		"flare":
			mb.add_box(fit, Transform3D(Basis(), Vector3(0, -0.012, -0.052)), Vector3(0.03, 0.085, 0.022), 2.0)
			mb.add_box(fit, Transform3D(Basis(Vector3.RIGHT, -0.5), Vector3(0, -0.05, -0.068)), Vector3(0.024, 0.02, 0.04), 2.0)
		"bolster":
			mb.add_box(fit, Transform3D(Basis(), Vector3(0, 0, -0.048)), Vector3(0.042, 0.056, 0.03), 2.0)
		"shell":
			mb.add_cylinder(fit, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, -0.01, -0.056)), 0.06, 0.06, 0.012, 8, 2.0)
			mb.add_box(fit, Transform3D(Basis(), Vector3(0, 0, -0.05)), Vector3(0.024, 0.22, 0.02), 2.0)
			for s in [-1.0, 1.0]:
				mb.add_box(fit, Transform3D(Basis(Vector3.RIGHT, s * 0.5), Vector3(0, s * 0.11, -0.065)), Vector3(0.024, 0.02, 0.04), 2.0)
		"none":
			mb.add_box(fit, Transform3D(Basis(), Vector3(0, 0, -0.05)), Vector3(0.036, 0.046, 0.016), 2.0)
		_:
			mb.add_box(fit, Transform3D(Basis(), Vector3(0, 0, -0.05)), Vector3(0.028, 0.11, 0.022), 2.0)
			for s in [-1.0, 1.0]:
				mb.add_box(fit, Transform3D(Basis(), Vector3(0, s * 0.055, -0.056)), Vector3(0.034, 0.022, 0.03), 2.0)
	mb.add_box(m["grip"], Transform3D(Basis(), Vector3(0, 0, 0.012)), Vector3(0.032, 0.036, 0.11), 2.0)
	var end := Vector3(0, 0, 0.075)
	match str(p.get("pommel", "cap")):
		"ball":
			mb.add_cylinder(fit, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), end), 0.022, 0.022, 0.032, 6, 2.0)
		"hook":
			mb.add_box(fit, Transform3D(Basis(Vector3.RIGHT, 0.7), end + Vector3(0, -0.015, 0.008)), Vector3(0.034, 0.03, 0.05), 2.0)
		_:
			mb.add_box(fit, Transform3D(Basis(), end), Vector3(0.04, 0.044, 0.02), 2.0)
	if m["gem"]:
		mb.add_box(m["gem"], Transform3D(Basis(), Vector3(0.0, 0, -0.05)), Vector3(0.04, 0.024, 0.024), 2.0)


## A dagger's sheath in the blade's own frame: leather along the same curve, a
## throat band and a chape at the tip (it stays on the hip when the dagger's drawn).
static func dagger_sheath(model: String) -> ArrayMesh:
	var p: Dictionary = (DESIGNS["dagger"] as Dictionary).get(model.get_slice(":", 1), {})
	var tier := clampi(int(model.get_slice(":", 2)), 0, 6) if model.get_slice_count(":") > 2 else 0
	var leather := PSXMat.lit("leather", Color(0.32, 0.22, 0.15))
	var metal := PSXMat.lit("metal", TIER_FIT[tier] if tier >= 2 else _c(p, "fit", Color(0.62, 0.6, 0.56)))
	var mb := MeshBuilder.new()
	var segs := 4
	# (the blade's point runs 0.09 past its length: _blade's two narrowing steps)
	var seg := (_f(p, "len", 0.21) + _f(p, "tip", 0.07) + 0.11) / segs
	var h := _f(p, "w", 0.038) * maxf(_f(p, "taper", 0.75), 1.0) + 0.02 + absf(_f(p, "wave", 0.0)) * 0.12 + (0.025 if p.has("teeth") else 0.0)
	var t := _f(p, "th", 0.016) + 0.02
	var curve := _f(p, "curve", 0.0)
	var at := Vector3(0, 0, -0.06)
	var b := Basis()
	for i in range(segs):
		b = Basis(Vector3.RIGHT, curve * pow((i + 0.5) / segs, 1.6))
		mb.add_box(leather, Transform3D(b, at + b * Vector3(0, 0, -seg * 0.5)), Vector3(t, h * lerpf(1.0, 0.75, float(i) / segs), seg + 0.01), 2.0)
		at += b * Vector3(0, 0, -seg)
	mb.add_box(metal, Transform3D(b, at + b * Vector3(0, 0, 0.012)), Vector3(t + 0.004, h * 0.72, 0.03), 2.0)
	mb.add_box(metal, Transform3D(Basis(), Vector3(0, 0, -0.068)), Vector3(t + 0.006, h + 0.006, 0.016), 2.0)
	return mb.commit()


## Polearms: held at the origin by the rear (right) hand, the shaft POLE_BEHIND back to its butt and
## POLE_AHEAD (x "reach") forward to the head, which spreads in the Y plane with its edge toward -Y.
## Leather wraps mark where the hands go (the left slides along the shaft between them).
static func _polearm(mb: MeshBuilder, p: Dictionary, tier: int) -> void:
	var m := _mats(p, tier, Color(0.6, 0.58, 0.55), Color(0.32, 0.22, 0.15), "leather")
	var wood := PSXMat.lit("planks", _c(p, "wood", Color(0.62, 0.46, 0.3)))
	var steel: Material = m["blade"]
	var edge: Material = m["edge"]
	var fit: Material = m["fit"]
	var along := Basis(Vector3.RIGHT, -PI * 0.5)
	var ahead := POLE_AHEAD * _f(p, "reach", 1.0)
	var z0 := -ahead
	mb.add_cylinder(wood, Transform3D(along, Vector3(0, 0, POLE_BEHIND)), 0.021, 0.019, ahead + POLE_BEHIND, 6, 2.0)
	mb.add_cylinder(fit, Transform3D(along, Vector3(0, 0, POLE_BEHIND + 0.035)), 0.025, 0.023, 0.07, 6, 2.0, Color.WHITE, true, true)
	for g in [[0.02, 0.17], [-0.5, 0.22]]:
		mb.add_box(m["grip"], Transform3D(Basis(), Vector3(0, 0, float(g[0]))), Vector3(0.046, 0.046, float(g[1])), 2.0)
	mb.add_cylinder(fit, Transform3D(along, Vector3(0, 0, z0 + 0.12)), 0.027, 0.023, 0.13, 6, 2.0)
	var h := z0 - 0.01
	match str(p.get("head", "leaf")):
		"trident":
			mb.add_box(fit, Transform3D(Basis(), Vector3(0, 0, h)), Vector3(0.03, 0.22, 0.03), 2.0)
			for y in [-0.095, 0.0, 0.095]:
				var l := 0.34 if y == 0.0 else 0.26
				mb.add_box(steel, Transform3D(Basis(), Vector3(0, y, h - l * 0.5)), Vector3(0.018, 0.022, l), 2.0)
				mb.add_box(edge, Transform3D(Basis(), Vector3(0, y, h - l - 0.025)), Vector3(0.012, 0.014, 0.05), 2.0)
				var out := signf(y) if y != 0.0 else -1.0
				mb.add_box(steel, Transform3D(Basis(Vector3.RIGHT, -out * 0.6), Vector3(0, y + out * 0.018, h - l + 0.04)), Vector3(0.014, 0.012, 0.06), 2.0)
		"naginata":
			mb.add_cylinder(fit, Transform3D(along, Vector3(0, 0, h + 0.008)), 0.045, 0.045, 0.014, 8, 2.0)
			_blade(mb, m, Vector3(0, 0, h - 0.02), 0.5, 0.046, 0.014, 0.4, 1.08, 5, false)
		"bisento":
			_blade(mb, m, Vector3(0, -0.03, h - 0.02), 0.58, 0.12, 0.018, 0.24, 1.3, 5, false)
			mb.add_box(fit, Transform3D(Basis(), Vector3(0, 0.05, h - 0.14)), Vector3(0.024, 0.05, 0.05), 2.0)
			mb.add_box(fit, Transform3D(Basis(), Vector3(0, 0, h + 0.02)), Vector3(0.036, 0.1, 0.03), 2.0)
			var tassel := PSXMat.lit("fabric", _c(p, "tassel", Color(0.75, 0.12, 0.1)))
			mb.add_box(tassel, Transform3D(Basis(Vector3.RIGHT, 0.25), Vector3(0, 0.07, h + 0.13)), Vector3(0.03, 0.12, 0.03), 2.0)
		"halberd":
			_blade(mb, m, Vector3(0, 0, h - 0.04), 0.26, 0.032, 0.02, 0.0, 0.6, 2, false)
			mb.add_box(steel, Transform3D(Basis(), Vector3(0, -0.1, h - 0.1)), Vector3(0.022, 0.17, 0.2), 2.0)
			mb.add_box(steel, Transform3D(Basis(Vector3.RIGHT, 0.35), Vector3(0, -0.17, h - 0.05)), Vector3(0.02, 0.06, 0.12), 2.0)
			mb.add_box(edge, Transform3D(Basis(), Vector3(0, -0.19, h - 0.1)), Vector3(0.016, 0.022, 0.26), 2.0)
			mb.add_box(steel, Transform3D(Basis(Vector3.RIGHT, -0.5), Vector3(0, 0.08, h - 0.06)), Vector3(0.02, 0.14, 0.03), 2.0)
		"fork":
			mb.add_box(fit, Transform3D(Basis(), Vector3(0, 0, h)), Vector3(0.028, 0.17, 0.026), 2.0)
			for y in [-0.07, 0.0, 0.07]:
				mb.add_box(fit, Transform3D(Basis(), Vector3(0, y, h - 0.15)), Vector3(0.012, 0.012, 0.3), 2.0)
		_:
			mb.add_box(fit, Transform3D(Basis(), Vector3(0, 0, h)), Vector3(0.032, 0.034, 0.04), 2.0)
			_blade(mb, m, Vector3(0, 0, h - 0.02), 0.2, 0.068, 0.02, 0.0, 0.62, 3, false)
	if m["gem"]:
		mb.add_box(m["gem"], Transform3D(Basis(), Vector3(0, 0, z0 + 0.08)), Vector3(0.058, 0.03, 0.03), 2.0)


## Hammers: held at the origin by the right hand near the butt (HAMMER_BUTT behind it), the haft "haft" on
## to the head's middle; the head spreads in the Y plane, its striking face toward -Y (as a polearm's edge).
## The left hand slides along the wrap above the right.
static func _hammer(mb: MeshBuilder, p: Dictionary, tier: int) -> void:
	var m := _mats({"blade": Color(0.56, 0.55, 0.54)}.merged(p, true), tier, Color(0.5, 0.48, 0.46), Color(0.3, 0.2, 0.13), "leather")
	var wood := PSXMat.lit("planks_dark", _c(p, "wood", Color(0.5, 0.36, 0.24)))
	var iron: Material = m["blade"]
	var face: Material = m["edge"]
	var fit: Material = m["fit"]
	var along := Basis(Vector3.RIGHT, -PI * 0.5)
	var haft := _f(p, "haft", HAMMER_HAFT)
	var hz := -haft
	var head := str(p.get("head", "war"))
	if head != "kanabo":
		mb.add_cylinder(iron if head == "anchor" else wood, Transform3D(along, Vector3(0, 0, HAMMER_BUTT)), 0.025, 0.022, haft + HAMMER_BUTT, 6, 2.0)
	mb.add_cylinder(fit, Transform3D(along, Vector3(0, 0, HAMMER_BUTT + 0.03)), 0.033, 0.029, 0.06, 6, 2.0, Color.WHITE, true, true)
	mb.add_box(m["grip"], Transform3D(Basis(), Vector3(0, 0, -0.12)), Vector3(0.056, 0.056, 0.4), 2.0, Color.WHITE, false, false)
	match head:
		"kanabo":
			# an octagonal club thickening to its end, iron studs in staggered rings over its upper half
			var top := hz - 0.12
			mb.add_cylinder(wood, Transform3D(along, Vector3(0, 0, HAMMER_BUTT)), 0.026, 0.03, 0.42 + HAMMER_BUTT, 8, 2.0)
			mb.add_cylinder(wood, Transform3D(along, Vector3(0, 0, -0.3)), 0.03, 0.074, -0.3 - top, 8, 2.0)
			mb.add_cylinder(fit, Transform3D(along, Vector3(0, 0, top + 0.03)), 0.078, 0.07, 0.045, 8, 2.0)
			for i in 6:
				var z := lerpf(-0.44, top + 0.07, i / 5.0)
				var r := lerpf(0.03, 0.074, (-0.3 - z) / (-0.3 - top))
				for k in 8:
					var a := TAU * (k + 0.5 * (i % 2)) / 8.0
					mb.add_box(fit, Transform3D(Basis(), Vector3(cos(a), sin(a), 0) * (r + 0.008) + Vector3(0, 0, z)), Vector3(0.026, 0.026, 0.026), 2.0, Color.WHITE, false, false)
		"mallet":
			# a barrel of oak across the end, an iron hoop near each face
			mb.add_cylinder(wood, Transform3D(Basis(), Vector3(0, -0.17, hz)), 0.105, 0.105, 0.34, 8, 2.0, Color.WHITE, true, true)
			for y in [-0.15, 0.12]:
				mb.add_cylinder(fit, Transform3D(Basis(), Vector3(0, y, hz)), 0.113, 0.113, 0.03, 8, 2.0, Color.WHITE, false, false)
		"maul":
			# a long block of black iron, a face at each end
			mb.add_box(iron, Transform3D(Basis(), Vector3(0, 0, hz)), Vector3(0.14, 0.36, 0.14), 2.0, Color.WHITE, false, false)
			for s in [-1.0, 1.0]:
				mb.add_box(face, Transform3D(Basis(), Vector3(0, s * 0.19, hz)), Vector3(0.152, 0.03, 0.152), 2.0, Color.WHITE, false, false)
				mb.add_box(fit, Transform3D(Basis(), Vector3(0, s * 0.08, hz)), Vector3(0.15, 0.025, 0.15), 2.0, Color.WHITE, false, false)
			mb.add_box(fit, Transform3D(Basis(), Vector3(0, 0, hz + 0.1)), Vector3(0.05, 0.05, 0.08), 2.0)
		"anchor":
			# an anchor's crown on an iron shank: the arms curving back to the flukes, a ring at the butt, chain
			# wound round the shank above the hands
			mb.add_box(iron, Transform3D(Basis(), Vector3(0, 0, hz - 0.02)), Vector3(0.1, 0.13, 0.11), 2.0, Color.WHITE, false, false)
			for s in [-1.0, 1.0]:
				var arm := PackedVector3Array([Vector3(0, 0, hz - 0.04), Vector3(0, s * 0.13, hz - 0.05), Vector3(0, s * 0.22, hz + 0.04), Vector3(0, s * 0.25, hz + 0.16)])
				mb.add_tube(iron, arm, 0.032, 0.022, 6)
				mb.add_box(face, Transform3D(Basis(Vector3.RIGHT, s * 0.35), Vector3(0, s * 0.262, hz + 0.17)), Vector3(0.028, 0.11, 0.15), 2.0, Color.WHITE, false, false)
			var ring := PackedVector3Array()
			for k in 9:
				var a := TAU * k / 8.0
				ring.append(Vector3(0, sin(a) * 0.05, HAMMER_BUTT + 0.1 + cos(a) * 0.05))
			mb.add_tube(fit, ring, 0.012, -1.0, 4)
			for i in 7:
				mb.add_box(fit, Transform3D(Basis(Vector3.BACK, PI * 0.5 * (i % 2)), Vector3(0, 0, -0.38 - i * 0.065)), Vector3(0.06, 0.016, 0.075), 2.0, Color.WHITE, false, false)
		_:
			# the warhammer: a square face on an iron block, a spike behind and one on top, langets down the haft
			mb.add_box(iron, Transform3D(Basis(), Vector3(0, -0.04, hz)), Vector3(0.12, 0.2, 0.12), 2.0, Color.WHITE, false, false)
			mb.add_box(face, Transform3D(Basis(), Vector3(0, -0.15, hz)), Vector3(0.135, 0.03, 0.135), 2.0, Color.WHITE, false, false)
			mb.add_cone(iron, Transform3D(Basis(), Vector3(0, 0.06, hz)), 0.05, 0.17, 4)
			mb.add_cone(iron, Transform3D(along, Vector3(0, 0, hz - 0.06)), 0.03, 0.09, 4)
			for s in [-1.0, 1.0]:
				mb.add_box(fit, Transform3D(Basis(), Vector3(s * 0.026, 0, hz + 0.16)), Vector3(0.01, 0.036, 0.22), 2.0)
	if m["gem"]:
		mb.add_box(m["gem"], Transform3D(Basis(), Vector3(0, 0, hz + 0.12)), Vector3(0.062, 0.03, 0.03), 2.0)


## Greatswords: held at the origin by the right hand at the pommel end of a long two-hand grip (the left slides up it
## toward the guard), the guard GREAT_GUARD ahead and a broad blade "len" on along -Z, its edge toward -Y.
static func _greatsword(mb: MeshBuilder, p: Dictionary, tier: int) -> void:
	var m := _mats(p, tier, Color(0.6, 0.58, 0.55), Color(0.3, 0.2, 0.14), "leather")
	var fit: Material = m["fit"]
	var w := _f(p, "w", 0.12)
	var th := _f(p, "th", 0.026)
	var length := _f(p, "len", GREAT_LEN)
	var taper := _f(p, "taper", 0.85)
	var curve := _f(p, "curve", 0.0)
	var gz := -GREAT_GUARD
	var z0 := gz - 0.025
	_blade(mb, m, Vector3(0, 0, z0), length, w, th, curve, taper, 6, bool(p.get("clip", false)))
	# the fuller down the first half of each face, or teeth filed into the edge (the same segments as the blade)
	var bt: Color = _c(p, "blade", Color.WHITE) * (TIER_BLADE[tier] if tier >= 5 else Color.WHITE)
	var groove := PSXMat.lit("metal", bt * 0.55)
	var seg := length / 6.0
	var at := Vector3(0, 0, z0)
	for i in 6:
		var k := (i + 0.5) / 6.0
		var b := Basis(Vector3.RIGHT, curve * pow(k, 1.6))
		var dir := b * Vector3(0, 0, -1)
		var bw := w * lerpf(1.0, taper, k)
		if i < 3 and not bool(p.get("clip", false)):
			mb.add_box(groove, Transform3D(b, at + dir * seg * 0.5), Vector3(th + 0.004, bw * 0.22, seg + 0.01), 2.0, Color.WHITE, false, false)
		if bool(p.get("teeth", false)) and i > 0:
			for t in 2:
				var c := at + dir * seg * (0.25 + 0.5 * t) + b * Vector3(0, -bw * 0.5 - 0.012, 0)
				mb.add_box(m["edge"], Transform3D(b * Basis(Vector3.RIGHT, 0.5), c), Vector3(th * 0.85, 0.034, 0.03), 2.0)
		at += dir * seg
	if bool(p.get("clip", false)):
		# (the cleaver's hanging hole near its end)
		mb.add_cylinder(groove, Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3((th + 0.006) * 0.5, w * 0.22, z0 - length + 0.13)), 0.032, 0.032, th + 0.006, 8, 2.0)
	match str(p.get("guard", "cross")):
		"long":
			mb.add_box(fit, Transform3D(Basis(), Vector3(0, 0, gz)), Vector3(0.032, 0.46, 0.036), 2.0)
			mb.add_box(fit, Transform3D(Basis(Vector3.BACK, PI * 0.25), Vector3(0, 0, gz)), Vector3(0.05, 0.06, 0.06), 2.0)
			for s in [-1.0, 1.0]:
				mb.add_box(fit, Transform3D(Basis(Vector3.RIGHT, s * 0.7), Vector3(0, s * 0.235, gz - 0.035)), Vector3(0.03, 0.028, 0.09), 2.0)
		"claymore":
			mb.add_box(fit, Transform3D(Basis(), Vector3(0, 0, gz)), Vector3(0.05, 0.09, 0.06), 2.0)
			mb.add_box(fit, Transform3D(Basis(), Vector3(0, 0, gz - 0.07)), Vector3(0.02, 0.05, 0.1), 2.0)
			for s in [-1.0, 1.0]:
				mb.add_box(fit, Transform3D(Basis(Vector3.RIGHT, -s * 0.6), Vector3(0, s * 0.083, gz - 0.056)), Vector3(0.03, 0.2, 0.03), 2.0)
				var tip := Vector3(0, s * 0.165, gz - 0.113)
				for o in [Vector3(0, 0.026, 0), Vector3(0, -0.026, 0), Vector3(0, 0, 0.026), Vector3(0, 0, -0.026)]:
					mb.add_box(fit, Transform3D(Basis(), tip + o * Vector3(1, s, 1)), Vector3(0.028, 0.028, 0.028), 2.0, Color.WHITE, false, false)
		"block":
			mb.add_box(fit, Transform3D(Basis(), Vector3(0, 0, gz)), Vector3(0.06, w + 0.07, 0.07), 2.0)
		"bone":
			mb.add_cylinder(fit, Transform3D(Basis(), Vector3(0, -0.14, gz)), 0.034, 0.03, 0.28, 6, 2.0)
			for s in [-1.0, 1.0]:
				mb.add_box(fit, Transform3D(Basis(Vector3.RIGHT, s * 0.4), Vector3(0, s * 0.15, gz + 0.01)), Vector3(0.06, 0.055, 0.065), 2.0)
		_:
			mb.add_box(fit, Transform3D(Basis(), Vector3(0, 0, gz)), Vector3(0.036, 0.34, 0.04), 2.0)
			mb.add_box(fit, Transform3D(Basis(), Vector3(0, 0, gz)), Vector3(0.05, 0.08, 0.055), 2.0)
			for s in [-1.0, 1.0]:
				mb.add_box(fit, Transform3D(Basis(), Vector3(0, s * 0.17, gz)), Vector3(0.048, 0.036, 0.05), 2.0)
	mb.add_box(m["grip"], Transform3D(Basis(), Vector3(0, 0, (0.06 + gz + 0.03) * 0.5)), Vector3(0.042, 0.046, 0.06 - gz - 0.03), 2.0)
	mb.add_box(fit, Transform3D(Basis(), Vector3(0, 0, -0.12)), Vector3(0.048, 0.052, 0.018), 2.0, Color.WHITE, false, false)
	var end := Vector3(0, 0, 0.085)
	match str(p.get("pommel", "ball")):
		"disc":
			mb.add_cylinder(fit, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), end - Vector3(0, 0, 0.015)), 0.048, 0.048, 0.03, 8, 2.0)
		"wheel":
			mb.add_cylinder(fit, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), end - Vector3(0, 0, 0.02)), 0.055, 0.055, 0.035, 8, 2.0)
			mb.add_box(fit, Transform3D(Basis(), end + Vector3(0, 0, 0.025)), Vector3(0.03, 0.03, 0.03), 2.0)
		"drop":
			mb.add_box(fit, Transform3D(Basis(), end), Vector3(0.046, 0.05, 0.06), 2.0)
			mb.add_cone(fit, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), end + Vector3(0, 0, 0.03)), 0.03, 0.06, 4)
		_:
			mb.add_cylinder(fit, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), end - Vector3(0, 0, 0.02)), 0.036, 0.036, 0.045, 6, 2.0)
	if m["gem"]:
		mb.add_box(m["gem"], Transform3D(Basis(), Vector3(0, 0, gz)), Vector3(0.058, 0.032, 0.032), 2.0)


## Axes: the haft back past the hand, the head out toward -Y (the knuckle
## side, as a sword's edge) near the far end.
static func _axe(mb: MeshBuilder, p: Dictionary, tier: int) -> void:
	var m := _mats(p, tier, Color(1.0, 0.78, 0.4), Color.WHITE, "planks_dark")
	var wood := PSXMat.lit("planks_dark", _c(p, "wood", Color(1, 1, 1)))
	var steel: Material = m["blade"]
	var edge: Material = m["edge"]
	var fit: Material = m["fit"]
	var haft := _f(p, "haft", 0.9)
	var hz := -(haft - 0.22)
	mb.add_box(wood, Transform3D(Basis(), Vector3(0, 0, 0.13 - haft * 0.5)), Vector3(0.05, 0.05, haft), 2.0)
	mb.add_box(fit, Transform3D(Basis(), Vector3(0, 0, 0.1)), Vector3(0.06, 0.06, 0.05), 2.0)
	if bool(p.get("bands", false)):
		for z in [hz * 0.3, hz * 0.6]:
			mb.add_box(fit, Transform3D(Basis(), Vector3(0, 0, z)), Vector3(0.058, 0.058, 0.025), 2.0)
	# The head is laid out with its bit toward +y and mirrored to -y as it's
	# placed: the bit leads the swing on the knuckle side, like a sword's edge.
	var hb := func(mat: Material, ang: float, pos: Vector3, size: Vector3) -> void:
		mb.add_box(mat, Transform3D(Basis(Vector3.RIGHT, -ang), Vector3(pos.x, -pos.y, pos.z)), size, 2.0)
	match str(p.get("head", "boarding")):
		"hatchet":
			hb.call(steel, 0.0, Vector3(0, 0.07, hz), Vector3(0.035, 0.14, 0.1))
			hb.call(edge, 0.0, Vector3(0, 0.145, hz), Vector3(0.025, 0.02, 0.13))
		"bearded":
			hb.call(steel, 0.0, Vector3(0, 0.07, hz), Vector3(0.04, 0.14, 0.11))
			hb.call(steel, 0.45, Vector3(0, 0.15, hz + 0.06), Vector3(0.035, 0.1, 0.22))
			hb.call(edge, 0.2, Vector3(0, 0.205, hz + 0.04), Vector3(0.025, 0.02, 0.28))
		"double":
			hb.call(fit, 0.0, Vector3(0, 0, hz), Vector3(0.06, 0.07, 0.09))
			for s in [-1.0, 1.0]:
				hb.call(steel, 0.0, Vector3(0, s * 0.1, hz), Vector3(0.035, 0.13, 0.12))
				hb.call(steel, 0.0, Vector3(0, s * 0.16, hz), Vector3(0.03, 0.06, 0.24))
				hb.call(edge, 0.0, Vector3(0, s * 0.195, hz), Vector3(0.022, 0.02, 0.26))
		"cleaver":
			hb.call(steel, 0.0, Vector3(0, 0.1, hz - 0.06), Vector3(0.03, 0.22, 0.3))
			hb.call(edge, 0.0, Vector3(0, 0.215, hz - 0.06), Vector3(0.02, 0.02, 0.3))
		"tomahawk":
			# a narrow bit flaring at the edge, a spike out behind it
			hb.call(steel, 0.0, Vector3(0, 0.065, hz), Vector3(0.032, 0.13, 0.065))
			hb.call(steel, 0.0, Vector3(0, 0.12, hz), Vector3(0.028, 0.04, 0.11))
			hb.call(edge, 0.0, Vector3(0, 0.145, hz), Vector3(0.022, 0.02, 0.12))
			hb.call(fit, 0.0, Vector3(0, -0.03, hz), Vector3(0.045, 0.06, 0.06))
			hb.call(steel, 0.0, Vector3(0, -0.1, hz), Vector3(0.022, 0.1, 0.024))
			hb.call(steel, 0.0, Vector3(0, -0.165, hz), Vector3(0.012, 0.04, 0.014))
		"reaver":
			# a bearded head whose beard sweeps back down the haft into a hook
			hb.call(steel, 0.0, Vector3(0, 0.07, hz), Vector3(0.04, 0.14, 0.11))
			hb.call(steel, 0.5, Vector3(0, 0.16, hz + 0.08), Vector3(0.035, 0.1, 0.26))
			hb.call(edge, 0.22, Vector3(0, 0.215, hz + 0.04), Vector3(0.025, 0.02, 0.32))
			hb.call(steel, 0.0, Vector3(0, 0.17, hz + 0.21), Vector3(0.032, 0.05, 0.06))
			hb.call(edge, -0.7, Vector3(0, 0.135, hz + 0.25), Vector3(0.024, 0.075, 0.03))
			hb.call(fit, 0.0, Vector3(0, -0.03, hz), Vector3(0.05, 0.06, 0.08))
		"war":
			hb.call(steel, 0.0, Vector3(0, 0.07, hz), Vector3(0.04, 0.13, 0.1))
			for s in [-1.0, 1.0]:
				hb.call(steel, s * 0.55, Vector3(0, 0.17, hz + s * 0.07), Vector3(0.035, 0.08, 0.17))
				hb.call(edge, s * 0.55, Vector3(0, 0.2, hz + s * 0.085), Vector3(0.025, 0.02, 0.17))
			hb.call(steel, 0.3, Vector3(0, -0.09, hz + 0.02), Vector3(0.03, 0.16, 0.035))
			hb.call(steel, 0.0, Vector3(0, 0, hz - 0.12), Vector3(0.03, 0.03, 0.14))
		_:
			hb.call(steel, 0.0, Vector3(0, 0.1, hz), Vector3(0.04, 0.26, 0.16))
			hb.call(steel, 0.25, Vector3(0, 0.22, hz - 0.06), Vector3(0.035, 0.14, 0.22))
			hb.call(edge, 0.25, Vector3(0, 0.29, hz - 0.08), Vector3(0.025, 0.02, 0.22))
	if m["gem"]:
		mb.add_box(m["gem"], Transform3D(Basis(), Vector3(0, 0, hz)), Vector3(0.062, 0.035, 0.035), 2.0)


## Pistols: barrel(s) forward above the hand, a curved grip below.
static func _pistol(mb: MeshBuilder, p: Dictionary, tier: int) -> void:
	var m := _mats(p, tier, Color(1.0, 0.78, 0.4), Color.WHITE, "planks")
	var wood := PSXMat.lit("planks", _c(p, "wood", Color(0.75, 0.5, 0.3)))
	var fit: Material = m["fit"]
	var steel: Material = fit if bool(p.get("brass_barrel", false)) else m["blade"]
	var bl := _f(p, "barrel", 0.36)
	var r := _f(p, "r", 0.022)
	var n := int(p.get("barrels", 1))
	var sides := int(p.get("sides", 6))
	var along := Basis(Vector3.RIGHT, -PI * 0.5)
	var muzzle := Vector3(0, 0.06, -0.05 - bl)
	if n == 1:
		var flare := _f(p, "flare", 0.0)
		if flare > 0.0:
			mb.add_cylinder(steel, Transform3D(along, Vector3(0, 0.06, -0.05)), r, r * 1.1, bl * 0.72, sides, 2.0)
			mb.add_cylinder(steel, Transform3D(along, Vector3(0, 0.06, -0.05 - bl * 0.72)), r * 1.1, flare, bl * 0.28, sides, 2.0)
		else:
			mb.add_cylinder(steel, Transform3D(along, Vector3(0, 0.06, -0.05)), r, r * 0.9, bl, sides, 2.0)
		mb.add_cylinder(fit, Transform3D(along, muzzle + Vector3(0, 0, 0.03)), r * 1.25, r * 1.25, 0.02, sides, 2.0)
	elif n == 2:
		for x in [-r, r]:
			mb.add_cylinder(steel, Transform3D(along, Vector3(x, 0.06, -0.05)), r, r, bl, sides, 2.0)
		mb.add_box(fit, Transform3D(Basis(), muzzle + Vector3(0, 0, 0.03)), Vector3(r * 4.4, r * 2.4, 0.02), 2.0)
	else:
		mb.add_cylinder(fit, Transform3D(along, Vector3(0, 0.06, -0.03)), r * 3.0, r * 3.0, 0.05, 8, 2.0)
		for k in range(n):
			var a := TAU * k / n
			mb.add_cylinder(steel, Transform3D(along, Vector3(cos(a) * r * 2.0, 0.06 + sin(a) * r * 2.0, -0.05)), r, r, bl, 6, 2.0)
	if bool(p.get("dragon", false)):
		var head := muzzle + Vector3(0, 0, -0.01)
		mb.add_box(fit, Transform3D(Basis(), head + Vector3(0, 0.012, -0.02)), Vector3(0.055, 0.035, 0.07), 2.0)
		mb.add_box(fit, Transform3D(Basis(Vector3.RIGHT, -0.35), head + Vector3(0, -0.02, -0.03)), Vector3(0.05, 0.015, 0.07), 2.0)
		for s in [-1.0, 1.0]:
			mb.add_box(fit, Transform3D(Basis(Vector3.RIGHT, 0.5), head + Vector3(s * 0.018, 0.04, 0.015)), Vector3(0.012, 0.04, 0.012), 2.0)
			mb.add_box(PSXMat.glow(Color(1.0, 0.2, 0.1), 2.5), Transform3D(Basis(), head + Vector3(s * 0.029, 0.02, -0.025)), Vector3(0.006, 0.01, 0.01), 2.0)
	# stock, grip and lock
	mb.add_box(wood, Transform3D(Basis(), Vector3(0, 0.05, -0.1)), Vector3(0.045 + (0.02 if n == 2 else 0.0), 0.05, 0.22), 2.0)
	mb.add_box(wood, Transform3D(Basis(Vector3.RIGHT, 0.5), Vector3(0, -0.03, 0.03)), Vector3(0.045, 0.16, 0.06), 2.0)
	mb.add_box(fit, Transform3D(Basis(Vector3.RIGHT, 0.5), Vector3(0, -0.1, 0.07)), Vector3(0.055, 0.04, 0.07), 2.0)
	mb.add_box(m["blade"], Transform3D(Basis(Vector3.RIGHT, -0.4), Vector3(0, 0.1, 0.02)), Vector3(0.02, 0.05, 0.02), 2.0)
	mb.add_box(fit, Transform3D(Basis(), Vector3(0, 0.0, -0.04)), Vector3(0.01, 0.04, 0.05), 2.0)
	if m["gem"]:
		mb.add_box(m["gem"], Transform3D(Basis(Vector3.RIGHT, 0.5), Vector3(0, -0.13, 0.085)), Vector3(0.03, 0.02, 0.03), 2.0)


# --------------------------------------------------------------------------
# Icons: the mesh itself, seen side on and laid corner to corner
# --------------------------------------------------------------------------
## Rough colours of the textures weapons use (icons are made headless too,
## where textures have no pixels to read).
const TEX_TONE := {"metal": Color(0.62, 0.63, 0.66), "planks_dark": Color(0.33, 0.23, 0.15), "planks": Color(0.56, 0.4, 0.25),
	"fabric": Color(0.75, 0.72, 0.68), "leather": Color(0.5, 0.36, 0.24), "bark": Color(0.45, 0.35, 0.25)}
const ICON := 24


static func icon(model: String) -> Texture2D:
	if _icons.has(model):
		return _icons[model]
	var tex := mesh_icon(build(model))
	_icons[model] = tex
	return tex


## Any mesh as an icon: turned by `view`, seen from +X (down -X, right = -Z), the picture turned by `turn`.
static func mesh_icon(mesh: ArrayMesh, view := Basis(), turn := -PI * 0.25) -> ImageTexture:
	var tris: Array = []
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	var rot := Transform2D(turn, Vector2.ZERO)
	for s in range(mesh.get_surface_count()):
		var arr := mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var norms: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
		var col := _tone(mesh.surface_get_material(s))
		for i in range(0, verts.size() - 2, 3):
			var pts: Array = []
			var depth := 0.0
			for j in range(3):
				var v: Vector3 = view * verts[i + j]
				var q: Vector2 = rot * Vector2(-v.z, -v.y)
				pts.append(q)
				depth += v.x / 3.0
				lo = Vector2(minf(lo.x, q.x), minf(lo.y, q.y))
				hi = Vector2(maxf(hi.x, q.x), maxf(hi.y, q.y))
			var nv: Vector3 = view * norms[i]
			var shade := 0.55 + 0.45 * absf(nv.x) + 0.15 * nv.y
			tris.append([pts, col * shade, depth])
	tris.sort_custom(func(a, b): return float(a[2]) < float(b[2]))
	var span := maxf(hi.x - lo.x, hi.y - lo.y)
	var k := (ICON - 3.0) / maxf(span, 0.001)
	var off := Vector2(ICON, ICON) * 0.5 - (lo + hi) * 0.5 * k
	var img := Image.create(ICON, ICON, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for t in tris:
		var a: Vector2 = t[0][0] * k + off
		var b: Vector2 = t[0][1] * k + off
		var c: Vector2 = t[0][2] * k + off
		var col: Color = t[1]
		col.a = 1.0
		var x0 := clampi(int(floor(minf(a.x, minf(b.x, c.x)))), 0, ICON - 1)
		var x1 := clampi(int(ceil(maxf(a.x, maxf(b.x, c.x)))), 0, ICON - 1)
		var y0 := clampi(int(floor(minf(a.y, minf(b.y, c.y)))), 0, ICON - 1)
		var y1 := clampi(int(ceil(maxf(a.y, maxf(b.y, c.y)))), 0, ICON - 1)
		var any := false
		for y in range(y0, y1 + 1):
			for x in range(x0, x1 + 1):
				if Geometry2D.point_is_inside_triangle(Vector2(x + 0.5, y + 0.5), a, b, c):
					img.set_pixel(x, y, col)
					any = true
		# (thin parts - a rapier's blade - still get their pixel)
		if not any:
			var m := (a + b + c) / 3.0
			img.set_pixel(clampi(int(m.x), 0, ICON - 1), clampi(int(m.y), 0, ICON - 1), col)
	# a dark outline, like the painted icons
	var out := img.duplicate() as Image
	for y in range(ICON):
		for x in range(ICON):
			if img.get_pixel(x, y).a > 0.0:
				continue
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var n: Vector2i = Vector2i(x, y) + d
				if n.x >= 0 and n.y >= 0 and n.x < ICON and n.y < ICON and img.get_pixel(n.x, n.y).a > 0.0:
					out.set_pixel(x, y, Color(0.08, 0.055, 0.04))
					break
	return ImageTexture.create_from_image(out)


static func _tone(mat: Material) -> Color:
	var sm := mat as ShaderMaterial
	var tint: Color = sm.get_shader_parameter("albedo_color")
	var em = sm.get_shader_parameter("emission_color")
	if em != null and float(sm.get_shader_parameter("emission_energy")) > 0.0:
		return (em as Color).lightened(0.2)
	var tex = sm.get_shader_parameter("albedo_tex")
	var tone: Color = TEX_TONE.get((tex as Texture2D).resource_path.get_file().get_basename(), Color(0.6, 0.6, 0.6)) if tex else Color.WHITE
	return Color(tone.r * tint.r, tone.g * tint.g, tone.b * tint.b)
