extends SceneTree
## The woods round Brinehollow (StarterIsland._plant_woods): hundreds of trees and their undergrowth on the eastern hill
## and round the town, round the farmland and down to the south-east, none on a path, a lane, the stair, a door's
## way, a chest, a burrow, a field or the orchard; the harbour still sees the pagoda and the lighthouse past them;
## they go into the vegetation's draws already there.
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
			var farm: Vector2 = isl.FARM
			var round_farm := trees.filter(func(t): return Vector2(t[0].origin.x, t[0].origin.z).distance_to(farm) > 50.0 and Vector2(t[0].origin.x, t[0].origin.z).distance_to(farm) < 130.0)
			var south_east := trees.filter(func(t): return t[0].origin.x > 0.0 and t[0].origin.z > 150.0)
			print("   %d round the farmland, %d in the south-east; built in %d ms (+%d committing)" % [round_farm.size(), south_east.size(), isl.build_ms["woods"], isl.build_ms["vegetation"]])
			check("woods round the farmland and down to the south-east", round_farm.size() >= 250 and south_east.size() >= 100)
			var kf = load("res://scripts/island/kit/kit_farm.gd")
			var in_fields := trees.filter(func(t): return (isl.FIELDS + [isl.ORCHARD]).any(func(f): return kf.inside(f, Vector2(t[0].origin.x, t[0].origin.z), 3.0)))
			check("none in a field or the orchard (%d)" % in_fields.size(), in_fields.is_empty())
			var keep: Dictionary = isl._woods_keep()
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
