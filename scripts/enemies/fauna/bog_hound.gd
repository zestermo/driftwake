extends Wolf
## Bog hounds (the fog isles, 1.30): drowned dogs the black water gave back, running in packs on the wolves' brain -
## the lead's gargled bark, circling at a lunge's length, one lunge at a time. Bloated and hunched, slick grey-green
## hide gone to rot along the ribs, pond weed hanging off them in strings, eyes two cold points. They drip as they run;
## a landed bite gushes bog water.

const HIDE := Color(0.26, 0.31, 0.27)
const WEED := Color(0.2, 0.3, 0.14)
const EYES := Color(0.6, 1.0, 0.75)


func _setup(args: Dictionary) -> void:
	super._setup(args)
	kind = "bog_hound"
	morph = 2
	skin_tex = "fur_white"
	size_k = 1.45 if lead else 1.15
	max_hp = 140.0 if lead else 70.0
	drops = [["bear_hide", 0.35, 1], ["fish", 0.25, 1]]


func _build() -> void:
	super._build()
	var skin := _skin()
	var eye := _glow(EYES)
	# the rot over the ribs, weed off the back and jaw in strings, and its own eyes over the wolf's
	_part(_body, "Rot", Vector3.ZERO, "bog_rot", func(mb: MeshBuilder, rng: RandomNumberGenerator):
		for s in [-1.0, 1.0]:
			mb.add_blob(skin, Transform3D(Basis.IDENTITY, Vector3(s * 0.19, -0.02, -0.12)), Vector3(0.05, 0.13, 0.2), rng, 0.2, 3, 5, 1.0, HIDE.darkened(0.35))
			for k in range(4):
				mb.add_box(skin, Transform3D(Basis(Vector3.BACK, s * 0.3), Vector3(s * 0.22, 0.06 - k * 0.06, -0.12)), Vector3(0.02, 0.025, 0.24), 1.0, Color(0.62, 0.62, 0.52), false, false)
		# a hump of a back, bloated
		mb.add_blob(skin, Transform3D(Basis.IDENTITY, Vector3(0, 0.17, -0.18)), Vector3(0.17, 0.12, 0.26), rng, 0.2, 3, 6, 1.0, HIDE)
		for k in range(10):
			var z := rng.randf_range(-0.45, 0.45)
			var x := rng.randf_range(-0.14, 0.14)
			var l := rng.randf_range(0.18, 0.4)
			mb.add_box(skin, Transform3D(Basis(Vector3.BACK, x * 2.0), Vector3(x * 1.4, 0.16 - l * 0.5, z)), Vector3(0.025, l, 0.02), 1.0, WEED.darkened(rng.randf() * 0.3), false, false))
	_part(_head, "Bog", Vector3.ZERO, "bog_head", func(mb: MeshBuilder, rng: RandomNumberGenerator):
		for s in [-1.0, 1.0]:
			mb.add_box(eye, Transform3D(Basis.IDENTITY, Vector3(s * 0.066, 0.052, -0.135)), Vector3(0.034, 0.024, 0.02), 1.0, Color.WHITE, false, false)
		for k in range(4):
			mb.add_box(skin, Transform3D(Basis.IDENTITY, Vector3(-0.05 + k * 0.033, -0.13 - rng.randf() * 0.05, -0.2 + rng.randf_range(-0.05, 0.05))), Vector3(0.015, rng.randf_range(0.12, 0.2), 0.015), 1.0, WEED, false, false))
	_recolour()


## The wolf's own parts take the bog's grey-green (their meshes are built from the wolf's dark coat, once per kind).
func _recolour() -> void:
	var skin := _skin()
	for mi in _parts:
		var key := str(mi.get_parent().name)
		if key in ["Rot", "Bog"]:
			continue
		var m := mi.mesh as ArrayMesh
		var k := "bog_hound:tint:" + key + ("_lead" if lead else "")
		if not _meshes.has(k):
			var am := ArrayMesh.new()
			for i in range(m.get_surface_count()):
				var arr := m.surface_get_arrays(i)
				var c: PackedColorArray = arr[Mesh.ARRAY_COLOR]
				if m.surface_get_material(i) == skin:
					for j in range(c.size()):
						c[j] = Color(c[j].r * 0.6 + HIDE.r * 0.6, c[j].g * 0.6 + HIDE.g * 0.75, c[j].b * 0.6 + HIDE.b * 0.6)
					arr[Mesh.ARRAY_COLOR] = c
				am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
				am.surface_set_material(i, m.surface_get_material(i))
			_meshes[k] = am
		mi.mesh = _meshes[k]


func _brain(delta: float) -> void:
	if state == S.NOTICE and lead and st_t < delta * 1.5:
		Net.fx("sfx", ["bog_bark", global_position, 0.0, 0.08, 0.9])
	elif state == S.TELL and st_t < delta * 1.5:
		Net.fx("sfx", ["bog_bark", global_position, -4.0, 0.1, 1.15])
	super._brain(delta)


func _landed(target: Node, data: HitData) -> void:
	super._landed(target, data)
	FX.splash((target as Node3D).global_position + Vector3.UP * 0.9, 5, 0.5)


func _cry_death() -> void:
	Net.fx("sfx", ["bog_bark", global_position, -2.0, 0.05, 0.7])
	Net.fx("splash", [global_position + Vector3.UP * 0.5, 6, 0.6])


func _pose(delta: float) -> void:
	super._pose(delta)
	# hunched lower than a wolf, its head carried low; drips as it runs
	_body.position.y -= 0.06
	_head.rotation.x -= 0.2
	if lod == LOD_FULL and flat(velocity).length() > 3.0 and fmod(_t, 0.4) < delta:
		FX.splash(global_position + Vector3.UP * 0.4, 1, 0.25)
