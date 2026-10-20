extends SceneTree
## Fishing: with a rod in the equipment slot at the water's edge, F's prompt reads "Cast your line"; F casts
## (the cast plays, the bobber flies out and floats on the waves, the line drawn), a bite dips it, F inside the
## window reels in and lands the catch (a fish-tagged ingredient in the bag, Fishing mastery), and the line's
## put away. With the rod hidden on the body it all still works.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var rod
var xp0 := 0
var bag0 := 0
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


func catches() -> int:
	var n := 0
	for id in ["fish", "crab_meat", "oyster", "sea_urchin"]:
		n += p.inventory_component.count(id)
	return n


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			rod = p.fish_rod
			var it = ItemDB.get_item("rod_bamboo")
			p.inventory_component.add_item(it, 1)
			p.equip_gear_from_bag(p.inventory_component.find_index("rod_bamboo"))
			p.show_equipment(false)
			p.global_position = Vector3(stage.SHORE_X - 1.2, stage.GROUND_Y + 0.1, 0.0)
			p.player_model.rotation.y = -PI * 0.5
			p.reset_physics_interpolation()
			xp0 = fish_xp()
			bag0 = catches()
			until = TK.wait_secs(0.6)
		1:
			check("hidden, the rod isn't drawn on the back", rod._back != null and not rod._back.visible)
			check("at the water's edge with a rod: F's prompt is Cast your line", p.interaction_component._cast and rod.cast_ready != Vector3.INF)
			TK.press("interact")
			until = TK.wait_ticks(2)
		2:
			TK.release("interact")
			check("F casts (%s, %s)" % [p.current_state_name(), p.body_model.current_action()], p.current_state_name() == "Fish" and p.body_model.current_action() == "rod_cast")
			until = TK.wait_secs(0.45)
		3:
			check("...the rod's in both hands", rod._parts["butt"].visible and rod._parts["tip"].visible)
			check("...the hands on it: the right at the fore grip (%.2f m), the left at the butt (%.2f m)" % [hand_gap(true), hand_gap(false)], hand_gap(true) < 0.12 and hand_gap(false) < 0.12)
			until = TK.wait_secs(0.5)
		4:
			check("the bobber flies out (%s)" % rod.phase, rod.phase in ["flight", "float"] and rod._bob.visible)
			until = TK.wait_secs(1.6)
		5:
			var wave: float = root.get_node("Ocean").get_wave_height(rod._bob.global_position)
			check("...and floats on the waves (%.2f vs %.2f)" % [rod._bob.global_position.y, wave], rod.phase == "float" and absf(rod._bob.global_position.y - wave) < 0.15)
			check("...out past the shore (%.1f m off)" % (rod._bob.global_position.x - stage.SHORE_X), rod._bob.global_position.x > stage.SHORE_X + 1.0)
			check("...the line drawn to it, the body holding the wait", rod._line.visible and p.body_model.current_action() == "rod_wait" and state().phase == "wait")
			state()._bite_at = state()._t
			until = TK.wait_ticks(3)
		6:
			check("a bite: the float goes under (%s)" % state().phase, state().phase == "bite" and rod.phase == "bite")
			until = TK.wait_ticks(6)
		7:
			check("...dipped below the surface", rod._bob.global_position.y < root.get_node("Ocean").get_wave_height(rod._bob.global_position) - 0.05)
			TK.press("interact")
			until = TK.wait_ticks(2)
		8:
			TK.release("interact")
			check("F in the window reels in (%s)" % p.body_model.current_action(), state().phase == "reel" and p.body_model.current_action() == "rod_reel")
			until = TK.wait_secs(1.5)
		9:
			check("landed: the catch on the line, held up (%s)" % p.body_model.current_action(), p.body_model.current_action() == "rod_land" and rod._fish.visible)
			until = TK.wait_secs(1.3)
		10:
			check("...in the bag (%d)" % (catches() - bag0), catches() > bag0)
			check("...Fishing mastery for it (%d)" % (fish_xp() - xp0), fish_xp() > xp0)
			check("...the line put away, back on your feet (%s)" % p.current_state_name(), p.current_state_name() in ["Idle", "Move"] and not rod._bob.visible and not rod._line.visible and rod.phase == "")
			return TK.done(fails)
	step += 1
	return false


func fish_xp() -> int:
	var pr = p.progression
	var m: Dictionary = pr.mastery_of("fish")
	var total := int(m["xp"])
	for lv in range(1, int(m["lv"])):
		total += pr.mastery_to_next(lv)
	return total


func hand_gap(right: bool) -> float:
	var b = p.body_model
	var on: Vector3 = b.torso.global_transform * ((rod._parts["butt"] as Node3D).transform * (rod.HAND_R if right else rod.HAND_L))
	return ((b.hand_r if right else b.hand_l) as Node3D).global_position.distance_to(on)
