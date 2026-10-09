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

const THEMES := {
	"jungle": {"name": "Jungle", "blurb": "a steaming jungle isle",
		"names": ["Verdant", "Kalani", "Mosswater", "Tambor", "Orchid", "Viper", "Greenmaw", "Tikal"]},
	"snow": {"name": "Snow", "blurb": "an island under ice and snow",
		"names": ["Frosthelm", "Rimeholt", "Whitecap", "Glacia", "Icefang", "Winterhold", "Hoarfell", "Snowmere"]},
	"desert": {"name": "Desert", "blurb": "a sun-baked desert island",
		"names": ["Sunscar", "Dunmara", "Saffra", "Ashbar", "Mirage", "Scorpa", "Dustwell", "Qadir"]},
	"forest": {"name": "Forest", "blurb": "an island of deep green woods",
		"names": ["Elderwood", "Oakhollow", "Fernreach", "Mistvale", "Thornby", "Larchmoor", "Bramble", "Woodhaven"]},
}
const FIRST_SEA_THEMES := ["jungle", "snow", "desert", "forest"]
const ISLE_WORDS := ["Isle", "Island", "Key", "Atoll", "Rock"]
const CITY_WORDS := ["Port", "Harbour", "Haven"]

var seed_value: int
## Index = node id: {id, sea, layer, branch, theme, role, level, seed, pos, name, next}
var nodes: Array = []
## Where Brinehollow's sea leads (the first layer's ids).
var start_next: Array = []


static func make(chain_seed: int, origin: Vector2, heading: Vector2) -> Chain:
	var c := Chain.new()
	c.seed_value = chain_seed
	c._build(origin, heading.normalized())
	return c


func node(id: int) -> Dictionary:
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
		at += dir * leg
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
		var side := Vector2(-dir.y, dir.x)
		var ids: Array = []
		var used: Array = []
		for b in range(2 if two else 1):
			var off := 0.0
			if two:
				off = rng.randf_range(FORK_SPREAD[0], FORK_SPREAD[1]) * (-1.0 if b == 0 else 1.0)
			else:
				off = rng.randf_range(-WOBBLE, WOBBLE)
			var theme := _pick_theme(rng, [prev_theme.get(b, ""), prev_theme.get(0, "")] + used)
			used.append(theme)
			var n := {
				"id": nodes.size(), "sea": 1, "layer": layer, "branch": b, "theme": theme, "role": role,
				"level": 10 + layer * 2 + rng.randi_range(0, 1), "seed": rng.randi(),
				"pos": at + side * off, "next": [],
			}
			n["name"] = _name(rng, n)
			nodes.append(n)
			ids.append(n["id"])
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


## (only themes IslandTheme can build; the rest join as they're made)
func _pick_theme(rng: RandomNumberGenerator, avoid: Array) -> String:
	var ready: Array = FIRST_SEA_THEMES.filter(func(t): return IslandTheme.has(t))
	var pool: Array = ready.filter(func(t): return not avoid.has(t))
	if pool.is_empty():
		pool = ready
	return pool[rng.randi() % pool.size()]


func _name(rng: RandomNumberGenerator, n: Dictionary) -> String:
	var names: Array = THEMES[n["theme"]]["names"]
	var base: String = names[rng.randi() % names.size()]
	if n["role"] == "city":
		var w: String = CITY_WORDS[rng.randi() % CITY_WORDS.size()]
		return "Port " + base if w == "Port" else "%s %s" % [base, w]
	return "%s %s" % [base, ISLE_WORDS[rng.randi() % ISLE_WORDS.size()]]


## What the log pose tells of an island (its theme and how dangerous).
static func describe(n: Dictionary) -> String:
	var kind: String = THEMES[n["theme"]]["name"]
	match str(n["role"]):
		"city":
			kind += " city"
		"sea_boss":
			kind += " - the sea's end"
	return "%s  Lv %d" % [kind, int(n["level"])]
