extends SceneTree
## The capital's catacombs (1.27, CityUndercity): four trapdoors in rolled lanes, one per tunnel, each on the street;
## climbing down puts you on the vaults' floor in the sealed pocket; the thieves' stash and two caches are down
## there, and no water; climbing the ladder brings you out beside the trapdoor you came down.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var w
var isl
var u
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
	var p = stage.player
	match step:
		0:
			w = load("res://tools/dev/t/capital/_world.gd").take_over(stage, 4242)
			until = TK.wait_ticks(2)
		1:
			isl = w.build_capital(Vector3(900, 0, 900))
			until = TK.wait_ticks(6)
		2:
			u = isl.undercity
			check("the undercity is built", u != null)
			if u == null:
				return TK.done(fails)
			check("a trapdoor per tunnel (%d)" % u.hatches.size(), u.hatches.size() == 4)
			var P = load("res://scripts/island/capital_plan.gd")
			check("...each in a lane or alley", u.hatches.values().all(func(h): return P.rolled().any(func(fl): return (fl[1] as Rect2).has_point(h[0]))))
			var bags: int = u.find_children("*", "LootBag", true, false).size()
			check("the den's stash and two caches down there (%d)" % bags, bags == 3)
			check("lanterns, and dry (no cistern water)", u.find_children("*", "OmniLight3D", true, false).size() == 3 and u.get_node_or_null("Water") == null)
			isl.city.get_node("Hatch_n/Down").interacted.emit(p)
			until = TK.wait_secs(1.0)
		3:
			var floor_y: float = u.global_position.y
			check("down the trapdoor: on the vaults' floor (%.1f, the floor %.1f)" % [p.global_position.y, floor_y], absf(p.global_position.y - floor_y) < 0.6 and p.is_on_floor())
			u.get_node("Up_n").interacted.emit(p)
			until = TK.wait_ticks(4)
		4:
			var h: Array = u.hatches["n"]
			var at: Vector3 = isl.city.to_global(Vector3((h[0] as Vector2).x, float(h[1]), (h[0] as Vector2).y))
			check("up the ladder: out beside the trapdoor (%.1f m)" % p.global_position.distance_to(at), p.global_position.distance_to(at) < 3.0)
			return TK.done(fails)
	step += 1
	return false
