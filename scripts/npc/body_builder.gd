class_name BodyBuilder
extends RefCounted
## Builds a Humanoid's skeleton and its low-poly anime/PS1-style body, face,
## hair, headwear and layered clothing from a CharacterLook dictionary.
##
## * Proportions come from a style preset (STYLES): head size, leg / torso /
##   arm length, shoulder and waist shape, hand and foot size, eye size.
## * Everything is lofted from cross-section rings (MeshBuilder.add_loft);
##   rings can carry their own profile, which gives chests, busts and V chins.
## * The face is painted by FacePainter and wrapped onto the head surface.
## * Hair strands, ponytails, braids, coat tails, skirts, sashes and aprons are
##   skinned to SpringChains bones and simulated (see spring_chains.gd).

const STYLES := {
	# One Piece-ish shonen: ~6 heads tall, big expressive head, long legs, strong V-taper
	"shonen": {"head": 0.74, "leg": 1.13, "torso": 0.86, "neck": 0.55, "arm": 1.04, "sh": 1.15, "wa": 0.84,
		"ch": 1.06, "hand": 1.18, "foot": 1.15, "eye": 1.0, "limb": 1.0, "leg_gap": 0.1},
	# Chibi / super-deformed: ~3 heads tall, huge head, stubby limbs
	"chibi": {"head": 1.1, "leg": 0.46, "torso": 0.62, "neck": 0.45, "arm": 0.66, "sh": 0.98, "wa": 1.04,
		"ch": 1.0, "hand": 1.3, "foot": 1.25, "eye": 1.4, "limb": 1.1, "leg_gap": 0.1},
	# Heroic: ~7.5 heads tall, realistic-leaning anime proportions
	"heroic": {"head": 0.6, "leg": 1.08, "torso": 0.98, "neck": 1.05, "arm": 1.06, "sh": 1.1, "wa": 0.92,
		"ch": 1.04, "hand": 1.0, "foot": 1.0, "eye": 0.8, "limb": 0.95, "leg_gap": 0.12},
}
## Shonen is the game's art style. The other presets stay available to looks
## that name a "style" explicitly (tools / mockups).
const DEFAULT_STYLE := "shonen"
const STYLE_NAMES := ["shonen", "chibi", "heroic"]


static func current_style() -> String:
	return DEFAULT_STYLE

const BUILD_F := {
	"slim": {"sh": 0.92, "ch": 0.9, "wa": 0.9, "hp": 0.95, "de": 0.92, "limb": 0.9},
	"average": {"sh": 1.0, "ch": 1.0, "wa": 1.0, "hp": 1.0, "de": 1.0, "limb": 1.0},
	"broad": {"sh": 1.12, "ch": 1.1, "wa": 1.02, "hp": 1.0, "de": 1.06, "limb": 1.1},
	"stout": {"sh": 1.05, "ch": 1.14, "wa": 1.3, "hp": 1.15, "de": 1.28, "limb": 1.12},
}

var h: Humanoid
var lk: Dictionary
var st: Dictionary
var fem := false
var bf: Dictionary
var sh := 1.0      # shoulder width
var ch := 1.0      # chest
var wa := 1.0      # waist
var hp := 1.0      # hips
var de := 1.0      # depth
var limb := 1.0    # limb thickness
var T := 1.0       # torso length
var Ls := 1.0      # leg length
var A := 1.0       # arm length
var Hk := 1.0      # hand size
var Fk := 1.0      # foot size
var yk := 1.0      # head vertical stretch
var m_skin: Material
var m_hair: Material
var head_rings: Array = []
var hair_off := 0.018
var colliders: Dictionary = {}
var _parts: Dictionary = {}
var _part_order: Array = []
var _sims: Dictionary = {}


static func build(hum: Humanoid, look: Dictionary) -> void:
	var b := BodyBuilder.new()
	b._run(hum, look)


func _run(hum: Humanoid, look: Dictionary) -> void:
	h = hum
	lk = look
	st = STYLES.get(str(lk.get("style", current_style())), STYLES[DEFAULT_STYLE])
	fem = str(lk.get("body", "masc")) == "fem"
	bf = BUILD_F.get(str(lk.get("build", "average")), BUILD_F["average"])
	var ex := 0.45 if fem else 1.0  # women get a softer version of the style's V-taper
	sh = bf["sh"] * (1.0 + (float(st["sh"]) - 1.0) * ex)
	ch = bf["ch"] * (1.0 + (float(st["ch"]) - 1.0) * ex)
	wa = bf["wa"] * float(st["wa"])
	hp = bf["hp"]
	de = bf["de"]
	limb = bf["limb"] * float(st["limb"]) * (0.86 if fem else 1.0)
	T = float(st["torso"])
	Ls = float(st["leg"]) * (1.03 if fem else 1.0)
	A = float(st["arm"]) * (0.97 if fem else 1.0)
	Hk = float(st["hand"]) * (0.84 if fem else 1.0)
	Fk = float(st["foot"]) * (0.86 if fem else 1.0)
	m_skin = PSXMat.flat(_col("skin"))
	# (pulled a touch toward the camera so the scalp never shows through it)
	var hk := 1.25
	var hc := _col("hair_color")
	m_hair = PSXMat.lit("hair", Color(minf(hc.r * hk, 1.0), minf(hc.g * hk, 1.0), minf(hc.b * hk, 1.0)), {"pull": 0.01})
	_skeleton()
	_colliders()
	_legs()
	_lower_body()
	_torso()
	_arms()
	_head()
	_clothes()
	_accessories()
	_commit_parts()
	for s in _sims.values():
		(s as SpringChains).finalize()


# --------------------------------------------------------------------------
# helpers
# --------------------------------------------------------------------------
func _col(key: String) -> Color:
	return lk.get(key, Color.WHITE)


## Textured materials darken their tint (textures average ~75% gray), so
## brighten the palette color to keep it reading as picked.
func _textured(tex: String, c: Color) -> Material:
	var k := 1.25
	return PSXMat.lit(tex, Color(minf(c.r * k, 1.0), minf(c.g * k, 1.0), minf(c.b * k, 1.0)))


func _cloth(key: String) -> Material:
	return _textured("fabric", _col(key))


func _leather(key: String) -> Material:
	return _textured("leather", _col(key))


func _node(n: String, pos: Vector3, parent: Node3D) -> Node3D:
	var p := Node3D.new()
	p.name = n
	p.position = pos
	parent.add_child(p)
	return p


## Rigid parts are merged per skeleton node and committed once at the end
## (one MeshInstance per joint keeps instance counts and draw calls low).
func _mesh(parent: Node3D, mb: MeshBuilder, _n: String = "Mesh") -> void:
	if mb.is_empty():
		return
	if not _parts.has(parent):
		_parts[parent] = MeshBuilder.new()
		_part_order.append(parent)
	(_parts[parent] as MeshBuilder).merge(mb)


func _commit_parts() -> void:
	for node in _part_order:
		(node as Node3D).add_child((_parts[node] as MeshBuilder).to_instance("Mesh"))
	_parts.clear()
	_part_order.clear()


## Physics chains anchored on a joint (created on first use).
func _sim(anchor: Node3D) -> SpringChains:
	if not _sims.has(anchor):
		var s := SpringChains.new()
		s.colliders = colliders
		anchor.add_child(s)
		_sims[anchor] = s
		h._sims.append(s)
	return _sims[anchor]


static func _prof(half: Array) -> PackedVector2Array:
	return MeshBuilder.profile_mirror(PackedVector2Array(half))


static func P_BODY() -> PackedVector2Array:
	return _prof([Vector2(0, -1), Vector2(0.5, -0.97), Vector2(0.86, -0.74), Vector2(1, -0.2), Vector2(0.96, 0.42), Vector2(0.62, 0.9), Vector2(0, 1)])


static func P_PEC() -> PackedVector2Array:
	return _prof([Vector2(0, -0.98), Vector2(0.5, -1.03), Vector2(0.88, -0.8), Vector2(1, -0.2), Vector2(0.96, 0.42), Vector2(0.62, 0.9), Vector2(0, 1)])


static func P_BUST() -> PackedVector2Array:
	return _prof([Vector2(0, -0.86), Vector2(0.46, -1.16), Vector2(0.86, -0.84), Vector2(1, -0.2), Vector2(0.96, 0.42), Vector2(0.62, 0.9), Vector2(0, 1)])


static func P_HEAD() -> PackedVector2Array:
	return _prof([Vector2(0, -1), Vector2(0.52, -0.93), Vector2(0.88, -0.62), Vector2(1, -0.12), Vector2(0.94, 0.45), Vector2(0.58, 0.9), Vector2(0, 1)])


static func P_CHIN_V() -> PackedVector2Array:
	return _prof([Vector2(0, -1.25), Vector2(0.45, -0.92), Vector2(0.85, -0.56), Vector2(1, -0.1), Vector2(0.9, 0.45), Vector2(0.55, 0.88), Vector2(0, 1)])


static func P_JAW() -> PackedVector2Array:
	return _prof([Vector2(0, -1), Vector2(0.62, -0.98), Vector2(0.96, -0.6), Vector2(1, -0.1), Vector2(0.92, 0.45), Vector2(0.56, 0.9), Vector2(0, 1)])


## Push a ring profile's back half out (kb deeper, kw wider), keeping the front.
static func _back_ext(prof: PackedVector2Array, kb: float, kw: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in prof:
		out.append(Vector2(p.x * kw, p.y * kb) if p.y > 0.0 else p)
	return out


static func _off(rings: Array, o: float, oz: float = 0.0, strip: bool = false) -> Array:
	var out: Array = []
	for r in rings:
		var rr: Array = (r as Array).duplicate()
		while rr.size() < 5:
			rr.append(0.0)
		rr[1] = maxf(float(rr[1]) + o, 0.0)
		rr[2] = maxf(float(rr[2]) + o, 0.0)
		rr[3] = float(rr[3]) + oz
		if strip and rr.size() > 5:
			rr.resize(5)
		out.append(rr)
	return out


static func _lerp_ring(a: Array, b: Array, t: float) -> Array:
	var out: Array = []
	for i in range(5):
		var va: float = a[i] if i < a.size() else 0.0
		var vb: float = b[i] if i < b.size() else 0.0
		out.append(lerpf(va, vb, t))
	var pa: Variant = a[5] if a.size() > 5 else null
	var pb: Variant = b[5] if b.size() > 5 else null
	if pa is PackedVector2Array and pb is PackedVector2Array and (pa as PackedVector2Array).size() == (pb as PackedVector2Array).size():
		var pp := PackedVector2Array()
		for i in range((pa as PackedVector2Array).size()):
			pp.append((pa as PackedVector2Array)[i].lerp((pb as PackedVector2Array)[i], t))
		out.append(pp)
	elif pa is PackedVector2Array:
		out.append(pa)
	elif pb is PackedVector2Array:
		out.append(pb)
	return out


## Rings clipped to lo <= y <= hi (interpolating new rings at the cuts).
static func _clip(rings: Array, lo: float, hi: float) -> Array:
	var out: Array = []
	for i in range(rings.size()):
		var r: Array = rings[i]
		var y: float = r[0]
		if i > 0:
			var p: Array = rings[i - 1]
			var py: float = p[0]
			var cuts := [lo, hi] if y > py else [hi, lo]
			for cut in cuts:
				if (cut - py) * (cut - y) < 0.0:
					out.append(_lerp_ring(p, r, (cut - py) / (y - py)))
		if y >= lo - 1e-5 and y <= hi + 1e-5:
			out.append(r)
	return out


## Ring sizes at height y (for placing details on a lofted part).
static func _at(rings: Array, y: float) -> Array:
	for i in range(1, rings.size()):
		var a: Array = rings[i - 1]
		var b: Array = rings[i]
		var ya: float = a[0]
		var yb: float = b[0]
		if (y - ya) * (y - yb) <= 0.0 and ya != yb:
			return _lerp_ring(a, b, (y - ya) / (yb - ya))
	return _lerp_ring(rings[0], rings[0], 0.0)


## Front surface z of a ring (its profile's front-center point).
static func _front_z(r: Array) -> float:
	var f := -1.0
	if r.size() > 5 and r[5] is PackedVector2Array:
		f = (r[5] as PackedVector2Array)[0].y
	return float(r[3]) + f * float(r[2])


## Torso-shaped open-front shell profile (vests, coats): same outline as
## P_BODY so the body never pokes through, with a gap at the front.
static func open_body(gap: float) -> PackedVector2Array:
	var full := P_BODY()
	var out := PackedVector2Array([Vector2(gap, -0.985)])
	for i in range(1, full.size()):
		out.append(full[i])
	out.append(Vector2(-gap, -0.985))
	return out


static func open_front(gap: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(gap, -1), Vector2(1, -0.45), Vector2(1, 0.45), Vector2(0.45, 1),
		Vector2(-0.45, 1), Vector2(-1, 0.45), Vector2(-1, -0.45), Vector2(-gap, -1)])


func ty(v: float) -> float:
	return v * T


## Torso height for the upper chest: from the top of the chest up (shoulders,
## traps, neck base, collars) heights are compressed, so the shoulders sit
## lower and the traps don't climb the neck. Everything placed up there uses this.
const UPPER_FROM := 0.45
const UPPER_K := 0.82


func tu(v: float) -> float:
	return ty(v if v <= UPPER_FROM else UPPER_FROM + (v - UPPER_FROM) * UPPER_K)


# --------------------------------------------------------------------------
# skeleton + colliders
# --------------------------------------------------------------------------
func _skeleton() -> void:
	var lg := float(st["leg_gap"])
	h.hip_y = 0.02 + (0.42 + 0.46) * Ls
	h.pivot = _node("Pivot", Vector3(0, h.hip_y, 0), h)
	h.hips = _node("Hips", Vector3.ZERO, h.pivot)
	h.leg_l = _node("LegL", Vector3(-lg, -0.02, 0), h.hips)
	h.leg_r = _node("LegR", Vector3(lg, -0.02, 0), h.hips)
	h.shin_l = _node("ShinL", Vector3(0, -0.42 * Ls, 0), h.leg_l)
	h.shin_r = _node("ShinR", Vector3(0, -0.42 * Ls, 0), h.leg_r)
	h.torso = _node("Torso", Vector3.ZERO, h.hips)
	# shoulder joints sit just inside the torso's edge, under the deltoid
	# cap of the torso, so the top of each arm is buried in the shoulder
	# instead of sitting on it like an action figure's ball joint
	var sxr := (0.158 * sh + 0.004) if fem else (0.2 * sh + 0.004)
	h.arm_l = _node("ArmL", Vector3(-sxr, tu(0.52), 0), h.torso)
	h.arm_r = _node("ArmR", Vector3(sxr, tu(0.52), 0), h.torso)
	h.fore_l = _node("ForeL", Vector3(0, -0.3 * A, 0), h.arm_l)
	h.fore_r = _node("ForeR", Vector3(0, -0.3 * A, 0), h.arm_r)
	var wrist := -0.23 * A
	h.hand_l = _node("HandL", Vector3(0, wrist - 0.07 * Hk, -0.02), h.fore_l)
	h.hand_r = _node("HandR", Vector3(0, wrist - 0.07 * Hk, -0.02), h.fore_r)
	h.neck = _node("Neck", Vector3(0, tu(0.6), 0.012), h.torso)
	h.head = _node("Head", Vector3(0, tu(0.62) + 0.06 * float(st["neck"]), 0) - h.neck.position, h.neck)
	var hs := float(st["head"]) * (0.97 if fem else 1.0)
	h.head.scale = Vector3(hs, hs, hs)
	var waist := _torso_rings()[0][1] as float
	h.hip_socket = _node("HipSocket", Vector3(-waist - 0.07, ty(0.05), 0.02), h.torso)
	# (up square to the blade with no sideways part: the flat lies against the thigh, edge forward)
	h.hip_socket.basis = Basis.looking_at(Vector3(-0.15, -0.78, 0.6).normalized(), Vector3(0, 0.6, 0.78))


func _colliders() -> void:
	var thigh_r := (0.108 if fem else 0.1) * limb + 0.03
	colliders["thigh_l"] = {"node": h.leg_l, "a": Vector3(0, 0.02, 0), "b": Vector3(0, -0.42 * Ls, 0), "r": thigh_r}
	colliders["thigh_r"] = {"node": h.leg_r, "a": Vector3(0, 0.02, 0), "b": Vector3(0, -0.42 * Ls, 0), "r": thigh_r}
	colliders["shin_l"] = {"node": h.shin_l, "a": Vector3.ZERO, "b": Vector3(0, -0.4 * Ls, 0), "r": 0.075 * limb + 0.025}
	colliders["shin_r"] = {"node": h.shin_r, "a": Vector3.ZERO, "b": Vector3(0, -0.4 * Ls, 0), "r": 0.075 * limb + 0.025}
	colliders["hips"] = {"node": h.hips, "a": Vector3(0, 0.05, 0), "b": Vector3(0, -0.08, 0), "r": _hips_hw() * 0.82}
	colliders["torso"] = {"node": h.torso, "a": Vector3(0, ty(0.12), 0.01), "b": Vector3(0, tu(0.5), 0.01), "r": 0.13 * de + 0.025}
	colliders["head"] = {"node": h.head, "a": Vector3(0, 0.13, 0.01), "b": Vector3(0, 0.26, 0.01), "r": 0.17}


# --------------------------------------------------------------------------
# body
# --------------------------------------------------------------------------
func _torso_rings() -> Array:
	var B := P_BODY()
	var r: Array
	if fem:
		var w := bf["wa"] as float * float(st["wa"]) * 1.02
		r = [
			# (narrowest at 0.11; already flaring toward the hips at the bottom: hourglass)
			[0.0, 0.142 * w, 0.1 * de, 0.0, 0.0, B],
			[0.11, 0.125 * w, 0.096 * de, 0.0, 0.0, B],
			[0.22, 0.14 * ch, 0.104 * de, -0.004, 0.0, B],
			[0.31, 0.158 * ch, 0.126 * de, -0.016, 0.0, P_BUST()],
			[0.385, 0.165 * ch, 0.128 * de, -0.016, 0.0, P_BUST()],
			[0.45, 0.178 * sh, 0.11 * de, -0.004, 0.0, B],
			[0.5, 0.198 * sh, 0.106 * de, 0.0, 0.0, B],
			[0.535, 0.2 * sh, 0.102 * de, 0.002, 0.0, B],
			[0.57, 0.162 * sh, 0.095 * de, 0.005, 0.0, B],
			[0.615, 0.118 * sh, 0.086 * de, 0.01, 0.0, B],
			[0.655, 0.064, 0.06, 0.01, 0.0, B]]
	else:
		r = [
			[0.0, 0.155 * wa, 0.108 * de, 0.0, 0.0, B],
			[0.13, 0.162 * wa, 0.114 * de, -0.03 * maxf(bf["wa"] as float - 1.0, 0.0), 0.0, B],
			[0.27, 0.2 * ch, 0.128 * de, -0.004, 0.0, B],
			[0.39, 0.222 * ch, 0.136 * de, -0.008, 0.0, P_PEC()],
			[0.49, 0.25 * sh, 0.128 * de, 0.0, 0.0, B],
			[0.535, 0.252 * sh, 0.122 * de, 0.002, 0.0, B],
			[0.575, 0.205 * sh, 0.112 * de, 0.005, 0.0, B],
			[0.615, 0.14 * sh, 0.1 * de, 0.01, 0.0, B],
			[0.655, 0.075, 0.068, 0.01, 0.0, B]]
	# slimmer through the chest and shoulders, a touch at the waist (depth kept)
	for i in range(r.size()):
		var ring: Array = r[i]
		ring[0] = tu(ring[0])
		ring[1] = float(ring[1]) * (0.95 if i < 2 else 0.88)
	return r


