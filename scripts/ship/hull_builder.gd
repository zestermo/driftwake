class_name HullBuilder
extends RefCounted
## A ship's model and collision from its layout (HullLayout: the crew's ship's own, or base() for the pirates',
## traders' and wrecks'), so boarding, cannons and the Sea King work the same on every hull. Ship-local: stern at
## +Z, bow at -Z.
##
## A ~23 m sloop: the main deck from the bow to the raised quarterdeck at the stern, which roofs the crew cabin (a
## door in its front wall, stairs up on both sides). The mast carries a crow's nest above the yard, reached up the
## rigging (shrouds with ratlines) from either rail.

static var _jolly_tex: ImageTexture
static var _jolly_mat: ShaderMaterial
static var _marine_mat: ShaderMaterial


## The hull, decks, quarterdeck and cabin walls, stairs, and (rig) the mast,
## crow's nest and rigging into `mb`. mats: hull, deck, trim, wood, rope.
static func hull(mb: MeshBuilder, m: Dictionary, rig: bool = true, L: HullLayout = HullLayout.base()) -> void:
	var hull_m: Material = m["hull"]
	var deck_m: Material = m["deck"]
	var trim: Material = m["trim"]
	var wood: Material = m["wood"]
	var rope: Material = m["rope"]
	for i in range(L.rings.size() - 1):
		var a: Array = L.rings[i]
		var b: Array = L.rings[i + 1]
		# the outside runs on up past the deck to the rail (the stern castle has its own)
		var lip := L.lip if i > 0 else 0.0
		var a_tl := Vector3(-a[1], a[3] + lip, a[0]); var a_bl := Vector3(-a[2], a[4], a[0])
		var a_tr := Vector3(a[1], a[3] + lip, a[0]); var a_br := Vector3(a[2], a[4], a[0])
		var b_tl := Vector3(-b[1], b[3] + lip, b[0]); var b_bl := Vector3(-b[2], b[4], b[0])
		var b_tr := Vector3(b[1], b[3] + lip, b[0]); var b_br := Vector3(b[2], b[4], b[0])
		mb.add_quad(hull_m, a_tl, a_bl, b_bl, b_tl, _side_uv(a_tl), _side_uv(a_bl), _side_uv(b_bl), _side_uv(b_tl), Color.WHITE, Vector3(-1, -0.3, 0).normalized())
		mb.add_quad(hull_m, a_tr, b_tr, b_br, a_br, _side_uv(a_tr), _side_uv(b_tr), _side_uv(b_br), _side_uv(a_br), Color.WHITE, Vector3(1, -0.3, 0).normalized())
		mb.add_quad(hull_m, a_bl, a_br, b_br, b_bl, _plank_uv(a_bl), _plank_uv(a_br), _plank_uv(b_br), _plank_uv(b_bl), Color(0.7, 0.7, 0.7), Vector3.DOWN)
		_deck_quad(mb, deck_m, Vector3(-a[1] + 0.1, L.deck_y, a[0]), Vector3(a[1] - 0.1, L.deck_y, a[0]), Vector3(b[1] - 0.1, L.deck_y, b[0]), Vector3(-b[1] + 0.1, L.deck_y, b[0]), Color.WHITE, Vector3.UP)
		if i == 0:
			# the stern castle: the hull's sides carry on up to the quarterdeck
			for sgn in [-1.0, 1.0]:
				var p0 := Vector3(sgn * float(a[1]), float(a[3]), float(a[0]))
				var p1 := Vector3(sgn * float(b[1]), float(b[3]), float(b[0]))
				var up := Vector3(0, L.qd_y + 0.1, 0)
				var p2 := Vector3(p1.x, up.y, p1.z)
				var p3 := Vector3(p0.x, up.y, p0.z)
				mb.add_quad(hull_m, p0, p1, p2, p3, _side_uv(p0), _side_uv(p1), _side_uv(p2), _side_uv(p3), Color.WHITE, Vector3(sgn, 0, 0))
			continue
		# main deck rails (visual; the bulwarks are in collide())
		for sgn in [-1.0, 1.0]:
			var p0 := Vector3(sgn * float(a[1]), float(a[3]) + L.lip, float(a[0]))
			var p1 := Vector3(sgn * float(b[1]), float(b[3]) + L.lip, float(b[0]))
			var dir := p1 - p0
			mb.add_box(trim, Transform3D(Basis.looking_at(dir.normalized(), Vector3.UP), (p0 + p1) * 0.5), Vector3(0.16, 0.14, dir.length() + 0.1), 1.0)
			# solid bulwark planking under the rail
			var q0 := Vector3(sgn * (float(a[1]) - 0.04), L.deck_y, float(a[0]))
			var q1 := Vector3(sgn * (float(b[1]) - 0.04), L.deck_y, float(b[0]))
			var q2 := q1 + Vector3(0, float(b[3]) + L.lip - 0.05 - L.deck_y, 0)
			var q3 := q0 + Vector3(0, float(a[3]) + L.lip - 0.05 - L.deck_y, 0)
			mb.add_quad(hull_m, q0, q1, q2, q3, _side_uv(q0), _side_uv(q1), _side_uv(q2), _side_uv(q3), Color(0.8, 0.8, 0.8), Vector3(-sgn, 0, 0))
	# the transom, up to the quarterdeck rail
	var st: Array = L.rings[0]
	var t0 := Vector3(-st[1], L.qd_y + 0.1, st[0]); var t1 := Vector3(st[1], L.qd_y + 0.1, st[0])
	var t2 := Vector3(st[1], st[3], st[0]); var t3 := Vector3(-st[1], st[3], st[0])
	var t4 := Vector3(st[2], st[4], st[0]); var t5 := Vector3(-st[2], st[4], st[0])
	mb.add_quad(hull_m, t0, t1, t2, t3, _transom_uv(t0), _transom_uv(t1), _transom_uv(t2), _transom_uv(t3), Color.WHITE, Vector3.BACK)
	mb.add_quad(hull_m, t3, t2, t4, t5, _transom_uv(t3), _transom_uv(t2), _transom_uv(t4), _transom_uv(t5), Color.WHITE, Vector3.BACK)
	# the bow: the sides meet at a stem post (closed outside and in, the rail across)
	var bw: Array = L.rings[L.rings.size() - 1]
	var bz := float(bw[0])
	var btop := float(bw[3]) + L.lip
	var f0 := Vector3(-bw[1], btop, bz); var f1 := Vector3(bw[1], btop, bz)
	var f2 := Vector3(bw[2], bw[4], bz); var f3 := Vector3(-bw[2], bw[4], bz)
	mb.add_quad(hull_m, f0, f1, f2, f3, Vector2(0, 0), Vector2(0.4, 0), Vector2(0.4, 1.4), Vector2(0, 1.4), Color.WHITE, Vector3.FORWARD)
	mb.add_quad(hull_m, Vector3(-bw[1] + 0.04, L.deck_y, bz + 0.03), Vector3(bw[1] - 0.04, L.deck_y, bz + 0.03), Vector3(bw[1] - 0.04, btop - 0.05, bz + 0.03), Vector3(-bw[1] + 0.04, btop - 0.05, bz + 0.03),
		Vector2(0, 0), Vector2(0.4, 0), Vector2(0.4, 0.5), Vector2(0, 0.5), Color(0.8, 0.8, 0.8), Vector3.BACK)
	mb.add_box(trim, Transform3D(Basis(), Vector3(0, btop, bz - 0.02)), Vector3(float(bw[1]) * 2.0 + 0.2, 0.14, 0.2), 1.0)
	mb.add_box(trim, Transform3D(Basis(), Vector3(0, (btop + 0.1 + float(bw[4])) * 0.5, bz - 0.08)), Vector3(0.26, btop + 0.1 - float(bw[4]), 0.16), 1.0)
	for z in [-9.5, -6.0, -3.0, 0.0, 3.0]:
		for sgn in [-1.0, 1.0]:
			mb.add_box(trim, Transform3D(Basis(), Vector3(sgn * (L.half_width(z) - 0.02), L.deck_y + 0.3, z)), Vector3(0.14, 0.6, 0.14), 1.0)
	_quarterdeck(mb, m, L)
	_stairs(mb, m, L)
	# bowsprit
	mb.add_cylinder(wood, Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-70)), Vector3(0, 1.05, -12.3)), 0.15, 0.09, 4.5, 6, 0.8)
	if not rig:
		return
	# the mast, the crow's nest at its head, and the rigging up to it
	mb.add_cylinder(wood, Transform3D(Basis(), Vector3(0, L.deck_y - 0.02, L.mast_z)), 0.3, 0.17, L.mast_top - L.deck_y, 8, 0.8)
	mb.add_cylinder(wood, Transform3D(Basis(), Vector3(0, L.nest_y - 0.12, L.mast_z)), L.nest_r, L.nest_r, 0.14, 12, 1.0, Color.WHITE, true, true)
	for k in L.nest_rail():
		mb.add_box(trim, Transform3D(Basis(Vector3.UP, -float(k)), L.nest_rail_at(float(k))), Vector3(0.08, 0.9, L.nest_r * 0.55), 1.0)
	for sgn in [-1.0, 1.0]:
		var bot := Vector3(sgn * L.rig_bottom.x, L.rig_bottom.y, L.rig_bottom.z)
		var top := Vector3(sgn * L.rig_top.x, L.rig_top.y, L.rig_top.z)
		# three shrouds fanning out at the rail, ratlines across them
		for dz in [-0.55, 0.0, 0.55]:
			_line(mb, rope, bot + Vector3(0, -0.4, dz * 1.6), Vector3(top.x, L.mast_top - 0.5, top.z + dz * 0.2), 0.045)
		var n := int((top.y - bot.y) / 0.42)
		for r in range(1, n):
			var k := float(r) / n
			var c := bot.lerp(top, k)
			var w := lerpf(0.55 * 1.6, 0.25, k)
			_line(mb, rope, c + Vector3(0, 0, -w), c + Vector3(0, 0, w), 0.035)
		# a forestay-ish line to the bow and a backstay to the quarterdeck
		_line(mb, rope, Vector3(sgn * 0.1, L.mast_top - 0.3, L.mast_z), Vector3(sgn * 0.1, 1.5, -12.0), 0.04)
		_line(mb, rope, Vector3(sgn * 0.1, L.mast_top - 0.3, L.mast_z), Vector3(sgn * 3.6, L.qd_y + 0.8, L.qd_back - 0.4), 0.04)


## Deck planking mapped by position: boards run fore and aft, 0.25 m wide.
static func _plank_uv(p: Vector3) -> Vector2:
	return Vector2(-p.z * 0.25, p.x * 0.5)


## Side planking mapped by position: strakes run fore and aft, 0.25 m high.
static func _side_uv(p: Vector3) -> Vector2:
	return Vector2(p.z * 0.25, -p.y * 0.5)


## The transom's strakes, mapped by position like the sides' (0.25 m high).
static func _transom_uv(p: Vector3) -> Vector2:
	return Vector2(p.x * 0.5, -p.y * 0.5)


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
static func _quarterdeck(mb: MeshBuilder, m: Dictionary, L: HullLayout) -> void:
	var hull_m: Material = m["hull"]
	var deck_m: Material = m["deck"]
	var trim: Material = m["trim"]
	var wall_h := L.qd_y - L.deck_y
	var wy := L.deck_y + wall_h * 0.5
	var zf := L.qd_front
	# front wall: either side of the door, and the lintel over it
	var side_w := L.cabin_hw - L.door_hw
	for sgn in [-1.0, 1.0]:
		mb.add_box(trim, Transform3D(Basis(), Vector3(sgn * (L.door_hw + side_w * 0.5), wy, zf + 0.06)), Vector3(side_w, wall_h, 0.12), 0.6, Color.WHITE, true, true)
		# door posts
		mb.add_box(hull_m, Transform3D(Basis(), Vector3(sgn * (L.door_hw + 0.06), L.deck_y + L.door_h * 0.5, zf - 0.02)), Vector3(0.14, L.door_h, 0.16), 1.0)
		# the cabin's side walls, inside the stern castle
		mb.add_box(trim, Transform3D(Basis(), Vector3(sgn * (L.cabin_hw + 0.06), wy, (zf + L.qd_back) * 0.5)), Vector3(0.12, wall_h, L.qd_back - zf), 0.6, Color.WHITE, true, true)
	mb.add_box(trim, Transform3D(Basis(), Vector3(0, L.deck_y + L.door_h + (wall_h - L.door_h) * 0.5, zf + 0.06)), Vector3(L.door_hw * 2.0, wall_h - L.door_h, 0.12), 0.6, Color.WHITE, true, true)
	# the stern wall inside (the transom only faces out)
	mb.add_box(trim, Transform3D(Basis(), Vector3(0, wy, L.qd_back - 0.1)), Vector3(L.cabin_hw * 2.0, wall_h, 0.1), 0.6, Color.WHITE, true, true)
	mb.add_box(hull_m, Transform3D(Basis(), Vector3(0, L.deck_y + L.door_h + 0.05, zf - 0.02)), Vector3(L.door_hw * 2.0 + 0.3, 0.12, 0.16), 1.0)
	# the quarterdeck: its floor (hull-wide), a lip along its front edge, the ceiling under it
	var hf := L.half_width(zf)
	var hb := L.half_width(L.qd_back)
	_deck_quad(mb, deck_m, Vector3(-hf + 0.05, L.qd_y, zf), Vector3(hf - 0.05, L.qd_y, zf), Vector3(hb - 0.05, L.qd_y, L.qd_back), Vector3(-hb + 0.05, L.qd_y, L.qd_back), Color.WHITE, Vector3.UP)
	_deck_quad(mb, deck_m, Vector3(-L.cabin_hw, L.qd_y - 0.12, zf), Vector3(L.cabin_hw, L.qd_y - 0.12, zf), Vector3(L.cabin_hw, L.qd_y - 0.12, L.qd_back), Vector3(-L.cabin_hw, L.qd_y - 0.12, L.qd_back), Color(0.6, 0.6, 0.6), Vector3.DOWN)
	mb.add_box(hull_m, Transform3D(Basis(), Vector3(0, L.qd_y - 0.06, zf - 0.04)), Vector3(hf * 2.0, 0.16, 0.12), 1.0, Color.WHITE, false, false)
	# beams under the ceiling
	for z in [6.2, 7.6, 9.0]:
		mb.add_box(hull_m, Transform3D(Basis(), Vector3(0, L.qd_y - 0.2, z)), Vector3(L.cabin_hw * 2.0, 0.16, 0.18), 1.0, Color.WHITE, false, false)
	# quarterdeck rails: round the sides and stern, and along its front edge
	# between the stairheads
	for sgn in [-1.0, 1.0]:
		var p0 := Vector3(sgn * (hf - 0.02), L.qd_y + 0.8, zf)
		var p1 := Vector3(sgn * (hb - 0.02), L.qd_y + 0.8, L.qd_back)
		var d := p1 - p0
		mb.add_box(trim, Transform3D(Basis.looking_at(d.normalized(), Vector3.UP), (p0 + p1) * 0.5), Vector3(0.14, 0.12, d.length() + 0.1), 1.0)
		for k in range(4):
			var p := p0.lerp(p1, (k + 0.5) / 4.0)
			mb.add_box(trim, Transform3D(Basis(), Vector3(p.x, L.qd_y + 0.4, p.z)), Vector3(0.1, 0.8, 0.1), 1.0)
	mb.add_box(trim, Transform3D(Basis(), Vector3(0, L.qd_y + 0.8, L.qd_back - 0.05)), Vector3(hb * 2.0, 0.12, 0.14), 1.0)
	mb.add_box(trim, Transform3D(Basis(), Vector3(0, L.qd_y + 0.8, zf + 0.05)), Vector3(L.stair_x0 * 2.0, 0.12, 0.12), 1.0)
	for x in [-2.6, -1.3, 0.0, 1.3, 2.6]:
		mb.add_box(trim, Transform3D(Basis(), Vector3(x, L.qd_y + 0.4, zf + 0.05)), Vector3(0.1, 0.8, 0.1), 1.0)
		mb.add_box(trim, Transform3D(Basis(), Vector3(x * 1.4, L.qd_y + 0.4, L.qd_back - 0.05)), Vector3(0.1, 0.8, 0.1), 1.0)


