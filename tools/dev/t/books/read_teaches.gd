extends SceneTree
## Reading a book teaches its one thing and shelves it: a blueprint book teaches the gadget, a recipe book the recipe,
## a manual a permanent perk; the bag's copy is used up; the wheel's Read aboard reads a book you carry first; a chart
## with nothing ahead pays experience; a book already read isn't read again; the shelf is saved with the captain.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var pr
var ship
var DT
var B
var dmg0 := 0.0
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "ship": true})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func give(id: String) -> void:
	p.inventory_component.add_item(load("res://scripts/loot/item_db.gd").get_item(id), 1)


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			pr = p.progression
			ship = stage.ship
			DT = load("res://scripts/game/downtime.gd")
			B = load("res://scripts/books/books.gd")
			for id in ["book_pepper", "book_roast", "manual_grip"]:
				give(id)
			check("no Pepper Bomb blueprint yet", not load("res://scripts/gadgets/gadgets.gd").knows(p, "pepper"))
			B.read(p, "book_pepper")
			check("a blueprint book teaches its gadget", load("res://scripts/gadgets/gadgets.gd").knows(p, "pepper"))
			check("...the book's used up from the bag", p.inventory_component.count("book_pepper") == 0)
			check("...and on the shelf", B.has_read(pr, "book_pepper"))
			B.read(p, "book_roast")
			check("a recipe book teaches its recipe", pr.recipes.has("roast_feast"))
			dmg0 = pr.stat("damage_pct")
			B.read(p, "manual_grip")
			check("a manual's perk is for good (+%.2f damage)" % (pr.stat("damage_pct") - dmg0), is_equal_approx(pr.stat("damage_pct") - dmg0, 0.03))
			give("book_pepper")
			B.read(p, "book_pepper")
			check("a book already read isn't read again (the copy's kept to sell)", p.inventory_component.count("book_pepper") == 1)
			var xp0: int = pr.xp + pr.level * 100000
			give("chart_stops")
			B.read(p, "chart_stops")
			check("a chart with nothing ahead pays experience", pr.xp + pr.level * 100000 > xp0)
			# the wheel's Read aboard: the book you carry is read on the first interval
			give("book_spike")
			ship.set_anchored(true)
			p.global_position = ship.global_transform * Vector3(0, ship.DECK_Y + 0.3, 0.0)
			p.reset_physics_interpolation()
			until = TK.wait_ticks(10)
		1:
			DT.start(p, "read")
			until = TK.wait_ticks(10)
		2:
			check("reading aboard", p.current_state_name() == "Downtime")
			p.state_machine.current_state._earned = DT.every(p, "read") - 0.1
			until = TK.wait_secs(0.3)
		3:
			check("Read aboard reads the book you carry first", load("res://scripts/gadgets/gadgets.gd").knows(p, "spike") and p.inventory_component.count("book_spike") == 0)
			var d: Dictionary = pr.to_dict()
			pr.from_dict({})
			check("(a fresh captain has no books)", not B.has_read(pr, "manual_grip"))
			pr.from_dict(d)
			check("the shelf is saved with the captain", B.has_read(pr, "manual_grip") and B.has_read(pr, "book_spike") and B.count(pr) == 5)
			check("...and the manual's perk with it", is_equal_approx(pr.stat("damage_pct") - dmg0, 0.03))
			return TK.done(fails)
	step += 1
	return false
