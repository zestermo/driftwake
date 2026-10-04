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
	"shonen": {"head": 0.74, "leg": 1.13, "torso": 0.86, "neck": 0.9, "arm": 1.04, "sh": 1.15, "wa": 0.84,
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
	m_hair = _textured("hair", _col("hair_color"))
	_skeleton()
	_colliders()
	_legs()
	_pelvis()
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
	# shoulder joints sit a little inside the torso's edge so the arm tops
	# overlap the shoulders
	var sxr := (0.174 * sh + 0.026) if fem else (0.22 * sh + 0.032)
	h.arm_l = _node("ArmL", Vector3(-sxr, ty(0.53), 0), h.torso)
	h.arm_r = _node("ArmR", Vector3(sxr, ty(0.53), 0), h.torso)
	h.fore_l = _node("ForeL", Vector3(0, -0.3 * A, 0), h.arm_l)
	h.fore_r = _node("ForeR", Vector3(0, -0.3 * A, 0), h.arm_r)
	var wrist := -0.23 * A
	h.hand_l = _node("HandL", Vector3(0, wrist - 0.07 * Hk, -0.02), h.fore_l)
	h.hand_r = _node("HandR", Vector3(0, wrist - 0.07 * Hk, -0.02), h.fore_r)
	h.neck = _node("Neck", Vector3(0, ty(0.6), 0.012), h.torso)
	h.head = _node("Head", Vector3(0, ty(0.62) + 0.1 * float(st["neck"]), 0) - h.neck.position, h.neck)
	var hs := float(st["head"]) * (0.97 if fem else 1.0)
	h.head.scale = Vector3(hs, hs, hs)
	var waist := _torso_rings()[0][1] as float
	h.hip_socket = _node("HipSocket", Vector3(-waist - 0.07, ty(0.05), 0.02), h.torso)
	h.hip_socket.basis = Basis.looking_at(Vector3(-0.12, -0.9, 0.42).normalized(), Vector3.LEFT)


func _colliders() -> void:
	var thigh_r := (0.108 if fem else 0.1) * limb + 0.03
	colliders["thigh_l"] = {"node": h.leg_l, "a": Vector3(0, 0.02, 0), "b": Vector3(0, -0.42 * Ls, 0), "r": thigh_r}
	colliders["thigh_r"] = {"node": h.leg_r, "a": Vector3(0, 0.02, 0), "b": Vector3(0, -0.42 * Ls, 0), "r": thigh_r}
	colliders["shin_l"] = {"node": h.shin_l, "a": Vector3.ZERO, "b": Vector3(0, -0.4 * Ls, 0), "r": 0.075 * limb + 0.025}
	colliders["shin_r"] = {"node": h.shin_r, "a": Vector3.ZERO, "b": Vector3(0, -0.4 * Ls, 0), "r": 0.075 * limb + 0.025}
	colliders["hips"] = {"node": h.hips, "a": Vector3(0, 0.05, 0), "b": Vector3(0, -0.08, 0), "r": _hips_hw() * 0.82}
	colliders["torso"] = {"node": h.torso, "a": Vector3(0, ty(0.12), 0.01), "b": Vector3(0, ty(0.5), 0.01), "r": 0.13 * de + 0.025}
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
			[0.0, 0.128 * w, 0.098 * de, 0.0, 0.0, B],
			[0.11, 0.125 * w, 0.096 * de, 0.0, 0.0, B],
			[0.22, 0.14 * ch, 0.104 * de, -0.004, 0.0, B],
			[0.31, 0.158 * ch, 0.126 * de, -0.016, 0.0, P_BUST()],
			[0.385, 0.165 * ch, 0.128 * de, -0.016, 0.0, P_BUST()],
			[0.45, 0.178 * sh, 0.11 * de, -0.004, 0.0, B],
			[0.5, 0.198 * sh, 0.106 * de, 0.0, 0.0, B],
			[0.56, 0.172 * sh, 0.098 * de, 0.004, 0.0, B],
			[0.615, 0.118 * sh, 0.086 * de, 0.01, 0.0, B],
			[0.655, 0.064, 0.06, 0.01, 0.0, B]]
	else:
		r = [
			[0.0, 0.155 * wa, 0.108 * de, 0.0, 0.0, B],
			[0.13, 0.162 * wa, 0.114 * de, -0.03 * maxf(bf["wa"] as float - 1.0, 0.0), 0.0, B],
			[0.27, 0.2 * ch, 0.128 * de, -0.004, 0.0, B],
			[0.39, 0.222 * ch, 0.136 * de, -0.008, 0.0, P_PEC()],
			[0.49, 0.25 * sh, 0.128 * de, 0.0, 0.0, B],
			[0.56, 0.215 * sh, 0.118 * de, 0.004, 0.0, B],
			[0.615, 0.14 * sh, 0.1 * de, 0.01, 0.0, B],
			[0.655, 0.075, 0.068, 0.01, 0.0, B]]
	# slimmer through the chest and shoulders, a touch at the waist (depth kept)
	for i in range(r.size()):
		var ring: Array = r[i]
		ring[0] = ty(ring[0])
		ring[1] = float(ring[1]) * (0.95 if i < 2 else 0.88)
	return r


