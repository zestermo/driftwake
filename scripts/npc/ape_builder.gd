class_name ApeBuilder
extends RefCounted
## The silverback's body (JungleApe; a look with "beast": "ape" builds this
## instead of BodyBuilder). A gorilla on the Humanoid's joints, so every pose,
## the ragdoll and co-op puppets work unchanged: short legs, arms longer than
## them ending in knuckle-walking fists, a barrel chest and a hump of shoulder,
## a small head set low with a heavy brow and a sagittal crest. Shaggy fur as
## clumps of 3-sided tufts, the silver saddle painted over the back, rump and
## thighs, a bare scarred chest, a bone necklace and a broken harpoon in the
## shoulder. Rigid parts per joint (PS1 style), in the rig's unit space (the
## Humanoid scales it by the look's height).

const HIP_Y := 0.68
const THIGH := 0.3
const LEG_X := 0.15
const SH_X := 0.28
const SH_Y := 0.52
const UPPER := 0.4
const FORE := 0.38
const DARK := Color(0.2, 0.18, 0.17)
const SILVER := Color(0.95, 0.95, 0.93)
const BONE := Color(0.88, 0.84, 0.72)
const SCAR := Color(0.66, 0.42, 0.4)

var h: Humanoid
var fur: Material
var skin: Material
var flat: Material
var eye: Material
var rng := RandomNumberGenerator.new()
var _parts := {}
## Where the swinging parts hang from (torso space), and what's being built for one (its points are made from there).
const MANE_AT := Vector3(0, 0.6, 0.12)
const NECK_AT := Vector3(0, 0.56, -0.02)
var _off := Vector3.ZERO


static func build(hum: Humanoid, _look: Dictionary) -> void:
	var b := ApeBuilder.new()
	b._run(hum)


func _run(hum: Humanoid) -> void:
	h = hum
	rng.seed = 7741
	fur = PSXMat.lit("fur", Color(1.1, 1.1, 1.1))
	skin = PSXMat.lit("leather", Color(0.44, 0.4, 0.39))
	flat = PSXMat.flat(Color.WHITE)
	eye = PSXMat.glow(Color(1.0, 0.55, 0.12), 1.4)
	_skeleton()
	_torso()
	_hips()
	_head()
	for side in [-1.0, 1.0]:
		_arm(side)
		_leg(side)
	for node in _parts.keys():
		var mb: MeshBuilder = _parts[node]
		_paint(mb, node)
		(node as Node3D).add_child(mb.to_instance("Mesh"))
	_breakables()


## Its own nodes for the 1.23 beast pass (JungleApe reads them by name): the hump's long hair ("Mane") and the
## necklace ("Necklace") swing on springs; the tusks ("Tusks", "TusksBroken") and the stone-hard knuckle pads
## ("Knuckles", "KnucklesBroken" on each hand) break off; the eyes ("Eyes") change with its phase.
func _breakables() -> void:
	var tusks := MeshBuilder.new()
	var stubs := MeshBuilder.new()
	for s in [-1.0, 1.0]:
		var root := Vector3(s * 0.04, -0.035, -0.158)
		tusks.add_tube(flat, PackedVector3Array([root, root + Vector3(s * 0.025, 0.05, -0.025), root + Vector3(s * 0.05, 0.1, -0.015), root + Vector3(s * 0.05, 0.13, 0.01)]),
			0.017, 0.004, 5, 1.0, BONE)
		stubs.add_cylinder(flat, Transform3D(_yb(Vector3(s * 0.4, 1, -0.4)), root), 0.017, 0.012, 0.03, 5, 1.0, BONE.darkened(0.15), false, true, false)
		stubs.add_box(flat, Transform3D(Basis(), root + Vector3(0, -0.012, 0)), Vector3(0.03, 0.012, 0.02), 1.0, Color(0.45, 0.06, 0.05), false)
	h.head.add_child(_named(tusks.to_instance("Tusks"), true))
	h.head.add_child(_named(stubs.to_instance("TusksBroken"), false))
	for hand in [h.hand_l, h.hand_r]:
		var pads := MeshBuilder.new()
		var raw := MeshBuilder.new()
		for i in range(4):
			var x := lerpf(-0.052, 0.052, i / 3.0)
			pads.add_box(flat, Transform3D(Basis(Vector3.RIGHT, 0.3), Vector3(x, -0.142, -0.05)), Vector3(0.036, 0.022, 0.04), 1.0, Color(0.55, 0.53, 0.5), false)
			raw.add_box(flat, Transform3D(Basis(Vector3.RIGHT, 0.3), Vector3(x, -0.138, -0.048)), Vector3(0.03, 0.012, 0.035), 1.0, Color(0.5, 0.07, 0.06), false)
		(hand as Node3D).add_child(_named(pads.to_instance("Knuckles"), true))
		(hand as Node3D).add_child(_named(raw.to_instance("KnucklesBroken"), false))
	var eyes := MeshBuilder.new()
	for s in [-1.0, 1.0]:
		eyes.add_box(flat, Transform3D(Basis(), Vector3(s * 0.042, 0.066, -0.109)), Vector3(0.02, 0.013, 0.008), 1.0)
	var emi := eyes.to_instance("Eyes")
	emi.material_override = eye
	h.head.add_child(emi)


