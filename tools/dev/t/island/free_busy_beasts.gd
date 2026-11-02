extends SceneTree
## An island let go while its beasts' models are still building on a worker (GenIsland.start_beasts) isn't freed
## until that task ends: the worker is mid-call on the island, and free() refused it as "a locked object" and leaked
## it (chaintest under load, 2026-11-02). WorldGenerator._free_some holds the root a frame at a time instead.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var step := 0
var until := 0
var fails := 0
var wg
var isl
var beast
var slices := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			# a beast whose prebuild runs until the test lets it end (a QuadBeast's takes a while with the workers busy)
			var slow := GDScript.new()
			slow.source_code = "extends Node3D\nvar go := false\nfunc prebuild() -> void:\n\twhile not go:\n\t\tOS.delay_msec(2)\n"
			slow.reload()
			beast = Node3D.new()
			beast.set_script(slow)
			isl = load("res://scripts/island/gen_island.gd").new()
			isl.name = "Isle9"
			isl.add_child(Node3D.new())
			isl._beasts = {"roamer": ["test", beast]}
			stage.add_child(isl)
			wg = load("res://scripts/island/world_generator.gd").new()
			isl._beast_task = WorkerThreadPool.add_task(isl._prebuild_beasts, true, "test beasts")
			wg._let_go(isl)
			for i in range(4):
				wg._free_some()
			check("while its beasts build, the island waits (not freed, still let go)", is_instance_valid(isl) and wg._freeing.size() == 1)
			check("...its beasts are still building", not isl.beasts_idle())
		1:
			(isl._beasts["roamer"][1]).go = true
			while is_instance_valid(isl) and slices < 2000:
				wg._free_some()
				slices += 1
				OS.delay_msec(1)
			check("once they're built it's freed (%d slices), nothing left let go" % slices, not is_instance_valid(isl) and wg._freeing.is_empty())
			wg.free()
			return TK.done(fails)
	step += 1
	return false