## Stairs up to the quarterdeck, port and starboard of the cabin door.
static func _stairs(mb: MeshBuilder, m: Dictionary, L: HullLayout) -> void:
	var hull_m: Material = m["hull"]
	var deck_m: Material = m["deck"]
	var trim: Material = m["trim"]
	var run := L.qd_front - L.stair_z0
	var rise := L.qd_y - L.deck_y
	var w := L.cabin_hw - L.stair_x0
	for sgn in [-1.0, 1.0]:
		var cx: float = sgn * (L.stair_x0 + w * 0.5)
		var x0: float = sgn * L.stair_x0
		var x1: float = sgn * L.cabin_hw
		var tread := run / L.stair_steps
		for i in range(L.stair_steps):
			var z0 := L.stair_z0 + tread * i
			var y0 := L.deck_y + rise * i / L.stair_steps
			var y1 := L.deck_y + rise * (i + 1) / L.stair_steps
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
			var s0 := Vector3(x, L.deck_y, L.stair_z0); var s1 := Vector3(x, L.deck_y, L.qd_front); var s2 := Vector3(x, L.qd_y, L.qd_front)
			mb.add_tri(hull_m, s0, s1, s2, Vector3(o, 0, 0), Vector3(o, 0, 0), Vector3(o, 0, 0), _side_uv(s0), _side_uv(s1), _side_uv(s2), Color(0.85, 0.85, 0.85), Vector3(o, 0, 0))
		# a hand rail up the inner side
		var a := Vector3(sgn * (L.stair_x0 - 0.05), L.deck_y + 0.9, L.stair_z0 + 0.2)
		var b := Vector3(sgn * (L.stair_x0 - 0.05), L.qd_y + 0.8, L.qd_front)
		_line(mb, trim, a, b, 0.08)
		for k in [0.15, 0.55]:
			var p := a.lerp(b, k)
			mb.add_box(trim, Transform3D(Basis(), Vector3(p.x, (p.y + L.deck_y + rise * k) * 0.5 - 0.05, p.z)), Vector3(0.08, p.y - (L.deck_y + rise * k) + 0.1, 0.08), 1.0)


