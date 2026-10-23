extends SceneTree
## A greatsword never cuts through its wielder: every frame of the combo (each blow chained out of the last at its chain
## time), the charged heavy, Running Cleave and the techniques' swings, the blade (guard to point) stays clear of the
## chest, head, thighs and shins; and the big blows reach well out from the body.
const TK := preload("res://tools/dev/test_kit.gd")
## Each run: [action, length] played back to back, the next at the last one's chain time (a hold: after 0.5 s).
const RUNS := [
	[["gs_1", 0.9], ["gs_2", 0.85], ["gs_3", 0.9], ["gs_4", 1.1]],
	[["gs_charge", 0.2], ["gs_heavy", 0.8]],
	[["gs_rush", 0.8]], [["gs_guardbreak", 0.95]], [["gs_crescent", 0.8]], [["gs_tempest", 1.7]], [["gs_deflect", 0.45]],
	[["gs_updraft", 1.0]], [["gs_gate", 1.5]], [["gs_gate_rise", 0.6]]]
## (m) how far out from the chest's axis the sword hand must get at some frame of each big swing (the old moves kept it
## within 0.4-0.47 m on all but the heavy and Guardbreaker)
const REACH := {"gs_1": 0.5, "gs_3": 0.52, "gs_4": 0.55, "gs_heavy": 0.6, "gs_rush": 0.5, "gs_crescent": 0.52, "gs_tempest": 0.55}
var stage
var p
var bm
var step := 0
var until := 0
var fails := 0
var run := 0
var idx := 0
var playing := ""
var worst := {}
var far := {}
var hands := {}


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "weapon": "greatsword"})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


## [clearance (m), what it's nearest] of the blade against the body's capsules this frame.
func clearance() -> Array:
	var w: MeshInstance3D = bm.weapon
	var a: Vector3 = w.global_transform * Vector3(0, 0, -WeaponDesigns.GREAT_GUARD)
	var b: Vector3 = w.global_transform * Vector3(0, 0, w.mesh.get_aabb().position.z)
	var up: Vector3 = bm.global_basis.y.normalized()
	var hc: Vector3 = bm.head.global_transform * Vector3(0, 0.11, 0)
	var parts := {"chest": [bm.hips.global_position + up * 0.1, bm.neck.global_position, 0.15], "head": [hc, hc, 0.12]}
	for s in ["l", "r"]:
		var leg: Node3D = bm.get("leg_" + s)
		var shin: Node3D = bm.get("shin_" + s)
		var len := leg.global_position.distance_to(shin.global_position)
		parts["thigh_" + s] = [leg.global_position, shin.global_position, 0.08]
		parts["shin_" + s] = [shin.global_position, shin.global_position - shin.global_basis.y.normalized() * len, 0.065]
	var best := [99.0, ""]
	for n in parts:
		var c: Array = parts[n]
		var pts := Geometry3D.get_closest_points_between_segments(a, b, c[0], c[1])
		var d: float = (pts[0] as Vector3).distance_to(pts[1]) - float(c[2]) - 0.02
		if d < best[0]:
			best = [d, n]
	return best


func sample() -> void:
	var act: String = bm.current_action()
	if act == "" or not act.begins_with("gs_"):
		return
	var u: float = float(bm._action["t"]) / float(bm._action["dur"])
	var c := clearance()
	if c[0] < 0.0:
		print("NEAR %s u %.2f %.3f %s grip %s" % [act, u, c[0], c[1], str(bm.pole_cur)])
	if not worst.has(act) or c[0] < worst[act][0]:
		worst[act] = [c[0], c[1], u]
	var w: MeshInstance3D = bm.weapon
	var tip: Vector3 = w.global_transform * Vector3(0, 0, w.mesh.get_aabb().position.z)
	var rel: Vector3 = tip - bm.torso.global_position
	rel.y = 0.0
	far[act] = maxf(far.get(act, 0.0), rel.length())
	var hand: Vector3 = bm.hand_r.global_position - bm.torso.global_position
	hand.y = 0.0
	hands[act] = maxf(hands.get(act, 0.0), hand.length())


func _process(_d: float) -> bool:
	if stage.up and bm != null:
		sample()
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			bm = p.body_model
			p.set_physics_process(false)
			until = TK.wait_secs(0.6)
		1:
			if run >= RUNS.size():
				step = 3
				return false
			var r: Array = RUNS[run]
			var n: String = r[idx][0]
			var sp: Dictionary = ActionSpecs.SPECS[n]
			if sp.get("hold", false):
				bm.hold(n)
				until = TK.wait_secs(0.5)
			else:
				bm.play(n, float(r[idx][1]))
				var last: bool = idx == r.size() - 1
				until = TK.wait_secs(float(r[idx][1]) * (1.0 if last or not sp.has("chain") else float(sp["chain"])))
			idx += 1
			if idx >= r.size():
				idx = 0
				run += 1
				step = 2
			return false
		2:
			until = TK.wait_secs(0.5)
			step = 1
			return false
		3:
			for n in worst:
				var wv: Array = worst[n]
				print("CLEAR %s %.3f m (%s at u %.2f) tip out %.2f m hand out %.2f m" % [n, wv[0], wv[1], wv[2], far.get(n, 0.0), hands.get(n, 0.0)])
			for n in worst:
				check("%s: the blade never through the body (closest %.3f m, the %s at u %.2f)" % [n, worst[n][0], worst[n][1], worst[n][2]], worst[n][0] >= 0.0)
			for n in REACH:
				check("%s swings out wide (the hand %.2f m from the chest, wants %.2f)" % [n, hands.get(n, 0.0), REACH[n]], hands.get(n, 0.0) >= REACH[n])
			return TK.done(fails)
	step += 1
	return false
