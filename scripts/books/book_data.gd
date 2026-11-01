class_name BookData
extends RefCounted
## The books (1.28, docs/life_systems_plan.md "Books"): every book, what reading it teaches, where it's found. Data and
## the items only (ItemDB names this class before the autoloads exist: nothing here may name one); reading, the shelf
## and the sources are Books'.
##   kind "blueprint": "teaches" a blueprint id (Gadgets.teach)
##   kind "recipe":    "teaches" a meal id (Food.teach)
##   kind "manual":    "perk" {Progression.stat key: amount}, for good
##   kind "chart":     "marks" "stops" / "king" / "wrecks" on the legs ahead (MapMarks), read again to mark again
##   kind "lore":      "set" id: one volume of LORE_SETS[set]; the set's reward on the last one

## id -> name, kind, rarity (ItemData.Rarity), what it teaches, a line.
const BOOKS := {
	"book_pepper": {"name": "The Spice Merchant's Revenge", "kind": "blueprint", "rarity": 1, "teaches": "bp_pepper",
		"desc": "A merchant's memoir with a recipe in the back that isn't for eating."},
	"book_spike": {"name": "Cliffs and How to Cheat Them", "kind": "blueprint", "rarity": 1, "teaches": "bp_spike",
		"desc": "A climber's notes. Most of the chapters are about falling."},
	"book_helmet": {"name": "Breathing Under the Sea", "kind": "blueprint", "rarity": 2, "teaches": "bp_diving_helmet",
		"desc": "A practical guide, with diagrams, by someone who clearly drowned a few times."},
	"book_reel": {"name": "The Lazy Angler's Workshop", "kind": "blueprint", "rarity": 1, "teaches": "bp_auto_reel",
		"desc": "Why reel a fish in yourself when a spring will do it?"},
	"book_glider": {"name": "On Wings of Canvas", "kind": "blueprint", "rarity": 2, "teaches": "bp_glider",
		"desc": "Gull wings, kite frames and one very brave cabin boy."},
	"book_decoy": {"name": "The Straw Captain", "kind": "blueprint", "rarity": 2, "teaches": "bp_decoy",
		"desc": "How a crew of three held a fort against forty with a scarecrow and a hat."},
	"book_feast": {"name": "Galley Secrets of the Southern Isles", "kind": "recipe", "rarity": 1, "teaches": "captains_feast",
		"desc": "Grease-spotted and dog-eared at one page in particular."},
	"book_roast": {"name": "The Roasting Pit", "kind": "recipe", "rarity": 1, "teaches": "roast_feast",
		"desc": "A whole boar, a whole night and a whole crew to feed."},
	"book_atlas": {"name": "A Cook's Atlas", "kind": "recipe", "rarity": 2, "teaches": "isles_feast",
		"desc": "Every island's larder in one book, and the feast that uses them all."},
	"manual_footwork": {"name": "Deck Footwork", "kind": "manual", "rarity": 2, "perk": {"move_pct": 0.03, "sprint_pct": 0.03},
		"desc": "Drills for a rolling deck. Ashore you'll feel like you're flying."},
	"manual_grip": {"name": "The Iron Grip", "kind": "manual", "rarity": 2, "perk": {"damage_pct": 0.03},
		"desc": "Hold the hilt like a bird: tight enough it can't fly, loose enough it can breathe."},
	"manual_breath": {"name": "Pearl Diver's Breath", "kind": "manual", "rarity": 1, "perk": {"swim_pct": 0.08},
		"desc": "The pearl divers' way of moving through water: slow is fast."},
	"manual_galley": {"name": "The Ship's Cook's Companion", "kind": "manual", "rarity": 1, "perk": {"meal_time_pct": 0.15},
		"desc": "Salt, smoke and patience. A meal that keeps keeps you."},
	"manual_angler": {"name": "Notes of an Old Angler", "kind": "manual", "rarity": 1, "perk": {"fish_bite_pct": 0.1, "fish_reel_pct": 0.1},
		"desc": "Forty years of fishing in a hand that shakes less on the page than it did on the line."},
	"manual_guard": {"name": "Turning the Blade", "kind": "manual", "rarity": 2, "perk": {"defense": 2.0},
		"desc": "Don't stop a cut. Send it somewhere else."},
	"manual_wind": {"name": "Second Wind", "kind": "manual", "rarity": 1, "perk": {"max_stamina": 10.0},
		"desc": "Breathe out longer than you breathe in. Then run."},
	"chart_stops": {"name": "A Trader's Sea Chart", "kind": "chart", "rarity": 1, "marks": "stops",
		"desc": "Where the ships that don't sail between islands are found, more or less."},
	"chart_king": {"name": "The Whaler's Chart", "kind": "chart", "rarity": 2, "marks": "king",
		"desc": "Waters to avoid, inked in red by a whaler who didn't."},
	"chart_wrecks": {"name": "The Salvager's Chart", "kind": "chart", "rarity": 1, "marks": "wrecks",
		"desc": "Every wreck worth diving, and a few that weren't."},
	"lore_king_1": {"name": "The Drowned King, I", "kind": "lore", "rarity": 2, "set": "drowned_king",
		"desc": "A king who wanted the sea. The first volume: he gets it."},
	"lore_king_2": {"name": "The Drowned King, II", "kind": "lore", "rarity": 2, "set": "drowned_king",
		"desc": "His court under the waves, and the bargain that built it."},
	"lore_king_3": {"name": "The Drowned King, III", "kind": "lore", "rarity": 2, "set": "drowned_king",
		"desc": "The captains he took, and why they stayed."},
	"lore_king_4": {"name": "The Drowned King, IV", "kind": "lore", "rarity": 2, "set": "drowned_king",
		"desc": "How it ends. Or doesn't."},
	"lore_orla_1": {"name": "Voyages of Captain Orla, I", "kind": "lore", "rarity": 1, "set": "orla",
		"desc": "A cook who became a captain because nobody else could keep a crew fed."},
	"lore_orla_2": {"name": "Voyages of Captain Orla, II", "kind": "lore", "rarity": 1, "set": "orla",
		"desc": "Orla's crew crosses the chain, one island's larder at a time."},
	"lore_orla_3": {"name": "Voyages of Captain Orla, III", "kind": "lore", "rarity": 1, "set": "orla",
		"desc": "The last feast, and the recipe she left for whoever read this far."},
	"lore_deep_1": {"name": "A Bestiary of the Deep, I", "kind": "lore", "rarity": 1, "set": "deep",
		"desc": "Fish of the shallows, drawn true. The ink still smells of salt."},
	"lore_deep_2": {"name": "A Bestiary of the Deep, II", "kind": "lore", "rarity": 1, "set": "deep",
		"desc": "The open sea, and what follows ships."},
	"lore_deep_3": {"name": "A Bestiary of the Deep, III", "kind": "lore", "rarity": 1, "set": "deep",
		"desc": "Below the light. The author's hand gets shakier."},
}
## The lore sets: name, volumes in order, the reward for reading them all ("will": Will points, "gold", "recipe",
## "perk": {stat key: amount} for good), and the reward said.
const LORE_SETS := {
	"drowned_king": {"name": "The Drowned King", "books": ["lore_king_1", "lore_king_2", "lore_king_3", "lore_king_4"],
		"reward": {"will": 1}, "said": "a Will point"},
	"orla": {"name": "Voyages of Captain Orla", "books": ["lore_orla_1", "lore_orla_2", "lore_orla_3"],
		"reward": {"gold": 400, "recipe": "isles_feast"}, "said": "400 gold and the Feast of the Isles"},
	"deep": {"name": "A Bestiary of the Deep", "books": ["lore_deep_1", "lore_deep_2", "lore_deep_3"],
		"reward": {"perk": {"fish_rare_pct": 0.15}}, "said": "+15% rare fish, for good"},
}
## The shelf's rows and each kind's cover colour.
const KINDS := ["blueprint", "recipe", "manual", "chart", "lore"]
const KIND_NAMES := {"blueprint": "Blueprints", "recipe": "Recipes", "manual": "Technique manuals", "chart": "Sea charts", "lore": "Lore"}
const COVERS := {"blueprint": Color(0.2, 0.32, 0.55), "recipe": Color(0.62, 0.32, 0.14), "manual": Color(0.5, 0.12, 0.12),
	"chart": Color(0.22, 0.42, 0.3), "lore": Color(0.32, 0.2, 0.38)}
