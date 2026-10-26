extends SceneTree
## An AI captain's rig is posed at the rig LOD's rate like a grunt's: every frame close to the camera, only some
## frames far off; the captain's own rig every frame.
const TK := preload("res://tools/dev/test_kit.gd")
const FRAMES := 60
var stage
var p
var r
var step := 0
var until := 0
var fails := 0
var frames := 0
var posed := 0
var mine := 0
var last := -1
var last_mine := -1


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _count() -> bool:
	var pf: int = r.body_model.pose_frame
	if pf != last:
		posed += 1
		last = pf
	var mf: int = p.body_model.pose_frame
	if mf != last_mine:
		mine += 1
		last_mine = mf
	frames += 1
	return frames >= FRAMES


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			r = load("res://scripts/ai/rival_duel.gd").spawn(p, 0.5, "cutlass")
			r.get_node("Brain").order = "hold"
			until = TK.wait_ticks(10)
		1:
			check("an AI captain's rig is on the rig LOD", r.body_model.lod and not p.body_model.lod)
			r.global_position = p.global_position + Vector3(0, 0, -70.0)
			r.reset_physics_interpolation()
			frames = 0
		2:
			if not _count():
				return false
			check("70 m off it poses only some frames (%d of %d), the captain's own every frame (%d)" % [posed, FRAMES, mine],
				posed <= FRAMES / 2 and mine >= FRAMES - 1)
			return TK.done(fails)
	step += 1
	return false
