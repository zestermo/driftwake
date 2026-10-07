class_name PSXMat
extends RefCounted
## Cached PSX materials. All props share a handful of ShaderMaterials so the
## renderer can batch them. Textures live in res://assets/textures/psx/.

const TEX_DIR := "res://assets/textures/psx/"
const LIT_SHADER := preload("res://shaders/psx/psx_lit.gdshader")
const CUTOUT_SHADER := preload("res://shaders/psx/psx_cutout.gdshader")

static var _cache: Dictionary = {}
static var _tex_cache: Dictionary = {}
## Characters are built on a worker thread too (Humanoid.prebuild): the caches
## are shared, so every lookup holds this.
static var _lock := Mutex.new()


static func tex(tex_name: String) -> Texture2D:
	if tex_name == "":
		return null
	_lock.lock()
	if not _tex_cache.has(tex_name):
		_tex_cache[tex_name] = load(TEX_DIR + tex_name + ".png")
	var t: Texture2D = _tex_cache[tex_name]
	_lock.unlock()
	return t


static func _cached(key: String) -> ShaderMaterial:
	_lock.lock()
	var m: ShaderMaterial = _cache.get(key)
	_lock.unlock()
	return m


## Keep `m` under `key` (or the one another thread stored first).
static func _store(key: String, m: ShaderMaterial) -> ShaderMaterial:
	_lock.lock()
	if _cache.has(key):
		m = _cache[key]
	else:
		_cache[key] = m
	_lock.unlock()
	return m


## Opaque lit material. `tex_name` may be "" for a flat-colored surface.
static func lit(tex_name: String, tint: Color = Color.WHITE, opts: Dictionary = {}) -> ShaderMaterial:
	var key := "lit|%s|%s|%s" % [tex_name, tint.to_html(), str(opts)]
	var hit := _cached(key)
	if hit:
		return hit
	var m := ShaderMaterial.new()
	m.shader = LIT_SHADER
	var t := tex(tex_name)
	if t:
		m.set_shader_parameter("albedo_tex", t)
	m.set_shader_parameter("albedo_color", tint)
	m.set_shader_parameter("affine_amount", float(opts.get("affine", 1.0)))
	m.set_shader_parameter("decal_mode", bool(opts.get("decal", false)))
	m.set_shader_parameter("use_vertex_color", bool(opts.get("vertex_color", true)))
	if opts.has("emission_tex"):
		m.set_shader_parameter("emission_tex", tex(str(opts["emission_tex"])))
	if opts.has("emission"):
		m.set_shader_parameter("emission_color", opts["emission"])
		m.set_shader_parameter("emission_energy", float(opts.get("emission_energy", 1.0)))
		m.set_shader_parameter("emission_pulse", float(opts.get("emission_pulse", 0.0)))
		if not opts.has("emission_tex"):
			# Full-surface glow: use a white emission texture
			m.set_shader_parameter("emission_tex", _white())
	if opts.has("pull"):
		m.set_shader_parameter("depth_pull", float(opts["pull"]))
	if opts.has("cull_disabled"):
		m.render_priority = 0
	return _store(key, m)


## Alpha-cutout foliage material (double sided, optional wind sway).
static func cutout(tex_name: String, tint: Color = Color.WHITE, wind: float = 0.0, sway_height: float = 1.0) -> ShaderMaterial:
	var key := "cut|%s|%s|%f|%f" % [tex_name, tint.to_html(), wind, sway_height]
	var hit := _cached(key)
	if hit:
		return hit
	var m := ShaderMaterial.new()
	m.shader = CUTOUT_SHADER
	m.set_shader_parameter("albedo_tex", tex(tex_name))
	m.set_shader_parameter("albedo_color", tint)
	m.set_shader_parameter("wind_strength", wind)
	m.set_shader_parameter("sway_height", sway_height)
	return _store(key, m)


## Plain colored surface (no texture).
static func flat(color: Color) -> ShaderMaterial:
	return lit("", color)


## Glowing surface (lanterns, windows, fire).
static func glow(color: Color, energy: float = 2.0, tex_name: String = "") -> ShaderMaterial:
	return lit(tex_name, color, {"emission": color, "emission_energy": energy, "affine": 0.3})


static var _white_tex: ImageTexture


## Drop cached materials/textures (called on exit so nothing leaks).
static func clear_cache() -> void:
	_lock.lock()
	_cache.clear()
	_tex_cache.clear()
	_white_tex = null
	_lock.unlock()

static func _white() -> Texture2D:
	_lock.lock()
	if _white_tex == null:
		var img := Image.create(2, 2, false, Image.FORMAT_RGB8)
		img.fill(Color.WHITE)
		_white_tex = ImageTexture.create_from_image(img)
	var t := _white_tex
	_lock.unlock()
	return t


const TERRAIN_SHADER := preload("res://scenes/island/terrain.gdshader")

## Terrain material shared by the procedural world and the hand-built island.
static func terrain(use_splat: bool, water_level: float = 0.0) -> ShaderMaterial:
	var key := "terrain|%s|%f" % [str(use_splat), water_level]
	var hit := _cached(key)
	if hit:
		return hit
	var m := ShaderMaterial.new()
	m.shader = TERRAIN_SHADER
	m.set_shader_parameter("tex_grass", tex("grass"))
	m.set_shader_parameter("tex_sand", tex("sand"))
	m.set_shader_parameter("tex_wet_sand", tex("wet_sand"))
	m.set_shader_parameter("tex_dirt", tex("dirt"))
	m.set_shader_parameter("tex_rock", tex("rock"))
	m.set_shader_parameter("tex_seafloor", tex("seafloor"))
	m.set_shader_parameter("use_splat", use_splat)
	m.set_shader_parameter("water_level", water_level)
	m.set_shader_parameter("sand_height", water_level + 2.2)
	m.set_shader_parameter("rock_height", water_level + 14.0)
	return _store(key, m)