func _named(mi: MeshInstance3D, on: bool) -> MeshInstance3D:
	mi.visible = on
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


func _node(n: String, pos: Vector3, parent: Node3D) -> Node3D:
	var p := Node3D.new()
	p.name = n
	p.position = pos
	parent.add_child(p)
	return p


func _mb(node: Node3D) -> MeshBuilder:
	if not _parts.has(node):
		_parts[node] = MeshBuilder.new()
	return _parts[node]


func _skeleton() -> void:
	h.hip_y = HIP_Y
	h.pivot = _node("Pivot", Vector3(0, HIP_Y, 0), h)
	h.hips = _node("Hips", Vector3.ZERO, h.pivot)
	h.leg_l = _node("LegL", Vector3(-LEG_X, -0.03, 0.02), h.hips)
	h.leg_r = _node("LegR", Vector3(LEG_X, -0.03, 0.02), h.hips)
	# (shin as long as the thigh: foot IK assumes it)
	h.shin_l = _node("ShinL", Vector3(0, -THIGH, 0), h.leg_l)
	h.shin_r = _node("ShinR", Vector3(0, -THIGH, 0), h.leg_r)
	h.torso = _node("Torso", Vector3.ZERO, h.hips)
	h.arm_l = _node("ArmL", Vector3(-SH_X, SH_Y, 0.03), h.torso)
	h.arm_r = _node("ArmR", Vector3(SH_X, SH_Y, 0.03), h.torso)
	h.fore_l = _node("ForeL", Vector3(0, -UPPER, 0), h.arm_l)
	h.fore_r = _node("ForeR", Vector3(0, -UPPER, 0), h.arm_r)
	h.hand_l = _node("HandL", Vector3(0, -FORE, -0.01), h.fore_l)
	h.hand_r = _node("HandR", Vector3(0, -FORE, -0.01), h.fore_r)
	h.neck = _node("Neck", Vector3(0, 0.5, -0.1), h.torso)
	h.head = _node("Head", Vector3(0, 0.04, -0.03), h.neck)
	h.hip_socket = _node("HipSocket", Vector3(-0.26, 0.05, 0.02), h.torso)


# --------------------------------------------------------------------------
# Helpers
# --------------------------------------------------------------------------
## A basis whose +Y points along d.
static func _yb(d: Vector3) -> Basis:
	var y := d.normalized()
	var x := y.cross(Vector3.FORWARD if absf(y.z) < 0.9 else Vector3.RIGHT).normalized()
	return Basis(x, y, x.cross(y))


