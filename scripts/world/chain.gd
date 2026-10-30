class_name Chain
extends RefCounted
## The chain of islands past Brinehollow (docs/island_chain_plan.md), made
## from the game's chain seed: the same on every screen and every load.
##
## A sea is SEA_LAYERS layers sailed in order. Layers 3 and 6 are cities, the
## last is the sea boss's island; the pairs between them (1-2, 4-5, 7-8) are
## either one island after another or a fork: two islands side by side, each
## leading on to its own next one, both rejoining at the city after them.
## Node -1 is Brinehollow's sea (where the log pose is first set).

const SEA_LAYERS := 9
const CITY_LAYERS := [3, 6]
const FORK_CHANCE := 0.6
## Brinehollow to the first island, then layer to layer (m, along the line).
const FIRST_LEG := [1900.0, 2300.0]
const LEG := [1100.0, 2600.0]
## A fork's islands sit this far either side of the line (m).
const FORK_SPREAD := [520.0, 820.0]
const WOBBLE := 260.0
## The line turns this much at most from one layer to the next (rad).
const BEND := 0.22
## Every island stays this far from Brinehollow (m): the line turns to keep
## inside the ring, wandering round it instead of heading off (the islands
## behind are gone anyway, and 7.5 km out floats are still about 1 mm fine).
const RING := [2000.0, 7500.0]
## A layer's islands keep this far from the layer before's (m).
const APART := 1150.0
## The island radius the legs, forks and APART are sized for (the jungle's top end): a theme whose islands
## reach further (ThemeDef.radius) pushes its fork partner and the next layer out by the difference.
const BASE_R := 450.0
## (1.27) The stronghold off the chain: how far out to the side of the canal city's layer, and its clearance from every
## island; its names (one per chain, from the chain seed).
const STRONGHOLD_OFF := [1400.0, 2000.0]
const STRONGHOLD_CLEAR := 1100.0
const STRONGHOLD_ID := 1000
const STRONGHOLD_NAMES := ["Gallowmere Bastion", "Saltmarch Citadel", "Ironveil Hold", "Graveshoal Keep", "Bellweather Fort",
	"Coldharrow Bastion", "Thornwick Battery", "Saint Odran's Rock"]

## (the themes, their names and blurbs are the registry's: IslandThemes, in its declared order)
const ISLE_WORDS := ["Isle", "Island", "Key", "Atoll", "Rock"]
const CITY_WORDS := ["Port", "Harbour", "Haven"]
## The first city is the royal capital (docs/capital_plan.md: CapitalIsland, the same in every world): every path
## reaches it after exactly two islands (layers 1-2 are one after another or a fork that rejoins there). Its
## name is rolled from the chain seed apart from the chain's own stream, so the rest of the chain is unchanged.
const CAPITAL_NAMES := ["Port Solenne", "Highcrown", "Meridian"]
## The second city is the canal city (docs/v1_21_plan.md: CanalIsland, the same in every world), its name rolled too.
const CANAL_NAMES := ["Saltmere", "Lantern Reach", "Brackwater"]

var seed_value: int
## Index = node id: {id, sea, layer, branch, theme, role, level, seed, pos, name, next}
var nodes: Array = []
## (1.27) The Admiralty's stronghold, off the chain: not one of `nodes` (nothing that walks the chain sees it), its id
## STRONGHOLD_ID; {} in a chain without one.
var stronghold: Dictionary = {}
## Where Brinehollow's sea leads (the first layer's ids).
var start_next: Array = []


static func make(chain_seed: int, origin: Vector2, heading: Vector2) -> Chain:
	var c := Chain.new()
	c.seed_value = chain_seed
	c._build(origin, heading.normalized())
	return c


func node(id: int) -> Dictionary:
	if id == STRONGHOLD_ID:
		return stronghold
	return nodes[id]


## The ids the log pose can point to from `id` (-1 = Brinehollow's sea).
func next_of(id: int) -> Array:
	if id < 0:
		return start_next
	return nodes[id]["next"]


