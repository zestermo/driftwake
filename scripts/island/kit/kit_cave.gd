class_name KitCave
extends RefCounted
## Places you walk into: a cave in its own clearing (BroodCave: a craggy outcrop,
## the chamber, dripstone and lichen, the brood queen and her hoard) and the inn
## (Buildings.tavern_hall: bar, kegs, tables, fireplace, markers Barkeep,
## Patron1-3, Door). The cave wants a flat clearing 30-44 m across (the island's
## flat zone) and reserves `clear` round it; its outcrop's foot stays inside that.


## A cave at c. opts: shape_seed (its rock), hoard_id (the boss's hoard in the
## save; Brinehollow's is "brood_hoard"), title (the banner).
static func cave(ctx: KitContext, c: Vector2, opts := {}, clear := 32.0, node_name := "BroodCave") -> BroodCave:
	ctx.reserve(c, clear)
	var cv := BroodCave.new()
	cv.name = node_name
	if opts.has("shape_seed"):
		cv.shape_seed = int(opts["shape_seed"])
	if opts.has("hoard_id"):
		cv.hoard_id = str(opts["hoard_id"])
	if opts.has("title"):
		cv.title = str(opts["title"])
	ctx.put(cv, Vector3(c.x, ctx.hv(c), c.y))
	return cv


## The inn at p, its door toward `face`; the ground at its door kept clear.
static func inn(ctx: KitContext, p: Vector2, face: Vector2, footprint := 8.0) -> Node3D:
	var hall := ctx.place(Buildings.tavern_hall(), p, KitContext.face_yaw(face), footprint)
	ctx.reserve(ctx.marker_point(hall, "Door"), 3.0)
	return hall
