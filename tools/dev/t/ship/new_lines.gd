extends SceneTree
## The new upgrade lines do what they say: the copper bottom (faster, less from reefs), the bow chaser (a
## gun firing ahead, kept out of broadsides, harder and further at 2-3), the crow's nest (the lookout's range,
## the flag up its staff), lanterns (faster at night), railings (steady when rammed, a boarder fewer), the
## tangerine grove (pick what's ripe, it ripens again), the galley (more of each restocked) and the hold
## (more bag slots).
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var ship
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


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			ship = stage.ship
			ship.apply_kit({"copper": 3})
			check("coppered: +6%% speed, 60%% less from reefs (%.2f, %.2f)" % [ship._top_k, ship._reef_k], is_equal_approx(ship._top_k, 1.06) and is_equal_approx(ship._reef_k, 0.4))
			ship.apply_kit({"chaser": 1})
			var bow = ship.get_node_or_null("ShipModel/CannonBow")
			check("a bow chaser, firing ahead", bow != null and ship.cannons.has(bow) and (bow.global_basis.z).dot(ship.global_basis.z) > 0.99)
			check("...not one of the broadside guns", not ship.side_cannons(1.0).has(bow) and not ship.side_cannons(-1.0).has(bow))
			var d1: float = bow.hull_damage
			ship.apply_kit({"chaser": 3, "guns": 1})
			bow = ship.get_node("ShipModel/CannonBow")
			print("   chaser 3: %.1f hull dmg, %.1f m/s, fitted %d" % [bow.hull_damage, bow.muzzle_speed, bow.fitted])
			check("...harder and further at 3, banded and long", bow.hull_damage > d1 * 1.3 and is_equal_approx(bow.hull_damage, 30.0 * 1.35) and bow.muzzle_speed > 46.0 * 1.05 and bow.fitted == 5)
			check("...the broadside guns don't get the chaser's levels", is_equal_approx(ship.cannons[0].hull_damage, 31.5))
			ship.apply_kit({})
			check("...and gone with the line", ship.get_node_or_null("ShipModel/CannonBow") == null and ship.cannons.size() == 4)
			ship.apply_kit({"nest": 3})
			check("the crow's nest: the lookout sees 500 m, the flag's up its staff", is_equal_approx(ship.lookout, 500.0) and ship._flag_node.position.y > 0.5)
			ship.apply_kit({"lanterns": 3, "rails": 2})
			check("lanterns: +9% at night; rails 2: a ram doesn't throw the crew", is_equal_approx(ship._night_k, 0.09) and is_equal_approx(ship.steady, 1.0))
			ship.apply_kit({"rails": 3})
			check("boarding nets: a boarder fewer", int(load("res://scripts/ship/ship_lines.gd").total(ship.kit, "board")) == 1)
			ship.apply_kit({"chest": 3})
			check("the hold: +6 bag slots (%d)" % p.inventory_component.slots(), p.inventory_component.slots() == p.inventory_component.max_slots + 6)
			ship.apply_kit({"galley": 3})
			var rum = load("res://resources/items/rum.tres")
			p.inventory_component.remove_item(rum, p.inventory_component.count("rum"))
			root.get_node("GameManager").restock(p)
			check("the galley at 3 stocks six of each (%d rum)" % p.inventory_component.count("rum"), p.inventory_component.count("rum") == 6)
			ship.apply_kit({"grove": 3})
			var parts = ship.parts
			check("three trees in the grove, a tangerine on each", parts.grove_zone != null and parts.ripe == 3 and parts.grove_zone.prompt_text.contains("3"))
			parts.pick(p)
			check("picked: three tangerines, nothing left", p.inventory_component.count("tangerine") == 3 and parts.ripe == 0 and not parts._fruit[0].visible)
			parts._ripen()
			check("...they ripen again (one on each tree)", parts.ripe == 3 and parts._fruit[2].visible)
			parts._ripen()
			parts._ripen()
			check("...up to two a tree", parts.ripe == 6)
			ship.apply_kit({})
			return TK.done(fails)
	step += 1
	return false
