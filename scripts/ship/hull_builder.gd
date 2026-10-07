class_name HullBuilder
extends RefCounted
## The ship's layout, model and collision, shared by the crew's ship and the
## pirates' (so boarding, cannons and the Sea King work the same on both).
## Ship-local: stern at +Z, bow at -Z, the main deck at DECK_Y.
##
## A ~23 m sloop: the main deck from the bow to the raised quarterdeck at the
## stern, which roofs the crew cabin (a door in its front wall, stairs up on
## both sides). The mast carries a crow's nest above the yard, reached up the
## rigging (shrouds with ratlines) from either rail.

const DECK_Y := 0.32
## Hull cross-sections along Z: [z, top half-width, bottom half-width, top y, bottom y].
## Ring 0 to 1 is the quarterdeck's length.
const RINGS := [
	[9.9, 4.05, 2.25, 0.35, -2.4],
	[5.0, 4.4, 2.4, 0.25, -2.85],
	[-3.0, 4.4, 2.25, 0.25, -2.85],
	[-8.25, 3.6, 1.5, 0.4, -2.55],
	[-12.6, 0.38, 0.15, 1.0, -1.35],
]
## Origin height above the (averaged) water: the main deck stands ~1.8 m clear.
const FREEBOARD := 1.45
## Where the swell is sampled (bow, stern, either side).
const BOW_Z := -8.7
const STERN_Z := 8.7
const HALF_BEAM := 4.0
## The quarterdeck: from QD_FRONT aft, its floor at QD_Y.
const QD_FRONT := 5.0
const QD_BACK := 9.9
const QD_Y := DECK_Y + 2.4
## The cabin under it: walls at +-CABIN_HW, a door 2*DOOR_HW wide.
const CABIN_HW := 3.95
const DOOR_HW := 0.65
const DOOR_H := 2.05
## Stairs up to the quarterdeck, either side of the cabin front (x from
## STAIR_X0 to CABIN_HW), from STAIR_Z0 on the main deck to QD_FRONT.
const STAIR_X0 := 2.75
const STAIR_Z0 := 1.4
const STAIR_STEPS := 8
## The wheel and where the helmsman stands (on the quarterdeck).
const WHEEL_Z := 6.6
const HELM_Z := 7.4
## Mast, yard, crow's nest.
const MAST_Z := -1.8
const MAST_TOP := 16.8
const YARD_Y := 13.8
const NEST_Y := 15.0
## (room to walk round the mast: it's ~0.2 m thick up there)
const NEST_R := 1.6
## Rigging: on each side the ratlines run from the rail (bottom) up to the
## nest's edge (top). +x side; the port side mirrors it.
const RIG_BOTTOM := Vector3(3.75, DECK_Y + 0.85, MAST_Z)
const RIG_TOP := Vector3(1.5, NEST_Y + 0.05, MAST_Z)
## The bulwark above the hull's top edge (rail height over the sheer).
const LIP := 0.45
## Rope ladders down the hull from the water, amidships.
const LADDER_Z := -2.9
const LADDER_LEN := 3.0

static var _jolly_tex: ImageTexture
static var _jolly_mat: ShaderMaterial
static var _marine_mat: ShaderMaterial


## Half the deck's width at `z` (ship-local).
static func half_width(z: float) -> float:
	for i in range(RINGS.size() - 1):
		var a: Array = RINGS[i]
		var b: Array = RINGS[i + 1]
		if z <= float(a[0]) and z >= float(b[0]):
			var t := (float(a[0]) - z) / (float(a[0]) - float(b[0]))
			return lerpf(float(a[1]), float(b[1]), t)
	return 0.45


## Inside the ship's bounds (ship-local): on a deck, in the cabin, in the
## rigging or the nest, on a ladder, jumping about over the deck.
static func aboard_local(l: Vector3) -> bool:
	return absf(l.x) < 4.9 and l.z > -14.0 and l.z < 10.6 and l.y > -1.4 and l.y < MAST_TOP + 1.5


## Under the quarterdeck (in the cabin).
static func in_cabin(l: Vector3) -> bool:
	return absf(l.x) < CABIN_HW and l.z > QD_FRONT and l.z < QD_BACK and l.y < QD_Y - 0.3 and l.y > -0.5


