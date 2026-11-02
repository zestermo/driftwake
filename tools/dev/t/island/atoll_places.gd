extends SceneTree
## The coral atoll's places for the chain's set pieces (scripts/island/themes/atoll_places.gd): a wreck on the reef flat
## (her chest, one sunk beside her, wreckers on the beach above), a pearl bed in the lagoon (oysters to pry, the divers'
## raft and a diver), the blue hole dressed (coral gardens round its lip, a drowned shrine and a chest on its floor).
## Each forced on an atoll, planned without an error, built.
const TK := preload("res://tools/dev/test_kit.gd")
## [set piece, the atoll's place]
const CASES := [["giant_skeleton", "atoll_wreck"], ["cenote", "atoll_pearls"], ["volcano_vent", "atoll_hole"]]
var stage
var fails := 0


class ErrorLog extends Logger:
	var errors: Array = []

	func _log_error(_function: String, _file: String, _line: int, code: String, rationale: String, _editor_notify: bool, _error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		errors.append(rationale if rationale != "" else code)


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _process(_d: float) -> bool:
	if not stage.up:
		return false
	var IT = load("res://scripts/island/themes/island_themes.gd")
	var CH = load("res://scripts/world/chain.gd")
	var KL = load("res://scripts/island/kit/kit_landmarks.gd")
	var v = IT.of("atoll")
	for ci in range(CASES.size()):
		var piece: String = CASES[ci][0]
		var kind: String = CASES[ci][1]
		var c = CH.make(7 + ci, Vector2.ZERO, Vector2(0, -1))
		var n: Dictionary = c.node(int(c.start_next[0])).duplicate(true)
		n["theme"] = "atoll"
		n["setpiece"] = piece
		n["landmark_count"] = 0
		n.merge({"beast": v.bosses[0], "beast_look": 0, "beast_name": v.beasts[v.bosses[0]]["names"][0], "minis": [v.minis[0]], "roamer": v.roamers[0]}, true)
		var isl = load("res://scripts/island/gen_island.gd").new()
		var errlog := ErrorLog.new()
		OS.add_logger(errlog)
		isl.prepare(n)
		OS.remove_logger(errlog)
		check("%s: planned without an error %s" % [kind, errlog.errors], errlog.errors.is_empty())
		var pl: Array = isl.places.filter(func(e): return e["kind"] == kind)
		check("%s: the %s became it" % [kind, piece], pl.size() == 1)
		if pl.is_empty():
			isl.free()
			continue
		isl.name = "Atoll%d" % ci
		stage.add_child(isl)
		for s in KL.steps(isl):
			if s[0] == kind:
				s[1].call()
		var node: Node3D = isl.get_node("Place_" + kind)
		var bags := node.find_children("*", "LootBag", true, false).size()
		match kind:
			"atoll_wreck":
				var at: Vector2 = pl[0]["at"]
				check("%s: aground on the reef flat in shallow water (%.1f m)" % [kind, isl.hv(at)], isl.hv(at) < 0.0 and isl.hv(at) > -2.5)
				check("%s: her hull, a chest aboard and one sunk (%d)" % [kind, bags], node.get_node_or_null("Wreck") != null and bags >= 2)
				check("%s: wreckers camped above her" % kind, isl.get_node_or_null("WreckCrew") != null)
			"atoll_pearls":
				check("%s: oysters on the bottom (%d)" % [kind, node.find_children("Oysters_*", "", true, false).size()], node.find_children("Oysters_*", "", true, false).size() >= 4)
				check("%s: the divers' raft and a diver" % kind, node.get_node_or_null("Raft") != null and node.find_children("*", "NPC", true, false).size() == 1)
			"atoll_hole":
				var hole: Array = isl.land_plan["hole"]
				check("%s: the hole is deep (%.0f m)" % [kind, isl.hv(hole[0])], isl.hv(hole[0]) < -9.0)
				check("%s: coral gardens round it, a shrine and chests on its floor (%d)" % [kind, bags], node.find_children("Reef_*", "", true, false).size() >= 3 and node.find_children("Ruin_*", "", true, false).size() == 1 and bags >= 2)
		check("%s: a spear spot there" % kind, kind == "atoll_hole" or node.find_children("SpearSpot*", "", true, false).size() >= 1)
		isl.queue_free()
	return TK.done(fails)
