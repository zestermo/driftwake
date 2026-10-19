extends SceneTree
## The fog of war is the crew's (no network: the messages are handed to Net as they'd arrive): a
## guest's uncovered ground and found spot reach the host, and a captain joining gets the host's fog
## and found spots with the world state, in place of their own.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var gm
var MF
var d: Dictionary
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
	match step:
		0:
			gm = root.get_node("GameManager")
			MF = load("res://scripts/map/map_fog.gd")
			var isle = load("res://tools/dev/map_stub_isle.gd").new()
			isle.setup(5, 110.0)
			# (out of the stage's captain's sight: only the guest looks)
			isle.position = Vector3(2000, 0, 0)
			isle.add_to(self)
			d = load("res://scripts/map/map_isles.gd").at(self, Vector2(2000, 0))
			until = TK.wait_ticks(2)
		1:
			var net := root.get_node("Net")
			var cells: PackedInt32Array = MF.cells_near(d, Vector2(-80, 0), 30.0)
			net._allr(net.time() - 1.0, "_all_fog", ["isle5", int(d["n"]), cells])
			net._allr(net.time() - 1.0, "_all_spot", ["isle5", "inside0", "The Roost", 2])
			check("(not yet: a guest's message waits its turn)", not MF.seen(gm, d, Vector2(-80, 0)))
			net._apply_events()
			check("a guest's uncovered ground reaches the host", MF.seen(gm, d, Vector2(-80, 0)) and not MF.seen(gm, d, Vector2(80, 0)))
			check("...and so does their found spot", MF.found(gm, "isle5", "inside0"))
			var state: Dictionary = net._world_state()
			gm.fog.clear()
			gm.charted.erase("spot:isle5:inside0")
			gm.charted["spot:isle5:site_camp"] = true
			MF.apply(gm, "isle5", int(d["n"]), MF.cells_near(d, Vector2(80, 0), 20.0))
			net._apply_world_sync(state)
			check("a joining captain gets the host's fog", MF.seen(gm, d, Vector2(-80, 0)))
			check("...in place of their own", not MF.seen(gm, d, Vector2(80, 0)))
			check("...and the host's found spots, not theirs", MF.found(gm, "isle5", "inside0") and not MF.found(gm, "isle5", "site_camp"))
			return TK.done(fails)
	step += 1
	return false