func _hips_hw() -> float:
	# (female: the build's hip and waist factors compounded made the stout seat too wide)
	var base := 0.198 * (1.0 + (hp - 1.0) * 0.6) * (1.0 + (wa - 1.0) * 0.3) if fem else 0.175 * hp * (1.0 + (wa - 1.0) * 0.5)
	# wide enough that the thighs run up inside the pelvis (it, not the thighs, makes the hips' outline)
	return maxf(base, float(st["leg_gap"]) + (0.098 if fem else 0.09) * limb)


func _hips_hd() -> float:
	return 0.122 * (1.0 + (de - 1.0) * 0.6) if fem else 0.118 * de


## Thigh rings in the leg joint's space. The top is a closed, rounded dome
## buried in the pelvis (the hip joint sits inside the hips), and the bottom
## runs a little past the knee so a bent knee never opens a gap.
func _thigh_rings(side: float) -> Array:
	var L := limb
	var inx := -side * 0.015
	var r: Array
	# (the dome stays below the waist: higher, its sides poked out above the shirt hem)
	if fem:
		# full, rounded thighs set a little toward the middle: they meet near the
		# top and only part slightly toward the knee
		# ...and bulging outward up top, so from behind the outline curves from the
		# widest point of the hips down to the knee instead of stepping in
		var fi := -side * 0.02
		var o := side * 0.014
		r = [[0.05, 0.045 * L, 0.05 * L, 0.0, inx], [0.02, 0.088 * L, 0.09 * L, 0.004, fi + o * 0.5],
			[-0.05 * Ls, 0.116 * L, 0.112 * L, 0.008, fi + o], [-0.12 * Ls, 0.118 * L, 0.11 * L, 0.007, fi * 0.85 + o],
			[-0.2 * Ls, 0.106 * L, 0.1 * L, 0.005, fi * 0.6 + o * 0.6], [-0.28 * Ls, 0.09 * L, 0.09 * L, 0.002, fi * 0.3 + o * 0.25],
			[-0.35 * Ls, 0.075 * L, 0.08 * L, 0.0, 0.0], [-0.42 * Ls, 0.063 * L, 0.07 * L, 0.0, 0.0], [-0.45 * Ls, 0.053 * L, 0.058 * L, -0.004, 0.0]]
	else:
		r = [[0.05, 0.04 * L, 0.045 * L, 0.0, inx], [0.02, 0.066 * L, 0.074 * L, 0.0, inx * 0.6], [-0.05 * Ls, 0.084 * L, 0.094 * L, 0.004, 0.0],
			[-0.24 * Ls, 0.085 * L, 0.094 * L, 0.002, 0.0], [-0.42 * Ls, 0.066 * L, 0.076 * L, 0.0, 0.0], [-0.45 * Ls, 0.056 * L, 0.064 * L, -0.004, 0.0]]
	# heavier builds widen the hips: the upper thighs fill out (mostly outward)
	# to meet them, so the pelvis's lower corners don't hang out past the legs
	var top: Array = r[2]
	var c0 := float(st["leg_gap"]) + float(top[4]) * side
	var g := maxf((_hips_hw() * 0.92 - c0 - float(top[1])) / 1.6, 0.0)
	if g > 0.0:
		for ring in r:
			var w := 1.0 - smoothstep(-0.06 * Ls, -0.38 * Ls, float(ring[0]))
			ring[1] = float(ring[1]) + g * w
			ring[2] = float(ring[2]) + g * w * 0.5
			ring[4] = float(ring[4]) + side * g * w * 0.6
	return r


func _shin_rings() -> Array:
	var L := limb
	return [[0.035, 0.054 * L, 0.062 * L, 0.004], [-0.03 * Ls, 0.064 * L, 0.076 * L, 0.01], [-0.1 * Ls, 0.066 * L, 0.08 * L, 0.014],
		[-0.26 * Ls, 0.05 * L, 0.058 * L, 0.004], [-0.4 * Ls, 0.042 * L, 0.048 * L]]


func _legs() -> void:
	var legs := str(lk.get("legs", "trousers"))
	var feet := str(lk.get("feet", "boots"))
	var m_legs := _cloth("legs_color")
	var prof := MeshBuilder.profile_oct(0.5)
	# (thighs, knees and shins are the skinned lower body, see _lower_body; only
	# the cuffs and footwear ride the shin joint)
	for side in [-1, 1]:
		var shin: Node3D = h.shin_l if side < 0 else h.shin_r
		var sr := _shin_rings()
		var smb := MeshBuilder.new()
		if legs == "breeches":
			smb.add_loft(m_legs, Transform3D.IDENTITY, _off(_clip(sr, -0.11 * Ls, -0.06 * Ls), 0.012), prof, 3.0)
		_feet(smb, sr, feet)
		_mesh(shin, smb)


func _feet(mb: MeshBuilder, sr: Array, feet: String) -> void:
	var m_feet := _leather("feet_color")
	var sole := -0.46 * Ls
	var fx := Transform3D(Basis(Vector3.RIGHT, -PI / 2.0), Vector3(0, sole, 0.0))
	var L := limb * Fk
	var F := Fk
	var foot := [[-0.085 * F, 0.05 * L, 0.04 * F, 0.05 * F], [-0.06 * F, 0.06 * L, 0.06 * F, 0.065 * F], [0.0, 0.064 * L, 0.058 * F, 0.06 * F],
		[0.08 * F, 0.062 * L, 0.04 * F, 0.042 * F], [0.15 * F, 0.05 * L, 0.028 * F, 0.03 * F], [0.178 * F, 0.03 * L, 0.018 * F, 0.022 * F]]
	var fprof := MeshBuilder.profile_oct(0.6)
	var sp := MeshBuilder.profile_oct(0.5)
	match feet:
		"barefoot":
			var bare := [[-0.075 * F, 0.042 * L, 0.035 * F, 0.04 * F], [-0.05 * F, 0.05 * L, 0.05 * F, 0.055 * F], [0.0, 0.054 * L, 0.05 * F, 0.05 * F],
				[0.07 * F, 0.054 * L, 0.03 * F, 0.032 * F], [0.13 * F, 0.046 * L, 0.022 * F, 0.022 * F], [0.15 * F, 0.03 * L, 0.014 * F, 0.016 * F]]
			mb.add_loft(m_skin, fx, bare, fprof, 3.0, Color.WHITE, true, true)
		"shoes":
			mb.add_loft(m_feet, fx, _off(foot, -0.004), fprof, 3.0, Color.WHITE, true, true)
			mb.add_loft(m_feet, Transform3D.IDENTITY, _off(_clip(sr, sole + 0.04, sole + 0.1 * F), 0.01), sp, 3.0)
			mb.add_box(PSXMat.flat(Color(0.85, 0.75, 0.4)), Transform3D(Basis(Vector3.RIGHT, -0.5), Vector3(0, sole + 0.07 * F, -0.07 * F)), Vector3(0.05, 0.035, 0.012) * F, 2.0)
		"tall_boots":
			mb.add_loft(m_feet, fx, foot, fprof, 3.0, Color.WHITE, true, true)
			# (the cuff stops just under the knee's bend: higher, the bending knee
			# pushed the trousers out through it)
			mb.add_loft(m_feet, Transform3D.IDENTITY, _off(_clip(sr, sole + 0.04, -0.16 * Ls), 0.016), sp, 3.0)
			var cuff := _off(_clip(sr, -0.19 * Ls, -KNEE_BAND - 0.012), 0.03)
			mb.add_loft(_textured("leather", _col("feet_color").lightened(0.12)), Transform3D.IDENTITY, cuff, sp, 3.0, Color.WHITE, false, false, true, false, true)
		"greaves":
			# tall boots with steel plates down the shin and a cop over the knee
			mb.add_loft(m_feet, fx, foot, fprof, 3.0, Color.WHITE, true, true)
			mb.add_loft(m_feet, Transform3D.IDENTITY, _off(_clip(sr, sole + 0.04, -0.16 * Ls), 0.016), sp, 3.0)
			var steel := PSXMat.lit("metal", Color(0.9, 0.92, 0.96))
			var plate := _off(_clip(sr, sole + 0.09, -0.15 * Ls), 0.03)
			var front := PackedVector2Array([Vector2(0.75, -0.55), Vector2(0.95, 0.05), Vector2(0.5, 0.2), Vector2(-0.5, 0.2), Vector2(-0.95, 0.05), Vector2(-0.75, -0.55), Vector2(0, -1)])
			mb.add_loft(steel, Transform3D.IDENTITY, plate, front, 0.5, Color.WHITE, false, false, true, false, true)
			var kr := _at(sr, -0.02)
			mb.add_box(steel, Transform3D(Basis(Vector3.RIGHT, -0.2), Vector3(float(kr[4]), -0.02, float(kr[3]) - float(kr[2]) - 0.03)), Vector3(0.075, 0.065, 0.02), 3.0)
			mb.add_box(steel, Transform3D(Basis(), Vector3(0, sole + 0.03, -0.1 * F)), Vector3(0.07, 0.03, 0.09) * F, 3.0)
		_:  # boots
			mb.add_loft(m_feet, fx, foot, fprof, 3.0, Color.WHITE, true, true)
			mb.add_loft(m_feet, Transform3D.IDENTITY, _off(_clip(sr, sole + 0.04, sole + 0.19 * F), 0.016), sp, 3.0, Color.WHITE, false, true)


## Top of the footwear's shaft in shin space (-INF: barefoot), where the legs
## tuck into it.
func _boot_top() -> float:
	var sole := -0.46 * Ls
	match str(lk.get("feet", "boots")):
		"tall_boots", "greaves":
			return -KNEE_BAND - 0.012
		"boots":
			return sole + 0.19 * Fk
		"shoes":
			return sole + 0.1 * Fk
	return -INF


## Half height of the blend across the knee, elbow and shoulder joints.
const KNEE_BAND := 0.07
const ARM_BAND := 0.065


## Weights across a joint for a chain of bones turning evenly from none to all
## of the bend: `f` (0 above the joint's band .. 1 below it) picks the two
## neighbours and blends them. Rings placed at the chain's steps ride one bone
## each, so a bend fans them round the joint instead of averaging them in.
static func _chain_w(f: float, chain: Array) -> Array:
	var n := chain.size() - 1
	var x := clampf(f, 0.0, 1.0) * n
	var i := mini(int(x), n - 1)
	var t := x - i
	return [PackedInt32Array([chain[i], chain[i + 1], 0, 0]), PackedFloat32Array([1.0 - t, t, 0.0, 0.0])]


## Hips, seat and both thighs as ONE skinned surface (LowerBody): the pelvis
## tube narrows into a "split ring" at the crotch whose two halves are the tops
## of the two thigh tubes (they share their inner edge on the centre line), so
## there are no overlapping rigid pieces to show seams or lumps. Every ring is
## 12 points: front centre, 5 on the +x side, back centre, 5 on the -x side.
func _lower_body() -> void:
	var legs := str(lk.get("legs", "trousers"))
	var m_legs := _cloth("legs_color")
	var hw := _hips_hw()
	var hd := _hips_hd()
	var lg := float(st["leg_gap"])
	# the top tucks inside the shirt's waist and the hips only widen below its hem
	var tr0: Array = _torso_rings()[0]
	var ww := float(tr0[1])
	var wd := float(tr0[2])
	var ys := -0.18 if fem else -0.165
	var pelvis: Array = []
	if fem:
		# an hourglass that rounds into a high, full seat; the back centre pulls in
		# (the cleft) and the split below divides it into two glutes
		for r in [[0.04, ww * 0.9, wd * 0.9, 0.0, 1.0, 1.0], [0.0, ww + 0.004, wd + 0.004, 0.0, 1.0, 1.0],
				[-0.03, lerpf(ww, hw, 0.55), lerpf(wd, hd, 0.6), 0.008, 0.94, 1.02], [-0.065, lerpf(ww, hw, 0.88), hd * 0.98, 0.014, 0.86, 1.06],
				[-0.105, hw, hd, 0.016, 0.8, 1.08], [-0.145, hw * 0.95, hd * 0.96, 0.014, 0.76, 1.08]]:
			pelvis.append(_hip_ring(r[0], r[1], r[2], r[3], r[4], r[5]))
	else:
		for r in [[0.04, ww * 0.9, wd * 0.9, 0.0, 1.0, 1.0], [0.0, ww + 0.004, wd + 0.004, 0.0, 1.0, 1.0],
				[-0.045, lerpf(ww, hw, 0.6), lerpf(wd, hd, 0.6), 0.003, 0.96, 1.0], [-0.095, hw, hd, 0.006, 0.9, 1.02],
				[-0.13, hw * 0.94, hd * 0.92, 0.005, 0.86, 1.02]]:
			pelvis.append(_hip_ring(r[0], r[1], r[2], r[3], r[4], r[5]))
	# the split: each thigh's top ring at the crotch height (thigh rings are in
	# the leg joint's space, which sits at (+-leg_gap, -0.02) in hips space)
	var th := {-1: _thigh_rings(-1.0), 1: _thigh_rings(1.0)}
	var top := {}
	for s in [-1, 1]:
		var r := _at(th[s], ys + 0.02)
		top[s] = [s * lg + float(r[4]), float(r[3]), float(r[1]), float(r[2])]   # cx, cz, rx, rz
	# the side of the crotch ring runs halfway between the last hip ring and the
	# thigh just below it (narrower, it made a notch where the thigh joins the hip)
	var y_leg := ys + 0.02 - 0.045
	for s in [-1, 1]:
		var rl := _at(th[s], y_leg)
		var below := absf(s * lg + float(rl[4])) + float(rl[1])
		var above := absf((pelvis[pelvis.size() - 1] as PackedVector3Array)[3].x)
		var want := lerpf(above, below, 0.5)
		var cx: float = float(top[s][0]) * s
		top[s][2] = maxf(float(top[s][2]), want - cx)
	var zf := minf(float(top[1][1]) - float(top[1][3]) * 0.92, -hd * 0.8)
	var zb := float(top[1][1]) + float(top[1][3]) * (0.62 if fem else 0.8)
	var outer := {}
	for s in [-1, 1]:
		var pts := PackedVector3Array()
		for k in range(1, 6):
			var a: float = deg_to_rad(30.0 * k) * s
			pts.append(Vector3(float(top[s][0]) + float(top[s][2]) * sin(a), ys, float(top[s][1]) - float(top[s][3]) * cos(a)))
		outer[s] = pts
	var front := Vector3(0, ys, zf)
	var back := Vector3(0, ys, zb)
	var split := PackedVector3Array([front])
	split.append_array(outer[1])
	split.append(back)
	var left_back_to_front: PackedVector3Array = outer[-1].duplicate()
	left_back_to_front.reverse()
	split.append_array(left_back_to_front)
	pelvis.append(split)
	# skinning: a pure function of position, so the shared ring moves as one.
	# Pelvis above the hips, thigh below; near the crotch the centre stays with
	# the pelvis, but only near it (lower down the whole thigh follows the leg)
	var kj := -0.02 - 0.42 * Ls   # knee joint height (hips space)
	var wf := func(p: Vector3) -> Array:
		var left := p.x < 0.0
		var dk := p.y - kj
		if dk < KNEE_BAND:
			return _chain_w((KNEE_BAND - dk) / (2.0 * KNEE_BAND), LowerBody.KNEE_L_CHAIN if left else LowerBody.KNEE_R_CHAIN)
		# (short: a long pelvis/thigh blend squashed the upper thigh when a leg lifted)
		var t := 1.0 - smoothstep(-0.12, -0.03, p.y)
		# The back of the seat and the middle of the crotch take their leg share
		# from the seat helpers (they turn part way, push out on flex, and between
		# them average the two legs) instead of a thigh, fading to the thigh below
		# the crotch: a lifted leg no longer drags the seat flat or pinches the
		# crotch. (Wide, slow blends: narrow ones folded the surface.)
		var near := smoothstep(ys - 0.09, ys + 0.01, p.y)
		var behind := smoothstep(-0.01, 0.05, p.z)
		var mid := 1.0 - smoothstep(0.0, 0.07, absf(p.x))
		var hs := maxf(behind, mid) * near
		var helper := t * hs
		var thigh := t * (1.0 - hs)
		var to_left := clampf(0.5 - p.x / 0.1, 0.0, 1.0)
		var b := LowerBody.THIGH_L if p.x < 0.0 else LowerBody.THIGH_R
		return [PackedInt32Array([LowerBody.PELVIS, b, LowerBody.SEAT_L, LowerBody.SEAT_R]),
			PackedFloat32Array([1.0 - helper - thigh, thigh, helper * to_left, helper * (1.0 - to_left)])]
	var mb := MeshBuilder.new()
	mb.skinned = true
	mb.weight_fn = wf
	# trousers/breeches: cloth all the way; shorts: cloth to the hem, then skin;
	# skirt: bare thighs under it
	var hem := -0.2 * Ls - 0.02
	var m_stock := _textured("fabric", Color(0.88, 0.86, 0.78))
	var pick := func(c: Vector3) -> Material:
		if c.y > ys + 0.002:
			return m_legs
		match legs:
			"shorts": return m_legs if c.y > hem else m_skin
			"skirt": return m_skin
			"breeches": return m_legs if c.y > kj - 0.085 * Ls else m_stock
		return m_legs
	mb.add_rings(m_legs, pelvis, 3.0, Color.WHITE, true, false)
	for s in [-1, 1]:
		var ring0 := PackedVector3Array([front])
		var inner := PackedVector3Array()
		for j in range(1, 6):
			inner.append(Vector3(0, ys, lerpf(zf, zb, j / 6.0)))
		if s > 0:
			ring0.append_array(outer[1])
			ring0.append(back)
			inner.reverse()
			ring0.append_array(inner)
		else:
			ring0.append_array(inner)
			ring0.append(back)
			ring0.append_array(left_back_to_front)
		var tube := [ring0]
		tube.append(_thigh_ring(_at(th[s], y_leg), s, lg))
		for r in th[s]:
			if float(r[0]) < y_leg - 0.02 and float(r[0]) > -0.33 * Ls:
				tube.append(_thigh_ring(r, s, lg))
		# through the knee (one round kneecap ring on the joint) and down the shin
		# to the ankle, inside the boot
		# (nine rings across the joint, an eighth of the band apart, so a deep bend
		# turns over an arc, not a point; no kneecap bump, which jutted out of it)
		var sr := _shin_rings()
		# (the ring on the joint is the thigh's and shin's own size there, so it
		# lines up with its neighbours)
		var tj := _at(th[s], -0.42 * Ls)
		var sj := _at(sr, 0.0)
		for i in range(9):
			var dk := KNEE_BAND - i * KNEE_BAND / 4.0
			if i < 4:
				tube.append(_thigh_ring(_at(th[s], -0.42 * Ls + dk), s, lg))
			elif i == 4:
				tube.append(_thigh_ring([-0.42 * Ls, lerpf(float(tj[1]), float(sj[1]), 0.5), lerpf(float(tj[2]), float(sj[2]), 0.5),
					lerpf(float(tj[3]), float(sj[3]), 0.5), float(tj[4]) * 0.5], s, lg))
			else:
				tube.append(_shin_ring(_at(sr, dk), s, lg, kj))
		# inside footwear the legs are tucked in, well clear of the shaft (a few
		# millimetres let vertex snapping push them out through it)
		var shod := _boot_top()
		for r in sr:
			if float(r[0]) < -KNEE_BAND - 0.02:
				var rr: Array = (r as Array).duplicate()
				if float(rr[0]) < shod:
					rr[1] = float(rr[1]) - 0.008
					rr[2] = float(rr[2]) - 0.008
				tube.append(_shin_ring(rr, s, lg, kj))
		if legs == "trousers" and shod == -INF:
			# a little flare at the hem
			var last: Array = (sr[sr.size() - 1] as Array).duplicate()
			last[1] = float(last[1]) + 0.012
			last[2] = float(last[2]) + 0.012
			tube[tube.size() - 1] = _shin_ring(last, s, lg, kj)
		mb.add_rings(m_legs, tube, 3.0, Color.WHITE, false, true, pick)
		if legs == "shorts":
			# the rolled cuff at the hem: a bulge that starts and ends on the thigh
			# (an open band showed its inside edge)
			var cuff := []
			for k in [[-0.17, 0.0], [-0.188, 0.006], [-0.206, 0.007], [-0.222, 0.0]]:
				var r := _off([_at(th[s], float(k[0]) * Ls)], float(k[1]))[0] as Array
				cuff.append(_thigh_ring(r, s, lg))
			mb.add_rings(m_legs, cuff, 3.0)
	mb.weld_normals()
	var lb := LowerBody.new()
	h.hips.add_child(lb)
	lb.setup(h.leg_l, h.leg_r, h.shin_l, h.shin_r, mb)