func _build(origin: Vector2, heading: Vector2) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var dir := heading
	var at := origin
	var prev: Array = []      # the previous layer's ids
	var prev_theme := {}      # branch -> theme of the island before it
	var forked := false
	for layer in range(1, SEA_LAYERS + 1):
		var leg := rng.randf_range(FIRST_LEG[0], FIRST_LEG[1]) if layer == 1 else rng.randf_range(LEG[0], LEG[1])
		dir = dir.rotated(rng.randf_range(-BEND, BEND))
		var role := "regular"
		if layer in CITY_LAYERS:
			role = "city"
		elif layer == SEA_LAYERS:
			role = "sea_boss"
		# a fork opens on the first layer after a city (or the start) and holds for the pair
		var pair_start := layer == 1 or (layer - 1) in CITY_LAYERS
		if pair_start:
			forked = role == "regular" and rng.randf() < FORK_CHANCE
		var two := forked and role == "regular"
		var offs: Array = []
		for b in range(2 if two else 1):
			if two:
				offs.append(rng.randf_range(FORK_SPREAD[0], FORK_SPREAD[1]) * (-1.0 if b == 0 else 1.0))
			else:
				offs.append(rng.randf_range(-WOBBLE, WOBBLE))
		if layer > 1:
			dir = _steer(at, origin, dir, leg, offs, prev.map(func(pid): return nodes[pid]["pos"]))
		at += dir * leg
		var side := Vector2(-dir.y, dir.x)
		var ids: Array = []
		var used: Array = []
		for b in range(offs.size()):
			var off: float = offs[b]
			var avoid: Array = [prev_theme.get(b, ""), prev_theme.get(0, "")] + used
			var theme := _pick_theme(rng, avoid)
			if role == "regular" and layer > 1:
				theme = _apart(layer, b, avoid, theme)
			used.append(theme)
			var n := {
				"id": nodes.size(), "sea": 1, "layer": layer, "branch": b, "theme": theme, "role": role,
				"level": 4 + layer * 2 + rng.randi_range(0, 1), "seed": rng.randi(),
				"pos": at + side * off, "next": [],
			}
			n["name"] = _name(rng, n)
			# (the chain's own seed: what an island's arc roll is keyed by, IslandArcs.pick)
			n["chain"] = seed_value
			if layer == CITY_LAYERS[0]:
				n["capital"] = true
				n["name"] = capital_name(seed_value)
			elif layer == CITY_LAYERS[1]:
				n["canal"] = true
				n["name"] = canal_name(seed_value)
			nodes.append(n)
			ids.append(n["id"])
		at = _make_room(ids, prev, at, dir, side)
		# (the cities' harbours face the way the crew comes in: the islands before them)
		if layer in CITY_LAYERS:
			var from := Vector2.ZERO
			for pid in prev:
				from += nodes[pid]["pos"] / prev.size()
			nodes[ids[0]]["face"] = (from - nodes[ids[0]]["pos"]).normalized()
		# link the layer before to this one: branch to branch, everything into a single island
		if prev.is_empty():
			start_next = ids.duplicate()
		for pid in prev:
			var p: Dictionary = nodes[pid]
			if ids.size() == 1:
				p["next"] = [ids[0]]
			elif prev.size() == 1:
				p["next"] = ids.duplicate()
			else:
				p["next"] = [ids[int(p["branch"])]]
		prev_theme = {}
		for id in ids:
			prev_theme[int(nodes[id]["branch"])] = nodes[id]["theme"]
		prev = ids
	KitSetPieces.assign(self)
	BeastPool.assign(self)
	_add_stronghold()


