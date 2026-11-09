extends SceneTree
## Mock (staged, not gameplay) for melee targeting without the crosshair (Zach, 2026-11-09): row 1 the omni
## attack: now (the crosshair, the swing along the camera) then a swing at the grunt you push toward (left, right,
## behind) with the target chevron over it; row 2 the lock-on: the camera behind you on the line to the locked
## grunt, strafing round it, then switched to another. Poses and cameras are placed by hand.
## Run: & $env:GODOT --path . --resolution 1920x1080 --script res://tools/dev/aimmock.gd -- res://tools/dev/out/aim
const TK := preload("res://tools/dev/test_kit.gd")
const COLS := 4

var out := ""
var stage
var p
var cam: Camera3D
var t := 0.0
var frames := {}
var started := false
var chevron: MeshInstance3D
var cross := false


func _initialize() -> void:
	out = OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "weather": true, "weapon": "cutlass", "grunts": [
		{"post": Vector3(-3.2, 0, -0.6), "role": "sword", "seed": 11},
		{"post": Vector3(3.2, 0, -0.6), "role": "sword", "seed": 23},
		{"post": Vector3(-1.2, 0, 3.0), "role": "sword", "seed": 37},
		{"post": Vector3(0.3, 0, -7.5), "role": "sword", "seed": 41}]})


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


func _shot(row: int, i: int) -> void:
	for l in stage.find_children("*", "Label3D", true, false):
		(l as Label3D).visible = false
	await process_frame
	await process_frame
	var img := root.get_texture().get_image()
	if cross:
		var cx := img.get_width() / 2
		var cy := img.get_height() / 2
		img.fill_rect(Rect2i(cx - 14, cy - 2, 28, 4), Color(1, 1, 1))
		img.fill_rect(Rect2i(cx - 2, cy - 14, 4, 28), Color(1, 1, 1))
	img.save_png("%s/row%d_%d.png" % [out, row, i])
	frames["%d_%d" % [row, i]] = img
	print("shot ", row, " ", i)


## A pixel chevron over a grunt's head: the soft target (small, amber) or the lock (big, red).
func _mark(g: Node3D, locked: bool) -> void:
	if g == null:
		chevron.visible = false
		return
	chevron.visible = true
	var s := 0.32 if locked else 0.22
	chevron.scale = Vector3(s, s, s)
	(chevron.material_override as StandardMaterial3D).albedo_color = Color(1.0, 0.18, 0.12) if locked else Color(1.0, 0.72, 0.2)
	chevron.global_position = g.global_position + Vector3(0, 2.35, 0)


func _face(at: Vector3) -> void:
	var d: Vector3 = at - p.global_position
	p.player_model.rotation.y = atan2(-d.x, -d.z)


func _swing(g: Node3D, anim: String) -> void:
	_face(g.global_position)
	_mark(g, false)
	p.body_model.play(anim, ActionSpecs.length(anim))
	await _wait(ActionSpecs.length(anim) * 0.42)


func _lock_cam(g: Node3D) -> void:
	var back: Vector3 = p.global_position - g.global_position
	back.y = 0.0
	back = back.normalized()
	var right := Vector3.UP.cross(back).normalized() * -1.0
	cam.current = true
	cam.global_position = p.global_position + back * 3.4 + right * 0.6 + Vector3(0, 1.75, 0)
	cam.look_at((p.global_position + g.global_position) * 0.5 + Vector3(0, 1.1, 0), Vector3.UP)


func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	var st = root.get_node("Settings")
	st.set_value("video", "pixelate", true, false)
	root.get_node("Weather").force(0)
	root.get_node("Weather").skip_to(15.0)
	p = stage.player
	p.health_component.max_health = 99999.0
	p.health_component.current_health = 99999.0
	var gs: Array = stage.camp.grunts
	for g in gs:
		TK.calm(g, (p.global_position - g.global_position).normalized())
	cam = Camera3D.new()
	cam.fov = 60
	cam.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	root.add_child(cam)
	chevron = MeshInstance3D.new()
	var am := ArrayMesh.new()
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3(-0.5, 0.5, 0), Vector3(0.5, 0.5, 0), Vector3(0, -0.4, 0)])
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	chevron.mesh = am
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.no_depth_test = true
	chevron.material_override = m
	chevron.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(chevron)
	chevron.visible = false
	await _wait(1.0)

	# row 1: now (crosshair, swing along the camera), then omni swings at the grunt pushed toward
	stage.camera_rig.rotation.y = 0.0
	cam.current = true
	cam.global_position = p.global_position + Vector3(3.8, 5.2, 6.4)
	cam.look_at(p.global_position + Vector3(0, 0.6, -0.8), Vector3.UP)
	cross = true
	p.player_model.rotation.y = 0.0
	p.body_model.play("slash_r", ActionSpecs.length("slash_r"))
	await _wait(ActionSpecs.length("slash_r") * 0.42)
	await _shot(1, 0)
	cross = false
	await _wait(0.5)
	await _swing(gs[0], "slash_r")
	await _shot(1, 1)
	await _wait(0.4)
	await _swing(gs[1], "slash_l")
	await _shot(1, 2)
	await _wait(0.4)
	await _swing(gs[2], "slash_spin")
	await _shot(1, 3)
	await _wait(0.6)

	# row 2: locked on the far grunt, strafing round it, then switched to the right-hand one
	gs[0].global_position = Vector3(-9.0, gs[0].global_position.y, -6.0)
	gs[2].global_position = Vector3(-10.0, gs[2].global_position.y, 4.0)
	gs[1].global_position = Vector3(5.5, gs[1].global_position.y, -9.0)
	for g in gs:
		g.reset_physics_interpolation()
	var tgt: Node3D = gs[3]
	var c := tgt.global_position
	var r: float = p.global_position.distance_to(c)
	var a0: float = atan2(p.global_position.x - c.x, p.global_position.z - c.z)
	for i in range(3):
		var a := a0 + 0.4 * i
		p.global_position = Vector3(c.x + sin(a) * r * 0.8, p.global_position.y, c.z + cos(a) * r * 0.8)
		p.reset_physics_interpolation()
		_face(c)
		_mark(tgt, true)
		_lock_cam(tgt)
		if i == 2:
			p.body_model.play("slash_l", ActionSpecs.length("slash_l"))
			await _wait(ActionSpecs.length("slash_l") * 0.42)
		else:
			await _wait(0.3)
		await _shot(2, i)
	tgt = gs[1]
	_face(tgt.global_position)
	_mark(tgt, true)
	_lock_cam(tgt)
	await _wait(0.3)
	await _shot(2, 3)

	_sheet()
	print("SAVED")
	quit()


func _sheet() -> void:
	var any: Image = frames.values()[0]
	var fw: int = any.get_width() / 3
	var fh: int = any.get_height() / 3
	var sheet := Image.create((fw + 4) * COLS, (fh + 4) * 2, false, Image.FORMAT_RGB8)
	sheet.fill(Color(0.08, 0.08, 0.08))
	for r in range(2):
		for c in range(COLS):
			var f: Image = frames.get("%d_%d" % [r + 1, c])
			if f == null:
				continue
			var s := f.duplicate()
			s.convert(Image.FORMAT_RGB8)
			s.resize(fw, fh, Image.INTERPOLATE_BILINEAR)
			sheet.blit_rect(s, Rect2i(0, 0, fw, fh), Vector2i(c * (fw + 4), r * (fh + 4)))
	sheet.save_png("%s/aim_sheet.png" % out)
