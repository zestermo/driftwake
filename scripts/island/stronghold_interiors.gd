class_name StrongholdInteriors
extends RefCounted
## The rooms you walk into, shaped inside (1.30 round 7, Zach: "not just completely square: trim, windows, arches,
## pillars, slopes"): inside the shell's walls (StrongholdPlan.ROOMS: their footprint, doors and floors unchanged) each
## hall gets skirting, a dado rail and a cornice; a blind arcade of pilasters with capitals and arches round its walls;
## tall recessed arched windows with deep sills in the bays; a segmental barrel vault with ribs over it (the Casting Hall
## timber trusses and a travelling crane instead); lamps hung from the vault; a fireplace built into a wall. Pilasters and
## hearths have colliders; vaults, ribs, arches and windows are out of reach. The floor in the middle stays clear
## (Kesh's channels and pours, Vane's quadrants: everything here is within 1.6 m of a wall or overhead).

const P := preload("res://scripts/island/stronghold_plan.gd")
const M := preload("res://scripts/island/capital_models.gd")
const S := preload("res://scripts/island/stronghold_shell.gd")
## Per room: the bay (pilaster spacing), where the vault springs (over the floor) and its rise, the windows' walls
## (outward normals) and the fireplace's wall and offset along it; "truss": timber trusses instead of a vault.
const SPEC := {
	"mess": {"bay": 4.0, "spring": 6.2, "rise": 3.0, "windows": [Vector2(0, 1)], "hearth": [Vector2(-1, 0), 0.0]},	"barracks": {"bay": 5.4, "spring": 6.2, "rise": 3.0, "windows": [Vector2(0, -1), Vector2(0, 1)], "hearth": [Vector2(1, 0), 0.0]},
	"casting": {"bay": 5.0, "spring": 9.0, "rise": 0.0, "windows": [Vector2(0, -1), Vector2(0, 1)], "truss": true},
	"command": {"bay": 4.6, "spring": 17.0, "rise": 8.0, "windows": [Vector2(1, 0), Vector2(-1, 0)], "hearth": [Vector2(1, 0), 0.0]},
}


## Every room's inside into mb, colliders into cols; what's in the way of a pilaster (frame rects) in `keep_out`.
static func build(mb: MeshBuilder, cols: Array, keep_out: Array) -> void:
	for rm in P.ROOMS:
		_room(mb, cols, rm, SPEC[str(rm[0])], keep_out)


