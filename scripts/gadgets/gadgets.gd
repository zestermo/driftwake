class_name Gadgets
extends RefCounted
## Gadgets (1.28, docs/v1_28_plan.md "Gadgets and tinkering", numbers in GadgetData / docs/gadgets_plan.md): the
## belt's gadgets, their blueprints, parts and tiers, and the workbench's work (build, upgrade, refill, study).
## CONTRACT (lead, 2026-10-31): other features only call the members below (the forge town's master tinkerer,
## books, the merchant ship, loot):
##   Gadgets.teach(player, blueprint_id) -> bool   a captain learns a blueprint (false: already known / no such one)
##   Gadgets.blueprint_ids() -> Array              every blueprint id (for shops, books and loot tables)
##   Gadgets.part_ids() -> Array                   every part item id (salvage, ore, beast parts: for loot tables)
## A blueprint id is also an item ("bp_<gadget>", a scroll): carried to a workbench, it's studied (learned, used up).
## No autoloads by name here (ItemDB calls make_items before they exist).

## The gadgets the bench offers (all of GadgetData since piece 5).
const WORKING := ["smoke", "tar", "flash", "pepper", "star", "decoy", "caltrops", "grapple", "spring_boots", "glider", "spike",
	"spyglass", "diving_helmet", "auto_reel", "lockpick", "lantern_bomb", "skimmer", "burst_launcher", "paddle_boost", "smoke_screen", "harpoon"]


static func teach(player: Node, blueprint_id: String) -> bool:
	if not blueprint_id in all_blueprint_ids() or knows(player, gadget_of(blueprint_id)):
		return false
	player.gadgets.known[blueprint_id] = true
	player.gadgets.changed.emit()
	player.call("_toast", "Blueprint learned: %s (build it at a workbench)" % GadgetData.GADGETS[gadget_of(blueprint_id)]["name"])
	return true


## (shops, books and loot tables: a regional gadget's blueprint, the skimmer's, is placed by its region alone)
static func blueprint_ids() -> Array:
	return GadgetData.GADGETS.keys().filter(func(g): return not GadgetData.GADGETS[g].has("region")).map(func(g): return "bp_" + str(g))


static func all_blueprint_ids() -> Array:
	return GadgetData.GADGETS.keys().map(func(g): return "bp_" + str(g))


static func part_ids() -> Array:
	return GadgetData.ALL_PARTS.duplicate()


static func gadget_of(blueprint_id: String) -> String:
	return blueprint_id.trim_prefix("bp_")


static func knows(player: Node, gid: String) -> bool:
	return ("bp_" + gid) in GadgetData.STARTER or player.gadgets.known.has("bp_" + gid) or player.gadgets.owned.has(gid)


## (ItemDB._load_all) the new parts and the blueprints into the item table.
static func make_items(items: Dictionary) -> void:
	for id in GadgetData.PARTS.keys():
		var e: Array = GadgetData.PARTS[id]
		var it := ItemData.new()
		it.id = id
		it.display_name = str(e[0])
		it.value = int(e[1])
		it.description = str(e[2])
		it.item_type = ItemData.ItemType.LOOT
		it.max_stack = 50
		it.icon_kind = "part"
		it.icon = GadgetModels.part_icon(id)
		items[id] = it
	for bp in all_blueprint_ids():
		var g: Dictionary = GadgetData.GADGETS[gadget_of(bp)]
		var it := ItemData.new()
		it.id = bp
		it.display_name = "Blueprint: %s" % g["name"]
		it.value = GadgetData.BLUEPRINT_VALUE
		it.rarity = ItemData.Rarity.UNCOMMON
		it.description = "Plans for the %s. Take it to a workbench to study it, then build it there.\n%s" % [g["name"], g["desc"]]
		it.item_type = ItemData.ItemType.LOOT
		it.max_stack = 5
		it.icon_kind = "blueprint"
		it.icon = GadgetModels.part_icon("blueprint")
		items[bp] = it
	GadgetBag.make_items(items)