## The hull, decks, quarterdeck and cabin walls, stairs, and (rig) the mast,
## crow's nest and rigging into `mb`. mats: hull, deck, trim, wood, rope.
static func hull(mb: MeshBuilder, m: Dictionary, rig: bool = true) -> void:
	var hull_m: Material = m["hull"]
	var deck_m: Material = m["deck"]
	var trim: Material = m["trim"]
	var wood: Material = m["wood"]
	var rope: Material = m["rope"]
	for i in range(RINGS.size() - 1):
		var a: Array = RINGS[i]
		var b: Array = RINGS[i + 1]
		# the outside runs on up past the deck to the rail (the stern castle has its own)
		var lip := LIP if i > 0 else 0.0
		var a_tl := Vector3(-a[1], a[3] + lip, a[0]); var a_bl := Vector3(-a[2], a[4], a[0])
		var a_tr := Vector3(a[1], a[3] + lip, a[0]); var a_br := Vector3(a[2], a[4], a[0])
		var b_tl := Vector3(-b[1], b[3] + lip, b[0]); var b_bl := Vector3(-b[2], b[4], b[0])
		var b_tr := Vector3(b[1], b[3] + lip, b[0]); var b_br := Vector3(b[2], b[4], b[0])
		mb.add_quad(hull_m, a_tl, a_bl, b_bl, b_tl, _side_uv(a_tl), _side_uv(a_bl), _side_uv(b_bl), _side_uv(b_tl), Color.WHITE, Vector3(-1, -0.3, 0).normalized())
		mb.add_quad(hull_m, a_tr, b_tr, b_br, a_br, _side_uv(a_tr), _side_uv(b_tr), _side_uv(b_br), _side_uv(a_br), Color.WHITE, Vector3(1, -0.3, 0).normalized())
		mb.add_quad(hull_m, a_bl, a_br, b_br, b_bl, _plank_uv(a_bl), _plank_uv(a_br), _plank_uv(b_br), _plank_uv(b_bl), Color(0.7, 0.7, 0.7), Vector3.DOWN)
		_deck_quad(mb, deck_m, Vector3(-a[1] + 0.1, DECK_Y, a[0]), Vector3(a[1] - 0.1, DECK_Y, a[0]), Vector3(b[1] - 0.1, DECK_Y, b[0]), Vector3(-b[1] + 0.1, DECK_Y, b[0]), Color.WHITE, Vector3.UP)
		if i == 0:
			# the stern castle: the hull's sides carry on up to the quarterdeck
			for sgn in [-1.0, 1.0]:
				var p0 := Vector3(sgn * float(a[1]), float(a[3]), float(a[0]))
				var p1 := Vector3(sgn * float(b[1]), float(b[3]), float(b[0]))
				var up := Vector3(0, QD_Y + 0.1, 0)
				var p2 := Vector3(p1.x, up.y, p1.z)
				var p3 := Vector3(p0.x, up.y, p0.z)
				mb.add_quad(hull_m, p0, p1, p2, p3, _side_uv(p0), _side_uv(p1), _side_uv(p2), _side_uv(p3), Color.WHITE, Vector3(sgn, 0, 0))
			continue
		# main deck rails (visual; the bulwarks are in collide())
		for sgn in [-1.0, 1.0]:
			var p0 := Vector3(sgn * float(a[1]), float(a[3]) + LIP, float(a[0]))
			var p1 := Vector3(sgn * float(b[1]), float(b[3]) + LIP, float(b[0]))
			var dir := p1 - p0
			mb.add_box(trim, Transform3D(Basis.looking_at(dir.normalized(), Vector3.UP), (p0 + p1) * 0.5), Vector3(0.16, 0.14, dir.length() + 0.1), 1.0)
			# solid bulwark planking under the rail
			var q0 := Vector3(sgn * (float(a[1]) - 0.04), DECK_Y, float(a[0]))
			var q1 := Vector3(sgn * (float(b[1]) - 0.04), DECK_Y, float(b[0]))
			var q2 := q1 + Vector3(0, float(b[3]) + LIP - 0.05 - DECK_Y, 0)
			var q3 := q0 + Vector3(0, float(a[3]) + LIP - 0.05 - DECK_Y, 0)
			mb.add_quad(hull_m, q0, q1, q2, q3, _side_uv(q0), _side_uv(q1), _side_uv(q2), _side_uv(q3), Color(0.8, 0.8, 0.8), Vector3(-sgn, 0, 0))
	# the transom, up to the quarterdeck rail
	var st: Array = RINGS[0]
	mb.add_quad(hull_m, Vector3(-st[1], QD_Y + 0.1, st[0]), Vector3(st[1], QD_Y + 0.1, st[0]), Vector3(st[2], st[4], st[0]), Vector3(-st[2], st[4], st[0]),
		Vector2(0, 0), Vector2(4.0, 0), Vector2(3.0, 2.6), Vector2(1.0, 2.6), Color.WHITE, Vector3.BACK)
	# the bow: the sides meet at a stem post (closed outside and in, the rail across)
	var bw: Array = RINGS[RINGS.size() - 1]
	var bz := float(bw[0])
	var btop := float(bw[3]) + LIP
	var f0 := Vector3(-bw[1], btop, bz); var f1 := Vector3(bw[1], btop, bz)
	var f2 := Vector3(bw[2], bw[4], bz); var f3 := Vector3(-bw[2], bw[4], bz)
	mb.add_quad(hull_m, f0, f1, f2, f3, Vector2(0, 0), Vector2(0.4, 0), Vector2(0.4, 1.4), Vector2(0, 1.4), Color.WHITE, Vector3.FORWARD)
	mb.add_quad(hull_m, Vector3(-bw[1] + 0.04, DECK_Y, bz + 0.03), Vector3(bw[1] - 0.04, DECK_Y, bz + 0.03), Vector3(bw[1] - 0.04, btop - 0.05, bz + 0.03), Vector3(-bw[1] + 0.04, btop - 0.05, bz + 0.03),
		Vector2(0, 0), Vector2(0.4, 0), Vector2(0.4, 0.5), Vector2(0, 0.5), Color(0.8, 0.8, 0.8), Vector3.BACK)
	mb.add_box(trim, Transform3D(Basis(), Vector3(0, btop, bz - 0.02)), Vector3(float(bw[1]) * 2.0 + 0.2, 0.14, 0.2), 1.0)
	mb.add_box(trim, Transform3D(Basis(), Vector3(0, (btop + 0.1 + float(bw[4])) * 0.5, bz - 0.08)), Vector3(0.26, btop + 0.1 - float(bw[4]), 0.16), 1.0)
	for z in [-9.5, -6.0, -3.0, 0.0, 3.0]:
		for sgn in [-1.0, 1.0]:
			mb.add_box(trim, Transform3D(Basis(), Vector3(sgn * (half_width(z) - 0.02), DECK_Y + 0.3, z)), Vector3(0.14, 0.6, 0.14), 1.0)
	_quarterdeck(mb, m)
	_stairs(mb, m)
	# bowsprit
	mb.add_cylinder(wood, Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-70)), Vector3(0, 1.05, -12.3)), 0.15, 0.09, 4.5, 6, 0.8)
	if not rig:
		return
	# the mast, the crow's nest at its head, and the rigging up to it
	mb.add_cylinder(wood, Transform3D(Basis(), Vector3(0, DECK_Y - 0.02, MAST_Z)), 0.3, 0.17, MAST_TOP - DECK_Y, 8, 0.8)
	mb.add_cylinder(wood, Transform3D(Basis(), Vector3(0, NEST_Y - 0.12, MAST_Z)), NEST_R, NEST_R, 0.14, 12, 1.0, Color.WHITE, true, true)
	for k in nest_rail():
		mb.add_box(trim, Transform3D(Basis(Vector3.UP, -float(k)), nest_rail_at(float(k))), Vector3(0.08, 0.9, NEST_R * 0.55), 1.0)
	for sgn in [-1.0, 1.0]:
		var bot := Vector3(sgn * RIG_BOTTOM.x, RIG_BOTTOM.y, RIG_BOTTOM.z)
		var top := Vector3(sgn * RIG_TOP.x, RIG_TOP.y, RIG_TOP.z)
		# three shrouds fanning out at the rail, ratlines across them
		for dz in [-0.55, 0.0, 0.55]:
			_line(mb, rope, bot + Vector3(0, -0.4, dz * 1.6), Vector3(top.x, MAST_TOP - 0.5, top.z + dz * 0.2), 0.045)
		var n := int((top.y - bot.y) / 0.42)
		for r in range(1, n):
			var k := float(r) / n
			var c := bot.lerp(top, k)
			var w := lerpf(0.55 * 1.6, 0.25, k)
			_line(mb, rope, c + Vector3(0, 0, -w), c + Vector3(0, 0, w), 0.035)
		# a forestay-ish line to the bow and a backstay to the quarterdeck
		_line(mb, rope, Vector3(sgn * 0.1, MAST_TOP - 0.3, MAST_Z), Vector3(sgn * 0.1, 1.5, -12.0), 0.04)
		_line(mb, rope, Vector3(sgn * 0.1, MAST_TOP - 0.3, MAST_Z), Vector3(sgn * 3.6, QD_Y + 0.8, QD_BACK - 0.4), 0.04)