## Ring sizes [y, hw, hd, cz, cx] at height y (rings listed in either order).
static func _ring_at(rings: Array, y: float) -> Array:
	for i in range(1, rings.size()):
		var a: Array = rings[i - 1]
		var b: Array = rings[i]
		if (y - float(a[0])) * (y - float(b[0])) <= 0.0 and a[0] != b[0]:
			var t := (y - float(a[0])) / (float(b[0]) - float(a[0]))
			var out := []
			for k in range(5):
				out.append(lerpf(float(a[k]) if k < a.size() else 0.0, float(b[k]) if k < b.size() else 0.0, t))
			return out
	var e: Array = rings[0] if absf(y - float(rings[0][0])) < absf(y - float(rings[rings.size() - 1][0])) else rings[rings.size() - 1]
	return [e[0], e[1], e[2], e[3] if e.size() > 3 else 0.0, e[4] if e.size() > 4 else 0.0]


## A point on a lofted part's surface and its outward normal (a = 0 at the front, -z).
static func _on(rings: Array, y: float, a: float) -> Array:
	var r := _ring_at(rings, y)
	var p := Vector3(float(r[4]) + sin(a) * float(r[1]), y, float(r[3]) - cos(a) * float(r[2]))
	var n := Vector3(sin(a) / maxf(float(r[1]), 0.01), 0.0, -cos(a) / maxf(float(r[2]), 0.01)).normalized()
	return [p, n]


## A clump of fur: a 3-sided spike from the surface.
func _tuft(mb: MeshBuilder, at: Vector3, dir: Vector3, length: float, w: float) -> void:
	var s := rng.randf_range(0.62, 0.92)
	var b := _yb(dir) * Basis(Vector3.UP, rng.randf() * TAU)
	mb.add_cylinder(fur, Transform3D(b, at - _off), w, 0.0, length, 3, 5.0, Color(s, s, s), false, false, false)


## Tufts scattered over a lofted part: `count` between heights y0..y1 and angles a0..a1,
## each hanging along `down` and out from the surface.
func _shag(mb: MeshBuilder, rings: Array, y0: float, y1: float, a0: float, a1: float, count: int,
		length: float, down: Vector3, out_k: float = 0.55, skip: Callable = Callable()) -> void:
	var n := 0
	var tries := 0
	while n < count and tries < count * 4:
		tries += 1
		var y := rng.randf_range(y0, y1)
		var a := rng.randf_range(a0, a1)
		var s := _on(rings, y, a)
		var p: Vector3 = s[0]
		if skip.is_valid() and skip.call(p):
			continue
		var nn: Vector3 = s[1]
		var l := length * rng.randf_range(0.7, 1.25)
		_tuft(mb, p - nn * l * 0.12, (nn * out_k + down.normalized()).normalized(), l, l * 0.34)
		n += 1


## The silver saddle: fur vertices over the back, rump and thighs fade to silver.
func _paint(mb: MeshBuilder, node: Node3D) -> void:
	if not mb._surfaces.has(fur):
		return
	var v: PackedVector3Array = mb._surfaces[fur]["v"]
	var c: PackedColorArray = mb._surfaces[fur]["c"]
	for i in range(v.size()):
		var w := _silver(node, v[i])
		var k := c[i].r
		c[i] = DARK.lerp(SILVER, w) * k
	mb._surfaces[fur]["c"] = c


func _silver(node: Node3D, p: Vector3) -> float:
	var wob := sin(p.x * 31.0 + p.y * 17.0) * 0.025
	if node == h.torso:
		# the saddle: the lower back, up toward the shoulder blades
		return smoothstep(-0.02, 0.1, p.z + wob) * (1.0 - smoothstep(0.38, 0.5, p.y + wob))
	if node == h.hips:
		return smoothstep(-0.08, 0.06, p.z + wob)
	if node == h.leg_l or node == h.leg_r:
		return smoothstep(0.0, 0.1, p.z + wob) * smoothstep(-0.24, -0.1, p.y)
	return 0.0


# --------------------------------------------------------------------------
# Body
# --------------------------------------------------------------------------
const TORSO := [[-0.14, 0.17, 0.15, 0.03], [-0.04, 0.23, 0.2, 0.0], [0.08, 0.27, 0.235, -0.03], [0.2, 0.285, 0.235, -0.02],
	[0.32, 0.31, 0.24, 0.0], [0.44, 0.35, 0.24, 0.02], [0.54, 0.31, 0.22, 0.05], [0.62, 0.22, 0.19, 0.08],
	[0.7, 0.12, 0.13, 0.1], [0.745, 0.03, 0.04, 0.1]]


