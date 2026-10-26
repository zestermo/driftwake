extends SceneTree
## A long build step that breathes (GenIsland.breathe) runs a BUDGET_US slice a frame when WorldGenerator runs it
## (budgeted: resumed a slice a frame), every piece once and in order, with the same result as straight through; run
## straight through (finish, the tools) nothing waits. A step whose island is let go mid-way never resumes.
const TK := preload("res://tools/dev/test_kit.gd")
const PIECES := 30
var GI
var stage
var step := 0
var until := 0
var fails := 0
var isl
var done: Array = []
var got: Array = []
var frames := 0
var finished := false


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


## A step's work: PIECES of ~1 ms, an rng stream through them (the result), breathing after each.
func _work(out: Array) -> Array:
	return ["work", func():
		var rng := RandomNumberGenerator.new()
		rng.seed = 77
		for i in range(PIECES):
			done.append(i)
			out.append(rng.randi())
			_busy(1000)
			await GI.breathe()]


func _run(s: Array) -> void:
	await isl.run_step(s)
	finished = true


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			GI = load("res://scripts/island/gen_island.gd")
			isl = GI.new()
			isl.name = "Isle9"
			stage.add_child(isl)
			var straight: Array = []
			isl.run_step(_work(straight))
			check("straight through: every piece in one go", done.size() == PIECES)
			got = straight
			done = []
			var sliced: Array = []
			isl.set_meta("sliced", sliced)
			isl.budget()
			_run(_work(sliced))
			check("budgeted: the first frame does a slice (%d of %d pieces)" % [done.size(), PIECES], done.size() >= 2 and done.size() < 10)
		_:
			if not finished:
				frames += 1
				isl.resume.emit()
				if frames > 100:
					check("the budgeted step finished", false)
					return TK.done(fails)
				return false
			GI.unbudget()
			check("...over several frames (%d)" % frames, frames >= 5)
			check("every piece once, in order", done == range(PIECES))
			check("the same result as straight through", isl.get_meta("sliced") == got)
			check("its worst slice is near the budget (%.1f ms)" % (isl._slice_max / 1000.0), isl._slice_max < GI.BUDGET_US + 2500)
			# let go mid-way: freed while waiting, it never resumes
			done = []
			finished = false
			isl.budget()
			_run(_work([]))
			var at := done.size()
			isl.free()
			GI.unbudget()
			check("let go mid-way: the step stops where it was (%d of %d)" % [at, PIECES], at < PIECES and done.size() == at and not finished)
			return TK.done(fails)
	step += 1
	return false
