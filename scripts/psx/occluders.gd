class_name Occluders
extends RefCounted
## Occlusion culling's occluders (rendering/occlusion_culling/use_occlusion_culling): boxes kept inside a town's
## solid walls (a house's walls, a curtain wall, a tower's shaft), so whatever stands behind them isn't drawn.
## A box must lie wholly inside opaque geometry, or something seen past its edge would vanish: builders shrink
## them by MARGIN and leave out anything with an opening (arches, arcades, porches, rooms you walk into).
## Builders on a worker keep them as data ({"occ": size, "xf"} in a piece's colliders); `node` makes the
## OccluderInstance3D on the main thread (an Occluder3D is a server object).

const MARGIN := 0.15
## Too small to hide much (a box under this in two of its sizes isn't kept).
const MIN := 1.6


static func box(cols: Array, t: Transform3D, size: Vector3) -> void:
	var s := size - Vector3.ONE * MARGIN * 2.0
	if int(s.x >= MIN) + int(s.y >= MIN) + int(s.z >= MIN) < 2 or s.x <= 0.0 or s.y <= 0.0 or s.z <= 0.0:
		return
	cols.append({"occ": s, "xf": t})


## `cols` without its occluders, and their boxes as one mesh ([vertices, indices]; empty when there are none).
static func take(cols: Array) -> Array:
	var solid: Array = []
	var verts := PackedVector3Array()
	var idx := PackedInt32Array()
	for c in cols:
		if c.has("occ"):
			_add(verts, idx, c["xf"], c["occ"])
		else:
			solid.append(c)
	return [solid, [verts, idx]]


static func _add(verts: PackedVector3Array, idx: PackedInt32Array, t: Transform3D, size: Vector3) -> void:
	var h := size * 0.5
	var b := verts.size()
	for k in range(8):
		verts.append(t * Vector3(h.x * (1 if k & 1 else -1), h.y * (1 if k & 2 else -1), h.z * (1 if k & 4 else -1)))
	for q in [[0, 2, 3, 1], [4, 5, 7, 6], [0, 1, 5, 4], [2, 6, 7, 3], [0, 4, 6, 2], [1, 3, 7, 5]]:
		idx.append_array([b + q[0], b + q[1], b + q[2], b + q[0], b + q[2], b + q[3]])


## The occluders of [vertices, indices] (`take`'s), or null when there are none.
static func node(mesh: Array) -> OccluderInstance3D:
	if (mesh[0] as PackedVector3Array).is_empty():
		return null
	var occ := ArrayOccluder3D.new()
	occ.set_arrays(mesh[0], mesh[1])
	var oi := OccluderInstance3D.new()
	oi.name = "Occluder"
	oi.occluder = occ
	return oi


## One box's occluder, for a building made on the main thread (Buildings.house).
static func box_node(t: Transform3D, size: Vector3) -> OccluderInstance3D:
	var cols: Array = []
	box(cols, t, size)
	return node(take(cols)[1])
