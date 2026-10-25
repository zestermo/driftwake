extends SceneTree
## The high flocks fly on the GPU (2026-10-25 GPU pass): a wheeling or V flock bird on its path goes into SkyBirds'
## flock MultiMesh with a row of numbers whose sums (sky_flock.gdshader's path(), mirrored here) put it where the
## CPU's _target does at any clock time; nothing of it is drawn by the CPU's MultiMesh; sent home it comes back to
## the CPU where its path had it, flying on.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var step := 0
var until := 0
var fails := 0
var birds
var leaver: Dictionary


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


## sky_flock.gdshader's path(): row r (16 floats) at clock t.
func path(r: PackedFloat32Array, o: int, t: float) -> Vector3:
	var s := r[o + 7]
	var a := r[o + 4] + r[o + 5] * t
	if r[o + 3] < 0.5:
		var rad := r[o + 6] + sin(t * 0.37 + s) * 5.0
		var c := Vector3(r[o] + sin(t * 0.05 + s * 0.01) * 18.0, 0.0, r[o + 2] + cos(t * 0.043) * 18.0)
		return c + Vector3(cos(a) * rad, r[o + 1] + sin(t * 0.6 + s) * 2.5, sin(a) * rad)
	var lead := Vector3(r[o] + cos(a) * r[o + 6], r[o + 1], r[o + 2] + sin(a) * r[o + 6])
	var dir := Vector3(-sin(a), 0.0, cos(a)) * signf(r[o + 5])
	var side := dir.cross(Vector3.UP)
	return lead - dir * r[o + 8] + side * r[o + 9] + Vector3(0.0, sin(t * 1.3 + s) * 0.3 + r[o + 10], 0.0)


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	var cam := root.get_viewport().get_camera_3d()
	match step:
		0:
			birds = load("res://scripts/world/sky_birds.gd").new()
			root.add_child(birds)
			var rng := RandomNumberGenerator.new()
			rng.seed = 11
			var at := cam.global_position + Vector3(0, 0, -60)
			var wheel := {"c": at, "a": 0.3, "w": 0.1, "h": 40.0, "r": 30.0, "R": 80.0, "t0": birds._t}
			var vee := {"c": at, "a": 1.2, "w": -11.0 / 80.0, "h": 50.0, "r": 30.0, "R": 80.0, "t0": birds._t}
			for i in range(7):
				var v := i >= 4
				var b: Dictionary = birds._bird(birds.DARK, "test", birds.VEE if v else birds.WHEEL, at, rng)
				b["flock"] = vee if v else wheel
				b["rank"] = i - 4
				b["off"] = rng.randf_range(-0.5, 0.5)
				b["ro"] = rng.randf_range(-6.0, 6.0)
				b["ho"] = rng.randf_range(-4.0, 4.0)
				b["keep"] = -1.0
				b["pos"] = birds._target(b, null, Transform3D.IDENTITY)
			until = TK.wait_ticks(4)
		1:
			check("every flock bird on its path is on the GPU (%d of 7)" % birds.gpu.size(), birds.gpu.size() == 7)
			check("...drawn by the flock MultiMesh, not the CPU's", birds._flock_mm.visible_instance_count == 7 and birds._mm.visible_instance_count == 0)
			var worst := 0.0
			for i in range(birds.gpu.size()):
				var b: Dictionary = birds.gpu[i]
				for t in [birds._t, birds._t + 3.7, birds._t + 61.0, 900.0]:
					worst = maxf(worst, path(birds.flock_rows, i * 16, t).distance_to(birds._target(b, null, Transform3D.IDENTITY, t)))
			check("its row puts it where its path does at any time (worst %.4f m off)" % worst, worst < 0.01)
			var r: PackedFloat32Array = birds.flock_rows
			check("...with its kind, size and wingbeat", is_equal_approx(r[11], 1.0) and is_equal_approx(r[12], birds.SIZE[birds.DARK]) and is_equal_approx(r[13], 30.0))
			leaver = birds.gpu[5]
			leaver["keep"] = 2.0
			until = TK.wait_ticks(2)
		2:
			var want: Vector3 = birds._target(leaver, null, Transform3D.IDENTITY)
			check("sent home it's back on the CPU (%d left on the GPU)" % birds.gpu.size(), not leaver["gpu"] and birds.gpu.size() == 6
				and birds._flock_mm.visible_instance_count == 6 and leaver["mode"] == birds.LEAVE)
			check("...from where its path had it, flying on (%.2f m off, %.1f m/s)" % [(leaver["pos"] as Vector3).distance_to(want), (leaver["vel"] as Vector3).length()],
				(leaver["pos"] as Vector3).distance_to(want) < 3.0 and (leaver["vel"] as Vector3).length() > 2.0)
			check("...and drawn by the CPU's MultiMesh", birds._mm.visible_instance_count == 1)
			return TK.done(fails)
	step += 1
	return false
