extends SceneTree
## Loot is each captain's own: a chest rolls by its key and the captain opening it (the same captain always
## gets the same roll, so a reload can't reroll it; another captain's copy rolls differently), a chest rolls
## once when it's first opened, and a kill's drops land in the captain's own bag (not a shared one), a weapon
## on the ground by itself.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var step := 0
var until := 0
var fails := 0
var LOOT


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "chest": [["gold", 20], ["treasure", 3], ["rum", 2]]})
	LOOT = load("res://scripts/items/loot.gd")


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func roll_of(key: String) -> String:
	var c: Array[ItemStack] = []
	for e in [["gold", 30], ["treasure", 3], ["cutlass@2", 1]]:
		var st := ItemStack.new()
		st.item = ItemDB.get_item(str(e[0]))
		st.quantity = int(e[1])
		c.append(st)
	var out: Array = []
	for st in LOOT.chest(c, key, false):
		out.append("%s x%d" % [st.item.id, st.quantity])
	return ", ".join(out)


func bags() -> Array:
	return get_nodes_in_group("loot_bags")


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			p.appearance["name"] = "Anne"
			var a: Array = []
			var same := true
			for i in range(30):
				a.append(roll_of("isle2_cache_%d" % i))
				same = same and roll_of("isle2_cache_%d" % i) == a[i]
			check("the same captain always rolls the same chest the same way", same)
			p.appearance["name"] = "Bart"
			var differ := 0
			for i in range(30):
				if roll_of("isle2_cache_%d" % i) != a[i]:
					differ += 1
			check("another captain's copy rolls differently (%d of 30 differ)" % differ, differ >= 15)
			var ch = stage.chest
			ch.roll()
			var first: Array = ch.refs()
			ch.roll()
			check("a chest rolls once (%s)" % str(first), ch.rolled and ch.refs() == first)
			var g := 0
			for st in ch.contents:
				if st.item.id == "gold":
					g = st.quantity
			check("...and holds less than was put in (%d of 20 gold)" % g, g >= 1 and g <= 14)
			root.get_node("Net").kill_loot([["boar_haunch", 1.0, 2], ["pistol", 1.0, 1]], p.global_position + Vector3(2, 0.3, 2))
			until = TK.wait_ticks(4)
		1:
			var haunch = null
			var pistol = null
			for b in bags():
				if b.contents.size() == 1 and b.contents[0].item.id == "boar_haunch":
					haunch = b
				if b.contents.size() == 1 and b.contents[0].item.id == "pistol":
					pistol = b
			check("a kill's drops land in the captain's own bag, not a shared one", haunch != null and haunch.shared_id == "" and haunch.contents[0].quantity == 2)
			check("...a weapon lies on the ground by itself", pistol != null and pistol.shared_id == "")
			return TK.done(fails)
	step += 1
	return false
