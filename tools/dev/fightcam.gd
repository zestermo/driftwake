extends SceneTree
## The combat camera (1.31) before / after: the same fight (grunts flanking the captain), the "Combat camera" setting
## off then on, from the game's own camera; <out>/fightcam_off.png, fightcam_on.png and fightcam.png side by side.
## Run: & $env:GODOT --path . --resolution 1920x1080 --script res://tools/dev/fightcam.gd -- res://tools/dev/out/fightcam
const TK := preload("res://tools/dev/test_kit.gd")
var out := ""
var stage
var t := 0.0
var started := false
var imgs := []


func _initialize() -> void:
	out = OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "weather": true, "weapon": "cutlass", "grunts": [
		{"post": Vector3(-4.0, 0, -3.0), "role": "sword", "seed": 11},
		{"post": Vector3(-5.0, 0, 1.5), "role": "sword", "seed": 23},
		{"post": Vector3(3.5, 0, -4.5), "role": "sword", "seed": 37},
		{"post": Vector3(-2.0, 0, -6.5), "role": "sword", "seed": 41}]})


func _process(d: float) -> bool:
	t += d
	for c in root.find_children("*", "CharacterCreator", true, false):
		c._finish(true)
	if not stage.up or started:
		return false
	started = true
	_run()
	return false


func _wait(s: float) -> void:
	var until := t + s
	while t < until:
		await process_frame


func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	var st = root.get_node("Settings")
	st.set_value("video", "pixelate", true, false)
	root.get_node("Weather").force(0)
	root.get_node("Weather").skip_to(15.0)
	var p = stage.player
	for g in stage.camp.grunts:
		TK.calm(g, (p.global_position - g.global_position).normalized())
	stage.camera_rig.rotation.y = 0.0
	for on in [false, true]:
		st.set_value("gameplay", "combat_camera", on, false)
		await _wait(2.5)
		for l in stage.find_children("*", "Label3D", true, false):
			(l as Label3D).visible = false
		await process_frame
		var img := root.get_texture().get_image()
		img.save_png("%s/fightcam_%s.png" % [out, "on" if on else "off"])
		imgs.append(img)
	var w: int = imgs[0].get_width() / 2
	var h: int = imgs[0].get_height() / 2
	var sheet := Image.create(w * 2 + 6, h, false, Image.FORMAT_RGB8)
	for i in range(2):
		var s: Image = imgs[i].duplicate()
		s.convert(Image.FORMAT_RGB8)
		s.resize(w, h, Image.INTERPOLATE_BILINEAR)
		sheet.blit_rect(s, Rect2i(0, 0, w, h), Vector2i(i * (w + 6), 0))
	sheet.save_png("%s/fightcam.png" % out)
	print("SAVED")
	quit()