func _hips_hw() -> float:
	var base := (0.198 if fem else 0.175) * hp * (1.0 + (wa - 1.0) * 0.5)
	# wide enough that the thighs run up into the pelvis instead of beside it
	return maxf(base, float(st["leg_gap"]) + (0.088 if fem else 0.082) * limb)


func _hips_hd() -> float:
	return (0.122 if fem else 0.118) * de


## Thigh rings in the leg joint's space. The top is a closed, rounded dome
## buried in the pelvis (the hip joint sits inside the hips), and the bottom
## runs a little past the knee so a bent knee never opens a gap.
func _thigh_rings(side: float) -> Array:
	var L := limb
	var inx := -side * 0.015
	if fem:
		return [[0.12, 0.05 * L, 0.055 * L, 0.0, inx], [0.07, 0.092 * L, 0.096 * L, 0.0, inx * 0.6], [-0.05 * Ls, 0.104 * L, 0.108 * L, 0.005],
			[-0.24 * Ls, 0.084 * L, 0.09 * L, 0.002], [-0.42 * Ls, 0.06 * L, 0.07 * L], [-0.45 * Ls, 0.05 * L, 0.058 * L, -0.004]]
	return [[0.12, 0.05 * L, 0.055 * L, 0.0, inx], [0.07, 0.085 * L, 0.09 * L, 0.0, inx * 0.6], [-0.05 * Ls, 0.096 * L, 0.104 * L, 0.004],
		[-0.24 * Ls, 0.085 * L, 0.094 * L, 0.002], [-0.42 * Ls, 0.066 * L, 0.076 * L], [-0.45 * Ls, 0.056 * L, 0.064 * L, -0.004]]


func _shin_rings() -> Array:
	var L := limb
	return [[0.035, 0.054 * L, 0.062 * L, 0.004], [-0.03 * Ls, 0.064 * L, 0.076 * L, 0.01], [-0.1 * Ls, 0.066 * L, 0.08 * L, 0.014],
		[-0.26 * Ls, 0.05 * L, 0.058 * L, 0.004], [-0.4 * Ls, 0.042 * L, 0.048 * L]]


