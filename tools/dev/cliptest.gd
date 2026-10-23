extends SceneTree
## Clothing layers don't poke through each other: for fixed combos (every vest under every coat,
## belts and tops under them, baldric and bandolier over both, the cloak over both, every hat over long and wild hair,
## every legwear in every footwear),
## each vertex of the inner layer is cast out level from the body's axis at its height (in the
## head's own space for hats, where hair below the lowest brim is free to hang out) and must not end
## up past the outer layer's surface by more than TOL. Bodies are built at rest.
## Layers are found by material: the colours below are unique per slot, and the extra materials a
## slot brings (steel, studs, trim) are learnt by building it alone on a bare body.
## Prints the worst offender per pair; CLIP_ALL=1 lists every combo. Also hair under hats (the retired hairtest).
const TOL := 0.004
const C := {"top_color": Color(0.9, 0.88, 0.8), "vest_color": Color(0.18, 0.34, 0.2), "coat_color": Color(0.2, 0.32, 0.62),
	"trim_color": Color(0.75, 0.76, 0.78), "belt_color": Color(0.62, 0.44, 0.26), "sash_color": Color(0.8, 0.62, 0.2),
	"legs_color": Color(0.36, 0.2, 0.44), "feet_color": Color(0.1, 0.08, 0.07), "hat_color": Color(0.66, 0.14, 0.12),
	"hair_color": Color(0.7, 0.34, 0.14), "mantle_color": Color(0.55, 0.55, 0.55), "cloak_color": Color(0.42, 0.42, 0.2)}
const BARE := {"hat": "none", "vest": "none", "coat": "none", "belt": "none", "top": "bare", "feet": "barefoot", "hair": "bald", "legs": "skirt"}
## The part of the body each layer pair is checked on: the meshes it reads and how rays are cast.
const TORSO := ["Torso", "Hips"]
var fails := 0
var f := 0
var _learnt := {}
var _all := OS.get_environment("CLIP_ALL") != ""


func check(name: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + name)
	if not cond:
		fails += 1


func _initialize() -> void:
	load("res://tools/dev/test_kit.gd").seed_of(self)


func _process(_d: float) -> bool:
	f += 1
	if f < 2:
		return false
	_hair_checks()
	var torso := []
	var belts := ["belt", "sash", "wide_belt", "belt_sash"]
	var i := 0
	for vest in CharacterLook.VESTS:
		for coat in CharacterLook.COATS:
			if vest == "none" and coat == "none":
				continue
			# (two belts each, taking turns, so every belt meets every vest and coat)
			for k in range(2):
				torso.append({"vest": vest, "coat": coat, "belt": belts[(i + k * 2) % 4], "top": "shirt"})
			i += 1
	for top in ["tunic", "doublet", "kimono", "blouse", "striped"]:
		for coat in ["haori", "frock", "jacket"]:
			torso.append({"vest": "jerkin", "coat": coat, "belt": "wide_belt", "top": top})
	# straps over whatever's under them (no belt: it shares the straps' leather; not the greatcoat,
	# whose shoulder cape is meant to hang over them)
	var straps := []
	for coat in CharacterLook.COATS:
		if coat == "greatcoat":
			continue
		for vest in ["none", "scale", "cuirass", "harness"]:
			straps.append({"coat": coat, "vest": vest, "belt": "none", "top": "shirt", "baldric": true})
			straps.append({"coat": coat, "vest": vest, "belt": "none", "top": "shirt", "bandolier": true})
	# the cloak's yoke and collar over coats and vests (not the greatcoat, whose own shoulder cape it sits beside)
	var cloaks := []
	for coat in CharacterLook.COATS:
		if coat == "greatcoat":
			continue
		for vest in ["none", "scale", "cuirass", "padded"]:
			cloaks.append({"coat": coat, "vest": vest, "belt": "belt", "top": "shirt", "cloak": true})
	# (fem: the coat's shell sits further out over the bust)
	for vest in ["cuirass", "padded", "scale", "mail"]:
		torso.append({"body": "fem", "vest": vest, "coat": "longcoat", "belt": "belt_sash", "top": "blouse"})
	var heads := []
	for hat in CharacterLook.HATS:
		if hat == "none" or hat in CharacterLook.OVER_HAIR:
			continue
		for hair in ["long", "wild", "spiky", "bun"]:
			heads.append({"hat": hat, "hair": hair})
	var legs := []
	for lg in CharacterLook.LEGS:
		for ft in CharacterLook.FEET:
			if ft not in ["barefoot", "sandals"] and lg != "skirt":
				legs.append({"legs": lg, "feet": ft})
	_run("vests, tops and belts under coats", torso, [["top", "vest"], ["top", "coat"], ["vest", "coat"], ["belt", "coat"], ["vest", "belt"]], "axis", TORSO)
	_run("baldric and bandolier over coats and vests", straps, [["coat", "baldric"], ["vest", "baldric"], ["coat", "bandolier"], ["vest", "bandolier"]], "axis", TORSO)
	_run("coats and vests under the cloak", cloaks, [["coat", "cloak"], ["vest", "cloak"], ["top", "cloak"]], "axis", TORSO)
	_run("hair under hats", heads, [["hair", "hat"]], "head", ["Head"])
	_run("legs in footwear", legs, [["legs", "feet"]], "legs", ["Hips", "ShinL", "ShinR"])
	print("RESULT fails=", fails)
	quit()
	return false


