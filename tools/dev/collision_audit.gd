extends SceneTree
## (1.30) The collision audit: builds islands (every theme on two seeds, Brinehollow, the capital, the canal city, the
## stronghold) and lists every solid-looking surface a captain could touch with no collider on it. Every lit, opaque
## surface of a mesh or MultiMesh instance bigger than MIN_SIZE on two axes is sampled every ~SPACING m; a sample in
## reach (0.3-4 m over the floor below it, or an up-facing roof to 12 m) with no collider within PROBE m (the terrain
## left out) is open. Open samples of one instance that join into a patch MIN_SIZE across on two axes are a hole.
## Holes are grouped by kind: the builder that made the mesh (MeshBuilder.trace's "made_by": file.function < caller),
## else the node path without numbers. Passable things (foliage cards, water, decals, cloth, flags, rope) are skipped
## by material and by ALLOW below.
## Out: tools/dev/out/collision/<tag>/<island>.txt (kinds by score: area x how near the paths), summary.txt, one
## "CA <island> holes <n> area <m2> shapes <n>" line per island. Env: CA_TAG=before (the folder under out/collision), CA_ONLY=snow,capital (labels or prefixes),
## CA_SEEDS=4242,77. Opens a window (headless keeps no MultiMesh transforms), ~15 min for all:
## & $env:GODOT --path . --script res://tools/dev/collision_audit.gd
const TK := preload("res://tools/dev/test_kit.gd")
const SEEDS := [4242, 77]
const SPACING := 0.6
const MIN_SIZE := 0.6
const PROBE := 0.3
const BAND := 4.0
const ROOF := 12.0
const NEAR_PATH := 12.0
## Deeper than a wader reaches (m under the sea) is passable: coral and rock a swimmer meets (Zach, 1.30).
const WADE := 1.2
const MASK := 2049
var OUT := "res://tools/dev/out/collision/" + (OS.get_environment("CA_TAG") if OS.get_environment("CA_TAG") != "" else "now")
## Node-name or kind fragments that are meant to be passable, and why.
const ALLOW := {
	"Flag": "cloth", "Banner": "cloth", "Pennant": "cloth", "Bunting": "cloth", "Laundry": "cloth", "Washing": "cloth",
	"Awning": "cloth overhead", "Rope": "rope", "Rigging": "rope", "Smoke": "fx", "Fire": "fx", "Flame": "fx",
	"Ocean": "water", "Water": "water", "Pool": "water", "Foam": "water", "Wake": "water", "Cloud": "sky", "Sky": "sky",
	"Paving": "lies on the ground", "Path": "lies on the ground", "Decal": "decal", "Cobwebs": "cloth",
}
## Textures that are never solid (foliage the cutout shader doesn't already cover, water, cloth).
const PASS_TEX := ["leaves", "pine_snow", "fir_needles", "palm_frond", "fern", "bush", "grass_tuft", "thornbrush", "moss", "water", "fabric"]
## Textures passable only on the plants (snow banked round a tree's foot; a snow-capped roof still counts).
const PASS_PLANT_TEX := ["snow", "volcanic_ash"]

var stage
var w
var step := 0
var until := 0
var queue: Array = []
var cur: Dictionary = {}
var isl
var summary := PackedStringArray()
var by_file := {}
var by_kind := {}
var _samples := {}
var _q: PhysicsShapeQueryParameters3D


