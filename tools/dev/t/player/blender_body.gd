extends SceneTree
## F4's Blender body (BlenderBody, assets/models/captain/captain.glb): it hides the procedural body, its bones
## follow the procedural joints and skeleton bones through a weapon draw, the fist mirrors the procedural one,
## and F4 again gives the procedural body back.
const TK := preload("res://tools/dev/test_kit.gd")
const BONES := ["ForeR", "ArmBody_shoulder_r_4", "LowerBody_knee_l_3", "HeadChains_chain0_1"]
var stage
var p
var b
var step := 0
var until := 0
var fails := 0
var fore_at := Transform3D()


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "weapon": "cutlass"})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func bb() -> Node:
	return b.get_node_or_null("BlenderBody")


func procedural() -> Array:
	return b.find_children("*", "MeshInstance3D", true, false).filter(func(n): return n.has_meta("body_part"))


## Worst gap (m) between a Blender bone and the joint or bone it copies, both in the body's space.
func worst_gap() -> String:
	var sk: Skeleton3D = bb().skel
	var k: Transform3D = BlenderBody._xf(sk, b)
	var src: Dictionary = BlenderBody._sources(b)
	var hinv: Transform3D = b.global_transform.affine_inverse()
	var worst := 0.0
	var at := ""
	for bn in BONES:
		var i := sk.find_bone(bn)
		if i < 0:
			return "no bone " + bn
		var s: Dictionary = src[bn]
		var now: Transform3D = hinv * (s["node"] as Node3D).global_transform
		if int(s["bone"]) >= 0:
			now = now * (s["node"] as Skeleton3D).get_bone_global_pose(s["bone"])
		var d := (k * sk.get_bone_global_pose(i)).origin.distance_to(now.origin)
		if d > worst:
			worst = d
			at = bn
	return "" if worst < 0.01 else "%s off by %.3f m" % [at, worst]


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			b = p.body_model
			print(BlenderBody.toggle(b))
			until = TK.wait_ticks(10)
		1:
			check("F4 puts the Blender body on", bb() != null and bb().skel.get_bone_count() > 40)
			check("the procedural body is hidden", procedural().all(func(m): return m.layers == 0))
			var gap := worst_gap()
			check("Blender bones sit on the rig at rest" + ("" if gap == "" else ": " + gap), gap == "")
			fore_at = b.global_transform.affine_inverse() * b.fore_r.global_transform
			TK.act("ready_weapon")
			until = TK.wait_secs(0.6)
		2:
			var moved: float = (b.global_transform.affine_inverse() * b.fore_r.global_transform).origin.distance_to(fore_at.origin)
			check("drawing moves the forearm (%.2f m)" % moved, moved > 0.02)
			var gap := worst_gap()
			check("Blender bones follow the drawn pose" + ("" if gap == "" else ": " + gap), gap == "")
			var pairs := 0
			var same := 0
			for m in bb().find_children("*", "MeshInstance3D", true, false):
				for src in procedural():
					if BlenderBody._part_name(src) == String(m.name):
						pairs += 1
						same += int(m.visible == src.is_visible_in_tree())
			check("every Blender part mirrors its procedural part's visibility (%d/%d)" % [same, pairs], pairs > 5 and same == pairs)
			print(BlenderBody.toggle(b))
			until = TK.wait_ticks(2)
		3:
			check("F4 again restores the procedural body", bb() == null and procedural().all(func(m): return m.layers != 0))
			return TK.done(fails)
	step += 1
	return false
