extends SceneTree
## Instruments as items: none in a new captain's kit; five with icons; Corin's music shop sells all five (and a chain
## island's trader now and then, the same on every machine); carried in the equipment slot one at a time (a second
## swaps the first back into the bag), named in the look; carried on the back; saved by id.
const TK := preload("res://tools/dev/test_kit.gd")
const SHOPS := preload("res://scripts/game/shops.gd")
var stage
var p
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			var inv = p.inventory_component
			var any := false
			for k in Instruments.KINDS:
				any = any or inv.count(Instruments.item_id(k)) > 0
			check("a new captain has no instrument (bag or worn)", not any and p.equipment.get_item("equipment") == null and p.jam.worn() == "")
			var ok := true
			for k in Instruments.KINDS:
				var it: ItemData = ItemDB.get_item(Instruments.item_id(k))
				ok = ok and it != null and it.is_gear() and it.gear_slot == "equipment" and it.icon != null and Instruments.kind_of(it) == k and it.worth() > 0
			check("five instruments, each gear for the equipment slot with an icon", ok)
			var music: Array = []
			for e in SHOPS.SHOPS["corin"]["stock"]:
				var it: ItemData = SHOPS.item_of(e)
				if Instruments.kind_of(it) != "":
					music.append(Instruments.kind_of(it))
			check("Corin's music shop sells all five instruments (%s)" % str(music), music.size() == 5)
			var others := 0
			for id in SHOPS.SHOPS.keys():
				if id != "corin":
					for e in SHOPS.SHOPS[id]["stock"]:
						if e.size() == 2 and Instruments.kind_of(ItemDB.get_item(str(e[0]))) != "":
							others += 1
			check("no other Brinehollow trader sells one", others == 0)
			var rolled := 0
			var same := true
			for i in range(40):
				var a: Array = Instruments.trader_stock("isle%d_trader" % i)
				same = same and str(a) == str(Instruments.trader_stock("isle%d_trader" % i))
				rolled += a.size()
			check("a chain trader sometimes has one (%d of 40), the same every time" % rolled, rolled > 6 and rolled < 34 and same)
			# wear the fiddle, then the whistle: one at a time
			var fid: ItemData = ItemDB.get_item("fiddle")
			var whi: ItemData = ItemDB.get_item("tin_whistle")
			inv.add_item(fid, 1)
			inv.add_item(whi, 1)
			p.equip_gear_from_bag(inv.find_index("fiddle"))
			check("the fiddle goes in the equipment slot", p.equipment.get_item("equipment") == fid and p.body_model.look.get("instrument") == "fiddle")
			p.equip_gear_from_bag(inv.find_index("tin_whistle"))
			check("the whistle takes its place, the fiddle back in the bag", p.equipment.get_item("equipment") == whi and inv.count("fiddle") == 1 and inv.count("tin_whistle") == 0)
			check("worn instruments don't count as armour", is_equal_approx(whi.armor(), 0.0))
			var sg = load("res://scripts/game/save_game.gd")
			var ref: Array = sg.item_ref(whi)
			check("saved by id (%s)" % str(ref), ref == ["id", "tin_whistle"] and sg.item_from(ref) == whi)
			p.unequip_gear("equipment")
			p.equip_gear_from_bag(inv.find_index("fiddle"))
			until = TK.wait_ticks(4)
		1:
			var back = p.jam._back
			check("the fiddle rides on the back (on the torso, behind it)", back != null and back.visible and back.get_parent() == p.body_model.torso and back.position.z > 0.1)
			return TK.done(fails)
	step += 1
	return false
