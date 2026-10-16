class_name ThemeDef
extends RefCounted
## What one island theme provides: everything the game looks up by a theme's name. A theme is
## `scripts/island/themes/<theme>_theme.gd` extending this, filling every member in _init and
## overriding meshes(); IslandThemes registers it (its one line in IslandThemes.SCRIPTS) and
## refuses one that leaves a member unset (missing()), so a gap shows at start-up, not deep in
## an island build. The hubs read a theme only through IslandThemes: IslandTheme (land, meshes),
## KitStyle (style, props), LifePools (life), BeastPool (bosses, minis, roamers, beasts), Chain
## (display, blurb, island_names, weight), FaunaSpawner (fauna, creatures), ChainMarks (color,
## glyph), SkyBirds (flocks). Its models, plants, creatures and beasts live in their own files
## (scripts/props/<theme>_plants.gd, <theme>_props.gd, scripts/enemies/fauna/, scripts/enemies/beasts/).

## The chain's key for it ("jungle"): in chain nodes, saves, KitStyle.of, LifePools.of...
var name := ""
## What the log pose, the compass strip and the arrival banner call it ("Jungle") and say of it ("a steaming jungle isle").
var display := ""
var blurb := ""
## The names its islands are given (Chain._name: a sea never repeats one while the list lasts).
var island_names: Array = []
## Its share of the chain's islands against the other themes' (Chain._pick_theme; the jungle's 1.0).
var weight := 0.0
## The chart's and the compass strip's colour and little glyph: glyph(ci: CanvasItem, p: Vector2, s: float, col: Color)
## draws it about s px from its middle p to each edge.
var color := Color(0, 0, 0, 0)
var glyph := Callable()
## Parties of parrots hopping crown to crown over an island of 6+ crowns (SkyBirds; Brinehollow gets one). 0 = none.
var flocks := -1
## The land's shape and the plants on it (IslandTheme.def: peak, hills, roll, base, ramp, cliffs, the plant chances
## per grid cell, cover, canopy and giants, the floor layers, forests). Numbers only: GenIsland.prepare reads it on a worker.
var land := {}
## The settlement style (KitStyle.of merges it over KitStyle.BRINEHOLLOW: a key replaces the whole base key,
## so a nested table carries every sub-key; its "props" slots name models, "ambience" an Ambience.LOOPS key,
## "music" a Music.TRACKS key).
var style := {}
## The makers of the prop models its style's "props" slots name beyond KitStyle.BASE_PROPS (crate, barrel,
## lantern_post, notice_board): model -> Callable(rng: RandomNumberGenerator, size: float) -> Node3D; a lamp has a
## "Flame" Marker3D where its light goes. Model names are unique across themes (prefix them with the theme's).
var props := {}
## Its people's text (LifePools.of): first names, where, roles, barks, menus, rumours, quests, scout_at, lost_at,
## elder_about (the elder's two lines about the island).
var life := {}
## Its beasts (BeastPool): the bosses its islands roll from, the minibosses (1+ picked per island) and roamers (one),
## and every kind named there in `beasts`: {"script": the beast's script, "names": its names (the first the plain one;
## a boss's picked by the chain, a mini's and roamer's by the island's seed), a boss's "looks": how many variants,
## a mini's "site": the island site it keeps, optionally "stock": Callable() -> a look whose body prepare builds ahead}.
var bosses: Array = []
var minis: Array = []
var roamers: Array = []
var beasts := {}
## Its wildlife (FaunaSpawner): kind -> {"zones": where it lives (floor, shore, canopy, swamp, cave), "p": the chance
## an island has it, "dens": [lo, hi] groups when it does}, and each kind's Creature script.
var fauna := {}
var creatures := {}

## Every member above, for the check and the test: a new member goes here too.
const CONTRACT := ["name", "display", "blurb", "island_names", "weight", "color", "glyph", "flocks", "land", "style", "props",
	"life", "bosses", "minis", "roamers", "beasts", "fauna", "creatures"]


## The plant and rock meshes its islands are made of, built once per theme on the main thread before
## GenIsland.prepare (IslandTheme.meshes caches it; KitLandmarks.canopy reads their AABBs). The scatter
## reads: tree, beach_tree, bush, fern, grass, rock (lists of meshes), giant, fig, kapok, emergent, roof
## (lists of [body, detail, lean]), mangrove, bamboo, broadleaf, shrub.
func meshes() -> Dictionary:
	push_error("ThemeDef: theme %s has no meshes()" % name)
	assert(false)
	return {}


## What's unset or inconsistent, by member (IslandThemes refuses a theme that leaves anything).
func missing() -> Array:
	var out: Array = []
	for k in CONTRACT:
		var v = get(k)
		var bad := false
		match typeof(v):
			TYPE_STRING:
				bad = v == ""
			TYPE_ARRAY:
				bad = (v as Array).is_empty()
			TYPE_DICTIONARY:
				bad = (v as Dictionary).is_empty() and k != "props"
			TYPE_FLOAT:
				bad = v <= 0.0
			TYPE_INT:
				bad = v < 0
			TYPE_COLOR:
				bad = (v as Color).a <= 0.0
			TYPE_CALLABLE:
				bad = not (v as Callable).is_valid()
		if bad:
			out.append(k)
	for k in bosses:
		if not _beast_has(k, ["script", "names", "looks"]):
			out.append("beasts.%s (a boss: script, names, looks)" % k)
	for k in minis:
		if not _beast_has(k, ["script", "names", "site"]):
			out.append("beasts.%s (a miniboss: script, names, site)" % k)
	for k in roamers:
		if not _beast_has(k, ["script", "names"]):
			out.append("beasts.%s (a roamer: script, names)" % k)
	for k in fauna:
		if not creatures.has(k):
			out.append("creatures.%s" % k)
	return out


func _beast_has(kind: String, keys: Array) -> bool:
	if not beasts.has(kind):
		return false
	for key in keys:
		if not (beasts[kind] as Dictionary).has(key):
			return false
	return true
