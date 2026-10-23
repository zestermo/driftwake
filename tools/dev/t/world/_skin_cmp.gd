extends RefCounted
## Comparing what two bodies draw, vertex for vertex (t/world/one_skin_*): every visible mesh CPU-skinned into
## world space, by material.
const EPS := 0.0002


## Look i of a range: random looks with the bodies, builds, heights, hats, coats, vests, legs, feet, tops and
## sleeves cycled through.
static func look_of(i: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7000 + i
	var lk: Dictionary = CharacterLook.random_look(rng)
	lk["body"] = CharacterLook.BODIES[i % 2]
	lk["build"] = CharacterLook.BUILDS[i % CharacterLook.BUILDS.size()]
	lk["height"] = CharacterLook.HEIGHTS[i % CharacterLook.HEIGHTS.size()]
	lk["hat"] = CharacterLook.HATS[i % CharacterLook.HATS.size()]
	lk["coat"] = CharacterLook.COATS[(i * 5) % CharacterLook.COATS.size()]
	lk["vest"] = CharacterLook.VESTS[(i * 3) % CharacterLook.VESTS.size()]
	lk["legs"] = CharacterLook.LEGS[i % CharacterLook.LEGS.size()]
	lk["feet"] = CharacterLook.FEET[(i * 3) % CharacterLook.FEET.size()]
	lk["top"] = CharacterLook.TOPS[(i * 2) % CharacterLook.TOPS.size()]
	lk["sleeves"] = CharacterLook.SLEEVES[i % CharacterLook.SLEEVES.size()]
	return lk


## A rig built with or without BodyBuilder.one_skin (a background rig unless `player`), not posing by itself.
static func rig(tree: SceneTree, lk: Dictionary, one: bool, player := false) -> Humanoid:
	BodyBuilder.one_skin = one
	var h := Humanoid.new()
	h.lod = true
	h.swappable_hands = player
	h.setup(lk)
	h.process_mode = Node.PROCESS_MODE_DISABLED
	tree.root.add_child(h)
	BodyBuilder.one_skin = false
	return h


## The same pose on any rig: every joint turned by the same seeded amounts, the skeletons posed from them.
static func pose(h: Humanoid, seed_i: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 90 + seed_i
	for j in [h.hips, h.torso, h.neck, h.head, h.leg_l, h.leg_r, h.shin_l, h.shin_r, h.arm_l, h.arm_r, h.fore_l, h.fore_r,
			h.hand_l, h.hand_r]:
		(j as Node3D).rotation = Vector3(rng.randf_range(-0.9, 0.9), rng.randf_range(-0.6, 0.6), rng.randf_range(-0.6, 0.6))
	# (where the animator leaves them: a built rig has the hips at the pivot, the pivot at hip height)
	h.hips.position = Vector3.ZERO
	h.pivot.position = Vector3(0.1, h.hip_y - 0.2, 0.05)
	skin_now(h)


static func skin_now(n: Node) -> void:
	for sk in n.find_children("*", "Skeleton3D", true, false):
		if sk.has_method("_pose"):
			sk._pose()


## Every visible vertex under `n` in world space, by material (all one key if `any_mat`; hair and cloth springs left
## out if `no_springs`): [pos, normal, uv, colour].
static func verts(n: Node, any_mat := false, no_springs := false) -> Dictionary:
	var out := {}
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		if not (mi as MeshInstance3D).is_visible_in_tree() or (mi as MeshInstance3D).mesh == null:
			continue
		if no_springs and ((mi as Node).get_parent() is SpringChains or (mi as Node).get_parent().get_parent() is SpringChains):
			continue
		var m: Mesh = (mi as MeshInstance3D).mesh
		var xf: Transform3D = (mi as MeshInstance3D).global_transform
		if (mi as MeshInstance3D).skin and m is ArrayMesh:
			var sk := (mi as MeshInstance3D).get_node((mi as MeshInstance3D).skeleton) as Skeleton3D
			m = ArmBody.bake(sk, mi)
			xf = sk.global_transform
		for s in range(m.get_surface_count()):
			var arr := m.surface_get_arrays(s)
			var mat: Material = (mi as MeshInstance3D).get_active_material(s)
			var key := 0 if any_mat or mat == null else mat.get_instance_id()
			if not out.has(key):
				out[key] = []
			var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var nr = arr[Mesh.ARRAY_NORMAL]
			var uv = arr[Mesh.ARRAY_TEX_UV]
			var c = arr[Mesh.ARRAY_COLOR]
			for i in range(v.size()):
				out[key].append([xf * v[i], (xf.basis * (nr[i] as Vector3)).normalized() if nr != null else Vector3.ZERO,
					uv[i] if uv != null else Vector2.ZERO, c[i] if c != null and not any_mat else Color.WHITE])
	return out


static func _cell(p: Vector3) -> Vector3i:
	return Vector3i(floori(p.x / 0.001), floori(p.y / 0.001), floori(p.z / 0.001))


## [misses, compared, first miss]: b's vertices with no twin in a (same material, within EPS, same normal, uv and
## colour), plus a's left over.
static func misses(a: Dictionary, b: Dictionary) -> Array:
	var miss := 0
	var total := 0
	var worst := ""
	for key in b:
		var grid := {}
		for e in a.get(key, []):
			var cc := _cell(e[0])
			if not grid.has(cc):
				grid[cc] = []
			grid[cc].append(e)
		for e in b[key]:
			total += 1
			var found := false
			var cc := _cell(e[0])
			for dx in [-1, 0, 1]:
				for dy in [-1, 0, 1]:
					for dz in [-1, 0, 1]:
						if found:
							break
						var lst = grid.get(cc + Vector3i(dx, dy, dz))
						if lst == null:
							continue
						for k in range((lst as Array).size()):
							var o: Array = lst[k]
							if (o[0] as Vector3).distance_to(e[0]) < EPS and (o[1] as Vector3).dot(e[1]) > 0.999 \
									and (o[2] as Vector2).distance_to(e[2]) < 0.0005 and (o[3] as Color).is_equal_approx(e[3]):
								found = true
								(lst as Array).remove_at(k)
								break
			if not found:
				miss += 1
				if worst == "":
					worst = "%s at %s" % [str(instance_from_id(key)) if key else "-", str(e[0])]
		for lst in grid.values():
			miss += (lst as Array).size()
	for key in a:
		if not b.has(key):
			miss += (a[key] as Array).size()
			if worst == "":
				worst = "material %s only in the old" % str(instance_from_id(key))
	return [miss, total, worst]


static func draws(h: Node) -> int:
	var d := 0
	for mi in h.find_children("*", "MeshInstance3D", true, false):
		if (mi as MeshInstance3D).is_visible_in_tree() and (mi as MeshInstance3D).mesh:
			d += (mi as MeshInstance3D).mesh.get_surface_count()
	return d