static func _chest(p: Vector3) -> bool:
	return p.z < -0.1 and p.y > 0.2 and p.y < 0.47 and absf(p.x) < 0.2


func _torso() -> void:
	var mb := _mb(h.torso)
	var prof := MeshBuilder.profile_circle(10)
	mb.add_loft(fur, Transform3D.IDENTITY, TORSO, prof, 4.0, Color.WHITE, true, true, true, false, false,
		PackedInt32Array(), skin, Callable(), func(p: Vector3): return skin if _chest(p) else false)
	# the bare chest's pecs and the claw scars across them
	for s in [-1.0, 1.0]:
		mb.add_blob(skin, Transform3D(Basis(Vector3.RIGHT, 0.25), Vector3(s * 0.1, 0.37, -0.205)), Vector3(0.12, 0.085, 0.05), rng, 0.05, 3, 6, 4.0)
	for i in range(3):
		var b := Basis(Vector3.FORWARD, 0.75) * Basis(Vector3.RIGHT, 0.25)
		mb.add_box(flat, Transform3D(b, Vector3(0.06 + i * 0.035, 0.36 - i * 0.02, -0.252)), Vector3(0.012, 0.15, 0.012), 1.0, SCAR, false)
	# fur over the back, sides and belly; the chest stays bare
	# (the saddle's hair is short: no clumps on it)
	var bare := func(p: Vector3): return _chest(p) or (p.z < -0.15 and p.y > 0.14 and absf(p.x) < 0.24) or _silver(h.torso, p) > 0.3
	_shag(mb, TORSO, -0.1, 0.66, -PI, PI, 48, 0.13, Vector3(0, -1, 0.35), 0.32, bare)
	# the hump and shoulder line: longer, swept back (its own node: it swings, JungleApe)
	var mane := _node("Mane", MANE_AT, h.torso)
	_off = MANE_AT
	_shag(_mb(mane), TORSO, 0.5, 0.72, 0.9, TAU - 0.9, 18, 0.14, Vector3(0, -0.4, 1.0), 0.4)
	_off = NECK_AT
	_necklace(_mb(_node("Necklace", NECK_AT, h.torso)))
	_off = Vector3.ZERO
	_harpoon(mb)


## A cord of teeth and finger bones with a captain's skull at the front.
func _necklace(mb: MeshBuilder) -> void:
	var pts := PackedVector3Array()
	for i in range(13):
		var a := lerpf(-1.9, 1.9, i / 12.0)
		pts.append(Vector3(sin(a) * 0.27, 0.5 - cos(a) * 0.075, -cos(a) * 0.23 + 0.02) - _off)
	mb.add_tube(flat, pts, 0.008, 0.008, 4, 1.0, Color(0.32, 0.22, 0.13))
	for i in range(1, 12):
		if i == 6:
			continue
		var p: Vector3 = pts[i]
		var l := 0.05 if i % 2 == 0 else 0.035
		mb.add_cylinder(flat, Transform3D(_yb(Vector3(0, -1, -0.25)), p), 0.012, 0.003, l, 4, 1.0, BONE, false, false, false)
	var sk: Vector3 = pts[6] + Vector3(0, -0.04, -0.015)
	mb.add_blob(flat, Transform3D(Basis(), sk), Vector3(0.032, 0.036, 0.03), rng, 0.0, 3, 6, 1.0, BONE)
	for s in [-1.0, 1.0]:
		mb.add_box(flat, Transform3D(Basis(), sk + Vector3(s * 0.012, 0.004, -0.028)), Vector3(0.012, 0.012, 0.006), 1.0, Color(0.06, 0.05, 0.05), false)


