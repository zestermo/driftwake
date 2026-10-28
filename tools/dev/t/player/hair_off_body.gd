extends SceneTree
## The 1.25 dreadlocks stay off the body: standing still their chains settle clear of the torso and shoulders, and under
## the chains kit's script (running, 180 turns, hops, a leaning torso, uneven frame times) they go into the torso in no
## more frames, and no deeper, than the long hair does (the old long style with chains, the yardstick).
const TK := preload("res://tools/dev/test_kit.gd")
const KIT := preload("res://tools/dev/t/player/_chains_kit.gd")
const CLEAR := 0.03
const SLACK := 10
var stage
var fails := 0


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
	for body in ["masc", "fem"]:
		var rec := {}
		for st in ["long", "dreads"]:
			var lk := CharacterLook.base_look()
			lk.merge({"hair": st, "body": body}, true)
			var h = KIT.body(root, lk, SpringChains.native_ok)
			var still := 0.0
			for i in range(120):
				for s in h._sims:
					s.simulate(1.0 / 60.0)
				if i > 60:
					still = maxf(still, _deep(h))
			var r := [0, 0.0]
			var sh := [0, 0.0]
			for i in range(KIT.FRAMES):
				KIT.drive(h, i, KIT.yaw_at(i))
				var d := _deep(h, ["torso"])
				if d > 0.0:
					r[0] += 1
					r[1] = maxf(r[1], d)
				var d2 := _deep(h, ["hair_sh"])
				if d2 > 0.0:
					sh[0] += 1
					sh[1] = maxf(sh[1], d2)
			rec[st] = r
			rec[st + "_sh"] = sh
			print("%s %s: settled %.1f cm in, driven into the torso %d frames (worst %.1f cm), shoulders %d (%.1f cm)" % [body, st, still * 100.0, r[0], r[1] * 100.0, sh[0], sh[1] * 100.0])
			if st == "dreads":
				check("%s dreads settle clear of the body (%.1f cm in)" % [body, still * 100.0], still <= 0.0)
			h.queue_free()
		var lr: Array = rec["long"]
		var dr: Array = rec["dreads"]
		check("%s dreads go into the torso no more than long hair (%d frames, long %d)" % [body, dr[0], lr[0]],
			dr[0] <= lr[0] + SLACK and dr[1] <= float(lr[1]) + 0.03)
		var ls: Array = rec["long_sh"]
		var ds: Array = rec["dreads_sh"]
		check("%s dreads go into the shoulders no more than long hair (%d frames, long %d)" % [body, ds[0], ls[0]],
			ds[0] <= ls[0] + SLACK and ds[1] <= float(ls[1]) + 0.03)
	return TK.done(fails)


## How deep the head's chain segments (below their roots) go into the torso and shoulders' capsules this frame.
func _deep(h, keys: Array = ["torso", "hair_sh"]) -> float:
	var cols: Dictionary = h._sims[0].colliders.duplicate()
	# (the shoulders' capsule as HairFlow and the dreads add it, for every style alike)
	cols["hair_sh"] = {"node": h.torso, "a": h.arm_l.position + Vector3(0, 0.05, 0), "b": h.arm_r.position + Vector3(0, 0.05, 0), "r": 0.075}
	var caps: Array = []
	for key in keys:
		var cd: Dictionary = cols[key]
		var tt: Transform3D = (cd["node"] as Node3D).global_transform
		caps.append([tt * (cd["a"] as Vector3), tt * (cd["b"] as Vector3), float(cd["r"]) * tt.basis.get_scale().x - CLEAR])
	var deep := 0.0
	for s in h._sims:
		if s.get_parent() != h.head:
			continue
		var gt: Transform3D = s.skel.global_transform
		for ci in range(s.chain_count()):
			var c: Dictionary = s.chain(ci)
			var pts: PackedVector3Array = c["p"]
			var bones: PackedInt32Array = c["bones"]
			for j in range(1, bones.size()):
				var bp: Transform3D = s.skel.get_bone_global_pose(bones[j])
				var b: Vector3 = gt * (bp.origin + bp.basis * (pts[j + 1] - pts[j]))
				var a: Vector3 = gt * bp.origin
				for cap in caps:
					var stt: Array = SpringChains._closest_segments(a, b, cap[0], cap[1])
					deep = maxf(deep, float(cap[2]) - (stt[0] as Vector3).distance_to(stt[1]))
	return deep
