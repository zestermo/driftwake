class_name BeastPool
extends RefCounted
## Which beasts an island of the chain gets, seeded from the chain so every
## screen agrees: its boss (BeastArena), its minibosses (at POIs) and the beast
## roaming its floor. assign() writes them into each chain node ("beast",
## "beast_look", "minis", "roamer") once the chain is built.
##
## Pool rules: a boss is never one the island before it had on any route
## (walking back through the chain's links), nor its fork's other side's; past
## that it's an even seeded pick. A variant ("beast_look": skin, name) is rolled
## with it, so two islands with the same beast still differ.

## theme -> the bosses its islands roll from.
const POOLS := {
	"jungle": ["ape", "serpent", "stalker", "mantis"],
}
## kind -> its names (one is picked per island; the first is the plain one).
const NAMES := {
	"ape": ["The Silverback"],
	"serpent": ["The Strangler", "Old Coil", "Mother of Vines"],
	"stalker": ["The Shade", "Nightmaw", "The Spotted Death"],
	"mantis": ["The Mantis Queen", "The Orchid Queen", "The Leaf Queen"],
}
## How many looks each kind has (the variant index is < this).
const LOOKS := {"ape": 1, "serpent": 3, "stalker": 3, "mantis": 3}
## The beasts that aren't the ape (JungleBeast scripts).
const SCRIPTS := {
	"serpent": "res://scripts/enemies/beasts/strangler.gd",
	"stalker": "res://scripts/enemies/beasts/stalker.gd",
	"mantis": "res://scripts/enemies/beasts/mantis_queen.gd",
	"boar": "res://scripts/enemies/beasts/alpha_boar.gd",
	"behemoth": "res://scripts/enemies/beasts/behemoth.gd",
}
const MINIS := {"jungle": ["boar"]}
const ROAMERS := {"jungle": ["behemoth"]}
const SALT := 70411


## Every node of `chain` gets its beasts (called at the end of Chain._build).
static func assign(chain: Chain) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = chain.seed_value + SALT
	var prevs := {}
	for n in chain.nodes:
		for id in n["next"]:
			if not prevs.has(id):
				prevs[id] = []
			prevs[id].append(int(n["id"]))
	for n in chain.nodes:
		var pool: Array = POOLS[str(n["theme"])]
		var avoid := _before(chain, prevs, int(n["id"]), str(n["theme"]))
		for o in chain.nodes:
			if int(o["layer"]) == int(n["layer"]) and o.has("beast") and str(o["theme"]) == str(n["theme"]):
				avoid.append(o["beast"])
		# (a pool of one can't help repeating)
		var left: Array = pool.filter(func(k): return not avoid.has(k)) if pool.size() > 1 else pool
		var kind: String = left[rng.randi() % left.size()]
		n["beast"] = kind
		n["beast_look"] = rng.randi() % int(LOOKS[kind])
		n["beast_name"] = NAMES[kind][rng.randi() % (NAMES[kind] as Array).size()]
		var minis: Array = (MINIS[str(n["theme"])] as Array).duplicate()
		var keep := 1 + rng.randi() % minis.size()
		var picked: Array = []
		while picked.size() < keep:
			picked.append(minis.pop_at(rng.randi() % minis.size()))
		n["minis"] = picked
		var roam: Array = ROAMERS[str(n["theme"])]
		n["roamer"] = roam[rng.randi() % roam.size()]


## The bosses of the nearest islands of the same theme behind `id` on every route.
static func _before(chain: Chain, prevs: Dictionary, id: int, theme: String) -> Array:
	var out: Array = []
	var todo: Array = (prevs.get(id, []) as Array).duplicate()
	var seen := {}
	while not todo.is_empty():
		var q: int = todo.pop_back()
		if seen.has(q):
			continue
		seen[q] = true
		var o: Dictionary = chain.node(q)
		if str(o["theme"]) == theme:
			out.append(o["beast"])
		else:
			todo.append_array(prevs.get(q, []))
	return out


## Where an island's beasts are, for quests and markers ("hunt the roaming
## beast"): [{kind: "boss" | "miniboss" | "roamer", beast, name, at (island
## space), pos (world), radius}]. The roamer's is its range (its home and how
## far it wanders); find it live with roamer_of(isl).
static func pois(isl: GenIsland) -> Array:
	var n := isl.node
	var out: Array = []
	var c: Vector2 = isl.sites["boss"]
	out.append({"kind": "boss", "beast": n["beast"], "name": n["beast_name"], "at": c,
		"pos": isl.to_global(Vector3(c.x, isl.hv(c), c.y)), "radius": BeastArena.FLOOR_R})
	for m in n["minis"]:
		var site: String = MINI_SITES[m]
		var at: Vector2 = isl.sites[site]
		out.append({"kind": "miniboss", "beast": m, "name": mini_name(isl, m), "at": at,
			"pos": isl.to_global(Vector3(at.x, isl.hv(at), at.y)), "radius": 22.0})
	var home: Vector2 = roam_home(isl)
	out.append({"kind": "roamer", "beast": n["roamer"], "name": roamer_name(isl), "at": home,
		"pos": isl.to_global(Vector3(home.x, isl.hv(home), home.y)), "radius": ROAM_R})
	return out


## Where each miniboss keeps (a site of the island's).
const MINI_SITES := {"boar": "ruins", "warlord": "camp"}
const ROAM_R := 140.0
const BOAR_NAMES := ["Tuskmaw", "Old Gristle", "Mudking", "Ironbristle"]
const WARLORD_NAMES := ["Warlord", "Warchief", "Butcher"]
const ROAMER_NAMES := ["The Thornback", "Old Ironhide", "The Mossback"]


static func mini_name(isl: GenIsland, kind: String) -> String:
	var s := int(isl.node["seed"])
	match kind:
		"boar":
			return BOAR_NAMES[absi(s) % BOAR_NAMES.size()]
		"warlord":
			return WARLORD_NAMES[absi(s / 7) % WARLORD_NAMES.size()]
	return kind


static func roamer_name(isl: GenIsland) -> String:
	return ROAMER_NAMES[absi(int(isl.node["seed"]) / 13) % ROAMER_NAMES.size()]


## The middle of the roamer's range: between the island's middle and its boss, off the paths.
static func roam_home(isl: GenIsland) -> Vector2:
	return (isl.sites["boss"] as Vector2) * 0.35 + (isl.sites["summit"] as Vector2) * 0.15


## The roaming beast, wherever it is now (null before it's built or once it's dead).
static func roamer_of(isl: GenIsland) -> Node3D:
	var r := isl.get_node_or_null("Roamer") as Node3D
	if r == null or (r.has_method("is_dead") and r.is_dead()):
		return null
	return r


## The bodies prepare builds ahead for this island's beasts (Humanoid.stock).
static func stock_looks(n: Dictionary) -> Array:
	return [JungleApe.ape_look()] if str(n["beast"]) == "ape" else []
