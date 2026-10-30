class_name CityCaches
extends RefCounted
## The cities' hidden caches (1.27, docs/v1_27_plan.md C4): a strongbox each in the places a curious captain finds by
## climbing or poking about (hatch roofs, courtyard corners, the belfries, the library's hidden room, the maze's heart,
## the theatre's stage, the glassworks' back). Each city's district lists them as data (`entry`); the island makes the
## LootBags on the main thread (`place`), skipping any already opened in this save. Contents roll from the cache's key:
## a chain island's chest, more or less.

const LOOT_BAG := "res://scenes/loot/loot_bag.tscn"


## One cache: at frame transform `xf` (on the floor it stands on), saved as `key`.
static func entry(xf: Transform3D, key: String) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(key)
	var items: Array = [["gold", rng.randi_range(40, 90)], ["treasure", rng.randi_range(1, 3)]]
	if rng.randf() < 0.5:
		items.append(["tonic", 1])
	return {"xf": xf, "key": key, "items": items}


## The caches as LootBags under `parent` (the city node), the opened ones left out.
static func place(parent: Node3D, caches: Array) -> void:
	var gm := parent.get_node_or_null("/root/GameManager")
	for e in caches:
		if gm and gm.opened.has(str(e["key"])):
			continue
		var bag := (load(LOOT_BAG) as PackedScene).instantiate() as LootBag
		var stacks: Array[ItemStack] = []
		for it in e["items"]:
			var st := ItemStack.new()
			st.item = ItemDB.get_item(str(it[0]))
			st.quantity = int(it[1])
			if st.item:
				stacks.append(st)
		bag.setup(stacks)
		bag.save_id = str(e["key"])
		bag.name = "Cache_" + str(e["key"])
		var mi := bag.get_node_or_null("MeshInstance3D") as MeshInstance3D
		if mi:
			mi.mesh = Props.treasure_chest_mesh()
			mi.position = Vector3.ZERO
			mi.scale = Vector3.ONE
		bag.transform = e["xf"]
		parent.add_child(bag)
		# (a lead bought from the Hooded Stranger: an X on the map until it's opened)
		if gm and gm.world_flags.has(LEAD + str(e["key"])):
			_mark(bag, str(e["key"]))


# --------------------------------------------------------------------------
# The Hooded Stranger's leads (docs/v1_27_plan.md "The Hooded Stranger's leads"): a cache in this city for LEAD_GOLD,
# marked with an X on the map (saved as a world flag, so it comes back after a load and for the crew) until opened. The
# dearer leads (a legendary weapon, the stronghold's way in, a Driftfruit) come with the strongholds and the fruits.
# --------------------------------------------------------------------------
const LEAD := "lead_"
const LEAD_GOLD := 300


## The Stranger's talk for a city (`city`: "capital" / "canal"; the island holds the caches as `caches` under `city`).
static func stranger_nodes(city: String, isl: Node) -> Dictionary:
	var me := func() -> Player: return isl.get_tree().get_first_node_in_group("player") as Player if isl.is_inside_tree() else null
	var left := func(): return not _unled(isl).is_empty()
	var can := func(): return left.call() and me.call() != null and me.call().inventory_component.count("gold") >= LEAD_GOLD
	var short := func(): return left.call() and (me.call() == null or me.call().inventory_component.count("gold") < LEAD_GOLD)
	var menu := {"text": "Well?", "choices": [
		{"text": "Sell me a secret. (%d gold)" % LEAD_GOLD, "next": "sell", "if": can},
		{"text": "What do you sell?", "next": "what"},
		{"text": "I'm short of gold.", "next": "short", "if": short},
		{"text": "Nothing left to sell me?", "next": "none", "if": func(): return not left.call()},
		{"text": "Goodbye.", "next": "end"}]}
	return {"intro": {"text": ["...You climbed all this way. Most don't.", "I sell what this city hides. Gold up front."], "next": "menu"}, "menu": menu,
		"what": {"text": ["Strongboxes, tucked where nobody looks: up on the roofs, behind the shelves, in the dark corners.",
			"For %d gold I'll put one on your map. Bigger secrets later. Bigger prices too." % LEAD_GOLD], "next": "menu"},
		"sell": {"text": ["Look at your map. There. Don't tell anyone where you heard it."], "event": "lead:cache:" + city, "next": "menu"},
		"short": {"text": ["Then come back when you aren't."], "next": "menu"},
		"none": {"text": ["You've had everything I know about this city. Try the other one. Or wait for news."], "next": "menu"}}


## A "lead:cache:<city>" event: the gold paid, the next unled cache flagged for the crew and marked on the map.
static func sell_lead(ev: String, city: String, isl: Node) -> void:
	if ev != "lead:cache:" + city:
		return
	var p := isl.get_tree().get_first_node_in_group("player") as Player
	var todo := _unled(isl)
	if p == null or todo.is_empty() or p.inventory_component.count("gold") < LEAD_GOLD:
		return
	p.inventory_component.remove_item(ItemDB.get_item("gold"), LEAD_GOLD)
	var key: String = todo[0]
	isl.get_node("/root/Net").world_flag(LEAD + key)
	var bag := (isl.get("city") as Node).get_node_or_null("Cache_" + key) as Node3D
	if bag:
		_mark(bag, key)
	isl.get_tree().call_group("hud", "show_toast", "A cache marked on your map (%d gold)" % LEAD_GOLD)


## The caches still closed that no lead has pointed to yet, in their order.
static func _unled(isl: Node) -> Array:
	var gm := isl.get_node_or_null("/root/GameManager")
	var out: Array = []
	for e in isl.get("caches"):
		var k := str(e["key"])
		if gm and (gm.opened.has(k) or gm.world_flags.has(LEAD + k)):
			continue
		out.append(k)
	return out


static func _mark(bag: Node3D, key: String) -> void:
	MapMarks.put("cache_" + key, bag.global_position, "x", "A cache")
	bag.tree_exited.connect(func(): MapMarks.clear("cache_" + key))