## (1.28.1) The forge town's master tinkerer sells a gadget bag in `colour`: his answer (the bag in yours if paid).
static func buy_bag(player: Node, colour: String) -> String:
	var inv = player.inventory_component
	if inv.count(GadgetBag.item_id(colour)) > 0:
		return "You've a %s one already, Captain. One bag's plenty for one pair of hips." % colour
	if inv.count("gold") < GadgetBag.PRICE:
		return "That's %d gold, Captain. The stitching alone took me a week." % GadgetBag.PRICE
	if inv.used_slots() >= inv.slots():
		return "Your pack's stuffed full, Captain. Make room and I'll hand it over."
	inv.remove_item(ItemDB.get_item("gold"), GadgetBag.PRICE)
	player.gadgets.bag_pref = colour
	inv.add_item(ItemDB.get_item(GadgetBag.item_id(colour)), 1)
	return "There. Six pockets inside, and the clasp holds whatever you jump off. Tap for the next gadget, hold for the lot."


## What taking `gid` to `tier` costs: [[item id, n], ...] with the gold first.
static func cost(gid: String, tier: int) -> Array:
	var c: Array = GadgetData.tier_val(gid, "cost", tier)
	var out: Array = [["gold", int(c[0])]]
	for k in (c[1] as Dictionary).keys():
		out.append([str(k), int(c[1][k])])
	return out


static func refill_cost(gid: String) -> Array:
	var out: Array = []
	for k in (GadgetData.GADGETS[gid]["refill"] as Dictionary).keys():
		out.append([str(k), int(GadgetData.GADGETS[gid]["refill"][k])])
	return out


## What of `cost` the bag is short of, in words ("" none).
static func short_of(inv, c: Array) -> String:
	var miss: Array = []
	for e in c:
		var have: int = inv.count(str(e[0]))
		if have < int(e[1]):
			miss.append("%d %s" % [int(e[1]) - have, _name(str(e[0]))])
	return ", ".join(miss)


static func cost_text(c: Array) -> String:
	return ", ".join(c.map(func(e): return "%d%s" % [int(e[1]), "g" if e[0] == "gold" else " " + _name(str(e[0]))]))


static func _name(id: String) -> String:
	if id == "gold":
		return "gold"
	var it := ItemDB.get_item(id)
	return it.display_name if it else id


## What `gid` does at `tier`, in a line ("3 CHARGES  6 S COOLDOWN  RANGE 14 M  RADIUS 3.5 M ...").
static func stat_text(gid: String, tier: int) -> String:
	var g: Dictionary = GadgetData.GADGETS[gid]
	var parts: Array = []
	var ch := int(GadgetData.tier_val(gid, "charges", tier))
	parts.append("%d charges" % ch if ch > 0 else "no charges")
	parts.append("%s s cooldown" % _num(GadgetData.tier_val(gid, "cd", tier)))
	for k in STAT_WORDS.keys():
		if g.has(k):
			var v = GadgetData.tier_val(gid, k, tier)
			if (v is float or v is int) and float(v) > 0.0:
				parts.append(str(STAT_WORDS[k]) % _num(v))
	return "  ".join(parts)


const STAT_WORDS := {"range": "range %s m", "radius": "radius %s m", "secs": "lasts %s s", "blind": "staggers %s s",
	"slow": "speed x%s", "stun": "stuns %s s", "dps": "%s dmg/s", "damage": "%s dmg", "lure": "lures from %s m",
	"pull": "pulls %s m/s", "jump": "jump %s m/s", "fall": "falls %s m/s", "hold": "holds %s s", "reach": "marks to %s m",
	"breath": "breath x%s", "reel": "reel +%s", "catches": "%s catches", "pick_secs": "picks in %s s", "light": "light %s m",
	"impulse": "+%s m/s", "boost": "speed +%s", "bleed": "bleeds %s s", "burst": "bursts for %s", "speed": "%s m/s", "hop": "hops %s m/s"}


