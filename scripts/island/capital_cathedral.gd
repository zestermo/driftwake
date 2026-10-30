class_name CapitalCathedral
extends RefCounted
## The capital's cathedral, walked into (1.27, docs/v1_27_plan.md C2): the old temple block (CapitalShell._landmarks) made
## a hollow nave behind tall doors in its east front on the forecourt (CapitalPlan.FLOORS "forecourt", joined to the
## avenue by "temple_walk"): a flagged floor, columns down both aisles, pews in two blocks, the altar on its step at the
## west end under a hanging lamp, candles (glow, not lights: the plaza holds the light budget), coloured windows. The
## dome, roof and towers stay as they were outside. Frame coordinates, into the shell's Landmarks piece.

const M := preload("res://scripts/island/capital_models.gd")
const W := 26.0
const D := 32.0
const H := 12.0
const WALL := 0.9
const DOOR_W := 3.4
const DOOR_H := 5.2


## The cathedral's middle (frame) and ground: the temple rect's, nudged as the shell always placed it.
static func centre() -> Vector2:
	return CapitalPlan.TEMPLE.get_center() + Vector2(4.0, 2.0)


## Where someone inside would stand: before the altar (frame, on the floor).
static func inside(ty: float) -> Vector3:
	return M.v3(centre() + Vector2(-W * 0.5 + 6.0, 0), ty + 0.8)