func _initialize() -> void:
	# (headless, the dummy renderer keeps no MultiMesh transforms: every tree, rock and coral would read as at the origin)
	if DisplayServer.get_name() == "headless":
		printerr("collision_audit needs a window (MultiMesh instances only read back from a real renderer): run it without --headless")
		quit(1)
		return
	TK.seed_of(self)
	load("res://scripts/psx/mesh_builder.gd").trace = true
	stage = TK.stage(self, {"hud": false})
	var only := OS.get_environment("CA_ONLY").split(",", false)
	var seeds: Array = SEEDS
	if OS.get_environment("CA_SEEDS") != "":
		seeds = Array(OS.get_environment("CA_SEEDS").split(",", false)).map(func(s): return int(s))
	var all: Array = [{"label": "brinehollow", "kind": "brinehollow"}, {"label": "capital", "kind": "capital"},
		{"label": "canal", "kind": "canal"}, {"label": "stronghold", "kind": "stronghold"}]
	for th in load("res://scripts/island/themes/island_themes.gd").all():
		for s in seeds:
			all.append({"label": "%s_%d" % [th.name, s], "kind": "theme", "theme": th.name, "seed": s})
	for e in all:
		if only.is_empty() or Array(only).any(func(o): return str(e["label"]).begins_with(o)):
			queue.append(e)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			w = load("res://tools/dev/t/capital/_world.gd").take_over(stage, 4242)
			load("res://scripts/world/actor_sleep.gd").enabled = false
			var sph := SphereShape3D.new()
			sph.radius = PROBE
			_q = PhysicsShapeQueryParameters3D.new()
			_q.shape = sph
			_q.collision_mask = MASK
			_q.collide_with_areas = false
			step = 1
		1:
			if queue.is_empty():
				for t in [["By builder file", by_file], ["By builder", by_kind]]:
					var d: Dictionary = t[1]
					var keys: Array = d.keys()
					keys.sort_custom(func(a, b): return float(d[a][1]) > float(d[b][1]))
					summary.append("")
					summary.append("%s (all islands): holes, m2, where" % t[0])
					for fl in keys:
						summary.append("%6d %9.0f  %s  %s" % [d[fl][0], d[fl][1], fl, " ".join((d[fl][2] as Dictionary).keys())])
				var f := FileAccess.open(OUT + "/summary.txt", FileAccess.WRITE)
				f.store_string("\n".join(summary) + "\n")
				print("CA done: %s" % ProjectSettings.globalize_path(OUT))
				quit(0)
				return true
			cur = queue.pop_front()
			isl = _build(cur)
			until = TK.wait_ticks(4)
			step = 2
		2:
			for spot in OS.get_environment("CA_PROBE").split(";", false):
				_probe(isl, str_to_var("Vector3(%s)" % spot))
			if OS.get_environment("CA_PROBE") != "":
				isl.queue_free()
				until = TK.wait_ticks(3)
				step = 1
				return false
			var t0 := Time.get_ticks_msec()
			var rep := audit(isl, str(cur["label"]))
			var f := FileAccess.open(OUT + "/%s.txt" % cur["label"], FileAccess.WRITE)
			f.store_string(rep["text"])
			var line := "CA %s holes %d area %.0f roofs %d shapes %d (%s) bodies %d  %.1f s" % [cur["label"], rep["holes"], rep["area"], rep["roofs"],
				rep["shapes"], rep["by_type"], rep["bodies"], (Time.get_ticks_msec() - t0) / 1000.0]
			print(line)
			summary.append(line)
			for k in rep["top"]:
				summary.append("    " + k)
			for k in rep["kinds"]:
				var file := str(k).get_slice(".", 0) if not str(k).contains("/") else "node " + str(k).get_slice("/", 0)
				for t in [[by_file, file], [by_kind, str(k)]]:
					var e: Array = (t[0] as Dictionary).get(t[1], [0, 0.0, {}])
					e[0] += int(rep["kinds"][k]["holes"])
					e[1] += float(rep["kinds"][k]["area"])
					e[2][str(cur["label"]).get_slice("_", 0)] = true
					t[0][t[1]] = e
			isl.queue_free()
			w.chain_islands.clear()
			_samples.clear()
			until = TK.wait_ticks(3)
			step = 1
	return false


## CA_PROBE="x,y,z;x,y,z" (island space): what a ray down from 3 m over the spot meets, and the colliders and meshes near it.
func _probe(root_isl: Node3D, at: Vector3) -> void:
	var space := root.world_3d.direct_space_state
	var wp := root_isl.to_global(at)
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(wp + Vector3.UP * 3.0, wp + Vector3.DOWN * 20.0, MASK))
	print("CA probe %s: ray down hits %s at %s; ground %.2f" % [at, str(root_isl.get_path_to(hit["collider"])) if not hit.is_empty() else "nothing",
		str(hit.get("position", "-")), float(root_isl.hv(Vector2(at.x, at.z)))])
	var sph := SphereShape3D.new()
	sph.radius = 1.5
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = sph
	q.collision_mask = MASK
	q.transform = Transform3D(Basis(), wp)
	for mmi in root_isl.find_children("*", "MultiMeshInstance3D", true, false):
		var mm: MultiMesh = (mmi as MultiMeshInstance3D).multimesh
		for i in range(mm.instance_count):
			var o: Vector3 = root_isl.to_local((mmi as Node3D).global_transform * mm.get_instance_transform(i).origin)
			if Vector2(o.x - at.x, o.z - at.z).length() < 3.0:
				print("   instance %d of %s (%s) at %s, basis scale %s" % [i, root_isl.get_path_to(mmi), mm.mesh.get_meta("made_by", "?"), o, mm.get_instance_transform(i).basis.get_scale()])
	for r in space.intersect_shape(q, 12):
		var cs: Node = (r["collider"] as CollisionObject3D).shape_owner_get_owner((r["collider"] as CollisionObject3D).shape_find_owner(int(r["shape"])))
		print("   within 1.5 m: %s (%s)" % [root_isl.get_path_to(r["collider"]), cs.shape.get_class() if cs is CollisionShape3D else "?"])


