class_name DrawLOD
extends RefCounted
## The draw-call pass over a place once it's built (Brinehollow, a chain island):
## - a mesh whose surfaces differ only by tint becomes one surface per texture
##   (MeshBuilder.fold_tints; shared meshes once each);
## - visibility ranges by size for whatever set none itself: a thing stops drawing once
##   it would be ~2 pixels on the 640x360 grid (PX_PER_M metres of range per metre of
##   size), glowing things later, nothing as big as a landmark ever (past the camera's far);
## - small things stop casting shadows.
## Characters (Humanoid) set their own (BodyBuilder.RANGE).

const PX_PER_M := 130.0
const MIN_END := 45.0
const NEVER := 1200.0
## Glowing things (lanterns, windows) are seen from much further at night.
const GLOW_K := 3.0
const NO_SHADOW_UNDER := 0.9


## Everything under `root` built so far. Returns [geometry, surfaces folded away, ranges set, shadows turned off].
static func apply(root: Node) -> Array:
	var out := [0, 0, 0, 0]
	var folds := {}
	var list: Array = []
	_walk(root, list)
	for g in list:
		_fit(g, out, folds)
	return out


## apply as `count` build steps ([name, Callable], GenIsland.finish_steps) of about BUDGET_MS each:
## the first finds the geometry, the last does whatever is left.
const BUDGET_MS := 12
static func steps(root: Node, count: int) -> Array:
	var st := {"list": null, "i": 0, "out": [0, 0, 0, 0], "folds": {}}
	var out: Array = []
	for k in range(count):
		out.append(["draw lod", func():
			if st["list"] == null:
				st["list"] = []
				_walk(root, st["list"])
			var list: Array = st["list"]
			var t0 := Time.get_ticks_msec()
			while int(st["i"]) < list.size() and (k == count - 1 or Time.get_ticks_msec() - t0 < BUDGET_MS):
				var g = list[st["i"]]
				st["i"] = int(st["i"]) + 1
				if is_instance_valid(g):
					_fit(g, st["out"], st["folds"])])
	return out


## A creature's parts (a bug and its legs): ranges by each part's size, nothing else
## (its materials are its own copies for the hit flash; small parts keep their shadows).
static func creature(root: Node) -> void:
	for g in root.find_children("*", "MeshInstance3D", true, false):
		var mi := g as MeshInstance3D
		if mi.visibility_range_end > 0.0 or mi.mesh == null:
			continue
		var size := (mi.global_transform.basis * mi.mesh.get_aabb().size).abs()
		var end := maxf(MIN_END, PX_PER_M * maxf(size.x, maxf(size.y, size.z)))
		if end < NEVER:
			mi.visibility_range_end = end
			mi.visibility_range_end_margin = end * 0.1


static func _walk(n: Node, list: Array) -> void:
	for c in n.get_children():
		if c is Humanoid or c is CharacterBody3D:
			continue
		if c is MeshInstance3D or c is MultiMeshInstance3D:
			list.append(c)
		_walk(c, list)


static func _fit(g: GeometryInstance3D, out: Array, folds: Dictionary) -> void:
	if g is MeshInstance3D:
		_fold(g as MeshInstance3D, out, folds)
	if g.visibility_range_end > 0.0 or g.visibility_range_begin > 0.0:
		return
	var mesh: Mesh = (g as MeshInstance3D).mesh if g is MeshInstance3D else (g as MultiMeshInstance3D).multimesh.mesh
	if mesh == null:
		return
	out[0] += 1
	var box := mesh.get_aabb()
	if g is MultiMeshInstance3D:
		# (the server's AABB: empty under the headless renderer, so work it out here)
		var mm := (g as MultiMeshInstance3D).multimesh
		if mm.instance_count == 0:
			return
		box = mm.get_instance_transform(0) * mesh.get_aabb()
		for i in range(1, mm.instance_count):
			box = box.merge(mm.get_instance_transform(i) * mesh.get_aabb())
	var size := (g.global_transform * box).size
	var s := maxf(size.x, maxf(size.y, size.z))
	var end := maxf(MIN_END, PX_PER_M * s)
	if _glows(mesh) or (g.material_override is ShaderMaterial and (g.material_override as ShaderMaterial).get_shader_parameter("emission_tex") != null):
		end *= GLOW_K
	if end < NEVER:
		g.visibility_range_end = end
		g.visibility_range_end_margin = end * 0.1
		out[2] += 1
	if s < NO_SHADOW_UNDER and g.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
		g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		out[3] += 1


## (not under a material override or a surface override: those would multiply the baked tints)
static func _fold(mi: MeshInstance3D, out: Array, folds: Dictionary) -> void:
	if mi.material_override != null or not mi.mesh is ArrayMesh:
		return
	for i in range(mi.get_surface_override_material_count()):
		if mi.get_surface_override_material(i) != null:
			return
	var m := mi.mesh as ArrayMesh
	if not folds.has(m):
		folds[m] = m
		var mb := MeshBuilder.from_mesh(m)
		if mb != null:
			mb.fold_tints()
			if mb.surface_count() < m.get_surface_count():
				var f := mb.commit()
				f.custom_aabb = m.custom_aabb
				folds[m] = f
	var to: ArrayMesh = folds[m]
	if to != m:
		out[1] += m.get_surface_count() - to.get_surface_count()
		mi.mesh = to


static func _glows(mesh: Mesh) -> bool:
	for i in range(mesh.get_surface_count()):
		var m := mesh.surface_get_material(i) as ShaderMaterial
		if m != null and m.get_shader_parameter("emission_tex") != null:
			return true
	return false