## Angles of the crow's nest rail's boards (a gap each side for the ratlines).
static func nest_rail() -> Array:
	var out: Array = []
	for k in range(12):
		var a := TAU * (k + 0.5) / 12.0
		if absf(cos(a)) < 0.95:
			out.append(a)
	return out


static func nest_rail_at(a: float) -> Vector3:
	return Vector3(cos(a) * (NEST_R - 0.05), NEST_Y + 0.45, MAST_Z + sin(a) * (NEST_R - 0.05))


## Deck planking mapped by position: boards run fore and aft, 0.25 m wide.
static func _plank_uv(p: Vector3) -> Vector2:
	return Vector2(-p.z * 0.25, p.x * 0.5)


## Side planking mapped by position: strakes run fore and aft, 0.25 m high.
static func _side_uv(p: Vector3) -> Vector2:
	return Vector2(p.z * 0.25, -p.y * 0.5)


static func _deck_quad(mb: MeshBuilder, mat: Material, a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color, n: Vector3) -> void:
	mb.add_quad(mat, a, b, c, d, _plank_uv(a), _plank_uv(b), _plank_uv(c), _plank_uv(d), col, n)


## A rope (thin box) from a to b.
static func _line(mb: MeshBuilder, mat: Material, a: Vector3, b: Vector3, w: float) -> void:
	var d := b - a
	if d.length() < 0.01:
		return
	var up := Vector3.UP if absf(d.normalized().y) < 0.95 else Vector3.FORWARD
	mb.add_box(mat, Transform3D(Basis.looking_at(d.normalized(), up), (a + b) * 0.5), Vector3(w, w, d.length()), 2.0, Color.WHITE, false, false)


