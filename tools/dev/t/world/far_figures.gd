extends SceneTree
## Townsfolk far off are FarFigures instances (2026-10-25 GPU pass): an NPC past FarFigures.ON_R hides its body and
## writes one row (where it is, its heading and height, its colours packed, its speed, sat or standing) instead of
## posing; walking, its row says how fast; sat, how high the seat is; close again (inside OFF_R) it's a body once more
## and its slot is freed, as it is when it's hidden or gone.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var step := 0
var until := 0
var fails := 0
var ff
var walker
var sitter
var pf := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _npc(n: String, at: Vector3, cfg: Dictionary):
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(n)
	var lk: Dictionary = load("res://scripts/npc/character_look.gd").random_look(rng)
	lk["top_color"] = Color8(200, 40, 30)
	lk["coat"] = "none"
	lk["legs_color"] = Color8(30, 60, 140)
	cfg.merge({"name": n, "look": lk})
	var npc = load("res://scripts/npc/npc.gd").new().setup(cfg)
	root.add_child(npc)
	npc.global_position = at
	return npc


func _row(i: int) -> PackedFloat32Array:
	return ff.rows.slice(i * ff.ROW, (i + 1) * ff.ROW)


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	var cam := root.get_viewport().get_camera_3d()
	var fwd := -cam.global_basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var at := Vector3(cam.global_position.x, 0.0, cam.global_position.z) + fwd * 70.0
	match step:
		0:
			walker = _npc("Far Walker", at, {"waypoints": [at + fwd.cross(Vector3.UP) * 30.0, at]})
			sitter = _npc("Far Sitter", at + fwd * 6.0, {"seated": true})
			until = TK.wait_secs(1.5)
		1:
			ff = root.get_node_or_null("FarFigures")
			var h = walker.humanoid
			check("past ON_R a villager's a figure: its body hidden, one slot each (%d)" % (ff.used if ff else -1), ff != null and ff.used == 2
				and h._fig >= 0 and not h.pivot.visible and sitter.humanoid._fig >= 0)
			var r := _row(h._fig)
			var p: Vector3 = h.global_position
			check("...its row where its body is (%.2f m off)" % Vector3(r[3], r[7], r[11]).distance_to(p), Vector3(r[3], r[7], r[11]).distance_to(p) < 0.6)
			check("...its colours packed: red top, blue legs", is_equal_approx(r[12], 200.0 * 65536 + 40 * 256 + 30) and is_equal_approx(r[13], 30.0 * 65536 + 60 * 256 + 140))
			var head := -Vector3(r[2], r[6], r[10]).normalized()
			check("...walking at its pace (%.2f m/s) the way it's going" % r[17], r[17] > 0.8 and head.dot(fwd.cross(Vector3.UP)) > 0.9)
			var s := _row(sitter.humanoid._fig)
			check("...the sitter sat on its seat (%.2f), not walking" % s[19], is_equal_approx(s[19], 1.0 + sitter.humanoid.seat_y) and s[17] == 0.0)
			pf = h.pose_frame
			until = TK.wait_secs(0.5)
		2:
			check("...and its rig poses no more", walker.humanoid.pose_frame == pf)
			walker.global_position = Vector3(cam.global_position.x, 0.0, cam.global_position.z) + fwd * 12.0
			walker.waypoints = []
			until = TK.wait_secs(0.6)
		3:
			check("close again it's a body, its slot freed", walker.humanoid._fig < 0 and walker.humanoid.pivot.visible and ff.used == 1
				and walker.humanoid.pose_frame != pf)
			sitter.visible = false
			until = TK.wait_ticks(2)
		4:
			check("hidden, its figure goes too", sitter.humanoid._fig < 0 and ff.used == 0 and sitter.humanoid.pivot.visible)
			return TK.done(fails)
	step += 1
	return false