func _build(e: Dictionary) -> Node3D:
	var at := Vector3(0, 0, -3000)
	match str(e["kind"]):
		"brinehollow":
			var b = load("res://scripts/island/starter_island.gd").new()
			b.name = "Brinehollow"
			b.position = at
			stage.add_child(b)
			b.build(42)
			return b
		"capital":
			return w.build_capital(at)
		"canal":
			return w.build_canal(at)
		"stronghold":
			return w.build_stronghold(at)
	var th = load("res://scripts/island/themes/island_themes.gd").of(str(e["theme"]))
	var c = load("res://scripts/world/chain.gd").make(int(e["seed"]), Vector2.ZERO, Vector2(0, -1))
	w.c = c
	var n: Dictionary = c.node(int(c.start_next[0])).duplicate(true)
	n["theme"] = th.name
	n.merge({"beast": th.bosses[0], "beast_look": 0, "beast_name": th.beasts[th.bosses[0]]["names"][0], "minis": [th.minis[0]], "roamer": th.roamers[0]}, true)
	var gi = load("res://scripts/island/gen_island.gd").new()
	gi.name = "Isle%d" % int(n["id"])
	gi.position = at
	stage.add_child(gi)
	w.chain_islands[int(n["id"])] = gi
	gi.build(n)
	return gi


## The holes on one built island, as {text, holes, area, roofs, shapes, by_type, bodies, top}.
func audit(root_isl: Node3D, label: String) -> Dictionary:
	var space := root.world_3d.direct_space_state
	var terrain: Array[RID] = []
	for ch in root_isl.get_children():
		if ch is StaticBody3D and (str(ch.name).begins_with("Ground") or str(ch.name) == "Terrain"):
			terrain.append((ch as StaticBody3D).get_rid())
	_q.exclude = terrain
	var kinds := {}
	var geo: Array = []
	_walk(root_isl, geo)
	var holes := 0
	var roofs := 0
	var area := 0.0
	for g in geo:
		var kind := _kind(g, root_isl)
		var path := str(root_isl.get_path_to(g))
		if _allowed(path) != "":
			continue
		var mesh: Mesh = g.mesh if g is MeshInstance3D else g.multimesh.mesh
		var pts: Array = _sampled(g, mesh, kind.contains("_plants."))
		if pts.is_empty():
			continue
		var xfs: Array = []
		if g is MeshInstance3D:
			xfs.append(g.global_transform)
		else:
			var mm: MultiMesh = g.multimesh
			for i in range(mm.visible_instance_count if mm.visible_instance_count >= 0 else mm.instance_count):
				xfs.append(g.global_transform * mm.get_instance_transform(i))
		var box := mesh.get_aabb()
		for xf in xfs:
			var wb: AABB = xf * box
			if [wb.size.x >= MIN_SIZE, wb.size.y >= MIN_SIZE, wb.size.z >= MIN_SIZE].count(true) < 2:
				continue
			var open: Array = []
			for s in pts:
				var wp: Vector3 = xf * (s[0] as Vector3)
				var wn: Vector3 = (xf.basis * (s[1] as Vector3)).normalized()
				var lp := root_isl.to_local(wp)
				var rel: float = lp.y - float(root_isl.hv(Vector2(lp.x, lp.z)))
				if rel < 0.3 or rel > ROOF + 4.0 or lp.y < -WADE:
					continue
				_q.transform = Transform3D(Basis(), wp + wn * 0.05)
				if not space.intersect_shape(_q, 1).is_empty():
					continue
				var down := PhysicsRayQueryParameters3D.create(wp + wn * 0.05, wp + Vector3.DOWN * (ROOF + 1.0), MASK)
				var hit := space.intersect_ray(down)
				var floor_rel: float = rel if hit.is_empty() else wp.y - float(hit["position"].y)
				if floor_rel < 0.3:
					continue
				var roof := floor_rel > BAND
				if roof and (wn.y < 0.5 or floor_rel > ROOF):
					continue
				open.append([wp, float(s[2]), roof])
			for cl in _clusters(open):
				var k: Dictionary = kinds.get(kind, {"holes": 0, "area": 0.0, "near": 0, "roofs": 0, "at": [], "node": path})
				var c: Vector3 = root_isl.to_local(cl["c"])
				k["holes"] += 1
				k["area"] += cl["area"]
				if cl["roof"]:
					k["roofs"] += 1
					roofs += 1
				if float(root_isl.path_dist(Vector2(c.x, c.z))) < NEAR_PATH:
					k["near"] += 1
				if (k["at"] as Array).size() < 6:
					var sz: Vector3 = cl["size"]
					(k["at"] as Array).append("(%.0f,%.0f,%.0f)%.1fx%.1fx%.1f%s" % [c.x, c.y, c.z, sz.x, sz.y, sz.z, "r" if cl["roof"] else ""])
				kinds[kind] = k
				holes += 1
				area += cl["area"]
	var order: Array = kinds.keys()
	var score := func(k): return float(kinds[k]["area"]) * (1.0 + 2.0 * float(kinds[k]["near"]) / float(kinds[k]["holes"]))
	order.sort_custom(func(a, b): return score.call(a) > score.call(b))
	var shapes := _shapes(root_isl)
	var lines := PackedStringArray(["%s: %d holes, %.0f m2 open (%d roof tops); %d shapes %s in %d bodies" % [label, holes, area, roofs, shapes[0], shapes[1], shapes[2]], ""])
	var top := PackedStringArray()
	for k in order:
		var e: Dictionary = kinds[k]
		var l := "%5d holes %7.1f m2 near %4d roofs %4d  %s  [%s]  at %s" % [e["holes"], e["area"], e["near"], e["roofs"], k, e["node"], " ".join(e["at"])]
		lines.append(l)
		if top.size() < 8:
			top.append(l)
	return {"text": "\n".join(lines) + "\n", "holes": holes, "area": area, "roofs": roofs, "shapes": shapes[0], "by_type": shapes[1], "bodies": shapes[2], "top": top, "kinds": kinds}


