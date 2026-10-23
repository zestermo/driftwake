class_name PSXMat
extends RefCounted
## Cached PSX materials. All props share a handful of ShaderMaterials so the
## renderer can batch them. Textures live in res://assets/textures/psx/.

const TEX_DIR := "res://assets/textures/psx/"
const LIT_SHADER := preload("res://shaders/psx/psx_lit.gdshader")
const CUTOUT_SHADER := preload("res://shaders/psx/psx_cutout.gdshader")
const DECAL_SHADER := preload("res://shaders/psx/psx_decal.gdshader")
const DECAL_UNSHADED_SHADER := preload("res://shaders/psx/psx_decal_unshaded.gdshader")
const DECAL_SHEET_SHADER := preload("res://shaders/psx/psx_decal_sheet.gdshader")
const DECAL_SHEET_UNSHADED_SHADER := preload("res://shaders/psx/psx_decal_sheet_unshaded.gdshader")
const SNOW_LAYER_SHADER := preload("res://shaders/world/snow_layer.gdshader")
## What a footprint multiplies the ground's colour by (terrain's prints), by ground: a blue shadow in snow, darker sand.
const PRINT_TINT := {"snow": Vector3(0.52, 0.62, 0.82), "sand": Vector3(0.6, 0.46, 0.32)}

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
	if opts.has("vc_srgb"):
		m.set_shader_parameter("vertex_srgb", true)
	m.set_meta("psx", [tex_name, tint, opts])
	return _store(key, m)


## The shared white-tinted twin of a plain lit material, and the tint (linear) its
## vertex colours must carry instead: one surface per texture, whatever the tints.
## [] for a material that can't fold (glow, decal, no vertex colour, not a PSXMat.lit) or already has,
## and for an object's own copy of one (its hit flash sets tint_mul on that copy).
static func fold(m: Material) -> Array:
	if m == null or not m.has_meta("psx"):
		return []
	var spec: Array = m.get_meta("psx")
	var opts: Dictionary = spec[2]
	if _cached("lit|%s|%s|%s" % [spec[0], (spec[1] as Color).to_html(), str(opts)]) != m:
		return []
	for k in opts:
		if not k in ["affine", "pull", "cull_disabled"]:
			return []
	var o := opts.duplicate()
	o["vc_srgb"] = true
	return [lit(spec[0], Color.WHITE, o), (spec[1] as Color).srgb_to_linear()]


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


## A flat mark lying on a surface (blood, puddles; psx_decal_body.gdshaderinc): blended over it, never
## written to depth, pulled toward the camera so the snapped ground never pokes through. Not cached: each
## caller owns its copy (to fade it). opts: unshaded, roughness, specular, pull (metres at 5 m).
static func decal(color: Color, opts: Dictionary = {}) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = DECAL_UNSHADED_SHADER if opts.get("unshaded", false) else DECAL_SHADER
	m.set_shader_parameter("albedo_color", color)
	for k in ["roughness", "specular", "pull"]:
		if opts.has(k):
			m.set_shader_parameter(k, float(opts[k]))
	return m


## A decal drawn from a flipbook sheet (assets/textures/fx/<sheet_name>.png, 4x2 frames; gen_dither_fx.py)
## on a mesh's UVs. opts as decal(), plus fps (loops by itself; else set "frame"), palette ([dark, deep,
## body, hi] for an index sheet).
static func decal_sheet(sheet_name: String, color: Color = Color.WHITE, opts: Dictionary = {}) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = DECAL_SHEET_UNSHADED_SHADER if opts.get("unshaded", false) else DECAL_SHEET_SHADER
	m.set_shader_parameter("albedo_color", color)
	m.set_shader_parameter("sheet", load("res://assets/textures/fx/%s.png" % sheet_name))
	for k in ["roughness", "specular", "pull", "fps"]:
		if opts.has(k):
			m.set_shader_parameter(k, float(opts[k]))
	if opts.has("palette"):
		m.set_shader_parameter("palette_mode", true)
		for i in range(4):
			m.set_shader_parameter(["pal_dark", "pal_deep", "pal_body", "pal_hi"][i], opts["palette"][i])
	return m


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
## `ground` swaps the textures by layer (KitStyle "ground": grass, sand, wet_sand, dirt, rock, seafloor).
## `prints` (KitStyle "ground_prints"): footprints pressed into it ("sand", "snow"); "snow" also lays the soft
## snow layer over it as a next pass (snow_layer.gdshader).
static func terrain(use_splat: bool, water_level: float = 0.0, ground: Dictionary = {}, prints := "") -> ShaderMaterial:
	var key := "terrain|%s|%f" % [str(use_splat), water_level]
	if not ground.is_empty():
		key += "|" + str(ground)
	if prints != "":
		key += "|" + prints
	var hit := _cached(key)
	if hit:
		return hit
	var m := ShaderMaterial.new()
	m.shader = TERRAIN_SHADER
	for layer in ["grass", "sand", "wet_sand", "dirt", "rock", "seafloor"]:
		m.set_shader_parameter("tex_" + layer, tex(str(ground.get(layer, layer))))
	m.set_shader_parameter("use_splat", use_splat)
	m.set_shader_parameter("water_level", water_level)
	m.set_shader_parameter("sand_height", water_level + 2.2)
	m.set_shader_parameter("rock_height", water_level + 14.0)
	if prints != "":
		var shade: Vector3 = PRINT_TINT[prints]
		m.set_shader_parameter("prints", true)
		m.set_shader_parameter("print_tint", shade)
		if prints == "snow":
			var layer := ShaderMaterial.new()
			layer.shader = SNOW_LAYER_SHADER
			layer.set_shader_parameter("tex_snow", tex(str(ground.get("grass", "grass"))))
			layer.set_shader_parameter("water_level", water_level)
			layer.set_shader_parameter("print_tint", shade)
			m.next_pass = layer
	return _store(key, m)
