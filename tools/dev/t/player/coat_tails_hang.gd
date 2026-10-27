extends SceneTree
## Long coats' tails hang: the captain standing idle in each long coat (and a skirt), the drawn hem of every panel on the
## hips sits close to where it was built, not swung out into a stiff A (Zach's 1.23 playtest: tails like boards).
const TK := preload("res://tools/dev/test_kit.gd")
const LOOKS := [{"coat": "longcoat", "belt": "sash"}, {"coat": "captain"}, {"coat": "greatcoat", "vest": "padded"},
	{"coat": "duster", "belt": "wide_belt"}, {"coat": "admiral"}, {"coat": "none", "legs": "skirt"}]
## How far (m) a drawn hem point may stand further out from the hips' axis than built, on average and at worst (a
## panel the idle stance's forward leg really pushes). Before the net's slack: means 2-5.4 cm, the long coats 5.
const MEAN_OUT := 0.035
const MOST_OUT := 0.11
var stage
var p
var step := 0
var until := 0
var fails := 0
var li := 0


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
			# (the cloth's nets are native only: a checkout that hasn't built native/ has none to test)
			if not SpringChains.native_ok:
				print("SKIP native not built (no ChainSolver at API %d in bin/): the cloth has no nets" % SpringChains.NATIVE_API)
				return TK.done(fails)
			p = stage.player
			var lk: Dictionary = CharacterLook.default_look()
			lk.merge(LOOKS[li], true)
			p.body_model.apply_look(lk)
			until = TK.wait_secs(2.5)
		1:
			var hm = p.body_model
			var sim = null
			for s in hm._sims:
				if s.get_parent() == hm.hips:
					sim = s
			var outs: Array = []
			for ci in range(sim.chain_count()):
				var c: Dictionary = sim.chain(ci)
				var pts: PackedVector3Array = c["p"]
				var bones: PackedInt32Array = c["bones"]
				var last := bones.size() - 1
				var bp: Transform3D = sim.skel.get_bone_global_pose(bones[last])
				var hem: Vector3 = bp.origin + bp.basis * (pts[last + 1] - pts[last])
				var rest: Vector3 = pts[pts.size() - 1]
				outs.append(Vector2(hem.x, hem.z).length() - Vector2(rest.x, rest.z).length())
			var mean := 0.0
			var most := -INF
			for o in outs:
				mean += o / outs.size()
				most = maxf(most, o)
			var tag := str(LOOKS[li])
			print("%s: hem out from built mean %.1f cm, most %.1f cm  %s" % [tag, mean * 100.0, most * 100.0,
				", ".join(outs.map(func(o): return "%.1f" % (o * 100.0)))])
			check("%s: the tails hang close (mean %.1f cm, most %.1f cm out)" % [tag, mean * 100.0, most * 100.0],
				mean < MEAN_OUT and most < MOST_OUT)
			li += 1
			if li >= LOOKS.size():
				return TK.done(fails)
			step = 0
			return false
	step += 1
	return false
