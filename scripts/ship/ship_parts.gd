class_name ShipParts
extends Node3D
## What Tackett's upgrade lines (ShipLines) put on the sloop, level by level:
## built from the kit on every screen (Ship.apply_kit), ship-local (HullBuilder:
## stern +Z, bow -Z). The fixed parts are one mesh per range (UpgradeMesh: the
## readable pieces; UpgradeFine: rivets, shot and pegs, close up only), the
## moving ones nodes of their own (the jib and studding sails furl with the
## main sail, the rudder turns with the wheel, the guns' fittings on each gun).

## Main sail scale (x, y) per sails level: 1 and 3 bolt on more canvas, 5 the old "larger sail".
const RIG_SCALE := [Vector2(1.0, 1.0), Vector2(1.04, 1.03), Vector2(1.04, 1.03), Vector2(1.1, 1.07), Vector2(1.1, 1.07), Vector2(1.18, 1.12)]
## The rudder, hung on the stern post (ship-local), and how far it swings at full helm.
const RUDDER_AT := Vector3(0, -0.2, HullBuilder.QD_BACK + 0.12)
const RUDDER_SWING := 0.45

var ship: Ship
var levels: Dictionary = {}
var jib: Node3D
var rudder_node: Node3D
var _mesh: MeshInstance3D
var _fine: MeshInstance3D
var _nodes: Array = []
var _sail_mat: Material
var _m: Dictionary = {}


func setup(s: Ship) -> void:
	ship = s
	name = "Upgrades"
	_m = {
		"iron": PSXMat.lit("metal", Color(0.55, 0.55, 0.6)),
		"dark_iron": PSXMat.lit("metal", Color(0.28, 0.28, 0.3)),
		"brass": PSXMat.lit("metal", Color(1.0, 0.78, 0.4)),
		"oak": PSXMat.lit("planks_dark", Color(0.78, 0.66, 0.52)),
		"trim": PSXMat.lit("planks", Color(0.85, 0.65, 0.35)),
		"wale": PSXMat.lit("planks", Color(1.15, 0.88, 0.45)),
		"gilt": PSXMat.lit("", Color(1.0, 0.76, 0.28)),
		"rope": PSXMat.lit("rope"),
		"pennant": PSXMat.lit("cloth_red", Color(1.0, 0.85, 0.8)),
		"glass": PSXMat.glow(Color(1.0, 0.76, 0.32), 2.6),
		"copper": PSXMat.lit("", Color(0.92, 0.48, 0.22)),
		"canvas": PSXMat.lit("canvas", Color(0.92, 0.88, 0.76)),
		"roof": PSXMat.lit("planks_dark", Color(0.7, 0.5, 0.38)),
		"leaves": PSXMat.lit("leaves", Color(0.55, 0.85, 0.45)),
		"soil": PSXMat.lit("dirt", Color(0.6, 0.5, 0.42)),
		"fruit": PSXMat.lit("", Color(1.0, 0.52, 0.1)),
		"linen": PSXMat.lit("fabric", Color(0.9, 0.86, 0.75)),
		"blanket": PSXMat.lit("fabric", Color(0.2, 0.3, 0.6)),
		"lamp_red": PSXMat.glow(Color(1.0, 0.36, 0.24), 2.6),
		"lamp_gold": PSXMat.glow(Color(1.0, 0.76, 0.32), 2.6),
		"lamp_white": PSXMat.glow(Color(1.0, 0.94, 0.82), 2.4),
	}


## Every screen: the kit's levels on her (rebuilt only when a level changed).
## `sail_mat`: her painted canvas, for the extra sails.
func apply(kit: Dictionary, sail_mat: Material) -> void:
	_sail_mat = sail_mat
	var now := {}
	for id in ShipLines.LINES.keys():
		now[id] = ShipLines.level(kit, id)
	if now != levels:
		levels = now
		_rebuild()
	for n in _nodes:
		if is_instance_valid(n) and n.has_meta("sail"):
			(n as MeshInstance3D).material_override = _sail_mat
	ship.rig_scale = RIG_SCALE[lv("sails")]
	ship._show_sail(0.0)
	# (the nest's hood stands where the flag flew: it goes up the staff)
	ship._flag_node.position.y = 0.75 if lv("nest") >= 1 else 0.0
	for c in ship.cannons:
		(c as ShipCannon).fit(maxi(lv("guns"), [0, 0, 3, 5][lv("chaser")]) if c.name == "CannonBow" else lv("guns"))


func lv(id: String) -> int:
	return int(levels.get(id, 0))


## How many pieces the line's levels have put on her (tests: every level shows).
func pieces(id: String) -> int:
	return int(_counts.get(id, 0))


var _counts: Dictionary = {}


func _rebuild() -> void:
	for n in _nodes:
		if is_instance_valid(n):
			n.free()
	_nodes.clear()
	_counts.clear()
	var mb := MeshBuilder.new()
	var fine := MeshBuilder.new()
	_armour(mb, fine, lv("armour"))
	_copper(mb, lv("copper"))
	_guns(mb, fine, lv("guns"))
	_chaser(mb, fine, lv("chaser"))
	_sails(mb, lv("sails"))
	_nest(mb, lv("nest"))
	if lv("nest") >= 1 or lv("sails") >= 5:
		_staff(mb)
	_rudder(mb, fine, lv("rudder"))
	_lanterns(mb, lv("lanterns"))
	_rails(mb, fine, lv("rails"))
	_grove(mb, lv("grove"))
	_galley(mb, fine, lv("galley"))
	_hold(mb, fine, lv("chest"))
	for b in [mb, fine]:
		(b as MeshBuilder).fold_tints()
	if _mesh == null:
		_mesh = MeshInstance3D.new()
		_mesh.name = "UpgradeMesh"
		_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_mesh.visibility_range_end = 600.0
		add_child(_mesh)
		_fine = MeshInstance3D.new()
		_fine.name = "UpgradeFine"
		_fine.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_fine.visibility_range_end = 90.0
		add_child(_fine)
	_mesh.mesh = mb.commit()
	_fine.mesh = fine.commit()


func _count(id: String, n: int = 1) -> void:
	_counts[id] = int(_counts.get(id, 0)) + n


## A node of ours (freed on the next rebuild).
func _own(n: Node3D, parent: Node) -> Node3D:
	parent.add_child(n)
	_nodes.append(n)
	return n


## Something you can't walk through (a box on the ship's body, ship-local).
func _solid(at: Vector3, size: Vector3) -> void:
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = size
	cs.shape = b
	cs.position = at
	_own(cs, ship)


