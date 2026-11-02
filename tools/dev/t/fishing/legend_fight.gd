extends SceneTree
## A legendary on the line (1.28): FishFight alone - a steady angler (reel while it rests, ease off while it runs or
## the line's tight) lands even the strongest within a minute and a half, always holding snaps the line, never
## reeling throws the hook. In play: a legendary on the hook starts the fight (its bars on screen, the float still
## down); wound in, it's landed into the bag, in the journal (caught once, a length, where) and teaches the legend's
## recipe; a journal page completed pays its reward once.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "water": true})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func state():
	return p.state_machine.get_node("Fish")


## Seconds a strategy takes against `pull` (or -1 and the result when it loses).
func play(pull: float, strat: Callable, s: int) -> Array:
	var f := FishFight.new(pull, s)
	var t := 0.0
	while f.result == "" and t < 300.0:
		f.tick(1.0 / 60.0, strat.call(f))
		t += 1.0 / 60.0
	return [t if f.result == "landed" else -1.0, f.result]


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			var steady := func(f: FishFight): return not f.running and f.tension < 0.85 or f.tension < 0.15
			var worst := 0.0
			var lost := 0
			for s in range(10):
				var r := play(1.3, steady, s)
				if float(r[0]) < 0.0:
					lost += 1
				worst = maxf(worst, float(r[0]))
			check("a steady angler lands the strongest legendary every time (lost %d, slowest %.0f s)" % [lost, worst], lost == 0 and worst < 90.0)
			var r2 := play(1.0, steady, 3)
			check("a gentler legendary comes in faster (%.0f s)" % float(r2[0]), float(r2[0]) > 0.0 and float(r2[0]) < worst)
			check("always holding snaps the line", play(1.0, func(_f): return true, 1)[1] == "snapped")
			check("never reeling throws the hook", play(1.0, func(_f): return false, 1)[1] == "thrown")
			p = stage.player
			p.inventory_component.add_item(ItemDB.get_item("rod_driftwood"), 1)
			p.equip_gear_from_bag(p.inventory_component.find_index("rod_driftwood"))
			p.global_position = Vector3(stage.SHORE_X - 1.2, stage.GROUND_Y + 0.1, 0.0)
			p.player_model.rotation.y = -PI * 0.5
			p.reset_physics_interpolation()
			until = TK.wait_secs(0.5)
			step = 1
		1:
			p.fish()
			until = TK.wait_secs(2.0)
			step = 2
		2:
			state()._bite_at = state()._t
			until = TK.wait_ticks(3)
			step = 3
		3:
			check("a bite", state().phase == "bite")
			state().rig = "fish_jade_gar"
			TK.press("interact")
			until = TK.wait_ticks(2)
			step = 4
		4:
			check("a legendary on the hook starts the fight (%s)" % state().phase, state().phase == "fight" and state().fight != null)
			check("its bars are on screen", state()._hud != null and is_instance_valid(state()._hud))
			check("the float's still down", p.fish_rod.phase == "bite")
			# wind it the last of the way in
			state().fight.dist = 0.05
			state().fight.tension = 0.2
			until = TK.wait_ticks(10)
			step = 5
		5:
			TK.release("interact")
			check("landed, it comes in on the line (%s)" % state().phase, state().phase in ["reel", "land"] or p.current_state_name() != "Fish")
			until = TK.wait_secs(2.5)
			step = 6
		6:
			var pr = p.progression
			check("the Jade Gar's in the bag", p.inventory_component.count("fish_jade_gar") == 1)
			var e: Dictionary = pr.fish_log.get("fish_jade_gar", {})
			check("the journal has it: once, a length, where (%s)" % str(e), int(e.get("n", 0)) == 1 and float(e.get("best", 0.0)) > 1.0 and str(e.get("where", "")) != "")
			check("the legend's recipe is taught", Food.known(pr, FishTable.LEGEND_RECIPE))
			check("the fight's bars are gone", state()._hud == null)
			# a page: the jungle's others caught, the last one completes it
			var F = load("res://scripts/fishing/fishing.gd")
			var g0: int = p.inventory_component.count("gold")
			for id in ["fish_parrotfish", "fish_lionfish"]:
				F.record(p, id, p.global_position)
			check("a page part-done pays nothing", p.inventory_component.count("gold") == g0 and not pr.fish_pages.has("jungle"))
			F.record(p, "fish_tarpon", p.global_position)
			check("the jungle page done: 120 gold and glow bait", p.inventory_component.count("gold") == g0 + 120 and p.inventory_component.count("bait_glow") >= 6 and pr.fish_pages.has("jungle"))
			F.record(p, "fish_tarpon", p.global_position)
			check("...only once", p.inventory_component.count("gold") == g0 + 120 and int(pr.fish_log["fish_tarpon"]["n"]) == 2)
			var d: Dictionary = pr.to_dict()
			pr.fish_log = {}
			pr.fish_pages = {}
			pr.from_dict(d)
			check("the journal saves and loads", pr.fish_log.has("fish_jade_gar") and pr.fish_pages.has("jungle"))
			print("RESULT OK" if fails == 0 else "RESULT FAILED (%d)" % fails)
			quit(1 if fails else 0)
			step = 7
	return false
