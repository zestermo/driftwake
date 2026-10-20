extends SceneTree
## Alt+F10 (Player.debug_to_capital): the crew arrives at the royal capital and, once it's built, the ship lies at
## its berth and the captain stands on the quay beside her.
const TK := preload("res://tools/dev/test_kit.gd")
const AT := Vector3(0, 0, 4000)
var stage
var step := 0
var until := 0
var fails := 0
var w
var isl
var id := -1


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
	var P = load("res://scripts/island/capital_plan.gd")
	match step:
		0:
			w = load("res://tools/dev/t/capital/_world.gd").take_over(stage, 77)
			until = TK.wait_ticks(2)
		1:
			id = w.c.capital_id()
			stage.player.debug_to_capital()
			until = TK.wait_ticks(10)
		2:
			check("the crew is at the capital", int(root.get_node("GameManager").chain_at) == id)
			check("nobody's moved before it stands", stage.player.global_position.distance_to(AT) > 1000.0)
			isl = w.build_capital(AT)
			until = TK.wait_secs(1.5)
		3:
			var sp: Vector3 = isl.harbour_spawn()
			var pp: Vector3 = stage.player.global_position
			check("the captain stands on the quay by the ship (%s, %s)" % [pp, sp], Vector2(pp.x - sp.x, pp.z - sp.z).length() < 1.0 and absf(pp.y - P.QUAY_Y) < 0.3)
			var moor: Array = isl.mooring()
			check("the ship lies at the berth", (stage.ship as Node3D).global_position.distance_to(moor[0]) < 3.0)
			return TK.done(fails)
	step += 1
	return false
