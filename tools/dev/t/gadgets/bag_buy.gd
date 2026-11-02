extends SceneTree
## Getting a gadget bag (1.28.1): the four colours are items; the forge town's master tinkerer offers it for 250 gold
## and the colour asked for; short of gold he won't, with it the bag's in yours and worn in that colour, four slots; a
## second of the same colour he won't sell; hoards roll one now and then for a captain without one, ordinary chests never.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var t
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


func _bags(kind: String, n: int) -> int:
	var G = load("res://scripts/gadgets/gadgets.gd")
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var got := 0
	for i in range(n):
		var out: Array = []
		G.chest_extras(out, kind, rng, p)
		got += out.filter(func(s): return str(s.item.id).begins_with("gadget_bag_")).size()
	return got


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			for c in ["mustard", "olive", "oxblood", "navy"]:
				var it = ItemDB.get_item("gadget_bag_" + c)
				check("the %s bag is an item with an icon" % c, it != null and it.icon != null)
			t = load("res://scripts/island/themes/volcanic_tinkerer.gd").new()
			t.key = "test_tinkerer"
			t.who = "Master Tinkerer Test"
			t.price = 100
			stage.add_child(t)
			until = TK.wait_ticks(2)
		1:
			var dlg := root.get_node("Dialogue")
			var id: String = t.define()
			var menu: Array = (dlg._cache[id]["nodes"]["menu"]["choices"] as Array).map(func(c): return str(c["text"]))
			check("he offers a gadget bag for 250 gold (%s)" % str(menu), menu.has("A gadget bag. (250 gold)"))
			var picks: Array = (dlg._cache[id]["nodes"]["bag"]["choices"] as Array).map(func(c): return str(c["text"]))
			check("...in four colours (%s)" % str(picks), picks.slice(0, 4) == ["Mustard.", "Olive.", "Oxblood.", "Navy."])
			p.inventory_component.remove_item(ItemDB.get_item("gold"), p.inventory_component.count("gold"))
			p.inventory_component.add_item(ItemDB.get_item("gold"), 200)
			t._on_event("volcanic_bag:test_tinkerer:navy")
			check("short of gold he won't (%s)" % t._said, p.inventory_component.count("gadget_bag_navy") == 0 and p.inventory_component.count("gold") == 200)
			p.inventory_component.add_item(ItemDB.get_item("gold"), 100)
			t._on_event("volcanic_bag:test_tinkerer:navy")
			check("with 250 the navy bag is yours", p.inventory_component.count("gadget_bag_navy") == 1 and p.inventory_component.count("gold") == 50)
			check("...worn in navy, four slots", p.body_model.bag_colour == "navy" and p.gadgets.capacity() == 4)
			p.inventory_component.add_item(ItemDB.get_item("gold"), 300)
			t._on_event("volcanic_bag:test_tinkerer:navy")
			check("a second navy one he won't sell", p.inventory_component.count("gadget_bag_navy") == 1 and p.inventory_component.count("gold") == 350)
			p.inventory_component.remove_item(ItemDB.get_item("gadget_bag_navy"), 1)
			var h := _bags("hoard", 400)
			check("hoards roll one now and then (%d in 400)" % h, h >= 8 and h <= 60)
			check("...ordinary chests never", _bags("ordinary", 400) == 0)
			p.inventory_component.add_item(ItemDB.get_item("gadget_bag_olive"), 1)
			check("...nor for a captain who carries one", _bags("hoard", 400) == 0)
			return TK.done(fails)
	step += 1
	return false