## (1.27) The Admiralty's stronghold: an island off the chain (docs/v1_27_raids_fruits_plan.md), added after every
## other roll from its own stream, so no island before it changes. Out to the side of the route by the canal city's
## layer, clear of every island; nothing's "next" leads to it and it leads nowhere: optional, missable, found by
## sailing near it or hearing of it (stronghold_known).
func _add_stronghold() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_value, "stronghold"])
	var canal: Dictionary = {}
	for n in nodes:
		if n.get("canal", false):
			canal = n
	if canal.is_empty():
		return
	var face: Vector2 = canal.get("face", Vector2(0, 1))
	var side := Vector2(-face.y, face.x) * (1.0 if rng.randf() < 0.5 else -1.0)
	var at: Vector2 = canal["pos"] + side * rng.randf_range(STRONGHOLD_OFF[0], STRONGHOLD_OFF[1]) - face * rng.randf_range(-600.0, 600.0)
	# (pushed further out until it's clear of every island)
	for _i in range(40):
		var near := nodes.any(func(o): return (o["pos"] as Vector2).distance_to(at) < STRONGHOLD_CLEAR)
		if not near:
			break
		at += side * 150.0
	var n := {
		"id": STRONGHOLD_ID, "sea": 1, "layer": int(canal["layer"]), "branch": 9, "theme": canal["theme"], "role": "stronghold",
		"level": int(canal["level"]) + 4, "seed": rng.randi(), "pos": at, "next": [], "stronghold": true,
		"face": (at - (canal["pos"] as Vector2)).normalized(), "chain": seed_value, "base": "", "name": stronghold_name(seed_value),
	}
	stronghold = n


## The stronghold's node id (STRONGHOLD_ID), or -1.
func stronghold_id() -> int:
	return -1 if stronghold.is_empty() else STRONGHOLD_ID


static func stronghold_name(chain_seed: int) -> String:
	return STRONGHOLD_NAMES[posmod(hash([chain_seed, "stronghold"]), STRONGHOLD_NAMES.size())]


## The crew has heard of (or found) the stronghold: on the chart from now on, for everyone (a world flag).
static func learn_stronghold(tree: SceneTree, _how: String) -> void:
	var gm := tree.root.get_node_or_null("/root/GameManager")
	if gm and not gm.world_flags.has("stronghold_known"):
		tree.root.get_node("/root/Net").world_flag("stronghold_known")


static func stronghold_known(tree: SceneTree) -> bool:
	var gm := tree.root.get_node_or_null("/root/GameManager")
	return gm != null and gm.world_flags.has("stronghold_known")


## `dir` turned as little as it takes for a leg from `at` to end inside RING with
## the layer's islands (`offs` either side) all APART from the layer before's
## (or, if no turn manages both, the in-ring one that keeps them furthest).
static func _steer(at: Vector2, origin: Vector2, dir: Vector2, leg: float, offs: Array, before: Array) -> Vector2:
	var best := dir
	var best_gap := -INF
	for i in range(43):
		var d := dir.rotated(0.15 * float((i + 1) / 2) * (1.0 if i % 2 == 1 else -1.0))
		var p := at + d * leg
		var r := p.distance_to(origin)
		if r < RING[0] or r > RING[1]:
			continue
		var side := Vector2(-d.y, d.x)
		var gap := INF
		for o in offs:
			for q in before:
				gap = minf(gap, (p + side * float(o)).distance_to(q))
		if gap >= APART:
			return d
		if gap > best_gap:
			best_gap = gap
			best = d
	return best


## Room for islands bigger than BASE_R (no rng: a chain of BASE_R themes is untouched): a fork's two pushed
## apart sideways by their excess, then the layer pushed on along `dir` until each island keeps APART plus
## both excesses from the layer before's. Returns the line's point, moved with the layer.
func _make_room(ids: Array, prev: Array, at: Vector2, dir: Vector2, side: Vector2) -> Vector2:
	if ids.size() == 2:
		for b in range(2):
			nodes[ids[b]]["pos"] += side * _excess(nodes[ids[b]]) * (-1.0 if b == 0 else 1.0)
	var push := 0.0
	for id in ids:
		for pid in prev:
			var extra := _excess(nodes[id]) + _excess(nodes[pid])
			if extra > 0.0:
				var a: Vector2 = nodes[pid]["pos"]
				var q: Vector2 = nodes[id]["pos"]
				var need := APART + extra
				var along := (q - a).dot(dir)
				var across := (q - a).length_squared() - along * along
				if across < need * need:
					push = maxf(push, sqrt(need * need - across) - along)
	if push > 0.0:
		for id in ids:
			nodes[id]["pos"] += dir * push
	return at + dir * push


