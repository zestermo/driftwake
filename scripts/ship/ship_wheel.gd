class_name ShipWheel
extends RefCounted
## The crew's ship's wheel and its pedestal (1.29): eight spokes through a hub and an inner ring, a heavy rim, turned
## handles past it, on a turned post with the axle box at its head. The Rudder & helm line (ShipLines "rudder") shows
## on it level by level: 2 brass (a brass band round the rim, ferrules on the handles, a brass hub), 3 the binnacle
## forward of it (ShipParts), 4 a carved pedestal (a panelled box, scrolls either side, a capped crown), 5 gilding (a
## gilt boss and star on the hub, gilt knobs, a gilt crown). Wheel-local: the hub at the origin, the axle along Z
## (the helmsman aft, +Z); the pedestal from the deck under it.

## The rim's radius, the handles' reach past it, and the hub's height over the deck.
const R := 0.46
const HANDLE := 0.17
const HUB_Y := 0.93
const SPOKES := 8


static func mats() -> Dictionary:
	return {
		"oak": PSXMat.lit("planks_dark", Color(0.95, 0.78, 0.6)),
		"dark": PSXMat.lit("planks_dark", Color(0.62, 0.5, 0.4)),
		"brass": PSXMat.lit("metal", Color(1.0, 0.78, 0.4)),
		"gilt": PSXMat.lit("", Color(1.0, 0.76, 0.28)),
		"iron": PSXMat.lit("metal", Color(0.3, 0.3, 0.32)),
	}


## The wheel itself (it turns: its own node).
static func wheel(mb: MeshBuilder, m: Dictionary, level: int) -> void:
	var oak: Material = m["oak"]
	var dark: Material = m["dark"]
	var brass := level >= 2
	var gilt := level >= 5
	# the rim: twelve felloes round, a little proud fore and aft of the spokes
	for k in range(12):
		var a := TAU * (k + 0.5) / 12.0
		var p := Vector3(cos(a), sin(a), 0) * R
		var b := Basis(Vector3.BACK, a)
		mb.add_box(oak, Transform3D(b, p), Vector3(0.07, R * TAU / 12.0 + 0.02, 0.08), 1.0)
		if brass:
			# a brass band round its outer face
			mb.add_box(m["brass"], Transform3D(b, p * ((R + 0.038) / R)), Vector3(0.012, R * TAU / 12.0 + 0.03, 0.05), 1.0)
	# an inner ring the spokes pass through
	for k in range(8):
		var a := TAU * (k + 0.5) / 8.0
		mb.add_box(dark, Transform3D(Basis(Vector3.BACK, a), Vector3(cos(a), sin(a), 0) * 0.24), Vector3(0.04, 0.24 * TAU / 8.0 + 0.01, 0.05), 1.0)
	# the spokes, each turned out past the rim into a handle
	for k in range(SPOKES):
		var a := TAU * k / SPOKES
		var dir := Vector3(cos(a), sin(a), 0)
		var b := Basis(Vector3.BACK, a - PI * 0.5)
		mb.add_box(oak, Transform3D(b, dir * (0.08 + (R - 0.08) * 0.5)), Vector3(0.04, R - 0.08, 0.04), 1.0)
		mb.add_cylinder(oak, Transform3D(b, dir * (R + 0.03)), 0.03, 0.022, HANDLE - 0.03, 6, 1.0)
		mb.add_cylinder(m["gilt"] if gilt else oak, Transform3D(b, dir * (R + HANDLE - 0.01)), 0.032, 0.02, 0.05, 6, 1.0, Color.WHITE, true, true)
		if brass:
			mb.add_cylinder(m["brass"], Transform3D(b, dir * (R + 0.035)), 0.033, 0.033, 0.025, 6, 1.0, Color.WHITE, true, true)
	# the hub, the axle's end through it
	var hub: Material = m["brass"] if brass else dark
	mb.add_cylinder(hub, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 0, -0.07)), 0.095, 0.095, 0.15, 8, 1.0, Color.WHITE, true, true)
	mb.add_cylinder(m["iron"], Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 0, 0.08)), 0.035, 0.035, 0.06, 6, 1.0, Color.WHITE, true, true)
	if gilt:
		# a gilt boss and a star on its face (toward the helmsman)
		mb.add_cylinder(m["gilt"], Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 0, 0.08)), 0.07, 0.05, 0.04, 8, 1.0, Color.WHITE, true, true)
		for k in range(4):
			mb.add_box(m["gilt"], Transform3D(Basis(Vector3.BACK, TAU * k / 8.0), Vector3(0, 0, 0.1)), Vector3(0.025, 0.2, 0.012), 1.0)


