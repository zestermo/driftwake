extends SceneTree
## The quick-item key (E): held, it opens the item wheel (not at once: a tap stays a tap) with every food and
## drink carried; letting go on the biscuit selects it without eating anything. A tap of E then eats the biscuit,
## and when the biscuits run out the selection moves on to the rum.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var w
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


func point_at(i: int) -> void:
	var a: float = TAU * i / w.entries.size()
	var mm := InputEventMouseMotion.new()
	mm.relative = Vector2(sin(a), -cos(a)) * 90.0
	mm.screen_relative = mm.relative
	w._input(mm)


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			w = p.item_wheel
			p.inventory_component.add_item(ItemDB.get_item("biscuit"), 2)
			check("the starting rum is the quick item", p.inventory_component.quick == "rum")
			p.health_component.current_health = 30.0
			Input.action_press("quick_item")
			until = TK.wait_ticks(1)
		1:
			check("a short press doesn't open the wheel", not w.is_open())
			until = TK.wait_secs(0.4)
		2:
			check("held, E opens the item wheel", w.is_open())
			check("...with the rum and the biscuits on it (%s)" % str(w.entries), w.entries == ["rum", "biscuit"])
			point_at(w.entries.find("biscuit"))
			check("pointing picks the biscuit", w._pick == w.entries.find("biscuit"))
			Input.action_release("quick_item")
			until = TK.wait_ticks(3)
		3:
			check("letting go selects the biscuit", not w.is_open() and p.inventory_component.quick == "biscuit")
			check("...without eating anything", p.inventory_component.count("biscuit") == 2 and p.inventory_component.count("rum") == 3 and not p.is_using_item())
			check("the selected biscuits are off the bag grid", not p.inventory_component.bag_view().has(p.inventory_component.find_index("biscuit")))
			TK.act("quick_item")
			until = TK.wait_secs(0.2)
		4:
			check("a tap of E eats the biscuit (%s)" % p.body_model.current_action(), p.body_model.current_action() == "bite" and p.inventory_component.count("biscuit") == 1)
			p.inventory_component.remove_item(ItemDB.get_item("biscuit"), 1)
			check("out of biscuits: the rum is the quick item again", p.inventory_component.quick == "rum")
			return TK.done(fails)
	step += 1
	return false