# --------------------------------------------------------------------------
# The hull's shape (HullBuilder.RINGS) at any point
# --------------------------------------------------------------------------
## [z, top half-width, bottom half-width, top y, bottom y] at `z`.
static func ring_at(z: float) -> Array:
	var rings: Array = HullBuilder.RINGS
	for i in range(rings.size() - 1):
		var a: Array = rings[i]
		var b: Array = rings[i + 1]
		if z <= float(a[0]) and z >= float(b[0]):
			var k := (float(a[0]) - z) / (float(a[0]) - float(b[0]))
			var out: Array = [z]
			for j in range(1, 5):
				out.append(lerpf(float(a[j]), float(b[j]), k))
			return out
	return rings[0] if z > 0.0 else rings[rings.size() - 1]


## The hull's half-width at (z, y): straight up from its top edge, tapering to the keel.
static func side_at(z: float, y: float) -> float:
	var r := ring_at(z)
	var k := clampf((float(r[3]) - y) / maxf(float(r[3]) - float(r[4]), 0.01), 0.0, 1.0)
	return lerpf(float(r[1]), float(r[2]), k)


## A band `h` high, `thick` proud of both sides from z0 to z1 at height y (segments follow the curve).
static func _band(mb: MeshBuilder, mat: Material, z0: float, z1: float, y: float, h: float, thick: float, col := Color.WHITE) -> void:
	var n := maxi(int(absf(z1 - z0) / 1.2), 1)
	for sgn in [-1.0, 1.0]:
		for i in range(n):
			var za := lerpf(z0, z1, float(i) / n)
			var zb := lerpf(z0, z1, float(i + 1) / n)
			var p0 := Vector3(sgn * (side_at(za, y) + thick * 0.5), y, za)
			var p1 := Vector3(sgn * (side_at(zb, y) + thick * 0.5), y, zb)
			var d := p1 - p0
			mb.add_box(mat, Transform3D(Basis.looking_at(d.normalized(), Vector3.UP), (p0 + p1) * 0.5), Vector3(thick, h, d.length() + 0.06), 1.0, col)


## Sheathing laid on both sides from z0 to z1, y0 up to y1, `out` proud of the planks.
static func _skin(mb: MeshBuilder, mat: Material, z0: float, z1: float, y0: float, y1: float, out: float, col := Color.WHITE) -> void:
	var n := maxi(int(absf(z1 - z0) / 1.0), 1)
	var rows := maxi(int(absf(y1 - y0) / 0.6), 1)
	for sgn in [-1.0, 1.0]:
		for i in range(n):
			var za := lerpf(z0, z1, float(i) / n)
			var zb := lerpf(z0, z1, float(i + 1) / n)
			for j in range(rows):
				var ya := lerpf(y0, y1, float(j) / rows)
				var yb := lerpf(y0, y1, float(j + 1) / rows)
				var a := Vector3(sgn * (side_at(za, ya) + out), ya, za)
				var b := Vector3(sgn * (side_at(zb, ya) + out), ya, zb)
				var c := Vector3(sgn * (side_at(zb, yb) + out), yb, zb)
				var d := Vector3(sgn * (side_at(za, yb) + out), yb, za)
				# (alternate plates a shade apart, so the seams read)
				var shade := col.darkened(0.12 * ((i + j) % 2))
				mb.add_quad(mat, a, b, c, d, Vector2(za * 0.6, -ya * 0.6), Vector2(zb * 0.6, -ya * 0.6), Vector2(zb * 0.6, -yb * 0.6), Vector2(za * 0.6, -yb * 0.6), shade, Vector3(sgn, -0.25, 0).normalized())


# --------------------------------------------------------------------------
# Hull plating
# --------------------------------------------------------------------------
func _armour(mb: MeshBuilder, fine: MeshBuilder, n: int) -> void:
	var iron: Material = _m["iron"]
	if n >= 1:
		# rubbing strakes: two heavy wales the length of her, painted (they read whatever her hull paint)
		for y in [-0.1, -0.8]:
			_band(mb, _m["wale"], -11.8, 9.85, y, 0.26, 0.1)
		_count("armour")
	if n >= 2:
		# iron knees: straps amidships
		_straps(mb, [-2.0, 1.0, 4.0])
		_count("armour")
	if n >= 3:
		# straps her whole length, and an iron band under the rail
		_straps(mb, [-8.0, -5.0, 7.0, 9.4])
		var rings: Array = HullBuilder.RINGS
		for i in range(rings.size() - 2):
			var a: Array = rings[i]
			var c: Array = rings[i + 1]
			for sgn in [-1.0, 1.0]:
				var p0 := Vector3(sgn * (float(a[1]) - 0.05), float(a[3]) - 0.35, float(a[0]))
				var p1 := Vector3(sgn * (float(c[1]) - 0.05), float(c[3]) - 0.35, float(c[0]))
				mb.add_box(iron, Transform3D(Basis.looking_at((p1 - p0).normalized(), Vector3.UP), (p0 + p1) * 0.5), Vector3(0.08, 0.12, p0.distance_to(p1) + 0.05), 1.0)
		_count("armour")
	if n >= 4:
		# an iron-shod bow: the stem capped, plates over her cheeks
		var bw: Array = rings_last()
		var top := float(bw[3]) + HullBuilder.LIP
		mb.add_box(iron, Transform3D(Basis(), Vector3(0, (top + float(bw[4])) * 0.5, float(bw[0]) - 0.18)), Vector3(0.34, top - float(bw[4]) + 0.1, 0.12), 1.0, Color.WHITE, false)
		_skin(mb, iron, -12.45, -10.2, -0.55, 1.3, 0.035, Color(0.85, 0.85, 0.88))
		_rivets(fine, [-12.0, -11.1, -10.2], -0.5, 1.25)
		_count("armour")
	if n >= 5:
		# iron capping along the main deck's rails
		var rings: Array = HullBuilder.RINGS
		for i in range(1, rings.size() - 1):
			var a: Array = rings[i]
			var b: Array = rings[i + 1]
			for sgn in [-1.0, 1.0]:
				var p0 := Vector3(sgn * float(a[1]), float(a[3]) + HullBuilder.LIP + 0.09, float(a[0]))
				var p1 := Vector3(sgn * float(b[1]), float(b[3]) + HullBuilder.LIP + 0.09, float(b[0]))
				var d := p1 - p0
				mb.add_box(_m["dark_iron"], Transform3D(Basis.looking_at(d.normalized(), Vector3.UP), (p0 + p1) * 0.5), Vector3(0.22, 0.05, d.length() + 0.1), 1.0)
		_count("armour")
	if n >= 6:
		# riveted plates over her stern quarters, up to the quarterdeck rail
		_skin(mb, iron, 6.0, HullBuilder.QD_BACK - 0.02, 0.45, HullBuilder.QD_Y, 0.04, Color(0.8, 0.8, 0.84))
		_rivets(fine, [6.0, 7.3, 8.6, 9.8], 0.5, HullBuilder.QD_Y - 0.05)
		_count("armour")


