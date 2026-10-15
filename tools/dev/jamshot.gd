extends SceneTree
## The captain with each instrument, on the light stage: playing it (front, front-left quarter, right side,
## a close-up), then carried (back, left side). Args: <out_prefix>. Env JS_KINDS=fiddle,gurdy: only those;
## JS_AT=<beats>: hold every play shot at that beat of the tune (default: wherever it is).
const TK := preload("res://tools/dev/test_kit.gd")
const PLAY_VIEWS := ["front", "quarter", "side", "close"]
const CARRY_VIEWS := ["back", "front"]
var out := ""
var stage
var p
var cam: Camera3D
var kinds: Array = ["concertina", "fiddle", "whistle", "bodhran", "gurdy"]
var shots: Array = []
var step := 0
var until := 0


func _initialize() -> void:
	out = OS.get_cmdline_user_args()[0]
	if OS.get_environment("JS_KINDS") != "":
		kinds = Array(OS.get_environment("JS_KINDS").split(","))
	for k in kinds:
		shots.append([k, "wear", ""])
		for v in PLAY_VIEWS:
			shots.append([k, "play", v])
		shots.append([k, "stop", ""])
		for v in CARRY_VIEWS:
			shots.append([k, "carry", v])
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false})
	# the icons, side by side at 8x
	var sheet := Image.create(24 * 8 * kinds.size(), 24 * 8, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.16, 0.12, 0.1))
	for i in range(kinds.size()):
		var img: Image = Instruments.icon(kinds[i]).get_image()
		img.resize(24 * 8, 24 * 8, Image.INTERPOLATE_NEAREST)
		sheet.blend_rect(img, Rect2i(0, 0, 24 * 8, 24 * 8), Vector2i(i * 24 * 8, 0))
	sheet.save_png("%s_icons.png" % out)


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	if cam == null:
		root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
		p = stage.player
		cam = Camera3D.new()
		cam.fov = 34
		root.add_child(cam)
		cam.current = true
	if step > 0 and str(shots[step - 1][2]) != "":
		var s: Array = shots[step - 1]
		root.get_texture().get_image().save_png("%s_%s_%s_%s.png" % [out, s[0], s[1], s[2]])
	if step >= shots.size():
		quit()
		return false
	var sh: Array = shots[step]
	var k: String = sh[0]
	match str(sh[1]):
		"wear":
			var it = ItemDB.get_item(Instruments.item_id(k))
			p.inventory_component.add_item(it, 1)
			p.equip_gear_from_bag(p.inventory_component.find_index(it.id))
			until = TK.wait_ticks(6)
		"play":
			if not p.jam.playing:
				p.jam.start()
				if OS.get_environment("JS_AT") != "":
					p.jam.t0 = root.get_node("Net").time() - float(OS.get_environment("JS_AT")) * p.jam.beat_len()
			_view(str(sh[2]))
			until = TK.wait_secs(0.9 if sh[2] == "front" else 0.25)
		"stop":
			p.jam.stop()
			until = TK.wait_secs(0.6)
		"carry":
			_view(str(sh[2]))
			until = TK.wait_ticks(8)
	step += 1
	return false


func _view(v: String) -> void:
	var b: Basis = p.player_model.global_basis
	var face := -b.z
	var right := b.x
	var at: Vector3 = p.global_position + Vector3(0, 1.1, 0)
	match v:
		"front": cam.global_position = at + face * 2.8 + right * 0.4 + Vector3(0, 0.2, 0)
		"quarter": cam.global_position = at + (face - right).normalized() * 2.4 + Vector3(0, 0.35, 0)
		"side": cam.global_position = at + right * 2.6 + face * 0.3
		"close":
			at.y += 0.35
			cam.global_position = at + (face * 1.0 + right * 0.45).normalized() * 1.3 + Vector3(0, 0.1, 0)
		"back": cam.global_position = at - face * 2.4 - right * 0.5 + Vector3(0, 0.2, 0)
	cam.look_at(at, Vector3.UP)
	cam.reset_physics_interpolation()