static func _num(v) -> String:
	var f := float(v)
	return str(int(f)) if is_equal_approx(f, roundf(f)) else ("%.2f" % f).rstrip("0")


## The tier the next build or upgrade of `gid` makes (0 = build Mk I), or -1 at Mk III.
static func next_tier(player: Node, gid: String) -> int:
	var t: int = player.gadgets.tier_of(gid)
	return t + 1 if t < 2 else -1


## Why `gid` can't be built or upgraded now ("" it can).
static func why_not(player: Node, gid: String) -> String:
	if not knows(player, gid):
		return "You don't know its blueprint"
	var nt := next_tier(player, gid)
	if nt < 0:
		return "Already Mk III"
	var need: int = GadgetData.TIER_TINKER[nt]
	if player.progression.mastery_level("tinker") < need:
		return "Needs Tinkering %d" % need
	var s := short_of(player.inventory_component, cost(gid, nt))
	return "" if s == "" else "Short of " + s


## Build `gid` (Mk I) or upgrade it a tier, paying from the bag: "" done, else why not.
static func build(player: Node, gid: String) -> String:
	var why := why_not(player, gid)
	if why != "":
		return why
	var nt := next_tier(player, gid)
	_pay(player.inventory_component, cost(gid, nt))
	player.gadgets.give(gid, nt)
	player.progression.add_life("tinker", int(GadgetData.BUILD_XP[nt]))
	return ""


## Refill `gid`'s charges from the bag: "" done, else why not.
static func refill(player: Node, gid: String) -> String:
	var b = player.gadgets
	if b.max_charges(gid) <= 0 or b.charges(gid) >= b.max_charges(gid):
		return "Already full"
	var s := short_of(player.inventory_component, refill_cost(gid))
	if s != "":
		return "Short of " + s
	_pay(player.inventory_component, refill_cost(gid))
	b.refill(gid)
	player.progression.add_life("tinker", GadgetData.REFILL_XP)
	return ""


static func _pay(inv, c: Array) -> void:
	for e in c:
		inv.remove_item(ItemDB.get_item(str(e[0])), int(e[1]))


## At a workbench: every blueprint in the bag is studied (learned and used up; one already known is kept).
## Returns the gadgets learned.
static func study(player: Node) -> Array:
	var out: Array = []
	var inv = player.inventory_component
	for bp in all_blueprint_ids():
		if inv.count(bp) > 0 and not knows(player, gadget_of(bp)):
			inv.remove_item(ItemDB.get_item(bp), 1)
			teach(player, bp)
			out.append(gadget_of(bp))
	return out


## (Loot.chest) a chest's tinker extras for this captain, from its own stream: a few parts, now and then a blueprint
## they don't know yet (GadgetData.CHEST_PARTS / CHEST_BLUEPRINT / CHEST_POOLS).
static func chest_extras(out: Array, kind: String, rng: RandomNumberGenerator, player: Node) -> void:
	var cp: Array = GadgetData.CHEST_PARTS[kind]
	if rng.randf() < float(cp[0]):
		var pool: Array = cp[1]
		_stack(out, str(pool[rng.randi() % pool.size()]), rng.randi_range(1, int(cp[2])))
	if rng.randf() < float(GadgetData.CHEST_BLUEPRINT[kind]):
		var unknown: Array = (GadgetData.CHEST_POOLS[kind] as Array).filter(func(g): return player == null or not knows(player, str(g)))
		if not unknown.is_empty():
			_stack(out, "bp_" + str(unknown[rng.randi() % unknown.size()]), 1)
	# (1.28.1) now and then a hoard holds a gadget bag, for a captain without one
	if kind == "hoard" and rng.randf() < GadgetData.HOARD_BAG and (player == null or player.gadgets.bag_colour() == ""):
		_stack(out, GadgetBag.item_id(GadgetBag.ORDER[rng.randi() % GadgetBag.ORDER.size()]), 1)


static func _stack(out: Array, id: String, n: int) -> void:
	var st := ItemStack.new()
	st.item = ItemDB.get_item(id)
	st.quantity = n
	out.append(st)
