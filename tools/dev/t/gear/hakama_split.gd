extends SceneTree
## The split hakama (1.30.3): wide trousers, a leg each on its thigh's own chains (not one skirt round both legs), the
## kimono's hem tucked inside (its own panels came out through it), and standing idle each leg's hem hangs close to
## where it was built, not stood out along the thigh.
const TK := preload("res://tools/dev/test_kit.gd")
## (how far out from as built, the straighter leg: the idle stance has it 6 degrees forward too, its front over the knee
## by ~7 cm; the skirt test's 11 cm at worst for a panel a leg pushes)
const MEAN_OUT := 0.06
const MOST_OUT := 0.11
var stage
var p
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
			if not SpringChains.native_ok:
				print("SKIP native not built (no ChainSolver at API %d in bin/): the cloth has no nets" % SpringChains.NATIVE_API)
				return TK.done(fails)
			p = stage.player
			var lk: Dictionary = CharacterLook.default_look()
			lk.merge({"top": "kimono", "legs": "hakama", "coat": "none", "hat": "none"}, true)
			p.body_model.apply_look(lk)
			until = TK.wait_secs(2.5)
		1:
			var hm = p.body_model
			var on_leg := {"LegL": 0, "LegR": 0}
			var hips_chains := 0
			# (the straighter leg's hems against as built; the idle stance's forward leg, thigh up and knee bent, rightly
			# drapes its front over the knee, so for both legs only: every hem hangs below its knee, not out along the thigh)
			var straight: Node3D = hm.leg_l if absf(hm.leg_l.rotation.x) < absf(hm.leg_r.rotation.x) else hm.leg_r
			var outs: Array = []
			var low := true
			var worst_low := -INF
			for sim in hm._sims:
				var par: Node3D = sim.get_parent()
				if par == hm.hips:
					hips_chains += sim.chain_count()
				if not on_leg.has(str(par.name)):
					continue
				on_leg[str(par.name)] += sim.chain_count()
				var knee: Node3D = hm.shin_l if par == hm.leg_l else hm.shin_r
				var g: Transform3D = sim.skel.global_transform
				for ci in range(sim.chain_count()):
					var c: Dictionary = sim.chain(ci)
					var pts: PackedVector3Array = c["p"]
					var bones: PackedInt32Array = c["bones"]
					var last := bones.size() - 1
					var bp: Transform3D = sim.skel.get_bone_global_pose(bones[last])
					var hem_w: Vector3 = g * (bp.origin + bp.basis * (pts[last + 1] - pts[last]))
					worst_low = maxf(worst_low, hem_w.y - knee.global_position.y)
					if hem_w.y > knee.global_position.y - 0.1:
						low = false
					if par != straight:
						continue
					# (in the world, how much further out sideways from its root than built: the cloth hangs plumb)
					var d: Vector3 = hem_w - g * sim.skel.get_bone_global_pose(bones[0]).origin
					var built: Vector3 = pts[pts.size() - 1] - pts[0]
					outs.append(Vector2(d.x, d.z).length() - Vector2(built.x, built.z).length())
			print("chains: left leg %d, right leg %d, hips %d; straighter leg %s; hem out (cm): %s" % [on_leg["LegL"],
				on_leg["LegR"], hips_chains, straight.name, ", ".join(outs.map(func(o): return "%.1f" % (o * 100.0)))])
			check("each leg has its own panels (left %d, right %d)" % [on_leg["LegL"], on_leg["LegR"]],
				on_leg["LegL"] >= 4 and on_leg["LegR"] >= 4)
			check("the kimono's hem is tucked in: no panels on the hips (%d)" % hips_chains, hips_chains == 0)
			var mean := 0.0
			var most := 0.0
			for o in outs:
				mean += o / maxf(outs.size(), 1)
				most = maxf(most, o)
			check("standing, the straighter leg's hems hang close to as built (mean %.1f cm, most %.1f cm)" % [mean * 100.0,
				most * 100.0], not outs.is_empty() and mean < MEAN_OUT and most < MOST_OUT)
			check("every hem hangs 10 cm or more below its knee (highest %.1f cm from it)" % (worst_low * 100.0), low)
			return TK.done(fails)
	step += 1
	return false