static func rings_last() -> Array:
	return HullBuilder.RINGS[HullBuilder.RINGS.size() - 1]


## Iron straps down her sides at each z (the top of the hull to halfway down).
func _straps(mb: MeshBuilder, zs: Array) -> void:
	for z in zs:
		var r := ring_at(z)
		var top := Vector2(float(r[1]), float(r[3]))
		var low := top.lerp(Vector2(float(r[2]), float(r[4])), 0.55)
		var along := top - low
		for sgn in [-1.0, 1.0]:
			var mid := (top + low) * 0.5
			var b := Basis(Vector3.BACK, -sgn * asin(along.x / along.length()))
			mb.add_box(_m["iron"], Transform3D(b, Vector3(sgn * (mid.x + 0.04), mid.y, z)), Vector3(0.07, along.length(), 0.22), 1.0)


## Rows of rivet heads up the plate seams at each z, from y0 to y1.
func _rivets(fine: MeshBuilder, zs: Array, y0: float, y1: float) -> void:
	for z in zs:
		var y := y0
		while y <= y1:
			for sgn in [-1.0, 1.0]:
				fine.add_box(_m["dark_iron"], Transform3D(Basis(), Vector3(sgn * (side_at(z, y) + 0.06), y, z)), Vector3(0.05, 0.05, 0.05), 1.0)
			y += 0.32


# --------------------------------------------------------------------------
# Gun deck (the guns' own fittings: ShipCannon.fit)
# --------------------------------------------------------------------------
func _guns(mb: MeshBuilder, fine: MeshBuilder, n: int) -> void:
	if n >= 1:
		# a rack of shot inboard of every gun
		var pairs := 3 if n >= 2 else 2
		for i in range(pairs):
			var g: Array = Ship.GUN_SPOTS[i]
			for sgn in [-1.0, 1.0]:
				var at := Vector3(sgn * (float(g[1]) - 0.55), float(g[2]), float(g[0]) + 0.75)
				mb.add_box(_m["oak"], Transform3D(Basis(), at + Vector3(0, 0.09, 0)), Vector3(0.36, 0.18, 0.5), 1.0)
				for k in range(4):
					var b := at + Vector3((k % 2 - 0.5) * 0.15, 0.24, (floorf(k / 2.0) - 0.5) * 0.2)
					fine.add_cylinder(_m["dark_iron"], Transform3D(Basis(), b), 0.075, 0.075, 0.13, 6, 1.0, Color.WHITE, true, true)
				fine.add_cylinder(_m["dark_iron"], Transform3D(Basis(), at + Vector3(0, 0.36, 0)), 0.075, 0.075, 0.12, 6, 1.0, Color.WHITE, true, true)
		_count("guns")
	for k in range(2, n + 1):
		_count("guns")


# --------------------------------------------------------------------------
# Sails & rigging (the main sail grows by RIG_SCALE)
# --------------------------------------------------------------------------
func _sails(mb: MeshBuilder, n: int) -> void:
	var sail_node: Node3D = ship._sail_node
	if n >= 1:
		# bolt ropes and two rows of reef points across the sail (on it: they furl with it)
		var rmb := MeshBuilder.new()
		for r in [[-1.6, 4.05, 0.23], [-3.2, 3.95, 0.39]]:
			var y: float = r[0]
			var z: float = r[2]
			HullBuilder._line(rmb, _m["rope"], Vector3(-r[1], y, z), Vector3(r[1], y, z), 0.06)
			for k in range(9):
				var x := -3.6 + k * 0.9
				HullBuilder._line(rmb, _m["rope"], Vector3(x, y, z + 0.02), Vector3(x, y - 0.35, z + 0.05), 0.03)
		_own(rmb.to_instance("ReefBands"), sail_node)
		_count("sails")
	if n >= 2:
		# a jib from the bowsprit's end up the forestay
		var tack := Vector3(0, 2.45, -16.1)
		var head := Vector3(0, 11.2, -3.0) - tack
		var clew := Vector3(0, 2.3, -9.6) - tack
		var jmb := MeshBuilder.new()
		jmb.add_tri(_m["trim"], Vector3.ZERO, head, clew, Vector3.RIGHT, Vector3.RIGHT, Vector3.RIGHT, Vector2(0, 2.4), Vector2(1.2, 0), Vector2(1.4, 2.4), Color.WHITE, Vector3.RIGHT)
		jmb.add_tri(_m["trim"], Vector3.ZERO, head, clew, Vector3.LEFT, Vector3.LEFT, Vector3.LEFT, Vector2(0, 2.4), Vector2(1.2, 0), Vector2(1.4, 2.4), Color(0.8, 0.8, 0.75), Vector3.LEFT)
		jib = Node3D.new()
		jib.name = "Jib"
		jib.position = tack
		_own(jib, ship.ship_model)
		var jm := jmb.to_instance("JibSail")
		jm.set_meta("sail", true)
		jib.add_child(jm)
		_nodes.append(jm)
		HullBuilder._line(mb, _m["rope"], tack, tack + head, 0.04)
		HullBuilder._line(mb, _m["rope"], tack + clew, Vector3(0.0, HullBuilder.DECK_Y + 0.9, -9.2), 0.03)
		_count("sails")
	if n >= 3:
		_count("sails")
	if n >= 4:
		# studding sails: booms out past each end of the yard, a sail hanging from each
		var bmb := MeshBuilder.new()
		var sx: float = (RIG_SCALE[n] as Vector2).x
		for sgn in [-1.0, 1.0]:
			bmb.add_cylinder(_m["trim"], Transform3D(Basis(Vector3.BACK, -sgn * PI * 0.5), Vector3(sgn * 4.3 * sx, 0.12, 0.18)), 0.07, 0.06, 1.8 * sx, 6, 0.8)
		_own(bmb.to_instance("StudBooms"), ship._rig)
		var smb := MeshBuilder.new()
		for sgn in [-1.0, 1.0]:
			var x0: float = sgn * 4.35
			var x1: float = sgn * 5.85
			var a := Vector3(x0, -0.05, 0.25); var b := Vector3(x1, -0.05, 0.25)
			var c := Vector3(x1 - sgn * 0.15, -4.8, 0.55); var d := Vector3(x0 - sgn * 0.05, -4.8, 0.55)
			smb.add_quad(_m["trim"], a, b, c, d, Vector2(0, 0), Vector2(0.4, 0), Vector2(0.4, 1.2), Vector2(0, 1.2), Color.WHITE, Vector3.BACK)
			smb.add_quad(_m["trim"], a, d, c, b, Vector2(0, 0), Vector2(0, 1.2), Vector2(0.4, 1.2), Vector2(0.4, 0), Color(0.8, 0.8, 0.75), Vector3.FORWARD)
		var studs := smb.to_instance("StuddingSails")
		studs.set_meta("sail", true)
		_own(studs, sail_node)
		_count("sails")
	if n >= 5:
		# a long pennant streaming aft from the masthead's staff
		var top := Vector3(0, HullBuilder.MAST_TOP + STAFF_H, HullBuilder.MAST_Z)
		var p0 := top + Vector3(0, -0.1, 0.05)
		var p1 := top + Vector3(0, -0.48, 0.05)
		var tip := top + Vector3(0.0, -0.75, 4.6)
		for side in [Vector3.RIGHT, Vector3.LEFT]:
			mb.add_tri(_m["pennant"], p0, p1, tip, side, side, side, Vector2(0, 0), Vector2(0, 0.4), Vector2(2.0, 0.2), Color.WHITE, side)
		_count("sails")