static func _excess(n: Dictionary) -> float:
	return maxf(float(IslandThemes.of(n["theme"]).radius[1]) - BASE_R, 0.0)


## A registered theme by its weight (ThemeDef.weight), the ones to avoid left out unless
## that leaves none; one draw whatever the themes, so the stream is the same as with one.
func _pick_theme(rng: RandomNumberGenerator, avoid: Array) -> String:
	var ready: Array = IslandThemes.all().filter(func(t): return not t.apart)
	var pool: Array = ready.filter(func(t): return not avoid.has(t.name))
	if pool.is_empty():
		pool = ready
	var total := 0.0
	for t in pool:
		total += float(t.weight)
	var roll := float(rng.randi()) / 4294967296.0 * total
	for t in pool:
		roll -= float(t.weight)
		if roll < 0.0:
			return t.name
	return pool[-1].name



## A theme rolled apart from the draw (ThemeDef.apart) taking this island instead, by its own chance from a hash (no
## draw on the chain's stream: every other island stays as it was); `theme` (the draw's) when none does.
func _apart(layer: int, branch: int, avoid: Array, theme: String) -> String:
	for t in IslandThemes.all():
		if not t.apart or avoid.has(t.name):
			continue
		var roll := float(hash([seed_value, layer, branch, t.name]) & 0xffffff) / 16777216.0
		if roll < float(t.weight):
			return t.name
	return theme

## (a name not given yet in this sea; once a theme's run out, one not on the
## islands of this layer or the two before, so a fork's two never match)
func _name(rng: RandomNumberGenerator, n: Dictionary) -> String:
	var names: Array = IslandThemes.of(n["theme"]).island_names
	var given := {}
	var near := {}
	var same_layer := {}
	for o in nodes:
		given[o["base"]] = true
		if int(o["layer"]) == int(n["layer"]):
			same_layer[o["base"]] = true
		if int(o["layer"]) >= int(n["layer"]) - 2:
			near[o["base"]] = true
	var pool: Array = names.filter(func(b): return not given.has(b))
	if pool.is_empty():
		pool = names.filter(func(b): return not near.has(b))
	if pool.is_empty():
		pool = names.filter(func(b): return not same_layer.has(b))
	if pool.is_empty():
		pool = names
	var base: String = pool[rng.randi() % pool.size()]
	n["base"] = base
	if n["role"] == "city":
		var w: String = CITY_WORDS[rng.randi() % CITY_WORDS.size()]
		return "Port " + base if w == "Port" else "%s %s" % [base, w]
	return "%s %s" % [base, ISLE_WORDS[rng.randi() % ISLE_WORDS.size()]]


static func capital_name(chain_seed: int) -> String:
	return CAPITAL_NAMES[posmod(hash([chain_seed, "capital"]), CAPITAL_NAMES.size())]


static func canal_name(chain_seed: int) -> String:
	return CANAL_NAMES[posmod(hash([chain_seed, "canal"]), CANAL_NAMES.size())]


## The royal capital's node id.
func capital_id() -> int:
	for n in nodes:
		if n.get("capital", false):
			return int(n["id"])
	push_error("Chain %d has no capital" % seed_value)
	return -1


## What the log pose tells of an island (its theme and how dangerous).
static func describe(n: Dictionary) -> String:
	if n.get("capital", false):
		return "The royal capital  Lv %d" % int(n["level"])
	if n.get("canal", false):
		return "The canal city  Lv %d" % int(n["level"])
	if n.get("stronghold", false):
		return "The Admiralty's stronghold  Lv %d" % int(n["level"])
	var kind: String = IslandThemes.of(n["theme"]).display
	match str(n["role"]):
		"city":
			kind += " city"
		"sea_boss":
			kind += " - the sea's end"
	return "%s  Lv %d" % [kind, int(n["level"])]