## Hair-material vertices of the head (head-local, unscaled), the strands included
## (HairFlow's locks are untextured: all of a lock style's chain mesh counts).
func _hair_verts(h, style: String) -> PackedVector3Array:
	var out := PackedVector3Array()
	var locks := HairFlow.has(style)
	for mi in h.head.find_children("*", "MeshInstance3D", true, false):
		var m: Mesh = (mi as MeshInstance3D).mesh
		if m == null:
			continue
		var on_chains: bool = (mi as Node).get_parent() is Skeleton3D and (mi as Node).get_parent().get_parent() is SpringChains
		for s in range(m.get_surface_count()):
			var mat := m.surface_get_material(s) as ShaderMaterial
			if mat == null:
				continue
			var tex = mat.get_shader_parameter("albedo_tex")
			var textured_hair: bool = tex != null and str((tex as Texture2D).resource_path).contains("hair")
			if not textured_hair and not (locks and on_chains):
				continue
			var v: PackedVector3Array = m.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]
			var xf: Transform3D = h.head.global_transform.affine_inverse() * (mi as Node3D).global_transform
			for p in v:
				out.append(xf * p)
	return out



## Every hair style builds for both bodies, and under every hat no hair reaches out past the scalp
## (from the retired hairtest).
func _hair_checks() -> void:
	var built := 0
	var styles: Array = CharacterLook.HAIR
	for body in ["masc", "fem"]:
		for hs in styles:
			var lk := CharacterLook.base_look()
			lk["body"] = body
			lk["hair"] = hs
			var h := Humanoid.new()
			h.setup(lk)
			root.add_child(h)
			if hs == "bald" or _hair_verts(h, hs).size() > 0:
				built += 1
			h.free()
	check("every hair style builds for both bodies (%d / %d)" % [built, styles.size() * 2], built == styles.size() * 2)
	# under a hat, hair above the brim hugs the scalp: within the round head's
	# top ring (its real profile, 0.162 x 0.158 m) plus a few millimetres, and
	# no higher than the crown
	var bb := BodyBuilder.new()
	var ring := [0.268, 0.162, 0.158, 0.004, 0.0, BodyBuilder.P_HEAD()]
	var worst := ""
	var worst_r := 0.0
	for hat in CharacterLook.HATS:
		if hat == "none" or hat in CharacterLook.OVER_HAIR:
			continue
		for hs in styles:
			var lk := CharacterLook.base_look()
			lk["hair"] = hs
			lk["hat"] = hat
			var h := Humanoid.new()
			h.setup(lk)
			root.add_child(h)
			for p in _hair_verts(h, hs):
				if p.y < 0.285:
					continue
				var d := Vector2(p.x, p.z - 0.004)
				var lim: float = bb._surf_r(ring, atan2(d.x, -d.y)) + 0.008
				var r := maxf(d.length() / lim, (p.y - 0.392) / 0.01 + 1.0 if p.y > 0.392 else 0.0)
				if r > worst_r:
					worst_r = r
					worst = "%s + %s at (%.3f, %.3f, %.3f)" % [hat, hs, p.x, p.y, p.z]
			h.free()
	check("no hair pokes out under any hat (worst %.2f of the limit: %s)" % [worst_r, worst], worst_r <= 1.0)


