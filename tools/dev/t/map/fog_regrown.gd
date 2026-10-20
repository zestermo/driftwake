extends SceneTree
## The held map's fog of war when the chain is rebuilt under the same island key (a new chain seed): the stored
## grid of the old island is the wrong size, so it counts as no fog, and the next look starts a fresh grid.
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
			isle.setup(3, 110.0)
			isle.add_to(self)
			d = load("res://scripts/map/map_isles.gd").at(self, Vector2.ZERO)
			var stale := PackedByteArray()
			stale.resize(16)
			stale.fill(255)
			gm.fog["isle3"] = stale
			check("another island's grid under the key shows no fog seen", not MF.seen(gm, d, Vector2.ZERO))
			until = TK.wait_secs(1.2)
		1:
			var n := int(d["n"])
			check("the captain's look starts a fresh grid for this island", (gm.fog["isle3"] as PackedByteArray).size() == n * n)
			check("...with the ground under them uncovered", MF.seen(gm, d, Vector2.ZERO))
			check("...and none of the old grid's cells carried over", not MF.seen(gm, d, Vector2(90, 90)))
			return TK.done(fails)
	step += 1
	return false