## A 12-point hip ring (front centre, +x side, back centre, -x side) of half
## width hw, half depth hd; `back` < 1 pulls the back centre in (the cleft),
## `bulge` > 1 rounds the back out on either side of it (the seat).
func _hip_ring(y: float, hw: float, hd: float, cz: float, back: float, bulge: float) -> PackedVector3Array:
	var half := [Vector2(0, -1), Vector2(0.55, -0.9), Vector2(0.92, -0.5), Vector2(1.0, 0.02), Vector2(0.92, 0.52 * bulge),
		Vector2(0.56, 0.95 * bulge), Vector2(0, back)]
	var out := PackedVector3Array()
	for p in half:
		out.append(Vector3(p.x * hw, y, cz + p.y * hd))
	for i in range(5, 0, -1):
		var p: Vector2 = half[i]
		out.append(Vector3(-p.x * hw, y, cz + p.y * hd))
	return out


## A 12-point ellipse ring from a shin-space shin ring, in hips space (the shin
## joint sits on the knee at kj, under the leg joint).
func _shin_ring(r: Array, s: int, lg: float, kj: float) -> PackedVector3Array:
	var out := PackedVector3Array()
	var cz := float(r[3]) if r.size() > 3 else 0.0
	for k in range(12):
		var a := deg_to_rad(30.0 * k)
		out.append(Vector3(s * lg + float(r[1]) * sin(a), kj + float(r[0]), cz - float(r[2]) * cos(a)))
	return out


## A 12-point ellipse ring (same point order) from a leg-space thigh ring, in hips space.
func _thigh_ring(r: Array, s: int, lg: float) -> PackedVector3Array:
	var cx := s * lg + float(r[4])
	var out := PackedVector3Array()
	for k in range(12):
		var a := deg_to_rad(30.0 * k)
		out.append(Vector3(cx + float(r[1]) * sin(a), float(r[0]) - 0.02, float(r[3]) - float(r[2]) * cos(a)))
	return out


func _torso() -> void:
	var top := str(lk.get("top", "shirt"))
	var m_top := m_skin if top == "bare" else _cloth("top_color")
	var tr := _torso_rings()
	var mb := MeshBuilder.new()
	mb.add_loft(m_top, Transform3D.IDENTITY, tr, P_BODY(), 3.0, Color.WHITE, false, true)
	# the tunic's skirt hangs in cloth panels that swing with the legs (a rigid
	# tube let the thighs through), snug under the belt and inside any coat's
	# tails; with a skirt it's tucked in
	if top == "tunic" and str(lk.get("legs", "")) != "skirt":
		var secs := []
		for i in range(6):
			secs.append([i * 60.0, (i + 1) * 60.0])
		_cloth_sectors(m_top, null, secs, -0.01, -0.21, [0.012, 0.02, 0.032], 0.2, 0.014)
	if top != "bare":
		var r := _at(tr, tu(0.6))
		var cz := _front_z(r) - 0.004
		var mc := _textured("fabric", _col("top_color").lightened(0.08))
		for s in [-1.0, 1.0]:
			mb.add_quad(mc, Vector3(0.0, tu(0.57), cz - 0.012), Vector3(s * 0.075, tu(0.665), cz + 0.012),
				Vector3(s * 0.1, tu(0.62), cz), Vector3(s * 0.025, tu(0.55), cz - 0.02),
				Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1))
		mb.add_tri(m_skin, Vector3(-0.045, tu(0.64), cz + 0.002), Vector3(0.045, tu(0.64), cz + 0.002), Vector3(0, tu(0.575), cz - 0.018),
			Vector3.FORWARD, Vector3.FORWARD, Vector3.FORWARD, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Color.WHITE, Vector3.FORWARD)
	_mesh(h.torso, mb)
	# neck (its own joint) from inside the collar up into the head
	var nmb := MeshBuilder.new()
	var head_y := h.head.position.y
	var hk := h.head.scale.y
	# runs up into the skull (closed top) so the nape never shows an open end
	nmb.add_loft(m_skin, Transform3D.IDENTITY, [[-0.03, 0.06, 0.058], [0.0, 0.058, 0.056], [head_y + 0.04 * hk, 0.052, 0.052, 0.006],
		[head_y + 0.12 * hk, 0.05, 0.05, 0.004], [head_y + 0.15 * hk, 0.03, 0.03, 0.0]], MeshBuilder.profile_oct(0.45), 3.0, Color.WHITE, false, true)
	_mesh(h.neck, nmb)


## A 12-point ellipse ring from a limb ring [y, hw, hd, cz?, cx?] in the space
## of a joint whose rest position (in the skeleton's space) is `origin`.
func _limb_ring(r: Array, origin: Vector3) -> PackedVector3Array:
	var cz := float(r[3]) if r.size() > 3 else 0.0
	var cx := float(r[4]) if r.size() > 4 else 0.0
	var out := PackedVector3Array()
	for k in range(12):
		var a := deg_to_rad(30.0 * k)
		out.append(origin + Vector3(cx + float(r[1]) * sin(a), float(r[0]), cz - float(r[2]) * cos(a)))
	return out


func _arms() -> void:
	var top := str(lk.get("top", "shirt"))
	var sleeves := str(lk.get("sleeves", "long"))
	if top == "bare":
		sleeves = "none"
	var coated := str(lk.get("coat", "none")) != "none"
	var m_top := _cloth("top_color")
	var gloves: bool = lk.get("gloves", false)
	var gauntlets: bool = lk.get("gauntlets", false)
	var m_hand := _leather("gloves_color") if gloves else m_skin
	var L := limb * (1.0 + (sh - 1.0) * 0.4)
	var prof := MeshBuilder.profile_oct(0.5)
	var wrist := -0.23 * A
	var elbow_y := -0.3 * A
	# upper arm rings (arm space) and forearm rings (forearm space) per outfit
	var up := [[0.036, 0.02 * L, 0.024 * L], [0.026, 0.046 * L, 0.052 * L], [0.0, 0.064 * L, 0.07 * L], [-0.06 * A, 0.071 * L, 0.077 * L],
		[-0.17 * A, 0.063 * L, 0.069 * L], [elbow_y, 0.055 * L, 0.06 * L]]
	var fo := [[0.02, 0.056 * L, 0.06 * L], [-0.08 * A, 0.06 * L, 0.064 * L, 0.004], [wrist, 0.043 * L, 0.047 * L]]
	var m_sleeve := m_top
	if coated:
		m_sleeve = _cloth("coat_color")
		up = [[0.07, 0.03 * L, 0.034 * L], [0.055, 0.062 * L, 0.068 * L], [0.02, 0.082 * L, 0.088 * L], [-0.06 * A, 0.09 * L, 0.096 * L], [elbow_y, 0.075 * L, 0.08 * L]]
		fo = [[0.02, 0.076 * L, 0.08 * L], [wrist + 0.02, 0.064 * L, 0.068 * L]]
	elif sleeves == "long":
		up = _off(up, 0.006)
		fo = _off(fo, 0.006)
		if top == "blouse":
			fo = [[0.02, 0.066 * L, 0.07 * L], [-0.1 * A, 0.08 * L, 0.084 * L, 0.006], [-0.19 * A, 0.062 * L, 0.066 * L], [wrist + 0.02, 0.05 * L, 0.054 * L]]
	elif sleeves == "short":
		up = _off(up, 0.003)
	var bare := not coated and sleeves != "long" and sleeves != "short"
	var shoulder_y := h.arm_l.position.y
	var short_hem := shoulder_y - 0.155 * A
	var pick := func(c: Vector3) -> Material:
		if bare or (not coated and sleeves == "short" and c.y < short_hem):
			return m_skin
		return m_sleeve
	# skinning: torso -> shoulder helper -> upper arm around the shoulder joint,
	# upper arm -> elbow helper -> forearm around the elbow (pure functions of position)
	var wf := func(p: Vector3) -> Array:
		var left := p.x < 0.0
		var ay := p.y - shoulder_y
		var de_ := ay - elbow_y
		if de_ < ARM_BAND:
			return _chain_w((ARM_BAND - de_) / (2.0 * ARM_BAND), ArmBody.ELBOW_L_CHAIN if left else ArmBody.ELBOW_R_CHAIN)
		return _chain_w((ARM_BAND - ay) / (2.0 * ARM_BAND), ArmBody.SHOULDER_L_CHAIN if left else ArmBody.SHOULDER_R_CHAIN)
	var arm_mbs := {}
	for side in [-1, 1]:
		var amb_all := MeshBuilder.new()
		amb_all.skinned = true
		amb_all.weight_fn = wf
		arm_mbs[side] = amb_all
		var a0 := (h.arm_l if side < 0 else h.arm_r).position
		# shoulder dome, then rings across the shoulder blend and down the upper
		# arm; five across the elbow (a deep bend turns over an arc); the forearm
		var tube := []
		var top_y := ARM_BAND + 0.004
		for r in up:
			if float(r[0]) > top_y:
				tube.append(_limb_ring(r, a0))
		if tube.is_empty():
			tube.append(_limb_ring(up[0], a0))   # the dome's tip
			top_y = float(up[0][0])
		for i in range(9):
			var y := ARM_BAND - i * ARM_BAND / 4.0
			if y < top_y - 0.002:
				tube.append(_limb_ring(_at(up, y), a0))
		for r in up:
			if float(r[0]) < -ARM_BAND - 0.02 and float(r[0]) > elbow_y + ARM_BAND + 0.02:
				tube.append(_limb_ring(r, a0))
		var ue: Array = up[up.size() - 1]
		var fe: Array = fo[0]
		var fo0 := a0 + Vector3(0, elbow_y, 0)
		for i in range(9):
			var de_ := ARM_BAND - i * ARM_BAND / 4.0
			if i < 4:
				tube.append(_limb_ring(_at(up, elbow_y + de_), a0))
			elif i == 4:
				tube.append(_limb_ring([elbow_y, maxf(float(ue[1]), float(fe[1])), maxf(float(ue[2]), float(fe[2]))], a0))
			else:
				tube.append(_limb_ring(_at(fo, de_), fo0))
		for r in fo:
			if float(r[0]) < -ARM_BAND - 0.02:
				tube.append(_limb_ring(r, fo0))
		amb_all.add_rings(m_sleeve, tube, 3.0, Color.WHITE, true, true, pick)
	var ab := ArmBody.new()
	h.torso.add_child(ab)
	ab.setup(h.arm_l, h.arm_r, h.fore_l, h.fore_r, arm_mbs[-1], arm_mbs[1])
	for side in [-1, 1]:
		var arm: Node3D = h.arm_l if side < 0 else h.arm_r
		var fore: Node3D = h.fore_l if side < 0 else h.fore_r
		var amb := MeshBuilder.new()
		var fmb := MeshBuilder.new()
		if top == "blouse" and sleeves == "long" and not coated:
			fmb.add_loft(m_top, Transform3D.IDENTITY, [[wrist + 0.03, 0.05 * L, 0.054 * L], [wrist - 0.005, 0.052 * L, 0.056 * L]], prof, 3.0)
		# mitten hand: wide front-to-back, thumb toward the front. Built as its
		# own mesh ("Mitten") so it can swap with a closed fist ("Fist") when
		# fighting bare-handed (Humanoid.set_fists).
		var k := Hk * limb
		var hmb := MeshBuilder.new()
		var hand := [[wrist + 0.015, 0.03 * k, 0.04 * k], [wrist - 0.02 * Hk, 0.028 * k, 0.056 * k, -0.005], [wrist - 0.08 * Hk, 0.026 * k, 0.057 * k, -0.005],
			[wrist - 0.115 * Hk, 0.02 * k, 0.04 * k, -0.004]]
		hmb.add_loft(m_hand, Transform3D.IDENTITY, hand, MeshBuilder.profile_oct(0.6), 3.0, Color.WHITE, true, true)
		var inward := -float(side)
		var tx := Transform3D(Basis(Vector3.FORWARD, inward * 0.5) * Basis(Vector3.RIGHT, 0.35), Vector3(inward * 0.012 * k, wrist - 0.005, -0.05 * k))
		hmb.add_loft(m_hand, tx, [[0.0, 0.016 * k, 0.018 * k], [-0.05 * k, 0.014 * k, 0.016 * k], [-0.07 * k, 0.008 * k, 0.01 * k]], MeshBuilder.profile_oct(0.6), 3.0, Color.WHITE, true, true)
		if not h.swappable_hands:
			# NPCs never fight bare-handed: keep the hand in the forearm's mesh
			fmb.merge(hmb)
			if gloves:
				fmb.add_loft(m_hand, Transform3D.IDENTITY, [[wrist + 0.06, 0.056 * L, 0.06 * L], [wrist + 0.01, 0.05 * L, 0.054 * L]], prof, 3.0, Color.WHITE, false, false, true, false, true)
			if gauntlets:
				_vambrace(fmb, wrist, L, k)
			_mesh(arm, amb)
			_mesh(fore, fmb)
			continue
		var mit := hmb.to_instance("Mitten")
		fore.add_child(mit)
		# closed fist: a chunky block of knuckles, the thumb wrapped across the front
		var fist_mb := MeshBuilder.new()
		var fist := [[wrist + 0.015, 0.031 * k, 0.041 * k], [wrist - 0.012 * Hk, 0.038 * k, 0.055 * k, -0.006],
			[wrist - 0.05 * Hk, 0.041 * k, 0.06 * k, -0.008], [wrist - 0.078 * Hk, 0.036 * k, 0.052 * k, -0.008], [wrist - 0.088 * Hk, 0.026 * k, 0.04 * k, -0.007]]
		fist_mb.add_loft(m_hand, Transform3D.IDENTITY, fist, MeshBuilder.profile_oct(0.85), 3.0, Color.WHITE, true, true)
		# the thumb lies across the front of the curled fingers, pointing in
		# toward the palm side, inside the outline of the fist
		var ttx := Transform3D(Basis(Vector3.BACK, inward * 1.5) * Basis(Vector3.RIGHT, -0.15), Vector3(-inward * 0.014 * k, wrist - 0.04 * Hk, -0.058 * k))
		fist_mb.add_loft(m_hand, ttx, [[0.0, 0.015 * k, 0.016 * k], [-0.034 * k, 0.014 * k, 0.014 * k], [-0.048 * k, 0.009 * k, 0.01 * k]], MeshBuilder.profile_oct(0.6), 3.0, Color.WHITE, true, true)
		var fi := fist_mb.to_instance("Fist")
		fi.visible = false
		fore.add_child(fi)
		if gloves:
			fmb.add_loft(m_hand, Transform3D.IDENTITY, [[wrist + 0.06, 0.056 * L, 0.06 * L], [wrist + 0.01, 0.05 * L, 0.054 * L]], prof, 3.0, Color.WHITE, false, false, true, false, true)
		if gauntlets:
			_vambrace(fmb, wrist, L, k)
		_mesh(arm, amb)
		_mesh(fore, fmb)


## Gauntlets: a steel plate round the forearm, flared at the wrist, and a
## plate over the back of the hand (on the forearm: it stays put when the
## hand swaps between open and fist).
func _vambrace(fmb: MeshBuilder, wrist: float, L: float, k: float) -> void:
	var steel := PSXMat.lit("metal", Color(0.9, 0.92, 0.96))
	# (out past a long sleeve or a coat's: inside one it vanished)
	fmb.add_loft(steel, Transform3D.IDENTITY, [[wrist + 0.15, 0.084 * L, 0.088 * L], [wrist + 0.03, 0.074 * L, 0.078 * L], [wrist + 0.005, 0.08 * L, 0.084 * L]],
		MeshBuilder.profile_oct(0.5), 0.5, Color.WHITE, false, false, true, false, true)
	for s in [-1.0, 1.0]:
		fmb.add_box(steel, Transform3D(Basis(), Vector3(s * 0.03 * k, wrist - 0.04 * Hk, -0.004)), Vector3(0.01, 0.06 * Hk, 0.07 * k), 3.0)