## A flagstaff up from the masthead with a gilt truck (the pennant flies from it; the nest's hood raises the flag on it).
const STAFF_H := 2.8


func _staff(mb: MeshBuilder) -> void:
	var top := Vector3(0, HullBuilder.MAST_TOP - 0.2, HullBuilder.MAST_Z)
	mb.add_cylinder(_m["trim"], Transform3D(Basis(), top), 0.09, 0.06, STAFF_H + 0.2, 6, 0.8)
	mb.add_cylinder(_m["gilt"], Transform3D(Basis(), top + Vector3(0, STAFF_H + 0.2, 0)), 0.13, 0.13, 0.12, 6, 1.0, Color.WHITE, true, true)


## The jib comes down with the main sail (k: how much canvas is let down).
func show_sail(k: float) -> void:
	if jib:
		jib.scale = Vector3.ONE * lerpf(0.04, 1.0, k)
		jib.visible = k > 0.01


# --------------------------------------------------------------------------
# Rudder & helm
# --------------------------------------------------------------------------
func _rudder(mb: MeshBuilder, fine: MeshBuilder, n: int) -> void:
	if n >= 1:
		# the rudder on the stern post, hung on iron pintles; the head up through the taffrail
		rudder_node = Node3D.new()
		rudder_node.name = "Rudder"
		rudder_node.position = RUDDER_AT
		_own(rudder_node, ship.ship_model)
		var rmb := MeshBuilder.new()
		var w := 1.25 if n >= 4 else 0.85
		rmb.add_box(_m["oak"], Transform3D(Basis(), Vector3(0, -1.05, w * 0.5)), Vector3(0.18, 2.6, w), 1.0, Color.WHITE, false)
		rmb.add_cylinder(_m["oak"], Transform3D(Basis(), Vector3(0, 0.2, 0.06)), 0.12, 0.12, HullBuilder.QD_Y + 0.4 - RUDDER_AT.y - 0.2, 6, 1.0)
		for y in [-2.0, -1.2, -0.4]:
			rmb.add_box(_m["iron"], Transform3D(Basis(), Vector3(0, y, 0.18)), Vector3(0.24, 0.1, 0.42), 1.0, Color.WHITE, false)
		if n >= 4:
			# the balanced blade: wider, iron-cheeked, a little forward of the post
			rmb.add_box(_m["oak"], Transform3D(Basis(), Vector3(0, -1.6, -0.18)), Vector3(0.16, 1.5, 0.36), 1.0, Color.WHITE, false)
			for sgn in [-1.0, 1.0]:
				rmb.add_box(_m["iron"], Transform3D(Basis(), Vector3(sgn * 0.1, -1.05, w - 0.12)), Vector3(0.03, 2.5, 0.2), 1.0)
		_own(rmb.to_instance("Blade"), rudder_node)
		_count("rudder")
	if n >= 2:
		# a brass rim round the wheel, handles out past it
		var wmb := MeshBuilder.new()
		wmb.add_cylinder(_m["brass"], Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 0, 0.06)), 0.47, 0.47, 0.05, 10, 1.0, Color.WHITE, true, true, false)
		for k in range(8):
			var a := TAU * k / 8.0
			var dir := Vector3(cos(a), sin(a), 0)
			wmb.add_box(_m["trim"], Transform3D(Basis(Vector3.BACK, a - PI * 0.5), dir * 0.55 + Vector3(0, 0, 0.04)), Vector3(0.05, 0.18, 0.05), 1.0)
		_own(wmb.to_instance("BrassRim"), ship.wheel)
		_count("rudder")
	if n >= 3:
		# a binnacle forward of the wheel: a post, the brass hood, the compass's lamp
		var at := Vector3(0, HullBuilder.QD_Y, HullBuilder.WHEEL_Z - 0.85)
		mb.add_box(_m["trim"], Transform3D(Basis(), at + Vector3(0, 0.45, 0)), Vector3(0.36, 0.9, 0.36), 1.0)
		mb.add_cylinder(_m["brass"], Transform3D(Basis(), at + Vector3(0, 0.9, 0)), 0.22, 0.14, 0.26, 8, 1.0, Color.WHITE, true, true)
		mb.add_box(_m["glass"], Transform3D(Basis(), at + Vector3(0, 0.98, 0.15)), Vector3(0.16, 0.1, 0.06), 1.0)
		_count("rudder")
	if n >= 4:
		_count("rudder")
	if n >= 5:
		# a carved, gilded taffrail across her stern, scrolls at its ends
		var hb := HullBuilder.half_width(HullBuilder.QD_BACK)
		var y := HullBuilder.QD_Y + 1.1
		var z := HullBuilder.QD_BACK + 0.04
		mb.add_box(_m["gilt"], Transform3D(Basis(), Vector3(0, y, z)), Vector3(hb * 1.7, 0.42, 0.1), 1.0)
		mb.add_box(_m["trim"], Transform3D(Basis(), Vector3(0, y + 0.26, z)), Vector3(hb * 1.8, 0.1, 0.16), 1.0)
		for sgn in [-1.0, 1.0]:
			mb.add_cylinder(_m["gilt"], Transform3D(Basis(Vector3.FORWARD, PI * 0.5), Vector3(sgn * hb * 0.92, y, z)), 0.2, 0.2, 0.14, 8, 1.0, Color.WHITE, true, true)
			for k in range(3):
				fine.add_box(_m["gilt"], Transform3D(Basis(Vector3.BACK, 0.6 * sgn), Vector3(sgn * (0.6 + k * 0.7), y + 0.02, z + 0.06)), Vector3(0.36, 0.08, 0.04), 1.0)
		_count("rudder")


