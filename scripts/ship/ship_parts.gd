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
		"gilt": PSXMat.lit("metal", Color(1.6, 1.25, 0.5)),
		"rope": PSXMat.lit("rope"),
		"pennant": PSXMat.lit("cloth_red", Color(1.0, 0.85, 0.8)),
		"glass": PSXMat.glow(Color(1.0, 0.8, 0.45), 2.2),
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
	for c in ship.cannons:
		(c as ShipCannon).fit(lv("guns"))


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
	_guns(mb, fine, lv("guns"))
	_sails(mb, lv("sails"))
	_rudder(mb, fine, lv("rudder"))
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
		# a truck on the masthead and a long pennant streaming aft from it
		var top := Vector3(0, HullBuilder.MAST_TOP, HullBuilder.MAST_Z)
		mb.add_cylinder(_m["trim"], Transform3D(Basis(), top), 0.1, 0.07, 1.1, 6, 0.8)
		mb.add_cylinder(_m["gilt"], Transform3D(Basis(), top + Vector3(0, 1.1, 0)), 0.13, 0.13, 0.12, 6, 1.0, Color.WHITE, true, true)
		var p0 := top + Vector3(0, 1.0, 0.05)
		var p1 := top + Vector3(0, 0.62, 0.05)
		var tip := top + Vector3(0.0, 0.35, 4.6)
		for side in [Vector3.RIGHT, Vector3.LEFT]:
			mb.add_tri(_m["pennant"], p0, p1, tip, side, side, side, Vector2(0, 0), Vector2(0, 0.4), Vector2(2.0, 0.2), Color.WHITE, side)
		_count("sails")


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