## The cabin's front wall (a door in the middle), its sides, the quarterdeck
## floor over it (the cabin ceiling under it), and the quarterdeck's rails.
static func _quarterdeck(mb: MeshBuilder, m: Dictionary) -> void:
	var hull_m: Material = m["hull"]
	var deck_m: Material = m["deck"]
	var trim: Material = m["trim"]
	var wall_h := QD_Y - DECK_Y
	var wy := DECK_Y + wall_h * 0.5
	var zf := QD_FRONT
	# front wall: either side of the door, and the lintel over it
	var side_w := CABIN_HW - DOOR_HW
	for sgn in [-1.0, 1.0]:
		mb.add_box(trim, Transform3D(Basis(), Vector3(sgn * (DOOR_HW + side_w * 0.5), wy, zf + 0.06)), Vector3(side_w, wall_h, 0.12), 0.6, Color.WHITE, true, true)
		# door posts
		mb.add_box(hull_m, Transform3D(Basis(), Vector3(sgn * (DOOR_HW + 0.06), DECK_Y + DOOR_H * 0.5, zf - 0.02)), Vector3(0.14, DOOR_H, 0.16), 1.0)
		# the cabin's side walls, inside the stern castle
		mb.add_box(trim, Transform3D(Basis(), Vector3(sgn * (CABIN_HW + 0.06), wy, (zf + QD_BACK) * 0.5)), Vector3(0.12, wall_h, QD_BACK - zf), 0.6, Color.WHITE, true, true)
	mb.add_box(trim, Transform3D(Basis(), Vector3(0, DECK_Y + DOOR_H + (wall_h - DOOR_H) * 0.5, zf + 0.06)), Vector3(DOOR_HW * 2.0, wall_h - DOOR_H, 0.12), 0.6, Color.WHITE, true, true)
	# the stern wall inside (the transom only faces out)
	mb.add_box(trim, Transform3D(Basis(), Vector3(0, wy, QD_BACK - 0.1)), Vector3(CABIN_HW * 2.0, wall_h, 0.1), 0.6, Color.WHITE, true, true)
	mb.add_box(hull_m, Transform3D(Basis(), Vector3(0, DECK_Y + DOOR_H + 0.05, zf - 0.02)), Vector3(DOOR_HW * 2.0 + 0.3, 0.12, 0.16), 1.0)
	# the quarterdeck: its floor (hull-wide), a lip along its front edge, the ceiling under it
	var hf := half_width(zf)
	var hb := half_width(QD_BACK)
	_deck_quad(mb, deck_m, Vector3(-hf + 0.05, QD_Y, zf), Vector3(hf - 0.05, QD_Y, zf), Vector3(hb - 0.05, QD_Y, QD_BACK), Vector3(-hb + 0.05, QD_Y, QD_BACK), Color.WHITE, Vector3.UP)
	_deck_quad(mb, deck_m, Vector3(-CABIN_HW, QD_Y - 0.12, zf), Vector3(CABIN_HW, QD_Y - 0.12, zf), Vector3(CABIN_HW, QD_Y - 0.12, QD_BACK), Vector3(-CABIN_HW, QD_Y - 0.12, QD_BACK), Color(0.6, 0.6, 0.6), Vector3.DOWN)
	mb.add_box(hull_m, Transform3D(Basis(), Vector3(0, QD_Y - 0.06, zf - 0.04)), Vector3(hf * 2.0, 0.16, 0.12), 1.0, Color.WHITE, false, false)
	# beams under the ceiling
	for z in [6.2, 7.6, 9.0]:
		mb.add_box(hull_m, Transform3D(Basis(), Vector3(0, QD_Y - 0.2, z)), Vector3(CABIN_HW * 2.0, 0.16, 0.18), 1.0, Color.WHITE, false, false)
	# quarterdeck rails: round the sides and stern, and along its front edge
	# between the stairheads
	for sgn in [-1.0, 1.0]:
		var p0 := Vector3(sgn * (hf - 0.02), QD_Y + 0.8, zf)
		var p1 := Vector3(sgn * (hb - 0.02), QD_Y + 0.8, QD_BACK)
		var d := p1 - p0
		mb.add_box(trim, Transform3D(Basis.looking_at(d.normalized(), Vector3.UP), (p0 + p1) * 0.5), Vector3(0.14, 0.12, d.length() + 0.1), 1.0)
		for k in range(4):
			var p := p0.lerp(p1, (k + 0.5) / 4.0)
			mb.add_box(trim, Transform3D(Basis(), Vector3(p.x, QD_Y + 0.4, p.z)), Vector3(0.1, 0.8, 0.1), 1.0)
	mb.add_box(trim, Transform3D(Basis(), Vector3(0, QD_Y + 0.8, QD_BACK - 0.05)), Vector3(hb * 2.0, 0.12, 0.14), 1.0)
	mb.add_box(trim, Transform3D(Basis(), Vector3(0, QD_Y + 0.8, zf + 0.05)), Vector3(STAIR_X0 * 2.0, 0.12, 0.12), 1.0)
	for x in [-2.6, -1.3, 0.0, 1.3, 2.6]:
		mb.add_box(trim, Transform3D(Basis(), Vector3(x, QD_Y + 0.4, zf + 0.05)), Vector3(0.1, 0.8, 0.1), 1.0)
		mb.add_box(trim, Transform3D(Basis(), Vector3(x * 1.4, QD_Y + 0.4, QD_BACK - 0.05)), Vector3(0.1, 0.8, 0.1), 1.0)


