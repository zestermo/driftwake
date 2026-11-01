class_name Books
extends RefCounted
## Reading (1.28, docs/life_systems_plan.md "Books"; the books themselves are BookData's). Each captain reads on their
## own machine: what a book teaches goes to the local captain, and the book goes on their shelf (Progression.downtime
## ["books"]: id -> true, saved with the captain). Read from the bag (a click) or with the wheel's Read (Downtime: the
## first interval reads the first unread book carried).
##   Books.read(p, id) -> String        read it (the bag's copy is used up); what it taught, said
##   Books.has_read(pr, id) / count(pr) / next_unread(p)
##   Books.perk(pr, key) -> float       the manuals' and lore sets' permanent perks (Progression.stat)
##   Books.chest_extras(out, kind, rng, p), library_shop(), tinker_shop(), merchant_pool()   where books come from

## Bumped on every book read anywhere on this screen (the shelf polls it to rebuild its spines).
static var rev := 0


static func shelf(pr) -> Dictionary:
	if not pr.downtime.has("books"):
		pr.downtime["books"] = {}
	return pr.downtime["books"]


static func has_read(pr, id: String) -> bool:
	return shelf(pr).has(id)


static func count(pr) -> int:
	return shelf(pr).size()


## The books read in shelf order (kinds in BookData.KINDS order, then as listed).
static func read_ids(pr) -> Array:
	var out: Array = []
	for k in BookData.KINDS:
		for id in BookData.of_kinds([k]):
			if has_read(pr, id):
				out.append(id)
	return out


## The first book carried that hasn't been read (charts count as unread: they mark again), or "".
static func next_unread(p) -> String:
	for st in p.inventory_component.items:
		if BookData.is_book(st.item) and (not has_read(p.progression, st.item.id) or BookData.kind_of(st.item.id) == "chart"):
			return st.item.id
	return ""


## Read book `id`: teach its thing, put it on the shelf, use up the bag's copy. Returns what to say.
static func read(p, id: String) -> String:
	var pr = p.progression
	var b: Dictionary = BookData.BOOKS[id]
	var inv = p.inventory_component
	var again := has_read(pr, id)
	if again and b["kind"] != "chart":
		return "You've read %s already. A bookseller would give you something for it." % b["name"]
	if inv.count(id) > 0:
		inv.remove_item(ItemDB.get_item(id), 1)
	shelf(pr)[id] = true
	rev += 1
	var said := ""
	match str(b["kind"]):
		"blueprint":
			var gid := Gadgets.gadget_of(str(b["teaches"]))
			said = "the plans for the %s (build it at a workbench)" % GadgetData.GADGETS[gid]["name"] if Gadgets.teach(p, str(b["teaches"])) \
				else "nothing new: you know the %s already" % GadgetData.GADGETS[gid]["name"]
		"recipe":
			var mid := str(b["teaches"])
			said = "a recipe: %s (the galley)" % Food.MEALS[mid]["name"] if Food.teach(pr, mid) else "a recipe you know already"
		"manual":
			p.call("_recalc_stats")
			said = perk_text(b["perk"]) + ", for good"
		"chart":
			said = chart(p, str(b["marks"]))
		"lore":
			said = _lore(p, str(b["set"]))
	p.call("_toast", "You read %s: %s" % [b["name"], said])
	return said


## A lore volume read: how far through its set, and the set's reward on the last one.
static func _lore(p, set_id: String) -> String:
	var pr = p.progression
	var s: Dictionary = BookData.LORE_SETS[set_id]
	var have := set_have(pr, set_id)
	var n: int = (s["books"] as Array).size()
	if have < n:
		return "%s, %d of %d" % [s["name"], have, n]
	var r: Dictionary = s["reward"]
	if r.has("will"):
		pr.will_point(int(r["will"]), "the last of %s" % s["name"])
	if r.has("gold"):
		p.inventory_component.add_item(ItemDB.get_item("gold"), int(r["gold"]))
	if r.has("recipe"):
		Food.teach(pr, str(r["recipe"]))
	if r.has("perk"):
		p.call("_recalc_stats")
	return "the set is whole! %s" % s["said"]


