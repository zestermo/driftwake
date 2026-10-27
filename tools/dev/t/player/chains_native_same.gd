extends SceneTree
## The native chain solver (ChainSolver) moves hair and cloth the same as SpringChains' GDScript one: two bodies dressed
## alike, one on each, driven by the same script at uneven frame times; the chain bones stay within EPS of their twins
## (all but a few frame-bones, never far).
const TK := preload("res://tools/dev/test_kit.gd")
const KIT := preload("res://tools/dev/t/player/_chains_kit.gd")
const EPS := 0.004
## The net's thresholds (inside the cushion or not, a best turn by a millimetre) can turn a float's difference into a
## frame's different turn on a hem that a kicking thigh keeps in the balance: a few frame-bones may part, briefly (a
## skirt's hem by 5.7 cm for 6 frames since 1.24's seat clearance moved its panels; the same with no net slack).
const OFF_SHARE := 0.01
const WORST := 0.07
var stage
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	# (the library's sources aren't loaded as resources: a change to them must still make this pass stale)
	for f in ["res://native/src/chain_solver.cpp", "res://native/src/chain_solver.h", "res://native/src/register_types.cpp"]:
		preload("res://scripts/game/dep_record.gd").note_dep(f)
	stage = TK.stage(self, {"hud": false})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	# (bin/ is gitignored: a checkout that hasn't built native/ runs the GDScript solver, and there's nothing to compare)
	if not SpringChains.native_ok:
		print("SKIP native not built (no ChainSolver at API %d in bin/): nothing to compare" % SpringChains.NATIVE_API)
		return TK.done(fails)
	for lk in KIT.looks():
		var tag := "cloak" if lk.get("cloak", false) else "cape"
		var a = KIT.body(root, lk, true)
		var b = KIT.body(root, lk, false)
		var worst := 0.0
		var worst_at := ""
		var swing := 0.0
		var acted := 0
		var samples := 0
		var off := 0
		var first := ""
		for i in range(KIT.FRAMES):
			var yaw: float = KIT.yaw_at(i)
			KIT.drive(a, i, yaw)
			KIT.drive(b, i, yaw)
			for si in range(a._sims.size()):
				var sa = a._sims[si]
				var sb = b._sims[si]
				if sa._net_acted:
					acted += 1
				for bi in range(sa.skel.get_bone_count()):
					var pa: Transform3D = sa.skel.get_bone_global_pose(bi)
					var pb: Transform3D = sb.skel.get_bone_global_pose(bi)
					var d := maxf(pa.origin.distance_to(pb.origin), (pa.basis.y - pb.basis.y).length() * 0.3)
					samples += 1
					if d > EPS:
						off += 1
						if first == "":
							first = "%s %s bone %d frame %d (%.4f)" % [sa.get_parent().name, sa.name, bi, i, d]
					if d > worst:
						worst = d
						worst_at = "%s %s bone %d frame %d" % [sa.get_parent().name, sa.name, bi, i]
					swing = maxf(swing, pa.origin.distance_to(sa.skel.get_bone_global_rest(bi).origin))
		print("%s: worst %.5f m at %s, swing %.2f m, net acted %d frames; %d of %d bone-frames past %.3f, first %s" % [
			tag, worst, worst_at, swing, acted, off, samples, EPS, first])
		check("%s: the native solver ran" % tag, a._sims.all(func(s): return s._nat != null) and b._sims.all(func(s): return s._nat == null))
		check("%s: the chains swung (%.2f m off rest)" % [tag, swing], swing > 0.1)
		check("%s: the cape's net acted" % tag, acted > 0)
		check("%s: the chain bones within %.3f of the GDScript solver's in %d of %d frame-bones (worst %.4f)" % [tag, EPS,
			samples - off, samples, worst], off <= samples * OFF_SHARE and worst < WORST)
		a.queue_free()
		b.queue_free()
	return TK.done(fails)
