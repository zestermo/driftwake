extends SceneTree
## 1.31 game feel, filmed on the light stage (docs/v1_31_feel_plan.md): a row of frames per feature and
## <out>/feel_sheet.png. Rows: assist (a light attack turning onto a dummy off to the side and stepping in, seen
## from the side), jolt (a shrugged-off blow from the front, side view), bank (sprinting round a curve, the
## camera behind), roll (a hard landing at a run, side view), screen (normal, low health, the knockout blink,
## launched), idle (the weight shift, front view), wind (a long coat calm, then in a storm wind).
## Run: & $env:GODOT --path . --resolution 1920x1080 --script res://tools/dev/feelshot.gd -- res://tools/dev/out/feel
const TK := preload("res://tools/dev/test_kit.gd")
const ROWS := ["assist", "jolt", "bank", "roll", "screen", "idle", "wind"]
const COLS := 5

var out := ""
var stage
var p
var cam: Camera3D
var t := 0.0
var _dt := 0.016
var frames := {}
var started := false


func _initialize() -> void:
	out = OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "weather": true, "dummy": Vector3(2.6, 0, -3.1), "weapon": "cutlass"})


func _process(d: float) -> bool:
	t += d
	_dt = d
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


func _shot(row: String, i: int) -> void:
	await process_frame
	var img := root.get_texture().get_image()
	img.save_png("%s/%s_%d.png" % [out, row, i])
	frames["%s_%d" % [row, i]] = img
	print("shot ", row, " ", i)


func _side(at: Vector3, side: Vector3, dist: float = 3.6, h: float = 1.1) -> void:
	cam.current = true
	cam.global_position = at + side.normalized() * dist + Vector3(0, h, 0)
	cam.look_at(at + Vector3(0, 0.95, 0), Vector3.UP)


func _rig_view() -> void:
	stage.camera_rig.camera.current = true


func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.get_node("Settings").set_value("video", "pixelate", true, false)
	p = stage.player
	cam = Camera3D.new()
	cam.fov = 50
	cam.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	p.health_component.max_health = 99999.0
	p.health_component.current_health = 99999.0
	root.get_node("Weather").force(0)
	root.get_node("Weather").skip_to(15.5)
	root.add_child(cam)
	await _wait(1.0)

	# assist: the dummy 40 degrees right of the camera's line; a light attack turns and steps onto it
	stage.camera_rig.rotation.y = 0.0
	_side(Vector3(1.0, p.global_position.y, -1.5), Vector3(-1, 0, 0.35), 6.0, 2.2)
	await _shot("assist", 0)
	TK.act("light_attack")
	for i in range(1, COLS):
		await _wait(0.09)
		await _shot("assist", i)
	await _wait(1.0)

	# jolt: a blow from the front that doesn't stagger
	p.global_position = Vector3(-6, p.global_position.y, 4)
	p.reset_physics_interpolation()
	p.player_model.rotation.y = 0.0
	await _wait(0.8)
	_side(p.global_position, Vector3(1, 0, 0), 3.0, 0.4)
	await _shot("jolt", 0)
	p.body_model.jolt(Vector3(0, 0, 1), 1.4)
	for i in range(1, COLS):
		await _wait(0.045)
		await _shot("jolt", i)

	# bank: sprinting round a curve, the camera sweeping left behind
	_rig_view()
	TK.press("move_forward")
	TK.press("sprint")
	await _wait(0.8)
	for i in range(COLS):
		var until := t + 0.25
		while t < until:
			stage.camera_rig.rotation.y += 2.4 * _dt
			var bk: Vector3 = p.player_model.global_basis.z
			cam.current = true
			cam.global_position = p.global_position + bk * 3.6 + Vector3(0, 1.6, 0)
			cam.look_at(p.global_position + Vector3(0, 1.0, 0), Vector3.UP)
			await process_frame
		await _shot("bank", i)

	# roll: a hard landing at a run (as running off a 6 m ledge lands: 15 m/s down, 9 m/s on)
	var fwd0: Vector3 = -p.player_model.global_basis.z
	var land_at: Vector3 = p.global_position
	p.velocity = fwd0 * 9.0
	p._on_landed(-15.0)
	print("  landed: action ", p.body_model.current_action())
	for i in range(COLS):
		_side(land_at + fwd0 * (0.6 * i), Vector3(fwd0.z, 0, -fwd0.x), 4.8, 0.6)
		await _shot("roll", i)
		await _wait(0.08)
	TK.release("sprint")
	TK.release("move_forward")
	await _wait(1.0)

	# screen: normal, low health, the knockout blink, launched
	_rig_view()
	await _shot("screen", 0)
	p.health_component.current_health = p.health_component.max_health * 0.1
	await _wait(0.6)
	await _shot("screen", 1)
	p.health_component.current_health = p.health_component.max_health
	p.knock_down(Vector3(0, 2.5, 2))
	await _wait(0.12)
	await _shot("screen", 2)
	await _wait(3.5)
	p.global_position += Vector3(0, 2, 0)
	p.velocity = Vector3(0, 26, 0)
	await _wait(0.3)
	await _shot("screen", 3)
	await _wait(0.25)
	await _shot("screen", 4)
	await _wait(2.5)
	p.health_component.current_health = p.health_component.max_health
	await _wait(4.0)

	# idle: weapon away, standing about; frames across two weight shifts
	if p.armed:
		TK.act("ready_weapon")
	await _wait(1.0)
	var fwd2: Vector3 = -p.player_model.global_basis.z
	_side(p.global_position, fwd2, 2.6, 0.3)
	p.body_model._idle_next = 0.5
	for i in range(COLS):
		await _shot("idle", i)
		await _wait(0.9)

	# wind: a long coat, calm then in a storm's wind from its left
	var lk: Dictionary = CharacterLook.default_look()
	lk.merge({"coat": "greatcoat"}, true)
	p.body_model.apply_look(lk)
	p.body_model._idle_next = 1e9
	await _wait(1.5)
	var fwd3: Vector3 = -p.player_model.global_basis.z
	_side(p.global_position, fwd3 * 0.8 + Vector3(fwd3.z, 0, -fwd3.x) * 0.6, 3.0, 0.3)
	await _shot("wind", 0)
	var gs := GDScript.new()
	gs.source_code = "extends Node\nvar wind_now := Vector3(0, 0, 0)\n"
	gs.reload()
	var storm := Node.new()
	storm.set_script(gs)
	root.add_child(storm)
	storm.set("wind_now", Vector3(fwd3.z, 0, -fwd3.x) * 3.0)
	p.body_model._weather = storm
	for i in range(1, COLS):
		await _wait(0.3)
		await _shot("wind", i)

	_sheet()
	print("SAVED")
	quit()


func _sheet() -> void:
	var any: Image = frames.values()[0]
	var fw: int = any.get_width() / 4
	var fh: int = any.get_height() / 4
	var sheet := Image.create((fw + 4) * COLS, (fh + 4) * ROWS.size(), false, Image.FORMAT_RGB8)
	sheet.fill(Color(0.08, 0.08, 0.08))
	for r in range(ROWS.size()):
		for c in range(COLS):
			var f: Image = frames.get("%s_%d" % [ROWS[r], c])
			if f == null:
				continue
			var s := f.duplicate()
			s.convert(Image.FORMAT_RGB8)
			s.resize(fw, fh, Image.INTERPOLATE_BILINEAR)
			sheet.blit_rect(s, Rect2i(0, 0, fw, fh), Vector2i(c * (fw + 4), r * (fh + 4)))
	sheet.save_png("%s/feel_sheet.png" % out)
