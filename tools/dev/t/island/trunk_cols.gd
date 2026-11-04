extends SceneTree
## (1.30, the collision audit) Tree trunks are solid where their wood stands: every theme's trees, palms, mangroves and
## giants get a trunk profile (IslandTheme.trunk: columns up the trunk, a column per bend of a leaning one), and most
## of each one's wood up to TRUNK_TOP (roots and low branches aside) lies inside its columns (an upright cylinder at the foot
## missed a palm's lean and a spiral giant's twist); never more than two columns a tree (the physics cost).
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


## How many wood points `mesh` has under the top.
func _wood(IT, mesh: ArrayMesh) -> int:
	var n := 0
	for si in range(mesh.get_surface_count()):
		var mat := mesh.surface_get_material(si) as ShaderMaterial
		if mat == null or mat.shader != PSXMat.LIT_SHADER or (mat.has_meta("psx") and IT.foliage(str(mat.get_meta("psx")[0]))):
			continue
		for v in IT.wood_points(mesh.surface_get_arrays(si)[Mesh.ARRAY_VERTEX]):
			if v.y >= 0.0 and v.y < IT.TRUNK_TOP:
				n += 1
	return n


## The share of `mesh`'s wood (below the top) inside its columns, give or take `slack` m.
func _inside(IT, mesh: ArrayMesh, slack: float) -> float:
	var tk: Array = mesh.get_meta("trunk", [])
	var n := 0
	var ok := 0
	for si in range(mesh.get_surface_count()):
		var mat := mesh.surface_get_material(si) as ShaderMaterial
		if mat == null or mat.shader != PSXMat.LIT_SHADER or (mat.has_meta("psx") and IT.foliage(str(mat.get_meta("psx")[0]))):
			continue
		for v in IT.wood_points(mesh.surface_get_arrays(si)[Mesh.ARRAY_VERTEX]):
			if v.y < 0.0 or v.y >= IT.TRUNK_TOP:
				continue
			n += 1
			for c in tk:
				if v.y >= float(c[1]) - 0.01 and v.y <= float(c[2]) + 0.01 and Vector2(v.x, v.z).distance_to(c[0]) <= float(c[3]) + slack:
					ok += 1
					break
	return float(ok) / maxf(float(n), 1.0)


func _process(_d: float) -> bool:
	if not stage.up:
		return false
	var IT = load("res://scripts/island/island_theme.gd")
	for th in load("res://scripts/island/themes/island_themes.gd").all():
		var m: Dictionary = IT.meshes(th.name)
		var trees := 0
		var bare := 0
		var worst := [1.0, ""]
		var most := 0
		for key in ["tree", "beach_tree", "mangrove", "giant", "fig", "kapok", "emergent"]:
			for e in m.get(key, []):
				var mesh: ArrayMesh = e[0] if e is Array else e
				trees += 1
				var tk: Array = mesh.get_meta("trunk", [])
				# (no columns is right for a plant with no wood low down: the desert's reeds stand in for mangroves)
				if tk.is_empty() and _wood(IT, mesh) > 0:
					bare += 1
					print("   no trunk: %s %d (%s)" % [key, (m[key] as Array).find(e), mesh.get_aabb()])
				if tk.is_empty():
					continue
				most = maxi(most, tk.size())
				var share := _inside(IT, mesh, 0.35)
				if share < worst[0]:
					worst = [share, "%s %s" % [key, mesh.get_meta("made_by", "?")]]
		check("[%s] every tree has its trunk's columns (%d trees, %d without)" % [th.name, trees, bare], trees > 0 and bare == 0)
		check("[%s] ...its wood inside them (worst %.0f%%: %s)" % [th.name, worst[0] * 100.0, worst[1]], worst[0] >= 0.5)
		check("[%s] ...two columns a tree at most (%d)" % [th.name, most], most <= 2)
	return TK.done(fails)
