extends SceneTree
## Footsteps by what's underfoot on the themes' ground: a snow island's terrain is snow (its packed paths too),
## its frozen lakes ice; a desert's terrain is sand; home's grass is still grass. A generated island's terrain
## collider (Ground0 beside its Terrain mesh) is read like the terrain. And the snow and ice steps load.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


## A 3 x 3 vertex patch of terrain (splat `col` everywhere) in a theme's ground, 6 m across, at `at`.
## `split`: the collider is a Ground0 body beside the Terrain body holding the mesh, as on a GenIsland.
func _terrain(at: Vector3, ground: Dictionary, col: Color, split: bool) -> void:
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	for iz in range(3):
		for ix in range(3):
			verts.append(Vector3(-3.0 + ix * 3.0, 0.0, -3.0 + iz * 3.0))
			norms.append(Vector3.UP)
			cols.append(col)
	var idx := PackedInt32Array([0, 1, 3, 1, 4, 3, 1, 2, 4, 2, 5, 4, 3, 4, 6, 4, 7, 6, 4, 5, 7, 5, 8, 7])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_COLOR] = cols
	arr[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	mesh.surface_set_material(0, load("res://scripts/psx/psx_mat.gd").terrain(true, 0.0, ground))
	var isle := Node3D.new()
	isle.position = at
	stage.add_child(isle)
	var body := StaticBody3D.new()
	body.name = "Terrain"
	var mi := MeshInstance3D.new()
	mi.name = "MeshInstance3D"
	mi.mesh = mesh
	body.add_child(mi)
	isle.add_child(body)
	var cb := body
	if split:
		cb = StaticBody3D.new()
		cb.name = "Ground0"
		isle.add_child(cb)
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(6, 0.2, 6)
	cs.shape = sh
	cs.position = Vector3(0, -0.1, 0)
	cb.add_child(cs)


## A box you can stand on with `tex` on it (the frozen lake's ice), at `at`.
func _slab(at: Vector3, tex: String) -> void:
	var body := StaticBody3D.new()
	body.position = at
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(4, 0.2, 4)
	mi.mesh = bm
	var m := StandardMaterial3D.new()
	m.albedo_texture = load("res://assets/textures/psx/%s.png" % tex)
	mi.material_override = m
	body.add_child(mi)
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = bm.size
	cs.shape = sh
	body.add_child(cs)
	stage.add_child(body)


func _under(at: Vector3) -> String:
	var n := Node3D.new()
	stage.add_child(n)
	n.global_position = at
	var s: String = load("res://scripts/game/footsteps.gd").surface_under(n)
	n.queue_free()
	return s


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			var KS = load("res://scripts/island/kit/kit_style.gd")
			var y: float = stage.GROUND_Y + 5.0
			_terrain(Vector3(20, y, 0), KS.of("snow")["ground"], Color(0, 0, 0, 1), false)
			_terrain(Vector3(30, y, 0), KS.of("snow")["ground"], Color(1, 0, 0, 1), true)
			_terrain(Vector3(40, y, 0), KS.of("desert")["ground"], Color(0, 0, 0, 1), true)
			_terrain(Vector3(-20, y, 0), KS.of("brinehollow")["ground"], Color(0, 0, 0, 1), false)
			_terrain(Vector3(-30, y, 0), KS.of("jungle")["ground"], Color(0, 0, 1, 1), true)
			_slab(Vector3(0, y, 20), "ice")
			until = TK.wait_ticks(3)
		1:
			var y: float = stage.GROUND_Y + 5.0
			check("a snow island's open ground is snow (%s)" % _under(Vector3(20, y, 0)), _under(Vector3(20, y, 0)) == "snow")
			check("...its packed paths too, read through its Ground collider (%s)" % _under(Vector3(30, y, 0)), _under(Vector3(30, y, 0)) == "snow")
			check("...and its frozen lakes are ice (%s)" % _under(Vector3(0, y + 0.1, 20)), _under(Vector3(0, y + 0.1, 20)) == "ice")
			check("a desert's dunes are sand (%s)" % _under(Vector3(40, y, 0)), _under(Vector3(40, y, 0)) == "sand")
			check("home's grass is still grass (%s)" % _under(Vector3(-20, y, 0)), _under(Vector3(-20, y, 0)) == "grass")
			check("a jungle beach is sand (%s)" % _under(Vector3(-30, y, 0)), _under(Vector3(-30, y, 0)) == "sand")
			var fx = root.get_node("FX")
			check("the snow and ice steps load, four takes each", fx._streams.has("step_snow") and fx._streams.has("step_ice")
				and (fx._streams["step_snow"] as AudioStreamRandomizer).streams_count == 4 and (fx._streams["step_ice"] as AudioStreamRandomizer).streams_count == 4)
			return TK.done(fails)
	step += 1
	return false
