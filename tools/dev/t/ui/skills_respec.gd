extends SceneTree
## The tree's refund in the skills menu: away from the ship's bunk there's no refund button; by the bunk the card
## shows one with the gold price; a first click only asks (the price in the line), a second pays the gold and puts
## every bought katana node back in the pool.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var gm
var sm
var p
var pr
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"weapon": "katana", "water": true, "ship": true})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func click(id: String) -> void:
	for h in sm._drawn:
		if h[1] == id:
			var ev := InputEventMouseButton.new()
			ev.button_index = MOUSE_BUTTON_LEFT
			ev.pressed = true
			ev.position = (h[0] as Rect2).get_center()
			sm._gui_input(ev)
			return
	check("%s is on screen" % id, false)


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			pr = p.progression
			pr.mastery_of("katana")["lv"] = 4
			pr.add_mastery("katana", pr.mastery_to_next(4))
			pr.buy("k_draw")
			root.size = Vector2i(1280, 720)
			root.get_node("Story").step = "done"
			gm = root.get_node("GameMenu")
			gm.open("skills")
			sm = gm._skills
			sm.set_tab("combat", "katana")
			until = TK.wait_ticks(4)
		1:
			check("Quick Draw bought: 9 of the katana's 11 points left", pr.owns("k_draw") and pr.pool("katana") == 9)
			check("away from the bunk: no refund button", not sm._drawn.any(func(h): return h[1] == "respec"))
			p.global_position = stage.ship.global_transform * (load("res://scripts/ship/ship.gd").BED_AT + Vector3(0.95, 0.1, 0.0))
			p.reset_physics_interpolation()
			p.inventory_component.add_item(ItemDB.get_item("gold"), 1000)
			until = TK.wait_ticks(4)
		2:
			var g0: int = p.inventory_component.count("gold")
			set_meta("g0", g0)
			check("by the bunk: a refund button", pr.can_respec() and sm._drawn.any(func(h): return h[1] == "respec"))
			click("respec")
			check("a first click asks, with the price (%s)" % sm._msg, sm._msg.contains("%d gold" % pr.respec_price()) and pr.owns("k_draw"))
			click("respec")
			check("a second pays: Quick Draw back in the pool, %d gold gone" % pr.respec_price(), not pr.owns("k_draw") and pr.pool("katana") == 11
				and p.inventory_component.count("gold") == g0 - pr.respec_price())
			until = TK.wait_ticks(3)
		3:
			check("nothing left to refund: the button's gone", not sm._drawn.any(func(h): return h[1] == "respec"))
			return TK.done(fails)
	step += 1
	return false