func _walk(n: Node, out: Array) -> void:
	if n is CharacterBody3D or n is RigidBody3D or n is Area3D or n.is_in_group("npc") or n.is_in_group("enemies"):
		return
	# (a far stand-in, drawn only past its near twin's range, is never touched)
	if n is GeometryInstance3D and (n as GeometryInstance3D).visibility_range_begin > 0.0:
		return
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null and (n as Node3D).is_visible_in_tree():
		out.append(n)
	elif n is MultiMeshInstance3D and (n as MultiMeshInstance3D).multimesh != null and (n as MultiMeshInstance3D).multimesh.mesh != null and (n as Node3D).is_visible_in_tree():
		out.append(n)
	for ch in n.get_children():
		_walk(ch, out)


## What made it: the builder's functions, else the node's path under the island without numbers.
func _kind(g: GeometryInstance3D, root_isl: Node) -> String:
	var mesh: Mesh = g.mesh if g is MeshInstance3D else g.multimesh.mesh
	var path := str(root_isl.get_path_to(g))
	var parts := path.split("/")
	var short := "/".join(parts.slice(maxi(0, parts.size() - 3)))
	var re := RegEx.create_from_string("[0-9]+")
	short = re.sub(short, "", true)
	if mesh.has_meta("made_by"):
		return str(mesh.get_meta("made_by"))
	return "%s%s" % ["mm " if g is MultiMeshInstance3D else "", short]


func _allowed(path: String) -> String:
	for k in ALLOW:
		if path.contains(k):
			return ALLOW[k]
	return ""


func _solid(m: Material, plant: bool) -> bool:
	var sm := m as ShaderMaterial
	if sm == null or sm.shader != load("res://shaders/psx/psx_lit.gdshader"):
		return false
	if bool(sm.get_shader_parameter("decal_mode")):
		return false
	if sm.has_meta("psx"):
		var tex := str(sm.get_meta("psx")[0])
		if tex.begins_with("leaves") or tex in PASS_TEX or (plant and tex in PASS_PLANT_TEX):
			return false
	return true