## Worth (G) by kind, before the rarity's curve.
const VALUE := {"blueprint": 50, "recipe": 40, "manual": 70, "chart": 60, "lore": 30}
## Reading a chart with nothing left to mark ahead: experience instead.
const CHART_XP := 20
## How many layers ahead of the island you're at a chart looks.
const CHART_DEPTH := 2

## Sources (Books.chest_extras, the shops). Chests: the chance of a book by chest kind and the kinds each can hold.
const CHEST_BOOK := {"ordinary": 0.04, "hidden": 0.1, "hoard": 0.25}
const CHEST_KINDS := {"ordinary": ["recipe", "chart", "lore"], "hidden": ["recipe", "chart", "lore", "manual", "blueprint"],
	"hoard": ["recipe", "chart", "lore", "manual", "blueprint"]}
## A village's old library ("Browse the shelves"): LIBRARY_SIZE a day from these kinds.
const LIBRARY_KINDS := ["recipe", "manual", "chart", "lore"]
const LIBRARY_SIZE := 4
## The forge town's master tinkerer ("Any books?"): TINKER_SIZE a day.
const TINKER_POOL := ["book_pepper", "book_spike", "book_helmet", "book_reel", "book_glider", "book_decoy", "manual_wind", "manual_grip"]
const TINKER_SIZE := 3
## The wandering merchant ship (MerchantShip.book_pool: it shows 2 a visit).
const MERCHANT_KINDS := ["chart", "manual", "blueprint"]

static var _icons := {}


static func is_book(it: ItemData) -> bool:
	return it != null and BOOKS.has(it.id)


static func kind_of(id: String) -> String:
	return str(BOOKS[id]["kind"])


static func of_kinds(kinds: Array) -> Array:
	return BOOKS.keys().filter(func(id): return BOOKS[id]["kind"] in kinds)


## (ItemDB._load_all) every book as an item.
static func make_items(items: Dictionary) -> void:
	for id in BOOKS.keys():
		var b: Dictionary = BOOKS[id]
		var it := ItemData.new()
		it.id = id
		it.display_name = str(b["name"])
		it.description = str(b["desc"])
		it.rarity = int(b["rarity"]) as ItemData.Rarity
		it.value = int(VALUE[b["kind"]])
		it.item_type = ItemData.ItemType.LOOT
		it.max_stack = 5
		it.icon_kind = "book"
		it.icon = icon(str(b["kind"]))
		items[id] = it


## A book's icon by kind (its cover colour).
static func icon(kind: String) -> Texture2D:
	if not _icons.has(kind):
		_icons[kind] = WeaponDesigns.mesh_icon(BookModels.book(COVERS[kind], kind == "chart"), Basis(Vector3.RIGHT, -0.5), -0.5)
	return _icons[kind]