static func _room(mb: MeshBuilder, cols: Array, rm: Array, sp: Dictionary, keep_out: Array) -> void:
	var ir: Rect2 = (rm[2] as Rect2).grow(-1.2)
	var y: float = rm[3]
	var h: float = rm[4]
	var door: Vector2 = rm[5]
	var dw: float = rm[6]
	var c := ir.get_center()
	var spring := y + float(sp["spring"])
	var bay: float = sp["bay"]
	var wall := S._wall_m()
	var dark := S._dark_m()
	var trim := S._trim_m()
	var gold := S._gold_m()
	var soot := str(rm[0]) == "casting"
	var shade := Color(0.62, 0.6, 0.6) if soot else Color.WHITE
	for f: Vector2 in [Vector2(0, -1), Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0)]:
		var al := Vector2(-f.y, f.x)
		var L := absf(al.x) * ir.size.x + absf(al.y) * ir.size.y
		var e := c + Vector2(f.x * ir.size.x * 0.5, f.y * ir.size.y * 0.5)
		var yaw := M.yaw_of(al)
		var is_door := f.is_equal_approx(door)
		var dh := minf(h * 0.6, 9.0)
		# skirting, dado rail and the cornice at the spring, cut round the door
		var runs: Array = [[-L * 0.5, L * 0.5]]
		if is_door:
			runs = [[-L * 0.5, -dw * 0.5 - 0.5], [dw * 0.5 + 0.5, L * 0.5]]
		for rr: Array in runs:
			var u := (float(rr[0]) + float(rr[1])) * 0.5
			var ln := float(rr[1]) - float(rr[0])
			mb.add_box(trim, M.xf(M.v3(e + al * u - f * 0.05, y + 0.2), yaw), Vector3(0.1, 0.4, ln), 0.5, shade)
			mb.add_box(dark, M.xf(M.v3(e + al * u - f * 0.05, y + 1.1), yaw), Vector3(0.12, 0.1, ln), 0.5, shade)
		mb.add_box(trim, M.xf(M.v3(e - f * 0.22, spring + 0.25), yaw), Vector3(0.44, 0.5, L), 0.5, shade, false)
		mb.add_box(gold, M.xf(M.v3(e - f * 0.45, spring + 0.02), yaw), Vector3(0.04, 0.08, L), 1.0)
		# the door's frame inside: jambs and an arched head over it
		if is_door:
			for s: float in [-1.0, 1.0]:
				_solid(mb, cols, dark, M.xf(M.v3(e + al * s * (dw * 0.5 + 0.25) - f * 0.15, y + dh * 0.5), yaw), Vector3(0.3, dh, 0.5), shade)
			_arch(mb, trim, e - f * 0.12, al, f, y + dh, dw * 0.5 + 0.5, 0.45, 0.24, minf(dw * 0.5, 2.5))
		# the blind arcade: pilasters every bay, arches between, a tall window in every other bay on a window wall
		var n := maxi(int(L / bay), 2)
		var step := L / n
		var windows: bool = (sp["windows"] as Array).any(func(w): return f.is_equal_approx(w))
		for k in range(n + 1):
			var u := -L * 0.5 + k * step
			if absf(u) > L * 0.5 - 0.4:
				continue
			if is_door and absf(u) < dw * 0.5 + 1.0:
				continue
			var q := e + al * u - f * 0.15
			if keep_out.any(func(r): return (r as Rect2).grow(0.4).has_point(q - f * 0.2)):
				continue
			_solid(mb, cols, wall, M.xf(M.v3(q, (y + spring) * 0.5), yaw), Vector3(0.3, spring - y, 0.7), shade)
			mb.add_box(trim, M.xf(M.v3(q - f * 0.06, y + 0.35), yaw), Vector3(0.42, 0.7, 0.9), 0.5, shade)
			mb.add_box(dark, M.xf(M.v3(q - f * 0.08, spring - 0.3), yaw), Vector3(0.46, 0.6, 0.95), 0.5, shade)
			mb.add_box(gold, M.xf(M.v3(q - f * 0.08, spring - 0.62), yaw), Vector3(0.48, 0.06, 0.92), 1.0)
		for k in range(n):
			var u0 := -L * 0.5 + k * step
			var u1 := u0 + step
			var um := (u0 + u1) * 0.5
			if is_door and absf(um) < dw * 0.5 + step * 0.5:
				continue
			var half := step * 0.5 - 0.35
			var top := spring - 0.6
			_arch(mb, dark, e + al * um - f * 0.04, al, f, top - half * 0.6, half, 0.3, 0.12, half * 0.6)
			if windows and k % 2 == 1 and not (is_door and absf(um) < dw):
				_window(mb, e + al * um, al, f, y + 2.6, top - 0.3, minf(step * 0.36, 1.2))
	# the ceiling: a ribbed segmental barrel vault along the long axis, or the Casting Hall's trusses
	if bool(sp.get("truss", false)):
		_trusses(mb, ir, y, h, bay)
	else:
		_vault(mb, ir, spring + 0.5, float(sp["rise"]), bay, y + h, shade)
	if sp.has("hearth"):
		var hf: Vector2 = sp["hearth"][0]
		var hal := Vector2(-hf.y, hf.x)
		var hL := absf(hal.x) * ir.size.x + absf(hal.y) * ir.size.y
		var hq := c + Vector2(hf.x * ir.size.x * 0.5, hf.y * ir.size.y * 0.5) + hal * float(sp["hearth"][1]) * hL * 0.5
		_hearth(mb, cols, hq, hf, y, spring)


## A solid box (mesh and collider).
static func _solid(mb: MeshBuilder, cols: Array, m: Material, t: Transform3D, size: Vector3, col := Color.WHITE) -> void:
	mb.add_box(m, t, size, 0.5, col)
	M.box(cols, t, size)


## A round arch's ring flat on a wall: its middle at frame point at (on the wall's face, f out of the wall into the room
## is -f... f is the wall's outward normal), springing at height y, half-span `half`, ring `ring` deep, `proud` out, its
## rise `rise` (a semicircle when rise == half, flatter below).
static func _arch(mb: MeshBuilder, m: Material, at: Vector2, al: Vector2, f: Vector2, y: float, half: float, ring: float, proud: float, rise: float) -> void:
	var o := PackedVector2Array()
	var n := 10
	for i in range(n + 1):
		var a := PI * i / n
		o.append(Vector2(cos(a) * (half + ring), sin(a) * (rise + ring)))
	for i in range(n, -1, -1):
		var a := PI * i / n
		o.append(Vector2(cos(a) * half, sin(a) * rise))
	var t := Transform3D(Basis(Vector3.UP, M.yaw_of(-f)), M.v3(at - f * proud * 0.5, y))
	mb.add_extrude(m, t, o, proud, 0.5)