# --------------------------------------------------------------------------
# head, face, hair, hats
# --------------------------------------------------------------------------
## Height of the skull's dome above the 0.268 ring (it was a flatter 0.078).
const DOME_H := 0.12
## How much taller the dome is than hats were made for: their crowns rise by it.
const DOME_EXTRA := DOME_H - 0.078


func _head() -> void:
	var shape := str(lk.get("head", "round"))
	var wk := 1.0
	var jaw := 1.0
	yk = 1.0
	match shape:
		"square":
			jaw = 1.15
		"long":
			wk = 0.95; yk = 1.08; jaw = 0.95
	var R := P_HEAD()
	var cs := P_CHIN_V() if fem else P_JAW()
	if shape == "square":
		cs = P_JAW()
	var c0 := 0.02 * jaw if fem else 0.055 * jaw
	var c1 := 0.06 * jaw if fem else 0.09 * jaw
	var c2 := 0.102 * jaw if fem else 0.128 * jaw
	head_rings = [
		[0.0, c0, 0.025 if fem else 0.035, -0.105 if fem else -0.088, 0.0, cs],
		# the back of the skull comes down to jaw level (only the profile's back
		# half is pushed out, so the face is unchanged)
		[0.035, c1, 0.065 if fem else 0.07, -0.075 if fem else -0.068, 0.0, _back_ext(cs, 2.0 if fem else 1.85, 1.35 if fem else 1.3)],
		[0.085, c2 * wk, 0.1 if fem else 0.106, -0.04 if fem else -0.036, 0.0, _back_ext(cs, 1.4 if fem else 1.33, 1.15 if fem else 1.12)],
		[0.135, (0.136 if fem else 0.148) * wk, 0.13, -0.015, 0.0, _back_ext(R, 1.05 if fem else 1.08, 1.0)],
		[0.195, (0.153 if fem else 0.158) * wk, 0.148, -0.004, 0.0, R],
		[0.235, (0.162 if fem else 0.164) * wk, 0.156, 0.0, 0.0, R],
		[0.268, (0.16 if fem else 0.162) * wk, 0.158, 0.004, 0.0, R]]
	# a tall, round dome above the hairline (the face and forehead below are unchanged)
	var w0 := float(head_rings[head_rings.size() - 1][1])
	for deg in [24.0, 44.0, 61.0, 75.0, 85.0, 89.5]:
		var a := deg_to_rad(deg)
		var c := pow(cos(a), 0.85)
		head_rings.append([0.268 + DOME_H * sin(a), w0 * c, 0.158 * c, lerpf(0.004, 0.011, sin(a)), 0.0, R])
	for r in head_rings:
		r[0] = float(r[0]) * yk
	var mb := MeshBuilder.new()
	var hs := str(lk.get("hair", "short"))
	var face := FacePainter.material(lk, float(st["eye"]), [] if hs == "bald" else hairline_for(hs))
	# under the hair the scalp is hair-coloured: wherever it peeks through the
	# hair shell (vertex snapping at a distance) it still reads as hair
	var scalp: Material = null
	var hstyle := str(lk.get("hair", "short"))
	var hline: Array = []
	if hstyle != "bald":
		scalp = PSXMat.flat(_col("hair_color").darkened(0.15))
		hline = hairline_for(hstyle)
	var hy := yk
	var pick := func(c: Vector3):
		if FacePainter.pick(c, hy):
			return true
		if scalp != null and c.y / hy > BodyBuilder._hairline(hline, atan2(c.x, -c.z)) + 0.015:
			return scalp
		return false
	mb.add_loft(m_skin, Transform3D.IDENTITY, head_rings, R, 3.0, Color.WHITE, true, true, true, false, false,
		PackedInt32Array(), face, Callable(FacePainter, "uv").bind(yk), pick)
	_nose(mb)
	# ears (covered by long hair)
	var ears := [] if hair_hides_ears(str(lk.get("hair", "short"))) and str(lk.get("hat", "none")) != "hood" else [-1.0, 1.0]
	for s in ears:
		var r := _at(head_rings, 0.19 * yk)
		var ex: float = s * (float(r[1]) + 0.004)
		mb.add_loft(m_skin, Transform3D(Basis(Vector3.UP, s * 0.3), Vector3(ex, 0.15 * yk, 0.012)),
			[[0.0, 0.012, 0.022], [0.05, 0.016, 0.03], [0.095, 0.01, 0.02]], MeshBuilder.profile_oct(0.6), 3.0, Color.WHITE, true, true)
	_mesh(h.head, mb)
	var hmb := MeshBuilder.new()
	_hair(hmb)
	_press_under_hat(hmb)
	if _sims.has(h.head):
		_press_under_hat((_sims[h.head] as SpringChains).mb)
	_facial_hair(hmb)
	_hat(hmb)
	_mesh(h.head, hmb)


## Head-local height above which the hat covers the head (INF: no hat).
func _hat_cut() -> float:
	match str(lk.get("hat", "none")):
		"none":
			return INF
		"hood":
			return -1.0
		"bandana":
			return 0.241 * yk
		"knit":
			return 0.244 * yk
		"turban", "morion":
			return 0.25 * yk
	return 0.262 * yk


## A hat presses the hair under it flat: every hair vertex inside what the hat
## covers is pulled in to just over the scalp (and down under the crown), so
## no clump, cowlick or spike pokes through; hair below the brim is untouched.
func _press_under_hat(mb: MeshBuilder) -> void:
	var cut := _hat_cut()
	if cut == INF:
		return
	var top: float = (head_rings[head_rings.size() - 1] as Array)[0]
	# nearly onto the scalp (which is hair-coloured): the hair material is drawn
	# a centimetre toward the camera, so anything closer to the hat shows through
	var flat := 0.004
	var edge := hair_off + 0.004
	mb.map_vertices(m_hair, func(p: Vector3) -> Vector3:
		if p.y <= cut:
			return p
		var y := minf(p.y, top + flat)
		var r := _at(head_rings, minf(y, top - 0.001))
		var cx := float(r[4])
		var cz := float(r[3])
		var d := Vector2(p.x - cx, p.z - cz)
		var lim := _surf_r(r, atan2(d.x, -d.y)) + lerpf(edge, flat, smoothstep(cut, cut + 0.014, y))
		if d.length() > lim:
			d = d.normalized() * lim
		return Vector3(cx + d.x, y, cz + d.y))


func _nose(mb: MeshBuilder) -> void:
	var w := 0.016
	var p := 0.022
	var top := 0.15
	var bot := 0.105
	match str(lk.get("nose", "small")):
		"small": w = 0.012; p = 0.014; top = 0.14; bot = 0.108
		"broad": w = 0.026; p = 0.024; bot = 0.1
		"hooked": w = 0.018; p = 0.042; top = 0.17; bot = 0.098
	var rt := _at(head_rings, top * yk)
	var rb := _at(head_rings, bot * yk)
	var zt := _front_z(rt) + 0.004
	var zb := _front_z(rb) + 0.004
	var a := Vector3(0, top * yk, zt)
	var bl := Vector3(-w, bot * yk, zb)
	var br := Vector3(w, bot * yk, zb)
	var tip := Vector3(0, (bot + 0.006) * yk, zb - p)
	var c := Color(0.95, 0.95, 0.95)
	for tri in [[a, bl, tip], [a, tip, br], [bl, br, tip]]:
		var n: Vector3 = ((tri[1] - tri[0]) as Vector3).cross(tri[2] - tri[0]).normalized()
		var center: Vector3 = (tri[0] + tri[1] + tri[2]) / 3.0
		if n.dot(center - Vector3(0, center.y, zb + 0.05)) < 0.0:
			n = -n
		mb.add_tri(m_skin, tri[0], tri[1], tri[2], n, n, n, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, c, n)


func _hair_back_profile() -> PackedVector2Array:
	return PackedVector2Array([Vector2(1, -0.3), Vector2(1, 0.1), Vector2(0.86, 0.68), Vector2(0.45, 1),
		Vector2(-0.45, 1), Vector2(-0.86, 0.68), Vector2(-1, 0.1), Vector2(-1, -0.3)])


## Point on the head surface (+ offset) at an angle around the head (0 = front,
## + = character's right) and height y.
func _head_pt(angle: float, y: float, off: float) -> Vector3:
	var r := _at(head_rings, y)
	return Vector3(sin(angle) * (float(r[1]) + off), y, float(r[3]) - cos(angle) * (float(r[2]) + off))


## Hairline height (head-local, before yk) by angle around the head (0 = front,
## 90 = over the ear, 180 = nape). Lines are [degrees, y] pairs, mirrored.
const HAIRLINES := {
	"short": [[0, 0.262], [28, 0.258], [50, 0.244], [64, 0.2], [75, 0.152], [83, 0.168], [92, 0.246], [102, 0.24], [115, 0.17], [140, 0.112], [180, 0.092]],
	"crop": [[0, 0.272], [40, 0.265], [62, 0.222], [75, 0.19], [85, 0.215], [94, 0.252], [106, 0.236], [125, 0.185], [180, 0.152]],
	"long": [[0, 0.262], [40, 0.25], [60, 0.19], [78, 0.12], [110, 0.075], [180, 0.05]],
	"ponytail": [[0, 0.262], [35, 0.258], [56, 0.236], [68, 0.192], [79, 0.166], [90, 0.246], [104, 0.24], [125, 0.17], [180, 0.128]],
	"braids": [[0, 0.262], [40, 0.25], [60, 0.19], [78, 0.13], [110, 0.115], [180, 0.1]],
	"wild": [[0, 0.262], [28, 0.258], [50, 0.244], [64, 0.2], [75, 0.15], [83, 0.166], [92, 0.246], [102, 0.24], [115, 0.16], [140, 0.095], [180, 0.075]],
}


## Styles that share another's hairline.
const HAIRLINE_OF := {"bun": "ponytail", "swept": "short", "messy": "wild", "slick": "short", "topknot": "crop",
	"hime": "long", "twintails": "ponytail", "bob": "long", "side_pony": "ponytail",
	"quiff": "short", "curtains": "short", "spiky": "wild", "shag": "long", "swoop": "crop",
	"layered": "long", "lob": "long", "braid": "ponytail", "low_pony": "ponytail"}


static func hairline_for(style: String) -> Array:
	return HAIRLINES.get(style, HAIRLINES.get(HAIRLINE_OF.get(style, "short"), HAIRLINES["short"]))


static func _hairline(line: Array, a: float) -> float:
	var d := absf(rad_to_deg(wrapf(a, -PI, PI)))
	for i in range(1, line.size()):
		var p: Array = line[i - 1]
		var q: Array = line[i]
		if d <= float(q[0]):
			var t := (d - float(p[0])) / maxf(float(q[0]) - float(p[0]), 0.001)
			return lerpf(float(p[1]), float(q[1]), smoothstep(0.0, 1.0, t))
	return float((line[line.size() - 1] as Array)[1])


## Whether a hair style covers the ears (they're left off the head then).
static func hair_hides_ears(style: String) -> bool:
	return style in ["long", "braids", "hime", "bob", "shag", "layered", "lob"]


## Distance from the ring center to the head surface along angle a (actual
## ring profile, not an ellipse, so hair never cuts into the head).
func _surf_r(r: Array, a: float) -> float:
	var prof: PackedVector2Array = r[5] if r.size() > 5 and r[5] is PackedVector2Array else P_HEAD()
	var hw: float = r[1]
	var hd: float = r[2]
	var dir := Vector2(sin(a), -cos(a))
	var best := 0.0
	var n := prof.size()
	for i in range(n):
		var p0 := Vector2(prof[i].x * hw, prof[i].y * hd)
		var p1 := Vector2(prof[(i + 1) % n].x * hw, prof[(i + 1) % n].y * hd)
		var e := p1 - p0
		var den := dir.x * e.y - dir.y * e.x
		if absf(den) < 1e-9:
			continue
		var t := (p0.x * e.y - p0.y * e.x) / den
		var u := (p0.x * dir.y - p0.y * dir.x) / den
		if t > 0.0 and u >= -1e-4 and u <= 1.0 + 1e-4:
			best = maxf(best, t)
	return best if best > 0.0 else maxf(hw, hd)


## Point on the hair surface at angle a (0 = front, + = right), height y and
## offset off from the scalp. Below the skull at the back and sides the hair
## hangs straight down instead of following the head in toward the jaw/nape.
func _hair_pt(a: float, y: float, off: float, hang_k: float = 1.0) -> Vector3:
	var top: float = (head_rings[head_rings.size() - 1] as Array)[0]
	var ad := absf(wrapf(a, -PI, PI))
	var hang := hang_k * maxf(smoothstep(deg_to_rad(85.0), deg_to_rad(130.0), ad), smoothstep(deg_to_rad(45.0), deg_to_rad(80.0), ad) * 0.7)
	var ye := clampf(lerpf(y, maxf(y, 0.15 * yk), hang), 0.0, top - 0.004)
	var r := _at(head_rings, ye)
	var d := _surf_r(r, a) + off
	return Vector3(float(r[4]) + sin(a) * d, y, float(r[3]) - cos(a) * d)


func _hair(mb: MeshBuilder) -> void:
	var style := str(lk.get("hair", "short"))
	var hat := str(lk.get("hat", "none"))
	if style == "bald":
		return
	if hat == "hood" and style != "crop":
		style = "crop"
	var off := 0.018
	match style:
		"crop", "topknot", "swoop":
			off = 0.009
		"wild":
			off = 0.024
		"messy", "bob", "shag", "spiky", "layered", "lob":
			off = 0.021
		"slick":
			off = 0.012
	hair_off = off
	var line: Array = hairline_for(style)
	_hair_shell(mb, line, off)
	var trng := RandomNumberGenerator.new()
	trng.seed = hash(style + str(lk.get("hair_color", "")) + str(lk.get("name", "")))
	_tufts(mb, style, hat, trng)
	var head := h.head
	var hair_cols := ["head", "torso"]
	match style:
		"long":
			var sim := _sim(head)
			for ang in [130.0, 162.0, 198.0, 230.0]:
				var a: float = deg_to_rad(ang)
				var root := _hair_pt(a, 0.22 * yk, off - 0.004)
				var pts := PackedVector3Array([root])
				var dir := Vector3(sin(a), 0, -cos(a))
				for i in range(1, 4):
					pts.append(root + Vector3(0, -0.15 * i, 0) + dir * 0.02 * i)
				var bones := sim.add_chain(pts, 0.1, 0.07, 1.0, hair_cols)
				var rings := []
				for i in range(pts.size()):
					rings.append([pts[i].y, lerpf(1.0, 0.62, float(i) / 3.0), lerpf(1.0, 0.62, float(i) / 3.0), pts[i].z, pts[i].x])
				sim.mb.add_loft(m_hair, Transform3D.IDENTITY, rings, _strand_profile(a, 0.058, 0.018), 3.0, Color.WHITE, true, true, true, false, false, bones)
			for s in [-1.0, 1.0]:
				var a2: float = deg_to_rad(68.0) * s
				var root2 := _hair_pt(a2, 0.235 * yk, off - 0.002)
				var pts2 := PackedVector3Array([root2, root2 + Vector3(s * 0.01, -0.13, -0.005), root2 + Vector3(s * 0.015, -0.26, -0.005)])
				var bones2 := sim.add_chain(pts2, 0.12, 0.08, 1.0, hair_cols)
				var rings2 := []
				for i in range(pts2.size()):
					var k2 := lerpf(1.0, 0.55, i / 2.0)
					rings2.append([pts2[i].y, k2, k2, pts2[i].z, pts2[i].x])
				sim.mb.add_loft(m_hair, Transform3D.IDENTITY, rings2, _strand_profile(a2, 0.03, 0.014), 3.0, Color.WHITE, true, true, true, false, false, bones2)
		"ponytail":
			var sim := _sim(head)
			# (under a hat it's tied lower, coming out below the brim)
			var root := Vector3(0, 0.275 * yk, 0.165) if hat == "none" else Vector3(0, 0.215 * yk, 0.17)
			var pts := PackedVector3Array([root, root + Vector3(0, -0.06, 0.06), root + Vector3(0, -0.2, 0.08), root + Vector3(0, -0.34, 0.07), root + Vector3(0, -0.46, 0.05)])
			var bones := sim.add_chain(pts, 0.06, 0.05, 1.0, hair_cols)
			var rr := []
			var radii := [0.032, 0.05, 0.045, 0.034, 0.012]
			for i in range(pts.size()):
				rr.append([pts[i].y, radii[i], radii[i], pts[i].z, pts[i].x])
			sim.mb.add_loft(m_hair, Transform3D.IDENTITY, rr, MeshBuilder.profile_oct(0.5), 3.0, Color.WHITE, true, true, true, false, false, bones)
			mb.add_loft(_cloth("sash_color"), Transform3D.IDENTITY, [[root.y + 0.012, 0.036, 0.036, root.z], [root.y - 0.02, 0.036, 0.036, root.z + 0.01]], MeshBuilder.profile_oct(0.5), 3.0, Color.WHITE, true, true)
		"bun":
			var rng := RandomNumberGenerator.new()
			rng.seed = 7
			# high on the crown, or a low bun at the nape under a hat
			var at := Vector3(0, 0.3 * yk, 0.15) if hat == "none" else Vector3(0, 0.19 * yk, 0.17)
			mb.add_blob(m_hair, Transform3D(Basis(), at), Vector3(0.08, 0.075, 0.075) * (1.0 if hat == "none" else 0.85), rng, 0.08, 4, 7, 3.0)
		"braids":
			var sim := _sim(head)
			for s in [-1.0, 1.0]:
				var root := _hair_pt(deg_to_rad(95.0) * s, 0.17 * yk, off - 0.004)
				var pts := PackedVector3Array([root])
				for i in range(1, 5):
					pts.append(root + Vector3(s * 0.008 * i, -0.09 * i, -0.012 * i))
				var bones := sim.add_chain(pts, 0.08, 0.06, 1.0, hair_cols)
				# dense rings for the braid bumps, each snapped to its segment's bone
				var rr := []
				var rb := PackedInt32Array()
				for i in range(pts.size() - 1):
					for j in range(2):
						var t := j / 2.0
						var p := pts[i].lerp(pts[i + 1], t)
						var r := 0.03 if j == 0 else 0.022
						rr.append([p.y, r, r, p.z, p.x])
						rb.append(bones[i])
				var tip := pts[pts.size() - 1]
				rr.append([tip.y, 0.012, 0.012, tip.z, tip.x])
				rb.append(bones[pts.size() - 1])
				sim.mb.add_loft(m_hair, Transform3D.IDENTITY, rr, MeshBuilder.profile_oct(0.5), 3.0, Color.WHITE, true, true, true, false, false, rb)
		"hime":
			# straight, long, cut level at the back
			_back_strands([112.0, 136.0, 160.0, 180.0, 200.0, 224.0, 248.0], 4, 0.155, 0.055, 0.8, hair_cols)
		"low_pony":
			_low_pony(hair_cols)
		"braid":
			_single_braid(hair_cols)
		"twintails":
			_tails([-1.0, 1.0], hat, hair_cols)
		"side_pony":
			_tails([-1.0], hat, hair_cols)
		"topknot" when hat == "none":
			# samurai knot on the crown with a short tail flicking back (under a hat: tucked away)
			var rng2 := RandomNumberGenerator.new()
			rng2.seed = 13
			var top: float = (head_rings[head_rings.size() - 1] as Array)[0]
			var at := Vector3(0, top + 0.012, 0.035)
			mb.add_blob(m_hair, Transform3D(Basis(), at), Vector3(0.042, 0.038, 0.05), rng2, 0.08, 4, 7, 3.0)
			mb.add_loft(_cloth("sash_color"), Transform3D(Basis(Vector3.RIGHT, 0.5), at + Vector3(0, -0.012, 0.03)),
				[[-0.012, 0.03, 0.026], [0.012, 0.03, 0.026]], MeshBuilder.profile_oct(0.5), 3.0, Color.WHITE, true, true)
			var tail_dir := Vector3(0, 0.45, 1.0).normalized()
			mb.add_loft(m_hair, Transform3D(Basis(Quaternion(Vector3.UP, tail_dir)), at + Vector3(0, 0.0, 0.035)),
				[[0.0, 0.03, 0.026], [0.06, 0.028, 0.02], [0.12, 0.004, 0.004]], MeshBuilder.profile_oct(0.55), 3.0, Color.WHITE, false, true)
		"wild":
			# big anime spikes all over
			for i in range(14):
				var a := TAU * float(i) / 14.0
				var up := 0.35 + 0.4 * float(i % 3) / 2.0
				var dir := Vector3(sin(a) * 0.9, up + 0.25, -cos(a) * 0.8 + 0.25).normalized()
				var base := _hair_pt(a, (0.262 + up * 0.055) * yk, off - 0.01)
				var bas := Basis(Quaternion(Vector3.UP, dir))
				mb.add_loft(m_hair, Transform3D(bas, base), [[0.0, 0.05, 0.03], [0.07, 0.03, 0.02], [0.13, 0.004, 0.004]], MeshBuilder.profile_oct(0.55), 3.0, Color.WHITE, false, true)


