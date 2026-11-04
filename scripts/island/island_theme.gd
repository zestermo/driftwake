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
		for key in ["tree", "beach_tree", "mangrove", "giant", "fig", "kapok", "emergent"]:
			for e in _meshes[theme].get(key, []):
				for m in (e if e is Array else [e]):
					if m is ArrayMesh and not (m as ArrayMesh).has_meta("trunk"):
						(m as ArrayMesh).set_meta("trunk", trunk(m))
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
		if not out.is_empty() and (out[-1][0] as Vector2).distance_to(c) < 0.35 and absf(float(out[-1][3]) - r) < 0.25:
			out[-1][2] = y0 + TRUNK_SLICE
			out[-1][3] = maxf(float(out[-1][3]), r)
		else:
			out.append([c, y0, y0 + TRUNK_SLICE, r])
	return out
