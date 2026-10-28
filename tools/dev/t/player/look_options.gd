extends SceneTree
## The 1.25 look options (head shapes, eye types): each round-trips through the saved look, builds a body whose head or
## painted face differs from the plain one, and turns up in the random looks at a sensible rate; a look saved before
## them loads unchanged.
const TK := preload("res://tools/dev/test_kit.gd")
const NEW := [["head", "heart"], ["head", "broad"], ["eyes", 6], ["eyes", 7]]
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
			_builds()
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
	check("random looks are the same from the same seed", same)
	check("new eyes in %d of %d random looks (15-45%%)" % [eyes, n], eyes > n * 0.15 and eyes < n * 0.45)
	check("new faces in %d of %d random looks (25-55%%)" % [heads, n], heads > n * 0.25 and heads < n * 0.55)
