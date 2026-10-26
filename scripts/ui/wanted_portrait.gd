class_name WantedPortrait
extends RefCounted
## A captain's face for a wanted poster (WantedCard, the Wanted screen): their body built from their look in a
## world of its own, filmed head and shoulders once, then inked sepia like a printed poster. Async (a frame or two):
## `await WantedPortrait.render(tree, look)`. Cached by look, so the same face isn't filmed twice.

const SIZE := Vector2i(96, 112)
const PAPER := Color(0.9, 0.8, 0.6)
const INK := Color(0.2, 0.13, 0.08)

static var _cache := {}


static func render(tree: SceneTree, look: Dictionary) -> Texture2D:
	var key := str(look.hash())
	if _cache.has(key):
		return _cache[key]
	var vp := SubViewport.new()
	vp.size = SIZE
	vp.own_world_3d = true
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = PAPER
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.75, 0.72, 0.68)
	env.environment.ambient_light_energy = 0.8
	vp.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, 160, 0)
	sun.light_energy = 1.1
	vp.add_child(sun)
	var body := Humanoid.new()
	body.setup(look)
	vp.add_child(body)
	var cam := Camera3D.new()
	cam.fov = 24.0
	vp.add_child(cam)
	tree.root.add_child(vp)
	# (the body faces -Z: film it from the front, head and shoulders)
	cam.global_position = Vector3(0.0, 1.55, -2.1)
	cam.look_at(Vector3(0.0, 1.47, 0.0), Vector3.UP)
	for i in range(3):
		await tree.process_frame
	var img := vp.get_texture().get_image()
	vp.queue_free()
	if img == null or img.is_empty():
		return null
	img.convert(Image.FORMAT_RGBA8)
	# printed: grey by brightness, then laid between the ink and the paper
	for y in range(img.get_height()):
		for x in range(img.get_width()):
			var c := img.get_pixel(x, y)
			var v := clampf(c.r * 0.3 + c.g * 0.59 + c.b * 0.11, 0.0, 1.0)
			img.set_pixel(x, y, INK.lerp(PAPER, v * v * 0.6 + v * 0.4))
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex
