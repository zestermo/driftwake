extends SceneTree
## A body's joints are out of the engine's physics interpolation (2026-11-11, BodyBuilder._skeleton) while the body
## itself is in it. What is drawn must still hang together: on every drawn frame of a grunt running at the captain,
## each of its meshes is drawn where the interpolated body puts it (not where the last physics tick left it, which
## would shake the whole body against the camera by up to a tick's travel, ~15 cm at a run).
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var g
var step := 0
var until := 0
var fails := 0
var sampling := false
var frames := 0
var worst := 0.0
var lead := 0.0
var moved := 0.0
var _last := Vector3.INF


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "grunts": [{"post": Vector3(0, 0, -16), "role": "sword", "seed": 501}]})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


## Every frame (the runner is headless: no draw to hook), after the engine's interpolation pass and the tick's moves:
## where each mesh is drawn against where the drawn body says it is.
func _watch() -> void:
	if not sampling or not is_instance_valid(g) or g.humanoid == null or g.humanoid.pivot == null:
		return
	var hum: Node3D = g.humanoid
	var drawn: Transform3D = hum.get_global_transform_interpolated()
	var inv: Transform3D = hum.global_transform.affine_inverse()
	for m in hum.pivot.find_children("*", "MeshInstance3D", true, false):
		if not (m as MeshInstance3D).is_visible_in_tree():
			continue
		var want: Vector3 = (drawn * (inv * (m as Node3D).global_transform)).origin
		worst = maxf(worst, ((m as Node3D).get_global_transform_interpolated().origin - want).length())
	# (how far the drawn body runs ahead of or behind its tick position: the test means nothing if that's always 0)
	lead = maxf(lead, (drawn.origin - hum.global_transform.origin).length())
	if _last != Vector3.INF:
		moved += drawn.origin.distance_to(_last)
	_last = drawn.origin
	frames += 1


func _process(_d: float) -> bool:
	_watch()
	if not stage.up or stage.camp.grunts.size() < 1 or TK.ticking(until):
		return false
	match step:
		0:
			g = stage.camp.grunts[0]
			stage.player.hurtbox.monitorable = false
			check("its joints are out of the interpolation, the body in it", not g.humanoid.pivot.is_physics_interpolated() and g.is_physics_interpolated())
			g.alert()
			until = TK.wait_secs(0.7)
		1:
			sampling = true
			until = TK.wait_secs(1.3)
		2:
			sampling = false
			print("   %d drawn frames, the body ran %.1f m, drawn up to %.3f m off its tick position, meshes off by at most %.4f m" % [frames, moved, lead, worst])
			check("the grunt ran while it was watched (%.1f m over %d frames)" % [moved, frames], frames > 20 and moved > 2.0)
			check("the body was drawn between ticks (up to %.3f m from its tick position)" % lead, lead > 0.01)
			check("every mesh was drawn where the drawn body puts it (worst %.4f m)" % worst, worst < 0.003)
			return TK.done(fails)
	step += 1
	return false
