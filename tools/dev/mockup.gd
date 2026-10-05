extends SceneTree
## Style mockup: same cast in a given style. Args: <style> <mode: full|heads|back> <out.png>
var f := 0
var models: Array = []
var style := "shonen"
var mode := "full"
var out := ""
static func cast() -> Array:
	var a := CharacterLook.default_look()
	a["coat"] = "captain"; a["hair"] = "short"; a["eyes"] = 4; a["brows"] = 3; a["mouth"] = 2
	var b := CharacterLook.base_look()
	b.merge({"body": "fem", "skin": CharacterLook.SKIN_TONES[1], "hair": "long", "hair_color": CharacterLook.HAIR_COLORS[1],
		"eyes": 0, "eye_color": CharacterLook.EYE_COLORS[3], "brows": 2, "mouth": 1, "top": "blouse", "top_color": CharacterLook.CLOTH[0],
		"vest": "corset", "vest_color": CharacterLook.CLOTH[14], "legs": "skirt", "legs_color": CharacterLook.CLOTH[8],
		"feet": "tall_boots", "feet_color": CharacterLook.LEATHER[0], "belt": "sash", "sash_color": CharacterLook.CLOTH[13], "earring": true}, true)
	var c := CharacterLook.base_look()
	c.merge({"build": "stout", "skin": CharacterLook.SKIN_TONES[3], "hair": "bald", "facial_hair": "beard", "hair_color": CharacterLook.HAIR_COLORS[2],
		"eyes": 3, "mouth": 1, "brows": 1, "nose": "broad", "top": "shirt", "sleeves": "short", "apron": true, "legs": "trousers",
		"legs_color": CharacterLook.CLOTH[4], "feet": "boots"}, true)
	var d := CharacterLook.base_look()
	d.merge({"body": "fem", "skin": CharacterLook.SKIN_TONES[5], "hair": "ponytail", "hair_color": CharacterLook.HAIR_COLORS[0],
		"eyes": 4, "eye_color": CharacterLook.EYE_COLORS[5], "brows": 3, "mouth": 4, "top": "shirt", "top_color": CharacterLook.CLOTH[7],
		"coat": "longcoat", "coat_color": CharacterLook.CLOTH[13], "legs": "trousers", "legs_color": CharacterLook.CLOTH[5],
		"feet": "tall_boots", "belt": "belt", "hat": "none", "marks": "scar"}, true)
	var e := CharacterLook.base_look()
	e.merge({"skin": CharacterLook.SKIN_TONES[2], "hair": "wild", "hair_color": CharacterLook.HAIR_COLORS[9], "eyes": 2, "mouth": 2,
		"brows": 0, "top": "bare", "vest": "vest", "vest_color": CharacterLook.CLOTH[11], "legs": "breeches", "legs_color": CharacterLook.CLOTH[2],
		"feet": "barefoot", "belt": "sash", "sash_color": CharacterLook.CLOTH[15], "hat": "bandana", "hat_color": CharacterLook.CLOTH[8]}, true)
	return [a, b, c, d, e]
func _initialize():
	var args := OS.get_cmdline_user_args()
	style = args[0]; mode = args[1]; out = args[2]
	var env := WorldEnvironment.new(); var e := Environment.new()
	e.background_mode = Environment.BG_COLOR; e.background_color = Color(0.42, 0.58, 0.74)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; e.ambient_light_color = Color(0.62, 0.62, 0.68); e.ambient_light_energy = 0.8
	env.environment = e; root.add_child(env)
	var sun := DirectionalLight3D.new(); sun.rotation = Vector3(deg_to_rad(-42), deg_to_rad(-25), 0); sun.shadow_enabled = true; root.add_child(sun)
	var ground := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = Vector2(40, 20); ground.mesh = pm; root.add_child(ground)
	var looks := cast()
	for i in range(looks.size()):
		looks[i]["style"] = style
		var h := Humanoid.new(); h.setup(looks[i]); root.add_child(h)
		h.position = Vector3((i - 2) * 1.05, 0, 0)
		h.rotation.y = deg_to_rad(160 if mode != "back" else -20)
		models.append(h)
	var cam := Camera3D.new(); root.add_child(cam); cam.current = true
	if mode == "heads":
		cam.fov = 24
		var hy: float = {"shonen": 1.8, "chibi": 1.12, "heroic": 1.84}[style]
		cam.look_at_from_position(Vector3(0, hy, 6.4), Vector3(0, hy - 0.03, 0))
	else:
		cam.fov = 38
		cam.look_at_from_position(Vector3(0, 1.4, 7.0), Vector3(0, 0.95, 0))
func _process(_d):
	f += 1
	if f == 2:
		root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
		for h in models:
			for k in range(90): h._process(1.0 / 60.0)
			h.set_process(false)
		if mode == "heads":
			var hy2: float = (models[1] as Humanoid).head.global_position.y + 0.17 * (models[1] as Humanoid).head.global_basis.get_scale().y
			var cam2 := root.get_viewport().get_camera_3d()
			cam2.look_at_from_position(Vector3(0, hy2 + 0.02, 6.4), Vector3(0, hy2, 0))
	if f == 6:
		root.get_texture().get_image().save_png(out); print("SAVED ", out); quit()
	return false
