extends SceneTree
## Which harbour a chain island rolls (GenHarbour): the same node plans the same harbour twice, and a handful of
## chain seeds roll different kinds. (harbourtest builds each kind forced; planning is a full island's prepare each time, so
## this half is its own suite to stay inside the runner's budget.)
const SEEDS := [777, 31337, 4242, 99, 1234, 5150]
const TK = preload("res://tools/dev/test_kit.gd")
var t := 0.0
var step := 0
var w
var fails := 0


func _initialize():
	TK.use_seed(self, 777)
	change_scene_to_file("res://scenes/world/world.tscn")


func check(name: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + name)
	if not cond:
		fails += 1


func finish() -> void:
	print("RESULT ", "OK" if fails == 0 else "FAILED (%d)" % fails)
	quit()


func _process(d: float) -> bool:
	t += d
	if t > 300.0:
		check("timed out at step %d" % step, false)
		finish()
		return true
	match step:
		0:
			if t < 1.5:
				return false
			w = root.get_node("World/Islands")
			if not w.chain_ready():
				return false
			w.set_process(false)
			step = 1
		1:
			TK.use_seed(self, 777)
			var c = w.chain()
			var n: Dictionary = c.node(int(c.start_next[0]))
			var a = load("res://scripts/island/gen_island.gd").new()
			var b = load("res://scripts/island/gen_island.gd").new()
			a.prepare(n)
			b.prepare(n)
			check("the same node plans the same harbour (%s)" % a.harbour.kind, a.harbour.kind == b.harbour.kind and a.harbour.spots == b.harbour.spots
				and a.harbour.steps().size() == b.harbour.steps().size() and a.exclusions.size() == b.exclusions.size())
			a.free()
			b.free()
			var gm = root.get_node("GameManager")
			var seen := {}
			for s in SEEDS:
				gm.chain_seed = s
				var cc = w.chain()
				var g = load("res://scripts/island/gen_island.gd").new()
				g.prepare(cc.node(int(cc.start_next[0])))
				seen[g.harbour.kind] = true
				g.free()
			print("   kinds rolled by six seeds: %s" % [seen.keys()])
			check("the seeds roll different kinds of harbour", seen.size() >= 2)
			finish()
	return false
