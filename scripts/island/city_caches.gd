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