## Stairs up to the quarterdeck, port and starboard of the cabin door.
static func _stairs(mb: MeshBuilder, m: Dictionary) -> void:
	var hull_m: Material = m["hull"]
	var deck_m: Material = m["deck"]
	var trim: Material = m["trim"]
	var run := QD_FRONT - STAIR_Z0
	var rise := QD_Y - DECK_Y
	var w := CABIN_HW - STAIR_X0
	for sgn in [-1.0, 1.0]:
		var cx: float = sgn * (STAIR_X0 + w * 0.5)
		var x0: float = sgn * STAIR_X0
		var x1: float = sgn * CABIN_HW
		var tread := run / STAIR_STEPS
		for i in range(STAIR_STEPS):
			var z0 := STAIR_Z0 + tread * i
			var y0 := DECK_Y + rise * i / STAIR_STEPS
			var y1 := DECK_Y + rise * (i + 1) / STAIR_STEPS
			# a tread board (a little nosing over the riser) and the riser under it
			mb.add_box(deck_m, Transform3D(Basis(), Vector3(cx, y1 - 0.04, z0 + tread * 0.5 - 0.03)), Vector3(w, 0.08, tread + 0.06), 0.5)
			var r0 := Vector3(x0, y0, z0); var r1 := Vector3(x1, y0, z0)
			var r2 := Vector3(x1, y1 - 0.08, z0); var r3 := Vector3(x0, y1 - 0.08, z0)
			mb.add_quad(hull_m, r0, r1, r2, r3, Vector2(r0.x * 0.25, -r0.y * 0.5), Vector2(r1.x * 0.25, -r1.y * 0.5), Vector2(r2.x * 0.25, -r2.y * 0.5), Vector2(r3.x * 0.25, -r3.y * 0.5), Color(0.75, 0.75, 0.75), Vector3.FORWARD)
			# the stringers' stepped edge either side
			for x in [x0, x1]:
				var o: float = signf(x - cx)
				var s0 := Vector3(x, y0, z0); var s1 := Vector3(x, y1, z0); var s2 := Vector3(x, y1, z0 + tread)
				mb.add_tri(hull_m, s0, s1, s2, Vector3(o, 0, 0), Vector3(o, 0, 0), Vector3(o, 0, 0), _side_uv(s0), _side_uv(s1), _side_uv(s2), Color(0.85, 0.85, 0.85), Vector3(o, 0, 0))
		# the stringers: solid under the line of the steps
		for x in [x0, x1]:
			var o: float = signf(x - cx)
			var s0 := Vector3(x, DECK_Y, STAIR_Z0); var s1 := Vector3(x, DECK_Y, QD_FRONT); var s2 := Vector3(x, QD_Y, QD_FRONT)
			mb.add_tri(hull_m, s0, s1, s2, Vector3(o, 0, 0), Vector3(o, 0, 0), Vector3(o, 0, 0), _side_uv(s0), _side_uv(s1), _side_uv(s2), Color(0.85, 0.85, 0.85), Vector3(o, 0, 0))
		# a hand rail up the inner side
		var a := Vector3(sgn * (STAIR_X0 - 0.05), DECK_Y + 0.9, STAIR_Z0 + 0.2)
		var b := Vector3(sgn * (STAIR_X0 - 0.05), QD_Y + 0.8, QD_FRONT)
		_line(mb, trim, a, b, 0.08)
		for k in [0.15, 0.55]:
			var p := a.lerp(b, k)
			mb.add_box(trim, Transform3D(Basis(), Vector3(p.x, (p.y + DECK_Y + rise * k) * 0.5 - 0.05, p.z)), Vector3(0.08, p.y - (DECK_Y + rise * k) + 0.1, 0.08), 1.0)


