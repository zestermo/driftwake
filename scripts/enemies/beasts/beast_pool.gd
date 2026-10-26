class_name BeastPool
extends RefCounted
## Which beasts an island of the chain gets, seeded from the chain so every
## screen agrees: its boss (BeastArena), its minibosses (at POIs) and the beast
## roaming its floor. assign() writes them into each chain node ("beast",
## "beast_look", "minis", "roamer") once the chain is built.
##
## The kinds are the theme's (ThemeDef: bosses, minis, roamers, and each kind's
## script, names, looks and site in `beasts`, read here with info()).
##
## Pool rules: a boss is never one the island before it had on any route
## (walking back through the chain's links), nor its fork's other side's; past
## that it's an even seeded pick. A variant ("beast_look": skin, name) is rolled
## with it, so two islands with the same beast still differ.

const SALT := 70411
## The share of islands (past a chain's first) with no roaming beast.
const ROAMER_NONE := 0.5


## A theme's beast kind: {"script", "names", a boss's "looks", a mini's "site", maybe "stock"}.
static func info(theme: String, kind: String) -> Dictionary:
	return IslandThemes.of(theme).beasts[kind]


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
		var theme: ThemeDef = IslandThemes.of(str(n["theme"]))
		var pool: Array = theme.bosses
		var before := _before(chain, prevs, int(n["id"]), str(n["theme"]))
		var avoid := before.duplicate()
		for o in chain.nodes:
			if int(o["layer"]) == int(n["layer"]) and o.has("beast") and str(o["theme"]) == str(n["theme"]):
				avoid.append(o["beast"])
		# (a pool of one can't help repeating)
		var left: Array = pool.filter(func(k): return not avoid.has(k)) if pool.size() > 1 else pool
		# (a small pool with its layer's neighbours taken: only the islands before are kept from repeating)
		if left.is_empty():
			left = pool.filter(func(k): return not before.has(k))
		if left.is_empty():
			left = pool
		var kind: String = left[rng.randi() % left.size()]
		var b: Dictionary = theme.beasts[kind]
		n["beast"] = kind
		n["beast_look"] = rng.randi() % int(b["looks"])
		n["beast_name"] = b["names"][rng.randi() % (b["names"] as Array).size()]
		var minis: Array = theme.minis.duplicate()
		var keep := 1 + rng.randi() % minis.size()
		var picked: Array = []
		while picked.size() < keep:
			picked.append(minis.pop_at(rng.randi() % minis.size()))
		n["minis"] = picked
		var roam: Array = theme.roamers
		n["roamer"] = roam[rng.randi() % roam.size()]
		# (1.23: fewer roamers, a rarer event: half the islands have none ("" here), but a chain's first islands, where
		# it's met first; its own roll, so the picks above stay as they were)
		var coin := RandomNumberGenerator.new()
		coin.seed = hash([chain.seed_value, int(n["id"]), "roamer"])
		if not chain.start_next.has(n["id"]) and coin.randf() < ROAMER_NONE:
			n["roamer"] = ""


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
		var site: String = info(isl.theme, m)["site"]
		var at: Vector2 = isl.sites[site]
		out.append({"kind": "miniboss", "beast": m, "name": mini_name(isl, m), "at": at,
			"pos": isl.to_global(Vector3(at.x, isl.hv(at), at.y)), "radius": 22.0})
	if str(n["roamer"]) == "":
		return out
	var home: Vector2 = roam_home(isl)
	out.append({"kind": "roamer", "beast": n["roamer"], "name": roamer_name(isl), "at": home,
		"pos": isl.to_global(Vector3(home.x, isl.hv(home), home.y)), "radius": ROAM_R})
	return out


const ROAM_R := 140.0


## A miniboss's name on this island, from the island's seed.
static func mini_name(isl: GenIsland, kind: String) -> String:
	var names: Array = info(isl.theme, kind)["names"]
	return names[absi(int(isl.node["seed"])) % names.size()]


static func roamer_name(isl: GenIsland) -> String:
	var names: Array = info(isl.theme, str(isl.node["roamer"]))["names"]
	return names[absi(int(isl.node["seed"]) / 13) % names.size()]


## The middle of the roamer's range: between the island's middle and its boss, off the paths.
static func roam_home(isl: GenIsland) -> Vector2:
	return (isl.sites["boss"] as Vector2) * 0.35 + (isl.sites["summit"] as Vector2) * 0.15


## The roaming beast, wherever it is now (null before it's built or once it's dead).
static func roamer_of(isl: GenIsland) -> Node3D:
	var r := isl.get_node_or_null("Roamer") as Node3D
	if r == null or (r.has_method("is_dead") and r.is_dead()):
		return null
	return r


## The bodies prepare builds ahead for this island's beasts (Humanoid.stock): the boss's, if its kind stocks one.
static func stock_looks(n: Dictionary) -> Array:
	var b := info(str(n["theme"]), str(n["beast"]))
	return [(b["stock"] as Callable).call()] if b.has("stock") else []