## A tall arched window set deep in the wall: a navy reveal round it, a deep sill, the glazing lit (leaded in a grid),
## a shaft of light falling from it.
static func _window(mb: MeshBuilder, at: Vector2, al: Vector2, f: Vector2, y0: float, y1: float, half: float) -> void:
	var yaw := M.yaw_of(al)
	var hh := y1 - y0
	mb.add_box(S._trim_m(), M.xf(M.v3(at - f * 0.02, (y0 + y1) * 0.5), yaw), Vector3(0.05, hh + 0.3, half * 2.0 + 0.5), 0.5)
	var pane := PackedVector2Array([Vector2(-half, 0), Vector2(half, 0)])
	for i in range(9):
		var a := PI * i / 8.0
		pane.append(Vector2(cos(a) * half, hh - half + sin(a) * half))
	mb.add_extrude(S._window_m(), Transform3D(Basis(Vector3.UP, M.yaw_of(-f)), M.v3(at - f * 0.06, y0)), pane, 0.04, 1.0)
	for k in range(1, 4):
		mb.add_box(S._iron_m(), M.xf(M.v3(at - f * 0.09, y0 + k * (hh - half) / 4.0), yaw), Vector3(0.03, 0.05, half * 2.0), 1.0)
	mb.add_box(S._iron_m(), M.xf(M.v3(at - f * 0.09, y0 + (hh - half) * 0.5 + half * 0.5), yaw), Vector3(0.03, hh, 0.05), 1.0)
	mb.add_box(S._dark_m(), M.xf(M.v3(at - f * 0.3, y0 - 0.12), yaw), Vector3(0.6, 0.24, half * 2.0 + 0.6), 0.5)


## A segmental barrel vault from wall to wall across the short side of ir, its springing at ys, rising `rise` to its
## crown, along the long side; transverse ribs every bay and lamps hung from the crown.
static func _vault(mb: MeshBuilder, ir: Rect2, ys: float, rise: float, bay: float, ceil_y: float, shade: Color) -> void:
	var along_x := ir.size.x >= ir.size.y
	var span := (ir.size.y if along_x else ir.size.x) * 0.5
	var length := ir.size.x if along_x else ir.size.y
	var r := (span * span + rise * rise) / (2.0 * rise)
	var c := ir.get_center()
	var n := 14
	var pts: Array = []
	for i in range(n + 1):
		var u := -span + 2.0 * span * i / n
		pts.append(Vector2(u, ys + sqrt(r * r - u * u) - (r - rise)))
	for i in range(n):
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		var m := (a + b) * 0.5
		var ang := atan2(b.y - a.y, b.x - a.x)
		var size := Vector3(a.distance_to(b) + 0.04, 0.2, length)
		var t: Transform3D
		if along_x:
			t = Transform3D(Basis(Vector3.UP, PI * 0.5) * Basis(Vector3.BACK, ang), Vector3(c.x, m.y + 0.1, c.y - m.x))
		else:
			t = Transform3D(Basis(Vector3.BACK, ang), Vector3(c.x + m.x, m.y + 0.1, c.y))
		mb.add_box(S._wall_m(), t, size, 0.5, shade * (0.86 + 0.08 * (i % 2)))
	# ribs across it every bay, gold on their soffit
	var ribs := maxi(int(length / bay), 2)
	for k in range(1, ribs):
		var v := -length * 0.5 + k * length / ribs
		var o := PackedVector2Array()
		for i in range(n + 1):
			o.append(pts[i] - Vector2(0, 0.0))
		for i in range(n, -1, -1):
			o.append(pts[i] - Vector2(0, 0.45))
		var t := Transform3D(Basis(Vector3.UP, PI * 0.5) if along_x else Basis(), Vector3(c.x + (v if along_x else 0.0), 0, c.y + (0.0 if along_x else v)))
		mb.add_extrude(S._trim_m(), t, o, 0.5, 0.5, shade)
		# a lamp on a chain from the crown between the ribs
		var lv := v - length * 0.5 / ribs
		var lp := Vector3(c.x + (lv if along_x else 0.0), 0, c.y + (0.0 if along_x else lv))
		var crown := ys + rise
		var drop := minf(rise + 2.0, crown - ys + 3.0)
		for j in range(int(drop / 0.35)):
			mb.add_box(S._iron_m(), Transform3D(Basis(Vector3.UP, j * PI * 0.5), lp + Vector3(0, crown - 0.2 - j * 0.35, 0)), Vector3(0.05, 0.28, 0.14), 1.0)
		mb.add_cylinder(S._gold_m(), Transform3D(Basis(), lp + Vector3(0, crown - drop - 0.6, 0)), 0.3, 0.2, 0.3, 6, 1.0)
		mb.add_box(S._window_m(), Transform3D(Basis(), lp + Vector3(0, crown - drop - 0.25, 0)), Vector3(0.4, 0.5, 0.4), 1.0)
		mb.add_pyramid_roof(S._gold_m(), Transform3D(Basis(), lp + Vector3(0, crown - drop + 0.0, 0)), 0.5, 0.5, 0.3, 0.05, 1.0)
	if ceil_y < ys + rise + 0.2:
		push_error("StrongholdInteriors: a vault over its room's ceiling")