## Flat strand cross-section (w wide, d thick) turned so its width runs along
## the head surface at `angle` (0 = front, + = right).
static func _strand_profile(angle: float, w: float, d: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in MeshBuilder.profile_oct(0.6):
		out.append(Vector2(p.x * w, p.y * d).rotated(angle))
	return out



## Physics strands hanging straight down the back (hime, bob): one per angle,
## `segs` segments of `seg_len`, `w` wide, tapering only to `tip` (cut level).
func _back_strands(angles: Array, segs: int, seg_len: float, w: float, tip: float, cols: Array) -> void:
	var sim := _sim(h.head)
	for ang in angles:
		var a: float = deg_to_rad(ang)
		var root := _hair_pt(a, 0.22 * yk, hair_off - 0.004)
		var pts := PackedVector3Array([root])
		var dir := Vector3(sin(a), 0, -cos(a))
		for i in range(1, segs + 1):
			pts.append(root + Vector3(0, -seg_len * i, 0) + dir * 0.012 * i)
		var bones := sim.add_chain(pts, 0.1, 0.07, 1.0, cols)
		var rings := []
		for i in range(pts.size()):
			var k := lerpf(1.0, tip, float(i) / segs)
			rings.append([pts[i].y, k, k, pts[i].z, pts[i].x])
		sim.mb.add_loft(m_hair, Transform3D.IDENTITY, rings, _strand_profile(a, w, 0.018), 3.0, Color.WHITE, true, true, true, false, false, bones)


## Tied tails high on the sides of the head (s = -1 left, 1 right): twin tails
## flare out and down, a single side ponytail hangs closer. Tied lower, below
## the brim, under a hat.
func _tails(sides: Array, hat: String, cols: Array) -> void:
	var sim := _sim(h.head)
	var twin := sides.size() == 2
	for s in sides:
		var root := _hair_pt(deg_to_rad(100.0) * s, (0.27 if hat == "none" else 0.215) * yk, hair_off + 0.004)
		var out := 0.1 if twin else 0.06
		var pts := PackedVector3Array([root, root + Vector3(s * out * 0.6, -0.04, 0.02), root + Vector3(s * out, -0.18, 0.03),
			root + Vector3(s * out * 1.1, -0.33, 0.03), root + Vector3(s * out, -0.48, 0.02)])
		var bones := sim.add_chain(pts, 0.06, 0.05, 1.0, cols)
		var radii := [0.03, 0.048, 0.044, 0.034, 0.012]
		var rr := []
		for i in range(pts.size()):
			rr.append([pts[i].y, radii[i], radii[i], pts[i].z, pts[i].x])
		sim.mb.add_loft(m_hair, Transform3D.IDENTITY, rr, MeshBuilder.profile_oct(0.5), 3.0, Color.WHITE, true, true, true, false, false, bones)
		# the tie
		var tie := PackedVector3Array()
		var tie2 := PackedVector3Array()
		var axis := (pts[1] - pts[0]).normalized()
		var side := axis.cross(Vector3.FORWARD).normalized()
		var up := side.cross(axis).normalized()
		for k in range(8):
			var ang := TAU * k / 8.0
			var d := side * cos(ang) + up * sin(ang)
			tie.append(pts[0] + axis * 0.004 + d * 0.036)
			tie2.append(pts[0] + axis * 0.026 + d * 0.038)
		_hair_tie(sim.mb, [tie, tie2], bones[0])


## Hair gathered low at the nape on the right and drawn forward over the right
## shoulder, a long loose tail with a slight wave.
func _low_pony(cols: Array) -> void:
	var sim := _sim(h.head)
	var root := _hair_pt(deg_to_rad(150.0), 0.15 * yk, hair_off + 0.006)
	var pts := PackedVector3Array([root, root + Vector3(0.04, -0.06, -0.03), root + Vector3(0.075, -0.17, -0.1),
		root + Vector3(0.085, -0.3, -0.15), root + Vector3(0.075, -0.43, -0.16), root + Vector3(0.085, -0.54, -0.15)])
	var bones := sim.add_chain(pts, 0.08, 0.06, 1.0, cols)
	var radii := [0.032, 0.046, 0.05, 0.044, 0.034, 0.01]
	var rr := []
	for i in range(pts.size()):
		rr.append([pts[i].y, radii[i], radii[i] * 0.8, pts[i].z, pts[i].x])
	sim.mb.add_loft(m_hair, Transform3D.IDENTITY, rr, MeshBuilder.profile_oct(0.5), 3.0, Color.WHITE, true, true, true, false, false, bones)
	var axis := (pts[1] - pts[0]).normalized()
	var side := axis.cross(Vector3.FORWARD).normalized()
	var up := side.cross(axis).normalized()
	var tie := PackedVector3Array()
	var tie2 := PackedVector3Array()
	for k in range(8):
		var ang := TAU * k / 8.0
		var dd := side * cos(ang) + up * sin(ang)
		tie.append(pts[0] + axis * 0.006 + dd * 0.038)
		tie2.append(pts[0] + axis * 0.026 + dd * 0.04)
	_hair_tie(sim.mb, [tie, tie2], bones[0])


## One thick braid down the middle of the back, tied at the end.
func _single_braid(cols: Array) -> void:
	var sim := _sim(h.head)
	var root := _hair_pt(PI, 0.19 * yk, hair_off - 0.002)
	var pts := PackedVector3Array([root])
	for i in range(1, 7):
		pts.append(root + Vector3(0.004 * sin(i * 1.3), -0.085 * i, 0.012 * minf(i, 2.0)))
	var bones := sim.add_chain(pts, 0.08, 0.06, 1.0, cols)
	# plaited bumps, each pair of rings on its segment's bone
	var rr := []
	var rb := PackedInt32Array()
	for i in range(pts.size() - 1):
		var taper := lerpf(1.0, 0.6, float(i) / (pts.size() - 2))
		for j in range(2):
			var p := pts[i].lerp(pts[i + 1], j / 2.0)
			var r := (0.056 if j == 0 else 0.04) * taper
			rr.append([p.y, r, r * 0.85, p.z, p.x])
			rb.append(bones[i])
	var tip := pts[pts.size() - 1]
	rr.append([tip.y + 0.012, 0.016, 0.014, tip.z, tip.x])
	rb.append(bones[pts.size() - 1])
	rr.append([tip.y - 0.05, 0.028, 0.024, tip.z, tip.x])
	rb.append(bones[pts.size() - 1])
	rr.append([tip.y - 0.09, 0.006, 0.006, tip.z, tip.x])
	rb.append(bones[pts.size() - 1])
	sim.mb.add_loft(m_hair, Transform3D.IDENTITY, rr, MeshBuilder.profile_oct(0.5), 3.0, Color.WHITE, true, true, true, false, false, rb)
	var b_end := bones[pts.size() - 1]
	var tie := PackedVector3Array()
	var tie2 := PackedVector3Array()
	for k in range(8):
		var ang := TAU * k / 8.0
		var dd := Vector3(cos(ang), 0, sin(ang))
		tie.append(tip + Vector3(0, 0.02, 0) + dd * 0.02)
		tie2.append(tip + Vector3(0, -0.004, 0) + dd * 0.021)
	_hair_tie(sim.mb, [tie, tie2], b_end)


func _hair_tie(smb: MeshBuilder, rings: Array, bone_i: int) -> void:
	var was := smb.bone
	smb.bone = bone_i
	smb.add_rings(_cloth("sash_color"), rings, 3.0, Color.WHITE, true, true)
	smb.bone = was


## A flat strand combed back over the scalp: from the front hairline at
## `side_deg` (+ = right) up over the crown and down the back, `w` wide. Rings
## are laid across the path, so it follows the head instead of hanging.
func _comb_strand(mb: MeshBuilder, side_deg: float, w: float, d: float, y_end: float, lift: float = 0.0) -> void:
	var top: float = (head_rings[head_rings.size() - 1] as Array)[0]
	var path := PackedVector3Array()
	var lifts := PackedFloat32Array()
	var n := 9
	for i in range(n):
		var t := float(i) / (n - 1)
		# front half rises to the crown, back half comes down behind it; `lift`
		# raises it off the scalp most just behind the hairline (a quiff)
		var front := t < 0.5
		var a := side_deg if front else 180.0 - side_deg
		var y := lerpf(0.292 * yk, top - 0.006, t * 2.0) if front else lerpf(top - 0.006, y_end * yk, (t - 0.5) * 2.0)
		var l := lift * sin(PI * clampf(t / 0.75, 0.0, 1.0))
		path.append(_scalp_pt(a, y, 0.002 + l))
		lifts.append(l)
	_path_strand(mb, path, w, d, 0.25, lifts)


## Point on the hair surface at a_deg around the head (0 = front, + = right),
## head-local height y, lifted `lift` off it along the head's outward normal.
func _scalp_pt(a_deg: float, y: float, lift: float) -> Vector3:
	var p := _hair_pt(deg_to_rad(a_deg), y, hair_off)
	return p + (p - Vector3(0, 0.15 * yk, 0)).normalized() * lift


## A flat strand through `path` (head-local), w wide and d thick, its width
## laid along the head; it narrows to `tip` of its width at the end. `fill`
## (per point: how far it's lifted off the scalp) carries its underside down
## to the scalp, so a lifted strand is a solid mass, not a sheet over a hollow.
func _path_strand(mb: MeshBuilder, path: PackedVector3Array, w: float, d: float, tip: float = 0.2,
		fill: PackedFloat32Array = PackedFloat32Array()) -> void:
	var rings := []
	var c := Vector3(0, 0.12 * yk, 0)
	var n := path.size()
	for i in range(n):
		var p := path[i]
		var tan := (path[mini(i + 1, n - 1)] - path[maxi(i - 1, 0)]).normalized()
		var nrm := (p - c).normalized()
		var side := tan.cross(nrm).normalized()
		nrm = side.cross(tan).normalized()
		var u := float(i) / (n - 1)
		# (the start swells up out of the hair cap instead of a flat open end)
		var k := lerpf(1.0, tip, pow(u, 2.0)) * lerpf(0.35, 1.0, smoothstep(0.0, 0.2, u))
		var sink := lerpf(-d * 1.2, 0.0, smoothstep(0.0, 0.2, u))
		var under := (float(fill[i]) + 0.004) if i < fill.size() else 0.0
		var ring := PackedVector3Array()
		for q in range(6):
			var ang := TAU * q / 6.0
			var s := sin(ang)
			ring.append(p + side * cos(ang) * w * k + nrm * ((s * d + d) * k * lerpf(1.0, 0.6, u) + sink - (under if s < 0.0 else 0.0)))
		rings.append(ring)
	mb.add_rings(m_hair, rings, 3.0, Color.WHITE, false, true)


## A strand swept from the front hairline at a0 over the crown round to a1,
## rising off the head toward its end (lift0 -> lift1) so the tip sticks out.
func _sweep_strand(mb: MeshBuilder, a0: float, a1: float, y_end: float, lift0: float, lift1: float, w: float, d: float) -> void:
	var top: float = (head_rings[head_rings.size() - 1] as Array)[0]
	var path := PackedVector3Array()
	var lifts := PackedFloat32Array()
	var n := 9
	for i in range(n):
		var t := float(i) / (n - 1)
		var y := lerpf(0.29 * yk, top - 0.01, smoothstep(0.0, 0.45, t)) if t < 0.45 else lerpf(top - 0.01, y_end * yk, smoothstep(0.45, 1.0, t))
		var l := lerpf(lift0, lift1, t * t)
		path.append(_scalp_pt(lerpf(a0, a1, t), y, l))
		lifts.append(l)
	_path_strand(mb, path, w, d, 0.15, lifts)


## The hair mass: a shell over the scalp whose lower edge follows a natural
## hairline (temples, sideburns, around the ears, nape), tucked in at the edge
## and closed over the crown. Two-sided, darker inside.
func _hair_shell(mb: MeshBuilder, line: Array, off: float) -> void:
	var cols := 32
	var rows := 7
	var top: float = (head_rings[head_rings.size() - 1] as Array)[0]
	var y_hi := top - 0.016 * yk
	var grid: Array = []
	for k in range(cols):
		var a := -PI + TAU * float(k) / cols
		var yl := _hairline(line, a) * yk
		var col := PackedVector3Array()
		for j in range(rows):
			var t := float(j) / (rows - 1)
			var y := lerpf(yl, y_hi, pow(t, 0.8))
			var o := lerpf(off * 0.25, off, smoothstep(0.0, 0.3, t)) + 0.003
			# the lowest rows curve back in to meet the scalp / nape (no ledge)
			col.append(_hair_pt(a, y, o, [0.0, 0.55, 1.0][mini(j, 2)]))
		grid.append(col)
	var ring_top: Array = head_rings[head_rings.size() - 1]
	var crown := Vector3(float(ring_top[4]), top + off + 0.008, float(ring_top[3]))
	# normals radiate from low in the head so the hair's lower edge isn't lit
	# like an overhang
	var c := Vector3(0, 0.06 * yk, 0.0)
	var dark := Color(0.62, 0.62, 0.62)
	for k in range(cols):
		var k1 := (k + 1) % cols
		var ga: PackedVector3Array = grid[k]
		var gb: PackedVector3Array = grid[k1]
		var u0 := float(k) / cols * 3.0
		var u1 := float(k + 1) / cols * 3.0
		for j in range(rows - 1):
			var p := [ga[j], gb[j], gb[j + 1], ga[j + 1]]
			var uv := [Vector2(u0, p[0].y * 5.0), Vector2(u1, p[1].y * 5.0), Vector2(u1, p[2].y * 5.0), Vector2(u0, p[3].y * 5.0)]
			_hair_quad(mb, p, uv, c, dark)
		var pa: Vector3 = ga[rows - 1]
		var pb: Vector3 = gb[rows - 1]
		var na := (pa - c).normalized()
		var nb := (pb - c).normalized()
		mb.add_tri(m_hair, crown, pa, pb, Vector3.UP, na, nb, Vector2((u0 + u1) * 0.5, crown.y * 5.0), Vector2(u0, pa.y * 5.0), Vector2(u1, pb.y * 5.0), Color.WHITE, Vector3.UP)


func _hair_quad(mb: MeshBuilder, p: Array, uv: Array, c: Vector3, dark: Color) -> void:
	var n: Array = []
	for q in p:
		n.append(((q as Vector3) - c).normalized())
	var f: Vector3 = ((p[0] as Vector3) + (p[1] as Vector3) + (p[2] as Vector3) + (p[3] as Vector3) - c * 4.0).normalized()
	mb.add_tri(m_hair, p[0], p[1], p[2], n[0], n[1], n[2], uv[0], uv[1], uv[2], Color.WHITE, f)
	mb.add_tri(m_hair, p[0], p[2], p[3], n[0], n[2], n[3], uv[0], uv[2], uv[3], Color.WHITE, f)
	mb.add_tri(m_hair, p[0], p[1], p[2], -n[0], -n[1], -n[2], uv[0], uv[1], uv[2], dark, -f)
	mb.add_tri(m_hair, p[0], p[2], p[3], -n[0], -n[2], -n[3], uv[0], uv[2], uv[3], dark, -f)


## A pointed clump of hair growing from the shell at angle a_deg, height
## y_root, hanging `length` down along the head; `sweep` turns it sideways
## (degrees over its length), `flick` lifts the tip away from the head.
func _clump(mb: MeshBuilder, a_deg: float, y_root: float, length: float, w: float, d: float,
		sweep: float = 0.0, flick: float = 0.0, off_extra: float = 0.0) -> void:
	var rings := []
	# the root grows out of the hair cap: two narrower rings above it, sunk into
	# the cap, so the top slopes in instead of ending in a flat ledge
	var top: float = (head_rings[head_rings.size() - 1] as Array)[0]
	var a0 := deg_to_rad(a_deg)
	for b in [[0.05, 0.25, -1.4], [0.028, 0.6, -0.6], [0.012, 0.88, -0.15]]:
		var yb := minf(y_root * yk + float(b[0]), top - 0.004)
		var pb := _hair_pt(a0, yb, hair_off + 0.001 + off_extra + d * float(b[2]))
		rings.append([pb.y, b[1], b[1], pb.z, pb.x])
	var n := 5
	for i in range(n):
		var t := float(i) / (n - 1)
		var a := deg_to_rad(a_deg + sweep * t)
		var y := (y_root - length * t) * yk
		var o := hair_off + 0.001 + off_extra - 0.004 * sin(PI * t) + flick * t * t
		var pt := _hair_pt(a, y, o)
		var k := lerpf(1.0, 0.1, pow(t, 1.15))
		rings.append([pt.y, k, k, pt.z, pt.x])
	mb.add_loft(m_hair, Transform3D.IDENTITY, rings, _strand_profile(deg_to_rad(a_deg + sweep * 0.5), w, d), 3.0, Color.WHITE, true, true)


## A tuft sticking up / out from the head (cowlicks, spiky crowns).
func _spike(mb: MeshBuilder, a_deg: float, y: float, dir: Vector3, length: float, w: float) -> void:
	var a := deg_to_rad(a_deg)
	var base := _hair_pt(a, y * yk, hair_off - 0.008)
	var bas := Basis(Quaternion(Vector3.UP, dir.normalized()))
	mb.add_loft(m_hair, Transform3D(bas, base), [[0.0, w, w * 0.6], [length * 0.55, w * 0.6, w * 0.4], [length, 0.003, 0.003]],
		MeshBuilder.profile_oct(0.55), 3.0, Color.WHITE, true, true)


## Bangs, side locks, nape tufts and cowlicks per style. Lengths are jittered
## a little per character so no two heads look stamped out.
func _tufts(mb: MeshBuilder, style: String, hat: String, rng: RandomNumberGenerator) -> void:
	var j := func(v: float) -> float: return v * rng.randf_range(0.86, 1.14)
	var crowned := hat == "none"
	match style:
		"crop":
			for i in range(5):
				var a := -36.0 + i * 18.0
				_clump(mb, a, 0.282, j.call(0.032), 0.05, 0.01, 6.0)
			for i in range(5):
				_clump(mb, 140.0 + i * 20.0, 0.19, j.call(0.03), 0.05, 0.01, 0.0, 0.006)
		"short", "wild":
			var wild := style == "wild"
			# side-swept bangs, longest over the eye they sweep toward
			var count := 7 if not wild else 8
			for i in range(count):
				var t := float(i) / (count - 1)
				var a := lerpf(-50.0, 48.0, t)
				var lgt: float = j.call(lerpf(0.05, 0.085, 1.0 - absf(t - 0.62) * 1.6) * (1.25 if wild else 1.0))
				_clump(mb, a, 0.292, lgt, 0.052 if not wild else 0.058, 0.013, 14.0 if not wild else 8.0, 0.006 if not wild else 0.022)
			for s in [-1.0, 1.0]:
				# locks in front of the ears and a tuft over each ear
				_clump(mb, s * 64.0, 0.25, j.call(0.085), 0.042, 0.012, s * 6.0, 0.004)
				_clump(mb, s * 76.0, 0.235, j.call(0.08), 0.036, 0.011, s * 4.0, 0.002)
				_clump(mb, s * 96.0, 0.275, j.call(0.05), 0.05, 0.012, s * 8.0, 0.014 if not wild else 0.03)
				_clump(mb, s * 112.0, 0.255, j.call(0.07), 0.05, 0.012, s * 6.0, 0.01 if not wild else 0.03)
			# nape: tufts that flick out at the tips
			for i in range(7):
				var a := 122.0 + i * 19.3
				var ry := 0.2 + 0.025 * float((i * 3) % 4) / 3.0
				_clump(mb, a, ry, j.call((0.1 if not wild else 0.12) + (ry - 0.2)), 0.056, 0.013, (a - 180.0) * 0.1, 0.004 if not wild else 0.012)
			if crowned and not wild:
				# cowlick at the crown
				_spike(mb, 170.0, 0.33 + DOME_EXTRA, Vector3(0.15, 1.0, 0.7), 0.08, 0.026)
				_spike(mb, 200.0, 0.325 + DOME_EXTRA, Vector3(-0.3, 1.0, 0.8), 0.065, 0.022)
				_spike(mb, 10.0, 0.335 + DOME_EXTRA, Vector3(0.2, 1.0, -0.25), 0.06, 0.02)
		"long", "braids":
			# centre-parted bangs sweeping outward, with face-framing locks
			for s in [-1.0, 1.0]:
				for i in range(4):
					var a: float = s * (6.0 + i * 12.0)
					_clump(mb, a, 0.29, j.call(lerpf(0.08, 0.06, i / 3.0)), 0.05, 0.012, s * 10.0, 0.004)
				_clump(mb, s * 54.0, 0.262, j.call(0.2), 0.05, 0.013, s * 6.0, 0.008, 0.004)
				_clump(mb, s * 66.0, 0.25, j.call(0.24), 0.05, 0.013, s * 4.0, 0.01, 0.008)
			if crowned:
				_spike(mb, 185.0, 0.335 + DOME_EXTRA, Vector3(0.1, 1.0, 0.6), 0.06, 0.02)
		"ponytail", "bun", "twintails", "side_pony":
			# swept bangs, long side strands framing the face, hair pulled back
			for i in range(6):
				var t := float(i) / 5.0
				var a := lerpf(-44.0, 40.0, t)
				_clump(mb, a, 0.29, j.call(lerpf(0.085, 0.055, t)), 0.05, 0.012, -12.0, 0.006)
			for s in [-1.0, 1.0]:
				_clump(mb, s * 62.0, 0.255, j.call(0.15), 0.04, 0.012, s * 5.0, 0.008)
			for i in range(5):
				_clump(mb, 140.0 + i * 20.0, 0.16, j.call(0.03), 0.04, 0.01, 0.0, 0.004)
		"swept":
			# long bangs swept across to the left, the longest hanging over the
			# left eye; short at the sides and nape
			for i in range(8):
				var t := float(i) / 7.0
				var a := lerpf(46.0, -50.0, t)
				_clump(mb, a, 0.298, j.call(lerpf(0.055, 0.165, t * t)), 0.06, 0.013, -26.0 * t, 0.006 + 0.014 * t)
			for s in [-1.0, 1.0]:
				_clump(mb, s * 68.0, 0.25, j.call(0.08), 0.042, 0.012, s * 5.0, 0.004)
				_clump(mb, s * 96.0, 0.272, j.call(0.055), 0.05, 0.012, s * 8.0, 0.012)
				_clump(mb, s * 114.0, 0.25, j.call(0.07), 0.05, 0.012, s * 6.0, 0.01)
			for i in range(7):
				var a := 122.0 + i * 19.3
				_clump(mb, a, 0.21, j.call(0.09), 0.056, 0.013, (a - 180.0) * 0.1, 0.006)
			if crowned:
				_spike(mb, 175.0, 0.33 + DOME_EXTRA, Vector3(0.1, 1.0, 0.7), 0.07, 0.024)
		"messy":
			# straw-hat-captain mop: uneven bangs pointing every which way,
			# tufts sticking out over the ears and at the nape
			for i in range(9):
				var t := float(i) / 8.0
				var a := lerpf(-56.0, 56.0, t)
				var lgt: float = j.call(0.06 + 0.035 * float(i % 3) / 2.0)
				_clump(mb, a, 0.295, lgt, 0.056, 0.014, rng.randf_range(-18.0, 18.0), rng.randf_range(0.008, 0.024))
			for s in [-1.0, 1.0]:
				_clump(mb, s * 70.0, 0.258, j.call(0.1), 0.05, 0.013, s * 12.0, 0.03)
				_clump(mb, s * 90.0, 0.275, j.call(0.075), 0.055, 0.013, s * 14.0, 0.042)
				_clump(mb, s * 112.0, 0.26, j.call(0.085), 0.055, 0.013, s * 10.0, 0.036)
			for i in range(8):
				var a := 124.0 + i * 16.0
				_clump(mb, a, 0.205 + 0.02 * float(i % 2), j.call(0.11), 0.058, 0.014, (a - 180.0) * 0.15, 0.028)
			if crowned:
				for k in range(4):
					var ka := 150.0 + k * 22.0
					_spike(mb, ka, 0.33 + DOME_EXTRA, Vector3(sin(deg_to_rad(ka)) * 0.6, 1.0, 0.5), j.call(0.07), 0.024)
		"slick":
			# combed straight back: strands laid over the crown from the
			# hairline, the ends flicking out at the nape, one loose strand
			# falling over the forehead
			for i in range(7):
				var sd := -54.0 + i * 18.0
				_comb_strand(mb, sd, 0.03, 0.006, 0.2 + 0.02 * float(i % 2))
			for i in range(5):
				_clump(mb, 140.0 + i * 20.0, 0.21, j.call(0.06), 0.05, 0.012, 0.0, 0.014)
			_clump(mb, -22.0, 0.292, j.call(0.08), 0.02, 0.008, -12.0, 0.012)
		"quiff":
			# pompadour: the front swept up and back in a tall roll, short sides
			for i in range(7):
				var sd := -48.0 + i * 16.0
				_comb_strand(mb, sd, 0.05, 0.011, 0.21, 0.055 * (1.0 - absf(sd) / 110.0))
			for s in [-1.0, 1.0]:
				_clump(mb, s * 72.0, 0.25, j.call(0.06), 0.045, 0.01, s * 4.0, 0.004)
				_clump(mb, s * 100.0, 0.262, j.call(0.05), 0.05, 0.01, s * 6.0, 0.006)
			for i in range(5):
				_clump(mb, 140.0 + i * 20.0, 0.205, j.call(0.06), 0.05, 0.011, 0.0, 0.008)
		"curtains":
			# middle part, the fringe falling away to both sides, and an
			# antenna strand springing up off the crown
			for s in [-1.0, 1.0]:
				for i in range(4):
					var a: float = s * (4.0 + i * 13.0)
					_clump(mb, a, 0.298, j.call(lerpf(0.11, 0.075, i / 3.0)), 0.055, 0.013, s * 24.0, 0.012)
				_clump(mb, s * 66.0, 0.26, j.call(0.11), 0.048, 0.012, s * 8.0, 0.01)
				_clump(mb, s * 96.0, 0.27, j.call(0.08), 0.052, 0.012, s * 8.0, 0.012)
				_clump(mb, s * 116.0, 0.25, j.call(0.09), 0.052, 0.012, s * 6.0, 0.012)
			for i in range(7):
				var a := 122.0 + i * 19.3
				_clump(mb, a, 0.21, j.call(0.1), 0.056, 0.013, (a - 180.0) * 0.1, 0.008)
			if crowned:
				var top: float = (head_rings[head_rings.size() - 1] as Array)[0]
				var p0 := _scalp_pt(175.0, top - 0.012, 0.0)
				_path_strand(mb, PackedVector3Array([p0, p0 + Vector3(0.0, 0.05, -0.005), p0 + Vector3(0.008, 0.09, -0.04),
					p0 + Vector3(0.012, 0.1, -0.08), p0 + Vector3(0.012, 0.085, -0.11)]), 0.02, 0.006, 0.2)
		"spiky":
			# short and jagged: a ragged fringe and spikes standing out all over
			for i in range(9):
				var t := float(i) / 8.0
				_clump(mb, lerpf(-54.0, 54.0, t), 0.295, j.call(0.05 + 0.03 * float(i % 2)), 0.05, 0.012, rng.randf_range(-12.0, 12.0), 0.012)
			for k in range(16):
				var ka := -90.0 + k * 22.5
				var yy := 0.31 + 0.035 * float(k % 3)
				var dir := Vector3(sin(deg_to_rad(ka)) * 0.75, 1.0, -cos(deg_to_rad(ka)) * 0.75 + 0.15)
				_spike(mb, ka, yy + DOME_EXTRA * 0.5, dir, j.call(0.075), 0.03)
			for s in [-1.0, 1.0]:
				_clump(mb, s * 72.0, 0.255, j.call(0.08), 0.045, 0.012, s * 10.0, 0.026)
				_clump(mb, s * 100.0, 0.265, j.call(0.07), 0.05, 0.012, s * 12.0, 0.034)
			for i in range(7):
				var a := 124.0 + i * 18.7
				_clump(mb, a, 0.21, j.call(0.09), 0.05, 0.012, (a - 180.0) * 0.15, 0.03)
		"shag":
			# wolf cut: choppy layers to the shoulders, a ragged fringe falling
			# over one eye, flicking out at the ends
			for i in range(8):
				var t := float(i) / 7.0
				_clump(mb, lerpf(48.0, -52.0, t), 0.298, j.call(lerpf(0.08, 0.15, t)), 0.056, 0.014, -14.0 * t + rng.randf_range(-6.0, 6.0), 0.012 + 0.01 * t)
			for k in range(13):
				var ka := 58.0 + k * 20.3
				_clump(mb, ka, 0.285, j.call(0.15), 0.06, 0.014, rng.randf_range(-10.0, 10.0), 0.02)
				_clump(mb, ka + 10.0, 0.235, j.call(0.2 + 0.03 * float(k % 2)), 0.058, 0.014, rng.randf_range(-8.0, 8.0), 0.03, 0.006)
			if crowned:
				for k in range(3):
					var ka := 160.0 + k * 20.0
					_spike(mb, ka, 0.33 + DOME_EXTRA, Vector3(sin(deg_to_rad(ka)) * 0.5, 1.0, 0.6), j.call(0.06), 0.024)
		"swoop":
			# undercut with a big sweep: the top swept up from the left round to
			# the back right, its ends standing out behind
			for i in range(5):
				var a0 := -48.0 + i * 14.0
				_sweep_strand(mb, a0, 120.0 + i * 10.0, 0.31 + 0.012 * i, 0.012, 0.075 - 0.008 * i, 0.05, 0.012)
			for i in range(5):
				_clump(mb, 140.0 + i * 20.0, 0.2, j.call(0.04), 0.05, 0.009, 0.0, 0.003)
		"layered":
			# shoulder-length layers flicking out at the ends, curtain bangs
			for s in [-1.0, 1.0]:
				for i in range(4):
					var a: float = s * (5.0 + i * 13.0)
					_clump(mb, a, 0.298, j.call(lerpf(0.13, 0.1, i / 3.0)), 0.055, 0.013, s * 26.0, 0.014)
			for k in range(14):
				var ka := 56.0 + k * 19.0
				_clump(mb, ka, 0.275, j.call(0.22), 0.065, 0.015, 0.0, 0.045, 0.004)
				_clump(mb, ka + 9.0, 0.24, j.call(0.15), 0.06, 0.014, 0.0, 0.03, 0.01)
		"lob":
			# a long bob to the shoulders, swept side bangs
			for i in range(7):
				var t := float(i) / 6.0
				_clump(mb, lerpf(-46.0, 40.0, t), 0.298, j.call(lerpf(0.15, 0.08, t)), 0.058, 0.013, 22.0 * (1.0 - t), 0.008)
			for k in range(15):
				var ka := 52.0 + k * 18.0
				_clump(mb, ka, 0.278, 0.26, 0.075, 0.016, 0.0, 0.016, 0.006)
		"braid", "low_pony":
			# hair drawn back, long face-framing strands (and side-swept bangs)
			for i in range(6):
				var t := float(i) / 5.0
				_clump(mb, lerpf(-46.0, 38.0, t), 0.296, j.call(lerpf(0.12, 0.06, t)), 0.052, 0.012, 16.0 * (1.0 - t), 0.008)
			for s in [-1.0, 1.0]:
				_clump(mb, s * 62.0, 0.258, j.call(0.24), 0.04, 0.011, s * 6.0, 0.006)
				_clump(mb, s * 72.0, 0.25, j.call(0.2), 0.034, 0.01, s * 4.0, 0.008, 0.004)
		"topknot":
			# shaved-short sides, a few loose strands at the temples
			for s in [-1.0, 1.0]:
				_clump(mb, s * 58.0, 0.268, j.call(0.1), 0.03, 0.009, s * 4.0, 0.004)
		"hime":
			# blunt bangs cut straight across, and cheek-length side locks cut level
			for i in range(11):
				var a := -50.0 + i * 10.0
				_clump(mb, a, 0.296, 0.08, 0.05, 0.012, 0.0, 0.004)
			for s in [-1.0, 1.0]:
				_clump(mb, s * 64.0, 0.262, 0.17, 0.05, 0.013, 0.0, 0.008, 0.004)
				_clump(mb, s * 76.0, 0.25, 0.17, 0.05, 0.013, 0.0, 0.01, 0.008)
		"bob":
			# rounded bob to the jaw all the way round, ends curling in, with bangs
			for i in range(9):
				var a := -44.0 + i * 11.0
				_clump(mb, a, 0.296, j.call(0.075), 0.052, 0.013, 0.0, 0.006)
			for k in range(15):
				var a := 52.0 + k * 18.0
				_clump(mb, a, 0.275, 0.2, 0.075, 0.016, 0.0, 0.01, 0.006)


func _facial_hair(mb: MeshBuilder) -> void:
	var fh := str(lk.get("facial_hair", "none"))
	if fem or fh in ["none", "stubble"]:
		return
	var front := PackedVector2Array([Vector2(-1, 0.25), Vector2(-1, -0.4), Vector2(-0.7, -1), Vector2(0.7, -1), Vector2(1, -0.4), Vector2(1, 0.25)])
	var jaw := _off(_clip(head_rings, 0.0, 0.1 * yk), 0.014, 0.0, true)
	match fh:
		"beard", "long_beard":
			var rings := jaw.duplicate()
			rings.insert(0, [-0.03, 0.04, 0.05, (jaw[0] as Array)[3] as float - 0.015, 0.0])
			if fh == "long_beard":
				rings.insert(0, [-0.15, 0.022, 0.03, (jaw[0] as Array)[3] as float - 0.04, 0.0])
			mb.add_loft(m_hair, Transform3D.IDENTITY, rings, front, 3.0, Color.WHITE, false, false, false)
			_moustache(mb)
		"goatee":
			mb.add_loft(m_hair, Transform3D.IDENTITY, [[-0.03, 0.03, 0.06, (jaw[0] as Array)[3] as float], [0.04, 0.045, 0.1, -0.04]],
				PackedVector2Array([Vector2(-1, -0.6), Vector2(-0.5, -1), Vector2(0.5, -1), Vector2(1, -0.6)]), 3.0, Color.WHITE, false, false, false)
			_moustache(mb)
		"moustache":
			_moustache(mb)
		"chops":
			for s in [-1.0, 1.0]:
				var side := _off(_clip(head_rings, 0.06 * yk, 0.22 * yk), 0.012, 0.0, true)
				mb.add_loft(m_hair, Transform3D.IDENTITY, side,
					PackedVector2Array([Vector2(s, 0.15), Vector2(s, -0.45), Vector2(s * 0.8, -0.8)]), 3.0, Color.WHITE, false, false, false)
			_moustache(mb)


func _moustache(mb: MeshBuilder) -> void:
	var r := _at(head_rings, 0.088 * yk)
	var z := _front_z(r) - 0.006
	for s in [-1.0, 1.0]:
		mb.add_box(m_hair, Transform3D(Basis(Vector3.FORWARD, s * 0.35), Vector3(s * 0.026, 0.088 * yk, z)), Vector3(0.045, 0.014, 0.02), 3.0, Color.WHITE, false)


func _hat(mb: MeshBuilder) -> void:
	var kind := str(lk.get("hat", "none"))
	var m_hat := _cloth("hat_color")
	var y0 := 0.268 * yk
	var cr := _at(head_rings, y0)
	var rw := float(cr[1]) + hair_off + 0.014
	var rd := float(cr[2]) + hair_off + 0.014
	var crown_prof := MeshBuilder.profile_oct(0.5)
	var captain := str(lk.get("coat", "none")) == "captain"
	var m_trim := PSXMat.flat(_col("trim_color"))
	match kind:
		"tricorn":
			mb.add_loft(m_hat, Transform3D.IDENTITY, [[y0, rw, rd], [y0 + 0.07, rw * 0.98, rd * 0.98], [y0 + 0.13, rw * 0.8, rd * 0.82], [y0 + 0.155, rw * 0.45, rd * 0.48]],
				crown_prof, 3.0, Color.WHITE, false, true)
			var tri := PackedVector2Array()
			for i in range(18):
				var a := TAU * float(i) / 18.0
				var r := 0.78 + 0.22 * cos(3.0 * a)
				tri.append(Vector2(sin(a), -cos(a)) * r)
			var bw := rw * 1.85
			mb.add_loft(m_hat, Transform3D.IDENTITY, [[y0 + 0.01, bw, bw], [y0 + 0.085, bw * 1.12, bw * 1.12]], tri, 3.0, Color.WHITE, false, false, true, false, true)
			mb.add_profile_disc(m_hat, Transform3D.IDENTITY, y0 + 0.01, bw, bw, tri, 3.0)
			if captain:
				mb.add_loft(m_trim, Transform3D.IDENTITY, [[y0 + 0.08, bw * 1.115, bw * 1.115], [y0 + 0.092, bw * 1.135, bw * 1.135]], tri, 3.0, Color.WHITE, false, false, true, false, true)
		"bicorne":
			mb.add_loft(m_hat, Transform3D.IDENTITY, [[y0, rw, rd], [y0 + 0.06 + DOME_EXTRA * 0.6, rw * 0.98, rd * 0.98], [y0 + 0.1 + DOME_EXTRA, rw * 0.7, rd * 0.72]], crown_prof, 3.0, Color.WHITE, false, true)
			var ell := PackedVector2Array()
			for i in range(14):
				var a := TAU * float(i) / 14.0
				ell.append(Vector2(sin(a), -cos(a)))
			mb.add_loft(m_hat, Transform3D.IDENTITY, [[y0 + 0.02, rw * 2.1, rd * 0.68], [y0 + 0.12, rw * 1.92, rd * 0.4], [y0 + 0.2, rw * 1.3, rd * 0.14]], ell, 3.0, Color.WHITE, true, true)
			mb.add_cylinder(m_trim if captain else _cloth("sash_color"), Transform3D(Basis(Vector3.RIGHT, PI / 2.0), Vector3(rw * 0.7, y0 + 0.1, -rd * 0.66)), 0.035, 0.035, 0.01, 8, 3.0)
		"bandana":
			var wrap := _off(_clip(head_rings, 0.245 * yk, 1.0), hair_off + 0.012)
			var nw := wrap.size()
			wrap[nw - 1][0] = float(wrap[nw - 1][0]) + hair_off + 0.014
			wrap[nw - 2][0] = float(wrap[nw - 2][0]) + (hair_off + 0.014) * 0.7
			mb.add_loft(m_hat, Transform3D.IDENTITY, wrap, P_HEAD(), 3.0, Color.WHITE, false, true)
			var rng := RandomNumberGenerator.new()
			rng.seed = 11
			var knot := _head_pt(PI, 0.258 * yk, hair_off + 0.02)
			mb.add_blob(m_hat, Transform3D(Basis(), knot), Vector3(0.04, 0.035, 0.035), rng, 0.1, 3, 6, 3.0)
			var sim := _sim(h.head)
			for s in [-1.0, 1.0]:
				var root: Vector3 = knot + Vector3(s * 0.018, -0.01, 0.01)
				var pts := PackedVector3Array([root, root + Vector3(s * 0.03, -0.08, 0.02), root + Vector3(s * 0.05, -0.17, 0.03)])
				var bones := sim.add_chain(pts, 0.05, 0.05, 1.0, ["head", "torso"])
				var rr := []
				for i in range(pts.size()):
					rr.append([pts[i].y, lerpf(0.022, 0.014, i / 2.0), 0.005, pts[i].z, pts[i].x])
				sim.mb.add_loft(m_hat, Transform3D.IDENTITY, rr, MeshBuilder.profile_oct(0.6), 3.0, Color.WHITE, true, true, true, false, false, bones)
		"cap":
			mb.add_loft(m_hat, Transform3D.IDENTITY, [[y0, rw, rd], [y0 + 0.06 + DOME_EXTRA * 0.5, rw * 1.04, rd * 1.05, -0.01], [y0 + 0.1 + DOME_EXTRA, rw * 0.92, rd * 0.97, -0.012], [y0 + 0.115 + DOME_EXTRA, rw * 0.58, rd * 0.62, -0.01]],
				crown_prof, 3.0, Color.WHITE, false, true)
			mb.add_box(m_hat, Transform3D(Basis(Vector3.RIGHT, 0.18), Vector3(0, y0 + 0.008, -rd - 0.03)), Vector3(rw * 1.4, 0.014, 0.09), 3.0, Color.WHITE, false)
		"knit":
			mb.add_loft(m_hat, Transform3D.IDENTITY, [[y0 - 0.02, rw, rd], [y0 + 0.07, rw * 0.98, rd * 0.98], [y0 + 0.13, rw * 0.7, rd * 0.72], [y0 + 0.16, rw * 0.24, rd * 0.26]],
				crown_prof, 3.0, Color.WHITE, false, true)
			mb.add_loft(_textured("fabric", _col("hat_color").darkened(0.15)), Transform3D.IDENTITY, [[y0 - 0.025, rw + 0.008, rd + 0.008], [y0 + 0.03, rw + 0.01, rd + 0.01]], crown_prof, 3.0)
		"straw":
			var straw := PSXMat.lit("straw", Color(1.0, 0.95, 0.8))
			mb.add_cylinder(straw, Transform3D(Basis(), Vector3(0, y0 + 0.01, 0)), rw * 2.5, rw * 2.4, 0.025, 10, 3.0, Color.WHITE, true, true, false)
			mb.add_cylinder(straw, Transform3D(Basis(), Vector3(0, y0 + 0.02, 0)), rw * 1.05, rw * 0.9, 0.12, 8, 3.0, Color.WHITE, true, false, false)
			mb.add_cylinder(_cloth("hat_color"), Transform3D(Basis(), Vector3(0, y0 + 0.03, 0)), rw * 1.06, rw * 1.02, 0.035, 8, 3.0, Color.WHITE, false, false, false)
		"cavalier":
			# a tall soft crown, a broad brim and a plume swept back over it
			mb.add_loft(m_hat, Transform3D.IDENTITY, [[y0, rw, rd], [y0 + 0.08 + DOME_EXTRA * 0.6, rw * 1.02, rd * 1.02], [y0 + 0.14 + DOME_EXTRA, rw * 0.86, rd * 0.88], [y0 + 0.16 + DOME_EXTRA, rw * 0.5, rd * 0.52]],
				crown_prof, 3.0, Color.WHITE, false, true)
			mb.add_cylinder(m_hat, Transform3D(Basis(Vector3.RIGHT, -0.12), Vector3(0, y0 + 0.012, 0)), rw * 2.45, rw * 2.3, 0.022, 12, 3.0, Color.WHITE, true, true, false)
			mb.add_cylinder(m_trim, Transform3D(Basis(), Vector3(0, y0 + 0.03, 0)), rw * 1.03, rw * 1.0, 0.03, 8, 3.0, Color.WHITE, false, false, false)
			var plume := PSXMat.lit("fabric", Color(0.95, 0.92, 0.86))
			var p0 := Vector3(rw * 0.75, y0 + 0.07, -rd * 0.3)
			for i in range(4):
				var t := i / 3.0
				var at := p0 + Vector3(rw * 0.25 * t, 0.07 * sin(t * PI) + 0.02 * t, rd * 1.3 * t)
				mb.add_box(plume, Transform3D(Basis(Vector3.RIGHT, -0.5 + t * 0.9) * Basis(Vector3.FORWARD, 0.3), at), Vector3(0.03 * (1.2 - t * 0.5), 0.012, 0.1), 3.0)
		"morion":
			# a steel helmet: a crested dome over a brim sweeping up fore and aft
			var steel := PSXMat.lit("metal", Color(0.9, 0.92, 0.95))
			mb.add_loft(steel, Transform3D.IDENTITY, [[y0 - 0.005, rw * 1.02, rd * 1.02], [y0 + 0.07 + DOME_EXTRA * 0.6, rw * 1.0, rd * 1.0], [y0 + 0.13 + DOME_EXTRA, rw * 0.72, rd * 0.76], [y0 + 0.155 + DOME_EXTRA, rw * 0.3, rd * 0.32]],
				crown_prof, 0.5, Color.WHITE, false, true)
			mb.add_box(steel, Transform3D(Basis(), Vector3(0, y0 + 0.15 + DOME_EXTRA, 0)), Vector3(0.012, 0.06, rd * 1.7), 3.0)
			var brim := PackedVector2Array()
			for i in range(16):
				var a := TAU * float(i) / 16.0
				brim.append(Vector2(sin(a), -cos(a)))
			mb.add_loft(steel, Transform3D.IDENTITY, [[y0 - 0.01, rw * 1.05, rd * 1.05], [y0 + 0.0, rw * 1.45, rd * 1.85]], brim, 0.5, Color.WHITE, false, false, true, false, true)
			for s in [-1.0, 1.0]:
				mb.add_box(steel, Transform3D(Basis(Vector3.RIGHT, s * 0.55), Vector3(0, y0 + 0.035, s * rd * 1.65)), Vector3(rw * 1.2, 0.012, 0.09), 3.0)
			mb.add_box(PSXMat.flat(Color(0.88, 0.72, 0.3)), Transform3D(Basis(), Vector3(rw * 0.98, y0 + 0.02, 0)), Vector3(0.012, 0.025, 0.025), 3.0)
		"turban":
			# cloth wound round and round, a jewel at the front
			for i in range(3):
				var yy := y0 - 0.015 + i * 0.045
				var sw := 1.1 - i * 0.07
				mb.add_loft(m_hat, Transform3D(Basis(Vector3.FORWARD, (0.08 if i % 2 == 0 else -0.06)), Vector3.ZERO),
					[[yy, rw * sw, rd * sw], [yy + 0.035, rw * (sw + 0.04), rd * (sw + 0.04)], [yy + 0.06, rw * (sw - 0.06), rd * (sw - 0.06)]], crown_prof, 3.0, Color.WHITE, false, i == 2)
			mb.add_box(PSXMat.glow(Color(0.85, 0.2, 0.25), 1.2), Transform3D(Basis(), Vector3(0, y0 + 0.06, -rd * 1.12)), Vector3(0.025, 0.03, 0.012), 3.0)
			mb.add_box(PSXMat.flat(Color(0.88, 0.72, 0.3)), Transform3D(Basis(), Vector3(0, y0 + 0.06, -rd * 1.1)), Vector3(0.04, 0.045, 0.008), 3.0)
		"hood":
			var hood := _off(head_rings, 0.04, 0.0, true)
			hood.insert(0, [-0.08, 0.13, 0.13, 0.03, 0.0])
			hood.append([(0.385 + DOME_EXTRA) * yk, 0.04, 0.06, 0.03, 0.0])
			# the opening's edges sit back along the cheeks (edges as far forward as
			# the face hid half of it from any angle but straight on)
			var hood_prof := PackedVector2Array([Vector2(0.86, -0.5), Vector2(1, -0.15), Vector2(1, 0.45), Vector2(0.45, 1),
				Vector2(-0.45, 1), Vector2(-1, 0.45), Vector2(-1, -0.15), Vector2(-0.86, -0.5)])
			mb.add_loft(m_hat, Transform3D.IDENTITY, hood, hood_prof, 3.0, Color.WHITE, false, false, false)


# --------------------------------------------------------------------------
# outer layers
# --------------------------------------------------------------------------
func _clothes() -> void:
	var tr := _torso_rings()
	var prof := MeshBuilder.profile_oct(0.55)
	var mb := MeshBuilder.new()
	match str(lk.get("vest", "none")):
		"vest":
			mb.add_loft(_cloth("vest_color"), Transform3D.IDENTITY, _off(_clip(tr, 0.0, tu(0.57)), 0.016, 0.0, true), open_body(0.3), 3.0, Color.WHITE, false, false, false)
			for i in range(3):
				var by := ty(0.12 + i * 0.12)
				var r := _at(tr, by)
				mb.add_box(PSXMat.flat(_col("trim_color")), Transform3D(Basis(), Vector3(-float(r[1]) * 0.3 - 0.012, by, _front_z(r) - 0.016)), Vector3(0.016, 0.016, 0.01), 3.0)
		"corset":
			mb.add_loft(_cloth("vest_color"), Transform3D.IDENTITY, _off(_clip(tr, 0.0, ty(0.36 if fem else 0.4)), 0.011), P_BODY(), 3.0, Color.WHITE, false, false)
			for i in range(5):
				var by := ty(0.05 + i * 0.06)
				var r := _at(tr, by)
				mb.add_box(PSXMat.flat(Color(0.1, 0.08, 0.07)), Transform3D(Basis(), Vector3(0, by, _front_z(r) - 0.012)), Vector3(0.05, 0.006, 0.004), 3.0)
		"cuirass":
			# a steel breast- and backplate, a ridge down the front, two lames over the belly
			# (the metal texture stretched wide: tiled at cloth scale it read as stripes)
			var steel := PSXMat.lit("metal", Color(0.92, 0.94, 0.98).lerp(_col("vest_color"), 0.2))
			mb.add_loft(steel, Transform3D.IDENTITY, _off(_clip(tr, ty(0.02), tu(0.56)), 0.026), P_BODY(), 0.5, Color.WHITE, false, false)
			var y_lo := ty(0.08)
			var y_hi := tu(0.5)
			var rm := _at(tr, (y_lo + y_hi) * 0.5)
			mb.add_box(steel, Transform3D(Basis(), Vector3(0, (y_lo + y_hi) * 0.5, _front_z(rm) - 0.032)), Vector3(0.016, y_hi - y_lo, 0.012), 3.0)
			var w0 := float(tr[0][1])
			var d0 := float(tr[0][2])
			for i in range(2):
				var yy := -0.012 - i * 0.04
				mb.add_loft(steel, Transform3D.IDENTITY, [[yy - 0.035, w0 + 0.034 + i * 0.006, d0 + 0.034 + i * 0.006], [yy, w0 + 0.03 + i * 0.006, d0 + 0.03 + i * 0.006]],
					MeshBuilder.profile_oct(0.55), 3.0, Color.WHITE, false, false, true, false, true)
			var gold := PSXMat.flat(Color(0.88, 0.72, 0.3))
			for s in [-1.0, 1.0]:
				var ry := tu(0.48)
				var rr := _at(tr, ry)
				mb.add_box(gold, Transform3D(Basis(), Vector3(s * float(rr[1]) * 0.55, ry, _front_z(rr) - 0.03)), Vector3(0.014, 0.014, 0.008), 3.0)
		"brigandine":
			# leather studded with the heads of the plates riveted inside it
			var m_brig := _textured("leather", _col("vest_color"))
			mb.add_loft(m_brig, Transform3D.IDENTITY, _off(_clip(tr, 0.0, tu(0.55)), 0.022), P_BODY(), 3.0, Color.WHITE, false, false)
			var stud := PSXMat.lit("metal", Color(0.85, 0.82, 0.7))
			for row in range(5):
				var by := ty(0.06 + row * 0.08)
				var r := _at(tr, by)
				for col in range(5):
					var x := (col - 2) * float(r[1]) * 0.28
					var z := _front_z(r) - 0.024 + absf(x) * 0.35
					mb.add_box(stud, Transform3D(Basis(), Vector3(x, by, z)), Vector3(0.012, 0.012, 0.008), 3.0)
		"mail":
			# a shirt of rings, hanging down over the hips
			var m_mail := _textured("fabric", Color(0.66, 0.68, 0.72))
			var w0 := float(tr[0][1])
			var d0 := float(tr[0][2])
			var mail := [[-0.11, w0 + 0.045, d0 + 0.045], [-0.03, w0 + 0.03, d0 + 0.03]]
			for r in _off(_clip(tr, 0.0, tu(0.57)), 0.016, 0.0, true):
				mail.append(r)
			mb.add_loft(m_mail, Transform3D.IDENTITY, mail, MeshBuilder.profile_oct(0.55), 3.0, Color.WHITE, false, false)
	var coat := str(lk.get("coat", "none"))
	if coat != "none":
		_coat(mb, tr, coat)
	if str(lk.get("legs", "")) == "skirt":
		_skirt(_cloth("legs_color"))
	_belts(mb, tr, prof)
	if lk.get("apron", false):
		_apron(mb, tr)
	_mesh(h.torso, mb)


func _coat(mb: MeshBuilder, tr: Array, coat: String) -> void:
	var m_coat := _cloth("coat_color")
	var m_trim := PSXMat.flat(_col("trim_color"))
	var captain := coat == "captain"
	var shell := _off(_clip(tr, 0.0, tu(0.62)), 0.03 + (0.012 if fem else 0.0), 0.0, true)
	mb.add_loft(m_coat, Transform3D.IDENTITY, shell, open_body(0.3), 3.0, Color.WHITE, false, false, false)
	if coat == "jacket":
		# short tails over the hips (cloth panels: a rigid hem let the thighs through)
		_cloth_sectors(m_coat, null, [[32.0, 100.0], [100.0, 180.0], [180.0, 260.0], [260.0, 328.0]],
			0.04, -0.14, [0.03, 0.045, 0.06], 0.18)
	mb.add_loft(m_coat, Transform3D.IDENTITY, [[tu(0.6), 0.105, 0.095, 0.012], [tu(0.6) + 0.11, 0.115, 0.105, 0.02]], open_front(0.55), 3.0, Color.WHITE, false, false, false)
	var lap := m_trim if captain else _textured("fabric", _col("coat_color").darkened(0.12))
	for s in [-1.0, 1.0]:
		var rt := _at(tr, tu(0.56))
		var rb := _at(tr, ty(0.3))
		var zt := _front_z(rt) - 0.028
		var zb := _front_z(rb) - 0.03
		mb.add_quad(lap, Vector3(s * 0.07, tu(0.6), zt + 0.01), Vector3(s * 0.16, tu(0.55), zt + 0.02),
			Vector3(s * float(rb[1]) * 0.42, ty(0.3), zb), Vector3(s * float(rb[1]) * 0.3, ty(0.3), zb - 0.002),
			Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1))
	if captain:
		for s in [-1.0, 1.0]:
			var pts := []
			for y in [0.0, 0.15, 0.3]:
				var r := _at(tr, ty(y))
				pts.append(Vector3(s * float(r[1]) * 0.3 + s * 0.008, ty(y), _front_z(r) - 0.03))
			for i in range(pts.size() - 1):
				var a: Vector3 = pts[i]
				var b: Vector3 = pts[i + 1]
				mb.add_quad(m_trim, a, a + Vector3(s * 0.018, 0, 0), b + Vector3(s * 0.018, 0, 0), b, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Color.WHITE, Vector3.FORWARD)
			var ex: float = s * (h.arm_r.position.x - 0.02)
			mb.add_box(m_trim, Transform3D(Basis(Vector3.FORWARD, s * 0.25), Vector3(ex, tu(0.6), 0.0)), Vector3(0.11, 0.02, 0.12), 3.0, Color.WHITE, false)
			mb.add_box(m_trim, Transform3D(Basis(), Vector3(ex + s * 0.05, tu(0.6) - 0.03, 0.0)), Vector3(0.012, 0.05, 0.11), 3.0, Color.WHITE, false)
	# turned-back cuffs (the sleeves themselves are the skinned arms, see _arms)
	var L := limb * (1.0 + (sh - 1.0) * 0.4)
	var wrist := -0.23 * A
	var cuff := [[wrist + 0.11, 0.08 * L, 0.084 * L], [wrist + 0.015, 0.082 * L, 0.086 * L]]
	for side in [-1, 1]:
		var fmb := MeshBuilder.new()
		fmb.add_loft(m_trim if captain else lap, Transform3D.IDENTITY, cuff, MeshBuilder.profile_oct(0.5), 3.0, Color.WHITE, false, false, true, false, true)
		_mesh(h.fore_l if side < 0 else h.fore_r, fmb)
	if coat in ["longcoat", "captain", "greatcoat"]:
		_cloth_sectors(m_coat, m_trim if captain else null, [[32.0, 100.0], [100.0, 180.0], [180.0, 260.0], [260.0, 328.0]],
			0.04, -0.02 - 0.42 * Ls - (0.14 if coat == "greatcoat" else 0.08), [0.03, 0.05, 0.08, 0.11], 0.14)
	if coat == "greatcoat":
		# a short cape over the shoulders
		var cape: Array = []
		for r in _clip(tr, tu(0.36), tu(0.63)):
			var rr: Array = (r as Array).slice(0, 5)
			while rr.size() < 5:
				rr.append(0.0)
			var k := inverse_lerp(tu(0.36), tu(0.63), float(rr[0]))
			rr[1] = float(rr[1]) * lerpf(1.32, 1.12, k) + 0.05
			rr[2] = float(rr[2]) * lerpf(1.2, 1.08, k) + 0.05
			cape.append(rr)
		mb.add_loft(m_coat, Transform3D.IDENTITY, cape, open_body(0.22), 3.0, Color.WHITE, false, false, false, false, true)