## A broken harpoon shaft lodged behind the left shoulder, a frayed line from it.
func _harpoon(mb: MeshBuilder) -> void:
	var a := Vector3(-0.17, 0.5, 0.13)
	var b := Vector3(-0.3, 0.76, 0.42)
	mb.add_tube(flat, PackedVector3Array([a, b]), 0.014, 0.012, 5, 1.0, Color(0.42, 0.3, 0.18), false, false)
	mb.add_cylinder(flat, Transform3D(_yb(b - a), b), 0.013, 0.0, 0.05, 4, 1.0, Color(0.5, 0.38, 0.24), false, false, false)
	mb.add_tube(flat, MeshBuilder.curve_points(a.lerp(b, 0.55), Vector3(-0.36, 0.5, 0.36), Vector3(-0.32, 0.36, 0.26), 6), 0.006, 0.005, 3, 1.0, Color(0.55, 0.48, 0.34))
	mb.add_blob(flat, Transform3D(Basis(), a.lerp(b, 0.38)), Vector3(0.04, 0.03, 0.035), rng, 0.2, 2, 5, 1.0, Color(0.3, 0.06, 0.05))


const HIPS := [[-0.18, 0.12, 0.1, 0.05], [-0.1, 0.22, 0.17, 0.04], [0.0, 0.245, 0.19, 0.02], [0.08, 0.2, 0.17, 0.0]]


func _hips() -> void:
	var mb := _mb(h.hips)
	mb.add_loft(fur, Transform3D.IDENTITY, HIPS, MeshBuilder.profile_circle(10), 4.0, Color.WHITE, true, true)
	_shag(mb, HIPS, -0.16, 0.04, PI * 0.35, PI * 1.65, 10, 0.11, Vector3(0, -1, 0.3), 0.35, func(p: Vector3): return _silver(h.hips, p) > 0.3)


const UPPER_ARM := [[0.09, 0.1, 0.1], [0.02, 0.135, 0.13], [-0.12, 0.13, 0.12], [-0.28, 0.11, 0.105], [-0.42, 0.095, 0.095]]
const FOREARM := [[0.03, 0.1, 0.1], [-0.1, 0.112, 0.105], [-0.26, 0.095, 0.09], [-0.36, 0.076, 0.07], [-0.4, 0.07, 0.065]]


func _arm(side: float) -> void:
	var arm: Node3D = h.arm_l if side < 0.0 else h.arm_r
	var fore: Node3D = h.fore_l if side < 0.0 else h.fore_r
	var hand: Node3D = h.hand_l if side < 0.0 else h.hand_r
	var prof := MeshBuilder.profile_circle(8)
	var amb := _mb(arm)
	amb.add_loft(fur, Transform3D.IDENTITY, UPPER_ARM, prof, 4.0, Color.WHITE, true, true)
	_shag(amb, UPPER_ARM, -0.36, 0.06, -PI, PI, 18, 0.12, Vector3(side * 0.2, -1, 0.15), 0.35)
	var fmb := _mb(fore)
	fmb.add_blob(fur, Transform3D.IDENTITY, Vector3(0.1, 0.1, 0.1), rng, 0.0, 3, 6, 4.0)
	fmb.add_loft(fur, Transform3D.IDENTITY, FOREARM, prof, 4.0, Color.WHITE, false, true)
	# the long hair of a gorilla's forearms, thickest along the back and the outside
	_shag(fmb, FOREARM, -0.34, 0.0, -PI, PI, 12, 0.12, Vector3(side * 0.3, -1, 0.2), 0.4)
	_shag(fmb, FOREARM, -0.3, -0.02, PI * 0.25 * side, PI * 0.25 * side + PI, 14, 0.16, Vector3(side * 0.6, -1, 0.5), 0.55)
	_fist(_mb(hand), side)