## The enemies' (and wrecks') whole model under `parent`. opts: hull (Color),
## sail (Color), trim (Color), emblem ("jolly": skull and crossbones on the
## sail and flag, "marine": the Marines' blue gull; the node is "Jolly" either
## way), wreck (bool: a broken hulk - mast snapped, no sail, flag or lights).
static func build(parent: Node3D, opts: Dictionary = {}) -> Node3D:
	var mb := MeshBuilder.new()
	var mats := {
		"hull": PSXMat.lit("planks_dark", opts.get("hull", Color.WHITE), {"affine": 0.6}),
		"deck": PSXMat.lit("planks", opts.get("deck", Color.WHITE), {"affine": 0.6}),
		"trim": PSXMat.lit("planks", opts.get("trim", Color(0.85, 0.65, 0.35))),
		"wood": PSXMat.lit("bark"),
		"rope": PSXMat.lit("rope"),
	}
	var canvas := PSXMat.lit("canvas", opts.get("sail", Color(0.95, 0.92, 0.82)), {"affine": 0.6})
	var canvas_back := PSXMat.lit("canvas", (opts.get("sail", Color(0.95, 0.92, 0.82)) as Color).darkened(0.2), {"affine": 0.6})
	var flag := PSXMat.lit("cloth_red", opts.get("flag", Color.WHITE))
	var glass := PSXMat.glow(Color(1.0, 0.8, 0.4), 2.5)
	var wood: Material = mats["wood"]
	var trim: Material = mats["trim"]
	if bool(opts.get("wreck", false)):
		# a wreck: the hull and cabin, the mast snapped off short, no canvas or colours
		var w := MeshBuilder.new()
		_wreck_hull(w, mats)
		w.add_cylinder(wood, Transform3D(Basis(Vector3.BACK, 0.25), Vector3(0, DECK_Y, MAST_Z)), 0.3, 0.22, 5.0, 6, 0.8)
		var winst := w.to_instance("PSXModel")
		parent.add_child(winst)
		return winst
	hull(mb, mats)
	# yard and sail (two panels, both faces), flag
	mb.add_cylinder(wood, Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(4.5, YARD_Y, MAST_Z)), 0.12, 0.12, 9.0, 6, 0.8)
	var sz := MAST_Z + 0.25
	var sn := Vector3(0, 0, 1)
	var top_y := YARD_Y - 0.15
	var mid_y := top_y - 4.35
	var bot_y := mid_y - 4.2
	mb.add_quad(canvas, Vector3(-4.2, top_y, sz), Vector3(4.2, top_y, sz), Vector3(3.9, mid_y, sz + 0.45), Vector3(-3.9, mid_y, sz + 0.45),
		Vector2(0, 0), Vector2(2.0, 0), Vector2(2.0, 1.0), Vector2(0, 1.0), Color.WHITE, sn)
	mb.add_quad(canvas, Vector3(-3.9, mid_y, sz + 0.45), Vector3(3.9, mid_y, sz + 0.45), Vector3(3.6, bot_y, sz + 0.1), Vector3(-3.6, bot_y, sz + 0.1),
		Vector2(0, 1.0), Vector2(2.0, 1.0), Vector2(2.0, 2.0), Vector2(0, 2.0), Color.WHITE, sn)
	mb.add_quad(canvas_back, Vector3(-4.2, top_y, sz), Vector3(-3.9, mid_y, sz + 0.45), Vector3(3.9, mid_y, sz + 0.45), Vector3(4.2, top_y, sz),
		Vector2(0, 0), Vector2(0, 1.0), Vector2(2.0, 1.0), Vector2(2.0, 0), Color.WHITE, -sn)
	mb.add_quad(canvas_back, Vector3(-3.9, mid_y, sz + 0.45), Vector3(-3.6, bot_y, sz + 0.1), Vector3(3.6, bot_y, sz + 0.1), Vector3(3.9, mid_y, sz + 0.45),
		Vector2(0, 1.0), Vector2(0, 2.0), Vector2(2.0, 2.0), Vector2(2.0, 1.0), Color.WHITE, -sn)
	mb.add_card(flag, Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(0, MAST_TOP + 0.2, MAST_Z + 0.45)), 1.35, 0.75, Rect2(0, 0, 0.5, 0.5))
	mb.add_card(flag, Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(0, MAST_TOP + 0.2, MAST_Z + 0.45)), 1.35, 0.75, Rect2(0, 0, 0.5, 0.5))
	# cabin windows by the door, a stern lantern
	mb.add_box(glass, Transform3D(Basis(), Vector3(2.0, DECK_Y + 1.5, QD_FRONT - 0.02)), Vector3(0.4, 0.4, 0.06), 1.0)
	mb.add_box(glass, Transform3D(Basis(), Vector3(-2.0, DECK_Y + 1.5, QD_FRONT - 0.02)), Vector3(0.4, 0.4, 0.06), 1.0)
	mb.add_box(glass, Transform3D(Basis(), Vector3(0, QD_Y + 1.3, QD_BACK + 0.15)), Vector3(0.3, 0.4, 0.3), 1.0, Color.WHITE, false)
	# a ship's wheel (fixed) on the quarterdeck, some cargo on deck
	mb.add_box(wood, Transform3D(Basis(), Vector3(0, QD_Y + 0.45, WHEEL_Z + 0.1)), Vector3(0.16, 0.9, 0.16), 1.0)
	mb.add_cylinder(trim, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, QD_Y + 0.95, WHEEL_Z)), 0.42, 0.42, 0.06, 8, 1.0, Color.WHITE, true, true, false)
	var crate := PSXMat.lit("planks", Color(0.8, 0.65, 0.45))
	mb.add_box(crate, Transform3D(Basis(Vector3.UP, 0.3), Vector3(2.1, DECK_Y + 0.3, -0.4)), Vector3(0.6, 0.6, 0.6), 1.0)
	mb.add_box(crate, Transform3D(Basis(Vector3.UP, -0.2), Vector3(-2.2, DECK_Y + 0.25, -4.5)), Vector3(0.5, 0.5, 0.5), 1.0)
	var inst := mb.to_instance("PSXModel")
	parent.add_child(inst)
	var emblem := str(opts.get("emblem", ""))
	if emblem != "":
		var j := MeshBuilder.new()
		var jm := jolly_material() if emblem == "jolly" else marine_material()
		# on the sail's front (toward the bow, -Z) and back, and both sides of the flag
		var ey := (top_y + bot_y) * 0.5 - 2.2
		j.add_card(jm, Transform3D(Basis(Vector3.UP, PI), Vector3(0, ey, sz + 0.26)), 4.5, 4.5, Rect2(0, 0, 1, 1))
		j.add_card(jm, Transform3D(Basis.IDENTITY, Vector3(0, ey, sz + 0.5)), 4.5, 4.5, Rect2(0, 0, 1, 1))
		j.add_card(jm, Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(0.01, MAST_TOP + 0.2, MAST_Z + 0.45)), 1.05, 0.65, Rect2(0, 0, 1, 1))
		j.add_card(jm, Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(-0.01, MAST_TOP + 0.2, MAST_Z + 0.45)), 1.05, 0.65, Rect2(0, 0, 1, 1))
		parent.add_child(j.to_instance("Jolly"))
	return inst