func _skirt(m: Material) -> void:
	var secs := []
	for i in range(6):
		secs.append([i * 60.0, (i + 1) * 60.0])
	_cloth_sectors(m, null, secs, 0.07, -0.02 - 0.42 * Ls + 0.04, [0.02, 0.04, 0.08, 0.12], 0.2)


## Hanging cloth around the hips (coat tails, skirts) split into sectors, each
## a physics chain so it swings and is pushed aside by the legs.
## angles: [[a0, a1], ...] in degrees (0 = front, 90 = right). Rows run from
## y_top down to y_bot with outward `flare` per row.
func _cloth_sectors(m: Material, m_trim: Material, sectors: Array, y_top: float, y_bot: float, flare: Array, stiff: float,
		top_off: float = 0.035) -> void:
	var sim := _sim(h.hips)
	var hw := _hips_hw()
	var hd := _hips_hd()
	var rows_n := flare.size()
	for sec in sectors:
		var a0 := deg_to_rad(float(sec[0]))
		var a1 := deg_to_rad(float(sec[1]))
		var am := (a0 + a1) * 0.5
		var chain := PackedVector3Array()
		var rows := []
		for r in range(rows_n):
			var y := lerpf(y_top, y_bot, float(r) / (rows_n - 1))
			var fl: float = flare[r]
			var aw := hw + fl
			var ad := hd + fl * 0.9
			if r == 0:
				aw = (_torso_rings()[0][1] as float) + top_off
				ad = (_torso_rings()[0][2] as float) + top_off
			var row := PackedVector3Array()
			for k in range(4):
				var a := lerpf(a0, a1, k / 3.0)
				row.append(Vector3(sin(a) * aw, y, -cos(a) * ad))
			rows.append(row)
			chain.append(Vector3(sin(am) * aw, y, -cos(am) * ad))
		var bones := sim.add_chain(chain, stiff, 0.06, 1.0, ["thigh_l", "thigh_r", "shin_l", "shin_r", "hips"])
		sim.mb.add_strip_grid(m, Transform3D.IDENTITY, rows, bones, 3.0, Color.WHITE, Vector3.ZERO)
		if m_trim:
			var last: PackedVector3Array = rows[rows_n - 1]
			var hem := PackedVector3Array()
			for p in last:
				hem.append(p + Vector3(0, 0.035, 0) + Vector3(p.x, 0, p.z).normalized() * 0.004)
			var hem2 := PackedVector3Array()
			for p in last:
				hem2.append(p + Vector3(p.x, 0, p.z).normalized() * 0.004)
			var hb := bones[rows_n - 1]
			sim.mb.add_strip_grid(m_trim, Transform3D.IDENTITY, [hem, hem2], PackedInt32Array([hb, hb]), 3.0, Color.WHITE, Vector3.ZERO)


