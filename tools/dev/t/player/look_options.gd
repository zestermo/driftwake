extends SceneTree
## The 1.25 look options (head shapes, eye types, hair styles, dye colours, finishes): each round-trips through the
## saved look and builds (the heads, eyes and finishes visibly differ from the plain ones; the styles on both bodies,
## bare and under a hat), and they turn up in the random looks at sensible rates; a look saved before them loads
## unchanged.
const TK := preload("res://tools/dev/test_kit.gd")
const NEW := [["head", "heart"], ["head", "broad"], ["eyes", 6], ["eyes", 7], ["hair", "dreads"], ["hair", "mohawk"],
	["hair_finish", "two_tone"], ["hair_finish", "tipped"]]
const RED := 10
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


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			CharacterLook.save_path = "user://t_look_options.cfg"
			for o in NEW:
				_round_trip(o[0], o[1])
			for i in range(CharacterLook.NATURAL_HAIR, CharacterLook.HAIR_COLORS.size()):
				_round_trip("hair_color", CharacterLook.HAIR_COLORS[i])
				_round_trip("hair_color2", CharacterLook.HAIR_COLORS[i])
			_builds()
			_hair_builds()
			_finishes()
			_old_look()
			_random_rates()
			return TK.done(fails)
	step += 1
	return false


func _round_trip(key: String, v: Variant) -> void:
	var lk := CharacterLook.default_look()
	lk[key] = v
	CharacterLook.save_look(lk)
	var back := CharacterLook.load_look()
	check("%s %s survives the save" % [key, v], back.get(key) == v)


## How wide the painted face is below the mouth (the chin and jaw), m.
func _jaw_w(lk: Dictionary) -> float:
	var h := Humanoid.new()
	h.setup(lk)
	root.add_child(h)
	var lo := INF
	var hi := -INF
	for mi in h.head.find_children("*", "MeshInstance3D", true, false):
		var m: Mesh = (mi as MeshInstance3D).mesh
		if m == null:
			continue
		for s in range(m.get_surface_count()):
			if (m.surface_get_material(s) as ShaderMaterial).get_shader_parameter("decal_mode"):
				for p in m.surface_get_arrays(s)[Mesh.ARRAY_VERTEX] as PackedVector3Array:
					if p.y < 0.06:
						lo = minf(lo, p.x)
						hi = maxf(hi, p.x)
	h.free()
	return hi - lo


func _builds() -> void:
	var plain := CharacterLook.default_look()
	plain["hat"] = "none"
	var chin := _jaw_w(plain)
	var heart := plain.duplicate()
	heart["head"] = "heart"
	var broad := plain.duplicate()
	broad["head"] = "broad"
	var w_heart := _jaw_w(heart)
	var w_broad := _jaw_w(broad)
	check("the heart face's chin is narrower (%.3f < %.3f m)" % [w_heart, chin], w_heart > 0.02 and w_heart < chin - 0.01)
	check("the broad face's jaw is wider (%.3f > %.3f m)" % [w_broad, chin], w_broad > chin + 0.01)
	for body in ["masc", "fem"]:
		var base := plain.duplicate()
		base["body"] = body
		var img0 := _face(base)
		for e in [6, 7]:
			var lk := base.duplicate()
			lk["eyes"] = e
			var diff := _diff(img0, _face(lk))
			check("%s eyes %d paint their own eyes (%d px differ)" % [body, e, diff], diff >= 12)


## The head's hair vertices (the hair texture's surfaces, chains included) in head space, with their colours.
func _hair(lk: Dictionary) -> Array:
	var h := Humanoid.new()
	h.setup(lk)
	root.add_child(h)
	var pts := PackedVector3Array()
	var cols := PackedColorArray()
	for mi in h.head.find_children("*", "MeshInstance3D", true, false):
		var m: Mesh = (mi as MeshInstance3D).mesh
		if m == null:
			continue
		var xf: Transform3D = h.head.global_transform.affine_inverse() * (mi as Node3D).global_transform
		for s in range(m.get_surface_count()):
			var tex = (m.surface_get_material(s) as ShaderMaterial).get_shader_parameter("albedo_tex")
			if tex == null or not str((tex as Texture2D).resource_path).contains("hair"):
				continue
			var arr := m.surface_get_arrays(s)
			for p in arr[Mesh.ARRAY_VERTEX] as PackedVector3Array:
				pts.append(xf * p)
			cols.append_array(arr[Mesh.ARRAY_COLOR] as PackedColorArray)
	var chains := 0
	for sc in h.head.find_children("*", "SpringChains", true, false):
		chains += sc.chain_count()
	h.free()
	return [pts, cols, chains]


