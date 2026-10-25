extends SceneTree
## The fog isle's giants have far versions (1.21 small fixes): each spiral and gnarled giant comes with a light mesh
## of the same tree (same size and shape, under ~60% of the triangles), and the fog theme's big-tree slots all carry
## one, so GenIsland shows the full tree close and the light one far off.
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


func _tris(m: Mesh) -> int:
	var n := 0
	for i in range(m.get_surface_count()):
		var a: Array = m.surface_get_arrays(i)
		n += (a[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3 if a[Mesh.ARRAY_INDEX] != null else (a[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	return n


func _process(_d: float) -> bool:
	if not stage.up:
		return false
	var FP = load("res://scripts/props/fog_plants.gd")
	for g in [["spiral", FP.spiral_giant(951)], ["gnarled", FP.gnarl_giant(955)]]:
		var t: Array = g[1]
		var near: Mesh = t[0]
		var far: Mesh = t[4] if t.size() > 4 else null
		check("the %s giant has a far version" % g[0], far != null)
		if far == null:
			continue
		var a := near.get_aabb()
		var b := far.get_aabb()
		check("...the same tree (size %.1f vs %.1f m)" % [a.size.length(), b.size.length()], absf(a.size.length() - b.size.length()) < a.size.length() * 0.08 and a.position.distance_to(b.position) < 2.0)
		check("...far lighter (%d of %d triangles)" % [_tris(far), _tris(near)], _tris(far) < _tris(near) * 0.6)
	var m: Dictionary = load("res://scripts/island/island_theme.gd").meshes("fog")
	var all := true
	for k in ["giant", "fig", "kapok", "emergent"]:
		for e in m.get(k, []):
			if not (e is Array and e.size() > 4 and e[4] is Mesh):
				all = false
	check("every big-tree slot on the fog isle carries a far version", all)
	return TK.done(fails)
