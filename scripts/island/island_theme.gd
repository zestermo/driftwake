class_name IslandTheme
extends RefCounted
## How a theme's islands are made (GenIsland): the land's shape and the plants and rocks on
## it, read from the theme's file through the registry (IslandThemes; ThemeDef.land says what
## the def holds). The chain only rolls registered themes.


static func has(theme: String) -> bool:
	return IslandThemes.has(theme)


static func def(theme: String) -> Dictionary:
	return IslandThemes.of(theme).land


## The meshes a theme's islands use, built once per theme (main thread, before GenIsland.prepare).
static var _meshes := {}


static func meshes(theme: String) -> Dictionary:
	if not _meshes.has(theme):
		_meshes[theme] = IslandThemes.of(theme).meshes()
		for key in ["tree", "beach_tree", "mangrove", "giant", "fig", "kapok", "emergent", "broadleaf"]:
			for e in _meshes[theme].get(key, []):
				for m in (e if e is Array else [e]):
					if m is ArrayMesh and not (m as ArrayMesh).has_meta("trunk"):
						(m as ArrayMesh).set_meta("trunk", trunk(m))
						(m as ArrayMesh).set_meta("log", lying(m) if key == "broadleaf" else [])
						if key in ["giant", "fig", "kapok", "emergent"]:
							(m as ArrayMesh).set_meta("hull", hull_points(m))
		for e in _meshes[theme].get("rock", []):
			(e as ArrayMesh).set_meta("hull", hull_points(e))
	return _meshes[theme]


## (1.30) Where a tree's trunk stands, for its colliders: the wood (not the leaves or needles) in 2.5 m slices up to
## TRUNK_TOP, each [middle (x, z), y0, y1, radius] in the mesh's space, a straight run of slices merged into one. A
## leaning or twisting trunk gets a column per bend instead of one upright cylinder half beside it. Main thread (reads
## the mesh's arrays); [] for a mesh with no wood low down.
const TRUNK_TOP := 5.0
const TRUNK_SLICE := 2.5
const FOLIAGE := ["pine_snow", "fir_needles", "palm_frond", "fern", "bush", "grass_tuft", "thornbrush", "moss", "snow", "volcanic_ash"]


## Whether a texture is leaves, needles, fronds, hanging moss or snow lying on a plant (walked through, never collided).
static func foliage(tex: String) -> bool:
	return tex.begins_with("leaves") or tex in FOLIAGE


## A tree's trunk colliders into `body` where its wood stands (trunk()), the tree at `xf` in the body's space; false
## when its mesh has no profile.
static func trunk_cols(body: Node, mesh: Mesh, xf: Transform3D) -> bool:
	var tk: Array = mesh.get_meta("trunk", [])
	var sc := xf.basis.get_scale().x
	for c in tk:
		var m: Vector2 = c[0]
		var cs := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = float(c[3]) * sc
		cyl.height = (float(c[2]) - float(c[1])) * sc
		cs.shape = cyl
		cs.position = xf * Vector3(m.x, (float(c[1]) + float(c[2])) * 0.5, m.y)
		body.add_child(cs)
	return not tk.is_empty()


## Points over a surface's triangles every ~0.5 m (a trunk drawn as one tall cylinder has vertices only at its ends).
static func wood_points(v: PackedVector3Array) -> PackedVector3Array:
	var out := PackedVector3Array()
	for t in range(0, v.size() - 2, 3):
		var a := v[t]
		var b := v[t + 1]
		var c := v[t + 2]
		if minf(a.y, minf(b.y, c.y)) >= TRUNK_TOP:
			continue
		var k := clampi(ceili(maxf(a.distance_to(b), maxf(b.distance_to(c), c.distance_to(a))) / 0.5), 1, 16)
		for i in range(k + 1):
			for j in range(k + 1 - i):
				out.append(a + (b - a) * (float(i) / k) + (c - a) * (float(j) / k))
	return out


static func trunk(mesh: ArrayMesh) -> Array:
	var n := ceili(TRUNK_TOP / TRUNK_SLICE)
	var pts: Array = []
	for k in range(n):
		pts.append([])
	for si in range(mesh.get_surface_count()):
		var mat := mesh.surface_get_material(si) as ShaderMaterial
		if mat == null or mat.shader != PSXMat.LIT_SHADER or (mat.has_meta("psx") and foliage(str(mat.get_meta("psx")[0]))):
			continue
		for v in wood_points(mesh.surface_get_arrays(si)[Mesh.ARRAY_VERTEX]):
			if v.y >= 0.0 and v.y < TRUNK_TOP:
				(pts[int(v.y / TRUNK_SLICE)] as Array).append(v)
	var out: Array = []
	for k in range(n):
		var list: Array = pts[k]
		if list.size() < 6:
			break
		var c := Vector2.ZERO
		for v in list:
			c += Vector2(v.x, v.z) / list.size()
		var d: Array = list.map(func(v): return Vector2(v.x, v.z).distance_to(c))
		d.sort()
		var r: float = d[d.size() / 2]
		var y0 := k * TRUNK_SLICE
		# (no higher than the wood goes: a stump or a cactus ends under the slice's top)
		var y1 := y0
		for v in list:
			y1 = maxf(y1, v.y)
		if not out.is_empty() and (out[-1][0] as Vector2).distance_to(c) < 0.35 and absf(float(out[-1][3]) - r) < 0.25:
			out[-1][2] = y1
			out[-1][3] = maxf(float(out[-1][3]), r)
		else:
			out.append([c, y0, y1, r])
	return out


## (1.30) A big tree's or a rock's own convex shape: its wood's (or stone's) vertices up to TRUNK_TOP, each once. A giant's
## buttresses and a rock's long side stood out of the one upright cylinder or sphere they had.
static func hull_points(mesh: ArrayMesh) -> PackedVector3Array:
	var seen := {}
	var out := PackedVector3Array()
	for si in range(mesh.get_surface_count()):
		var mat := mesh.surface_get_material(si) as ShaderMaterial
		if mat == null or mat.shader != PSXMat.LIT_SHADER or (mat.has_meta("psx") and foliage(str(mat.get_meta("psx")[0]))):
			continue
		# (a quarter-metre grid: enough to keep the shape, few enough points to build it quick)
		for v in wood_points(mesh.surface_get_arrays(si)[Mesh.ARRAY_VERTEX]):
			var k := Vector3i((v * 4.0).round())
			if v.y < TRUNK_TOP and not seen.has(k):
				seen[k] = true
				out.append(v)
	return out


## (1.30) A fallen log's capsule: its wood's box lies long and low (twice as long as it's tall) -> [end, end, radius] in
## the mesh's space along its long axis, or [] for anything else (Zach: logs are solid; the step-up takes captains over).
static func lying(mesh: ArrayMesh) -> Array:
	var box := AABB()
	var any := false
	for si in range(mesh.get_surface_count()):
		var mat := mesh.surface_get_material(si) as ShaderMaterial
		if mat == null or mat.shader != PSXMat.LIT_SHADER or (mat.has_meta("psx") and foliage(str(mat.get_meta("psx")[0]))):
			continue
		for v in (mesh.surface_get_arrays(si)[Mesh.ARRAY_VERTEX] as PackedVector3Array):
			box = box.expand(v) if any else AABB(v, Vector3.ZERO)
			any = true
	# (long one way only: a ring of toadstools is wide both ways)
	if not any or maxf(box.size.x, box.size.z) < box.size.y * 2.0 or minf(box.size.x, box.size.z) > box.size.y * 1.6 or box.size.y < 0.35 or box.size.y > 1.5:
		return []
	var r := box.size.y * 0.5
	var c := box.get_center()
	var along := Vector3(box.size.x * 0.5 - r, 0, 0) if box.size.x >= box.size.z else Vector3(0, 0, box.size.z * 0.5 - r)
	return [c - along, c + along, r]


## Whether a profile stands up (a trunk, a cactus, a stump): a fallen log's would be a squat disc over the air beside it.
static func upright(tk: Array) -> bool:
	return not tk.is_empty() and float(tk[0][2]) - float(tk[0][1]) >= float(tk[0][3]) * 1.5
