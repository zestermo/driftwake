extends SceneTree
## The cape lab's modes (BodyBuilder.cape_mode, thin and thick): each builds and runs (a scripted anchor motion
## stepped by hand, then the captain walking, turning, stopping and jumping) with finite bones; A0 thin is
## exactly today's chains (numbers recorded from the code before the lab); B and C never swing in front of the
## back's plane.
const TK := preload("res://tools/dev/test_kit.gd")
const MODES := ["a0", "a", "b", "bg", "c"]
# today's code, before the lab: the stepped harness's sum and the torso chains' last poses (the sash tail, the cape)
const REF_SUM := Vector3(-128.24307, 1429.30945, 37.28402)
const REF_CAPE := ["chain1_0 0.00000 0.49278 0.16800 | -0.00843 0.99996 0.00022", "chain1_1 0.00112 0.36120 0.17797 | -0.01495 0.99842 0.05415",
	"chain1_2 0.00654 -0.00051 0.17838 | 0.04691 0.99456 0.09297"]
var stage
var p
var step := 0
var until := 0
var fails := 0
var combo := 0
var finite := true
var behind := true
var worst := 0.0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _look() -> Dictionary:
	var lk: Dictionary = CharacterLook.default_look()
	lk["coat"] = "none"
	lk["cape"] = true
	lk["cape_color"] = Color(0.6, 0.12, 0.1)
	return lk


func _cape_sim(h) -> SpringChains:
	var c = h.torso.get_node_or_null("Cape")
	return c if c != null else h.torso.get_node("SpringChains")


## The cape's points (anchor space) from its bones; notes non-finite bones and the deepest point in front of the back plane.
func _watch(s: SpringChains, from_chain: int) -> void:
	var sk := s.skel
	for b in range(sk.get_bone_count()):
		var t := sk.get_bone_global_pose(b)
		if not (t.origin.is_finite() and t.basis.x.is_finite() and t.basis.y.is_finite()):
			finite = false
	if s.mode == "a0" and s.motion == null:
		return
	for ci in range(from_chain, s.chain_count()):
		var c := s.chain(ci)
		var bones: PackedInt32Array = c["bones"]
		var pts: PackedVector3Array = c["p"]
		for i in range(bones.size()):
			var t := sk.get_bone_global_pose(bones[i])
			# (each chain's root hangs on the yoke: only what swings counts)
			var d: float = s.back_z - (t * (pts[i + 1] - pts[i])).z
			if d > 0.001:
				behind = false
				worst = maxf(worst, d)


func _harness(m: String, thick: bool) -> Array:
	BodyBuilder.cape_mode = m
	BodyBuilder.cape_thick = thick
	var h = Humanoid.new()
	h.setup(_look())
	h.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	h.set_process(false)
	stage.add_child(h)
	var dt := 1.0 / 144.0
	var pos := Vector3(10, 3, 0)
	var yaw := 0.0
	var sum := Vector3.ZERO
	var s := _cape_sim(h)
	for i in range(160):
		if i >= 30 and i < 110:
			pos += Vector3(-sin(yaw), 0, -cos(yaw)) * 6.0 * dt
		if i >= 60 and i < 90:
			yaw += PI / 30.0
		h.global_transform = Transform3D(Basis(Vector3.UP, yaw), pos)
		for sim in h._sims:
			sim.simulate(dt)
		for sim in h._sims:
			var sk: Skeleton3D = sim.skel
			for b in range(sk.get_bone_count()):
				sum += sk.get_bone_global_pose(b).origin + sk.get_bone_global_pose(b).basis.y
		_watch(s, 0)
	var out := []
	var sk: Skeleton3D = h.torso.get_node("SpringChains").skel
	for b in range(sk.get_bone_count()):
		var t := sk.get_bone_global_pose(b)
		out.append("%s %.5f %.5f %.5f | %.5f %.5f %.5f" % [sk.get_bone_name(b), t.origin.x, t.origin.y, t.origin.z, t.basis.y.x, t.basis.y.y, t.basis.y.z])
	var chains := s.chain_count()
	h.queue_free()
	return [sum, out, chains]


func _process(_d: float) -> bool:
	if not stage.up:
		return false
	if step >= 2:
		_watch(_cape_sim(p.body_model), 1 if BodyBuilder.cape_mode == "a0" else 0)
	if TK.ticking(until):
		return false
	match step:
		0:
			var r := _harness("a0", false)
			check("A0 thin: today's stepped chains (sum %.5f %.5f %.5f)" % [r[0].x, r[0].y, r[0].z], (r[0] as Vector3).distance_to(REF_SUM) < 0.002)
			var same := true
			for l in REF_CAPE:
				same = same and (r[1] as Array).has(l)
			check("A0 thin: today's cape poses", same)
			for m in MODES:
				for thick in [false, true]:
					finite = true
					behind = true
					worst = 0.0
					var rr := _harness(m, thick)
					var tag := "%s %s" % [m, "thick" if thick else "thin"]
					check("%s builds with %d chain(s) and steps to finite bones" % [tag, rr[2]], finite and int(rr[2]) == (3 if thick else 1) + (1 if m == "a0" else 0))
					if m in ["b", "c"]:
						check("%s stays behind the back plane (worst %.3f m)" % [tag, worst], behind)
			p = stage.player
			combo = 0
		1:
			if combo >= MODES.size() * 2:
				BodyBuilder.cape_mode = "a0"
				BodyBuilder.cape_thick = false
				return TK.done(fails)
			BodyBuilder.cape_mode = MODES[combo / 2]
			BodyBuilder.cape_thick = combo % 2 == 1
			p.body_model.apply_look(_look())
			finite = true
			behind = true
			worst = 0.0
			TK.press("move_forward")
			TK.press("sprint")
			until = TK.wait_secs(0.8)
		2:
			TK.release("move_forward")
			TK.press("move_back")
			until = TK.wait_secs(0.5)
		3:
			TK.release("move_back")
			TK.release("sprint")
			until = TK.wait_secs(0.3)
		4:
			TK.act("jump")
			until = TK.wait_secs(0.9)
		5:
			var tag := "%s %s" % [BodyBuilder.cape_mode, "thick" if BodyBuilder.cape_thick else "thin"]
			check("%s: the captain's run keeps finite bones" % tag, finite)
			if BodyBuilder.cape_mode in ["b", "c"]:
				check("%s: the captain's cape stays behind the back plane (worst %.3f m)" % [tag, worst], behind)
			combo += 1
			step = 1
			return false
	step += 1
	return false