## A wreck's hull: the sides, deck and quarterdeck, no rigging.
static func _wreck_hull(mb: MeshBuilder, m: Dictionary) -> void:
	hull(mb, m, false)


## A skull and crossbones (painted at runtime), white on transparent.
static func jolly_material() -> ShaderMaterial:
	if _jolly_mat:
		return _jolly_mat
	var n := 64
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var white := Color(0.95, 0.93, 0.86, 1.0)
	var c := Vector2(32, 26)
	for y in range(n):
		for x in range(n):
			var p := Vector2(x, y)
			var on := false
			# cranium and jaw
			if p.distance_to(c) < 12.0:
				on = true
			if absf(x - 32) < 7 and y > 30 and y < 42:
				on = true
			# eye sockets and nose
			if p.distance_to(Vector2(27, 26)) < 3.6 or p.distance_to(Vector2(37, 26)) < 3.6:
				on = false
			if absf(x - 32) < 1.6 and y > 31 and y < 35:
				on = false
			# teeth gaps
			if y > 37 and y < 42 and (x == 29 or x == 32 or x == 35):
				on = false
			# crossbones under it
			for s in [-1.0, 1.0]:
				var a := Vector2(14, 46 if s > 0 else 58)
				var b := Vector2(50, 58 if s > 0 else 46)
				var t := clampf((p - a).dot(b - a) / (b - a).length_squared(), 0.0, 1.0)
				if p.distance_to(a.lerp(b, t)) < 2.6:
					on = true
				for e in [a, b]:
					if p.distance_to(e + Vector2(0, -2.5)) < 2.6 or p.distance_to(e + Vector2(0, 2.5)) < 2.6:
						on = true
			if on:
				img.set_pixel(x, y, white)
	_jolly_tex = ImageTexture.create_from_image(img)
	var m := ShaderMaterial.new()
	m.shader = PSXMat.CUTOUT_SHADER
	m.set_shader_parameter("albedo_tex", _jolly_tex)
	m.set_shader_parameter("albedo_color", Color.WHITE)
	m.set_shader_parameter("wind_strength", 0.0)
	m.set_shader_parameter("sway_height", 1.0)
	_jolly_mat = m
	return m


## The Marines' seagull (painted at runtime), blue on transparent.
static func marine_material() -> ShaderMaterial:
	if _marine_mat:
		return _marine_mat
	var n := 64
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var blue := Color(0.16, 0.3, 0.62, 1.0)
	for y in range(n):
		for x in range(n):
			var on := false
			# two swept wings meeting at the body
			for cx: float in [21.0, 43.0]:
				var u := (x - cx) / 13.0
				if absf(u) <= 1.0:
					var wy := 24.0 + 9.0 * u * u * (1.0 if (x - cx) * (cx - 32.0) > 0.0 else 0.35)
					if absf(y - wy) < 2.8 - absf(u) * 1.2:
						on = true
			# body and head
			if Vector2(x, y).distance_to(Vector2(32, 30)) < 3.6 or Vector2(x, y).distance_to(Vector2(32, 25)) < 2.4:
				on = true
			# a bar of "MARINE" blue under it
			if y > 44 and y < 49 and x > 14 and x < 50:
				on = true
			if on:
				img.set_pixel(x, y, blue)
	var m := ShaderMaterial.new()
	m.shader = PSXMat.CUTOUT_SHADER
	m.set_shader_parameter("albedo_tex", ImageTexture.create_from_image(img))
	m.set_shader_parameter("albedo_color", Color.WHITE)
	m.set_shader_parameter("wind_strength", 0.0)
	m.set_shader_parameter("sway_height", 1.0)
	_marine_mat = m
	return m