func _belts(mb: MeshBuilder, tr: Array, prof: PackedVector2Array) -> void:
	var belt := str(lk.get("belt", "none"))
	# under a coat only the front shows (its opening): the rest, a centimetre
	# inside the coat, was pushed out through it by vertex snapping
	var coated := str(lk.get("coat", "none")) != "none"
	var closed := not coated
	if coated:
		prof = PackedVector2Array()
		for i in range(9):
			var a := lerpf(-1.25, 1.25, i / 8.0)
			prof.append(Vector2(sin(a), -cos(a)))
	if belt in ["belt", "belt_sash"]:
		# straddles the seam where the shirt meets the trousers
		var by := -0.025 if belt == "belt" else -0.035
		var band := _off(_clip(tr, maxf(by, 0.0), by + 0.06), 0.017, 0.0, true)
		if by < 0.0:
			band = [[by, (tr[0][1] as float) + 0.02, (tr[0][2] as float) + 0.02], [by + 0.055, (tr[0][1] as float) + 0.018, (tr[0][2] as float) + 0.018]]
		mb.add_loft(_leather("belt_color"), Transform3D.IDENTITY, band, prof, 3.0, Color.WHITE, false, false, closed, false, true)
		var r := _at(tr, maxf(by, 0.0))
		mb.add_box(PSXMat.flat(Color(0.82, 0.72, 0.38)), Transform3D(Basis(), Vector3(0, by + 0.03, _front_z(r) - 0.024)), Vector3(0.05, 0.045, 0.012), 3.0)
	if belt in ["sash", "belt_sash"]:
		var sy := ty(0.04) if belt == "belt_sash" else 0.0
		var band2 := _off(_clip(tr, sy, sy + 0.1), 0.02, 0.0, true)
		var m_sash := _cloth("sash_color")
		mb.add_loft(m_sash, Transform3D.IDENTITY, band2, prof, 3.0, Color.WHITE, false, false, closed, false, true)
		var r2 := _at(tr, sy + 0.05)
		# the knot at the side, or in the coat's opening (its tail hung through the coat)
		var kk := 0.3 if coated else 0.75
		var kx := -float(r2[1]) * kk
		var kz := float(r2[3]) - float(r2[2]) * (0.97 if coated else 0.75) - 0.02
		var rng := RandomNumberGenerator.new()
		rng.seed = 5
		mb.add_blob(m_sash, Transform3D(Basis(), Vector3(kx, sy + 0.05, kz)), Vector3(0.035, 0.035, 0.03), rng, 0.1, 3, 6, 3.0)
		# hanging tail (physics)
		var sim := _sim(h.torso)
		var t0 := Vector3(kx - 0.01, sy + 0.035, kz - 0.012)
		var pts := PackedVector3Array([t0, t0 + Vector3(-0.01, -0.1, -0.005), t0 + Vector3(-0.02, -0.2, -0.008), t0 + Vector3(-0.025, -0.29, -0.01)])
		var bones := sim.add_chain(pts, 0.08, 0.06, 1.0, ["thigh_l", "hips"])
		var rr := []
		for i in range(pts.size()):
			rr.append([pts[i].y, lerpf(0.026, 0.02, i / 3.0), 0.006, pts[i].z, pts[i].x])
		sim.mb.add_loft(m_sash, Transform3D.IDENTITY, rr, MeshBuilder.profile_oct(0.6), 3.0, Color.WHITE, true, true, true, false, false, bones)


