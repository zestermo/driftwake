extends SceneTree
## No rival ship where none may come (1.30, docs/v1_30_plan.md "Rival crews"): the capital, the canal city and the
## stronghold never get a crew planned (RivalWatch.decide), and a ship already on her way turns back when the
## captains sail on to such a place.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var ship
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
	var RS = load("res://scripts/ai/rival_ship.gd")
	var RA = load("res://scripts/ai/rival_arrival.gd")
	var gm := root.get_node("GameManager")
	var w = gm.rival_watch
	match step:
		0:
			p = stage.player
			gm.rivals.clear()
			var pl: Dictionary = w.plan()
			var chain = load("res://scripts/world/chain.gd").make(4242, Vector2.ZERO, Vector2(0, -1))
			var capital: Dictionary = chain.nodes.filter(func(n): return n.get("capital", false))[0]
			var canal: Dictionary = chain.nodes.filter(func(n): return n.get("canal", false))[0]
			for n in [capital, canal, chain.stronghold]:
				w.decide(n, int(n["id"]))
				check("no crew planned at %s (role %s)" % [n["name"], n["role"]], int(pl["pending"]) == -1)
			RS.lane_m = 100.0
			RA.start(self, "brine_wolves", p.global_position + Vector3(40, 0, 0), Vector3.RIGHT, func(): return p)
			until = TK.wait_ticks(3)
		1:
			ship = RS.of(self)
			check("a ship on her way in", ship != null and not ship.leaving)
			var chain = load("res://scripts/world/chain.gd").make(4242, Vector2.ZERO, Vector2(0, -1))
			w.decide(chain.stronghold, int(chain.stronghold["id"]))
			until = TK.wait_ticks(3)
		2:
			check("...turns back when the captains sail on to the stronghold", ship.leaving and RA.of(self) == null)
			check("...and no meeting starts", get_first_node_in_group("rival_encounter") == null)
			RS.lane_m = RS.LANE
			gm.rivals.clear()
			return TK.done(fails)
	step += 1
	return false