## A knuckle-walking fist: furred back of the hand, bare curled fingers, the thumb inside.
func _fist(mb: MeshBuilder, side: float) -> void:
	var back := [[0.03, 0.07, 0.06], [-0.04, 0.08, 0.065, -0.005], [-0.1, 0.075, 0.06, -0.01]]
	mb.add_loft(fur, Transform3D.IDENTITY, back, MeshBuilder.profile_oct(0.55), 4.0, Color.WHITE, false, false)
	mb.add_box(skin, Transform3D(Basis(), Vector3(0, -0.06, 0.035)), Vector3(0.13, 0.11, 0.035), 4.0, Color(0.85, 0.85, 0.85), false)
	for i in range(4):
		var x := lerpf(-0.052, 0.052, i / 3.0)
		var l := 0.05 if i == 1 or i == 2 else 0.044
		mb.add_box(skin, Transform3D(Basis(Vector3.RIGHT, -0.15), Vector3(x, -0.115, -0.012)), Vector3(0.032, l, 0.085), 4.0, Color.WHITE, false)
		mb.add_box(skin, Transform3D(Basis(), Vector3(x, -0.13, -0.04)), Vector3(0.03, 0.03, 0.03), 4.0, Color(0.8, 0.8, 0.8), false)
	mb.add_box(skin, Transform3D(Basis(Vector3.FORWARD, side * 0.5), Vector3(-side * 0.075, -0.05, -0.02)), Vector3(0.03, 0.07, 0.035), 4.0, Color.WHITE, false)
	for i in range(5):
		_tuft(mb, Vector3(rng.randf_range(-0.06, 0.06), 0.0, rng.randf_range(-0.04, 0.04)), Vector3(side * 0.3, -1, -0.3), 0.07, 0.03)


const THIGH_R := [[0.07, 0.135, 0.135], [-0.05, 0.145, 0.14], [-0.18, 0.125, 0.12], [-0.31, 0.09, 0.095]]
const SHIN_R := [[0.03, 0.095, 0.1], [-0.12, 0.09, 0.09, 0.005], [-0.25, 0.07, 0.07], [-0.3, 0.065, 0.065]]


func _leg(side: float) -> void:
	var leg: Node3D = h.leg_l if side < 0.0 else h.leg_r
	var shin: Node3D = h.shin_l if side < 0.0 else h.shin_r
	var prof := MeshBuilder.profile_circle(8)
	var lmb := _mb(leg)
	lmb.add_loft(fur, Transform3D.IDENTITY, THIGH_R, prof, 4.0, Color.WHITE, true, true)
	_shag(lmb, THIGH_R, -0.26, 0.02, -PI, PI, 10, 0.1, Vector3(side * 0.15, -1, 0.2), 0.35, func(p: Vector3): return _silver(leg, p) > 0.3)
	var smb := _mb(shin)
	smb.add_blob(fur, Transform3D.IDENTITY, Vector3(0.095, 0.09, 0.1), rng, 0.0, 3, 6, 4.0)
	smb.add_loft(fur, Transform3D.IDENTITY, SHIN_R, prof, 4.0, Color.WHITE, false, false)
	_shag(smb, SHIN_R, -0.24, -0.02, -PI, PI, 8, 0.08, Vector3(0, -1, 0.2), 0.35)
	# a broad bare foot, the big toe set apart on the inside
	smb.add_box(skin, Transform3D(Basis(), Vector3(side * 0.01, -0.33, -0.035)), Vector3(0.13, 0.06, 0.2), 4.0, Color.WHITE, false)
	smb.add_box(skin, Transform3D(Basis(), Vector3(side * 0.005, -0.31, 0.04)), Vector3(0.1, 0.06, 0.07), 4.0, Color(0.85, 0.85, 0.85), false)
	for i in range(4):
		var x := side * lerpf(0.04, -0.02, i / 3.0) + side * 0.012
		smb.add_box(skin, Transform3D(Basis(), Vector3(x, -0.345, -0.15)), Vector3(0.026, 0.03, 0.05), 4.0, Color(0.8, 0.8, 0.8), false)
	smb.add_box(skin, Transform3D(Basis(Vector3.UP, side * 0.5), Vector3(-side * 0.065, -0.345, -0.09)), Vector3(0.035, 0.035, 0.07), 4.0, Color.WHITE, false)


# --------------------------------------------------------------------------
# Head
# --------------------------------------------------------------------------
const SKULL := [[-0.07, 0.08, 0.085, 0.0], [0.0, 0.105, 0.105, -0.01], [0.06, 0.11, 0.11, 0.0], [0.11, 0.1, 0.1, 0.015],
	[0.15, 0.075, 0.085, 0.025], [0.175, 0.03, 0.045, 0.035]]