## The pedestal under the wheel: `at` on the deck straight under the hub (the wheel's plane), the post just forward.
static func pedestal(mb: MeshBuilder, m: Dictionary, at: Vector3, level: int) -> void:
	var oak: Material = m["oak"]
	var dark: Material = m["dark"]
	var post := at + Vector3(0, 0, -0.16)
	if level >= 4:
		# carved: a panelled box on a plinth, scrolls either side, a capped crown under the axle box
		mb.add_box(dark, Transform3D(Basis(), post + Vector3(0, 0.05, 0)), Vector3(0.56, 0.1, 0.5), 1.0)
		mb.add_box(oak, Transform3D(Basis(), post + Vector3(0, 0.42, 0)), Vector3(0.38, 0.64, 0.34), 1.0)
		for sx in [-1.0, 1.0]:
			# a sunk panel on each face, and a scroll bracket curling out at the side
			mb.add_box(dark, Transform3D(Basis(), post + Vector3(sx * 0.192, 0.42, 0)), Vector3(0.01, 0.44, 0.22), 1.0)
			mb.add_cylinder(oak, Transform3D(Basis(Vector3.BACK, PI * 0.5), post + Vector3(sx * 0.21, 0.2, 0)), 0.07, 0.07, 0.06, 7, 1.0, Color.WHITE, true, true)
			mb.add_box(oak, Transform3D(Basis(Vector3.BACK, sx * 0.5), post + Vector3(sx * 0.24, 0.42, 0)), Vector3(0.05, 0.4, 0.1), 1.0)
		for sz in [-1.0, 1.0]:
			mb.add_box(dark, Transform3D(Basis(), post + Vector3(0, 0.42, sz * 0.172)), Vector3(0.24, 0.44, 0.01), 1.0)
		mb.add_box(dark, Transform3D(Basis(), post + Vector3(0, 0.77, 0)), Vector3(0.44, 0.06, 0.4), 1.0)
		if level >= 5:
			mb.add_box(m["gilt"], Transform3D(Basis(), post + Vector3(0, 0.81, 0)), Vector3(0.46, 0.025, 0.42), 1.0)
			for sx in [-1.0, 1.0]:
				mb.add_cylinder(m["gilt"], Transform3D(Basis(Vector3.BACK, PI * 0.5), post + Vector3(sx * 0.245, 0.2, 0)), 0.035, 0.035, 0.02, 7, 1.0, Color.WHITE, true, true)
	else:
		# a square plinth, a turned post, a collar
		mb.add_box(dark, Transform3D(Basis(), post + Vector3(0, 0.05, 0)), Vector3(0.36, 0.1, 0.36), 1.0)
		mb.add_cylinder(oak, Transform3D(Basis(), post + Vector3(0, 0.1, 0)), 0.1, 0.075, 0.3, 8, 1.0)
		mb.add_cylinder(dark, Transform3D(Basis(), post + Vector3(0, 0.4, 0)), 0.095, 0.095, 0.05, 8, 1.0, Color.WHITE, true, true)
		mb.add_cylinder(oak, Transform3D(Basis(), post + Vector3(0, 0.45, 0)), 0.075, 0.09, 0.32, 8, 1.0)
	# the axle box at the head, the axle out to the hub
	mb.add_box(dark, Transform3D(Basis(), post + Vector3(0, HUB_Y - 0.08, -0.02)), Vector3(0.22, 0.24, 0.26), 1.0)
	mb.add_box(oak, Transform3D(Basis(), post + Vector3(0, HUB_Y + 0.06, -0.02)), Vector3(0.26, 0.04, 0.3), 1.0)
	mb.add_cylinder(m["iron"], Transform3D(Basis(Vector3.RIGHT, PI * 0.5), at + Vector3(0, HUB_Y, -0.03)), 0.03, 0.03, 0.14, 6, 1.0)