## The rudder follows the helm (rudder -1..1, +1 hard to starboard).
func steer(r: float) -> void:
	if rudder_node:
		rudder_node.rotation.y = r * RUDDER_SWING


# --------------------------------------------------------------------------
# Copper bottom: sheathing along her waterline, bow first
# --------------------------------------------------------------------------
const COPPER_Z := [-12.45, -6.0, 2.0, HullBuilder.QD_BACK - 0.02]


func _copper(mb: MeshBuilder, n: int) -> void:
	for k in range(n):
		_skin(mb, _m["copper"], COPPER_Z[k], COPPER_Z[k + 1], -1.7, -0.97, 0.03)
		_band(mb, _m["copper"], COPPER_Z[k], COPPER_Z[k + 1], -0.95, 0.07, 0.05, Color(1.35, 1.25, 1.1))
		_count("copper")


# --------------------------------------------------------------------------
# Bow chaser (the gun itself is Ship's: CannonBow on CHASER_AT)
# --------------------------------------------------------------------------
## The chaser's step at the bow (ship-local, the gun stands on it).
const CHASER_AT := Vector3(0, HullBuilder.DECK_Y + 0.42, -10.9)


func _chaser(mb: MeshBuilder, fine: MeshBuilder, n: int) -> void:
	if n >= 1:
		var step := Vector3(CHASER_AT.x, HullBuilder.DECK_Y, CHASER_AT.z)
		mb.add_box(_m["oak"], Transform3D(Basis(), step + Vector3(0, 0.21, 0.4)), Vector3(1.7, 0.42, 2.0), 1.0)
		mb.add_box(_m["trim"], Transform3D(Basis(), step + Vector3(0, 0.43, 0.4)), Vector3(1.78, 0.04, 2.08), 1.0)
		_solid(step + Vector3(0, 0.21, 0.4), Vector3(1.7, 0.42, 2.0))
		_count("chaser")
	if n >= 2:
		# a shot locker to starboard of the step, balls ready on its lid
		var at := Vector3(1.25, HullBuilder.DECK_Y, -9.0)
		mb.add_box(_m["oak"], Transform3D(Basis(), at + Vector3(0, 0.25, 0)), Vector3(0.5, 0.5, 0.6), 1.0)
		mb.add_box(_m["dark_iron"], Transform3D(Basis(), at + Vector3(0, 0.51, 0)), Vector3(0.54, 0.04, 0.64), 1.0)
		for k in range(3):
			fine.add_cylinder(_m["dark_iron"], Transform3D(Basis(), at + Vector3(-0.12 + k * 0.12, 0.53, 0.05)), 0.07, 0.07, 0.12, 6, 1.0, Color.WHITE, true, true)
		_solid(at + Vector3(0, 0.25, 0), Vector3(0.5, 0.5, 0.6))
		_count("chaser")
	if n >= 3:
		# a rail round the step's front, a grating on it
		var top := CHASER_AT.y
		for x in [-0.8, 0.0, 0.8]:
			mb.add_box(_m["trim"], Transform3D(Basis(), Vector3(x, top + 0.3, CHASER_AT.z - 0.62)), Vector3(0.08, 0.6, 0.08), 1.0)
		for sx in [-1.0, 1.0]:
			mb.add_box(_m["trim"], Transform3D(Basis(), Vector3(sx * 0.82, top + 0.3, CHASER_AT.z - 0.1)), Vector3(0.08, 0.6, 0.08), 1.0)
			mb.add_box(_m["trim"], Transform3D(Basis(), Vector3(sx * 0.82, top + 0.6, CHASER_AT.z - 0.36)), Vector3(0.08, 0.07, 0.6), 1.0)
		mb.add_box(_m["trim"], Transform3D(Basis(), Vector3(0, top + 0.6, CHASER_AT.z - 0.62)), Vector3(1.72, 0.07, 0.08), 1.0)
		for k in range(5):
			mb.add_box(_m["dark_iron"], Transform3D(Basis(), Vector3(0, top + 0.03, CHASER_AT.z - 0.5 + k * 0.25)), Vector3(1.1, 0.03, 0.06), 1.0)
		_count("chaser")


# --------------------------------------------------------------------------
# Crow's nest
# --------------------------------------------------------------------------
const HOOD_Y := HullBuilder.NEST_Y + 2.0


func _nest(mb: MeshBuilder, n: int) -> void:
	var c := Vector3(0, 0, HullBuilder.MAST_Z)
	var rail_top := HullBuilder.NEST_Y + 0.9
	if n >= 1:
		# poles up from the rail and a hood over them (canvas, then boards)
		for k in range(4):
			var a := TAU * (k + 0.5) / 4.0
			var p := c + Vector3(cos(a) * (HullBuilder.NEST_R - 0.1), 0, sin(a) * (HullBuilder.NEST_R - 0.1))
			mb.add_cylinder(_m["trim"], Transform3D(Basis(), Vector3(p.x, HullBuilder.NEST_Y, p.z)), 0.05, 0.05, HOOD_Y - HullBuilder.NEST_Y, 5, 1.0)
		var hood: Material = _m["roof"] if n >= 2 else _m["canvas"]
		mb.add_cylinder(hood, Transform3D(Basis(), c + Vector3(0, HOOD_Y, 0)), HullBuilder.NEST_R + 0.3, 0.12, 0.65, 10, 0.8, Color.WHITE, false, true, false)
		_count("nest")
	if n >= 2:
		# boards above the rail fore and aft (the sides stay open for the rigging), a strip of windows
		for k in range(16):
			var a := TAU * (k + 0.5) / 16.0
			if absf(cos(a)) > 0.62:
				continue
			var p := c + Vector3(cos(a) * (HullBuilder.NEST_R - 0.05), 0, sin(a) * (HullBuilder.NEST_R - 0.05))
			var b := Basis(Vector3.UP, -a)
			mb.add_box(_m["roof"], Transform3D(b, Vector3(p.x, rail_top + 0.17, p.z)), Vector3(0.08, 0.34, HullBuilder.NEST_R * 0.66), 1.0)
			mb.add_box(_m["glass"], Transform3D(b, Vector3(p.x, rail_top + 0.48, p.z)), Vector3(0.04, 0.22, HullBuilder.NEST_R * 0.5), 1.0)
		_count("nest")
	if n >= 3:
		# a brass spyglass on a swivel at the fore side, a lantern under the roof
		var at := c + Vector3(0, rail_top, -(HullBuilder.NEST_R - 0.25))
		mb.add_cylinder(_m["trim"], Transform3D(Basis(), at), 0.05, 0.05, 0.35, 5, 1.0)
		mb.add_cylinder(_m["brass"], Transform3D(Basis(Vector3.RIGHT, -PI * 0.5 + 0.12), at + Vector3(0, 0.4, 0.35)), 0.07, 0.05, 1.1, 6, 1.0, Color.WHITE, true, true)
		mb.add_box(_m["glass"], Transform3D(Basis(), c + Vector3(0.45, HOOD_Y - 0.3, 0.3)), Vector3(0.18, 0.24, 0.18), 1.0)
		_count("nest")


