extends SceneTree
## (1.30) Wall splats render (Splat): three overkills on the light stage, each a strip of frames along game time
## from a side camera: into a wall 6 m behind, a launcher up into a ceiling, and in the open (the landing and skid).
## Args: <out_prefix>. Shots: <out>_wall.png, <out>_ceiling.png, <out>_open.png, <out>_mark.png (the wall mark close).
const TK := preload("res://tools/dev/test_kit.gd")
const GY := 3.0
const TIMES := [0.0, 0.12, 0.3, 0.7, 1.25, 2.0]
var stage
var out := ""
var cam: Camera3D
var step := 0
var until := 0
var scene := 0
var frame := 0
var strip: Image
var cases: Array = []


func _initialize() -> void:
	out = OS.get_cmdline_user_args()[0]
	stage = TK.stage(self, {"hud": false, "grunts": [
		{"post": Vector3(0.0, 0, -4.0), "role": "sword", "seed": 1},
		{"post": Vector3(-14.0, 0, 0.0), "role": "sword", "seed": 2},
		{"post": Vector3(14.0, 0, 0.0), "role": "sword", "seed": 3}]})


func slab(at: Vector3, size: Vector3) -> void:
	var b := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	cs.shape = box
	b.add_child(cs)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = PSXMat.lit("rock", Color(0.95, 0.9, 0.82))
	b.add_child(mi)
	stage.add_child(b)
	b.global_position = at


func aim() -> void:
	cam.global_position = Vector3(0, GY, 0) + cases[scene][4]
	cam.look_at(Vector3(0, GY, 0) + cases[scene][5], Vector3.UP)


func shot() -> Image:
	var img := root.get_texture().get_image()
	img.resize(img.get_width() / 2, img.get_height() / 2, Image.INTERPOLATE_NEAREST)
	return img


func _process(_d: float) -> bool:
	for n in root.find_children("*", "CharacterCreator", true, false):
		n._finish(true)
	if not stage.up or TK.ticking(until):
		return false
	var gs: Array = stage.camp.grunts
	match step:
		0:
			if gs.size() < 3:
				return false
			stage.player.hurtbox.monitorable = false
			stage.player.process_mode = Node.PROCESS_MODE_DISABLED
			stage.player.visible = false
			slab(Vector3(0, GY + 3.0, -10.5), Vector3(10, 6, 1))
			slab(Vector3(-14, GY + 4.6, 0), Vector3(5, 0.5, 5))
			for g in gs:
				g.set_physics_process(false)
			cam = Camera3D.new()
			cam.fov = 50.0
			root.add_child(cam)
			cam.current = true
			cases = [
				["wall", gs[0], Vector3(0, 0, -1), 0.0, Vector3(6.5, 2.4, -2.5), Vector3(0, 1.6, -8.0)],
				["ceiling", gs[1], Vector3(0, 0, -1), 9.0, Vector3(-14.0, 2.4, 8.0), Vector3(-14.0, 2.6, 0)],
				["open", gs[2], Vector3(1, 0, 0), 0.0, Vector3(17.5, 2.2, 8.0), Vector3(17.5, 0.6, 0)]]
			aim()
			until = TK.wait_secs(0.8)
		1:
			var c: Array = cases[scene]
			var g = c[1]
			var h := HitData.new()
			h.damage = 500.0
			h.poise = 6.0
			h.launch = c[3]
			var src := Node3D.new()
			stage.add_child(src)
			src.global_position = g.global_position - (c[2] as Vector3) * 2.0
			g._on_hit(h, src)
			frame = 0
			strip = null
			until = TK.wait_ticks(1)
		2:
			var img := shot()
			if strip == null:
				strip = Image.create(img.get_width() * TIMES.size(), img.get_height(), false, img.get_format())
			strip.blit_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i(img.get_width() * frame, 0))
			frame += 1
			if frame < TIMES.size():
				until = TK.wait_secs(TIMES[frame] - TIMES[frame - 1])
				return false
			strip.save_png("%s_%s.png" % [out, cases[scene][0]])
			print("SAVED %s_%s.png" % [out, cases[scene][0]])
			scene += 1
			if scene < cases.size():
				aim()
				step = 1
				until = TK.wait_secs(0.4)
				return false
			# (a bare mark beside the body's, no blood: the cracks themselves)
			root.get_node("FX").call("splat", Vector3(3.0, GY + 2.0, -10.0), Vector3.BACK, 1.0, false, 7)
			cam.global_position = Vector3(1.5, GY + 2.2, -5.0)
			cam.look_at(Vector3(1.5, GY + 1.8, -10.0), Vector3.UP)
			until = TK.wait_secs(1.0)
		3:
			root.get_texture().get_image().save_png("%s_mark.png" % out)
			print("SAVED %s_mark.png" % out)
			quit()
	step += 1
	return false