func _run(what: String, combos: Array, pairs: Array, mode: String, parts: Array) -> void:
	var worst := {}
	for combo in combos:
		var lk := _look(combo)
		var h := Humanoid.new()
		h.setup(lk)
		root.add_child(h)
		var layers := _layers(h, lk, parts, h.head if mode == "head" else h)
		for pr in pairs:
			if not layers.has(pr[0]) or not layers.has(pr[1]):
				continue
			var res := _poke(layers[pr[0]], layers[pr[1]], layers["all"][0], mode)
			var key := "%s in %s" % pr
			if _all and res[0] > TOL:
				print("   %s  %s: %.1f mm at %s" % [key, _name(combo), res[0] * 1000.0, res[1]])
			if res[0] > float(worst.get(key, [-1.0])[0]):
				worst[key] = [res[0], res[1], _name(combo)]
		h.free()
	for key in worst.keys():
		var w: Array = worst[key]
		check("%s: %s within %.0f mm (worst %.1f mm, %s, at %s)" % [what, key, TOL * 1000.0, w[0] * 1000.0, w[2], w[1]], float(w[0]) <= TOL)


func _name(combo: Dictionary) -> String:
	var bits := []
	for k in combo.keys():
		bits.append(str(combo[k]))
	return "+".join(bits)


func _look(combo: Dictionary) -> Dictionary:
	var lk := CharacterLook.base_look()
	lk.merge(C, true)
	lk.merge(BARE, true)
	lk["legs"] = "trousers"
	lk.merge(combo, true)
	return lk


## The materials a slot brings with it: built on a bare body with only that slot set.
func _slot_mats(slot: String, value: Variant) -> Dictionary:
	var key := slot + "=" + str(value)
	if not _learnt.has(key):
		var base := _mats_of(_bare({}))
		var mine := _mats_of(_bare({slot: value}))
		var out := {}
		for m in mine.keys():
			if not base.has(m):
				out[m] = true
		_learnt[key] = out
	return _learnt[key]


func _bare(extra: Dictionary) -> Dictionary:
	var lk := CharacterLook.base_look()
	lk.merge(C, true)
	lk.merge(BARE, true)
	lk.merge(extra, true)
	return lk


func _mats_of(lk: Dictionary) -> Dictionary:
	var h := Humanoid.new()
	h.setup(lk)
	var out := {}
	for mi in h.find_children("*", "MeshInstance3D", true, false):
		var m: Mesh = (mi as MeshInstance3D).mesh
		if m == null:
			continue
		for s in range(m.get_surface_count()):
			out[m.surface_get_material(s)] = true
	h.free()
	return out


## Each layer's triangles (in `space`) on the given parts: {layer: [PackedVector3Array verts, Array tris]},
## and "all": every vertex there.
func _layers(h, lk: Dictionary, parts: Array, space: Node3D) -> Dictionary:
	var by_mat := {}
	var owners := {}
	for slot in ["vest", "coat", "belt", "feet", "hat", "top", "hair", "legs", "baldric", "bandolier", "cloak"]:
		var v = lk.get(slot, "")
		if v is bool and not v or str(v) == "" or str(v) == str(BARE.get(slot, "")):
			continue
		for m in _slot_mats(slot, v).keys():
			owners[m] = owners.get(m, []) + [slot]
	for m in owners.keys():
		if (owners[m] as Array).size() == 1:
			by_mat[m] = owners[m][0]
	var out := {"all": [PackedVector3Array(), []]}
	for mi in h.find_children("*", "MeshInstance3D", true, false):
		if not _on_parts(mi, parts, h):
			continue
		var m: Mesh = (mi as MeshInstance3D).mesh
		if m == null:
			continue
		var xf: Transform3D = space.global_transform.affine_inverse() * (mi as Node3D).global_transform
		for s in range(m.get_surface_count()):
			var arr := m.surface_get_arrays(s)
			var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			# (every surface on the part: the body's axis is found from them all)
			var every: PackedVector3Array = out["all"][0]
			for p in vs:
				every.append(xf * p)
			out["all"][0] = every
			var mat := m.surface_get_material(s)
			var slot = by_mat.get(mat)
			# (hair is whatever wears the hair texture: strands and tufts come in several shades)
			var tex = (mat as ShaderMaterial).get_shader_parameter("albedo_tex") if mat is ShaderMaterial else null
			if tex != null and str((tex as Texture2D).resource_path).contains("hair"):
				slot = "hair"
			elif slot == "hair":
				slot = null
			if slot == null:
				continue
			var ix = arr[Mesh.ARRAY_INDEX]
			if not out.has(slot):
				out[slot] = [PackedVector3Array(), []]
			# (packed arrays are values: append to a local and store it back)
			var verts: PackedVector3Array = out[slot][0]
			var base := verts.size()
			for p in vs:
				verts.append(xf * p)
			out[slot][0] = verts
			var tris: Array = out[slot][1]
			if ix == null or (ix as PackedInt32Array).is_empty():
				for i in range(0, vs.size() - 2, 3):
					tris.append([base + i, base + i + 1, base + i + 2])
			else:
				for i in range(0, (ix as PackedInt32Array).size() - 2, 3):
					tris.append([base + ix[i], base + ix[i + 1], base + ix[i + 2]])
	return out