static func set_have(pr, set_id: String) -> int:
	return (BookData.LORE_SETS[set_id]["books"] as Array).filter(func(id): return has_read(pr, id)).size()


static func set_done(pr, set_id: String) -> bool:
	return set_have(pr, set_id) == (BookData.LORE_SETS[set_id]["books"] as Array).size()


## The manuals' and finished lore sets' permanent bonus to `key`.
static func perk(pr, key: String) -> float:
	var books: Dictionary = pr.downtime.get("books", {})
	if books.is_empty():
		return 0.0
	var v := 0.0
	for id in books.keys():
		var b: Dictionary = BookData.BOOKS.get(id, {})
		if b.get("kind", "") == "manual":
			v += float((b["perk"] as Dictionary).get(key, 0.0))
	for sid in BookData.LORE_SETS.keys():
		var r: Dictionary = BookData.LORE_SETS[sid]["reward"]
		if r.has("perk") and (r["perk"] as Dictionary).has(key) and set_done(pr, sid):
			v += float(r["perk"][key])
	return v


const PERK_TEXT := {"move_pct": "+%d%% run speed", "sprint_pct": "+%d%% sprint speed", "damage_pct": "+%d%% damage",
	"swim_pct": "+%d%% swim speed", "meal_time_pct": "meals last +%d%%", "fish_bite_pct": "bites %d%% sooner",
	"fish_reel_pct": "+%d%% reel window", "defense": "+%d defense", "max_stamina": "+%d max stamina", "fish_rare_pct": "+%d%% rare fish"}


static func perk_text(perk_: Dictionary) -> String:
	var parts: Array = []
	for k in perk_.keys():
		var amt := float(perk_[k])
		parts.append(PERK_TEXT[k] % (roundi(amt) if k in ["defense", "max_stamina"] else roundi(amt * 100.0)))
	return ", ".join(parts)


## What book `id` teaches, in a line (the bag's tooltip, the shelf).
static func teaches_text(id: String) -> String:
	var b: Dictionary = BookData.BOOKS[id]
	match str(b["kind"]):
		"blueprint":
			return "Blueprint: " + str(GadgetData.GADGETS[Gadgets.gadget_of(str(b["teaches"]))]["name"])
		"recipe":
			return "Recipe: " + str(Food.MEALS[str(b["teaches"])]["name"])
		"manual":
			return "Technique: " + perk_text(b["perk"])
		"chart":
			return "Chart: " + {"stops": "the sea stops ahead", "king": "the Leviathan's waters ahead", "wrecks": "the wrecks ahead"}[b["marks"]]
	var s: Dictionary = BookData.LORE_SETS[b["set"]]
	return "Lore: %s (the set: %s)" % [s["name"], s["said"]]


# --------------------------------------------------------------------------
# Sea charts: marks on the held map for the legs ahead (MapMarks, this screen; kept in pr.downtime["chart_marks"])
# --------------------------------------------------------------------------
## Mark what chart kind `what` shows on the legs ahead of the island the crew's at. Returns what was marked, said.
static func chart(p, what: String) -> String:
	var tree: SceneTree = p.get_tree()
	var gm := tree.root.get_node("GameManager")
	var legs := tree.get_first_node_in_group("sea_legs")
	var wg := tree.get_first_node_in_group("world_gen")
	var marks: Array = []
	if legs and wg and gm.log_pose_set():
		var c: Chain = wg.chain()
		var from_ids: Array = [int(gm.chain_at)]
		for depth in range(BookData.CHART_DEPTH):
			var next_ids: Array = []
			for f in from_ids:
				for t in c.next_of(int(f)):
					_marks_on(legs.plan(int(f), int(t)), what, int(f), int(t), marks)
					next_ids.append(int(t))
			from_ids = next_ids
	if marks.is_empty():
		p.progression.add_xp(BookData.CHART_XP)
		return "nothing on it lies ahead of you now (+%d XP)" % BookData.CHART_XP
	var kept: Array = p.progression.downtime.get("chart_marks", [])
	for m in marks:
		MapMarks.put(str(m[0]), Vector3(float(m[1]), 0.0, float(m[2])), str(m[3]), str(m[4]))
		kept = kept.filter(func(k): return k[0] != m[0])
		kept.append(m)
	p.progression.downtime["chart_marks"] = kept
	return "%d mark%s on your chart (M)" % [marks.size(), "" if marks.size() == 1 else "s"]