static func build(mb: MeshBuilder, cols: Array, ty: float) -> void:
	var tc := centre()
	var tt := M.xf(M.v3(tc, 0.0))
	var lime := M.mat("lime")
	var fy := ty + 0.8
	var hw := W * 0.5
	var hd := D * 0.5
	# the plinth and the floor (as before: the plinth's top is the floor)
	mb.add_box(lime, M.xf(M.v3(tc, ty - 1.0)), Vector3(W + 1.0, 3.6, D + 1.0), 0.5, Color(0.9, 0.88, 0.84), true, false)
	M.box(cols, M.xf(M.v3(tc, ty - 1.0)), Vector3(W + 1.0, 3.6, D + 1.0))
	# the walls, outside faced as before; inside plain; the east one round the doors
	# (three faces as before; the east front round its doors, a portal, a rose window and a pediment: a church's face)
	var fac := M.mat("facade_b")
	var fcol := Color(0.98, 0.95, 0.88)
	M.facade_quad(mb, fac, tt * Vector3(W * 0.5, fy, -D * 0.5), tt * Vector3(-W * 0.5, fy, -D * 0.5), H, (tt.basis * Vector3.FORWARD).normalized(), fcol)
	M.facade_quad(mb, fac, tt * Vector3(-W * 0.5, fy, D * 0.5), tt * Vector3(W * 0.5, fy, D * 0.5), H, (tt.basis * Vector3.BACK).normalized(), fcol)
	M.facade_quad(mb, fac, tt * Vector3(-W * 0.5, fy, -D * 0.5), tt * Vector3(-W * 0.5, fy, D * 0.5), H, (tt.basis * Vector3.LEFT).normalized(), fcol)
	var east := (tt.basis * Vector3.RIGHT).normalized()
	var front := Color(0.95, 0.93, 0.88)
	for sg in [[-D * 0.5, -DOOR_W * 0.5], [DOOR_W * 0.5, D * 0.5]]:
		var za: float = sg[0]
		var zb: float = sg[1]
		mb.add_quad(lime, tt * Vector3(W * 0.5, fy, zb), tt * Vector3(W * 0.5, fy, za), tt * Vector3(W * 0.5, fy + H, za), tt * Vector3(W * 0.5, fy + H, zb),
			Vector2(0, H * 0.3), Vector2((zb - za) * 0.3, H * 0.3), Vector2((zb - za) * 0.3, 0), Vector2(0, 0), front, east)
	mb.add_quad(lime, tt * Vector3(W * 0.5, fy + DOOR_H, DOOR_W * 0.5), tt * Vector3(W * 0.5, fy + DOOR_H, -DOOR_W * 0.5), tt * Vector3(W * 0.5, fy + H, -DOOR_W * 0.5),
		tt * Vector3(W * 0.5, fy + H, DOOR_W * 0.5), Vector2(0, 2), Vector2(1, 2), Vector2(1, 0), Vector2(0, 0), front, east)
	# the portal: pilasters, the lintel and a round arch moulding over the doors
	for s in [-1.0, 1.0]:
		mb.add_box(lime, tt * Transform3D(Basis(), Vector3(W * 0.5 + 0.2, fy + DOOR_H * 0.5 + 0.4, s * (DOOR_W * 0.5 + 0.45))), Vector3(0.5, DOOR_H + 0.8, 0.9), 0.6, Color(0.9, 0.88, 0.84))
	mb.add_box(lime, tt * Transform3D(Basis(), Vector3(W * 0.5 + 0.25, fy + DOOR_H + 0.5, 0)), Vector3(0.6, 0.6, DOOR_W + 2.0), 0.6, Color(0.88, 0.86, 0.82))
	for k in range(9):
		var a := PI * k / 8.0
		var q := Vector3(W * 0.5 + 0.22, fy + DOOR_H + 0.8 + sin(a) * (DOOR_W * 0.5 + 0.5), cos(a) * (DOOR_W * 0.5 + 0.5))
		mb.add_box(lime, tt * Transform3D(Basis(Vector3.RIGHT, -a), q), Vector3(0.44, 0.5, 0.75), 0.6, Color(0.92, 0.9, 0.86), false)
	# the rose window over the portal (glass that glows), its stone ring
	var rose := tt * Transform3D(Basis(Vector3.BACK, -PI * 0.5), Vector3(W * 0.5 + 0.05, fy + H - 2.6, 0))
	mb.add_cylinder(lime, rose, 2.0, 2.0, 0.2, 16, 0.5, Color(0.9, 0.88, 0.84))
	mb.add_cylinder(PSXMat.glow(Color(0.3, 0.45, 0.85), 1.1), rose * Transform3D(Basis(), Vector3(0, 0.16, 0)), 1.55, 1.55, 0.04, 16, 0.5)
	# a pediment over the front
	mb.add_tri(lime, tt * Vector3(W * 0.5 + 0.3, fy + H, -D * 0.5 * 0.55), tt * Vector3(W * 0.5 + 0.3, fy + H + 3.2, 0), tt * Vector3(W * 0.5 + 0.3, fy + H, D * 0.5 * 0.55),
		east, east, east, Vector2(0, 1), Vector2(0.5, 0), Vector2(1, 1), Color(0.94, 0.92, 0.88), east)
	var wy := fy + H * 0.5
	for s in [-1.0, 1.0]:
		M.box(cols, tt * Transform3D(Basis(), Vector3(0, wy, s * (hd - WALL * 0.5))), Vector3(W, H, WALL))
	M.box(cols, tt * Transform3D(Basis(), Vector3(-hw + WALL * 0.5, wy, 0)), Vector3(WALL, H, D))
	var pz := (D - DOOR_W) * 0.25
	for s in [-1.0, 1.0]:
		M.box(cols, tt * Transform3D(Basis(), Vector3(hw - WALL * 0.5, wy, s * (DOOR_W * 0.5 + pz))), Vector3(WALL, H, pz * 2.0))
	M.box(cols, tt * Transform3D(Basis(), Vector3(hw - WALL * 0.5, fy + DOOR_H + (H - DOOR_H) * 0.5, 0)), Vector3(WALL, H - DOOR_H, DOOR_W))
	# the inside faces (the facade box is one-sided, outward)
	var plaster := PSXMat.lit("plaster_wash")
	var ix := hw - WALL
	var iz := hd - WALL
	var inner := Color(0.86, 0.82, 0.74)
	var walls := [[Vector3(ix, 0, -iz), Vector3(-ix, 0, -iz), Vector3.BACK], [Vector3(-ix, 0, iz), Vector3(ix, 0, iz), Vector3.FORWARD],
		[Vector3(-ix, 0, -iz), Vector3(-ix, 0, iz), Vector3.RIGHT]]
	for wl in walls:
		var a: Vector3 = wl[0]
		var b: Vector3 = wl[1]
		mb.add_quad(plaster, tt * (a + Vector3(0, fy, 0)), tt * (b + Vector3(0, fy, 0)), tt * (b + Vector3(0, fy + H, 0)), tt * (a + Vector3(0, fy + H, 0)),
			Vector2(0, H * 0.4), Vector2(a.distance_to(b) * 0.4, H * 0.4), Vector2(a.distance_to(b) * 0.4, 0), Vector2(0, 0), inner, (tt.basis * (wl[2] as Vector3)).normalized())
	for sg in [[-iz, -DOOR_W * 0.5], [DOOR_W * 0.5, iz]]:
		var a := Vector3(ix, 0, sg[1])
		var b := Vector3(ix, 0, sg[0])
		mb.add_quad(plaster, tt * (a + Vector3(0, fy, 0)), tt * (b + Vector3(0, fy, 0)), tt * (b + Vector3(0, fy + H, 0)), tt * (a + Vector3(0, fy + H, 0)),
			Vector2(0, H * 0.4), Vector2(a.distance_to(b) * 0.4, H * 0.4), Vector2(a.distance_to(b) * 0.4, 0), Vector2(0, 0), inner, (tt.basis * Vector3.LEFT).normalized())
	mb.add_quad(plaster, tt * Vector3(ix, fy + DOOR_H, DOOR_W * 0.5), tt * Vector3(ix, fy + DOOR_H, -DOOR_W * 0.5), tt * Vector3(ix, fy + H, -DOOR_W * 0.5), tt * Vector3(ix, fy + H, DOOR_W * 0.5),
		Vector2.ZERO, Vector2(1, 0), Vector2(1, 1), Vector2(0, 1), inner, (tt.basis * Vector3.LEFT).normalized())
	# the ceiling, ribbed with beams
	mb.add_quad(plaster, tt * Vector3(-ix, fy + H - 0.05, iz), tt * Vector3(ix, fy + H - 0.05, iz), tt * Vector3(ix, fy + H - 0.05, -iz), tt * Vector3(-ix, fy + H - 0.05, -iz),
		Vector2(0, 0), Vector2(ix * 0.4, 0), Vector2(ix * 0.4, iz * 0.4), Vector2(0, iz * 0.4), Color(0.72, 0.68, 0.6), (tt.basis * Vector3.DOWN).normalized())
	var x := -ix + 2.0
	while x < ix:
		mb.add_box(lime, tt * Transform3D(Basis(), Vector3(x, fy + H - 0.3, 0)), Vector3(0.5, 0.5, iz * 2.0), 0.6, Color(0.9, 0.88, 0.84), false)
		x += 3.6
	# the floor's flagstones, in a two-tone checker
	var slabs := M.mat("slabs")
	mb.add_quad(slabs, tt * Vector3(-ix, fy + 0.01, -iz), tt * Vector3(ix, fy + 0.01, -iz), tt * Vector3(ix, fy + 0.01, iz), tt * Vector3(-ix, fy + 0.01, iz),
		Vector2(0, 0), Vector2(ix * 0.5, 0), Vector2(ix * 0.5, iz * 0.5), Vector2(0, iz * 0.5), Color(0.88, 0.84, 0.78), (tt.basis * Vector3.UP).normalized())
	# three broad steps down from the doors onto the forecourt
	for k in range(3):
		var sy := ty + (fy - ty) * (k + 1) / 3.0
		var st := tt * Transform3D(Basis(), Vector3(hw + 0.25 + (2 - k) * 0.45, (sy + ty - 1.0) * 0.5, 0))
		mb.add_box(lime, st, Vector3(0.5 + (2 - k) * 0.0 + 0.45, sy - ty + 1.0, DOOR_W + 2.4), 0.6, Color(0.9, 0.88, 0.84))
		M.box(cols, st, Vector3(0.45, sy - ty + 1.0, DOOR_W + 2.4))
	# the doors: two tall leaves, swung open into the nave
	for s in [-1.0, 1.0]:
		var hinge := tt * Transform3D(Basis(), Vector3(hw - WALL - 0.05, fy, s * DOOR_W * 0.5))
		var leaf := hinge * Transform3D(Basis(Vector3.UP, s * 1.3), Vector3.ZERO) * Transform3D(Basis(), Vector3(0, DOOR_H * 0.5, -s * DOOR_W * 0.25))
		mb.add_box(PSXMat.lit("planks_dark"), leaf, Vector3(0.12, DOOR_H - 0.1, DOOR_W * 0.5 - 0.06), 0.6, Color(0.5, 0.36, 0.26))
	# columns down both aisles, the pews in two blocks between them and the walls' middle
	var col_z := iz - 4.0
	x = -ix + 4.0
	while x < ix - 2.0:
		for s in [-1.0, 1.0]:
			var ct := tt * Transform3D(Basis(), Vector3(x, fy, s * col_z))
			mb.add_cylinder(lime, ct, 0.55, 0.5, H, 10, 0.5, Color(0.94, 0.92, 0.88))
			mb.add_box(lime, ct * Transform3D(Basis(), Vector3(0, 0.25, 0)), Vector3(1.4, 0.5, 1.4), 0.6, Color(0.9, 0.88, 0.84))
			M.cyl(cols, tt * Vector3(x, fy, s * col_z), 0.55, H)
		x += 4.4
	var wood := PSXMat.lit("planks_dark")
	x = -ix + 8.0
	while x < ix - 3.0:
		for s in [-1.0, 1.0]:
			var pt := tt * Transform3D(Basis(), Vector3(x, fy, s * (col_z * 0.5 + 0.9)))
			var pl := col_z - 2.6
			mb.add_box(wood, pt * Transform3D(Basis(), Vector3(0, 0.45, 0)), Vector3(0.5, 0.08, pl), 0.6, Color.WHITE, false)
			mb.add_box(wood, pt * Transform3D(Basis(), Vector3(0.24, 0.8, 0)), Vector3(0.06, 0.7, pl), 0.6, Color.WHITE, false)
			for e in [-1.0, 1.0]:
				mb.add_box(wood, pt * Transform3D(Basis(), Vector3(0, 0.45, e * pl * 0.5)), Vector3(0.6, 0.9, 0.08), 0.6, Color.WHITE, false)
			M.box(cols, pt * Transform3D(Basis(), Vector3(0, 0.45, 0)), Vector3(0.6, 0.9, pl))
		x += 1.8
	# the altar on its step at the west end, candles on it and on stands, a lamp hung over it
	var at := tt * Transform3D(Basis(), Vector3(-ix + 2.4, fy, 0))
	mb.add_box(lime, at * Transform3D(Basis(), Vector3(0, 0.2, 0)), Vector3(4.0, 0.4, 7.0), 0.6, Color(0.9, 0.88, 0.84))
	mb.add_box(lime, at * Transform3D(Basis(), Vector3(0, 0.95, 0)), Vector3(1.4, 1.1, 3.0), 0.6, Color(0.96, 0.94, 0.9))
	mb.add_box(M.mat("cloth"), at * Transform3D(Basis(), Vector3(0, 1.52, 0)), Vector3(1.5, 0.05, 3.2), 1.0, Color(0.55, 0.12, 0.14), false)
	M.box(cols, at * Transform3D(Basis(), Vector3(0, 0.2, 0)), Vector3(4.0, 0.4, 7.0))
	M.box(cols, at * Transform3D(Basis(), Vector3(0, 0.95, 0)), Vector3(1.4, 1.1, 3.0))
	var flame := PSXMat.glow(Color(1.0, 0.75, 0.35), 2.2)
	for k in range(5):
		var cz := -1.2 + k * 0.6
		mb.add_cylinder(PSXMat.flat(Color(0.94, 0.9, 0.8)), at * Transform3D(Basis(), Vector3(0, 1.55, cz)), 0.04, 0.04, 0.3, 5)
		mb.add_box(flame, at * Transform3D(Basis(), Vector3(0, 1.9, cz)), Vector3(0.05, 0.1, 0.05), 1.0, Color.WHITE, false)
	for s in [-1.0, 1.0]:
		var stand := at * Transform3D(Basis(), Vector3(1.6, 0.4, s * 3.0))
		mb.add_cylinder(M.mat("gold"), stand, 0.18, 0.06, 1.5, 6)
		for k in range(3):
			mb.add_box(flame, stand * Transform3D(Basis(), Vector3(-0.15 + k * 0.15, 1.65, 0)), Vector3(0.05, 0.12, 0.05), 1.0, Color.WHITE, false)
	mb.add_box(M.mat("iron"), tt * Transform3D(Basis(), Vector3(-ix + 4.0, fy + H - 1.6, 0)), Vector3(0.05, 3.0, 0.05), 1.0, Color.WHITE, false)
	mb.add_cylinder(M.mat("gold"), tt * Transform3D(Basis(), Vector3(-ix + 4.0, fy + H - 3.4, 0)), 0.9, 0.5, 0.4, 10)
	mb.add_box(flame, tt * Transform3D(Basis(), Vector3(-ix + 4.0, fy + H - 3.5, 0)), Vector3(0.6, 0.1, 0.6), 1.0, Color.WHITE, false)
	# coloured windows high in the long walls (glow: they light the nave's colour, not the scene)
	var glass: Array = [Color(0.3, 0.45, 0.85), Color(0.85, 0.3, 0.3)]
	x = -ix + 4.0
	var i := 0
	while x < ix - 2.0:
		for s in [-1.0, 1.0]:
			mb.add_box(PSXMat.glow(glass[i % glass.size()], 1.1), tt * Transform3D(Basis(), Vector3(x + 2.2, fy + H * 0.62, s * (iz - 0.02))), Vector3(1.2, 3.2, 0.04), 1.0, Color.WHITE, false)
			i += 1
		x += 4.4
	# (occluders inside the long walls: the nave itself is open to look through)
	for s in [-1.0, 1.0]:
		Occluders.box(cols, tt * Transform3D(Basis(), Vector3(0, fy + H * 0.5, s * (hd - WALL * 0.5))), Vector3(W - 2.0, H - 1.0, 0.4))
