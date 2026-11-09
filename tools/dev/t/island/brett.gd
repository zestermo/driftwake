extends SceneTree
## Brett, Brinehollow's wandering knife seller (2026-11-09): his look (pale, slim, shoulder-length brown hair,
## stubble, brown eyes, a black long coat, brown boots), his shop of daggers, his talk (the first meeting gives a
## cheap dagger, a fishing tip, the boots line, the shop) and the gift once per captain, never twice.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _blades() -> int:
	var n := 0
	for id in BrinehollowCast.BRETT_GIFTS:
		n += p.inventory_component.count(id)
	return n


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			var b: Dictionary = BrinehollowCast.brett()
			var lk: Dictionary = b["look"]
			check("his look: slim, pale, shoulder-length brown hair, stubble, brown eyes",
				lk["build"] == "slim" and lk["skin"] == CharacterLook.SKIN_TONES[0] and lk["hair"] == "lob"
				and lk["hair_color"] == CharacterLook.HAIR_COLORS[2] and lk["facial_hair"] == "stubble" and lk["eye_color"] == CharacterLook.EYE_COLORS[0])
			check("a black long coat and brown boots", lk["coat"] == "longcoat" and lk["coat_color"] == CharacterLook.CLOTH[5]
				and lk["feet"] == "boots" and lk["feet_color"] == CharacterLook.LEATHER[2])
			var plan: Array = []
			for e in BrinehollowCast.townsfolk():
				if e["cfg"]["name"] == "Brett":
					plan = e["plan"]
			check("he walks the town: %d stops by day" % plan.size(), plan.size() >= 10)
			var shop: Dictionary = Shops.SHOPS.get("brett", {})
			var sells_blades := not shop.is_empty()
			for s in shop.get("stock", []) + shop.get("pool", []):
				var it: ItemData = ItemDB.get_item(str(s[0]).get_slice("@", 0))
				sells_blades = sells_blades and it != null and it.item_type == ItemData.ItemType.WEAPON
			check("his shop sells only knives and daggers", sells_blades)
			var dlg: Node = root.get_node("Dialogue")
			var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/dialogue/brett.json"))
			var nodes: Dictionary = data["nodes"]
			check("the first meeting gives the gift", nodes[data["start"]].get("event", "") == "gift_brett")
			check("a fishing tip, the boots, the shop", "dawn" in str(nodes["fishing"]["text"]).to_lower()
				and "boots will last you a long time" in str(nodes["boots"]["text"]) and nodes["shop"]["event"] == "shop:brett")
			for id in BrinehollowCast.BRETT_GIFTS:
				var it: ItemData = ItemDB.get_item(id)
				check("%s is a cheap blade (%d gold)" % [id, Economy.price(it) if it else -1], it != null and it.item_type == ItemData.ItemType.WEAPON and Economy.price(it) <= 60)
			dlg.flags.erase("brett_gift")
			var before := _blades()
			BrinehollowCast.brett_gift(p)
			BrinehollowCast.brett_gift(p)
			var after := _blades()
			check("the first meeting: a dagger in the bag (%d -> %d)" % [before, after], after == before + 1)
			check("...and only once", dlg.has_flag("brett_gift"))
			return TK.done(fails)
	step += 1
	return false
