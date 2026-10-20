extends SceneTree
## A chain island's long build work comes in slices (GenIsland.sliced): every piece once, in order, a few ms a step,
## the last step finishing whatever's left. A lair's nest on an island still being built hatches a bug a frame
## (all of them, each once), and all at once on a built one.
const TK := preload("res://tools/dev/test_kit.gd")
var GI
var NEST
var stage
var step := 0
var until := 0
var fails := 0
var done: Array = []
var isl: Node3D
var nest: Node3D
var nest2: Node3D


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _busy(us: int) -> void:
	var t0 := Time.get_ticks_usec()
	while Time.get_ticks_usec() - t0 < us:
		pass


func _bugs(n: Node) -> Array:
	return n.get_children().filter(func(c): return c.name.begins_with("B"))


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			GI = load("res://scripts/island/gen_island.gd")
			NEST = load("res://scripts/enemies/scuttlebug_nest.gd")
			var i := [0]
			var steps: Array = GI.sliced("work", 40, func() -> bool:
				done.append(i[0])
				_busy(1000)
				i[0] += 1
				return i[0] < 30)
			check("40 steps, all named for the work", steps.size() == 40 and steps.all(func(s): return s[0] == "work"))
			var t0 := Time.get_ticks_usec()
			(steps[0][1] as Callable).call()
			var ms := (Time.get_ticks_usec() - t0) / 1000.0
			check("the first step does a slice (%d of 30 pieces, %.1f ms)" % [done.size(), ms], done.size() >= 2 and done.size() < 10 and ms < GI.SLICE_US / 1000.0 + 3.0)
			(steps[1][1] as Callable).call()
			(steps[39][1] as Callable).call()
			check("the last step finishes the rest", done.size() == 30)
			for s in steps.slice(2, 39):
				(s[1] as Callable).call()
			check("every piece once, in order", done == range(30))
			isl = GI.new()
			isl.name = "Isle9"
			stage.add_child(isl)
			nest = NEST.new()
			nest.name = "Burrows"
			for k in range(6):
				nest.add_spot(Vector3(k * 2.0 - 5.0, 0.3, 12.0), k == 0)
			isl.add_child(nest)
		1:
			pass
		2:
			# (frames, not ticks: a bug a frame)
			var n := _bugs(nest).size()
			check("building: bugs hatch over frames (%d of 6 out two frames on)" % n, n >= 1 and n < 6)
			until = TK.wait_ticks(20)
		3:
			var names: Array = _bugs(nest).map(func(c): return str(c.name))
			names.sort()
			check("...then all of them, each once (%s)" % str(names), names == ["B0_0", "B1_0", "B2_0", "B3_0", "B4_0", "B5_0"])
			isl.building = false
			nest2 = NEST.new()
			nest2.name = "Roosts"
			for k in range(4):
				nest2.add_spot(Vector3(k * 2.0 - 3.0, 0.3, -12.0))
			isl.add_child(nest2)
			until = TK.wait_ticks(1)
		4:
			check("built: a nest's bugs all hatch at once (%d of 4)" % _bugs(nest2).size(), _bugs(nest2).size() == 4)
			return TK.done(fails)
	step += 1
	return false