# --------------------------------------------------------------------------
# Lanterns: strings of paper lanterns (glow only, no real lights)
# --------------------------------------------------------------------------
func _lantern_string(mb: MeshBuilder, a: Vector3, b: Vector3, droop: float, n: int, k0: int = 0) -> void:
	var pts := MeshBuilder.sag_points(a, b, droop, n)
	var mats := [_m["lamp_red"], _m["lamp_gold"], _m["lamp_white"]]
	for i in range(pts.size() - 1):
		HullBuilder._line(mb, _m["rope"], pts[i], pts[i + 1], 0.03)
	for i in range(1, pts.size() - 1):
		var p: Vector3 = pts[i] - Vector3(0, 0.22, 0)
		mb.add_cylinder(mats[(i + k0) % 3], Transform3D(Basis(), p), 0.13, 0.13, 0.26, 6, 1.0, Color.WHITE, true, true)


func _lanterns(mb: MeshBuilder, n: int) -> void:
	var mast := Vector3(0, 9.0, HullBuilder.MAST_Z)
	if n >= 1:
		_lantern_string(mb, mast + Vector3(0, 0, -0.2), Vector3(0, 2.6, -15.7), 1.3, 10)
		_count("lanterns")
	if n >= 2:
		for sgn in [-1.0, 1.0]:
			_lantern_string(mb, mast + Vector3(sgn * 0.2, 0, 0.2), Vector3(sgn * 3.3, HullBuilder.QD_Y + 1.7, HullBuilder.QD_BACK - 0.35), 1.1, 9, 1)
		_count("lanterns")
	if n >= 3:
		# a ring under the nest, and along the main rails
		var mats := [_m["lamp_red"], _m["lamp_gold"], _m["lamp_white"]]
		for k in range(10):
			var a := TAU * (k + 0.5) / 10.0
			var p := Vector3(cos(a) * (HullBuilder.NEST_R + 0.05), HullBuilder.NEST_Y - 0.45, HullBuilder.MAST_Z + sin(a) * (HullBuilder.NEST_R + 0.05))
			HullBuilder._line(mb, _m["rope"], p + Vector3(0, 0.3, 0), p + Vector3(0, 0.13, 0), 0.02)
			mb.add_cylinder(mats[k % 3], Transform3D(Basis(), p - Vector3(0, 0.13, 0)), 0.12, 0.12, 0.24, 6, 1.0, Color.WHITE, true, true)
		for sgn in [-1.0, 1.0]:
			var r0 := ring_at(-8.0)
			var r1 := ring_at(4.4)
			_lantern_string(mb, Vector3(sgn * (float(r0[1]) - 0.05), float(r0[3]) + HullBuilder.LIP + 1.0, -8.0), Vector3(sgn * (float(r1[1]) - 0.05), float(r1[3]) + HullBuilder.LIP + 1.0, 4.4), 0.5, 9, 2)
		_count("lanterns")


# --------------------------------------------------------------------------
# Railings: stanchions and man-ropes, a balustrade, boarding nets (her waist)
# --------------------------------------------------------------------------
## Stanchions along the main deck rails (clear of the guns, ladders and shrouds), and the spans
## between them that carry a rope or rail (none over a gun).
const RAIL_POSTS := [-9.5, -8.0, -5.5, -3.6, -1.0, 0.8, 2.6, 4.6]
const RAIL_SPANS := [[0, 1], [3, 4], [4, 5], [5, 6], [6, 7]]
const RAIL_H := 0.55


func _rail_top(z: float, sgn: float) -> Vector3:
	var r := ring_at(z)
	return Vector3(sgn * (float(r[1]) - 0.05), float(r[3]) + HullBuilder.LIP + 0.07, z)


func _rails(mb: MeshBuilder, fine: MeshBuilder, n: int) -> void:
	if n >= 1:
		for sgn in [-1.0, 1.0]:
			for z in RAIL_POSTS:
				var p := _rail_top(z, sgn)
				mb.add_cylinder(_m["dark_iron"], Transform3D(Basis(), p), 0.035, 0.03, RAIL_H, 5, 1.0)
				fine.add_cylinder(_m["brass"], Transform3D(Basis(), p + Vector3(0, RAIL_H, 0)), 0.05, 0.05, 0.05, 6, 1.0, Color.WHITE, true, true)
			for s in RAIL_SPANS:
				var a := _rail_top(RAIL_POSTS[s[0]], sgn) + Vector3(0, RAIL_H - 0.05, 0)
				var b := _rail_top(RAIL_POSTS[s[1]], sgn) + Vector3(0, RAIL_H - 0.05, 0)
				var pts := MeshBuilder.sag_points(a, b, 0.12 if n < 2 else 0.0, 5)
				for i in range(pts.size() - 1):
					HullBuilder._line(mb, _m["rope"], pts[i], pts[i + 1], 0.04)
		_count("rails")
	if n >= 2:
		# turned balusters under a wooden top rail on each span
		for sgn in [-1.0, 1.0]:
			for s in RAIL_SPANS:
				var a := _rail_top(RAIL_POSTS[s[0]], sgn)
				var b := _rail_top(RAIL_POSTS[s[1]], sgn)
				var d := b - a
				mb.add_box(_m["trim"], Transform3D(Basis.looking_at(d.normalized(), Vector3.UP), (a + b) * 0.5 + Vector3(0, RAIL_H, 0)), Vector3(0.12, 0.08, d.length()), 1.0)
				var k := int(d.length() / 0.32)
				for i in range(1, k):
					var p := a.lerp(b, float(i) / k)
					mb.add_cylinder(_m["trim"], Transform3D(Basis(), p), 0.05, 0.035, RAIL_H, 5, 1.0, Color.WHITE, false)
		_count("rails")
	if n >= 3:
		# rope nets rigged above her waist's rails, against boarders
		for sgn in [-1.0, 1.0]:
			var a := _rail_top(RAIL_POSTS[3], sgn) + Vector3(0, RAIL_H, 0)
			var b := _rail_top(RAIL_POSTS[7], sgn) + Vector3(0, RAIL_H, 0)
			var up := Vector3(sgn * 0.25, 0.85, 0)
			var cols := 16
			for i in range(cols + 1):
				var p := a.lerp(b, float(i) / cols)
				HullBuilder._line(mb, _m["rope"], p, p + up, 0.025)
			for j in range(4):
				var h := up * (j + 1) / 4.0
				var pts := MeshBuilder.sag_points(a + h, b + h, 0.1, 8)
				for i in range(pts.size() - 1):
					HullBuilder._line(mb, _m["rope"], pts[i], pts[i + 1], 0.025)
			for z in [RAIL_POSTS[3], RAIL_POSTS[5], RAIL_POSTS[7]]:
				var p := _rail_top(z, sgn) + Vector3(0, RAIL_H, 0)
				mb.add_cylinder(_m["trim"], Transform3D(Basis(Vector3.BACK, -sgn * 0.28), p), 0.04, 0.035, 0.9, 5, 1.0)
		_count("rails")