## A mesh belongs to a part when the nearest joint above it is that part (arms on the torso don't
## count as the torso). Skinned cloth hangs off SpringChains / LowerBody under the joint.
func _on_parts(n: Node, parts: Array, h) -> bool:
	var p := n.get_parent()
	while p != null and p != h:
		if p is SpringChains or p is LowerBody or p.name == "Mesh":
			p = p.get_parent()
			continue
		return str(p.name) in parts
	return false


## The worst distance (m) an inner vertex sits past the outer layer along a ray from the axis, and where.
func _poke(inner: Array, outer: Array, every: PackedVector3Array, mode: String) -> Array:
	var ov: PackedVector3Array = outer[0]
	var tris: Array = outer[1]
	# triangles bucketed by height
	var slab := 0.02
	var buckets := {}
	for t in tris:
		var lo := INF
		var hi := -INF
		for i in t:
			lo = minf(lo, ov[i].y)
			hi = maxf(hi, ov[i].y)
		for b in range(floori(lo / slab), floori(hi / slab) + 1):
			if not buckets.has(b):
				buckets[b] = []
			buckets[b].append(t)
	# every vertex on the part in 1 cm slabs (per side for the legs): the body's axis at a height
	var cells := {}
	for p in every:
		var key := Vector2i(floori(p.y / 0.01), 0 if mode != "legs" else (1 if p.x > 0.0 else -1))
		var c: Array = cells.get(key, [Vector3.ZERO, 0])
		cells[key] = [c[0] + p, c[1] + 1]
	var worst := [0.0, ""]
	var iv: PackedVector3Array = inner[0]
	for v in iv:
		# (head mode is in the head's own space: hair below the lowest brim hangs out from under it)
		if mode == "head" and v.y < 0.24:
			continue
		var sum := Vector3.ZERO
		var n := 0
		var side := 0 if mode != "legs" else (1 if v.x > 0.0 else -1)
		for b in range(floori(v.y / 0.01) - 3, floori(v.y / 0.01) + 4):
			var c: Array = cells.get(Vector2i(b, side), [Vector3.ZERO, 0])
			sum += c[0]
			n += c[1]
		if n == 0:
			continue
		var o := Vector3(sum.x / n, v.y, sum.z / n)
		var dir := Vector3(v.x - o.x, 0, v.z - o.z)
		var dist := dir.length()
		if dist < 0.03:
			continue
		dir /= dist
		var reach := -1.0
		for t in buckets.get(floori(v.y / slab), []):
			var hit = Geometry3D.ray_intersects_triangle(o, dir, ov[t[0]], ov[t[1]], ov[t[2]])
			if hit != null:
				reach = maxf(reach, ((hit as Vector3) - o).length())
		if reach < 0.0:
			continue
		if dist - reach > worst[0]:
			worst = [dist - reach, "(%.2f, %.2f, %.2f) r %.3f, reach %.3f" % [v.x, v.y, v.z, dist, reach]]
	return worst