## [local point, local normal, area] every ~SPACING m over the solid surfaces facing anywhere but down (cached per mesh).
func _sampled(g: GeometryInstance3D, mesh: Mesh, plant: bool) -> Array:
	var key := [mesh.get_rid(), g.material_override]
	if _samples.has(key):
		return _samples[key]
	var out: Array = []
	for si in range(mesh.get_surface_count()):
		var mat: Material = g.material_override
		if mat == null and g is MeshInstance3D:
			mat = (g as MeshInstance3D).get_surface_override_material(si)
		if mat == null:
			mat = mesh.surface_get_material(si)
		if not _solid(mat, plant) or (mesh is ArrayMesh and (mesh as ArrayMesh).surface_get_primitive_type(si) != Mesh.PRIMITIVE_TRIANGLES):
			continue
		var arr := mesh.surface_get_arrays(si)
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var nrm = arr[Mesh.ARRAY_NORMAL]
		var idx = arr[Mesh.ARRAY_INDEX]
		var count: int = (idx as PackedInt32Array).size() if idx != null else v.size()
		for t in range(0, count - 2, 3):
			var i0: int = idx[t] if idx != null else t
			var i1: int = idx[t + 1] if idx != null else t + 1
			var i2: int = idx[t + 2] if idx != null else t + 2
			var a := v[i0]
			var b := v[i1]
			var c := v[i2]
			var cr := (b - a).cross(c - a)
			var ar := cr.length() * 0.5
			if ar < 0.004:
				continue
			var n := cr.normalized()
			if nrm != null and (nrm as PackedVector3Array).size() > i2:
				var vn: Vector3 = nrm[i0] + nrm[i1] + nrm[i2]
				if vn.dot(n) < 0.0:
					n = -n
			if n.y < -0.3:
				continue
			var k := clampi(ceili(maxf(a.distance_to(b), maxf(b.distance_to(c), c.distance_to(a))) / SPACING), 1, 24)
			var share := ar / float(k * k)
			for i in range(k):
				for j in range(k - i):
					out.append([a + (b - a) * ((i + 1.0 / 3.0) / k) + (c - a) * ((j + 1.0 / 3.0) / k), n, share])
					if i + j < k - 1:
						out.append([a + (b - a) * ((i + 2.0 / 3.0) / k) + (c - a) * ((j + 2.0 / 3.0) / k), n, share])
	_samples[key] = out
	return out


## Open samples joined on a 1 m grid; the patches MIN_SIZE across on two axes, as {c, area, roof}.
func _clusters(open: Array) -> Array:
	if open.is_empty():
		return []
	var cells := {}
	for o in open:
		var c := Vector3i((o[0] as Vector3).floor())
		if not cells.has(c):
			cells[c] = []
		(cells[c] as Array).append(o)
	var seen := {}
	var out: Array = []
	for start in cells:
		if seen.has(start):
			continue
		var stack: Array = [start]
		seen[start] = true
		var box := AABB((cells[start][0][0] as Vector3), Vector3.ZERO)
		var ar := 0.0
		var roof := 0
		var n := 0
		var members: Array = []
		while not stack.is_empty():
			var c: Vector3i = stack.pop_back()
			for o in cells[c]:
				box = box.expand(o[0])
				ar += float(o[1])
				roof += 1 if o[2] else 0
				n += 1
				members.append(o[0])
			for dx in range(-1, 2):
				for dy in range(-1, 2):
					for dz in range(-1, 2):
						var q := c + Vector3i(dx, dy, dz)
						if cells.has(q) and not seen.has(q):
							seen[q] = true
							stack.append(q)
		if [box.size.x >= MIN_SIZE, box.size.y >= MIN_SIZE, box.size.z >= MIN_SIZE].count(true) >= 2:
			# (the open spot nearest the patch's middle: a ring's middle is in the air)
			var mid := box.get_center()
			var at: Vector3 = members[0]
			for m in members:
				if (m as Vector3).distance_to(mid) < at.distance_to(mid):
					at = m
			out.append({"c": at, "size": box.size, "area": ar, "roof": roof * 2 > n})
	return out


## [shape count, by type, body count] under the island.
func _shapes(n: Node) -> Array:
	var by := {}
	var total := 0
	var bodies := 0
	var stack: Array = [n]
	while not stack.is_empty():
		var x: Node = stack.pop_back()
		if x is CollisionShape3D and (x as CollisionShape3D).shape != null:
			var t: String = (x as CollisionShape3D).shape.get_class().replace("Shape3D", "")
			by[t] = int(by.get(t, 0)) + 1
			total += 1
		elif x is StaticBody3D:
			bodies += 1
		stack.append_array(x.get_children())
	return [total, by, bodies]