# --------------------------------------------------------------------------
# Tangerine grove: trees in planters on the quarterdeck, fruit to pick
# --------------------------------------------------------------------------
const GROVE_AT := [Vector3(-1.7, HullBuilder.QD_Y, 9.15), Vector3(1.7, HullBuilder.QD_Y, 9.15), Vector3(0.0, HullBuilder.QD_Y, 9.35)]
## A tree ripens a tangerine this often (game seconds), up to RIPE_MAX on it.
const RIPEN := 150.0
const RIPE_MAX := 2
var ripe: int = 0
var grove_zone: Interactable
var _fruit: Array = []
var _ripen_timer: Timer


func _grove(mb: MeshBuilder, n: int) -> void:
	_fruit.clear()
	for i in range(n):
		var at: Vector3 = GROVE_AT[i]
		mb.add_box(_m["oak"], Transform3D(Basis(), at + Vector3(0, 0.25, 0)), Vector3(0.9, 0.5, 0.9), 1.0)
		for y in [0.1, 0.4]:
			mb.add_box(_m["dark_iron"], Transform3D(Basis(), at + Vector3(0, y, 0)), Vector3(0.93, 0.05, 0.93), 1.0)
		mb.add_box(_m["soil"], Transform3D(Basis(), at + Vector3(0, 0.49, 0)), Vector3(0.8, 0.04, 0.8), 1.0)
		mb.add_cylinder(_m["oak"], Transform3D(Basis(), at + Vector3(0, 0.5, 0)), 0.08, 0.06, 0.85, 5, 1.0)
		var rng := RandomNumberGenerator.new()
		rng.seed = 51 + i
		mb.add_blob(_m["leaves"], Transform3D(Basis(), at + Vector3(0, 1.45, 0)), Vector3(0.62, 0.5, 0.62), rng)
		_solid(at + Vector3(0, 0.25, 0), Vector3(0.9, 0.5, 0.9))
		# its fruit (shown while some's ripe)
		var fm := MeshBuilder.new()
		for k in range(7):
			var a := TAU * k / 7.0 + i
			fm.add_box(_m["fruit"], Transform3D(Basis(Vector3.UP, a), at + Vector3(cos(a) * 0.58, 1.2 + (k % 3) * 0.2, sin(a) * 0.58)), Vector3(0.17, 0.17, 0.17), 1.0)
		var fruit := fm.to_instance("Fruit%d" % i)
		fruit.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		fruit.visibility_range_end = 120.0
		_own(fruit, self)
		_fruit.append(fruit)
		_count("grove")
	grove_zone = null
	if n >= 1:
		var z := Interactable.new()
		z.name = "Grove"
		z.collision_layer = 512
		z.collision_mask = 0
		z.reach = 1.2
		var cs := CollisionShape3D.new()
		var sp := SphereShape3D.new()
		sp.radius = 1.4
		cs.shape = sp
		z.add_child(cs)
		z.position = Vector3(0, HullBuilder.QD_Y + 0.8, 8.85)
		_own(z, self)
		z.interacted.connect(pick)
		grove_zone = z
		if _ripen_timer == null:
			_ripen_timer = Timer.new()
			_ripen_timer.wait_time = RIPEN
			_ripen_timer.timeout.connect(_ripen)
			add_child(_ripen_timer)
			_ripen_timer.start()
			ripe = n
	ripe = mini(ripe, n * RIPE_MAX)
	_show_fruit()


func _ripen() -> void:
	ripe = mini(ripe + lv("grove"), lv("grove") * RIPE_MAX)
	_show_fruit()


func _show_fruit() -> void:
	for i in range(_fruit.size()):
		(_fruit[i] as Node3D).visible = ripe > i
	if grove_zone:
		grove_zone.prompt_text = "Pick tangerines (%d)" % ripe if ripe > 0 else "Not ripe yet"


## Our captain picks what's ripe (every captain picks their own trees: each screen grows its own).
func pick(p: Player) -> void:
	if ripe <= 0:
		p.call("_toast", "Nothing ripe yet. Give them a few minutes.")
		return
	var it := ItemDB.get_item("tangerine")
	var n := mini(ripe, p.inventory_component.room_for(it))
	if n <= 0:
		p.call("_toast", "Your bag is full")
		return
	p.inventory_component.add_item(it, n)
	ripe -= n
	FX.sparkle(grove_zone.global_position + Vector3.UP * 0.5, 10, Color(1.0, 0.65, 0.2))
	FX.sfx("blip_high", grove_zone.global_position, -6.0, 0.1)
	p.call("_toast", "Picked %d tangerine%s" % [n, "" if n == 1 else "s"])
	_show_fruit()


