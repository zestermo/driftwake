extends RefCounted
## What's underfoot, for footsteps: "sand", "grass", "dirt", "stone" or
## "wood" (shallow water is the caller's: it knows how deep it's standing).
## Each machine looks under every captain it sees, puppets too, so nothing
## is sent over the network.
##
## A ray goes down from the feet. Terrain (the terrain shader) is read like the
## shader paints it: its splat (dirt/sand) or its height (wet sand, sand), rock
## where it's steep, grass elsewhere. Anything else is judged once by the
## textures on its meshes (planks, stone, sand...): ships, piers and houses
## come out wood, the fort and ruins stone. A collider with a "surface" meta
## says for itself.

const TERRAIN_SHADER := preload("res://scenes/island/terrain.gdshader")
## (the shader's own height and slope rules, from PSXMat.terrain)
const SAND_ABOVE_WATER := 2.2
const ROCK_ABOVE_WATER := 14.0
const STEEP := 0.45
const WOOD_TEX := ["plank", "deck", "door", "bark", "rope", "straw", "thatch", "canvas", "fabric", "cloth", "leather"]
const STONE_TEX := ["stone", "rock", "cobble", "brick", "plaster", "driftstone", "roof_tiles", "metal"]
const SAND_TEX := ["sand", "seafloor"]
const GRASS_TEX := ["grass", "fern", "bush", "leaves", "thornbrush", "palm_frond"]

static var _kinds := {}
static var _grids := {}


static func surface_under(body: Node3D) -> String:
	var at := body.global_position
	var q := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 0.4, at + Vector3.DOWN * 1.0, 1)
	var hit := body.get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return "dirt"
	var col := hit["collider"] as Node
	if col == null:
		return "dirt"
	if col.has_meta("surface"):
		return str(col.get_meta("surface"))
	var mi := _terrain_mesh(col)
	if mi:
		return _terrain_surface(mi, hit["position"], hit["normal"])
	var id := col.get_instance_id()
	if not _kinds.has(id):
		if _kinds.size() > 512:
			_kinds.clear()
		_kinds[id] = _judge(col)
	return _kinds[id]


static func _terrain_mesh(col: Node) -> MeshInstance3D:
	for c in col.get_children():
		if c is MeshInstance3D:
			var m := (c as MeshInstance3D).get_active_material(0) as ShaderMaterial
			if m and m.shader == TERRAIN_SHADER:
				return c
	return null


## Read the terrain where the foot came down, as the shader paints it.
static func _terrain_surface(mi: MeshInstance3D, p: Vector3, n: Vector3) -> String:
	var m := mi.get_active_material(0) as ShaderMaterial
	var water := float(m.get_shader_parameter("water_level"))
	if 1.0 - clampf(n.y, 0.0, 1.0) > STEEP and p.y > water + 0.5:
		return "stone"
	var sand := 0.0
	var dirt := 0.0
	var rock := 0.0
	if bool(m.get_shader_parameter("use_splat")):
		var w := _splat_at(mi, p)
		dirt = w.r
		rock = w.g
		sand = w.b
	else:
		sand = 1.0 - smoothstep(water + SAND_ABOVE_WATER - 0.8, water + SAND_ABOVE_WATER + 0.8, p.y)
		rock = smoothstep(water + ROCK_ABOVE_WATER - 2.0, water + ROCK_ABOVE_WATER + 2.0, p.y)
	# (wet sand at the water's edge)
	sand = maxf(sand, 1.0 - smoothstep(water + 0.1, water + 0.8, p.y))
	var grass := clampf(1.0 - sand - dirt - rock, 0.0, 1.0)
	var best := maxf(maxf(sand, dirt), maxf(rock, grass))
	if best == rock:
		return "stone"
	if best == sand:
		return "sand"
	if best == dirt:
		return "dirt"
	return "grass"


## The splat colour (r dirt, g rock, b sand) under `p`: the terrain is a
## square grid of vertices, read once per mesh and kept.
static func _splat_at(mi: MeshInstance3D, p: Vector3) -> Color:
	var key := mi.mesh.get_instance_id()
	if not _grids.has(key):
		if _grids.size() > 16:
			_grids.clear()
		var arr := mi.mesh.surface_get_arrays(0)
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var side := int(round(sqrt(float(verts.size()))))
		_grids[key] = [arr[Mesh.ARRAY_COLOR], side, verts[0].x, verts[0].z, verts[1].x - verts[0].x]
	var g: Array = _grids[key]
	var cols: PackedColorArray = g[0]
	var side: int = g[1]
	var local := mi.global_transform.affine_inverse() * p
	var fx := clampf((local.x - float(g[2])) / float(g[4]), 0.0, side - 1.001)
	var fz := clampf((local.z - float(g[3])) / float(g[4]), 0.0, side - 1.001)
	var ix := int(fx)
	var iz := int(fz)
	var tx := fx - ix
	var tz := fz - iz
	var i := iz * side + ix
	var top := cols[i].lerp(cols[i + 1], tx)
	var bottom := cols[i + side].lerp(cols[i + side + 1], tx)
	return top.lerp(bottom, tz)


## What a collider is made of, by the textures on its meshes (its own, or
## its parent's when it has none): mostly planks = wood, stone = stone.
static func _judge(col: Node) -> String:
	if col.is_in_group("ship") or col.is_in_group("enemy_ships"):
		return "wood"
	var meshes := col.find_children("*", "MeshInstance3D", true, false)
	if meshes.is_empty() and col.get_parent():
		meshes = col.get_parent().get_children().filter(func(c): return c is MeshInstance3D)
	var score := {"wood": 0, "stone": 0, "sand": 0, "grass": 0}
	for mi in meshes.slice(0, 24):
		var mesh := (mi as MeshInstance3D).mesh
		if mesh == null:
			continue
		for s in range(mesh.get_surface_count()):
			var kind := _kind_of_texture(_texture_name((mi as MeshInstance3D).get_active_material(s)))
			if kind != "":
				score[kind] += 1
	var best := "wood"
	for k in score:
		if score[k] > score[best]:
			best = k
	return best


static func _texture_name(m: Material) -> String:
	var tex: Texture2D = null
	if m is ShaderMaterial:
		tex = (m as ShaderMaterial).get_shader_parameter("albedo_tex") as Texture2D
	elif m is BaseMaterial3D:
		tex = (m as BaseMaterial3D).albedo_texture
	return tex.resource_path.get_file() if tex else ""


static func _kind_of_texture(file: String) -> String:
	if file == "":
		return ""
	for w in WOOD_TEX:
		if w in file:
			return "wood"
	for w in STONE_TEX:
		if w in file:
			return "stone"
	for w in SAND_TEX:
		if w in file:
			return "sand"
	for w in GRASS_TEX:
		if w in file:
			return "grass"
	return ""