func _apron(mb: MeshBuilder, tr: Array) -> void:
	var m_ap := _cloth("apron_color")
	var rt := _at(tr, ty(0.38))
	var rb := _at(tr, 0.0)
	# out past a vest or corset (it showed through), and narrow enough to hang
	# in a coat's open front instead of through its tails
	var out := 0.03 + (0.018 if str(lk.get("vest", "none")) != "none" else 0.0)
	var hw := 0.1 if str(lk.get("coat", "none")) != "none" else 0.17
	var zt := _front_z(rt) - out
	var zb := _front_z(rb) - out
	mb.add_quad(m_ap, Vector3(-hw * 0.7, ty(0.38), zt), Vector3(hw * 0.7, ty(0.38), zt), Vector3(hw * 0.88, 0.0, zb), Vector3(-hw * 0.88, 0.0, zb),
		Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1), Color.WHITE, Vector3.FORWARD)
	var sim := _sim(h.hips)
	var z0 := -_hips_hd() - 0.035 - (out - 0.03)
	var y1 := -0.02 - 0.42 * Ls * 0.95
	var chain := PackedVector3Array([Vector3(0, 0.0, z0), Vector3(0, y1 * 0.5, z0 - 0.02), Vector3(0, y1, z0 - 0.04)])
	var bones := sim.add_chain(chain, 0.16, 0.06, 1.0, ["thigh_l", "thigh_r", "hips"])
	var rows := []
	for p in chain:
		rows.append(PackedVector3Array([p + Vector3(-hw, 0, 0.01), p + Vector3(-hw * 0.35, 0, -0.004), p + Vector3(hw * 0.35, 0, -0.004), p + Vector3(hw, 0, 0.01)]))
	sim.mb.add_strip_grid(m_ap, Transform3D.IDENTITY, rows, bones, 3.0, Color.WHITE, Vector3(0, 0, 0.3))


## A cape hanging from the shoulders to the backs of the knees, swinging
## (cloth on a chain like the apron, the other way round).
func _cape(tr: Array, coated: bool) -> void:
	var m := _cloth("cape_color")
	var sim := _sim(h.torso)
	var top := tu(0.6)
	var rt := _at(tr, top)
	# (clear of the back and only the thighs pushing it: against the torso's
	# or hips' collider it twisted off to one side)
	# (hung from the shoulders out past the deepest part of the back, which is
	# lower down than the shoulders: from the shoulder ring it cut into the back)
	var back := 0.0
	for r in tr:
		# (a ring's own profile can bulge past its nominal depth at the back)
		var prof: PackedVector2Array = r[5] if (r as Array).size() > 5 and r[5] is PackedVector2Array else P_BODY()
		var ky := 1.0
		for p in prof:
			ky = maxf(ky, p.y)
		back = maxf(back, float(r[3]) + float(r[2]) * ky)
	var g := 0.04 + (0.03 if coated else 0.0)
	var zb := back + g
	var hw := float(rt[1]) + 0.05
	var y1 := -0.02 - 0.42 * Ls * 0.9
	var chain := PackedVector3Array([Vector3(0, top, zb), Vector3(0, tu(0.42), zb + 0.01), Vector3(0, 0.0, zb + 0.03), Vector3(0, y1, zb + 0.07)])
	var bones := sim.add_chain(chain, 0.2, 0.08, 1.0, ["thigh_l", "thigh_r"])
	var rows := []
	for i in range(chain.size()):
		var p: Vector3 = chain[i]
		var w := hw * lerpf(1.0, 1.25, i / 3.0)
		rows.append(PackedVector3Array([p + Vector3(-w, 0, -0.02), p + Vector3(-w * 0.35, 0, 0.004), p + Vector3(w * 0.35, 0, 0.004), p + Vector3(w, 0, -0.02)]))
	sim.mb.add_strip_grid(m, Transform3D.IDENTITY, rows, bones, 3.0, Color.WHITE, Vector3(0, 0, -0.3))
	# the clasp at the collar
	var mb := MeshBuilder.new()
	for s in [-1.0, 1.0]:
		mb.add_box(PSXMat.flat(Color(0.88, 0.72, 0.3)), Transform3D(Basis(), Vector3(s * float(rt[1]) * 0.75, top, float(rt[3]))), Vector3(0.025, 0.025, 0.02), 3.0)
	_mesh(h.torso, mb)


func _accessories() -> void:
	var mb := MeshBuilder.new()
	var hmb := MeshBuilder.new()
	var gold := PSXMat.flat(Color(0.88, 0.72, 0.3))
	var tr := _torso_rings()
	var coated := str(lk.get("coat", "none")) != "none"
	if lk.get("scarf", false):
		var m := _cloth("scarf_color")
		# (outside a coat's collar, which it used to cut through)
		var g := 0.022 if coated else 0.0
		mb.add_loft(m, Transform3D.IDENTITY, [[tu(0.59), 0.1 + g, 0.092 + g, 0.012], [tu(0.65), 0.088 + g, 0.084 + g, 0.012], [tu(0.65) + 0.04, 0.07 + g * 0.5, 0.068 + g * 0.5, 0.012]], MeshBuilder.profile_oct(0.5), 3.0, Color.WHITE, false, false, true, false, true)
		var r := _at(tr, tu(0.5))
		mb.add_tri(m, Vector3(-0.08, tu(0.62), -0.085 - g), Vector3(0.08, tu(0.62), -0.085 - g), Vector3(0.0, tu(0.45), _front_z(r) - 0.02 - g),
			Vector3.FORWARD, Vector3.FORWARD, Vector3.FORWARD, Vector2(0, 0), Vector2(1, 0), Vector2(0.5, 1), Color.WHITE, Vector3.FORWARD)
	if lk.get("log_pose", false):
		# over the sleeve (or a coat's turned-back cuff)
		var L := limb * (1.0 + (sh - 1.0) * 0.4)
		var long := str(lk.get("sleeves", "long")) == "long" and str(lk.get("top", "shirt")) != "bare"
		var band := (0.09 if coated else (0.056 if long else 0.05)) * L
		LogPose.attach(h.fore_l, -0.23 * A + 0.05, band)
	if lk.get("pouch", false):
		var r2 := _at(tr, 0.02)
		if coated:
			# on the belt in the coat's open front (at the hip it poked through the coat)
			mb.add_box(_leather("belt_color"), Transform3D(Basis(Vector3.UP, -0.25), Vector3(float(r2[1]) * 0.42, -0.04, _front_z(r2) - 0.035)), Vector3(0.07, 0.08, 0.04), 3.0, Color.WHITE, false)
		else:
			mb.add_box(_leather("belt_color"), Transform3D(Basis(Vector3.UP, -0.5), Vector3(float(r2[1]) * 0.8, -0.04, -float(r2[2]) * 0.6)), Vector3(0.08, 0.09, 0.05), 3.0, Color.WHITE, false)
	if lk.get("earring", false):
		var re := _at(head_rings, 0.13 * yk)
		hmb.add_cylinder(gold, Transform3D(Basis(Vector3.FORWARD, PI / 2.0), Vector3(-float(re[1]) - 0.012, 0.12 * yk, 0.012)), 0.016, 0.016, 0.006, 6, 3.0, Color.WHITE, false, false)
	if lk.get("eyepatch", false):
		var band := _off(_clip(head_rings, 0.222 * yk, 0.24 * yk), 0.006, 0.0, true)
		hmb.add_loft(PSXMat.flat(Color(0.08, 0.06, 0.05)), Transform3D.IDENTITY, band, _hair_back_profile(), 3.0, Color.WHITE, false, false, false)
	if lk.get("bandolier", false):
		# a strap from the left shoulder to the right hip, cartridges along the front
		var strap := _leather("belt_color")
		var brass := PSXMat.flat(Color(0.82, 0.68, 0.32))
		var g := 0.03 if coated else 0.0
		var n := 7
		for i in range(n):
			var t := (i + 0.5) / n
			var y := lerpf(tu(0.6), 0.02, t)
			var r := _at(tr, y)
			var x := lerpf(-float(r[1]) * 0.55, float(r[1]) * 0.6, t)
			var z := _front_z(r) - 0.024 - g + absf(x) * 0.25
			var seg := (tu(0.6) - 0.02) / n * 1.25
			mb.add_box(strap, Transform3D(Basis(Vector3.BACK, -0.62), Vector3(x, y, z)), Vector3(0.045, seg, 0.01), 3.0)
			if i > 0 and i < n - 1:
				mb.add_box(brass, Transform3D(Basis(Vector3.BACK, -0.62), Vector3(x, y, z - 0.012)), Vector3(0.016, 0.03, 0.016), 3.0)
			var zb := float(r[3]) + float(r[2]) + 0.024 + g
			mb.add_box(strap, Transform3D(Basis(Vector3.BACK, 0.62), Vector3(-x, y, zb)), Vector3(0.045, seg, 0.01), 3.0)
	if lk.get("cape", false):
		_cape(tr, coated)
	if lk.get("pauldron", false):
		var pm := PSXMat.lit("metal", Color(0.85, 0.85, 0.9))
		var pmb := MeshBuilder.new()
		var k := limb * (1.0 + (sh - 1.0) * 0.4)
		pmb.add_loft(pm, Transform3D(Basis(Vector3.FORWARD, 0.3), Vector3(-0.01, 0.0, 0.0)),
			[[-0.09, 0.11 * k, 0.115 * k], [0.0, 0.105 * k, 0.11 * k], [0.05, 0.075 * k, 0.08 * k], [0.075, 0.02, 0.02]], MeshBuilder.profile_oct(0.5), 3.0, Color.WHITE, false, true)
		pmb.add_loft(_leather("belt_color"), Transform3D(Basis(Vector3.FORWARD, 0.3), Vector3(-0.01, 0.0, 0.0)),
			[[-0.1, 0.113 * k, 0.118 * k], [-0.085, 0.113 * k, 0.118 * k]], MeshBuilder.profile_oct(0.5), 3.0, Color.WHITE, false, false, true, false, true)
		_mesh(h.arm_l, pmb)
	_mesh(h.torso, mb)
	_mesh(h.head, hmb)
