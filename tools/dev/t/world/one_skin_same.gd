extends SceneTree
## BodyBuilder.one_skin (one skeleton per body) changes nothing you can see: the same looks built both ways and
## posed the same (random joint turns, head scale, a ragdoll-style knock), CPU-skinned into world space, give the
## same vertices per material (position, normal, uv, colour); every rigid part rides the one skeleton (the joints
## carry no meshes); fewer draws; the player's rig (swappable hands) keeps the old path.
const TK := preload("res://tools/dev/test_kit.gd")
const LOOKS := 28
const EPS := 0.0002
var fails := 0
var step := 0


func _initialize() -> void:
	TK.seed_of(self)


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func look_of(i: int) -> Dictionary:
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


func rig(lk: Dictionary, one: bool, player := false) -> Humanoid:
	BodyBuilder.one_skin = one
	var h := Humanoid.new()
	h.lod = true
	h.swappable_hands = player
	h.setup(lk)
	h.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(h)
	BodyBuilder.one_skin = false
	return h


## The same pose on both rigs: every joint turned by the same seeded amounts.
func pose(h: Humanoid, seed_i: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 90 + seed_i
	for j in [h.hips, h.torso, h.neck, h.head, h.leg_l, h.leg_r, h.shin_l, h.shin_r, h.arm_l, h.arm_r, h.fore_l, h.fore_r,
			h.hand_l, h.hand_r]:
		(j as Node3D).rotation = Vector3(rng.randf_range(-0.9, 0.9), rng.randf_range(-0.6, 0.6), rng.randf_range(-0.6, 0.6))
	h.pivot.position += Vector3(0.1, -0.2, 0.05)
	for sk in h.find_children("*", "Skeleton3D", true, false):
		if sk.has_method("_pose"):
			sk._pose()


## Every visible vertex in world space, by material: [pos, normal, uv, colour].
func verts(h: Humanoid) -> Dictionary:
	var out := {}
	for mi in h.find_children("*", "MeshInstance3D", true, false):
		if not (mi as MeshInstance3D).is_visible_in_tree() or (mi as MeshInstance3D).mesh == null:
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
			var key := mat.get_instance_id() if mat else 0
			if not out.has(key):
				out[key] = []
			var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var n = arr[Mesh.ARRAY_NORMAL]
			var uv = arr[Mesh.ARRAY_TEX_UV]
			var c = arr[Mesh.ARRAY_COLOR]
			for i in range(v.size()):
				out[key].append([xf * v[i], (xf.basis * (n[i] as Vector3)).normalized() if n != null else Vector3.ZERO,
					uv[i] if uv != null else Vector2.ZERO, c[i] if c != null else Color.WHITE])
	return out


func cell(p: Vector3) -> Vector3i:
	return Vector3i(floori(p.x / 0.001), floori(p.y / 0.001), floori(p.z / 0.001))


## How many of b's vertices have no twin in a (same material, within EPS, same normal, uv and colour).
func misses(a: Dictionary, b: Dictionary) -> Array:
	var miss := 0
	var total := 0
	var worst := ""
	for key in b:
		var grid := {}
		for e in a.get(key, []):
			var cc := cell(e[0])
			if not grid.has(cc):
				grid[cc] = []
			grid[cc].append(e)
		for e in b[key]:
			total += 1
			var found := false
			var cc := cell(e[0])
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
					worst = "%s at %s" % [str(instance_from_id(key)) if key else "none", str(e[0])]
	for key in a:
		if not b.has(key):
			miss += (a[key] as Array).size()
			worst = "material %s only in the old" % str(instance_from_id(key))
	return [miss, total, worst]


func draws(h: Humanoid) -> int:
	var d := 0
	for mi in h.find_children("*", "MeshInstance3D", true, false):
		if (mi as MeshInstance3D).is_visible_in_tree() and (mi as MeshInstance3D).mesh:
			d += (mi as MeshInstance3D).mesh.get_surface_count()
	return d


## Meshes left on joints (not on the skeleton, a spring chain or a weapon socket's weapon).
func stray(h: Humanoid) -> Array:
	var out := []
	for mi in h.find_children("*", "MeshInstance3D", true, false):
		var p := (mi as Node).get_parent()
		if p is LowerBody or p is SpringChains or mi == h.weapon or mi == h.offhand:
			continue
		var skip := false
		var q := p
		while q and q != h:
			if q is SpringChains:
				skip = true
			q = q.get_parent()
		if not skip:
			out.append("%s/%s" % [p.name, mi.name])
	return out


func _process(_d: float) -> bool:
	match step:
		0:
			var bad := 0
			var worst := ""
			var od := 0
			var nd := 0
			var strays := []
			var nverts := 0
			for i in range(LOOKS):
				var lk := look_of(i)
				var a := rig(lk, false)
				var b := rig(lk, true)
				pose(a, i)
				pose(b, i)
				var r := misses(verts(a), verts(b))
				nverts += int(r[1])
				if int(r[0]) > 0:
					bad += 1
					if worst == "":
						worst = "look %d (%s %s hat %s coat %s): %d of %d vertices, first %s" % [i, lk["body"], lk["build"], lk["hat"], lk["coat"], r[0], r[1], r[2]]
				od += draws(a)
				nd += draws(b)
				for s in stray(b):
					if not s in strays:
						strays.append(s)
				if i == 0:
					check("no ArmBody: the arms are on the one skeleton", b.torso.get_node_or_null("ArmBody") == null and b.hips.get_node("LowerBody").has_arms())
				a.free()
				b.free()
			check("%d looks posed alike: the same vertices both ways (%d compared)%s" % [LOOKS, nverts, "" if bad == 0 else ": " + worst], bad == 0)
			check("every rigid part rides the one skeleton (left on joints: %s)" % str(strays), strays.is_empty())
			check("fewer draws (mean %.1f -> %.1f)" % [od / float(LOOKS), nd / float(LOOKS)], nd < od)
			var p := rig(look_of(3), true, true)
			check("the player's rig (swappable hands) keeps the old path", p.torso.get_node_or_null("ArmBody") != null)
			p.free()
			return TK.done(fails)
	step += 1
	return false