## The enemies' (and wrecks') whole model under `parent`. opts: hull (Color),
## sail (Color), trim (Color), emblem ("jolly": skull and crossbones on the
## sail and flag, "marine": the Admiralty's steel gull; the node is "Jolly" either
## way), wreck (bool: a broken hulk - mast snapped, no sail, flag or lights), hull_tex (the hull's planks:
## "planks_dark", the Admiralty's painted "planks_grey"), layout (HullLayout, base() by default).
static func build(parent: Node3D, opts: Dictionary = {}) -> Node3D:
	var L: HullLayout = opts.get("layout", HullLayout.base())
	var mb := MeshBuilder.new()
	var mats := {
		"hull": PSXMat.lit(str(opts.get("hull_tex", "planks_dark")), opts.get("hull", Color.WHITE), {"affine": 0.6}),
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
		hull(w, mats, false, L)
		w.add_cylinder(wood, Transform3D(Basis(Vector3.BACK, 0.25), Vector3(0, L.deck_y, L.mast_z)), 0.3, 0.22, 5.0, 6, 0.8)
		var winst := w.to_instance("PSXModel")
		parent.add_child(winst)
		return winst
	hull(mb, mats, true, L)
	# yard and sail (two panels, both faces), flag
	mb.add_cylinder(wood, Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(4.5, L.yard_y, L.mast_z)), 0.12, 0.12, 9.0, 6, 0.8)
	var sz := L.mast_z + 0.25
	var sn := Vector3(0, 0, 1)
	var top_y := L.yard_y - 0.15
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
	mb.add_card(flag, Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(0, L.mast_top + 0.2, L.mast_z + 0.45)), 1.35, 0.75, Rect2(0, 0, 0.5, 0.5))
	mb.add_card(flag, Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(0, L.mast_top + 0.2, L.mast_z + 0.45)), 1.35, 0.75, Rect2(0, 0, 0.5, 0.5))
	# cabin windows by the door, a stern lantern
	mb.add_box(glass, Transform3D(Basis(), Vector3(2.0, L.deck_y + 1.5, L.qd_front - 0.02)), Vector3(0.4, 0.4, 0.06), 1.0)
	mb.add_box(glass, Transform3D(Basis(), Vector3(-2.0, L.deck_y + 1.5, L.qd_front - 0.02)), Vector3(0.4, 0.4, 0.06), 1.0)
	mb.add_box(glass, Transform3D(Basis(), Vector3(0, L.qd_y + 1.3, L.qd_back + 0.15)), Vector3(0.3, 0.4, 0.3), 1.0, Color.WHITE, false)
	# a ship's wheel (fixed) on the quarterdeck, some cargo on deck
	mb.add_box(wood, Transform3D(Basis(), Vector3(0, L.qd_y + 0.45, L.wheel_z + 0.1)), Vector3(0.16, 0.9, 0.16), 1.0)
	mb.add_cylinder(trim, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, L.qd_y + 0.95, L.wheel_z)), 0.42, 0.42, 0.06, 8, 1.0, Color.WHITE, true, true, false)
	var crate := PSXMat.lit("planks", Color(0.8, 0.65, 0.45))
	mb.add_box(crate, Transform3D(Basis(Vector3.UP, 0.3), Vector3(2.1, L.deck_y + 0.3, -0.4)), Vector3(0.6, 0.6, 0.6), 1.0)
	mb.add_box(crate, Transform3D(Basis(Vector3.UP, -0.2), Vector3(-2.2, L.deck_y + 0.25, -4.5)), Vector3(0.5, 0.5, 0.5), 1.0)
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
		j.add_card(jm, Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(0.01, L.mast_top + 0.2, L.mast_z + 0.45)), 1.05, 0.65, Rect2(0, 0, 1, 1))
		j.add_card(jm, Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(-0.01, L.mast_top + 0.2, L.mast_z + 0.45)), 1.05, 0.65, Rect2(0, 0, 1, 1))
		parent.add_child(j.to_instance("Jolly"))
	return inst


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


