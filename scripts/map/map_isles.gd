class_name MapIsles
extends RefCounted
## The islands the held map draws (docs/dev_notes.md, "the held map"): Brinehollow and the chain's
## islands standing in the world. Each is a dictionary made once per island node:
##   key   - its name in GameManager.fog and the found spots ("brinehollow", "isle<chain id>", as save_key)
##   name, isl (the Island), o (world x/z of island space's origin)
##   rect  - island space of its height grid (the map's square), cells (that grid's cells a side)
##   n     - fog cells a side (FOG_CELL m each over rect)
##   spots - the places worth finding: {id, kind, name, at (island space), r (found within, m)}
## The spots are read from the island kit's data (GenIsland.sites / places / interiors, Brinehollow's
## constants), never changed.

const FOG_CELL := 12.0
## Found within this of a spot's middle (plus its own size).
const FIND_R := 16.0
## GenIsland.sites worth a mark: [kind, name].
const SITES := {"camp": ["camp", "Pirate camp"], "lair": ["lair", "Bug burrows"], "ruins": ["ruins", "Old ruins"],
	"summit": ["lookout", "The lookout"], "boss": ["beast", "The beast's ground"]}
## Brinehollow's: [id, kind, name, island-space spot, size].
const BRINEHOLLOW := [["ruins", "ruins", "Jungle ruins", StarterIsland.RUINS, 9.0], ["lighthouse", "lookout", "The lighthouse", StarterIsland.HILL, 8.0],
	["cave", "cave", "The bug queen's cave", StarterIsland.CAVE, 8.0], ["den", "camp", "Grell's den", StarterIsland.DEN, 20.0],
	["smugglers", "camp", "Smugglers' camp", StarterIsland.SMUGGLERS, 10.0], ["castaway", "camp", "Castaway camp", StarterIsland.CAMP, 8.0],
	["falls", "landmark", "The falls", StarterIsland.POOL, 14.0], ["cove2", "landmark", "Fisher's cove", StarterIsland.COVE2 + Vector2(-4, -30), 10.0],
	["stash", "treasure", "A hidden stash", StarterIsland.JUNGLE_STASH, 4.0], ["yard", "landmark", "Training yard", StarterIsland.TRAINING, 10.0]]

static var _made := {}


## Every island standing in the world now.
static func all(tree: SceneTree) -> Array:
	var w := tree.get_first_node_in_group("world_gen")
	if w == null:
		return []
	var out: Array = []
	if w.starter_island:
		out.append(of(w.starter_island))
	for id in w.chain_islands.keys():
		out.append(of(w.chain_islands[id]))
	return out


## The island whose map square holds world point p ({} out at sea).
static func at(tree: SceneTree, p: Vector2) -> Dictionary:
	for d in all(tree):
		if (d["rect"] as Rect2).has_point(p - d["o"]):
			return d
	return {}


static func of(isl: Island) -> Dictionary:
	var id := isl.get_instance_id()
	if not _made.has(id):
		for k in _made.keys():
			if not is_instance_id_valid(k):
				_made.erase(k)
		_made[id] = _brinehollow(isl) if isl is StarterIsland else _gen(isl)
	return _made[id]


static func _brinehollow(isl: StarterIsland) -> Dictionary:
	var spots: Array = []
	for s in BRINEHOLLOW:
		spots.append({"id": s[0], "kind": s[1], "name": s[2], "at": s[3], "r": FIND_R + float(s[4])})
	if not isl.wreck_site.is_empty():
		spots.append({"id": "wreck", "kind": "landmark", "name": "The wreck", "at": isl.wreck_site[0], "r": FIND_R + 12.0})
	var rect := StarterIsland.grid_rect()
	return {"key": "brinehollow", "name": "Brinehollow", "isl": isl, "o": Vector2(isl.position.x, isl.position.z), "rect": rect,
		"cells": StarterIsland.RES, "n": ceili(rect.size.x / FOG_CELL), "spots": spots, "town": [StarterIsland.VILLAGE, "Brinehollow"]}


static func _gen(isl: GenIsland) -> Dictionary:
	var spots: Array = []
	for s in SITES.keys():
		if isl.sites.has(s):
			spots.append({"id": "site_" + s, "kind": SITES[s][0], "name": SITES[s][1], "at": isl.sites[s], "r": FIND_R + 8.0})
	for i in range(isl.places.size()):
		var pl: Dictionary = isl.places[i]
		var kind := str(pl["kind"])
		spots.append({"id": "place%d" % i, "kind": kind_of(kind), "name": str(pl.get("title", kind.capitalize())), "at": pl["at"],
			"r": FIND_R + float(pl.get("r", 8.0)) * 0.5})
	for i in range(isl.interiors.size()):
		var e: Dictionary = isl.interiors[i]
		spots.append({"id": "inside%d" % i, "kind": "ruins" if e["kind"] == "temple" else "cave", "name": str(e["title"]), "at": e["mouth"], "r": FIND_R + 6.0})
	var rect := Rect2(-isl.half, -isl.half, isl.extent, isl.extent)
	return {"key": "isle%d" % int(isl.node["id"]), "name": str(isl.node["name"]), "isl": isl, "o": Vector2(isl.position.x, isl.position.z),
		"rect": rect, "cells": isl.res, "n": ceili(rect.size.x / FOG_CELL), "spots": spots,
		"town": [isl.sites["village"], isl.island_name if isl is CapitalIsland else "Village"] if isl.sites.has("village") else []}


## A landmark's kind as the map draws it.
static func kind_of(kind: String) -> String:
	if kind in ["watchtower", "lookout", "lighthouse"]:
		return "lookout"
	if kind in ["temple", "ruins", "aqueduct", "totem_grove", "obelisk", "tomb"]:
		return "ruins"
	if kind in ["mine", "camp", "hermit_hut"]:
		return "camp"
	return "landmark"


## Where a spot's `?` sits while it's not found: near it, not on it (a fixed jitter per spot).
static func rough(d: Dictionary, s: Dictionary) -> Vector2:
	var h := absi(hash(str(d["key"]) + str(s["id"])))
	var a := float(h % 6283) * 0.001
	var r := 8.0 + float((h / 6283) % 1000) * 0.016
	return s["at"] + Vector2(cos(a), sin(a)) * r


## The island's heights as a texture (metres; the map's land shader reads it), made once per island.
static func heights_tex(d: Dictionary) -> ImageTexture:
	if not d.has("htex"):
		var w: int = int(d["cells"]) + 1
		var isl = d["isl"]
		var img := Image.create_from_data(w, w, false, Image.FORMAT_RF, (isl.heights as PackedFloat32Array).to_byte_array())
		# (mipmaps: the chart shows a whole island in a few dozen pixels)
		img.generate_mipmaps()
		d["htex"] = ImageTexture.create_from_image(img)
	return d["htex"]