func _head() -> void:
	var mb := _mb(h.head)
	mb.add_loft(fur, Transform3D.IDENTITY, SKULL, MeshBuilder.profile_circle(10), 4.0, Color.WHITE, true, true, true, false, false,
		PackedInt32Array(), skin, Callable(), func(p: Vector3): return skin if p.z < -0.05 and p.y < 0.1 else false)
	# the sagittal crest, rising to the back of the skull
	var crest := PackedVector2Array([Vector2(0.03, 0.14), Vector2(-0.02, 0.19), Vector2(-0.07, 0.225), Vector2(-0.115, 0.21),
		Vector2(-0.13, 0.15), Vector2(-0.1, 0.09), Vector2(0.0, 0.1)])
	mb.add_extrude(fur, Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3.ZERO), crest, 0.05, 4.0, Color(0.9, 0.9, 0.9))
	# the heavy brow, the deep-set eyes under it
	mb.add_box(skin, Transform3D(Basis(Vector3.RIGHT, 0.3), Vector3(0, 0.098, -0.098)), Vector3(0.2, 0.04, 0.07), 4.0, Color.WHITE, false)
	for s in [-1.0, 1.0]:
		mb.add_box(flat, Transform3D(Basis(), Vector3(s * 0.042, 0.066, -0.104)), Vector3(0.042, 0.026, 0.01), 1.0, Color(0.05, 0.04, 0.04), false)
		mb.add_box(skin, Transform3D(Basis(Vector3.UP, s * 0.3), Vector3(s * 0.108, 0.065, 0.0)), Vector3(0.02, 0.04, 0.035), 4.0)
	# the muzzle: a broad flat nose, a heavy jaw, fangs at the corners of the mouth
	mb.add_blob(skin, Transform3D(Basis(), Vector3(0, 0.005, -0.12)), Vector3(0.085, 0.062, 0.068), rng, 0.0, 3, 8, 4.0)
	mb.add_blob(skin, Transform3D(Basis(), Vector3(0, -0.05, -0.1)), Vector3(0.08, 0.045, 0.07), rng, 0.0, 3, 8, 4.0, Color(0.85, 0.85, 0.85))
	mb.add_box(skin, Transform3D(Basis(Vector3.RIGHT, -0.35), Vector3(0, 0.04, -0.176)), Vector3(0.085, 0.055, 0.03), 4.0, Color(0.9, 0.9, 0.9), false)
	for s in [-1.0, 1.0]:
		mb.add_box(flat, Transform3D(Basis(), Vector3(s * 0.02, 0.026, -0.193)), Vector3(0.022, 0.014, 0.006), 1.0, Color(0.04, 0.03, 0.03), false)
		mb.add_cylinder(flat, Transform3D(Basis(Vector3.RIGHT, PI), Vector3(s * 0.034, -0.02, -0.172)), 0.01, 0.0, 0.035, 4, 1.0, BONE, false, false, false)
	mb.add_box(flat, Transform3D(Basis(), Vector3(0, -0.024, -0.182)), Vector3(0.095, 0.009, 0.009), 1.0, Color(0.06, 0.04, 0.04), false)
	# an old scar through the left brow
	mb.add_box(flat, Transform3D(Basis(Vector3.FORWARD, -0.35), Vector3(-0.058, 0.07, -0.118)), Vector3(0.008, 0.085, 0.006), 1.0, SCAR, false)
	# shaggy cheeks and the back of the head
	_shag(mb, SKULL, -0.05, 0.14, PI * 0.45, PI * 1.55, 14, 0.06, Vector3(0, -1, 0.5), 0.5)
	for i in range(6):
		var z := lerpf(-0.02, 0.1, i / 5.0)
		_tuft(mb, Vector3(0, 0.17 + sin(i / 5.0 * PI) * 0.03, z), Vector3(0, 0.4, 1.0), 0.07, 0.03)