## The Admiralty's seagull crest (painted at runtime), pale steel on transparent (on their grey sails).
static func marine_material() -> ShaderMaterial:
	if _marine_mat:
		return _marine_mat
	var n := 64
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var blue := Color(0.82, 0.85, 0.9, 1.0)
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
static func collide(body: CollisionObject3D, rig: bool = true, L: HullLayout = HullLayout.base()) -> void:
	var pts := PackedVector3Array()
	for r in L.rings:
		for sgn in [-1.0, 1.0]:
			pts.append(Vector3(sgn * float(r[1]), L.deck_y, float(r[0])))
			pts.append(Vector3(sgn * float(r[2]), float(r[4]), float(r[0])))
	var hull_shape := ConvexPolygonShape3D.new()
	hull_shape.points = pts
	_shape(body, hull_shape, Transform3D.IDENTITY)
	# main deck bulwarks (waist high: jump to get over the side)
	for i in range(1, L.rings.size() - 1):
		var a: Array = L.rings[i]
		var b: Array = L.rings[i + 1]
		for sgn in [-1.0, 1.0]:
			_box(body, Vector3(sgn * (float(a[1]) - 0.05), L.deck_y + 0.4, float(a[0])), Vector3(sgn * (float(b[1]) - 0.05), L.deck_y + 0.4, float(b[0])), 0.18, 0.8)
	var bw: Array = L.rings[L.rings.size() - 1]
	_cbox(body, Vector3(0, L.deck_y + 0.4, float(bw[0])), Vector3(float(bw[1]) * 2.0 + 0.3, 0.8, 0.2))
	var wall_h := L.qd_y - L.deck_y
	var wy := L.deck_y + wall_h * 0.5
	var zf := L.qd_front
	# the cabin: front wall either side of the doorway, the lintel, the sides (out to the hull), the stern
	var side_w := L.cabin_hw - L.door_hw
	for sgn in [-1.0, 1.0]:
		_cbox(body, Vector3(sgn * (L.door_hw + side_w * 0.5), wy, zf + 0.06), Vector3(side_w, wall_h, 0.14))
		_cbox(body, Vector3(sgn * (L.cabin_hw + 0.3), wy, (zf + L.qd_back) * 0.5), Vector3(0.6, wall_h, L.qd_back - zf))
	_cbox(body, Vector3(0, L.deck_y + L.door_h + (wall_h - L.door_h) * 0.5, zf + 0.06), Vector3(L.door_hw * 2.0, wall_h - L.door_h, 0.14))
	_cbox(body, Vector3(0, wy, L.qd_back - 0.08), Vector3(L.cabin_hw * 2.0 + 0.6, wall_h, 0.16))
	# the quarterdeck floor (a slab the shape of the hull there)
	var hf := L.half_width(zf)
	var hb := L.half_width(L.qd_back)
	var slab := ConvexPolygonShape3D.new()
	slab.points = PackedVector3Array([Vector3(-hf, L.qd_y, zf), Vector3(hf, L.qd_y, zf), Vector3(-hb, L.qd_y, L.qd_back), Vector3(hb, L.qd_y, L.qd_back),
		Vector3(-hf, L.qd_y - 0.12, zf), Vector3(hf, L.qd_y - 0.12, zf), Vector3(-hb, L.qd_y - 0.12, L.qd_back), Vector3(hb, L.qd_y - 0.12, L.qd_back)])
	_shape(body, slab, Transform3D.IDENTITY)
	# its rails: sides, stern, and the front edge between the stairheads
	for sgn in [-1.0, 1.0]:
		_box(body, Vector3(sgn * (hf - 0.05), L.qd_y + 0.45, zf), Vector3(sgn * (hb - 0.05), L.qd_y + 0.45, L.qd_back), 0.18, 0.9)
	_cbox(body, Vector3(0, L.qd_y + 0.45, L.qd_back - 0.05), Vector3(hb * 2.0, 0.9, 0.18))
	_cbox(body, Vector3(0, L.qd_y + 0.45, zf + 0.05), Vector3(L.stair_x0 * 2.0, 0.9, 0.16))
	# the stairs: a wedge each side
	for sgn in [-1.0, 1.0]:
		var x0: float = sgn * L.stair_x0
		var x1: float = sgn * L.cabin_hw
		var wedge := ConvexPolygonShape3D.new()
		wedge.points = PackedVector3Array([Vector3(x0, L.deck_y, L.stair_z0), Vector3(x1, L.deck_y, L.stair_z0), Vector3(x0, L.deck_y, zf), Vector3(x1, L.deck_y, zf),
			Vector3(x0, L.qd_y, zf), Vector3(x1, L.qd_y, zf)])
		_shape(body, wedge, Transform3D.IDENTITY)
		# the hand rail along the inner side (don't step off the side mid-flight)
		_box(body, Vector3(sgn * (L.stair_x0 - 0.05), L.deck_y + 0.9, L.stair_z0 + 0.2), Vector3(sgn * (L.stair_x0 - 0.05), L.qd_y + 0.8, zf), 0.1, 0.5)
	if not rig:
		return
	# the mast and the crow's nest (floor and a rail with gaps for the rigging)
	var mast := CylinderShape3D.new()
	mast.radius = 0.28
	mast.height = L.mast_top - L.deck_y
	_shape(body, mast, Transform3D(Basis.IDENTITY, Vector3(0, (L.mast_top + L.deck_y) * 0.5, L.mast_z)))
	var nest := CylinderShape3D.new()
	nest.radius = L.nest_r
	nest.height = 0.14
	_shape(body, nest, Transform3D(Basis.IDENTITY, Vector3(0, L.nest_y - 0.12, L.mast_z)))
	for k in L.nest_rail():
		var bx := BoxShape3D.new()
		bx.size = Vector3(0.1, 0.9, L.nest_r * 0.6)
		_shape(body, bx, Transform3D(Basis(Vector3.UP, -float(k)), L.nest_rail_at(float(k))))


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