# --------------------------------------------------------------------------
# Galley & bunks (in the cabin; the chimney shows on the quarterdeck)
# --------------------------------------------------------------------------
func _galley(mb: MeshBuilder, fine: MeshBuilder, n: int) -> void:
	var bed := Ship.BED_AT
	if n >= 1:
		# an upper bunk on posts over the bed
		var y := 1.25
		for sx in [-0.55, 0.55]:
			for sz in [-1.02, 1.02]:
				mb.add_box(_m["oak"], Transform3D(Basis(), bed + Vector3(sx, (y + 0.2) * 0.5, sz)), Vector3(0.08, y + 0.2, 0.08), 1.0)
		mb.add_box(_m["oak"], Transform3D(Basis(), bed + Vector3(0, y, 0)), Vector3(1.15, 0.12, 2.1), 1.0, Color.WHITE, false)
		mb.add_box(_m["linen"], Transform3D(Basis(), bed + Vector3(0, y + 0.12, 0)), Vector3(1.0, 0.12, 1.95), 1.0)
		mb.add_box(_m["blanket"], Transform3D(Basis(), bed + Vector3(0, y + 0.19, -0.3)), Vector3(1.04, 0.05, 1.25), 1.0)
		_count("galley")
	if n >= 2:
		# an oven beside the stove, pots hung over the counter, a chimney up through the quarterdeck
		var st := Ship.STOVE_AT
		mb.add_box(_m["dark_iron"], Transform3D(Basis(), st + Vector3(-0.1, 0.35, -0.85)), Vector3(0.8, 0.7, 0.6), 1.0)
		mb.add_box(_m["glass"], Transform3D(Basis(), st + Vector3(-0.51, 0.3, -0.85)), Vector3(0.04, 0.22, 0.34), 1.0)
		var ct := Ship.COUNTER_AT
		mb.add_box(_m["oak"], Transform3D(Basis(), ct + Vector3(0, 1.85, 0)), Vector3(0.08, 0.08, 1.4), 1.0)
		for k in range(3):
			var z := -0.5 + k * 0.5
			HullBuilder._line(fine, _m["dark_iron"], ct + Vector3(0, 1.83, z), ct + Vector3(0, 1.6, z), 0.02)
			fine.add_cylinder(_m["dark_iron"], Transform3D(Basis(), ct + Vector3(0, 1.36, z)), 0.13, 0.15, 0.24, 7, 1.0, Color.WHITE, false, true)
		var pipe := Vector3(st.x + 0.1, HullBuilder.QD_Y, st.z + 0.1)
		mb.add_cylinder(_m["dark_iron"], Transform3D(Basis(), pipe), 0.13, 0.11, 1.35, 7, 1.0)
		mb.add_box(_m["dark_iron"], Transform3D(Basis(), pipe + Vector3(0, 1.42, 0)), Vector3(0.36, 0.06, 0.36), 1.0)
		_solid(pipe + Vector3(0, 0.67, 0), Vector3(0.28, 1.35, 0.28))
		_count("galley")
	if n >= 3:
		# hammocks slung under the beams to starboard, one rolled and stowed
		for k in range(2):
			var x := 1.2 + k * 1.15
			var a := Vector3(x, HullBuilder.QD_Y - 0.35, 6.2)
			var b := Vector3(x, HullBuilder.QD_Y - 0.35, 7.6)
			var pts := MeshBuilder.sag_points(a, b, 0.45, 6)
			for i in range(pts.size() - 1):
				var d: Vector3 = pts[i + 1] - pts[i]
				mb.add_box(_m["canvas"], Transform3D(Basis.looking_at(d.normalized(), Vector3.UP), (pts[i] + pts[i + 1]) * 0.5), Vector3(0.62, 0.04, d.length() + 0.02), 1.0)
			HullBuilder._line(mb, _m["rope"], a, a + Vector3(0, 0.15, 0), 0.03)
			HullBuilder._line(mb, _m["rope"], b, b + Vector3(0, 0.15, 0), 0.03)
		mb.add_cylinder(_m["canvas"], Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(-1.6, HullBuilder.QD_Y - 0.4, 6.4)), 0.12, 0.12, 1.2, 6, 1.0)
		_count("galley")


# --------------------------------------------------------------------------
# Ship's hold: the storage chest bound in iron, sea chests, a cargo hatch on deck
# --------------------------------------------------------------------------
func _hold(mb: MeshBuilder, fine: MeshBuilder, n: int) -> void:
	var sc := Ship.STORAGE_AT
	if n >= 1:
		for x in [-0.32, 0.32]:
			mb.add_box(_m["dark_iron"], Transform3D(Basis(), sc + Vector3(x, 0.33, 0)), Vector3(0.07, 0.68, 0.72), 1.0)
		fine.add_box(_m["brass"], Transform3D(Basis(), sc + Vector3(0, 0.42, -0.37)), Vector3(0.14, 0.16, 0.04), 1.0)
		_count("chest")
	if n >= 2:
		# [where, turned across (true) or along]
		for e in [[Ship.BED_AT + Vector3(0, 0, -1.45), false], [Ship.COUNTER_AT + Vector3(-0.85, 0, -1.25), true]]:
			var at: Vector3 = e[0]
			var b := Basis(Vector3.UP, PI * 0.5 if e[1] else 0.0)
			mb.add_box(_m["roof"], Transform3D(b, at + Vector3(0, 0.22, 0)), Vector3(0.9, 0.44, 0.5), 1.0)
			mb.add_box(_m["trim"], Transform3D(b, at + Vector3(0, 0.46, 0)), Vector3(0.94, 0.06, 0.54), 1.0)
			for x in [-0.3, 0.3]:
				mb.add_box(_m["dark_iron"], Transform3D(b, at + b * Vector3(x, 0.24, 0)), Vector3(0.05, 0.47, 0.53), 1.0)
			_solid(at + Vector3(0, 0.22, 0), Vector3(0.5, 0.44, 0.9) if e[1] else Vector3(0.9, 0.44, 0.5))
		_count("chest")
	if n >= 3:
		# a hatch on the main deck aft of the mast, crates lashed beside it
		var h := Vector3(0, HullBuilder.DECK_Y, 2.7)
		for sx in [-1.0, 1.0]:
			mb.add_box(_m["oak"], Transform3D(Basis(), h + Vector3(sx * 0.85, 0.08, 0)), Vector3(0.12, 0.16, 1.5), 1.0)
			mb.add_box(_m["oak"], Transform3D(Basis(), h + Vector3(0, 0.08, sx * 0.7)), Vector3(1.82, 0.16, 0.12), 1.0)
		for k in range(6):
			mb.add_box(_m["dark_iron"], Transform3D(Basis(), h + Vector3(-0.65 + k * 0.26, 0.12, 0)), Vector3(0.08, 0.04, 1.3), 1.0)
		for e in [[Vector3(-1.45, 0, 3.3), 0.25, 0.6], [Vector3(-1.5, 0, 2.25), -0.15, 0.5], [Vector3(-1.45, 0.6, 3.25), 0.5, 0.45]]:
			var at: Vector3 = h + (e[0] as Vector3)
			var s: float = e[2]
			mb.add_box(_m["trim"], Transform3D(Basis(Vector3.UP, float(e[1])), at + Vector3(0, s * 0.5, 0)), Vector3(s, s, s), 1.0)
		HullBuilder._line(mb, _m["rope"], h + Vector3(-1.8, 0.62, 3.1), h + Vector3(-1.1, 0.62, 3.5), 0.03)
		_solid(h + Vector3(-1.47, 0.45, 2.8), Vector3(0.75, 0.9, 1.7))
		_count("chest")