## The Casting Hall's roof inside: king-post trusses across it every bay (tie beam, rafters, king post, struts) on stone
## corbels, purlins along, and a travelling crane: rails on corbels down both long walls, its bridge across with a
## trolley, a chain and a hook over the floor.
static func _trusses(mb: MeshBuilder, ir: Rect2, y: float, h: float, bay: float) -> void:
	var wood := PSXMat.lit("planks_dark")
	var iron := S._iron_m()
	var soot := Color(0.5, 0.46, 0.44)
	var ty := y + h - 4.2
	var ry := y + h - 0.4
	var n := maxi(int(ir.size.x / bay), 2)
	for k in range(1, n):
		var x := ir.position.x + k * ir.size.x / n
		var a := Vector3(x, ty, ir.position.y)
		var b := Vector3(x, ty, ir.end.y)
		var top := Vector3(x, ry, ir.get_center().y)
		mb.add_box(wood, M.xf(Vector3(x, ty, ir.get_center().y)), Vector3(0.45, 0.5, ir.size.y), 0.5, soot)
		for e: Vector3 in [a, b]:
			mb.add_box(wood, Transform3D(Basis.looking_at(top - e, Vector3.LEFT), (e + top) * 0.5), Vector3(0.35, 0.35, e.distance_to(top)), 0.5, soot)
			mb.add_box(S._soot_m(), M.xf(e + Vector3(0, -0.6, 0)), Vector3(0.7, 0.7, 0.9), 0.5)
			var mid := e.lerp(top, 0.5)
			var foot := Vector3(x, ty, (e.z + top.z) * 0.5 + (top.z - e.z) * 0.1)
			mb.add_box(wood, Transform3D(Basis.looking_at(mid - foot, Vector3.LEFT), (foot + mid) * 0.5), Vector3(0.22, 0.22, foot.distance_to(mid)), 0.5, soot)
		mb.add_box(wood, M.xf(Vector3(x, (ty + ry) * 0.5, ir.get_center().y)), Vector3(0.3, ry - ty, 0.3), 0.5, soot)
		# a chain and hook hung from the tie beam at every other truss, off the middle
		if k % 2 == 0:
			var hp := Vector3(x, ty - 0.3, ir.get_center().y + (6.0 if k % 4 == 0 else -6.0))
			for j in range(10):
				mb.add_box(iron, Transform3D(Basis(Vector3.UP, j * PI * 0.5), hp + Vector3(0, -j * 0.35, 0)), Vector3(0.06, 0.3, 0.16), 1.0)
			mb.add_box(iron, M.xf(hp + Vector3(0, -3.8, 0)), Vector3(0.12, 0.5, 0.4), 1.0)
	for z: float in [ir.position.y + ir.size.y * 0.25, ir.end.y - ir.size.y * 0.25]:
		mb.add_box(wood, M.xf(Vector3(ir.get_center().x, ty + (ry - ty) * 0.5 + 0.2, z)), Vector3(ir.size.x, 0.3, 0.3), 0.5, soot)
	# the travelling crane
	var cy := y + 8.0
	for z: float in [ir.position.y + 0.5, ir.end.y - 0.5]:
		mb.add_box(iron, M.xf(Vector3(ir.get_center().x, cy, z)), Vector3(ir.size.x, 0.4, 0.4), 1.0)
		for k in range(n + 1):
			mb.add_box(S._soot_m(), M.xf(Vector3(ir.position.x + k * ir.size.x / n, cy - 0.6, z)), Vector3(0.6, 0.8, 0.9), 0.5)
	var bx := ir.position.x + ir.size.x * 0.3
	mb.add_box(iron, M.xf(Vector3(bx, cy + 0.5, ir.get_center().y)), Vector3(0.6, 0.6, ir.size.y), 1.0, Color(0.85, 0.7, 0.3))
	mb.add_box(iron, M.xf(Vector3(bx, cy + 0.1, ir.get_center().y + 3.0)), Vector3(1.0, 0.5, 1.2), 1.0)
	for j in range(9):
		mb.add_box(iron, Transform3D(Basis(Vector3.UP, j * PI * 0.5), Vector3(bx, cy - 0.3 - j * 0.35, ir.get_center().y + 3.0)), Vector3(0.06, 0.3, 0.16), 1.0)
	mb.add_box(iron, M.xf(Vector3(bx, cy - 3.6, ir.get_center().y + 3.0)), Vector3(0.14, 0.6, 0.5), 1.0)


