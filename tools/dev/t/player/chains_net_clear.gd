extends SceneTree
## The cape's net on the wardrobe: the same bodies run the kit's script (running, 180 turns, hops, legs kicking back into
## the drapes, uneven frame times) bare (BodyBuilder.cloth_net and cape_net off) and netted. Netted, the drawn cape,
## skirt, coat tails and sash go into the legs (less the capsules' clearance) in a small share of the frames and a third
## or less of the bare count, and long hair goes into the torso no more than bare.
const TK := preload("res://tools/dev/test_kit.gd")
const KIT := preload("res://tools/dev/t/player/_chains_kit.gd")
## The share of frames the netted drapes may dip into the legs for (where no turn of NET_TURN about a root clears
## them: a thigh swung back through a skirt's side), and how many more frames netted hair may touch the torso than bare
## (the swing range clamps a tail thrown round a 180 turn back past the shoulder).
const LEGS_SHARE := 0.1
const HAIR_SLACK := 10
const LEGS := ["thigh_l", "thigh_r", "shin_l", "shin_r"]
const CLEAR := 0.03
var stage
var fails := 0
var bare := {}


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _process(_d: float) -> bool:
	if not stage.up:
		return false
	# (the cloth's nets are native only: a checkout that hasn't built native/ has none to test)
	if not SpringChains.native_ok:
		print("SKIP native not built (no ChainSolver at API %d in bin/): the cloth has no nets" % SpringChains.NATIVE_API)
		return TK.done(fails)
	for netted in [false, true]:
		BodyBuilder.cloth_net = netted
		BodyBuilder.cape_net = netted
		for lk in KIT.looks():
			var base := "cloak" if lk.get("cloak", false) else "cape"
			var tag := base + (", nets" if netted else ", no nets")
			var h = KIT.body(root, lk, SpringChains.native_ok)
			var rec := {"legs": [0, 0.0], "torso": [0, 0.0]}
			for i in range(KIT.FRAMES):
				KIT.drive(h, i, KIT.yaw_at(i))
				_tally(rec["legs"], _deep(h, LEGS, [h.torso, h.hips]))
				_tally(rec["torso"], _deep(h, ["torso"], [h.head]))
			print("%s: drapes into the legs %d frames (worst %.1f cm), hair into the torso %d frames (worst %.1f cm)" % [
				tag, rec["legs"][0], rec["legs"][1] * 100.0, rec["torso"][0], rec["torso"][1] * 100.0])
			var was: Dictionary = bare.get(base, {})
			if not netted:
				bare[base] = rec
			else:
				var legs_was: int = was["legs"][0]
				var hair_was: int = was["torso"][0]
				check("%s: every set netted" % tag, h._sims.all(func(s): return s.net and s.mode in ["a", "n"]))
				check("%s: the drapes go into the legs in %d frames of %d, under %d%% and a third of without (%d)" % [tag, rec["legs"][0],
					KIT.FRAMES, int(LEGS_SHARE * 100), legs_was], rec["legs"][0] < KIT.FRAMES * LEGS_SHARE and rec["legs"][0] * 3 <= legs_was)
				check("%s: the hair goes into the torso no more than without (%d frames, was %d)" % [tag, rec["torso"][0], hair_was],
					rec["torso"][0] <= hair_was + HAIR_SLACK and rec["torso"][1] <= float(was["torso"][1]) + 0.03)
			h.queue_free()
	BodyBuilder.cloth_net = true
	BodyBuilder.cape_net = true
	return TK.done(fails)


func _tally(r: Array, deep: float) -> void:
	if deep > 0.0:
		r[0] += 1
		r[1] = maxf(r[1], deep)


## How deep the drawn segments of the chain sets on `anchors` go into the named capsules this frame (0: clear).
func _deep(h, caps: Array, anchors: Array) -> float:
	var cw: Array = []
	var cols: Dictionary = h._sims[0].colliders
	for key in caps:
		var cd: Dictionary = cols[key]
		var tt: Transform3D = (cd["node"] as Node3D).global_transform
		# (less the capsules' clearance over the limb, as capelab measures: inside that is inside the body)
		cw.append([tt * (cd["a"] as Vector3), tt * (cd["b"] as Vector3), float(cd["r"]) * tt.basis.get_scale().x - CLEAR])
	var deep := 0.0
	for s in h._sims:
		if not (s.get_parent() in anchors):
			continue
		var gt: Transform3D = s.skel.global_transform
		for ci in range(s.chain_count()):
			var c: Dictionary = s.chain(ci)
			var pts: PackedVector3Array = c["p"]
			var bones: PackedInt32Array = c["bones"]
			# (below the root segment: it hangs from where it's sewn on, over the thigh's top or the nape, and no turn
			# about its root moves it off them)
			for j in range(1, bones.size()):
				var bp: Transform3D = s.skel.get_bone_global_pose(bones[j])
				var b: Vector3 = gt * (bp.origin + bp.basis * (pts[j + 1] - pts[j]))
				var a: Vector3 = gt * bp.origin
				for cap in cw:
					var st: Array = SpringChains._closest_segments(a, b, cap[0], cap[1])
					deep = maxf(deep, float(cap[2]) - (st[0] as Vector3).distance_to(st[1]))
	return deep
