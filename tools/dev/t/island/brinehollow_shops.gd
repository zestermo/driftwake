extends SceneTree
## Brinehollow's traders after the shop moves (2026-10-17): Gus sells drink and food and no instrument, Vey's
## Armoury armour and no weapon (and buys no blades), Haldor's Forge every blade Vey used to and buys spares,
## Corin's music shop all five instruments. On Brinehollow built: Haldor trades at his anvil, Corin keeps a
## shopfront on the market street at its counter.
const TK := preload("res://tools/dev/test_kit.gd")
const SHOPS := preload("res://scripts/game/shops.gd")
var stage
var step := 0
var until := 0
var fails := 0
var isl


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _kinds(id: String) -> Array:
	var out: Array = []
	for e in SHOPS.SHOPS[id]["stock"]:
		var it: ItemData = SHOPS.item_of(e)
		out.append("instrument" if Instruments.kind_of(it) != "" else ["loot", "weapon", "consumable", "gear"][int(it.item_type)])
	return out


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			check("Gus sells drink and food, no instrument (%s)" % str(_kinds("gus")), not _kinds("gus").has("instrument") and _kinds("gus").has("consumable"))
			check("Vey sells armour, no weapon (%s)" % str(_kinds("vey")), not _kinds("vey").has("weapon") and _kinds("vey").count("gear") >= 10)
			var blade: ItemData = ItemDB.get_item("cutlass@2")
			check("Vey doesn't buy blades, Haldor does", SHOPS.offer("vey", blade) == 0 and SHOPS.offer("haldor", blade) > 0)
			check("Haldor sells only weapons, at least 16", _kinds("haldor").all(func(k): return k == "weapon") and _kinds("haldor").size() >= 16)
			var sold: Array = []
			for e in SHOPS.SHOPS["corin"]["stock"]:
				sold.append(Instruments.kind_of(SHOPS.item_of(e)))
			sold.sort()
			var all: Array = Instruments.KINDS.duplicate()
			all.sort()
			check("Corin sells all five instruments (%s)" % str(sold), sold == all)
			isl = load("res://scripts/island/starter_island.gd").new()
			isl.name = "Brinehollow"
			isl.position = Vector3(0, 0, 9000)
			stage.add_child(isl)
			isl.build(42)
			until = TK.wait_ticks(10)
		1:
			var npcs := {}
			for n in isl.find_children("*", "NPC", true, false):
				npcs[n.npc_name] = n
			var hal = npcs.get("Haldor the Smith")
			check("Haldor trades at his anvil", hal != null and hal.shop_id == "haldor" and hal.interactable.prompt_text.begins_with("Trade"))
			var cor = npcs.get("Corin")
			var shop: Node3D = null
			for s in isl.town_spots["shops"]:
				if cor and s.get_node("Vendor").global_position.distance_to(cor.global_position) < 0.6:
					shop = s
			check("Corin keeps a market street shopfront, at its counter", cor != null and cor.shop_id == "corin" and shop != null)
			isl.queue_free()
			return TK.done(fails)
	step += 1
	return false
