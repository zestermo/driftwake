extends SceneTree
## An island let go (WorldGenerator._let_go) is out of the game at once (processing off, hidden, renamed so one
## built again takes its name) and its nodes are freed a slice a frame, leaves first, not in one frame.
const TK := preload("res://tools/dev/test_kit.gd")
const GROUPS := 60
const EACH := 150
var stage
var step := 0
var until := 0
var fails := 0
var wg
var isl: Node3D
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
			isl = Node3D.new()
			isl.name = "Isle7"
			for g in range(GROUPS):
				var piece := Node3D.new()
				for i in range(EACH):
					var body := StaticBody3D.new()
					var cs := CollisionShape3D.new()
					cs.shape = BoxShape3D.new()
					body.add_child(cs)
					body.add_child(MeshInstance3D.new())
					piece.add_child(body)
				isl.add_child(piece)
			stage.add_child(isl)
			wg = load("res://scripts/island/world_generator.gd").new()
			wg._let_go(isl)
			check("let go: out of the game at once (processing off, hidden, renamed)", isl.process_mode == Node.PROCESS_MODE_DISABLED
				and not isl.visible and str(isl.name) != "Isle7" and stage.get_node_or_null("Isle7") == null)
			wg._free_some()
			slices = 1
			check("...not freed in one frame (%d of %d groups left)" % [isl.get_child_count(), GROUPS], is_instance_valid(isl) and isl.get_child_count() > 0)
		1:
			while is_instance_valid(isl) and slices < 400:
				wg._free_some()
				slices += 1
			check("...freed whole within %d slices" % slices, not is_instance_valid(isl) and wg._freeing.is_empty())
			wg.free()
			return TK.done(fails)
	step += 1
	return false
