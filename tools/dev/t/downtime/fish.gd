extends SceneTree
## Fishing aboard (anchored): you go to the rail, facing out with a rod over the side; each bite is a catch
## (an ingredient tagged fish into the bag) or one that got away, and either builds Fishing; Fishing's perks
## (fish_* keys) bring the bites sooner.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var pr
var ship
var DT
var every0 := 0.0
var bites := 0
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


func fish_xp() -> int:
	var m: Dictionary = pr.mastery_of("fish")
	var total := int(m["xp"])
	for lv in range(1, int(m["lv"])):
		total += pr.mastery_to_next(lv)
	return total


func caught() -> int:
	var n := 0
	for st in p.inventory_component.items:
		if st.item.ingredient == "fish":
			n += st.quantity
	return n


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			pr = p.progression
			ship = stage.ship
			DT = load("res://scripts/game/downtime.gd")
			ship.set_anchored(true)
			p.global_position = ship.global_transform * Vector3(0.8, ship.DECK_Y + 0.3, -1.0)
			p.reset_physics_interpolation()
			until = TK.wait_ticks(10)
		1:
			every0 = DT.every(p, "fish")
			DT.start(p, "fish")
			until = TK.wait_secs(0.6)
		2:
			var l: Vector3 = ship.global_transform.affine_inverse() * p.global_position
			var out: Vector3 = ship.global_basis.inverse() * -p.player_model.global_basis.z
			check("fishing: at the starboard rail (x %.2f)" % l.x, l.x > HullBuilder.half_width(l.z) - 1.0 and p.body_model.current_action() == "dt_fish")
			check("...facing out over the side (%.2f)" % out.x, out.x > 0.9)
			check("...a rod in hand", p.body_model.get_node_or_null("DowntimeProps") != null)
			until = TK.wait_ticks(1)
		3, 4, 5, 6, 7, 8:
			if step > 3:
				bites += 1
			p.state_machine.current_state._earned = DT.every(p, "fish") - 0.05
			until = TK.wait_secs(0.25)
		9:
			print("   after %d bites: %d fish-tagged, fishing xp %d" % [bites, caught(), fish_xp()])
			check("bites build Fishing (%d)" % fish_xp(), fish_xp() >= bites * DT.FISH_LOST_XP)
			check("...and land fish-tagged catches (%d)" % caught(), caught() >= 1)
			check("...still fishing", p.current_state_name() == "Downtime")
			while pr.mastery_level("fish") < 2:
				pr.add_mastery("fish", pr.mastery_to_next(pr.mastery_level("fish")))
			check("Patient Line (fish_bite_pct): bites come sooner (%.1f -> %.1f s)" % [every0, DT.every(p, "fish")], DT.every(p, "fish") < every0 - 1.0)
			p.state_machine.force_state("Idle", {})
			return TK.done(fails)
	step += 1
	return false