## Collision for the hull (call on the body): the hull volume under the main
## deck, waist-high bulwarks, the cabin (walls, a doorway), the quarterdeck
## and its rails, the stairs, and (rig) the mast and the crow's nest.
static func collide(body: CollisionObject3D, rig: bool = true) -> void:
	var pts := PackedVector3Array()
	for r in RINGS:
		for sgn in [-1.0, 1.0]:
			pts.append(Vector3(sgn * float(r[1]), DECK_Y, float(r[0])))
			pts.append(Vector3(sgn * float(r[2]), float(r[4]), float(r[0])))
	var hull_shape := ConvexPolygonShape3D.new()
	hull_shape.points = pts
	_shape(body, hull_shape, Transform3D.IDENTITY)
	# main deck bulwarks (waist high: jump to get over the side)
	for i in range(1, RINGS.size() - 1):
		var a: Array = RINGS[i]
		var b: Array = RINGS[i + 1]
		for sgn in [-1.0, 1.0]:
			_box(body, Vector3(sgn * (float(a[1]) - 0.05), DECK_Y + 0.4, float(a[0])), Vector3(sgn * (float(b[1]) - 0.05), DECK_Y + 0.4, float(b[0])), 0.18, 0.8)
	var bw: Array = RINGS[RINGS.size() - 1]
	_cbox(body, Vector3(0, DECK_Y + 0.4, float(bw[0])), Vector3(float(bw[1]) * 2.0 + 0.3, 0.8, 0.2))
	var wall_h := QD_Y - DECK_Y
	var wy := DECK_Y + wall_h * 0.5
	var zf := QD_FRONT
	# the cabin: front wall either side of the doorway, the lintel, the sides (out to the hull), the stern
	var side_w := CABIN_HW - DOOR_HW
	for sgn in [-1.0, 1.0]:
		_cbox(body, Vector3(sgn * (DOOR_HW + side_w * 0.5), wy, zf + 0.06), Vector3(side_w, wall_h, 0.14))
		_cbox(body, Vector3(sgn * (CABIN_HW + 0.3), wy, (zf + QD_BACK) * 0.5), Vector3(0.6, wall_h, QD_BACK - zf))
	_cbox(body, Vector3(0, DECK_Y + DOOR_H + (wall_h - DOOR_H) * 0.5, zf + 0.06), Vector3(DOOR_HW * 2.0, wall_h - DOOR_H, 0.14))
	_cbox(body, Vector3(0, wy, QD_BACK - 0.08), Vector3(CABIN_HW * 2.0 + 0.6, wall_h, 0.16))
	# the quarterdeck floor (a slab the shape of the hull there)
	var hf := half_width(zf)
	var hb := half_width(QD_BACK)
	var slab := ConvexPolygonShape3D.new()
	slab.points = PackedVector3Array([Vector3(-hf, QD_Y, zf), Vector3(hf, QD_Y, zf), Vector3(-hb, QD_Y, QD_BACK), Vector3(hb, QD_Y, QD_BACK),
		Vector3(-hf, QD_Y - 0.12, zf), Vector3(hf, QD_Y - 0.12, zf), Vector3(-hb, QD_Y - 0.12, QD_BACK), Vector3(hb, QD_Y - 0.12, QD_BACK)])
	_shape(body, slab, Transform3D.IDENTITY)
	# its rails: sides, stern, and the front edge between the stairheads
	for sgn in [-1.0, 1.0]:
		_box(body, Vector3(sgn * (hf - 0.05), QD_Y + 0.45, zf), Vector3(sgn * (hb - 0.05), QD_Y + 0.45, QD_BACK), 0.18, 0.9)
	_cbox(body, Vector3(0, QD_Y + 0.45, QD_BACK - 0.05), Vector3(hb * 2.0, 0.9, 0.18))
	_cbox(body, Vector3(0, QD_Y + 0.45, zf + 0.05), Vector3(STAIR_X0 * 2.0, 0.9, 0.16))
	# the stairs: a wedge each side
	for sgn in [-1.0, 1.0]:
		var x0: float = sgn * STAIR_X0
		var x1: float = sgn * CABIN_HW
		var wedge := ConvexPolygonShape3D.new()
		wedge.points = PackedVector3Array([Vector3(x0, DECK_Y, STAIR_Z0), Vector3(x1, DECK_Y, STAIR_Z0), Vector3(x0, DECK_Y, zf), Vector3(x1, DECK_Y, zf),
			Vector3(x0, QD_Y, zf), Vector3(x1, QD_Y, zf)])
		_shape(body, wedge, Transform3D.IDENTITY)
		# the hand rail along the inner side (don't step off the side mid-flight)
		_box(body, Vector3(sgn * (STAIR_X0 - 0.05), DECK_Y + 0.9, STAIR_Z0 + 0.2), Vector3(sgn * (STAIR_X0 - 0.05), QD_Y + 0.8, zf), 0.1, 0.5)
	if not rig:
		return
	# the mast and the crow's nest (floor and a rail with gaps for the rigging)
	var mast := CylinderShape3D.new()
	mast.radius = 0.28
	mast.height = MAST_TOP - DECK_Y
	_shape(body, mast, Transform3D(Basis.IDENTITY, Vector3(0, (MAST_TOP + DECK_Y) * 0.5, MAST_Z)))
	var nest := CylinderShape3D.new()
	nest.radius = NEST_R
	nest.height = 0.14
	_shape(body, nest, Transform3D(Basis.IDENTITY, Vector3(0, NEST_Y - 0.12, MAST_Z)))
	for k in nest_rail():
		var bx := BoxShape3D.new()
		bx.size = Vector3(0.1, 0.9, NEST_R * 0.6)
		_shape(body, bx, Transform3D(Basis(Vector3.UP, -float(k)), nest_rail_at(float(k))))


## A wall segment from a to b (centres), `thick` across, `tall` high.
static func _box(body: CollisionObject3D, a: Vector3, b: Vector3, thick: float, tall: float) -> void:
	var d := b - a
	var flat := Vector3(d.x, 0, d.z)
	var bx := BoxShape3D.new()
	bx.size = Vector3(thick, tall, d.length() + 0.2)
	var basis := Basis.looking_at(d.normalized(), Vector3.UP) if flat.length() > 0.01 else Basis()
	_shape(body, bx, Transform3D(basis, (a + b) * 0.5))


static func _cbox(body: CollisionObject3D, at: Vector3, size: Vector3) -> void:
	var bx := BoxShape3D.new()
	bx.size = size
	_shape(body, bx, Transform3D(Basis.IDENTITY, at))


static func _shape(body: CollisionObject3D, shape: Shape3D, xf: Transform3D) -> void:
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.transform = xf
	body.add_child(cs)
