extends SceneTree
## A rival crew's ship arrives (1.30, docs/v1_30_plan.md "Rival crews"; RivalArrival, RivalShip): she sails in from
## out at sea, brakes and anchors off the dock, the crew rows ashore and only then does the meeting start (from the
## dock); when it's over she weighs and sails back out. (A short lane: RivalShip.lane_m.)
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var a
var ship
var anchor := Vector3.ZERO
var d0 := 0.0
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


func flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	var RS = load("res://scripts/ai/rival_ship.gd")
	var RA = load("res://scripts/ai/rival_arrival.gd")
	match step:
		0:
			p = stage.player
			root.get_node("GameManager").rivals.clear()
			RS.lane_m = 100.0
			var dock: Vector3 = p.global_position + Vector3(40, 0, 0)
			anchor = RS.lane(dock, Vector3.RIGHT)[1]
			a = RA.start(self, "gilded_gulls", dock, Vector3.RIGHT, func(): return p)
			until = TK.wait_ticks(3)
		1:
			ship = RS.of(self)
			check("their ship is there, on every screen's call (%s)" % str(ship), ship != null)
			d0 = flat(ship.global_position).distance_to(anchor)
			check("...out at sea, not at her anchorage (%.0f m off)" % d0, d0 > 90.0)
			check("...out past the dock, seaward", ship.global_position.x > p.global_position.x + 100.0)
			check("...riding on the water (y %.2f)" % ship.global_position.y, absf(ship.global_position.y) < 3.0)
			check("nobody's come ashore yet (%s)" % a.phase, a.phase == "sail" and get_first_node_in_group("rival_encounter") == null)
			until = TK.wait_secs(RS.leg_secs() * 0.5)
		2:
			var d: float = flat(ship.global_position).distance_to(anchor)
			check("she sails in (%.0f m -> %.0f m)" % [d0, d], d < d0 - 30.0)
			check("...not anchored yet, and still no meeting", not ship.anchored() and get_first_node_in_group("rival_encounter") == null)
			until = TK.wait_secs(RS.leg_secs() * 0.5 + 0.5)
		3:
			var d: float = flat(ship.global_position).distance_to(anchor)
			check("she reaches her anchorage and stops (%.2f m off)" % d, ship.anchored() and d < 0.5)
			var fwd: Vector3 = -ship.global_basis.z
			check("...lying broadside to the shore (bow %.2f along the sea)" % absf(fwd.x), absf(fwd.x) < 0.2)
			check("...and the crew's rowing ashore: the meeting waits (%s)" % a.phase, a.phase == "row" and get_first_node_in_group("rival_encounter") == null)
			until = TK.wait_secs(RA.ROW_S + 1.0)
		4:
			var e = get_first_node_in_group("rival_encounter")
			check("then they come, after she's anchored (%s)" % a.phase, e != null and a.phase == "meet" and a.encounter == e)
			if e == null:
				return TK.done(fails)
			var cap = e.rivals[-1]
			check("...the Gilded Gulls, up from the dock's side", e.crew_id == "gilded_gulls" and (cap.global_position - p.global_position).x > 15.0)
			e.result = "won"
			e._gone()
			until = TK.wait_ticks(3)
		5:
			check("the visit over, she weighs anchor", ship.leaving and not ship.anchored())
			until = TK.wait_secs(RA.SAIL_OFF_S + 6.0)
		6:
			check("...and sails back out to sea (%.0f m off)" % flat(ship.global_position).distance_to(anchor),
				is_instance_valid(ship) and flat(ship.global_position).distance_to(anchor) > 20.0)
			RS.lane_m = RS.LANE
			return TK.done(fails)
	step += 1
	return false
