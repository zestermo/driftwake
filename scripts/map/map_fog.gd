class_name MapFog
extends RefCounted
## The held map's fog of war. Per island a coarse grid over its map square (MapIsles: n x n cells of
## FOG_CELL m) of what the crew has seen, in GameManager.fog (key -> PackedByteArray, 255 = seen), and
## the spots found, in GameManager.charted ("spot:<key>:<id>"). Every TICK s (GameManager ticks it) our
## captain uncovers what's round them, more from high ground, and finds spots they come near. Whatever
## any captain uncovers or finds goes to the whole crew (Net.fog_reveal / Net.spot_found); the host's
## save keeps it with the world, and a captain who joins gets it with the world state.

const TICK := 0.5
## Seen round a captain on the ground (m), and more from high up: per m above the sea, up to HIGH_MAX.
const SEE := 34.0
const HIGH_K := 0.9
const HIGH_MAX := 60.0
## Bumped on every change, so a map on screen knows to redraw.
static var version := 0
static var _t := 0.0


static func tick(gm: Node, delta: float) -> void:
	_t -= delta
	if _t > 0.0:
		return
	_t = TICK
	var at: Vector3 = gm.player.global_position
	var d := MapIsles.at(gm.get_tree(), Vector2(at.x, at.z))
	if not d.is_empty():
		look(gm, d, at)


## Our captain at world point `at` on island d: what's round them is uncovered, spots near them found.
static func look(gm: Node, d: Dictionary, at: Vector3) -> void:
	var lp := Vector2(at.x, at.z) - (d["o"] as Vector2)
	var have := grid(gm, d)
	var fresh := PackedInt32Array()
	for c in cells_near(d, lp, SEE + clampf(at.y * HIGH_K, 0.0, HIGH_MAX)):
		if have[c] == 0:
			fresh.append(c)
	if not fresh.is_empty():
		Net.fog_reveal(str(d["key"]), int(d["n"]), fresh)
	for s in d["spots"]:
		if not found(gm, str(d["key"]), str(s["id"])) and lp.distance_to(s["at"]) < float(s["r"]):
			Net.spot_found(str(d["key"]), str(s["id"]), str(s["name"]))


## The fog cells (indices) whose middles are within r of island point p.
static func cells_near(d: Dictionary, p: Vector2, r: float) -> PackedInt32Array:
	var n := int(d["n"])
	var o: Vector2 = (d["rect"] as Rect2).position
	var cell := MapIsles.FOG_CELL
	var out := PackedInt32Array()
	for z in range(clampi(floori((p.y - r - o.y) / cell), 0, n), clampi(ceili((p.y + r - o.y) / cell), 0, n)):
		for x in range(clampi(floori((p.x - r - o.x) / cell), 0, n), clampi(ceili((p.x + r - o.x) / cell), 0, n)):
			if p.distance_to(o + Vector2(x + 0.5, z + 0.5) * cell) <= r:
				out.append(z * n + x)
	return out


## Island d's grid (all fog if nobody's been).
static func grid(gm: Node, d: Dictionary) -> PackedByteArray:
	if gm.fog.has(d["key"]):
		return gm.fog[d["key"]]
	var g := PackedByteArray()
	g.resize(int(d["n"]) * int(d["n"]))
	return g


## Has the crew seen island point p of island d?
static func seen(gm: Node, d: Dictionary, p: Vector2) -> bool:
	var c := ((p - (d["rect"] as Rect2).position) / MapIsles.FOG_CELL).floor()
	var n := int(d["n"])
	return c.x >= 0 and c.y >= 0 and c.x < n and c.y < n and grid(gm, d)[int(c.y) * n + int(c.x)] != 0


## (every machine, Net) these cells of island `key` (n a side) are seen.
static func apply(gm: Node, key: String, n: int, cells: PackedInt32Array) -> void:
	var g: PackedByteArray = gm.fog.get(key, PackedByteArray())
	if g.size() != n * n:
		g.resize(n * n)
	for c in cells:
		g[c] = 255
	gm.fog[key] = g
	version += 1


static func found(gm: Node, key: String, id: String) -> bool:
	return gm.charted.has("spot:%s:%s" % [key, id])


## (every machine, Net) a spot is found.
static func find(gm: Node, key: String, id: String) -> void:
	gm.charted["spot:%s:%s" % [key, id]] = true
	version += 1


## The grids for a save or the world state: key -> [cells, deflated bytes].
static func pack(gm: Node) -> Dictionary:
	var out := {}
	for k in gm.fog.keys():
		var g: PackedByteArray = gm.fog[k]
		out[k] = [g.size(), g.compress(FileAccess.COMPRESSION_DEFLATE)]
	return out


static func unpack(gm: Node, data: Dictionary) -> void:
	gm.fog.clear()
	for k in data.keys():
		gm.fog[str(k)] = (data[k][1] as PackedByteArray).decompress(int(data[k][0]), FileAccess.COMPRESSION_DEFLATE)
	version += 1


## The found spots for the world state.
static func spots(gm: Node) -> Array:
	return gm.charted.keys().filter(func(k): return str(k).begins_with("spot:"))


## A joining guest: the host's found spots instead of ours.
static func take_spots(gm: Node, keys: Array) -> void:
	for k in spots(gm):
		gm.charted.erase(k)
	for k in keys:
		gm.charted[str(k)] = true
	version += 1
