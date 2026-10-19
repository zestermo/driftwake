extends SceneTree
## A galley meal's buff and its time: eating Fisherman's Stew (the slurp, from the quick slots' use) gives +20
## max health for 15 minutes, shown on the HUD with its time left; Ship's Cook (meal_time_pct) makes the next
## one last 25% longer, Master Chef (meal_power_pct) 20% stronger; a newer meal replaces it; the buff is
## saved with the captain; it wears off on game time and max health goes back.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var pr
var step := 0
var until := 0
var fails := 0
var mh0 := 0.0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {})


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
			pr = p.progression
			mh0 = p.health_component.max_health
			var stew: ItemData = ItemDB.get_item("fish_stew")
			check("Fisherman's Stew is a meal", stew != null and stew.meal == "fish_stew" and stew.is_consumable())
			p.inventory_component.add_item(stew, 2)
			p.heal_cd = 0.0
			p.use_item(stew)
			check("it's slurped from a bowl", p.body_model.current_action() == "slurp")
			until = TK.wait_secs(1.4)
		1:
			check("eaten: the stew's buff is on", pr.meal == "fish_stew")
			check("+20 max health (%.0f -> %.0f)" % [mh0, p.health_component.max_health], is_equal_approx(p.health_component.max_health, mh0 + 20.0))
			check("for 15 minutes (%.0f s)" % pr.meal_left, pr.meal_left > 15.0 * 60.0 - 3.0 and pr.meal_left <= 15.0 * 60.0)
			var t: String = stage.hud.meal_text()
			check("the HUD shows it with its time: '%s'" % t, t.begins_with("Fisherman's Stew") and (t.ends_with("15:00") or t.contains("14:5")))
			var d: Dictionary = pr.to_dict()
			pr.meal = ""
			pr.from_dict(d)
			check("saved with the captain", pr.meal == "fish_stew" and pr.meal_left > 890.0)
			pr.owned["ck_ship"] = true
			pr.owned["ck_chef"] = true
			pr.eat_meal("peppered_boar")
			check("a newer meal replaces it: Peppered Boar", pr.meal == "peppered_boar" and is_equal_approx(p.health_component.max_health, mh0))
			check("Ship's Cook: 25%% longer (%.0f s)" % pr.meal_left, is_equal_approx(pr.meal_left, 12.0 * 60.0 * 1.25))
			check("Master Chef: 20%% stronger (+%.1f%% damage)" % (pr.stat("damage_pct") * 100.0), is_equal_approx(pr.stat("damage_pct"), 0.08 * 1.2))
			pr.eat_meal("fish_stew")
			pr.meal_left = 1.0
			until = TK.wait_secs(1.5)
		2:
			check("it wears off on game time", pr.meal == "" and stage.hud.meal_text() == "")
			check("...and max health goes back (%.0f)" % p.health_component.max_health, is_equal_approx(p.health_component.max_health, mh0))
			return TK.done(fails)
	step += 1
	return false
