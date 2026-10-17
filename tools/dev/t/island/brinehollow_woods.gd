extends SceneTree
## The woods round Brinehollow (StarterIsland._plant_woods): hundreds of trees and their undergrowth on the eastern hill
## and round the town, none on a path, a lane, the stair, a door's way, a chest or a burrow; the harbour still sees
## the pagoda and the lighthouse past them; they go into the vegetation's draws already there.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var step := 0
var until := 0
var fails := 0
var isl


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
			load("res://scripts/world/actor_sleep.gd").enabled = false
			isl = load("res://scripts/island/starter_island.gd").new()
			isl.name = "Brinehollow"
			isl.position = Vector3(0, 0, 9000)
			stage.add_child(isl)
			isl.build(42)
			until = TK.wait_ticks(2)
		1:
			var trees: Array = isl.woods["trees"]
			var east := trees.filter(func(t): return t[0].origin.x > 30.0 and t[0].origin.x < 130.0 and t[0].origin.z > -80.0 and t[0].origin.z < 70.0)
			print("   %d trees, %d on the eastern hill, %d undergrowth" % [trees.size(), east.size(), isl.woods["under"]])
			check("the woods stand round the town", trees.size() >= 350 and isl.woods["under"] >= 800)
			check("they climb the eastern hill", east.size() >= 150)
			var keep: Array = isl._woods_keep()
			var bad := trees.filter(func(t):
				var p := Vector2(t[0].origin.x, t[0].origin.z)
				return isl._path_dist(p, isl.paths.size(), 0, true) < 3.0 or isl._near_any(p, keep))
			check("none on a path, a lane, the stair, a door's way, a chest or a burrow (%d)" % bad.size(), bad.is_empty())
			var eye: Vector2 = isl.harbour.dock_point(isl.DOCK_LENGTH - 4.0)
			var from := Vector3(eye.x, 8.0, eye.y)
			var pagoda: Vector3 = isl.town_spots["pagoda"].position + Vector3(0, 8.0, 0)
			var light := Vector3(isl.HILL.x, isl.hv(isl.HILL) + 12.0, isl.HILL.y)
			for e in [["pagoda", pagoda], ["lighthouse", light]]:
				var hid := trees.filter(func(t): return (t[0] * (t[1] as Mesh).get_aabb()).intersects_segment(from, e[1]) != null)
				check("the harbour still sees the %s (%d trees in the way)" % [e[0], hid.size()], hid.is_empty())
			var added: int = isl.woods["keys_after"] - isl.woods["keys_before"]
			check("the new plants go into the draws already there (%d new squares)" % added, added <= 8)
			isl.queue_free()
			return TK.done(fails)
	step += 1
	return false
