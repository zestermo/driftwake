extends RefCounted
## Brinehollow's busier harbour (2026-10-17, docs/brinehollow_polish_plan.md step 3, piece 4), built by
## BrinehollowLife: fishing smacks moored bow-out at the quay wall between the piers (MooredHull: walkable, riding
## the swell), two of them going out at dawn to fish off the coast and back in the afternoon (HarbourBoat: where
## each is follows Weather.hour, so a guest's harbour matches the host's), fishers on the piers' edges with rods at
## dawn and in the afternoon, dockers loading the merchantman from the quay. Nothing goes in the sloop's berth:
## the lane from the main pier's berth side out to sea (berth_lane) is kept clear, and the boats' courses run
## straight out from their own moorings and turn away from it.

const Boat := preload("res://scripts/island/harbour_boat.gd")
## Smack moorings at the quay wall (frame s), bow out; the first two go fishing.
const MOORINGS := [-27.0, -9.0, 40.0, -17.0, 54.0]
const SAILING := 2
## How far past the main pier's berth side the lane to sea stays clear.
const LANE_W := 14.0


## Is p (island) in the lane from the sloop's berth out to sea?
static func berth_lane(isl: StarterIsland, p: Vector2) -> bool:
	var h: KitHarbour = isl.harbour
	var side := Vector2(-isl.dock_dir.y, isl.dock_dir.x)
	var sd := signf(side.dot(h.along))
	var ds := h.s_of(h.dock)
	var rel := (h.s_of(p) - ds) * sd
	return rel > 0.0 and rel < h.pier_hw + LANE_W and h.t_of(p) < h.wall(h.s_of(p)) + 1.0


## The side piers (each with its ladder at the end): [root, out, length, node].
static func side_piers(isl: StarterIsland) -> Array:
	var out: Array = []
	for lad in isl.find_children("*", "Ladder", true, false):
		var pier: Node3D = lad.get_parent()
		# (KitHarbour.build_piers': only the first is named "Dock")
		if pier.get_parent() == isl and pier.name != "HarbourPier" and Vector2(pier.position.x, pier.position.z).distance_to(isl.harbour.dock) < 80.0:
			out.append([Vector2(pier.position.x, pier.position.z), Vector2(sin(pier.rotation.y), cos(pier.rotation.y)), float(lad.position.z), pier])
	return out


static func build(isl: StarterIsland, life: Node3D) -> void:
	var h: KitHarbour = isl.harbour
	var made := 0
	for s: float in MOORINGS:
		if s < h.s0 + 3.0 or s > h.s1 - 3.0:
			continue
		var q := h.quay_pt(s, -3.6)
		if berth_lane(isl, q):
			push_error("BrinehollowHarbour: a mooring in the sloop's lane")
			continue
		if made < SAILING:
			var b := Boat.new()
			b.name = "Smack%d" % made
			b.setup(isl, q, -h.inland, made)
			isl.add_child(b)
		else:
			var hull := MooredHull.new()
			hull.name = "Smack%d" % made
			hull.freeboard = 0.15
			hull.half_len = 2.4
			hull.collision_layer = 1
			hull.collision_mask = 0
			isl.kit.put(hull, Vector3(q.x, 0.15, q.y), KitContext.face_yaw(h.inland))
			TraderShips.longboat(hull)
			hull.add_child(Boat.rig(false))
		made += 1


## A fishing rod for a fisher's right hand, its line hanging from the tip (hidden until they sit to fish).
static func rod() -> Node3D:
	var mb := MeshBuilder.new()
	var cane := PSXMat.lit("bark")
	var tip := Vector3(0, 0.7, -2.3)
	mb.add_tube(cane, PackedVector3Array([Vector3(0, 0, 0.25), tip]), 0.025, -1.0, 4)
	mb.add_tube(PSXMat.flat(Color(0.85, 0.85, 0.8)), PackedVector3Array([tip, tip + Vector3(0, -2.6, -0.3)]), 0.006, -1.0, 3)
	var mi := mb.to_instance("Rod")
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visible = false
	return mi
