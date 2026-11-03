extends SceneTree
## 1.30 (playtest 2026-11-02 row 9): a captain thrown straight into a wall slides along it instead of being pinned there
## (StaggerState carries the throw on along the wall).
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var wall_z := 0.0
var start := Vector3.ZERO
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
			p = stage.player
			wall_z = p.global_position.z - 2.0
			var body := StaticBody3D.new()
			var cs := CollisionShape3D.new()
			var sh := BoxShape3D.new()
			sh.size = Vector3(30.0, 4.0, 1.0)
			cs.shape = sh
			body.add_child(cs)
			stage.add_child(body)
			body.global_position = Vector3(p.global_position.x, p.global_position.y + 2.0, wall_z - 0.5)
			until = TK.wait_ticks(4)
		1:
			start = p.global_position
			p.shoved(Vector3(0, 0, -15.0))
			until = TK.wait_secs(0.7)
		2:
			var moved: Vector3 = p.global_position - start
			check("thrown at a wall it doesn't go through it (z %.2f, wall %.2f)" % [p.global_position.z, wall_z], p.global_position.z > wall_z - 0.1)
			check("...it slides along it (%.1f m sideways)" % absf(moved.x), absf(moved.x) > 2.0)
			return TK.done(fails)
	step += 1
	return false
