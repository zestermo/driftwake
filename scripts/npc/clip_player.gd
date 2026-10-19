class_name ClipPlayer
extends RefCounted
## Clips authored in Blender (docs/blender_clips.md) played by the Humanoid beside its keyed poses: an action
## named "clip_<name>" plays assets/clips/<name>.tres (a BodyClip) through Humanoid._action_pose, so it
## blends, masks, holds and mirrors to co-op screens like any keyed action. Held, it loops on the action's
## own clock; it eases in over BLEND from what the body was doing.
## The import (from_scene) is the reverse of the old BlenderBody's retarget: the armature's bones are named
## after the joints; each joint's global rotation is source_now = bone_now * bone_rest^-1 * source_rest (the
## rests: the armature's, and a fresh unposed Humanoid's), and its track is its rotation relative to its
## parent joint against the same at rest, as the animator's Euler (YXZ), kept continuous frame to frame.

const DIR := "res://assets/clips/"
const BLEND := 0.4

static var _clips: Dictionary = {}


static func clip(name: String) -> BodyClip:
	if not _clips.has(name):
		_clips[name] = load(DIR + name + ".tres")
	return _clips[name]


## [pose, mask, lift] for the action "clip_<name>" at `u` (Humanoid._action_pose).
static func pose(h, n: String, _u: float) -> Array:
	DowntimeProps.ensure(h, n)
	var c := clip(n.trim_prefix("clip_"))
	var t: float = float(h._action["t"])
	var into := minf(t / BLEND, 1.0)
	var p := c.sample(t)
	var lift := Vector3.ZERO
	if p.has("_lift"):
		lift = (p["_lift"] as Vector3) * Humanoid.PIVOT_Y / float(h.hip_y)
		p.erase("_lift")
	return [h._keys(into, [[0.0, {}], [1.0, p]]), c.mask, lift * into]


## Every joint's rest in the body's frame (rotations zeroed, as the animator writes them), from a body
## in the tree: name -> Transform3D. Also each joint's parent joint ("" for the root).
static func rests(h) -> Array:
	var keep := {}
	for j in Humanoid.JOINTS:
		var nd: Node3D = h.get(j)
		keep[j] = nd.transform
		nd.rotation = Vector3.ZERO
		nd.scale = Vector3.ONE
	if h.neck:
		keep["neck"] = h.neck.transform
		h.neck.rotation = Vector3.ZERO
	var inv: Transform3D = h.global_transform.affine_inverse()
	var out := {}
	var parents := {}
	for j in Humanoid.JOINTS:
		var nd: Node3D = h.get(j)
		out[j] = (inv * nd.global_transform).orthonormalized()
		parents[j] = _parent_joint(h, nd)
	for j in Humanoid.JOINTS:
		(h.get(j) as Node3D).transform = keep[j]
	if h.neck:
		h.neck.transform = keep["neck"]
	return [out, parents]


static func _parent_joint(h, nd: Node) -> String:
	var up := nd.get_parent()
	while up != null and up != h:
		for j in Humanoid.JOINTS:
			if h.get(j) == up:
				return j
		up = up.get_parent()
	return ""


## A BodyClip from an imported glb's scene (in the tree): its Skeleton3D's bones named after the joints, its
## AnimationPlayer's `anim` sampled at `fps`, retargeted onto the body whose rests() are `src`.
static func from_scene(root: Node, anim: String, src: Array, fps: float, mask: String, looped: bool) -> BodyClip:
	var skel: Skeleton3D = root.find_children("*", "Skeleton3D", true, false)[0]
	var ap: AnimationPlayer = root.find_children("*", "AnimationPlayer", true, false)[0]
	var s_rest: Dictionary = src[0]
	var parents: Dictionary = src[1]
	var a := ap.get_animation(anim)
	var c := BodyClip.new()
	c.fps = fps
	c.length = a.length
	c.loop = looped
	c.mask = mask
	var bones := {}
	for j in Humanoid.JOINTS:
		var b := skel.find_bone(j)
		if b >= 0:
			bones[j] = b
			if mask == "full" or j in Humanoid.UPPER:
				c.tracks[j] = PackedVector3Array()
	var to_body: Transform3D = (root as Node3D).global_transform.affine_inverse() * skel.global_transform
	var b_rest := {}
	for j in bones:
		b_rest[j] = to_body * skel.get_bone_global_rest(bones[j])
	var hips_k := 1.0
	if bones.has("pivot"):
		hips_k = (s_rest["pivot"] as Transform3D).origin.y / maxf((b_rest["pivot"] as Transform3D).origin.y, 0.001)
	ap.play(anim)
	var prev := {}
	for f in range(c.frames()):
		ap.seek(minf(f / fps, a.length), true)
		var s_now := {}
		for j in Humanoid.JOINTS:
			if not bones.has(j):
				continue
			var bn: Transform3D = to_body * skel.get_bone_global_pose(bones[j])
			s_now[j] = bn.basis.orthonormalized() * (b_rest[j] as Transform3D).basis.orthonormalized().inverse() * (s_rest[j] as Transform3D).basis
		for j in c.tracks:
			var p: String = parents[j]
			var rest_rel: Basis = (s_rest[j] as Transform3D).basis if p == "" else (s_rest[p] as Transform3D).basis.inverse() * (s_rest[j] as Transform3D).basis
			var now_rel: Basis = s_now[j] if p == "" or not s_now.has(p) else (s_now[p] as Basis).inverse() * (s_now[j] as Basis)
			var e := natural_euler((rest_rel.inverse() * now_rel).orthonormalized(), prev.get(j, Vector3.ZERO))
			prev[j] = e
			var tr: PackedVector3Array = c.tracks[j]
			tr.append(e)
			c.tracks[j] = tr
		if mask == "full" and bones.has("pivot"):
			var d: Vector3 = (to_body * skel.get_bone_global_pose(bones["pivot"])).origin - (b_rest["pivot"] as Transform3D).origin
			c.lift.append(d * hips_k)
	if not c.lift.is_empty() and Array(c.lift).all(func(v): return (v as Vector3).length() < 0.002):
		c.lift = PackedVector3Array()
	return c


## The Euler (YXZ) of `b` the animator would write: of its two solutions (x and PI - x), the one with the
## smaller twist (a forearm bent past a right angle stays a bend, not a flip round), each angle wrapped to
## within PI of the frame before.
static func natural_euler(b: Basis, near: Vector3) -> Vector3:
	var e := b.get_euler()
	var alt := Vector3(PI - e.x, e.y + PI, e.z + PI)
	alt = Vector3(wrapf(alt.x, -PI, PI), wrapf(alt.y, -PI, PI), wrapf(alt.z, -PI, PI))
	var pick := alt if absf(alt.y) + absf(alt.z) < absf(e.y) + absf(e.z) - 0.001 else e
	return Vector3(near.x + wrapf(pick.x - near.x, -PI, PI), near.y + wrapf(pick.y - near.y, -PI, PI), near.z + wrapf(pick.z - near.z, -PI, PI))