func _legs() -> void:
	var legs := str(lk.get("legs", "trousers"))
	var feet := str(lk.get("feet", "boots"))
	var m_legs := _cloth("legs_color")
	var m_stock := _textured("fabric", Color(0.88, 0.86, 0.78)) if legs == "breeches" else m_skin
	var prof := MeshBuilder.profile_oct(0.5)
	for side in [-1, 1]:
		var leg: Node3D = h.leg_l if side < 0 else h.leg_r
		var shin: Node3D = h.shin_l if side < 0 else h.shin_r
		var th := _thigh_rings(float(side))
		var tmb := MeshBuilder.new()
		match legs:
			"shorts":
				tmb.add_loft(m_legs, Transform3D.IDENTITY, _off(_clip(th, -0.2 * Ls, 1.0), 0.008), prof, 3.0, Color.WHITE, false, true)
				tmb.add_loft(m_skin, Transform3D.IDENTITY, _clip(th, -1.0, -0.19 * Ls), prof, 3.0)
				tmb.add_loft(m_legs, Transform3D.IDENTITY, _off(_clip(th, -0.22 * Ls, -0.17 * Ls), 0.014), prof, 3.0)
			"skirt":
				tmb.add_loft(m_skin, Transform3D.IDENTITY, th, prof, 3.0, Color.WHITE, false, true)
			_:
				tmb.add_loft(m_legs, Transform3D.IDENTITY, _off(th, 0.006), prof, 3.0, Color.WHITE, false, true)
		_mesh(leg, tmb)
		var sr := _shin_rings()
		var smb := MeshBuilder.new()
		match legs:
			"trousers":
				var hem := _off(sr, 0.008)
				hem[hem.size() - 1][1] += 0.012
				hem[hem.size() - 1][2] += 0.012
				smb.add_loft(m_legs, Transform3D.IDENTITY, hem, prof, 3.0, Color.WHITE, false, true)
			"breeches":
				smb.add_loft(m_legs, Transform3D.IDENTITY, _off(_clip(sr, -0.09 * Ls, 1.0), 0.01), prof, 3.0, Color.WHITE, false, true)
				smb.add_loft(m_stock, Transform3D.IDENTITY, _off(_clip(sr, -1.0, -0.08 * Ls), 0.002), prof, 3.0)
				smb.add_loft(m_legs, Transform3D.IDENTITY, _off(_clip(sr, -0.11 * Ls, -0.06 * Ls), 0.016), prof, 3.0)
			_:
				smb.add_loft(m_skin, Transform3D.IDENTITY, sr, prof, 3.0, Color.WHITE, false, true)
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
			mb.add_loft(m_feet, Transform3D.IDENTITY, _off(_clip(sr, sole + 0.04, -0.1 * Ls), 0.016), sp, 3.0)
			var cuff := _off(_clip(sr, -0.13 * Ls, -0.02 * Ls), 0.03)
			mb.add_loft(_textured("leather", _col("feet_color").lightened(0.12)), Transform3D.IDENTITY, cuff, sp, 3.0, Color.WHITE, false, false, true, false, true)
		_:  # boots
			mb.add_loft(m_feet, fx, foot, fprof, 3.0, Color.WHITE, true, true)
			mb.add_loft(m_feet, Transform3D.IDENTITY, _off(_clip(sr, sole + 0.04, sole + 0.19 * F), 0.016), sp, 3.0, Color.WHITE, false, true)


func _pelvis() -> void:
	var m := _cloth("legs_color")
	var hw := _hips_hw()
	var hd := _hips_hd()
	var rings: Array
	if fem:
		var w := bf["wa"] as float * float(st["wa"]) * 1.02
		rings = [[0.06, 0.13 * w * 0.95, 0.098 * de], [0.0, hw * 0.86, 0.11 * de], [-0.06, hw, hd], [-0.13, hw * 0.95, hd * 0.94],
			[-0.175, hw * 0.66, hd * 0.76], [-0.2, hw * 0.26, hd * 0.34]]
	else:
		rings = [[0.06, 0.158 * wa * 0.95, 0.108 * de], [-0.02, lerpf(0.158 * wa * 0.95, hw, 0.7), hd * 0.98], [-0.08, hw, hd], [-0.13, hw * 0.94, hd * 0.93],
			[-0.17, hw * 0.64, hd * 0.72], [-0.195, hw * 0.26, hd * 0.32]]
	var mb := MeshBuilder.new()
	mb.add_loft(m, Transform3D.IDENTITY, rings, MeshBuilder.profile_oct(0.55), 3.0, Color.WHITE, true, false)
	_mesh(h.hips, mb)