func _hair_builds() -> void:
	for st in ["dreads", "mohawk"]:
		for body in ["masc", "fem"]:
			for hat in ["none", "tricorn", "bandana"]:
				var lk := CharacterLook.base_look()
				lk.merge({"hair": st, "body": body, "hat": hat}, true)
				var got := _hair(lk)
				check("%s on %s under %s builds hair (%d verts)" % [st, body, hat, (got[0] as PackedVector3Array).size()], (got[0] as PackedVector3Array).size() > 200)
				if st == "dreads":
					check("dreads on %s under %s hang on chains (%d)" % [body, hat, got[2]], int(got[2]) >= 10)
	var bare := CharacterLook.base_look()
	bare.merge({"hair": "mohawk"}, true)
	var top := -INF
	for p in _hair(bare)[0] as PackedVector3Array:
		top = maxf(top, p.y)
	check("the mohawk's crest stands %.2f m over the crown (> 0.08)" % (top - 0.388), top - 0.388 > 0.08)


## How many hair vertices take the red second colour, and how many of those are on the character's left (x < 0).
func _reds(lk: Dictionary) -> Vector2i:
	var got := _hair(lk)
	var pts: PackedVector3Array = got[0]
	var cols: PackedColorArray = got[1]
	var n := 0
	var left := 0
	for i in range(mini(pts.size(), cols.size())):
		var c := cols[i]
		if c.r > c.g + 0.25 and c.r > c.b + 0.25:
			n += 1
			if pts[i].x < -0.01:
				left += 1
	return Vector2i(n, left)


func _finishes() -> void:
	for st in ["short", "long", "dreads", "mohawk"]:
		var lk := CharacterLook.base_look()
		lk.merge({"hair": st, "hair_color": CharacterLook.HAIR_COLORS[0], "hair_color2": CharacterLook.HAIR_COLORS[RED]}, true)
		var plain := _reds(lk)
		lk["hair_finish"] = "two_tone"
		var two := _reds(lk)
		lk["hair_finish"] = "tipped"
		var tip := _reds(lk)
		var all := _hair(lk)[0] as PackedVector3Array
		check("%s plain has no second colour (%d)" % [st, plain.x], plain.x == 0)
		check("%s two-tone: %d verts in the second colour, %d on the left half" % [st, two.x, two.y], two.x > 30 and two.y < two.x * 0.15)
		check("%s tipped: %d of %d verts in the second colour (a few, not most)" % [st, tip.x, all.size()], tip.x > 6 and tip.x < all.size() * 0.5)


func _face(lk: Dictionary) -> Image:
	var fp := FacePainter.new()
	fp.paint(lk, 1.0)
	return fp.img


func _diff(a: Image, b: Image) -> int:
	var n := 0
	for y in range(a.get_height()):
		for x in range(a.get_width()):
			if not a.get_pixel(x, y).is_equal_approx(b.get_pixel(x, y)):
				n += 1
	return n


func _old_look() -> void:
	var old := {"name": "Old", "body": "fem", "head": "long", "eyes": 3, "hair": "bun", "hair_color": CharacterLook.HAIR_COLORS[4]}
	var cf := ConfigFile.new()
	for k in old:
		cf.set_value("look", k, old[k])
	cf.save(CharacterLook.save_path)
	var back := CharacterLook.load_look()
	var same := true
	for k in old:
		same = same and back[k] == old[k]
	check("a look saved before 1.25 loads unchanged", same)


func _random_rates() -> void:
	var n := 600
	var eyes := 0
	var heads := 0
	var dyes := 0
	var finishes := 0
	var styles := 0
	var rng := RandomNumberGenerator.new()
	var same := true
	for i in range(n):
		rng.seed = 1000 + i
		var lk := CharacterLook.random_look(rng)
		var s1 := rng.state
		rng.seed = 1000 + i
		var lk2 := CharacterLook.random_look(rng)
		same = same and str(lk) == str(lk2) and s1 == rng.state
		if int(lk["eyes"]) >= 6:
			eyes += 1
		if lk["head"] in ["heart", "broad"]:
			heads += 1
		if CharacterLook.HAIR_COLORS.find(lk["hair_color"]) >= CharacterLook.NATURAL_HAIR:
			dyes += 1
		if lk["hair_finish"] != "plain":
			finishes += 1
		if lk["hair"] in ["dreads", "mohawk"]:
			styles += 1
	check("random looks are the same from the same seed", same)
	check("new eyes in %d of %d random looks (15-45%%)" % [eyes, n], eyes > n * 0.15 and eyes < n * 0.45)
	check("new faces in %d of %d random looks (25-55%%)" % [heads, n], heads > n * 0.25 and heads < n * 0.55)
	check("dyed hair in %d of %d random looks (3-15%%)" % [dyes, n], dyes > n * 0.03 and dyes < n * 0.15)
	check("a hair finish in %d of %d random looks (4-18%%)" % [finishes, n], finishes > n * 0.04 and finishes < n * 0.18)
	check("the new styles in %d of %d random looks (4-20%%)" % [styles, n], styles > n * 0.04 and styles < n * 0.2)