static func _marks_on(lay: Dictionary, what: String, f: int, t: int, out: Array) -> void:
	var leg := "%d_%d" % [f, t]
	match what:
		"stops":
			if str(lay.get("stop", "")) != "":
				var at: Vector2 = lay["stop_at"]
				out.append(["chart:stop:" + leg, at.x, at.y, "x", STOP_NAMES.get(lay["stop"], str(lay["stop"]))])
		"king":
			if lay["king"] != Vector2.INF:
				out.append(["chart:king:" + leg, lay["king"].x, lay["king"].y, "spot", "Leviathan"])
		"wrecks":
			for i in range((lay["wrecks"] as Array).size()):
				var at: Vector2 = lay["wrecks"][i][0]
				out.append(["chart:wreck:%s:%d" % [leg, i], at.x, at.y, "spot", "Wreck"])


const STOP_NAMES := {"restaurant": "Floating restaurant", "merchant": "Merchant ship", "warlord": "Warlord's flagship", "lieutenant": "Admiralty warship"}


## (Progression.from_dict) a captain's chart marks back on this screen's map.
static func restore_marks(pr) -> void:
	for m in pr.downtime.get("chart_marks", []):
		MapMarks.put(str(m[0]), Vector3(float(m[1]), 0.0, float(m[2])), str(m[3]), str(m[4]))


# --------------------------------------------------------------------------
# Where books come from
# --------------------------------------------------------------------------
## (Loot.chest) now and then a book, from its own stream: one of the chest's kinds, a book this captain hasn't read first.
static func chest_extras(out: Array, kind: String, rng: RandomNumberGenerator, player: Node) -> void:
	if rng.randf() >= float(BookData.CHEST_BOOK[kind]):
		return
	var pool := BookData.of_kinds(BookData.CHEST_KINDS[kind])
	var fresh := pool.filter(func(id): return player == null or not has_read(player.progression, id))
	var from: Array = fresh if not fresh.is_empty() else pool
	var st := ItemStack.new()
	st.item = ItemDB.get_item(str(from[rng.randi() % from.size()]))
	st.quantity = 1
	out.append(st)


## A village's old library's bookshelf (Shops' shape: LIBRARY_SIZE a day from its pool).
static func library_shop(keeper: String) -> Dictionary:
	return {"name": "%s's Shelves" % keeper, "line": "Handle them gently. Pay for them firmly.", "trade": "books",
		"stock": [], "pool": BookData.of_kinds(BookData.LIBRARY_KINDS).map(func(id): return [id]), "size": BookData.LIBRARY_SIZE,
		"buys": {"loot": 0.5}}


## The forge town's master tinkerer's books.
static func tinker_shop(who: String) -> Dictionary:
	return {"name": "%s's Books" % who, "line": "Read them twice. Build once.", "trade": "books",
		"stock": [], "pool": BookData.TINKER_POOL.map(func(id): return [id]), "size": BookData.TINKER_SIZE, "buys": {}}


static func merchant_pool() -> Array:
	return BookData.of_kinds(BookData.MERCHANT_KINDS)


## (Downtime.register_wheel, once the game runs) the merchant ship's book pool (loaded by path: this class is named by
## Progression, which test scripts compile before the autoloads exist).
static func install() -> void:
	load("res://scripts/sea/merchant_ship.gd").book_pool = merchant_pool()