func _torso() -> void:
	var top := str(lk.get("top", "shirt"))
	var m_top := m_skin if top == "bare" else _cloth("top_color")
	var tr := _torso_rings()
	var mb := MeshBuilder.new()
	mb.add_loft(m_top, Transform3D.IDENTITY, tr, P_BODY(), 3.0, Color.WHITE, false, true)
	if top == "tunic":
		var hw := _hips_hw()
		var hem := [_at(_off(tr, 0.01), ty(0.1)), [0.0, (tr[0][1] as float) + 0.014, (tr[0][2] as float) + 0.014], [-0.22, hw + 0.04, _hips_hd() + 0.035]]
		hem = _off(hem, 0.0, 0.0, true)
		mb.add_loft(m_top, Transform3D.IDENTITY, hem, MeshBuilder.profile_oct(0.55), 3.0, Color.WHITE, false, false, true, false, true)
	if top != "bare":
		var r := _at(tr, ty(0.6))
		var cz := _front_z(r) - 0.004
		var mc := _textured("fabric", _col("top_color").lightened(0.08))
		for s in [-1.0, 1.0]:
			mb.add_quad(mc, Vector3(0.0, ty(0.57), cz - 0.012), Vector3(s * 0.075, ty(0.665), cz + 0.012),
				Vector3(s * 0.1, ty(0.62), cz), Vector3(s * 0.025, ty(0.55), cz - 0.02),
				Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1))
		mb.add_tri(m_skin, Vector3(-0.045, ty(0.64), cz + 0.002), Vector3(0.045, ty(0.64), cz + 0.002), Vector3(0, ty(0.575), cz - 0.018),
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


func _arms() -> void:
	var top := str(lk.get("top", "shirt"))
	var sleeves := str(lk.get("sleeves", "long"))
	if top == "bare":
		sleeves = "none"
	var coated := str(lk.get("coat", "none")) != "none"
	var m_top := _cloth("top_color")
	var gloves: bool = lk.get("gloves", false)
	var m_hand := _leather("gloves_color") if gloves else m_skin
	var L := limb * (1.0 + (sh - 1.0) * 0.4)
	var up := [[0.058, 0.022 * L, 0.026 * L], [0.044, 0.046 * L, 0.052 * L], [0.016, 0.064 * L, 0.07 * L], [-0.06 * A, 0.071 * L, 0.077 * L],
		[-0.17 * A, 0.063 * L, 0.069 * L], [-0.3 * A, 0.055 * L, 0.06 * L]]
	var fo := [[0.02, 0.056 * L, 0.06 * L], [-0.08 * A, 0.06 * L, 0.064 * L, 0.004], [-0.23 * A, 0.043 * L, 0.047 * L]]
	var prof := MeshBuilder.profile_oct(0.5)
	var wrist := -0.23 * A
	for side in [-1, 1]:
		var arm: Node3D = h.arm_l if side < 0 else h.arm_r
		var fore: Node3D = h.fore_l if side < 0 else h.fore_r
		var amb := MeshBuilder.new()
		var fmb := MeshBuilder.new()
		match "coat" if coated else sleeves:
			"coat":
				pass  # the coat's own sleeves cover the arms
			"long":
				amb.add_loft(m_top, Transform3D.IDENTITY, _off(up, 0.006), prof, 3.0, Color.WHITE, false, true)
				var f2 := _off(fo, 0.006)
				if top == "blouse":
					f2 = [[0.02, 0.066 * L, 0.07 * L], [-0.1 * A, 0.08 * L, 0.084 * L, 0.006], [-0.19 * A, 0.062 * L, 0.066 * L], [wrist + 0.02, 0.05 * L, 0.054 * L]]
					fmb.add_loft(m_top, Transform3D.IDENTITY, [[wrist + 0.03, 0.05 * L, 0.054 * L], [wrist - 0.005, 0.052 * L, 0.056 * L]], prof, 3.0)
				fmb.add_loft(m_top, Transform3D.IDENTITY, f2, prof, 3.0, Color.WHITE, false, true)
			"short":
				amb.add_loft(m_top, Transform3D.IDENTITY, _off(_clip(up, -0.16 * A, 1.0), 0.01), prof, 3.0, Color.WHITE, false, true)
				amb.add_loft(m_skin, Transform3D.IDENTITY, _clip(up, -1.0, -0.15 * A), prof, 3.0)
				fmb.add_loft(m_skin, Transform3D.IDENTITY, fo, prof, 3.0, Color.WHITE, false, true)
			_:
				amb.add_loft(m_skin, Transform3D.IDENTITY, up, prof, 3.0, Color.WHITE, false, true)
				fmb.add_loft(m_skin, Transform3D.IDENTITY, fo, prof, 3.0, Color.WHITE, false, true)
		# mitten hand: wide front-to-back, thumb toward the front
		var k := Hk * limb
		var hand := [[wrist + 0.015, 0.03 * k, 0.04 * k], [wrist - 0.02 * Hk, 0.028 * k, 0.056 * k, -0.005], [wrist - 0.08 * Hk, 0.026 * k, 0.057 * k, -0.005],
			[wrist - 0.115 * Hk, 0.02 * k, 0.04 * k, -0.004]]
		fmb.add_loft(m_hand, Transform3D.IDENTITY, hand, MeshBuilder.profile_oct(0.6), 3.0, Color.WHITE, true, true)
		var inward := -float(side)
		var tx := Transform3D(Basis(Vector3.FORWARD, inward * 0.5) * Basis(Vector3.RIGHT, 0.35), Vector3(inward * 0.012 * k, wrist - 0.005, -0.05 * k))
		fmb.add_loft(m_hand, tx, [[0.0, 0.016 * k, 0.018 * k], [-0.05 * k, 0.014 * k, 0.016 * k], [-0.07 * k, 0.008 * k, 0.01 * k]], MeshBuilder.profile_oct(0.6), 3.0, Color.WHITE, true, true)
		if gloves:
			fmb.add_loft(m_hand, Transform3D.IDENTITY, [[wrist + 0.06, 0.056 * L, 0.06 * L], [wrist + 0.01, 0.05 * L, 0.054 * L]], prof, 3.0, Color.WHITE, false, false, true, false, true)
		_mesh(arm, amb)
		_mesh(fore, fmb)


# --------------------------------------------------------------------------
# head, face, hair, hats
# --------------------------------------------------------------------------
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
		# short cranium with a flattish, rounded-off top (not a ball)
		[0.235, (0.162 if fem else 0.164) * wk, 0.156, 0.0, 0.0, R],
		[0.268, (0.16 if fem else 0.162) * wk, 0.158, 0.004, 0.0, R],
		[0.294, 0.15 * wk, 0.152, 0.008, 0.0, R],
		[0.316, 0.126 * wk, 0.13, 0.01, 0.0, R],
		[0.333, 0.088 * wk, 0.092, 0.011, 0.0, R],
		[0.343, 0.042 * wk, 0.046, 0.011, 0.0, R],
		[0.346, 0.012 * wk, 0.014, 0.011, 0.0, R]]
	for r in head_rings:
		r[0] = float(r[0]) * yk
	var mb := MeshBuilder.new()
	var face := FacePainter.material(lk, float(st["eye"]))
	mb.add_loft(m_skin, Transform3D.IDENTITY, head_rings, R, 3.0, Color.WHITE, true, true, true, false, false,
		PackedInt32Array(), face, Callable(FacePainter, "uv").bind(yk), Callable(FacePainter, "pick").bind(yk))
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
	_facial_hair(hmb)
	_hat(hmb)
	_mesh(h.head, hmb)


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
	return style in ["long", "braids"]


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
	if style == "crop":
		off = 0.009
	elif style == "wild":
		off = 0.024
	hair_off = off
	var line: Array = HAIRLINES.get(style, HAIRLINES["ponytail"] if style == "bun" else HAIRLINES["short"])
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
			var root := Vector3(0, 0.275 * yk, 0.165)
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
			mb.add_blob(m_hair, Transform3D(Basis(), Vector3(0, 0.3 * yk, 0.15)), Vector3(0.08, 0.075, 0.075), rng, 0.08, 4, 7, 3.0)
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
	var crowned := hat in ["none", "bandana"]
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
				_spike(mb, 170.0, 0.33, Vector3(0.15, 1.0, 0.7), 0.08, 0.026)
				_spike(mb, 200.0, 0.325, Vector3(-0.3, 1.0, 0.8), 0.065, 0.022)
				_spike(mb, 10.0, 0.335, Vector3(0.2, 1.0, -0.25), 0.06, 0.02)
		"long", "braids":
			# centre-parted bangs sweeping outward, with face-framing locks
			for s in [-1.0, 1.0]:
				for i in range(4):
					var a: float = s * (6.0 + i * 12.0)
					_clump(mb, a, 0.29, j.call(lerpf(0.08, 0.06, i / 3.0)), 0.05, 0.012, s * 10.0, 0.004)
				_clump(mb, s * 54.0, 0.262, j.call(0.2), 0.05, 0.013, s * 6.0, 0.008, 0.004)
				_clump(mb, s * 66.0, 0.25, j.call(0.24), 0.05, 0.013, s * 4.0, 0.01, 0.008)
			if crowned:
				_spike(mb, 185.0, 0.335, Vector3(0.1, 1.0, 0.6), 0.06, 0.02)
		"ponytail", "bun":
			# swept bangs, long side strands framing the face, hair pulled back
			for i in range(6):
				var t := float(i) / 5.0
				var a := lerpf(-44.0, 40.0, t)
				_clump(mb, a, 0.29, j.call(lerpf(0.085, 0.055, t)), 0.05, 0.012, -12.0, 0.006)
			for s in [-1.0, 1.0]:
				_clump(mb, s * 62.0, 0.255, j.call(0.15), 0.04, 0.012, s * 5.0, 0.008)
			for i in range(5):
				_clump(mb, 140.0 + i * 20.0, 0.16, j.call(0.03), 0.04, 0.01, 0.0, 0.004)


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
			mb.add_loft(m_hat, Transform3D.IDENTITY, [[y0, rw, rd], [y0 + 0.06, rw * 0.98, rd * 0.98], [y0 + 0.1, rw * 0.7, rd * 0.72]], crown_prof, 3.0, Color.WHITE, false, true)
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
			mb.add_loft(m_hat, Transform3D.IDENTITY, [[y0, rw, rd], [y0 + 0.06, rw * 1.04, rd * 1.05, -0.01], [y0 + 0.1, rw * 0.92, rd * 0.97, -0.012], [y0 + 0.115, rw * 0.58, rd * 0.62, -0.01]],
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
		"hood":
			var hood := _off(head_rings, 0.04, 0.0, true)
			hood.insert(0, [-0.08, 0.13, 0.13, 0.03, 0.0])
			hood.append([0.385 * yk, 0.04, 0.06, 0.03, 0.0])
			mb.add_loft(m_hat, Transform3D.IDENTITY, hood, open_front(0.6), 3.0, Color.WHITE, false, false, false)


# --------------------------------------------------------------------------
# outer layers
# --------------------------------------------------------------------------
func _clothes() -> void:
	var tr := _torso_rings()
	var prof := MeshBuilder.profile_oct(0.55)
	var mb := MeshBuilder.new()
	match str(lk.get("vest", "none")):
		"vest":
			mb.add_loft(_cloth("vest_color"), Transform3D.IDENTITY, _off(_clip(tr, 0.0, ty(0.57)), 0.016, 0.0, true), open_body(0.3), 3.0, Color.WHITE, false, false, false)
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
	var shell := _off(_clip(tr, 0.0, ty(0.62)), 0.03 + (0.012 if fem else 0.0), 0.0, true)
	if coat == "jacket":
		shell.insert(0, [-0.14, _hips_hw() + 0.03, _hips_hd() + 0.03, 0.0, 0.0])
	mb.add_loft(m_coat, Transform3D.IDENTITY, shell, open_body(0.3), 3.0, Color.WHITE, false, false, false)
	mb.add_loft(m_coat, Transform3D.IDENTITY, [[ty(0.6), 0.105, 0.095, 0.012], [ty(0.6) + 0.11, 0.115, 0.105, 0.02]], open_front(0.55), 3.0, Color.WHITE, false, false, false)
	var lap := m_trim if captain else _textured("fabric", _col("coat_color").darkened(0.12))
	for s in [-1.0, 1.0]:
		var rt := _at(tr, ty(0.56))
		var rb := _at(tr, ty(0.3))
		var zt := _front_z(rt) - 0.028
		var zb := _front_z(rb) - 0.03
		mb.add_quad(lap, Vector3(s * 0.07, ty(0.6), zt + 0.01), Vector3(s * 0.16, ty(0.55), zt + 0.02),
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
			mb.add_box(m_trim, Transform3D(Basis(Vector3.FORWARD, s * 0.25), Vector3(ex, ty(0.6), 0.0)), Vector3(0.11, 0.02, 0.12), 3.0, Color.WHITE, false)
			mb.add_box(m_trim, Transform3D(Basis(), Vector3(ex + s * 0.05, ty(0.6) - 0.03, 0.0)), Vector3(0.012, 0.05, 0.11), 3.0, Color.WHITE, false)
	# sleeves with turned-back cuffs
	var L := limb * (1.0 + (sh - 1.0) * 0.4)
	var up := [[0.07, 0.03 * L, 0.034 * L], [0.055, 0.062 * L, 0.068 * L], [0.02, 0.082 * L, 0.088 * L], [-0.06 * A, 0.09 * L, 0.096 * L], [-0.3 * A, 0.075 * L, 0.08 * L]]
	var wrist := -0.23 * A
	var fo := [[0.02, 0.076 * L, 0.08 * L], [wrist + 0.02, 0.064 * L, 0.068 * L]]
	var cuff := [[wrist + 0.11, 0.08 * L, 0.084 * L], [wrist + 0.015, 0.082 * L, 0.086 * L]]
	for side in [-1, 1]:
		var amb := MeshBuilder.new()
		amb.add_loft(m_coat, Transform3D.IDENTITY, up, MeshBuilder.profile_oct(0.5), 3.0, Color.WHITE, false, true)
		_mesh(h.arm_l if side < 0 else h.arm_r, amb)
		var fmb := MeshBuilder.new()
		fmb.add_loft(m_coat, Transform3D.IDENTITY, fo, MeshBuilder.profile_oct(0.5), 3.0, Color.WHITE, false, true)
		fmb.add_loft(m_trim if captain else lap, Transform3D.IDENTITY, cuff, MeshBuilder.profile_oct(0.5), 3.0, Color.WHITE, false, false, true, false, true)
		_mesh(h.fore_l if side < 0 else h.fore_r, fmb)
	if coat in ["longcoat", "captain"]:
		_cloth_sectors(m_coat, m_trim if captain else null, [[32.0, 100.0], [100.0, 180.0], [180.0, 260.0], [260.0, 328.0]],
			0.04, -0.02 - 0.42 * Ls - 0.08, [0.03, 0.05, 0.08, 0.11], 0.14)


func _skirt(m: Material) -> void:
	var secs := []
	for i in range(6):
		secs.append([i * 60.0, (i + 1) * 60.0])
	_cloth_sectors(m, null, secs, 0.07, -0.02 - 0.42 * Ls + 0.04, [0.02, 0.04, 0.08, 0.12], 0.2)


## Hanging cloth around the hips (coat tails, skirts) split into sectors, each
## a physics chain so it swings and is pushed aside by the legs.
## angles: [[a0, a1], ...] in degrees (0 = front, 90 = right). Rows run from
## y_top down to y_bot with outward `flare` per row.
func _cloth_sectors(m: Material, m_trim: Material, sectors: Array, y_top: float, y_bot: float, flare: Array, stiff: float) -> void:
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
				aw = (_torso_rings()[0][1] as float) + 0.035
				ad = (_torso_rings()[0][2] as float) + 0.035
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
	if belt in ["belt", "belt_sash"]:
		var by := ty(0.01) if belt == "belt" else -0.035
		var band := _off(_clip(tr, maxf(by, 0.0), by + 0.06), 0.017, 0.0, true)
		if by < 0.0:
			band = [[by, (tr[0][1] as float) + 0.02, (tr[0][2] as float) + 0.02], [by + 0.055, (tr[0][1] as float) + 0.018, (tr[0][2] as float) + 0.018]]
		mb.add_loft(_leather("belt_color"), Transform3D.IDENTITY, band, prof, 3.0, Color.WHITE, false, false, true, false, true)
		var r := _at(tr, maxf(by, 0.0))
		mb.add_box(PSXMat.flat(Color(0.82, 0.72, 0.38)), Transform3D(Basis(), Vector3(0, by + 0.03, _front_z(r) - 0.024)), Vector3(0.05, 0.045, 0.012), 3.0)
	if belt in ["sash", "belt_sash"]:
		var sy := ty(0.04) if belt == "belt_sash" else 0.0
		var band2 := _off(_clip(tr, sy, sy + 0.1), 0.02, 0.0, true)
		var m_sash := _cloth("sash_color")
		mb.add_loft(m_sash, Transform3D.IDENTITY, band2, prof, 3.0, Color.WHITE, false, false, true, false, true)
		var r2 := _at(tr, sy + 0.05)
		var kx := -float(r2[1]) * 0.75
		var kz := float(r2[3]) - float(r2[2]) * 0.75 - 0.02
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
	var zt := _front_z(rt) - 0.03
	var zb := _front_z(rb) - 0.03
	mb.add_quad(m_ap, Vector3(-0.12, ty(0.38), zt), Vector3(0.12, ty(0.38), zt), Vector3(0.15, 0.0, zb), Vector3(-0.15, 0.0, zb),
		Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1), Color.WHITE, Vector3.FORWARD)
	var sim := _sim(h.hips)
	var z0 := -_hips_hd() - 0.035
	var y1 := -0.02 - 0.42 * Ls * 0.95
	var chain := PackedVector3Array([Vector3(0, 0.0, z0), Vector3(0, y1 * 0.5, z0 - 0.02), Vector3(0, y1, z0 - 0.04)])
	var bones := sim.add_chain(chain, 0.16, 0.06, 1.0, ["thigh_l", "thigh_r", "hips"])
	var rows := []
	for p in chain:
		rows.append(PackedVector3Array([p + Vector3(-0.17, 0, 0.01), p + Vector3(-0.06, 0, -0.004), p + Vector3(0.06, 0, -0.004), p + Vector3(0.17, 0, 0.01)]))
	sim.mb.add_strip_grid(m_ap, Transform3D.IDENTITY, rows, bones, 3.0, Color.WHITE, Vector3(0, 0, 0.3))


func _accessories() -> void:
	var mb := MeshBuilder.new()
	var hmb := MeshBuilder.new()
	var gold := PSXMat.flat(Color(0.88, 0.72, 0.3))
	var tr := _torso_rings()
	if lk.get("scarf", false):
		var m := _cloth("scarf_color")
		mb.add_loft(m, Transform3D.IDENTITY, [[ty(0.59), 0.1, 0.092, 0.012], [ty(0.65), 0.088, 0.084, 0.012], [ty(0.65) + 0.04, 0.07, 0.068, 0.012]], MeshBuilder.profile_oct(0.5), 3.0, Color.WHITE, false, false, true, false, true)
		var r := _at(tr, ty(0.5))
		mb.add_tri(m, Vector3(-0.08, ty(0.62), -0.085), Vector3(0.08, ty(0.62), -0.085), Vector3(0.0, ty(0.45), _front_z(r) - 0.02),
			Vector3.FORWARD, Vector3.FORWARD, Vector3.FORWARD, Vector2(0, 0), Vector2(1, 0), Vector2(0.5, 1), Color.WHITE, Vector3.FORWARD)
	if lk.get("pouch", false):
		var r2 := _at(tr, 0.02)
		mb.add_box(_leather("belt_color"), Transform3D(Basis(Vector3.UP, -0.5), Vector3(float(r2[1]) * 0.8, -0.04, -float(r2[2]) * 0.6)), Vector3(0.08, 0.09, 0.05), 3.0, Color.WHITE, false)
	if lk.get("earring", false):
		var re := _at(head_rings, 0.13 * yk)
		hmb.add_cylinder(gold, Transform3D(Basis(Vector3.FORWARD, PI / 2.0), Vector3(-float(re[1]) - 0.012, 0.12 * yk, 0.012)), 0.016, 0.016, 0.006, 6, 3.0, Color.WHITE, false, false)
	if lk.get("eyepatch", false):
		var band := _off(_clip(head_rings, 0.222 * yk, 0.24 * yk), 0.006, 0.0, true)
		hmb.add_loft(PSXMat.flat(Color(0.08, 0.06, 0.05)), Transform3D.IDENTITY, band, _hair_back_profile(), 3.0, Color.WHITE, false, false, false)
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