## A fireplace built into the wall: a stone breast proud of it up to the cornice, a navy-trimmed mantel shelf, an arched
## opening with the fire in it, a hood, firedogs and logs; candlesticks and a crest on the breast.
static func _hearth(mb: MeshBuilder, cols: Array, q: Vector2, f: Vector2, y: float, top: float) -> void:
	var al := Vector2(-f.y, f.x)
	var yaw := M.yaw_of(al)
	var depth := 0.9
	var w := 3.2
	var c := q - f * depth * 0.5
	_solid(mb, cols, S._wall_m(), M.xf(M.v3(c + al * (w * 0.5 - 0.4), y + 1.1), yaw), Vector3(depth, 2.2, 0.8))
	_solid(mb, cols, S._wall_m(), M.xf(M.v3(c - al * (w * 0.5 - 0.4), y + 1.1), yaw), Vector3(depth, 2.2, 0.8))
	mb.add_box(S._wall_m(), M.xf(M.v3(c, (y + 2.2 + top) * 0.5), yaw), Vector3(depth, top - y - 2.2, w), 0.5)
	M.box(cols, M.xf(M.v3(c, (y + 2.2 + top) * 0.5), yaw), Vector3(depth, top - y - 2.2, w))
	mb.add_box(S._trim_m(), M.xf(M.v3(c - f * 0.1, y + 2.3), yaw), Vector3(depth + 0.3, 0.2, w + 0.5), 0.5)
	mb.add_box(S._gold_m(), M.xf(M.v3(c - f * 0.27, y + 2.21), yaw), Vector3(0.04, 0.06, w + 0.5), 1.0)
	mb.add_box(PSXMat.flat(Color(0.05, 0.04, 0.04)), M.xf(M.v3(q - f * 0.05, y + 1.0), yaw), Vector3(0.05, 2.0, w - 1.6), 1.0)
	mb.add_box(S._soot_m(), M.xf(M.v3(q - f * 0.4, y + 0.05), yaw), Vector3(0.8, 0.1, w - 1.4), 0.5)
	for k in range(3):
		mb.add_cylinder(PSXMat.lit("bark"), Transform3D(Basis(Vector3.UP, yaw) * Basis(Vector3.BACK, PI * 0.5), M.v3(q - f * (0.25 + k * 0.12) + al * 0.5, y + 0.2 + (0.18 if k == 1 else 0.0))), 0.1, 0.1, 1.0, 6, 1.0)
	mb.add_box(PSXMat.glow(Color(1.0, 0.5, 0.15), 2.4), M.xf(M.v3(q - f * 0.35, y + 0.55), yaw), Vector3(0.3, 0.6, 0.9), 1.0)
	for s: float in [-1.0, 1.0]:
		mb.add_cylinder(S._gold_m(), M.xf(M.v3(c - f * 0.2 + al * s * 1.2, y + 2.4)), 0.06, 0.05, 0.4, 5, 1.0)
		mb.add_box(S._window_m(), M.xf(M.v3(c - f * 0.2 + al * s * 1.2, y + 2.9)), Vector3(0.06, 0.12, 0.06), 1.0)
	S._crest(mb, c - f * (depth * 0.5 + 0.02), y + 3.8, -f, 0.8)
