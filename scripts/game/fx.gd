extends Node
## One-shot visual + audio effects (autoload "FX"): dust puffs and rings,
## sparkles, hit impacts, sword slash trails and positional sounds.
## Everything is spawned on demand and frees itself.

const SLASH_SHADER := preload("res://shaders/psx/slash_trail.gdshader")
## Sounds in res://assets/audio: name.wav, or takes name_1.wav, name_2.wav...
## played at random (never the same take twice running).
const SOUNDS := [
	"whoosh", "whoosh_big", "hit", "jump", "land", "chitter", "bug_hiss", "thud", "coin",
	"splash", "blip", "blip_high", "blip_low", "gunshot", "parry", "fire_burst", "fire_blast", "crunch",
	"howl", "haki", "block", "peril", "bell", "cannon", "cannon_hit", "horn", "roar", "rope",
	"splash_big", "wood_crack", "gull", "bow_spray", "swim_stroke", "hull_wave", "wave_break", "rock_crash",
	"gull_cry", "jungle_bird",
	"step_sand", "step_grass", "step_dirt", "step_stone", "step_wood", "step_water", "step_snow", "step_ice",
	"grunt", "squeal", "screech", "squawk", "flap", "hiss", "monkey", "clack",
	"draw_katana", "sheathe_katana", "draw_blade", "sheathe_blade", "draw_axe", "sheathe_axe", "draw_great", "sheathe_great",
	"draw_dagger", "sheathe_dagger", "draw_pistol", "gun_spin", "holster",
	"laugh", "cheer", "hup", "heel_click", "slap",
	"slice", "slice_heavy", "chop", "punch", "punch_heavy", "shot_hit", "clash",
	"fin_sting", "jelly_zap",
	"fish_cast", "fish_plop", "fish_bite", "fish_reel", "fish_catch",
]

var _dust_mat: StandardMaterial3D
var _spark_mat: StandardMaterial3D
var _impact_mat: StandardMaterial3D
var _petal_mat: StandardMaterial3D
var _flame_mat: StandardMaterial3D
var _flame_ramp: Gradient
var _slash_mat: ShaderMaterial
var _blood_mat: StandardMaterial3D
var _streak_mesh: BoxMesh
var _splat_mat: StandardMaterial3D
var _splats: Array = []
## Spray (flecks, streaks, mist) is darker than what lands: it reads lighter in the air.
const BLOOD := Color(0.2, 0.0, 0.012)
const SPLAT := Color(0.42, 0.02, 0.03)
## Ground splats kept at once (the oldest go first) and how long each lasts.
const MAX_SPLATS := 120
const SPLAT_LIFE := 40.0
## Splat shapes made at start ([round, directed]), each splat one of them turned and stretched its own way
## (a fresh mesh per splat was ~1 ms of GDScript, 2-5 of them a bloody hit).
const SPLAT_SHAPES := 12
var _splat_shapes := [[], []]
var _streams: Dictionary = {}
var _slash_meshes: Dictionary = {}


func _ready() -> void:
	_dust_mat = _billboard_mat("res://assets/textures/fx/dust.png", false)
	_spark_mat = _billboard_mat("res://assets/textures/fx/sparkle.png", true)
	_impact_mat = _billboard_mat("res://assets/textures/fx/impact.png", true)
	_petal_mat = _billboard_mat("res://assets/textures/fx/dust.png", false)
	_petal_mat.albedo_texture = _petal_texture()
	_flame_mat = _billboard_mat("res://assets/textures/fx/dust.png", true)
	_flame_ramp = Gradient.new()
	_flame_ramp.offsets = PackedFloat32Array([0.0, 0.25, 0.6, 1.0])
	_flame_ramp.colors = PackedColorArray([Color(1.0, 0.95, 0.6, 1.0), Color(1.0, 0.62, 0.15, 0.95),
		Color(0.85, 0.22, 0.05, 0.7), Color(0.3, 0.06, 0.02, 0.0)])
	_slash_mat = ShaderMaterial.new()
	_slash_mat.shader = SLASH_SHADER
	# blood droplets: plain square flecks (they read as pixels at PSX resolution)
	_blood_mat = StandardMaterial3D.new()
	_blood_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_blood_mat.vertex_color_use_as_albedo = true
	_blood_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	_blood_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	# (taken as linear, BLOOD showed as a pinkish mid red)
	_blood_mat.vertex_color_is_srgb = true
	# streaks: thin boxes stretched along their flight (particle_flag_align_y)
	var streak_mat := _blood_mat.duplicate() as StandardMaterial3D
	streak_mat.billboard_mode = BaseMaterial3D.BILLBOARD_DISABLED
	_streak_mesh = BoxMesh.new()
	_streak_mesh.size = Vector3(0.022, 0.16, 0.022)
	_streak_mesh.material = streak_mat
	_splat_mat = StandardMaterial3D.new()
	_splat_mat.albedo_color = SPLAT
	_splat_mat.vertex_color_use_as_albedo = true
	_splat_mat.roughness = 0.25
	_splat_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var srng := RandomNumberGenerator.new()
	srng.seed = 7
	for i in range(SPLAT_SHAPES):
		_splat_shapes[0].append(_splat_mesh(false, srng))
		_splat_shapes[1].append(_splat_mesh(true, srng))
	for k in SOUNDS:
		_streams[k] = _sound_set(k)
	var dim := Timer.new()
	dim.wait_time = 2.0
	dim.autostart = true
	dim.timeout.connect(_dim_emitters)
	add_child(dim)


func _sound_set(sound_name: String) -> AudioStream:
	var takes: Array = []
	while ResourceLoader.exists("res://assets/audio/%s_%d.wav" % [sound_name, takes.size() + 1]):
		takes.append(load("res://assets/audio/%s_%d.wav" % [sound_name, takes.size() + 1]))
	if takes.is_empty():
		return load("res://assets/audio/%s.wav" % sound_name)
	var r := AudioStreamRandomizer.new()
	r.playback_mode = AudioStreamRandomizer.PLAYBACK_RANDOM_NO_REPEATS
	r.random_pitch = 1.0
	r.random_volume_offset_db = 0.0
	for s in takes:
		r.add_stream(-1, s)
	return r


func _billboard_mat(tex_path: String, additive: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_texture = load(tex_path)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.vertex_color_use_as_albedo = true
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if additive:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.no_depth_test = false
	return m


## A petal: a pointed oval, a shade paler toward its tip (8x8, tinted per burst).
static func _petal_texture() -> ImageTexture:
	var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	for y in range(8):
		for x in range(8):
			var u := (x - 3.5) / 3.5
			var v := (y - 3.5) / 3.9
			var w := 1.0 - (v + 1.0) * 0.3
			if u * u / maxf(w * w, 0.01) + v * v <= 1.0:
				var shade := 0.8 + 0.2 * (1.0 - y / 7.0)
				img.set_pixel(x, y, Color(shade, shade, shade, 1.0))
	return ImageTexture.create_from_image(img)


## Every kind of effect once, in front of the camera, behind the loading screen (LoadingScreen's last moment):
## a material's shader and pipelines are compiled the first time it's drawn, which on a fresh install (no
## user shader cache) was a 50-400 ms frame at the first blow, splash or blast of a session.
func warm_up() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var at := cam.global_position - cam.global_basis.z * 6.0
	var side := cam.global_basis.x
	var up := Vector3.UP
	dust(at)
	dust_ring(at)
	heavy_dust(at)
	poison(at)
	bleed(at, side)
	# (a splat drawn for a moment, not left lying on the ground where the captain wakes)
	var splat := MeshInstance3D.new()
	splat.mesh = _splat_shapes[0][0]
	splat.material_override = _splat_mat
	_scene_root().add_child(splat)
	splat.global_position = at
	get_tree().create_timer(0.6).timeout.connect(splat.queue_free)
	sparkle(at)
	splash(at)
	bubbles(at)
	water_ring(at)
	smoke(at)
	muzzle_sparks(at, side)
	impact(at)
	parry_sparks(at, side)
	float_text(at, "0")
	tracer(at - side, at + side)
	flame(at)
	ring(at)
	spray(at, up)
	petals(at, up)
	motes(at, up)
	powder_burst(at, side)
	cannon_blast(at)
	blast(at)
	cannon_hit(at, up)
	cannon_splash(at)
	twin_cross(at, side)
	embers(at, up)
	debris(at)
	gather(at)
	streak(at - side, at + side)
	glint(at)
	sakura(at, up)
	droplets(at, up)
	for sheet in FLIP_SHEETS:
		puff(at, sheet)
	for tree in TREE_FX:
		elem_hit(tree, at, side)
	punch_wind(at, side)
	ground_crack(at, side, 2.0)
	cut_lines(at, 3)
	water_wake(at - side, at + side)
	katana_line(at - side, at + side)
	var holder := Node3D.new()
	_scene_root().add_child(holder)
	holder.global_position = at
	slash(holder, "right")
	vortex(holder, 0.5)
	get_tree().create_timer(0.7).timeout.connect(holder.queue_free)


func _scene_root() -> Node:
	var cs := get_tree().current_scene
	return cs if cs else get_tree().root


## Bursts this far from the camera aren't made at all.
const BURST_RANGE := 160.0
## Shared burst resources (one each, not one per burst).
static var _curves: Dictionary = {}
static var _grads: Dictionary = {}
static var _quads: Dictionary = {}


static func _curve(kind: String) -> Curve:
	if not _curves.has(kind):
		var curve := Curve.new()
		match kind:
			"hold":
				# full size most of the way, then gone (drops, not puffs)
				curve.add_point(Vector2(0, 1.0))
				curve.add_point(Vector2(0.75, 1.0))
				curve.add_point(Vector2(1, 0.0))
			"grow":
				curve.add_point(Vector2(0, 0.6))
				curve.add_point(Vector2(1, 1.3))
			"flat":
				curve.add_point(Vector2(0, 1.0))
				curve.add_point(Vector2(1, 1.0))
			_:
				curve.add_point(Vector2(0, 1.0))
				curve.add_point(Vector2(1, 0.0))
		_curves[kind] = curve
	return _curves[kind]


static func _fade_to_clear(col: Color) -> Gradient:
	if not _grads.has(col):
		if _grads.size() > 64:
			_grads.clear()
		var grad := Gradient.new()
		grad.set_color(0, col)
		grad.set_color(1, Color(col.r, col.g, col.b, 0.0))
		_grads[col] = grad
	return _grads[col]


static func _quad(size: float, mat: Material) -> QuadMesh:
	var key := [snappedf(size, 0.01), mat]
	if not _quads.has(key):
		if _quads.size() > 128:
			_quads.clear()
		var quad := QuadMesh.new()
		quad.size = Vector2(size, size)
		quad.material = mat
		_quads[key] = quad
	return _quads[key]


func _burst(pos: Vector3, amount: int, mat: Material, size: float, life: float, cfg: Dictionary) -> CPUParticles3D:
	var cam := get_viewport().get_camera_3d()
	if cam and cam.global_position.distance_squared_to(pos) > BURST_RANGE * BURST_RANGE:
		return null
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = cfg.get("explosiveness", 0.95)
	p.amount = maxi(amount, 1)
	p.lifetime = life
	# Local space: bursts never move once spawned, and world-space CPU particles
	# drop out entirely on long frames (hitches), which local space avoids.
	p.local_coords = true
	p.emission_shape = cfg.get("shape", CPUParticles3D.EMISSION_SHAPE_SPHERE)
	p.emission_sphere_radius = cfg.get("radius", 0.2)
	if cfg.has("ring_radius"):
		p.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
		p.emission_ring_axis = Vector3.UP
		p.emission_ring_height = 0.05
		p.emission_ring_radius = cfg["ring_radius"]
		p.emission_ring_inner_radius = cfg["ring_radius"] * 0.8
	p.direction = cfg.get("direction", Vector3.UP)
	p.spread = cfg.get("spread", 60.0)
	p.gravity = cfg.get("gravity", Vector3(0, -2.0, 0))
	p.initial_velocity_min = cfg.get("vel_min", 0.6)
	p.initial_velocity_max = cfg.get("vel_max", 1.6)
	p.damping_min = cfg.get("damping", 2.0)
	p.damping_max = cfg.get("damping", 2.0)
	p.radial_accel_min = cfg.get("radial", 0.0)
	p.radial_accel_max = cfg.get("radial", 0.0)
	p.scale_amount_min = cfg.get("scale_min", 0.7)
	p.scale_amount_max = cfg.get("scale_max", 1.2)
	p.scale_amount_curve = _curve("hold" if cfg.get("hold", false) else ("grow" if cfg.get("grow", true) else "shrink"))
	p.particle_flag_align_y = cfg.get("align", false)
	if cfg.has("ramp"):
		p.color_ramp = cfg["ramp"]
	else:
		p.color_ramp = _fade_to_clear(cfg.get("color", Color(0.85, 0.8, 0.68, 0.85)))
	p.mesh = cfg["mesh"] if cfg.has("mesh") else _quad(size, mat)
	_scene_root().add_child(p)
	p.global_position = pos
	p.emitting = true
	p.finished.connect(p.queue_free)
	return p


static var _tele_mat: StandardMaterial3D
static var _ring_mesh: ArrayMesh
static var _disc_mesh: ArrayMesh


## A warning on the ground: a ring where a big attack will land, filling in
## over `secs` (then it's gone). `follow` (a node key) carries it along on
## that node (a ship's deck under way).
func telegraph(pos: Vector3, radius: float, secs: float, color: Color = Color(1.0, 0.18, 0.12), follow: String = "") -> void:
	_tele_init()
	var holder := Node3D.new()
	holder.name = "Telegraph"
	var net := get_node_or_null("/root/Net")
	var on: Node3D = net.node_of(follow) as Node3D if net and follow != "" else null
	if on:
		on.add_child(holder)
	else:
		_scene_root().add_child(holder)
	holder.global_position = pos + Vector3(0, 0.07, 0)
	var ring := MeshInstance3D.new()
	ring.mesh = _ring_mesh
	ring.material_override = _tele_mat
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.scale = Vector3(radius, 1.0, radius)
	holder.add_child(ring)
	var disc := MeshInstance3D.new()
	disc.mesh = _disc_mesh
	disc.material_override = _tele_mat
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	disc.scale = Vector3(0.01, 1.0, 0.01)
	holder.add_child(disc)
	var c1 := Color(color.r, color.g, color.b, 0.85)
	var c2 := Color(color.r, color.g, color.b, 0.35)
	_tint(ring, c1)
	_tint(disc, c2)
	var tw := holder.create_tween()
	tw.tween_property(disc, "scale", Vector3(radius, 1.0, radius), maxf(secs, 0.05))
	tw.tween_callback(holder.queue_free)


static var _arc_meshes: Dictionary = {}


func _tele_init() -> void:
	if _tele_mat != null:
		return
	_tele_mat = StandardMaterial3D.new()
	_tele_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_tele_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_tele_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_tele_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_tele_mat.vertex_color_use_as_albedo = true
	_ring_mesh = _annulus(0.88, 1.0)
	_disc_mesh = _annulus(0.0, 1.0)


## A small fan on the ground in front of an attacker, `radius` m out over
## `angle` rad about `dir`: the rim shows at once and the fill sweeps out to
## it over `secs` (a close blow on its way: the rifle butt, a low sweep).
func arc_warn(pos: Vector3, dir: Vector3, radius: float, angle: float, secs: float, color: Color = Color(1.0, 0.9, 0.6)) -> void:
	_tele_init()
	var key := snappedf(angle, 0.05)
	if not _arc_meshes.has(key):
		_arc_meshes[key] = [_fan(0.86, 1.0, key), _fan(0.0, 1.0, key)]
	var d := Vector3(dir.x, 0.0, dir.z).normalized()
	var holder := Node3D.new()
	holder.name = "ArcWarn"
	_scene_root().add_child(holder)
	holder.global_transform = Transform3D(Basis.looking_at(d, Vector3.UP), pos + Vector3(0, 0.07, 0))
	var rim := MeshInstance3D.new()
	rim.mesh = _arc_meshes[key][0]
	rim.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	rim.scale = Vector3(radius, 1.0, radius)
	holder.add_child(rim)
	var fill := MeshInstance3D.new()
	fill.mesh = _arc_meshes[key][1]
	fill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	fill.scale = Vector3(0.05, 1.0, 0.05)
	holder.add_child(fill)
	_tint(rim, Color(color.r, color.g, color.b, 0.85))
	_tint(fill, Color(color.r, color.g, color.b, 0.35))
	var tw := holder.create_tween()
	tw.tween_property(fill, "scale", Vector3(radius, 1.0, radius), maxf(secs, 0.05))
	tw.tween_callback(holder.queue_free)


## A flat fan (-Z forward) between radii `inner` and `outer`, `angle` rad wide.
func _fan(inner: float, outer: float, angle: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 12
	for i in range(n):
		var a0 := -angle * 0.5 + angle * i / n
		var a1 := -angle * 0.5 + angle * (i + 1) / n
		var o0 := Vector3(sin(a0), 0, -cos(a0))
		var o1 := Vector3(sin(a1), 0, -cos(a1))
		for v in [o0 * inner, o0 * outer, o1 * outer, o0 * inner, o1 * outer, o1 * inner]:
			st.set_color(Color.WHITE)
			st.add_vertex(v)
	return st.commit()


## A strip on the ground where a charge or a dash will run (BeastFX.lane, sendable through Net.fx).
func lane(from: Vector3, to: Vector3, width: float, secs: float, color: Color = Color(1.0, 0.18, 0.12)) -> void:
	BeastFX.lane(from, to, width, secs, color)


func _tint(mi: MeshInstance3D, c: Color) -> void:
	var m := _tele_mat.duplicate() as StandardMaterial3D
	m.albedo_color = c
	mi.material_override = m


func _annulus(inner: float, outer: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 32
	for i in range(n):
		var a0 := TAU * i / n
		var a1 := TAU * (i + 1) / n
		var o0 := Vector3(cos(a0), 0, sin(a0))
		var o1 := Vector3(cos(a1), 0, sin(a1))
		for v in [o0 * inner, o0 * outer, o1 * outer, o0 * inner, o1 * outer, o1 * inner]:
			st.set_color(Color.WHITE)
			st.add_vertex(v)
	return st.commit()


## Little dust puff (footsteps, jumps, rolls).
func dust(pos: Vector3, amount: int = 5, size: float = 0.5) -> void:
	if flipbooks:
		puff(pos, "dust", maxi(amount / 3, 1), size * 1.6, 0.6, Color.WHITE, 1.0)
		return
	_burst(pos, amount, _dust_mat, size, 0.55, {
		"radius": 0.15, "spread": 70.0, "vel_min": 0.5, "vel_max": 1.4, "gravity": Vector3(0, 0.4, 0), "damping": 3.0})


## A chimney's thin smoke, rising and drifting for good (under `parent`).
func chimney_smoke(parent: Node3D, pos: Vector3) -> CPUParticles3D:
	if flipbooks:
		var w := flip_emitter(parent, "wisp", 6, 1.6, 4.5, {"radius": 0.15, "spread": 12.0, "gravity": Vector3(0.25, 0.35, 0.1),
			"vel_min": 0.5, "vel_max": 0.8, "damping": 0.15, "curve": "grow", "start": 0.05, "spin": 6.0, "fade_in": 0.12, "fade": 0.55,
			"color": Color(0.72, 0.7, 0.68, 0.5)})
		w.name = "Smoke"
		w.position = pos
		return w
	var p := CPUParticles3D.new()
	p.name = "Smoke"
	p.amount = 10
	p.lifetime = 4.5
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.15
	p.direction = Vector3.UP
	p.spread = 12.0
	p.gravity = Vector3(0.25, 0.35, 0.1)
	p.initial_velocity_min = 0.5
	p.initial_velocity_max = 0.8
	p.damping_min = 0.1
	p.damping_max = 0.2
	p.scale_amount_min = 0.8
	p.scale_amount_max = 1.2
	p.scale_amount_curve = _curve("grow")
	p.color_ramp = _fade_to_clear(Color(0.72, 0.7, 0.68, 0.45))
	p.mesh = _quad(0.9, _dust_mat)
	p.visibility_range_end = 140.0
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(p)
	p.position = pos
	p.emitting = true
	return p


## Green venom bubbles (poisoned targets, spit trails and splashes).
func poison(pos: Vector3, amount: int = 4, size: float = 0.35) -> void:
	_burst(pos, amount, _dust_mat, size, 0.6, {
		"radius": 0.2, "spread": 50.0, "vel_min": 0.4, "vel_max": 1.2, "gravity": Vector3(0, 1.2, 0), "damping": 2.5,
		"color": Color(0.45, 0.95, 0.25, 0.85), "grow": false})


## A blob of venom lobbed from `from` at velocity `vel` (PoisonGlob).
func spit(from: Vector3, vel: Vector3, damage: float, size: float = 1.0, poison_secs: float = 4.0, poison_dps: float = 3.0) -> void:
	var g := PoisonGlob.new()
	g.vel = vel
	g.damage = damage
	g.size = size
	g.poison_secs = poison_secs
	g.poison_dps = poison_dps
	_scene_root().add_child(g)
	g.global_position = from


## Expanding ring of dust (landings, heavy slam).
func dust_ring(pos: Vector3, amount: int = 12, size: float = 0.7) -> void:
	if flipbooks:
		puff_ring(pos, "dust_low", maxi(amount / 2, 4), 0.35, size * 2.1, 0.8, Color.WHITE, 6.0)
		return
	_burst(pos + Vector3(0, 0.08, 0), amount, _dust_mat, size, 0.6, {
		"ring_radius": 0.35, "spread": 15.0, "direction": Vector3(0, 0.2, 0), "vel_min": 0.4, "vel_max": 0.8,
		"radial": 6.0, "gravity": Vector3(0, 0.3, 0), "damping": 5.0})


## Twinkly stars (double jump, parry, pickups).
## Blood from a wound: the spray (bleed) thrown along `dir` (away from the
## blow), red mist, a big splat on the ground ahead with smaller ones strung
## out further along, and one on any wall (crate, mast...) close behind.
func blood(pos: Vector3, dir: Vector3, amount: int = 12) -> void:
	var dn := dir.normalized() if dir.length() > 0.01 else Vector3.UP
	var d := (dn + Vector3.UP * 0.35).normalized()
	bleed(pos, d, amount)
	if flipbooks:
		puff(pos, "blood", 2, 0.55, 0.45, Color.WHITE, 1.0, d)
	else:
		_burst(pos, 5, _dust_mat, 0.4, 0.45, {"radius": 0.06, "direction": d, "spread": 45.0, "vel_min": 0.4,
			"vel_max": 1.2, "gravity": Vector3(0, -1.5, 0), "color": Color(0.09, 0.0, 0.004, 0.6)})
	var flat := Vector3(dn.x, 0.0, dn.z)
	var along := flat.normalized() if flat.length() > 0.01 else Vector3.ZERO
	blood_splat(pos + along * randf_range(0.3, 0.9), 0.3 + 0.014 * amount, along)
	if along != Vector3.ZERO:
		for i in range(randi_range(1, 3)):
			var at := pos + along * randf_range(1.2, 2.8) + Vector3(randf_range(-0.35, 0.35), 0.0, randf_range(-0.35, 0.35))
			blood_splat(at, (0.1 + 0.007 * amount) * randf_range(0.6, 1.3), along)
	# the spray carries on along the blow and slightly down: whatever it meets
	var spray := (dn + Vector3.DOWN * 0.15).normalized() * WALL_REACH
	var h := _ray(pos, pos + spray)
	if not h.is_empty() and absf((h["normal"] as Vector3).y) < 0.7:
		_place_splat(h["position"], h["normal"], 0.24 + 0.012 * amount, dn)


## Just the spray, no splats (a stump pumping, a severed head dripping): a fast
## jet of streaks along `dir` and flecks of every size arcing down.
func bleed(pos: Vector3, dir: Vector3, amount: int = 12) -> void:
	var d := dir.normalized()
	# opaque until the drops shrink away (a fade read as pink against the sand)
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.8, 1.0])
	ramp.colors = PackedColorArray([BLOOD, BLOOD, Color(BLOOD.r, BLOOD.g, BLOOD.b, 0.0)])
	_burst(pos, amount * 2, _blood_mat, 0.07, 0.7, {"radius": 0.06, "direction": d, "spread": 34.0,
		"vel_min": 1.6, "vel_max": 5.5, "gravity": Vector3(0, -14.0, 0), "damping": 0.3, "hold": true,
		"scale_min": 0.35, "scale_max": 1.9, "ramp": ramp})
	_burst(pos, maxi(int(amount * 0.5), 2), _blood_mat, 0.0, 0.45, {"radius": 0.03, "direction": d, "spread": 12.0,
		"vel_min": 4.5, "vel_max": 8.5, "gravity": Vector3(0, -12.0, 0), "damping": 0.2, "hold": true,
		"align": true, "mesh": _streak_mesh, "scale_min": 0.6, "scale_max": 1.5, "ramp": ramp})


## A splat on whatever is below `pos` (ground, deck), lying on it; `along`
## stretches it and flings its droplets that way (the way the spray flew).
func blood_splat(pos: Vector3, size: float = 0.3, along: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var h := _ray(pos + Vector3.UP * 0.3, pos + Vector3.DOWN * 4.0)
	if h.is_empty():
		return null
	return _place_splat(h["position"], h["normal"], size, along)


## A pool spreading out under `pos` over `secs` (a body bleeding out).
func blood_pool(pos: Vector3, size: float, secs: float) -> void:
	var mi := blood_splat(pos, size)
	if mi == null:
		return
	var full := mi.scale
	mi.scale = full * 0.15
	mi.create_tween().tween_property(mi, "scale", full, secs).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)


## How far behind a wound the spray can reach a wall.
const WALL_REACH := 2.4


func _ray(from: Vector3, to: Vector3) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(from, to, 1)
	return get_viewport().world_3d.direct_space_state.intersect_ray(q)


## A blood splat flat on a surface (any angle) at `at`, facing out along `n`,
## stretched along `along` (projected onto the surface) when given.
func _place_splat(at: Vector3, n: Vector3, size: float, along: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var up := n.normalized()
	var x := along - up * along.dot(up)
	var directed := x.length() > 0.05
	var mi := MeshInstance3D.new()
	mi.mesh = (_splat_shapes[1] if directed else _splat_shapes[0]).pick_random()
	mi.material_override = _splat_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_scene_root().add_child(mi)
	var b: Basis
	if directed:
		x = x.normalized()
		b = Basis(x, up, x.cross(up))
	else:
		var side := up.cross(Vector3.FORWARD if absf(up.z) < 0.9 else Vector3.RIGHT).normalized()
		b = Basis(side, up, side.cross(up)).rotated(up, randf() * TAU)
	var s := size * randf_range(0.8, 1.25)
	var stretch := randf_range(1.2, 1.6) if directed else 1.0
	mi.global_transform = Transform3D(b * Basis.from_scale(Vector3(s * stretch, s, s)), at + up * 0.015)
	_splats.append(mi)
	while _splats.size() > MAX_SPLATS:
		var old = _splats.pop_front()
		if is_instance_valid(old):
			old.queue_free()
	var tw := mi.create_tween()
	tw.tween_interval(SPLAT_LIFE)
	tw.tween_property(mi, "scale", Vector3.ZERO, 1.5)
	tw.tween_callback(func():
		_splats.erase(mi)
		mi.queue_free())
	return mi


## An uneven unit splat (flat, +Y up): a few lumpy blobs run together, thin
## fingers out of it and droplets flung round it - mostly onward (+X) when
## `directed`. Vertex colours darken the middle (the albedo multiplies them).
func _splat_mesh(directed: bool, rng: RandomNumberGenerator) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	var blobs := [[Vector2.ZERO, 1.0]]
	for i in range(rng.randi_range(1, 3)):
		var a := rng.randf() * TAU
		blobs.append([Vector2(cos(a), sin(a)) * rng.randf_range(0.35, 0.7), rng.randf_range(0.45, 0.8)])
	for i in range(rng.randi_range(4, 10)):
		var a := rng.randf_range(-0.9, 0.9) if directed and rng.randf() < 0.75 else rng.randf() * TAU
		blobs.append([Vector2(cos(a), sin(a)) * rng.randf_range(1.1, 2.6), rng.randf_range(0.06, 0.26)])
	for bl in blobs:
		var c: Vector2 = bl[0]
		var r: float = bl[1]
		var seg := 14 if r > 0.4 else 6
		var ph1 := rng.randf() * TAU
		var ph2 := rng.randf() * TAU
		var rim: Array = []
		for k in range(seg):
			var a := float(k) / seg * TAU
			var lump := 1.0 + 0.22 * sin(3.0 * a + ph1) + 0.12 * sin(5.0 * a + ph2)
			rim.append(c + Vector2(cos(a), sin(a)) * r * lump * rng.randf_range(0.9, 1.08))
		var mid := Color(0.9, 0.9, 0.9)
		for k in range(seg):
			var p0: Vector2 = rim[k]
			var p1: Vector2 = rim[(k + 1) % seg]
			st.set_color(mid)
			st.add_vertex(Vector3(c.x, 0, c.y))
			st.set_color(Color.WHITE)
			st.add_vertex(Vector3(p1.x, 0, p1.y))
			st.add_vertex(Vector3(p0.x, 0, p0.y))
	for i in range(rng.randi_range(2, 5)):
		var a := rng.randf_range(-0.7, 0.7) if directed else rng.randf() * TAU
		var dv := Vector2(cos(a), sin(a))
		var side := Vector2(-dv.y, dv.x) * rng.randf_range(0.08, 0.16)
		var tip := dv * rng.randf_range(1.25, 1.75)
		st.set_color(Color.WHITE)
		for p in [dv * 0.7 + side, tip, dv * 0.7 - side]:
			st.add_vertex(Vector3(p.x, 0, p.y))
	return st.commit()


func sparkle(pos: Vector3, amount: int = 8, color: Color = Color(1.0, 0.95, 0.6)) -> void:
	_burst(pos, amount, _spark_mat, 0.22, 0.6, {
		"radius": 0.25, "spread": 180.0, "vel_min": 1.0, "vel_max": 2.8, "gravity": Vector3(0, -3.0, 0),
		"damping": 2.0, "grow": false, "color": Color(color.r, color.g, color.b, 1.0)})


## Sea spray: white droplets thrown up and falling back (bow wave, wake). A
## big one at the water (something falling in, a dive, a cannonball) leaves a
## ring of foam spreading on the swell.
func splash(pos: Vector3, amount: int = 4, size: float = 0.6) -> void:
	if flipbooks:
		plume(pos + Vector3(0, 0.8 * size, 0), Vector3.UP, "splash", maxi(amount / 3, 1), size * 3.0, 0.8, Color.WHITE, 1.0, 20.0)
	else:
		_burst(pos, amount, _dust_mat, size, 0.7, {
			"radius": 0.3, "spread": 35.0, "vel_min": 1.2, "vel_max": 2.6, "gravity": Vector3(0, -7.0, 0), "damping": 0.5,
			"color": Color(0.92, 0.97, 1.0, 0.85)})
	var oc := get_node_or_null("/root/Ocean")
	if size >= 0.7 and amount >= 5 and oc and absf(pos.y - float(oc.surface_at(pos))) < 1.2:
		water_ring(pos, size * 1.5 + amount * 0.06)


## Bubbles wobbling up through the water (a diver's breath, a gasp, a chest's lid): a few pale specks rising.
func bubbles(pos: Vector3, amount: int = 3) -> void:
	_burst(pos, amount, _spark_mat, 0.09, 1.3, {
		"radius": 0.1, "spread": 20.0, "vel_min": 0.5, "vel_max": 1.1, "gravity": Vector3(0, 1.8, 0), "damping": 0.4,
		"explosiveness": 0.6, "grow": false, "hold": true, "color": Color(0.82, 0.95, 1.0, 1.0)})


## Foam rings racing out on the water from `pos`, riding the swell as they go.
func water_ring(pos: Vector3, radius: float = 1.5, life: float = 1.1) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam and cam.global_position.distance_to(pos) > BURST_RANGE * 0.6:
		return
	var oc := get_node("/root/Ocean")
	var holder := Node3D.new()
	_scene_root().add_child(holder)
	# (high enough off the surface that a passing crest doesn't swallow half of it)
	holder.global_position = Vector3(pos.x, float(oc.surface_at(pos)) + 0.18, pos.z)
	var tw := holder.create_tween()
	for k in range(2):
		var mi := MeshInstance3D.new()
		mi.mesh = _band(0.24 if k == 0 else 0.16)
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat.albedo_color = Color(0.93, 0.97, 1.0, 0.75 if k == 0 else 0.6)
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		holder.add_child(mi)
		var r := radius * (1.0 if k == 0 else 0.55)
		var t := life * (1.0 if k == 0 else 0.8)
		mi.scale = Vector3(r * 0.15, 1.0, r * 0.15)
		tw.parallel().tween_property(mi, "scale", Vector3(r, 1.0, r), t).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		tw.parallel().tween_property(mat, "albedo_color:a", 0.0, t * 0.6).set_delay(t * 0.4)
	tw.parallel().tween_method(func(_k: float): holder.global_position.y = float(oc.surface_at(holder.global_position)) + 0.18, 0.0, 1.0, life)
	tw.tween_callback(holder.queue_free)


## Powder smoke: soft grey puffs that swell, drift up and linger.
func smoke(pos: Vector3, amount: int = 6, size: float = 0.8, life: float = 1.6, color: Color = Color(0.72, 0.72, 0.7, 0.75)) -> void:
	if flipbooks:
		puff(pos, "smoke", maxi(amount / 2, 2), size * 1.5, life, color, 0.8)
		return
	_burst(pos, amount, _dust_mat, size, life, {
		"radius": 0.15, "spread": 70.0, "vel_min": 0.2, "vel_max": 0.8, "gravity": Vector3(0, 0.45, 0),
		"damping": 1.2, "explosiveness": 0.9, "color": color})


## Gunshot sparks: a hot spray out of the muzzle along `dir`.
func muzzle_sparks(pos: Vector3, dir: Vector3, amount: int = 10, color: Color = Color(1.0, 0.75, 0.35)) -> void:
	flash_light(pos + dir.normalized() * 0.3, Color(1.0, 0.72, 0.4), 1.2 + amount * 0.08, 3.0 + amount * 0.12, 0.08 + amount * 0.004)
	_burst(pos, amount, _spark_mat, 0.16, 0.3, {
		"radius": 0.04, "direction": dir, "spread": 16.0, "vel_min": 5.0, "vel_max": 10.0,
		"gravity": Vector3(0, -4.0, 0), "damping": 6.0, "grow": false, "color": color})


## Hit impact: a flash plus a spray of sparks.
func impact(pos: Vector3, color: Color = Color(1.0, 0.9, 0.55)) -> void:
	if flipbooks:
		flash(pos, 1.7, Color.WHITE, "glint", 0.14)
	else:
		_burst(pos, 1, _impact_mat, 0.9, 0.12, {"radius": 0.01, "vel_min": 0.0, "vel_max": 0.0, "gravity": Vector3.ZERO,
			"grow": true, "color": Color(1, 1, 1, 1)})
	_burst(pos, 10, _spark_mat, 0.18, 0.4, {"radius": 0.1, "spread": 180.0, "vel_min": 3.0, "vel_max": 6.0,
		"gravity": Vector3(0, -9.0, 0), "damping": 4.0, "grow": false, "color": color})


## Parry: a white flash where the blades meet, a hot spray of sparks thrown
## back toward the attacker (`dir`) and a few slow glints hanging in the air.
func parry_sparks(pos: Vector3, dir: Vector3) -> void:
	if flipbooks:
		flash(pos, 2.2, Color.WHITE, "glint", 0.12)
	else:
		_burst(pos, 1, _impact_mat, 1.25, 0.1, {"radius": 0.01, "vel_min": 0.0, "vel_max": 0.0, "gravity": Vector3.ZERO,
			"grow": true, "color": Color(1, 1, 1, 1)})
	var d := dir.normalized() if dir.length() > 0.01 else Vector3.FORWARD
	_burst(pos, 22, _spark_mat, 0.13, 0.42, {"radius": 0.05, "direction": (d + Vector3(0, 0.35, 0)).normalized(),
		"spread": 55.0, "vel_min": 4.5, "vel_max": 9.0, "gravity": Vector3(0, -12.0, 0), "damping": 3.0,
		"grow": false, "color": Color(1.0, 0.82, 0.4)})
	_burst(pos, 10, _spark_mat, 0.1, 0.3, {"radius": 0.05, "spread": 180.0, "vel_min": 2.0, "vel_max": 5.0,
		"gravity": Vector3(0, -9.0, 0), "damping": 4.0, "grow": false, "color": Color(1.0, 0.97, 0.85)})
	sparkle(pos, 5, Color(1.0, 1.0, 0.85))


## Floating combat text (XP, status) that rises and fades.
func float_text(pos: Vector3, text: String, color: Color = Color.WHITE, size: int = 28) -> void:
	var l := Label3D.new()
	l.text = text
	l.font = load("res://assets/fonts/Silkscreen-Regular.woff2")
	l.font_size = size
	l.outline_size = 8
	l.modulate = color
	l.outline_modulate = Color(0, 0, 0, 0.9)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.pixel_size = 0.006
	l.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_scene_root().add_child(l)
	l.global_position = pos
	var tw := l.create_tween()
	tw.tween_property(l, "global_position", pos + Vector3(0, 1.2, 0), 1.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.6).set_delay(0.7)
	tw.tween_callback(l.queue_free)


## A fading ghost of a character's silhouette left behind (Soru, Foresight,
## Logia dodge): a few tinted additive copies of the body's meshes.
func afterimage(body: Node3D, color: Color = Color(0.6, 0.8, 1.0), life: float = 0.35) -> void:
	if body == null:
		return
	var holder := Node3D.new()
	_scene_root().add_child(holder)
	holder.global_transform = Transform3D.IDENTITY
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = Color(color.r, color.g, color.b, 0.45)
	mat.no_depth_test = false
	var n := 0
	for mi in body.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null or not m.is_visible_in_tree():
			continue
		var c := MeshInstance3D.new()
		c.mesh = m.mesh
		c.material_override = mat
		c.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		holder.add_child(c)
		c.global_transform = m.global_transform
		n += 1
		if n > 40:
			break
	var tw := holder.create_tween()
	tw.tween_property(mat, "albedo_color:a", 0.0, life)
	tw.tween_callback(holder.queue_free)


## Afterimage (Acrobatics): a copy of `body` left standing for `secs` that the foes after its captain swing at
## (Decoy; the host does the luring), with a pale flash where it appears.
func decoy(body: Node3D, secs: float) -> void:
	if body == null:
		return
	Decoy.spawn(_scene_root(), body, secs)
	afterimage(body, Decoy.COLOR, 0.2)
	sfx("whoosh_big", body.global_position, -9.0, 0.05, 1.7)


## Disarm (Defense): a weapon (its `mesh`, from `xf`) knocked spinning out of a hand at `vel`, falling to the ground
## FLUNG_DROP m below the hand, lying there a few seconds, then gone. A glint and a clang where it leaves the hand.
const FLUNG_DROP := 1.15
const FLUNG_LIE := 4.0


func flung_weapon(mesh: Mesh, xf: Transform3D, vel: Vector3) -> void:
	var cam := get_viewport().get_camera_3d()
	if mesh == null or (cam and cam.global_position.distance_to(xf.origin) > BURST_RANGE):
		return
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visibility_range_end = 60.0
	_scene_root().add_child(mi)
	mi.global_transform = xf
	var g := 18.0
	var from := xf.origin
	var floor_y := from.y - FLUNG_DROP
	# time to come down to the floor: from + vel.y t - g t^2 / 2 = floor_y
	var t_land := (vel.y + sqrt(vel.y * vel.y + 2.0 * g * FLUNG_DROP)) / g
	var spin := Vector3(randf_range(-1, 1), 1.0, randf_range(-1, 1)).normalized()
	var b0 := xf.basis
	var tw := mi.create_tween()
	tw.tween_method(func(t: float) -> void:
		if not is_instance_valid(mi):
			return
		var p := from + vel * t + Vector3.DOWN * 0.5 * g * t * t
		p.y = maxf(p.y, floor_y)
		mi.global_transform = Transform3D(b0.rotated(spin, 18.0 * t), p), 0.0, t_land, t_land)
	tw.tween_callback(func() -> void:
		if not is_instance_valid(mi):
			return
		# (the blade runs along -Z: lying flat on the ground, pointing the way it flew)
		mi.global_transform = Transform3D(Basis(Vector3.UP, atan2(-vel.x, -vel.z)), Vector3(mi.global_position.x, floor_y + 0.03, mi.global_position.z))
		sfx("clash", mi.global_position, -10.0, 0.08, 0.7)
		dust(mi.global_position + Vector3(0, 0.05, 0), 4, 0.4))
	tw.tween_interval(FLUNG_LIE)
	tw.tween_callback(mi.queue_free)
	glint(xf.origin, Color(1.0, 0.95, 0.8), 0.9)
	sfx("clash", xf.origin, -4.0, 0.06, 1.25)


## A foe's blow landed on the decoy near `at`: it shatters.
func decoy_break(at: Vector3) -> void:
	var d := Decoy.near(get_tree(), at, 2.0)
	if d:
		d.shatter()


## Vines wrapped round a rooted enemy's legs for `secs` (Vine Snare).
func vine_wrap(target: Node3D, secs: float, radius: float = 0.35) -> void:
	if target == null or not is_instance_valid(target):
		return
	var old := target.get_node_or_null("VineWrap")
	if old:
		old.queue_free()
	var holder := Node3D.new()
	holder.name = "VineWrap"
	target.add_child(holder)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.28, 0.58, 0.2)
	var leaf := StandardMaterial3D.new()
	leaf.albedo_color = Color(0.4, 0.75, 0.25)
	leaf.cull_mode = BaseMaterial3D.CULL_DISABLED
	for i in range(4):
		var ring := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = radius * (0.8 + 0.08 * i)
		tm.outer_radius = tm.inner_radius + 0.06
		tm.rings = 10
		tm.ring_segments = 4
		ring.mesh = tm
		ring.material_override = mat
		ring.position = Vector3(0, 0.15 + i * 0.22, 0)
		ring.rotation = Vector3(randf_range(-0.3, 0.3), randf() * TAU, randf_range(-0.3, 0.3))
		holder.add_child(ring)
		var lf := MeshInstance3D.new()
		var qm := QuadMesh.new()
		qm.size = Vector2(0.14, 0.09)
		lf.mesh = qm
		lf.material_override = leaf
		lf.position = Vector3(cos(i * 1.7) * radius, 0.2 + i * 0.22, sin(i * 1.7) * radius)
		lf.rotation = Vector3(0.4, i * 1.7, 0)
		holder.add_child(lf)
	holder.scale = Vector3(1, 0.1, 1)
	var tw := holder.create_tween()
	tw.tween_property(holder, "scale", Vector3.ONE, 0.2)
	tw.tween_interval(maxf(secs - 0.4, 0.05))
	tw.tween_property(holder, "scale", Vector3(1, 0.05, 1), 0.2)
	tw.tween_callback(holder.queue_free)


## A punch or kick's rush of air: a few straight speed lines shooting along
## `dir` from `from`, and a ring of displaced air bursting at the end. Linear
## and quick (bare-handed hits), unlike the sweeping blade trails.
func punch_wind(from: Vector3, dir: Vector3, length: float = 1.3, color: Color = Color(1.0, 0.97, 0.9), big: bool = false) -> void:
	if dir.length() < 0.01:
		return
	dir = dir.normalized()
	var holder := Node3D.new()
	holder.name = "PunchWind"
	_scene_root().add_child(holder)
	var up := Vector3.UP if absf(dir.y) < 0.95 else Vector3.FORWARD
	holder.global_transform = Transform3D(Basis.looking_at(dir, up), from)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = Color(color.r, color.g, color.b, 0.75)
	var box := BoxMesh.new()
	box.size = Vector3.ONE
	var n := 5 if big else 3
	var thick := 0.03 if big else 0.02
	var rad := 0.13 if big else 0.08
	var dur := 0.09 if big else 0.07
	for i in range(n):
		var mi := MeshInstance3D.new()
		mi.mesh = box
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		holder.add_child(mi)
		var a := TAU * float(i) / float(n) + randf() * 0.6
		var r := rad * randf_range(0.5, 1.1)
		var off := Vector3(cos(a) * r, sin(a) * r, 0.0)
		var ln := length * randf_range(0.55, 0.85)
		mi.position = off
		mi.scale = Vector3(thick, thick, 0.05)
		var tw := mi.create_tween().set_parallel(true)
		tw.tween_property(mi, "position", off + Vector3(0, 0, -length * 0.55), dur).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		tw.tween_property(mi, "scale", Vector3(thick, thick, ln), dur).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		tw.chain().tween_property(mi, "position", off + Vector3(0, 0, -length * 0.85), 0.1)
		tw.parallel().tween_property(mi, "scale", Vector3(thick * 0.5, thick * 0.5, ln * 0.4), 0.1)
	# the air ring where the blow lands
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.09
	tm.outer_radius = 0.12
	tm.rings = 14
	tm.ring_segments = 3
	ring.mesh = tm
	ring.material_override = mat
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.rotation = Vector3(PI * 0.5, 0, 0)
	ring.position = Vector3(0, 0, -length)
	ring.scale = Vector3.ONE * 0.3
	holder.add_child(ring)
	var end_scale := 2.6 if big else 1.8
	var tw2 := holder.create_tween()
	tw2.tween_interval(dur * 0.6)
	tw2.tween_property(ring, "scale", Vector3(end_scale, 1.0, end_scale), 0.16).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw2.parallel().tween_property(mat, "albedo_color:a", 0.0, 0.2).set_delay(0.04)
	tw2.tween_callback(holder.queue_free)


## Vines coiling round a character's arm(s) (Vine Fruit powers): rings up
## the forearm and upper arm with a few leaves, growing in quickly. sides:
## "r", "l" or "both". secs > 0: they wither on their own after that long;
## otherwise call wither_vines() with the returned holders.
func arm_vines(h: Humanoid, sides: String = "r", secs: float = -1.0) -> Array:
	var limbs: Array = []
	if h == null or not is_instance_valid(h):
		return limbs
	if sides in ["r", "both"]:
		limbs.append_array([[h.arm_r, absf(h.fore_r.position.y), 0.062], [h.fore_r, absf(h.hand_r.position.y), 0.052]])
	if sides in ["l", "both"]:
		limbs.append_array([[h.arm_l, absf(h.fore_l.position.y), 0.062], [h.fore_l, absf(h.hand_l.position.y), 0.052]])
	return limb_vines(limbs, secs)


## Vines round both legs too (the lingering look after a Vine power).
func leg_vines(h: Humanoid, secs: float) -> Array:
	if h == null or not is_instance_valid(h):
		return []
	var thigh := absf(h.shin_l.position.y)
	return limb_vines([[h.leg_l, thigh, 0.078], [h.shin_l, thigh * 0.95, 0.064],
		[h.leg_r, thigh, 0.078], [h.shin_r, thigh * 0.95, 0.064]], secs)


## limbs: [[bone, length, radius], ...] - rings down each bone from its joint.
func limb_vines(limbs: Array, secs: float = -1.0) -> Array:
	var out: Array = []
	var stem := StandardMaterial3D.new()
	stem.albedo_color = Color(0.25, 0.55, 0.16)
	var leaf := StandardMaterial3D.new()
	leaf.albedo_color = Color(0.42, 0.8, 0.26)
	leaf.cull_mode = BaseMaterial3D.CULL_DISABLED
	var li := 0
	for e in limbs:
		var bone: Node3D = e[0]
		if bone == null or not is_instance_valid(bone):
			continue
		var length: float = maxf(float(e[1]), 0.1)
		var r: float = e[2]
		li += 1
		var holder := Node3D.new()
		holder.name = "ArmVines"
		bone.add_child(holder, true)
		var n := 3 if length < 0.32 else 4
		for i in range(n):
			var ring := MeshInstance3D.new()
			var tm := TorusMesh.new()
			tm.inner_radius = r
			tm.outer_radius = r + 0.022
			tm.rings = 8
			tm.ring_segments = 3
			ring.mesh = tm
			ring.material_override = stem
			ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			ring.position = Vector3(0, -length * (0.15 + 0.75 * float(i) / float(maxi(n - 1, 1))), 0)
			ring.rotation = Vector3(0.45 if i % 2 == 0 else -0.45, float(i) * 1.3, 0.2)
			holder.add_child(ring)
		for i in range(2):
			var lf := MeshInstance3D.new()
			var qm := QuadMesh.new()
			qm.size = Vector2(0.12, 0.07)
			lf.mesh = qm
			lf.material_override = leaf
			lf.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var a := float(i) * PI + 0.7 * li
			lf.position = Vector3(cos(a) * (r + 0.02), -length * (0.3 + 0.4 * i), sin(a) * (r + 0.02))
			lf.rotation = Vector3(0.6, a, 0.3)
			holder.add_child(lf)
		holder.scale = Vector3(0.2, 0.05, 0.2)
		var tw := holder.create_tween()
		tw.tween_property(holder, "scale", Vector3.ONE, 0.14).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		if secs > 0.0:
			tw.tween_interval(secs)
			tw.tween_property(holder, "scale", Vector3(0.3, 0.05, 0.3), 0.25)
			tw.tween_callback(holder.queue_free)
		out.append(holder)
	return out


func wither_vines(holders: Array) -> void:
	for hd in holders:
		if hd == null or not is_instance_valid(hd):
			continue
		var holder := hd as Node3D
		var tw := holder.create_tween()
		tw.tween_property(holder, "scale", Vector3(0.3, 0.05, 0.3), 0.18)
		tw.tween_callback(holder.queue_free)


## A small pixel leaf (made once, in code).
var _leaf_mat_cache: StandardMaterial3D
func _leaf_mat() -> StandardMaterial3D:
	if _leaf_mat_cache:
		return _leaf_mat_cache
	var img := Image.create(12, 12, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in range(12):
		for x in range(12):
			# an ellipse along the diagonal
			var u := (x + y - 11.0) / 11.0
			var v := (x - y) / 5.0
			if u * u + v * v <= 1.0:
				var c := Color(0.36, 0.72, 0.22) if v > 0.0 else Color(0.28, 0.6, 0.18)
				if absf(x - y) < 0.6:
					c = Color(0.55, 0.85, 0.35)
				img.set_pixel(x, y, c)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_texture = ImageTexture.create_from_image(img)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.vertex_color_use_as_albedo = true
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.4
	_leaf_mat_cache = m
	return m


## A loose particle cloud riding with `parent` (world-space particles, so
## they trail behind as you move). Stops after `secs` and cleans itself up.
func _aura_emitter(parent: Node3D, mat: Material, cfg: Dictionary, secs: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = int(cfg.get("amount", 12))
	p.lifetime = float(cfg.get("life", 1.2))
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = cfg.get("box", Vector3(0.3, 0.55, 0.3))
	p.direction = cfg.get("direction", Vector3.UP)
	p.spread = float(cfg.get("spread", 180.0))
	p.gravity = cfg.get("gravity", Vector3(0, -0.6, 0))
	p.initial_velocity_min = float(cfg.get("vel_min", 0.2))
	p.initial_velocity_max = float(cfg.get("vel_max", 0.8))
	p.angle_min = 0.0
	p.angle_max = 360.0
	p.angular_velocity_min = -180.0
	p.angular_velocity_max = 180.0
	p.damping_min = 0.6
	p.damping_max = 1.2
	p.scale_amount_min = 0.7
	p.scale_amount_max = 1.3
	var grad := Gradient.new()
	var col: Color = cfg.get("color", Color.WHITE)
	grad.offsets = PackedFloat32Array([0.0, 0.15, 0.7, 1.0])
	grad.colors = PackedColorArray([Color(col.r, col.g, col.b, 0.0), col, col, Color(col.r, col.g, col.b, 0.0)])
	p.color_ramp = cfg.get("ramp", grad)
	var quad := QuadMesh.new()
	var sz: float = cfg.get("size", 0.1)
	quad.size = Vector2(sz, sz)
	quad.material = mat
	p.mesh = quad
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(p)
	p.position = cfg.get("offset", Vector3.ZERO)
	p.emitting = true
	var tw := p.create_tween()
	tw.tween_interval(secs)
	tw.tween_callback(func(): p.emitting = false)
	tw.tween_interval(p.lifetime + 0.1)
	tw.tween_callback(p.queue_free)
	return p


## The afterglow of a Devil Fruit power on whoever used it, for `secs`:
## Vine - vines stay coiled round all four limbs and leaves drift off you;
## Ember - the hands keep smouldering and embers rise off you;
## Wolf - dark wisps and amber motes. A new cast refreshes it.
func power_aura(h: Humanoid, fruit: String, secs: float = 2.5) -> void:
	if h == null or not is_instance_valid(h) or not h.is_inside_tree():
		return
	var old := h.get_node_or_null("PowerAura")
	if old:
		old.name = "PowerAuraOld"
		for c in old.get_children():
			if c is CPUParticles3D:
				(c as CPUParticles3D).emitting = false
		old.get_tree().create_timer(1.5).timeout.connect(old.queue_free)
	var holder := Node3D.new()
	holder.name = "PowerAura"
	h.add_child(holder)
	holder.position = Vector3(0, 1.0, 0)
	match fruit:
		"vine":
			var vines := h.get_meta("aura_vines", []) as Array
			wither_vines(vines)
			vines = arm_vines(h, "both", secs) + leg_vines(h, secs)
			h.set_meta("aura_vines", vines)
			_aura_emitter(holder, _leaf_mat(), {"amount": 14, "life": 1.6, "size": 0.11, "gravity": Vector3(0, -0.7, 0),
				"vel_min": 0.2, "vel_max": 0.7, "color": Color(1, 1, 1, 1)}, secs)
		"ember":
			for hand in [h.hand_l, h.hand_r]:
				var fe := flame_emitter(hand, 0.06, 8, 0.2, 0.35)
				var tw := fe.create_tween()
				tw.tween_interval(secs)
				tw.tween_callback(func(): fe.emitting = false)
				tw.tween_interval(0.5)
				tw.tween_callback(fe.queue_free)
			_aura_emitter(holder, _spark_mat, {"amount": 16, "life": 1.0, "size": 0.09, "gravity": Vector3(0, 1.4, 0),
				"direction": Vector3.UP, "spread": 40.0, "vel_min": 0.3, "vel_max": 1.0, "color": Color(1.0, 0.55, 0.15, 1.0)}, secs)
		"wolf":
			_aura_emitter(holder, _dust_mat, {"amount": 10, "life": 1.1, "size": 0.32, "gravity": Vector3(0, 0.5, 0),
				"vel_min": 0.1, "vel_max": 0.4, "color": Color(0.18, 0.15, 0.16, 0.55)}, secs)
			_aura_emitter(holder, _spark_mat, {"amount": 10, "life": 0.8, "size": 0.07, "gravity": Vector3(0, 0.6, 0),
				"vel_min": 0.2, "vel_max": 0.6, "color": Color(1.0, 0.75, 0.25, 1.0)}, secs)
	holder.create_tween().tween_callback(holder.queue_free).set_delay(secs + 2.0)


## Vine Fruit: little vines that sprout along the ground where you dash and
## wither away again.
func ground_vines(pos: Vector3, dir: Vector3) -> void:
	var holder := Node3D.new()
	holder.name = "GroundVines"
	_scene_root().add_child(holder)
	var fwd := Vector3(dir.x, 0, dir.z).normalized() if Vector3(dir.x, 0, dir.z).length() > 0.01 else Vector3.FORWARD
	holder.global_transform = Transform3D(Basis.looking_at(fwd, Vector3.UP), pos + Vector3.UP * 0.02)
	var stem := StandardMaterial3D.new()
	stem.albedo_color = Color(0.24, 0.5, 0.15)
	var bm := BoxMesh.new()
	bm.size = Vector3(0.035, 0.03, 1.0)
	# a wandering stem of a few segments with curls off to the sides
	var p := Vector3(randf_range(-0.15, 0.15), 0, 0.2)
	var a := randf_range(-0.6, 0.6)
	for i in range(4):
		var seg := MeshInstance3D.new()
		seg.mesh = bm
		seg.material_override = stem
		seg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var l := randf_range(0.22, 0.35)
		var d := Vector3(sin(a), 0, -cos(a))
		seg.position = p + d * l * 0.5
		seg.rotation = Vector3(0, -a, 0)
		seg.scale = Vector3(1, 1, l)
		holder.add_child(seg)
		p += d * l
		a += randf_range(-0.9, 0.9)
		if randf() < 0.7:
			var lf := MeshInstance3D.new()
			var qm := QuadMesh.new()
			qm.size = Vector2(0.1, 0.06)
			lf.mesh = qm
			lf.material_override = _leaf_flat()
			lf.position = p + Vector3(0, 0.015, 0)
			lf.rotation = Vector3(-PI * 0.5, randf() * TAU, 0)
			holder.add_child(lf)
	holder.scale = Vector3(0.01, 1, 0.01)
	var tw := holder.create_tween()
	tw.tween_property(holder, "scale", Vector3.ONE, 0.18).set_ease(Tween.EASE_OUT)
	tw.tween_interval(1.4)
	tw.tween_property(holder, "scale", Vector3(0.6, 0.2, 0.6), 0.5)
	tw.tween_callback(holder.queue_free)


var _leaf_flat_mat: StandardMaterial3D
func _leaf_flat() -> StandardMaterial3D:
	if _leaf_flat_mat == null:
		_leaf_flat_mat = StandardMaterial3D.new()
		_leaf_flat_mat.albedo_color = Color(0.4, 0.75, 0.25)
		_leaf_flat_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return _leaf_flat_mat


## A pistol shot's streak: a thin bright line that fades fast.
func tracer(from: Vector3, to: Vector3, color: Color = Color(1.0, 0.9, 0.6)) -> void:
	var seg := to - from
	var l := seg.length()
	if l < 0.05:
		return
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(1, 1, 1)
	mi.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = Color(color.r, color.g, color.b, 0.8)
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_scene_root().add_child(mi)
	mi.global_transform = Transform3D(Basis.looking_at(seg / l, Vector3.UP).scaled_local(Vector3(0.025, 0.025, l)), from + seg * 0.5)
	var tw := mi.create_tween()
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.12)
	tw.tween_callback(mi.queue_free)


# --------------------------------------------------------------------------
# Fire (Ember Fruit)
# --------------------------------------------------------------------------
## A gout of flame: hot puffs that rise, swell and burn out yellow -> red.
func flame(pos: Vector3, amount: int = 10, size: float = 0.6, life: float = 0.55, radius: float = 0.25) -> void:
	flash_light(pos + Vector3(0, 0.3, 0), FIRE_LIGHT, 1.2 + size * 1.5, 2.5 + size * 3.0 + radius * 2.0, minf(life * 0.5, 0.3))
	if flipbooks:
		flipbook(pos, "fire", maxi(amount / 3, 2), size * 2.4, life, {"radius": radius, "spread": 30.0, "vel_min": 1.0,
			"vel_max": 2.4, "gravity": Vector3(0, 2.5, 0), "damping": 2.0, "explosiveness": 0.85, "start": 0.1, "spin": 15.0, "fade": 0.75})
		return
	_burst(pos, amount, _flame_mat, size, life, {"radius": radius, "spread": 35.0, "vel_min": 1.0, "vel_max": 2.6,
		"gravity": Vector3(0, 2.5, 0), "damping": 2.0, "explosiveness": 0.85, "ramp": _flame_ramp})


## A ring of fire racing outward along the ground (fire ring, inferno).
func fire_ring(pos: Vector3, radius: float = 4.0, amount: int = 40) -> void:
	var speed := radius / 0.35
	flash_light(pos + Vector3(0, 0.6, 0), FIRE_LIGHT, 5.0, radius * 1.8, 0.45)
	if flipbooks:
		flipbook(pos + Vector3(0, 0.3, 0), "fireball", maxi(amount / 4, 8), 1.3, 0.5, {"ring_radius": 0.4, "spread": 8.0,
			"direction": Vector3(0, 0.15, 0), "vel_min": speed * 0.85, "vel_max": speed, "gravity": Vector3(0, 3.0, 0),
			"damping": speed * 1.6, "start": 0.1, "spin": 180.0, "fade": 0.6})
	else:
		_burst(pos + Vector3(0, 0.25, 0), amount, _flame_mat, 0.9, 0.5, {"ring_radius": 0.4, "spread": 8.0,
			"direction": Vector3(0, 0.15, 0), "vel_min": speed * 0.85, "vel_max": speed, "radial": 0.0,
			"gravity": Vector3(0, 3.0, 0), "damping": speed * 1.6, "ramp": _flame_ramp})
	flame(pos + Vector3(0, 0.3, 0), 14, 1.0, 0.6, 0.6)


## The ultimate: a column of fire and a rolling wave of flame along the ground.
func fire_pillar(pos: Vector3, radius: float = 7.0) -> void:
	flash_light(pos + Vector3(0, 1.2, 0), FIRE_LIGHT, 8.0, radius * 2.2, 0.6)
	if flipbooks:
		plume(pos, Vector3.UP, "fireball", 10, 2.4, 1.1, Color.WHITE, 11.0, 12.0)
	else:
		_burst(pos, 36, _flame_mat, 1.6, 1.1, {"radius": 0.8, "spread": 12.0, "vel_min": 6.0, "vel_max": 13.0,
			"gravity": Vector3(0, -2.0, 0), "damping": 3.0, "explosiveness": 0.9, "ramp": _flame_ramp})
	fire_ring(pos, radius, 70)
	impact(pos + Vector3(0, 1.0, 0), Color(1.0, 0.7, 0.3))
	smoke(pos + Vector3(0, 1.5, 0), 10, 1.8, 2.6)


## A flame emitter that keeps burning until freed (fire zones, burning
## enemies, the fireball's trail). world: particles stay where they were
## emitted (trails); otherwise they ride with the parent.
func flame_emitter(parent: Node3D, radius: float = 0.3, amount: int = 16, size: float = 0.5, life: float = 0.6, world: bool = false) -> CPUParticles3D:
	if flipbooks:
		return lick(parent, radius, maxi(amount / 2, 3), size * 1.6, life * 1.15, world)
	var p := CPUParticles3D.new()
	p.amount = amount
	p.lifetime = life
	p.local_coords = not world
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = radius
	p.direction = Vector3.UP
	p.spread = 25.0
	p.gravity = Vector3(0, 2.2, 0)
	p.initial_velocity_min = 0.3
	p.initial_velocity_max = 1.2
	p.damping_min = 1.0
	p.damping_max = 1.0
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.2
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.7))
	curve.add_point(Vector2(0.4, 1.0))
	curve.add_point(Vector2(1, 0.2))
	p.scale_amount_curve = curve
	p.color_ramp = _flame_ramp
	var quad := QuadMesh.new()
	quad.size = Vector2(size, size)
	quad.material = _flame_mat
	p.mesh = quad
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(p)
	p.emitting = true
	return p


# --------------------------------------------------------------------------
# Ability effects (the driftwake-fx skill: palettes, layering, budgets)
# --------------------------------------------------------------------------
## Each tree's colours: [core (the hot centre), edge (its own colour), accent].
const TREE_FX := {
	"sword": [Color(0.92, 0.98, 1.0), Color(0.3, 0.72, 1.0), Color(0.78, 0.95, 1.0)],
	"katana": [Color(1.0, 1.0, 1.0), Color(0.78, 0.86, 1.0), Color(1.0, 0.62, 0.8)],
	"axe": [Color(1.0, 0.9, 0.6), Color(1.0, 0.5, 0.15), Color(1.0, 0.32, 0.08)],
	"dual": [Color(0.95, 0.98, 1.0), Color(0.35, 0.9, 0.95), Color(0.75, 0.45, 1.0)],
	"pistol": [Color(1.0, 0.95, 0.75), Color(1.0, 0.75, 0.25), Color(0.7, 0.7, 0.68)],
	# sword + pistol: black powder - scarlet flash, gold sparks (dark smoke with them)
	"corsair": [Color(1.0, 0.95, 0.82), Color(1.0, 0.34, 0.26), Color(1.0, 0.8, 0.34)],
	# one dagger: crimson night - a crimson edge, wine-dark shadow (and black wisps with it)
	"dagger": [Color(1.0, 0.92, 0.95), Color(0.95, 0.15, 0.38), Color(0.55, 0.12, 0.45)],
	# two daggers: venom - viper green, a sickly yellow-green, poison bubbling off the wounds
	"dual_dagger": [Color(0.95, 1.0, 0.9), Color(0.45, 0.95, 0.3), Color(0.82, 1.0, 0.35)],
	# polearm: storm - lemon-white lightning with a violet afterglow, a thunderclap on the big blows
	"polearm": [Color(1.0, 1.0, 0.9), Color(1.0, 0.9, 0.32), Color(0.62, 0.48, 1.0)],
	# hammer: earth - sandstone shockwaves, rock thrown up, the ground cracking and stone spikes heaving up
	"hammer": [Color(1.0, 0.95, 0.82), Color(0.92, 0.8, 0.58), Color(0.55, 0.46, 0.36)],
	# twin axes: frost - white rime, pale ice-blue edges, a deep glacier blue; ice chips, a cold mist, ice heaving up
	"dual_axe": [Color(0.96, 1.0, 1.0), Color(0.68, 0.9, 1.0), Color(0.36, 0.55, 1.0)],
	# greatsword: gale - white air pressure, a pale jade edge, a deep sea-green; gusts torn off every swing, crescents of
	# wind flung off the big ones, a cyclone round the ultimate
	"greatsword": [Color(1.0, 1.0, 1.0), Color(0.74, 1.0, 0.88), Color(0.28, 0.8, 0.62)],
	# black-leg: heat - a white-hot core, cherry-red edge, a deep crimson (not the axe's ember orange): the kicking leg
	# glowing red-hot, crimson flames bursting off the big kicks
	"black_leg": [Color(1.0, 0.95, 0.82), Color(1.0, 0.17, 0.16), Color(0.7, 0.04, 0.1)],
	"unarmed": [Color(1.0, 1.0, 1.0), Color(1.0, 0.95, 0.85), Color(0.95, 0.75, 0.45)],
	"haki": [Color(1.0, 0.85, 0.85), Color(0.9, 0.12, 0.18), Color(0.1, 0.02, 0.04)],
	# a weapon whose element isn't awakened yet (its tree's mastery passive): steel and dust
	"plain": [Color(1.0, 1.0, 1.0), Color(0.88, 0.9, 0.95), Color(0.8, 0.76, 0.68)],
}
const CORE := 0
const EDGE := 1
const ACCENT := 2
## Two-weapon trees: the off hand's blade trails in the accent colour.
const TWIN_TREES := ["dual", "dual_dagger", "dual_axe"]
## The dagger's shadow (dark wisps: alpha-blended, so they read against light ground).
const SHADOW_SMOKE := Color(0.1, 0.03, 0.09, 0.85)

static var _bands: Dictionary = {}


static func tree_col(tree: String, which: int = EDGE) -> Color:
	return (TREE_FX[tree] as Array)[which]


## An additive glow material of its own (so its fade doesn't touch anyone else's).
func _glow_mat(color: Color, alpha: float = 0.85) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = Color(color.r, color.g, color.b, alpha)
	return m


func _band(width: float) -> ArrayMesh:
	var key := snappedf(width, 0.01)
	if not _bands.has(key):
		_bands[key] = _annulus(1.0 - width, 1.0)
	return _bands[key]


## A ring racing out from `pos` and fading, flat to `normal` (UP: along the
## ground; a direction: a ring of air round a thrust or a punch).
func ring(pos: Vector3, normal: Vector3 = Vector3.UP, radius: float = 3.0, color: Color = Color.WHITE, life: float = 0.35, width: float = 0.12) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam and cam.global_position.distance_to(pos) > BURST_RANGE:
		return
	var mi := MeshInstance3D.new()
	mi.mesh = _band(width)
	var mat := _glow_mat(color)
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var holder := Node3D.new()
	_scene_root().add_child(holder)
	var n := normal.normalized()
	var side := Vector3.RIGHT if absf(n.dot(Vector3.RIGHT)) < 0.9 else Vector3.FORWARD
	var x := n.cross(side).normalized()
	holder.global_transform = Transform3D(Basis(x, n, x.cross(n)), pos + (Vector3(0, 0.08, 0) if n.y > 0.9 else Vector3.ZERO))
	holder.add_child(mi)
	mi.scale = Vector3(radius * 0.12, 1.0, radius * 0.12)
	var tw := holder.create_tween()
	tw.tween_property(mi, "scale", Vector3(radius, 1.0, radius), life).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.parallel().tween_property(mat, "albedo_color:a", 0.0, life * 0.7).set_delay(life * 0.3)
	tw.tween_callback(holder.queue_free)


## Sea spray thrown along `dir`: droplets in an arc that fall back, and a mist.
func spray(pos: Vector3, dir: Vector3, amount: int = 12, color: Color = Color(0.85, 0.95, 1.0), speed: float = 6.0) -> void:
	_burst(pos, amount, _dust_mat, 0.16, 0.6, {"radius": 0.12, "direction": dir.normalized(), "spread": 30.0,
		"vel_min": speed * 0.55, "vel_max": speed, "gravity": Vector3(0, -12.0, 0), "damping": 0.8, "grow": false,
		"hold": true, "color": Color(color.r, color.g, color.b, 0.95)})
	if flipbooks:
		puff(pos, "mist", maxi(amount / 4, 1), 0.9, 0.55, Color(color.r, color.g, color.b, 0.6), speed * 0.2, dir)
	else:
		_burst(pos, maxi(amount / 3, 2), _dust_mat, 0.55, 0.55, {"radius": 0.2, "direction": dir.normalized(), "spread": 40.0,
			"vel_min": 0.6, "vel_max": 1.6, "gravity": Vector3(0, 0.3, 0), "damping": 2.0, "color": Color(color.r, color.g, color.b, 0.45)})


## Petals thrown along `dir` that tumble and drift down slowly (the katana's
## element, as spray is the cutlass's).
func petals(pos: Vector3, dir: Vector3, amount: int = 10, color: Color = Color(1.0, 0.62, 0.8), speed: float = 4.0) -> void:
	var p := _burst(pos, amount, _petal_mat, 0.14, 1.6, {"radius": 0.3, "direction": dir.normalized(), "spread": 50.0,
		"vel_min": speed * 0.35, "vel_max": speed, "gravity": Vector3(0, -1.3, 0), "damping": 2.4, "hold": true,
		"scale_min": 0.6, "scale_max": 1.15, "explosiveness": 0.85, "color": Color(color.r, color.g, color.b, 1.0)})
	if p:
		p.angle_max = 360.0
		p.angular_velocity_min = -420.0
		p.angular_velocity_max = 420.0


## The weapon trees whose element is drawn by gen_drawn_fx.py: tree -> its sheets' name (flip_<name>_slash,
## flip_<name>_cloud, <name>_trail).
const DRAWN := {"dagger": "shadow", "dual": "twin", "dual_dagger": "venom", "corsair": "powder", "pistol": "gold", "unarmed": "gale"}


## A tree's element thrown along `dir`: sea spray (cutlass), drawn sakura (katana: bigger, so
## fewer), drawn cinders and a lick of fire (axe: cinders are bigger, so fewer), rock and dust (hammer).
func element(tree: String, pos: Vector3, dir: Vector3, amount: int = 10, speed: float = 4.0) -> void:
	var c := tree_col(tree, ACCENT)
	# (the drawn elements: a burst of the element on the bigger throws, under the tree's own material)
	if flipbooks and amount >= 8 and DRAWN.has(tree):
		drawn_burst(pos, DRAWN[tree] + "_cloud", 0.5 + amount * 0.05, 0.45, 40.0)
	match tree:
		"katana":
			sakura(pos, dir, maxi(amount * 2 / 3, 2), speed)
		"axe":
			if not flipbooks:
				embers(pos, dir, amount, c, speed)
				return
			cinders(pos, dir, maxi(amount * 2 / 3, 2), speed)
			if amount >= 8:
				drawn_burst(pos, "ember_cloud", 0.5 + amount * 0.05, 0.45, 40.0)
		"dual":
			motes(pos, dir, maxi(amount / 2, 2), tree_col(tree, EDGE), speed)
			motes(pos, dir, maxi(amount / 2, 2), c, speed * 0.8)
		"corsair":
			muzzle_sparks(pos, dir, amount, c)
			smoke(pos, maxi(amount / 4, 2), 0.6, 1.1, POWDER_SMOKE)
		"dagger":
			shadow_wisps(pos, dir, amount, tree_col(tree, EDGE), speed)
		"dual_dagger":
			poison(pos, maxi(amount / 3, 2), 0.32)
			motes(pos, dir, maxi(amount / 2, 2), c, speed)
		"polearm":
			muzzle_sparks(pos, dir, amount, tree_col(tree, EDGE))
			motes(pos, dir, maxi(amount / 3, 2), c, speed * 0.7)
			bolt(pos, pos + (dir.normalized() + Vector3(randf_range(-0.4, 0.4), randf_range(0.0, 0.5), randf_range(-0.4, 0.4))) * 1.1,
				tree_col(tree, EDGE), 0.06, 0.16, randi() % 1000)
		"hammer":
			debris(pos, dir, amount, c, speed)
			dust(pos, maxi(amount / 3, 2), 0.6)
		"dual_axe":
			frost(pos, dir, amount, speed)
		"greatsword":
			gust(pos, dir, amount, speed)
		"black_leg":
			heat(pos, dir, amount, speed)
		_:
			spray(pos, dir, amount, c, speed)


## Heat thrown off a kick (black-leg's element): crimson flames tinted off the fire sheet (not the axe's orange
## embers), white-hot sparks flung hard along `dir`, and a brief red light.
const HEAT_TINT := Color(1.0, 0.3, 0.3)


func heat(pos: Vector3, dir: Vector3, amount: int = 10, speed: float = 4.0) -> void:
	var d := dir.normalized() if dir.length() > 0.01 else Vector3.UP
	var core := tree_col("black_leg", CORE)
	_burst(pos, maxi(amount * 2 / 3, 2), _spark_mat, 0.12, 0.35, {"radius": 0.12, "direction": d, "spread": 30.0, "vel_min": speed * 1.1,
		"vel_max": speed * 2.0, "gravity": Vector3(0, -6.0, 0), "damping": 2.5, "grow": false, "color": Color(core.r, core.g, core.b, 1.0)})
	flash_light(pos, Color(1.0, 0.35, 0.25), 1.2 + amount * 0.1, 3.0 + amount * 0.1, 0.2)
	if flipbooks:
		flipbook(pos, "fire", maxi(amount / 3, 2), 0.9, 0.45, {"radius": 0.15, "direction": (d + Vector3.UP * 0.6).normalized(), "spread": 35.0,
			"vel_min": speed * 0.3, "vel_max": speed * 0.7, "gravity": Vector3(0, 2.5, 0), "damping": 2.0, "explosiveness": 0.9, "start": 0.1,
			"spin": 20.0, "fade": 0.7, "color": HEAT_TINT})
	else:
		embers(pos, d, amount, tree_col("black_leg", EDGE), speed)


## A ring of crimson fire racing out along the ground (black-leg's Last Course): fire_ring's shape in the heat's tint,
## a pillar of it where the heel came down.
func heat_ring(pos: Vector3, radius: float = 6.0) -> void:
	var speed := radius / 0.35
	flash_light(pos + Vector3(0, 0.8, 0), Color(1.0, 0.3, 0.2), 6.0, radius * 1.8, 0.5)
	if flipbooks:
		flipbook(pos + Vector3(0, 0.3, 0), "fireball", 14, 1.4, 0.55, {"ring_radius": 0.4, "spread": 8.0, "direction": Vector3(0, 0.15, 0),
			"vel_min": speed * 0.85, "vel_max": speed, "gravity": Vector3(0, 3.0, 0), "damping": speed * 1.6, "start": 0.1, "spin": 180.0,
			"fade": 0.6, "color": HEAT_TINT})
		plume(pos, Vector3.UP, "fire", 6, 1.8, 0.8, HEAT_TINT, 7.0, 10.0)
	else:
		fire_ring(pos, radius, 50)
	heat(pos + Vector3(0, 0.5, 0), Vector3.UP, 14, 5.0)


## A kick's trail traced by the legs themselves (black-leg; as blade_swoosh is a blade's): `legs` "r", "l" or "lr".
func kick_swoosh(body: Node3D, secs: float, color: Color = Color.WHITE, color_l: Color = Color(0, 0, 0, 0), legs: String = "r") -> void:
	if not body is Humanoid:
		return
	var t := BladeTrail.new()
	t.body = body
	t.legs = legs
	t.emit = secs
	t.color = color
	t.color_l = color_l if color_l.a > 0.0 else color
	t.life = 0.16
	body.add_child(t)


## A leg glowing red-hot for `secs` (black-leg's heated kicks): a glow laid along the shin and foot, licks of crimson
## flame off it. One shared mesh; its own material (it fades).
static var _hot_mesh: CapsuleMesh


func hot_leg(body: Node3D, right: bool, secs: float = 0.6, color: Color = Color(1.0, 0.24, 0.14)) -> void:
	if not body is Humanoid or (body as Humanoid).ragdoll != null:
		return
	var shin: Node3D = (body as Humanoid).shin_r if right else (body as Humanoid).shin_l
	if shin == null:
		return
	if _hot_mesh == null:
		_hot_mesh = CapsuleMesh.new()
		_hot_mesh.radius = 0.09
		_hot_mesh.height = 0.62
		_hot_mesh.radial_segments = 6
		_hot_mesh.rings = 1
	var mi := MeshInstance3D.new()
	mi.mesh = _hot_mesh
	var mat := _glow_mat(color, 0.75)
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shin.add_child(mi)
	mi.position = Vector3(0, -0.24, -0.02)
	var fl := flip_emitter(mi, "fire", 6, 0.45, 0.35, {"radius": 0.1, "spread": 25.0, "vel_min": 0.3, "vel_max": 0.9, "gravity": Vector3(0, 2.0, 0),
		"damping": 0.8, "start": 0.15, "spin": 10.0, "fade": 0.7, "world": true, "color": HEAT_TINT}) if flipbooks else null
	var tw := mi.create_tween()
	tw.tween_property(mat, "albedo_color", Color(1.0, 0.9, 0.75, 0.85), secs * 0.25)
	tw.tween_property(mat, "albedo_color", Color(color.r, color.g, color.b, 0.0), secs * 0.75).set_ease(Tween.EASE_IN)
	if fl:
		tw.parallel().tween_callback(func(): fl.emitting = false).set_delay(secs * 0.4)
	tw.tween_callback(mi.queue_free)


## Will hardening the legs (Sky Leap): a dark glossy sheen over both shins and feet, up over `grow` s, held `hold` s,
## then fading. Called again on the same body it carries on from the sheen already there (0, 0 fades it now).
static var _haki_shin: CapsuleMesh
static var _haki_foot: BoxMesh


func haki_legs(body: Node3D, grow: float = 1.0, hold: float = 1.0) -> void:
	if not body is Humanoid:
		return
	var h := body as Humanoid
	var held: Array = h.get_meta("haki_legs") if h.has_meta("haki_legs") else []
	if held.is_empty():
		if _haki_shin == null:
			_haki_shin = CapsuleMesh.new()
			_haki_shin.radius = 0.085
			_haki_shin.height = absf(h.shin_l.position.y) + 0.12
			_haki_shin.radial_segments = 8
			_haki_shin.rings = 2
			_haki_foot = BoxMesh.new()
			_haki_foot.size = Vector3(0.13, 0.11, 0.27)
		var mat := StandardMaterial3D.new()
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = Color(0.05, 0.035, 0.06, 0.0)
		mat.metallic = 0.75
		mat.roughness = 0.16
		mat.rim_enabled = true
		mat.rim = 0.9
		mat.rim_tint = 0.2
		mat.emission_enabled = true
		mat.emission = Color(0.28, 0.02, 0.06)
		mat.emission_energy_multiplier = 0.6
		var parts := []
		var ankle := h.shin_l.position.y
		for shin in [h.shin_l, h.shin_r]:
			for m in [[_haki_shin, Vector3(0, ankle * 0.5, -0.005)], [_haki_foot, Vector3(0, ankle - 0.03, -0.07)]]:
				var mi := MeshInstance3D.new()
				mi.mesh = m[0]
				mi.material_override = mat
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				(shin as Node3D).add_child(mi)
				mi.position = m[1]
				parts.append(mi)
		held = [mat, parts, null]
		h.set_meta("haki_legs", held)
	var mat: StandardMaterial3D = held[0]
	if held[2] != null:
		(held[2] as Tween).kill()
	var tw := h.create_tween()
	held[2] = tw
	if grow > 0.0:
		tw.tween_property(mat, "albedo_color:a", 0.92, grow)
		tw.tween_interval(hold)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.35)
	tw.tween_callback(func():
		for mi in held[1]:
			(mi as Node).queue_free()
		h.remove_meta("haki_legs"))


## A fist wreathed in power (the fists' big punches): a glow round the hand with a hot core, and off it `kind`'s
## matter: "fire" (orange-yellow licks: Meteor Fist) or "galaxy" (star motes in every colour and embers: Sea King
## Fist, armed and after). Fades over `secs`; secs < 0 keeps it until the caller frees it (returned).
static var _fist_mesh: SphereMesh


func hot_fist(body: Node3D, right: bool, secs: float = 0.6, color: Color = Color(1.0, 0.62, 0.2), kind: String = "fire", size: float = 1.0) -> Node3D:
	if not body is Humanoid or (body as Humanoid).ragdoll != null:
		return null
	var hand: Node3D = (body as Humanoid).hand_r if right else (body as Humanoid).hand_l
	if hand == null:
		return null
	if _fist_mesh == null:
		_fist_mesh = SphereMesh.new()
		_fist_mesh.radius = 0.15
		_fist_mesh.height = 0.3
		_fist_mesh.radial_segments = 8
		_fist_mesh.rings = 4
	var mi := MeshInstance3D.new()
	mi.mesh = _fist_mesh
	var mat := _glow_mat(color, 0.7)
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.scale = Vector3.ONE * size
	hand.add_child(mi)
	var core := MeshInstance3D.new()
	core.mesh = _fist_mesh
	var cmat := _glow_mat(Color(1.0, 0.97, 0.85), 0.9)
	core.material_override = cmat
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	core.scale = Vector3.ONE * 0.55
	mi.add_child(core)
	if flipbooks:
		if kind == "galaxy":
			var st := flip_emitter(mi, "glint", 8, 0.2 * size, 0.5, {"radius": 0.22, "spread": 180.0, "vel_min": 0.4, "vel_max": 1.3,
				"gravity": Vector3.ZERO, "damping": 1.0, "fade": 0.6, "world": true, "color": Color(1.0, 0.55, 0.85)})
			st.hue_variation_min = -0.5
			st.hue_variation_max = 0.5
			flip_emitter(mi, "sparks", 5, 0.22 * size, 0.6, {"radius": 0.15, "spread": 40.0, "vel_min": 0.3, "vel_max": 0.9,
				"gravity": Vector3(0, 1.5, 0), "damping": 0.6, "fade": 0.6, "world": true, "color": Color(1.0, 0.7, 0.3)})
		else:
			flip_emitter(mi, "fire", 7, 0.42 * size, 0.35, {"radius": 0.12, "spread": 25.0, "vel_min": 0.3, "vel_max": 0.9,
				"gravity": Vector3(0, 2.0, 0), "damping": 0.8, "start": 0.15, "spin": 10.0, "fade": 0.7, "world": true, "color": color})
	if secs < 0.0:
		return mi
	var tw := mi.create_tween()
	tw.tween_property(mi, "scale", Vector3.ONE * size * 1.25, minf(0.12, secs * 0.2)).set_ease(Tween.EASE_OUT)
	tw.tween_property(mi, "scale", Vector3.ONE * size, minf(0.12, secs * 0.2))
	tw.tween_interval(secs * 0.4)
	tw.tween_property(mat, "albedo_color:a", 0.0, secs * 0.4).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(cmat, "albedo_color:a", 0.0, secs * 0.4).set_ease(Tween.EASE_IN)
	tw.tween_callback(mi.queue_free)
	return mi


## A four-pointed star of light at `pos`, facing the camera, popping open and fading over `life`: bright (a coloured
## rim round a white core) or `dark` (a black star rimmed in `color`: Meteor Fist's). `stretch` > 1 draws the rays
## out sideways (a flare).
static var _star_mesh: ArrayMesh


func _star() -> ArrayMesh:
	if _star_mesh == null:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var pts: Array = []
		for k in 8:
			var a := k * PI / 4.0
			var r := 1.0 if k % 2 == 0 else 0.16
			pts.append(Vector3(cos(a) * r, sin(a) * r, 0.0))
		for k in 8:
			st.add_vertex(Vector3.ZERO)
			st.add_vertex(pts[k])
			st.add_vertex(pts[(k + 1) % 8])
		_star_mesh = st.commit()
	return _star_mesh


func _star_mat(color: Color, alpha: float, dark: bool) -> StandardMaterial3D:
	var m := _glow_mat(color, alpha)
	if dark:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
		m.render_priority = 1
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.billboard_keep_scale = true
	return m


func star_glint(pos: Vector3, size: float = 0.8, color: Color = Color(1.0, 0.85, 0.5), life: float = 0.3, dark: bool = false, stretch: float = 1.0) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam and cam.global_position.distance_to(pos) > BURST_RANGE:
		return
	var holder := Node3D.new()
	_scene_root().add_child(holder)
	holder.global_position = pos
	var tw := holder.create_tween().set_parallel(true)
	var layers: Array = [[color, 0.85, false, 1.3], [Color(0.02, 0.0, 0.02) if dark else Color(1.0, 0.98, 0.9), 0.95, dark, 0.7]]
	for l in layers:
		var mi := MeshInstance3D.new()
		mi.mesh = _star()
		var mat := _star_mat(l[0], l[1], l[2])
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var full := Vector3(size * float(l[3]) * stretch, size * float(l[3]), 1.0)
		mi.scale = full * 0.2
		holder.add_child(mi)
		tw.tween_property(mi, "scale", full, life * 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		tw.tween_property(mat, "albedo_color:a", 0.0, life * 0.6).set_delay(life * 0.4).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(holder.queue_free)


## Anime speed lines: thin streaks along `dir` round `pos` (a punch or a dive going that way), behind it.
func speed_lines(pos: Vector3, dir: Vector3, color: Color = Color(0.85, 0.45, 1.0), count: int = 10, length: float = 2.5, life: float = 0.25, seed_v: int = 0) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam and cam.global_position.distance_to(pos) > BURST_RANGE:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var d := dir.normalized()
	var side := d.cross(Vector3.UP if absf(d.y) < 0.95 else Vector3.RIGHT).normalized()
	var up := side.cross(d).normalized()
	for i in count:
		var a := TAU * (i + rng.randf_range(-0.3, 0.3)) / count
		var from := pos + (side * cos(a) + up * sin(a)) * rng.randf_range(0.5, 1.5) - d * rng.randf_range(0.0, 0.8)
		streak(from, from - d * length * rng.randf_range(0.6, 1.0), color, 0.05, life * rng.randf_range(0.8, 1.2))


## A comet of light flung from `from` to `to` over `secs` (Sea King Fist's Galaxy punch): a stretched white-gold
## glow racing down the line, coloured stars thrown off it as it goes.
func comet(from: Vector3, to: Vector3, size: float = 1.6, secs: float = 0.4, color: Color = Color(1.0, 0.8, 0.4)) -> void:
	var seg := to - from
	if seg.length() < 0.5:
		return
	var holder := Node3D.new()
	_scene_root().add_child(holder)
	holder.global_transform = Transform3D(Basis.looking_at(seg.normalized(), Vector3.UP if absf(seg.normalized().y) < 0.95 else Vector3.FORWARD), from)
	var sm := SphereMesh.new()
	sm.radius = 0.5
	sm.height = 1.0
	sm.radial_segments = 8
	sm.rings = 4
	var tw := holder.create_tween()
	for l in [[color, 0.75, 1.0], [Color(1.0, 0.98, 0.92), 0.95, 0.5]]:
		var mat := _glow_mat(l[0], l[1])
		var ball := MeshInstance3D.new()
		ball.mesh = sm
		ball.material_override = mat
		ball.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ball.scale = Vector3(size, size, size * 3.0) * float(l[2])
		holder.add_child(ball)
		tw.parallel().tween_property(mat, "albedo_color:a", 0.0, secs * 0.5).set_delay(secs * 0.7)
	tw.parallel().tween_property(holder, "global_position", to, secs).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	var cols := [Color(1.0, 0.85, 0.3), Color(0.35, 0.95, 1.0), Color(1.0, 0.35, 0.85), Color.WHITE]
	for k in 6:
		var at := from + seg * (k + 1) / 7.0 + Vector3(randf_range(-0.6, 0.6), randf_range(-0.3, 0.9), randf_range(-0.6, 0.6))
		tw.parallel().tween_callback(star_glint.bind(at, randf_range(0.5, 0.9), cols[k % cols.size()], 0.35)).set_delay(secs * (k + 1) / 7.0)
	tw.chain().tween_interval(0.05)
	tw.tween_callback(holder.queue_free)


## A blast of light where a great blow lands (Sea King Fist): a white-hot pillar shooting up, an orange dome
## swelling out over the ground, the ground lit.
func light_pillar(pos: Vector3, height: float = 10.0, radius: float = 4.0, life: float = 0.8, color: Color = Color(1.0, 0.55, 0.15)) -> void:
	flash_light(pos + Vector3(0, 1.5, 0), Color(1.0, 0.75, 0.4), 8.0, radius * 3.0, life)
	var cam := get_viewport().get_camera_3d()
	if cam and cam.global_position.distance_to(pos) > BURST_RANGE * 1.5:
		return
	var holder := Node3D.new()
	_scene_root().add_child(holder)
	holder.global_position = pos
	var cyl := CylinderMesh.new()
	cyl.top_radius = 1.0
	cyl.bottom_radius = 1.0
	cyl.height = 1.0
	cyl.radial_segments = 10
	cyl.rings = 1
	cyl.cap_top = false
	cyl.cap_bottom = false
	var dome := SphereMesh.new()
	dome.radius = 1.0
	dome.height = 2.0
	dome.radial_segments = 12
	dome.rings = 6
	var tw := holder.create_tween().set_parallel(true)
	for l in [[cyl, Color(1.0, 0.98, 0.9), 0.9, radius * 0.35], [cyl, Color(1.0, 0.85, 0.5), 0.6, radius * 0.6], [dome, color, 0.55, radius]]:
		var mi := MeshInstance3D.new()
		mi.mesh = l[0]
		var mat := _glow_mat(l[1], l[2])
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		holder.add_child(mi)
		var r: float = l[3]
		if l[0] == cyl:
			mi.scale = Vector3(r, 0.1, r)
			mi.position.y = 0.05
			tw.tween_property(mi, "scale", Vector3(r, height, r), life * 0.15).set_ease(Tween.EASE_OUT)
			tw.tween_property(mi, "position:y", height * 0.5, life * 0.15).set_ease(Tween.EASE_OUT)
			tw.tween_property(mi, "scale:x", r * 0.1, life * 0.85).set_delay(life * 0.15).set_ease(Tween.EASE_IN)
			tw.tween_property(mi, "scale:z", r * 0.1, life * 0.85).set_delay(life * 0.15).set_ease(Tween.EASE_IN)
		else:
			mi.scale = Vector3.ONE * r * 0.2
			tw.tween_property(mi, "scale", Vector3(r, r * 0.6, r), life * 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		tw.tween_property(mat, "albedo_color:a", 0.0, life * 0.6).set_delay(life * 0.4).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(holder.queue_free)


## Wind torn off a blade (the greatsword's element): pale streaks of air flung hard along `dir`, jade motes riding
## them, a couple of rushing lines of air and a breath of mist.
func gust(pos: Vector3, dir: Vector3, amount: int = 10, speed: float = 4.0) -> void:
	var d := dir.normalized() if dir.length() > 0.01 else Vector3.UP
	var edge := tree_col("greatsword", EDGE)
	_burst(pos, amount, _spark_mat, 0.1, 0.32, {"radius": 0.2, "direction": d, "spread": 28.0, "vel_min": speed * 1.3, "vel_max": speed * 2.3,
		"gravity": Vector3.ZERO, "damping": 4.0, "grow": false, "color": Color(edge.r, edge.g, edge.b, 0.9)})
	motes(pos, d, maxi(amount / 3, 2), tree_col("greatsword", ACCENT), speed * 0.7)
	for i in 2:
		var off := Vector3(randf_range(-0.35, 0.35), randf_range(-0.2, 0.35), randf_range(-0.35, 0.35))
		punch_wind(pos, (d + off).normalized(), 0.8 + speed * 0.1, tree_col("greatsword", CORE))
	if flipbooks:
		puff(pos, "mist", 1, 0.8, 0.45, Color(0.85, 1.0, 0.93, 0.4), speed * 0.2, d)


## Frost thrown along `dir` (the twin axes' element): chips of ice that fly and fall hard, white rime motes that
## hang a moment, and a puff of cold mist.
func frost(pos: Vector3, dir: Vector3, amount: int = 10, speed: float = 4.0) -> void:
	debris(pos, dir, maxi(amount * 2 / 3, 2), tree_col("dual_axe", EDGE).lightened(0.25), speed)
	motes(pos, dir, maxi(amount / 3, 2), tree_col("dual_axe", CORE), speed * 0.6)
	if flipbooks:
		puff(pos, "mist", maxi(amount / 5, 1), 0.7, 0.6, Color(0.85, 0.94, 1.0, 0.55), speed * 0.15, dir)
	else:
		dust(pos, maxi(amount / 4, 2), 0.45)


## Shadow coming off a blade (the dagger's element): black wisps that rise and thin,
## and crimson motes thrown along `dir`.
func shadow_wisps(pos: Vector3, dir: Vector3, amount: int = 8, color: Color = Color(0.95, 0.15, 0.38), speed: float = 3.0) -> void:
	smoke(pos, maxi(amount / 2, 2), 0.45, 0.8, SHADOW_SMOKE)
	motes(pos, dir, maxi(amount / 2, 2), color, speed)


## Black powder smoke (the Corsair's element: darker than a plain gunshot's).
const POWDER_SMOKE := Color(0.24, 0.22, 0.24, 0.8)


## Bright motes thrown along `dir` that slow and hang a moment (the dual blades'
## twin currents).
func motes(pos: Vector3, dir: Vector3, amount: int = 8, color: Color = Color.WHITE, speed: float = 4.0) -> void:
	if flipbooks:
		flipbook(pos, "magic", maxi(amount / 3, 2), 0.5, 0.5, {"radius": 0.12, "direction": dir.normalized(), "spread": 45.0,
			"vel_min": speed * 0.4, "vel_max": speed, "gravity": Vector3.ZERO, "damping": 6.0, "start": 0.1, "spin": 180.0,
			"fade": 0.6, "color": Color(color.r, color.g, color.b, 1.0)})
		return
	_burst(pos, amount, _spark_mat, 0.14, 0.5, {"radius": 0.12, "direction": dir.normalized(), "spread": 45.0,
		"vel_min": speed * 0.4, "vel_max": speed, "gravity": Vector3.ZERO, "damping": 6.0, "grow": false,
		"color": Color(color.r, color.g, color.b, 1.0)})


## Black powder going off (the Corsair's shots and blasts): a flash, sparks
## thrown along `dir`, a ring of air and a puff of dark smoke. `size` scales it
## (a combo shot ~0.7, a cannon-blast ~2).
func powder_burst(pos: Vector3, dir: Vector3, size: float = 1.0, color: Color = Color(1.0, 0.34, 0.26)) -> void:
	var d := dir.normalized() if dir.length() > 0.01 else Vector3.UP
	flash_light(pos, color.lerp(FIRE_LIGHT, 0.5), 2.0 * size, 3.0 + 2.5 * size, 0.1 + 0.06 * size)
	if flipbooks:
		flash(pos, 1.2 * size, Color.WHITE, "muzzle", 0.22)
	else:
		_burst(pos, 1, _impact_mat, 0.9 * size, 0.1, {"radius": 0.01, "vel_min": 0.0, "vel_max": 0.0, "gravity": Vector3.ZERO,
			"grow": true, "color": Color(1, 1, 1, 1)})
	_burst(pos, int(8 * size) + 4, _spark_mat, 0.15, 0.4, {"radius": 0.08, "direction": d, "spread": 50.0,
		"vel_min": 3.0 * size, "vel_max": 7.0 * size, "gravity": Vector3(0, -7.0, 0), "damping": 3.0, "grow": false,
		"color": tree_col("corsair", ACCENT)})
	ring(pos, d, 0.8 * size, color, 0.2, 0.18)
	smoke(pos, int(3 * size) + 2, 0.55 * size + 0.2, 1.0 + 0.3 * size, POWDER_SMOKE)


## A cannonball landing (Broadside, the sword-and-pistol ultimate): a flash, rock
## and dirt thrown up, a ring racing out and a column of smoke. With a `glow`
## colour (the element) it burns: a ring of it, sparks, flame and black smoke.
func cannon_blast(pos: Vector3, size: float = 1.5, glow: Color = Color(0, 0, 0, 0)) -> void:
	var hot := glow.a > 0.0
	flash_light(pos + Vector3(0, 0.8, 0), Color(glow.r, glow.g, glow.b) if hot else FIRE_LIGHT, 4.0 * size, 6.0 * size, 0.2 + 0.1 * size)
	if flipbooks:
		flash(pos + Vector3(0, 0.5, 0), 2.2 * size, Color.WHITE, "muzzle", 0.3)
	else:
		_burst(pos + Vector3(0, 0.5, 0), 1, _impact_mat, 2.0 * size, 0.14, {"radius": 0.01, "vel_min": 0.0, "vel_max": 0.0, "gravity": Vector3.ZERO,
			"grow": true, "color": Color(1, 1, 1, 1)})
	debris(pos + Vector3(0, 0.1, 0), Vector3.UP, 12, Color(0.35, 0.3, 0.25), 6.5)
	dust_ring(pos, 18, 1.1 * size)
	ring(pos, Vector3.UP, 2.6 * size, glow if hot else Color(1.0, 0.95, 0.85), 0.4, 0.14)
	smoke(pos + Vector3(0, 0.6, 0), 9, 0.9 * size, 2.0, POWDER_SMOKE if hot else Color(0.62, 0.6, 0.58, 0.8))
	if hot:
		_burst(pos + Vector3(0, 0.3, 0), 20, _spark_mat, 0.16, 0.6, {"radius": 0.3, "direction": Vector3.UP, "spread": 55.0,
			"vel_min": 4.0, "vel_max": 9.0, "gravity": Vector3(0, -9.0, 0), "damping": 1.5, "grow": false,
			"color": tree_col("corsair", ACCENT)})
		flame(pos + Vector3(0, 0.3, 0), 10, 0.8, 0.5, 0.6)
		ring(pos + Vector3(0, 0.6, 0), Vector3.UP, 1.6 * size, tree_col("corsair", ACCENT), 0.3, 0.2)
	else:
		dust(pos + Vector3(0, 0.1, 0), 8, 1.0)


# --------------------------------------------------------------------------
# Flipbooks: sprite-sheet particles (the library in tools/texture_gen/gen_flipbooks.py) and the
# blocks over them that the effects are built from (puff, puff_ring, plume, flash, blast, lick)
# --------------------------------------------------------------------------
## Flipbook effects on (sprite sheets) or off (the geometry effects from before, kept to compare
## and to revert a regression in one line).
var flipbooks := true
## Every sheet in assets/textures/fx/flip_<name>.png, all 4x4 frames of 64 px.
const FLIP_SHEETS := ["smoke", "explosion", "dust", "dust_low", "sand", "snow", "mist", "blood", "splash", "fire",
	"fireball", "muzzle", "sparks", "glint", "magic", "wisp"]
## Light: grey-white sheets drawn additive, so the burst's colour tints them. The rest is matter.
const FLIP_ADD := ["sparks", "glint", "magic"]
## Matter that doesn't glow: dimmed with the night (unshaded, it would shine white in the dark).
const FLIP_LIT := ["smoke", "dust", "dust_low", "sand", "snow", "mist", "blood", "splash", "wisp"]
const FLIP_NIGHT_DIM := 0.65
var _flip_mats: Dictionary = {}
var _flip_ramps: Dictionary = {}
var _lit_emitters: Array = []


## A burst whose particles each play a sprite sheet once over their life. _burst's cfg, plus
## "start" (each starts up to that far into the sheet, 0..1), "spin" (a random roll up to that
## many degrees either way), "fade_in" / "fade" (when the colour is all there and when it starts
## to clear, 0..1 of the life), "curve" (the size over life: "flat", "grow"...) and "lit"
## (dimmed at night; by default the FLIP_LIT sheets).
func flipbook(pos: Vector3, sheet: String, amount: int, size: float, life: float, cfg: Dictionary) -> CPUParticles3D:
	var col: Color = cfg.get("color", Color.WHITE)
	if cfg.get("lit", sheet in FLIP_LIT):
		var k := _night_k()
		col = Color(col.r * k, col.g * k, col.b * k, col.a)
	var c := {"ramp": _flip_ramp(col, cfg.get("fade_in", 0.0), cfg.get("fade", 0.6))}
	c.merge(cfg)
	var p := _burst(pos, amount, _flip_mat(sheet), size, life, c)
	if p:
		p.scale_amount_curve = _curve(cfg.get("curve", "flat"))
		_flip_setup(p, cfg)
	return p


## A flipbook emitter that keeps going until freed: each particle plays `sheet` once over its
## life (a campfire's licks, a chimney's wisps, a burning body). cfg as flipbook's, plus "world"
## (particles stay where they were emitted: trails; otherwise they ride with `parent`) and
## "range" (seen this far, 140 m). Lit sheets follow the night as it comes and goes.
func flip_emitter(parent: Node3D, sheet: String, amount: int, size: float, life: float, cfg: Dictionary) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = amount
	p.lifetime = life
	p.local_coords = not cfg.get("world", false)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = cfg.get("radius", 0.2)
	p.direction = cfg.get("direction", Vector3.UP)
	p.spread = cfg.get("spread", 20.0)
	p.gravity = cfg.get("gravity", Vector3(0, 0.3, 0))
	p.initial_velocity_min = cfg.get("vel_min", 0.3)
	p.initial_velocity_max = cfg.get("vel_max", 0.8)
	p.damping_min = cfg.get("damping", 0.2)
	p.damping_max = cfg.get("damping", 0.2)
	p.scale_amount_min = cfg.get("scale_min", 0.8)
	p.scale_amount_max = cfg.get("scale_max", 1.2)
	p.scale_amount_curve = _curve(cfg.get("curve", "flat"))
	p.color_ramp = _flip_ramp(cfg.get("color", Color.WHITE), cfg.get("fade_in", 0.0), cfg.get("fade", 0.6))
	p.mesh = _quad(size, _flip_mat(sheet))
	p.visibility_range_end = cfg.get("range", 140.0)
	_flip_setup(p, cfg)
	parent.add_child(p)
	p.emitting = true
	if cfg.get("lit", sheet in FLIP_LIT):
		var k := _night_k()
		p.color = Color(k, k, k)
		_lit_emitters.append(p)
	return p


## Brief real light from fire and explosions: a pool of at most FLASH_CAP shadowless OmniLights (the
## weakest one is taken over when all are lit), none beyond FLASH_RANGE of the camera. false: no lights.
var flash_lights := true
const FLASH_CAP := 6
const FLASH_RANGE := 90.0
const FIRE_LIGHT := Color(1.0, 0.6, 0.28)
var _lights: Array = []


## A light flaring up at `pos` and dying away over `secs` (a fast rise, a quick fall-off), `reach` m.
## Lights asked for in the same frame close together (an effect calling another) are one light, the
## biggest of them.
func flash_light(pos: Vector3, color: Color = FIRE_LIGHT, energy: float = 3.0, reach: float = 6.0, secs: float = 0.25) -> void:
	if not flash_lights:
		return
	var cam := get_viewport().get_camera_3d()
	if cam and cam.global_position.distance_squared_to(pos) > FLASH_RANGE * FLASH_RANGE:
		return
	var frame := Engine.get_process_frames()
	var l: OmniLight3D = null
	for o in _lights:
		if o.visible and int(o.get_meta("frame")) == frame and o.global_position.distance_to(pos) < 1.5:
			if float(o.get_meta("peak")) >= energy:
				color = o.light_color
			energy = maxf(energy, float(o.get_meta("peak")))
			reach = maxf(reach, o.omni_range)
			secs = maxf(secs, float(o.get_meta("secs")))
			l = o
			break
	if l == null:
		for o in _lights:
			if not o.visible:
				l = o
				break
	if l == null and _lights.size() < FLASH_CAP:
		l = OmniLight3D.new()
		l.shadow_enabled = false
		l.light_bake_mode = Light3D.BAKE_DISABLED
		l.visible = false
		add_child(l)
		_lights.append(l)
	if l == null:
		l = _lights[0]
		for o in _lights:
			if o.light_energy < l.light_energy:
				l = o
	var old = l.get_meta("tw") if l.has_meta("tw") else null
	if old and (old as Tween).is_valid():
		(old as Tween).kill()
	l.global_position = pos
	l.light_color = color
	l.omni_range = reach
	l.set_meta("frame", frame)
	l.set_meta("peak", energy)
	l.set_meta("secs", secs)
	if not l.visible:
		l.light_energy = 0.0
	l.visible = true
	var tw := l.create_tween()
	tw.tween_property(l, "light_energy", energy, minf(0.04, secs * 0.2))
	tw.tween_property(l, "light_energy", 0.0, secs).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.tween_callback(l.hide)
	l.set_meta("tw", tw)


## Flash lights lit right now.
func lights_lit() -> int:
	var n := 0
	for o in _lights:
		if o.visible:
			n += 1
	return n


func _flip_setup(p: CPUParticles3D, cfg: Dictionary) -> void:
	p.anim_speed_min = 1.0
	p.anim_speed_max = 1.0
	p.anim_offset_max = cfg.get("start", 0.0)
	p.angle_min = -float(cfg.get("spin", 0.0))
	p.angle_max = float(cfg.get("spin", 0.0))
	p.draw_order = CPUParticles3D.DRAW_ORDER_VIEW_DEPTH
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _night_k() -> float:
	return 1.0 - FLIP_NIGHT_DIM * snappedf(float(get_node("/root/Weather").night), 0.1)


## Every 2 s: the lit emitters take the night's dimming (one loop, not a process on each).
func _dim_emitters() -> void:
	if _lit_emitters.is_empty():
		return
	var k := _night_k()
	var keep: Array = []
	for e in _lit_emitters:
		if is_instance_valid(e):
			e.color = Color(k, k, k)
			keep.append(e)
	_lit_emitters = keep


func _flip_mat(sheet: String) -> StandardMaterial3D:
	if not _flip_mats.has(sheet):
		var m := _billboard_mat("res://assets/textures/fx/flip_%s.png" % sheet, sheet in FLIP_ADD)
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
		m.particles_anim_h_frames = 4
		m.particles_anim_v_frames = 4
		m.particles_anim_loop = false
		_flip_mats[sheet] = m
	return _flip_mats[sheet]


func _flip_ramp(col: Color, fade_in: float, fade: float) -> Gradient:
	var key := [col, fade_in, fade]
	if not _flip_ramps.has(key):
		var clear := Color(col.r, col.g, col.b, 0.0)
		var g := Gradient.new()
		if fade_in > 0.0:
			g.offsets = PackedFloat32Array([0.0, fade_in, fade, 1.0])
			g.colors = PackedColorArray([clear, col, col, clear])
		else:
			g.offsets = PackedFloat32Array([0.0, fade, 1.0])
			g.colors = PackedColorArray([col, col, clear])
		_flip_ramps[key] = g
	return _flip_ramps[key]


## The blocks (all one burst each, so one draw; all sendable through Net.fx). Layer them as the
## driftwake-fx skill says: a flash or a gather first, the blast or the plume as the release, puffs
## and smoke settling after.

## One puff of `sheet` (or `amount` of them) drifting off along `dir` from `pos` at `lift` m/s:
## the smallest block (a footstep's dust, a shot's smoke, blood mist off a wound).
func puff(pos: Vector3, sheet: String = "dust", amount: int = 1, size: float = 0.6, life: float = 0.7, color: Color = Color.WHITE, lift: float = 0.6, dir: Vector3 = Vector3.UP) -> CPUParticles3D:
	return flipbook(pos, sheet, amount, size, life, {"radius": 0.12 * size, "direction": dir.normalized(), "spread": 45.0,
		"vel_min": lift * 0.5, "vel_max": lift, "gravity": Vector3(0, 0.3, 0), "damping": 2.0, "start": 0.06, "spin": 25.0, "color": color})


## A ring of `count` puffs of `sheet` thrown out along the ground from `pos` (a landing, a slam, a
## blast's base), racing out at `speed` m/s and slowing.
func puff_ring(pos: Vector3, sheet: String = "dust_low", count: int = 6, radius: float = 0.3, size: float = 1.0, life: float = 0.9, color: Color = Color.WHITE, speed: float = 5.0) -> CPUParticles3D:
	return flipbook(pos + Vector3(0, 0.12, 0), sheet, count, size, life, {"ring_radius": radius, "spread": 10.0,
		"direction": Vector3(0, 0.15, 0), "vel_min": speed * 0.06, "vel_max": speed * 0.12, "radial": speed,
		"gravity": Vector3(0, 0.3, 0), "damping": speed * 0.8, "start": 0.1, "spin": 30.0, "color": color})


## `count` puffs of `sheet` pushed out along `dir` from `pos` at up to `speed` m/s (a cannon's bank
## of smoke, a column of white water, a pillar of fire): fast at first, slowing and growing.
func plume(pos: Vector3, dir: Vector3, sheet: String = "smoke", count: int = 4, size: float = 1.5, life: float = 1.6, color: Color = Color.WHITE, speed: float = 4.0, spread: float = 15.0) -> CPUParticles3D:
	return flipbook(pos, sheet, count, size, life, {"radius": 0.15 * size, "direction": dir.normalized(), "spread": spread,
		"vel_min": speed * 0.35, "vel_max": speed, "gravity": Vector3(0, 0.35, 0), "damping": speed * 0.4, "start": 0.08,
		"spin": 25.0, "curve": "grow", "fade_in": 0.06, "color": color})


## A flash at `pos`: one `glint` (a star, in `color`) or `muzzle` (a blast's flare) sheet played fast.
func flash(pos: Vector3, size: float = 0.9, color: Color = Color.WHITE, sheet: String = "glint", life: float = 0.15) -> CPUParticles3D:
	return flipbook(pos, sheet, 1, size, life, {"radius": 0.01, "vel_min": 0.0, "vel_max": 0.0, "gravity": Vector3.ZERO,
		"damping": 0.0, "spin": 180.0 if sheet == "muzzle" else 0.0, "fade": 0.85, "color": color})


## Something going off at `pos`, out along `normal`: the flare, a fireball when `hot`, and smoke
## pushed out at `speed` (fast: a muzzle's jet; slow: a bloom on a hull). `size` scales it all (a
## pistol 0.4, a cannon's muzzle 1, a ball bursting on a hull 2). Sparks and embers are the caller's.
func blast(pos: Vector3, normal: Vector3 = Vector3.UP, size: float = 1.0, hot: bool = true, smoke_col: Color = Color(0.8, 0.79, 0.77, 0.9), speed: float = 6.0) -> void:
	var n := normal.normalized() if normal.length() > 0.01 else Vector3.UP
	flash_light(pos + n * 0.5 * size, FIRE_LIGHT, (3.0 if hot else 2.0) * size, 5.0 * size + 2.0, 0.15 + 0.12 * size)
	flash(pos, 1.6 * size, Color.WHITE, "muzzle", 0.35 + 0.1 * size)
	if hot:
		flipbook(pos + n * 0.3 * size, "fireball", 1 + int(size), 1.1 * size, 0.4 + 0.15 * size, {"radius": 0.1 * size,
			"direction": n, "spread": 30.0, "vel_min": speed * 0.3, "vel_max": speed * 0.8, "gravity": Vector3.ZERO,
			"damping": speed * 0.8, "start": 0.04, "spin": 180.0, "fade": 0.7})
	plume(pos + n * 0.5 * size, n, "smoke", 2 + int(size * 2.0), 1.4 * size + 0.3, 1.9 + 0.5 * size, smoke_col, speed, 25.0)


## Flame licking up for good from `parent` (a campfire, a brazier, a burning hull; `world`: a
## trail): `amount` tongues of the `fire` sheet, each rising and burning out over `life`.
func lick(parent: Node3D, radius: float = 0.3, amount: int = 8, size: float = 0.6, life: float = 0.7, world: bool = false) -> CPUParticles3D:
	return flip_emitter(parent, "fire", amount, size, life, {"radius": radius, "spread": 12.0, "vel_min": 0.4, "vel_max": 1.0,
		"gravity": Vector3(0, 1.2, 0), "damping": 0.8, "scale_min": 0.7, "scale_max": 1.2, "start": 0.15, "spin": 8.0,
		"fade": 0.75, "world": world})


## A ship's cannon going off at `from` along `dir`: sparks, the flare and a bank of smoke pushed
## out along the shot.
func cannon_fire(from: Vector3, dir: Vector3) -> void:
	flash_light(from + dir * 0.8, FIRE_LIGHT, 5.0, 10.0, 0.25)
	muzzle_sparks(from, dir, 16)
	if not flipbooks:
		smoke(from + dir * 0.6, 10, 1.6, 2.2)
		flame(from + dir * 0.3, 8, 0.7, 0.25, 0.25)
		return
	blast(from + dir * 0.5, dir, 1.0, false)


## A cannonball bursting on a hull, a rock or the ground at `at` (`normal`: off the surface): a
## fireball blooming, dark smoke and embers.
func cannon_hit(at: Vector3, normal: Vector3) -> void:
	flash_light(at + normal * 0.6, FIRE_LIGHT, 7.0, 12.0, 0.4)
	if not flipbooks:
		impact(at, Color(1.0, 0.7, 0.35))
		flame(at, 12, 0.8, 0.45, 0.6)
		smoke(at + normal * 0.3, 8, 1.3, 1.8)
		dust(at, 8, 0.9)
		return
	blast(at + normal * 0.2, normal, 2.0, true, Color(0.5, 0.48, 0.47, 0.85), 2.0)
	embers(at + normal * 0.3, normal + Vector3.UP * 0.5, 8, Color(1.0, 0.45, 0.12), 5.0)


## A cannonball into the sea at `at`: a splash, its foam ring and a column of white water.
func cannon_splash(at: Vector3) -> void:
	splash(at, 10, 1.4)
	if not flipbooks:
		splash(at + Vector3(0, 0.6, 0), 6, 0.9)
		return
	puff(at + Vector3(0, 1.2, 0), "mist", 2, 2.2, 1.4, Color(0.9, 0.96, 1.0, 0.7), 1.5)


## A heavy blow landing or a body thrown down hard: dust thrown out along the ground.
func heavy_dust(pos: Vector3, amount: int = 12, size: float = 0.8) -> void:
	if not flipbooks:
		dust_ring(pos, amount, size)
		return
	puff_ring(pos, "dust_low", maxi(amount / 2, 5), 0.3, size * 1.6, 0.95, Color.WHITE, 5.0)
	puff(pos + Vector3(0, 0.3, 0), "dust", 2, size * 1.4, 0.9, Color.WHITE, 1.2)


## An X of two light-streaks through `pos` (the dual blades' mark): upright,
## facing along `dir`, or `flat` on the ground; one stroke in each colour.
func twin_cross(pos: Vector3, dir: Vector3, size: float = 1.0, a: Color = Color(0.35, 0.9, 0.95), b: Color = Color(0.75, 0.45, 1.0), life: float = 0.3, flat: bool = false) -> void:
	var f := Vector3(dir.x, 0.0, dir.z)
	f = f.normalized() if f.length() > 0.01 else Vector3.FORWARD
	var right := f.cross(Vector3.UP).normalized()
	var up := f if flat else Vector3.UP
	var w := 0.08 + 0.04 * size
	streak(pos - right * size + up * size, pos + right * size - up * size, a, w, life)
	streak(pos + right * size + up * size, pos - right * size - up * size, b, w, life)


static var _ember_ramps: Dictionary = {}
static var _debris_mesh: BoxMesh
static var _unit_box: BoxMesh


## Hot embers thrown along `dir`: sparks that fly, slow, and drift up as they cool
## from white-yellow through `color` to a dull red (the axe's element), and a
## puff of flame.
func embers(pos: Vector3, dir: Vector3, amount: int = 10, color: Color = Color(1.0, 0.32, 0.08), speed: float = 4.0) -> void:
	if not _ember_ramps.has(color):
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.3, 1.0])
		g.colors = PackedColorArray([Color(1.0, 0.92, 0.6, 1.0), Color(color.r, color.g, color.b, 1.0), Color(0.45, 0.06, 0.02, 0.0)])
		_ember_ramps[color] = g
	_burst(pos, amount, _spark_mat, 0.12, 0.9, {"radius": 0.15, "direction": dir.normalized(), "spread": 40.0,
		"vel_min": speed * 0.5, "vel_max": speed, "gravity": Vector3(0, 1.6, 0), "damping": 3.0, "grow": false,
		"ramp": _ember_ramps[color]})
	flame(pos, maxi(amount / 4, 2), 0.45, 0.4, 0.15)


## Rock chips knocked loose (axe blows into the ground): dark chunks thrown
## along `dir` that fall hard.
func debris(pos: Vector3, dir: Vector3 = Vector3.UP, amount: int = 8, color: Color = Color(0.42, 0.36, 0.3), speed: float = 5.0) -> void:
	if _debris_mesh == null:
		_debris_mesh = BoxMesh.new()
		_debris_mesh.size = Vector3(0.09, 0.07, 0.08)
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.vertex_color_use_as_albedo = true
		m.vertex_color_is_srgb = true
		_debris_mesh.material = m
	_burst(pos, amount, null, 0.1, 0.8, {"radius": 0.25, "direction": dir.normalized(), "spread": 35.0,
		"vel_min": speed * 0.5, "vel_max": speed, "gravity": Vector3(0, -16.0, 0), "damping": 0.5, "hold": true,
		"scale_min": 0.6, "scale_max": 1.6, "mesh": _debris_mesh, "color": Color(color.r, color.g, color.b, 1.0)})


static func _box() -> BoxMesh:
	if _unit_box == null:
		_unit_box = BoxMesh.new()
		_unit_box.size = Vector3.ONE
	return _unit_box


## A crack torn along the ground from `from` along `dir` (axe blows that split the
## earth): a jagged dark line zipping out over `secs` with a branch here and
## there, lingering, then gone. A `glow` with alpha puts molten light in it (the
## axe's element). Seeded, so every screen draws the same crack.
func ground_crack(from: Vector3, dir: Vector3, length: float = 6.0, glow: Color = Color(0, 0, 0, 0), seed_v: int = 0, secs: float = 0.18) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam and cam.global_position.distance_to(from) > BURST_RANGE:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var d := Vector3(dir.x, 0.0, dir.z).normalized()
	var side := d.cross(Vector3.UP)
	var dark := StandardMaterial3D.new()
	dark.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dark.albedo_color = Color(0.09, 0.06, 0.04)
	var hot: StandardMaterial3D = _glow_mat(glow, 0.95) if glow.a > 0.0 else null
	var holder := Node3D.new()
	_scene_root().add_child(holder)
	var n := maxi(int(length / 0.55), 2)
	var pts: Array = []
	for i in range(n + 1):
		var p := from + d * (length * float(i) / n) + side * (rng.randf_range(-0.22, 0.22) if i > 0 else 0.0)
		pts.append(_ground_at(p))
	var tw := holder.create_tween()
	for i in range(n):
		var w := 0.28 * (1.0 - 0.6 * float(i) / n) + 0.05
		tw.tween_interval(secs / n)
		tw.tween_callback(_crack_seg.bind(holder, pts[i], pts[i + 1], w, dark, hot))
		if rng.randf() < 0.35:
			var bd := (d + side * rng.randf_range(-1.6, 1.6)).normalized()
			tw.tween_callback(_crack_seg.bind(holder, pts[i], _ground_at(pts[i] + bd * rng.randf_range(0.5, 1.1)), w * 0.6, dark, hot))
	# (it closes up: every piece narrows to nothing, the glow goes out first)
	tw.tween_interval(0.9)
	if hot:
		tw.tween_property(hot, "albedo_color:a", 0.0, 0.35)
	tw.tween_method(func(k: float):
		for c in holder.get_children():
			(c as Node3D).scale = Vector3(k, 1.0, 1.0), 1.0, 0.0, 0.5)
	tw.tween_callback(holder.queue_free)


static var _spike_mesh: ArrayMesh
static var _ice_mesh: ArrayMesh


static func _spike(mat: Material) -> ArrayMesh:
	var mb := MeshBuilder.new()
	mb.add_cone(mat, Transform3D(), 0.2, 1.0, 5, 1.0)
	mb.add_cone(mat, Transform3D(Basis(Vector3.BACK, 0.35), Vector3(0.12, 0, 0.05)), 0.12, 0.6, 4, 1.0)
	return mb.commit()


## Stone spikes heaving up out of the ground in a ring round `pos` (the hammer's element, its ultimate's
## signature): `count` shards of rock leaning outward, up in a snap, held, sunk back. Seeded, so every screen
## raises the same ring. One shared mesh (the "rock" material), no shadows, one tween. `ice`: shards of ice
## instead (the twin axes' frost: its own shared mesh, pale and cold).
func rock_spikes(pos: Vector3, radius: float = 2.5, count: int = 8, seed_v: int = 0, height: float = 1.2, life: float = 0.9, ice: bool = false) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam and cam.global_position.distance_to(pos) > BURST_RANGE:
		return
	if _spike_mesh == null:
		_spike_mesh = _spike(PSXMat.lit("rock", Color(0.92, 0.82, 0.7)))
		_ice_mesh = _spike(PSXMat.lit("metal", Color(0.82, 0.96, 1.15)))
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var holder := Node3D.new()
	_scene_root().add_child(holder)
	holder.global_position = pos
	for i in count:
		var a := TAU * (i + rng.randf_range(-0.3, 0.3)) / count
		var out := Vector3(cos(a), 0, sin(a))
		var h := height * rng.randf_range(0.6, 1.15)
		var mi := MeshInstance3D.new()
		mi.mesh = _ice_mesh if ice else _spike_mesh
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		holder.add_child(mi)
		var at := _ground_at(pos + out * radius * rng.randf_range(0.75, 1.1)) - pos
		var b := Basis(Vector3.UP.cross(out).normalized(), rng.randf_range(0.2, 0.5)) * Basis(Vector3.UP, rng.randf() * TAU)
		mi.transform = Transform3D(b * Basis.from_scale(Vector3(h * 0.9, h, h * 0.9)), at - Vector3(0, h, 0))
		mi.set_meta("y0", at.y - h)
		mi.set_meta("h", h)
	var rise := func(k: float) -> void:
		for c in holder.get_children():
			(c as Node3D).position.y = float(c.get_meta("y0")) + float(c.get_meta("h")) * k
	var tw := holder.create_tween()
	tw.tween_method(rise, 0.0, 0.92, 0.09).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(life * 0.55)
	tw.tween_method(rise, 0.92, 0.0, life * 0.35).set_ease(Tween.EASE_IN)
	tw.tween_callback(holder.queue_free)


func _ground_at(p: Vector3) -> Vector3:
	var h := _ray(p + Vector3.UP * 2.0, p + Vector3.DOWN * 3.0)
	return (h["position"] as Vector3) + Vector3(0, 0.03, 0) if not h.is_empty() else p


func _crack_seg(holder: Node3D, a: Vector3, b: Vector3, w: float, dark: Material, hot: Material) -> void:
	var seg := b - a
	var l := seg.length()
	if l < 0.05 or not is_instance_valid(holder):
		return
	var layers := [[dark, w, 0.0]]
	if hot:
		layers.append([hot, w * 0.4, 0.012])
	for layer in layers:
		# (each piece is a pivot carrying the box, so closing it up is one scale on x)
		var piece := Node3D.new()
		holder.add_child(piece)
		piece.global_transform = Transform3D(Basis.looking_at(seg / l, Vector3.UP), (a + b) * 0.5 + Vector3(0, layer[2], 0))
		var mi := MeshInstance3D.new()
		mi.mesh = _box()
		mi.material_override = layer[0]
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.scale = Vector3(layer[1], 0.03, l)
		piece.add_child(mi)


## A whirlwind round `follow` for `secs` (the Maelstrom): curved lines of wind on
## a funnel `radius` across at the top and `height` tall, spinning, fading in
## and out. Seeded, so every screen draws the same funnel.
func vortex(follow: Node3D, secs: float = 2.4, radius: float = 3.0, height: float = 3.0, color: Color = Color(0.9, 0.85, 0.75), seed_v: int = 0) -> void:
	if follow == null or not is_instance_valid(follow):
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var mat := _glow_mat(color, 0.0)
	var holder := Node3D.new()
	follow.add_child(holder)
	for i in range(18):
		var h := rng.randf_range(0.1, height)
		var r := radius * (0.45 + 0.55 * h / height)
		var a := rng.randf() * TAU
		var arc := rng.randf_range(0.5, 1.1)
		for k in range(3):
			var a0 := a + arc * k / 3.0
			var a1 := a + arc * (k + 1) / 3.0
			var p0 := Vector3(cos(a0) * r, h + k * 0.06, sin(a0) * r)
			var p1 := Vector3(cos(a1) * r, h + (k + 1) * 0.06, sin(a1) * r)
			var mi := MeshInstance3D.new()
			mi.mesh = _box()
			mi.material_override = mat
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			holder.add_child(mi)
			var seg := p1 - p0
			mi.transform = Transform3D(Basis.looking_at(seg.normalized(), Vector3.UP) * Basis.from_scale(Vector3(0.06, 0.06, seg.length())), (p0 + p1) * 0.5)
	var spin := holder.create_tween()
	spin.tween_property(holder, "rotation:y", -TAU * secs * 2.2, secs)
	var fade := holder.create_tween()
	fade.tween_property(mat, "albedo_color:a", 0.75, 0.2)
	fade.tween_interval(maxf(secs - 0.5, 0.0))
	fade.tween_property(mat, "albedo_color:a", 0.0, 0.3)
	fade.tween_callback(holder.queue_free)


## Cuts flashing through a body one after another (Thousand Petals): `count`
## thin lines at random angles across the space round `pos` over `secs`. Seeded,
## so every screen draws the same cuts.
func cut_lines(pos: Vector3, count: int = 10, color: Color = Color.WHITE, secs: float = 0.7, seed_v: int = 0) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam and cam.global_position.distance_to(pos) > BURST_RANGE:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var holder := Node3D.new()
	_scene_root().add_child(holder)
	var tw := holder.create_tween()
	for i in range(count):
		var c := pos + Vector3(rng.randf_range(-0.3, 0.3), rng.randf_range(0.5, 1.6), rng.randf_range(-0.3, 0.3))
		var d := Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(-0.7, 0.7), rng.randf_range(-1.0, 1.0)).normalized()
		var half := rng.randf_range(0.7, 1.25)
		tw.tween_interval(secs / count)
		tw.tween_callback(streak.bind(c - d * half, c + d * half, color, 0.07, 0.18))
	tw.tween_callback(holder.queue_free)


## Power drawn in to `pos` from all round (a wind-up, a charge): motes on a
## sphere of `radius` rushing to the middle over `secs`.
func gather(pos: Vector3, radius: float = 1.2, color: Color = Color.WHITE, secs: float = 0.4, amount: int = 16) -> void:
	if flipbooks:
		flipbook(pos, "glint", maxi(amount / 3, 4), 0.35, secs, {"shape": CPUParticles3D.EMISSION_SHAPE_SPHERE_SURFACE, "radius": radius,
			"vel_min": 0.0, "vel_max": 0.0, "radial": -2.0 * radius / (secs * secs), "gravity": Vector3.ZERO, "damping": 0.0,
			"explosiveness": 0.7, "start": 0.15, "fade": 0.9, "color": Color(color.r, color.g, color.b, 1.0)})
		return
	_burst(pos, amount, _spark_mat, 0.15, secs, {"shape": CPUParticles3D.EMISSION_SHAPE_SPHERE_SURFACE, "radius": radius,
		"vel_min": 0.0, "vel_max": 0.0, "radial": -2.0 * radius / (secs * secs), "gravity": Vector3.ZERO, "damping": 0.0,
		"grow": false, "explosiveness": 0.7, "color": Color(color.r, color.g, color.b, 1.0)})


## A dash's line through the air (a blink, a lunge): a hot core in a coloured
## sheath, thinning and fading.
func streak(from: Vector3, to: Vector3, color: Color = Color(0.4, 0.8, 1.0), width: float = 0.14, life: float = 0.3) -> void:
	var seg := to - from
	var l := seg.length()
	if l < 0.1:
		return
	var holder := Node3D.new()
	_scene_root().add_child(holder)
	holder.global_transform = Transform3D(Basis.looking_at(seg / l, Vector3.UP if absf(seg.normalized().y) < 0.95 else Vector3.FORWARD), from + seg * 0.5)
	var box := BoxMesh.new()
	box.size = Vector3.ONE
	var tw := holder.create_tween().set_parallel(true)
	for layer in [[width, color, 0.55], [width * 0.35, color.lerp(Color.WHITE, 0.7), 0.95]]:
		var mi := MeshInstance3D.new()
		mi.mesh = box
		var mat := _glow_mat(layer[1], layer[2])
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.scale = Vector3(layer[0], layer[0], l)
		holder.add_child(mi)
		tw.tween_property(mi, "scale", Vector3(float(layer[0]) * 0.15, float(layer[0]) * 0.15, l), life).set_ease(Tween.EASE_IN)
		tw.tween_property(mat, "albedo_color:a", 0.0, life).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(holder.queue_free)


## Lightning (the polearm's element): a jagged bolt from `from` to `to`, kinked at random (seeded) every ~0.35 m,
## a hot core in a coloured sheath, flickering once and gone. A few small forks off it on the longer ones.
func bolt(from: Vector3, to: Vector3, color: Color = Color(1.0, 0.9, 0.32), width: float = 0.08, life: float = 0.2, seed_v: int = 0, dark: bool = false) -> void:
	var seg := to - from
	var l := seg.length()
	if l < 0.1:
		return
	var cam := get_viewport().get_camera_3d()
	if cam and cam.global_position.distance_to(from) > BURST_RANGE:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var dir := seg / l
	var side := dir.cross(Vector3.UP if absf(dir.y) < 0.95 else Vector3.RIGHT).normalized()
	var up := side.cross(dir).normalized()
	var n := clampi(int(l / 0.35), 2, 14)
	var pts: Array = [from]
	for i in range(1, n):
		var jag := l * 0.08
		pts.append(from + seg * (float(i) / n) + side * rng.randf_range(-jag, jag) + up * rng.randf_range(-jag, jag))
	pts.append(to)
	var holder := Node3D.new()
	_scene_root().add_child(holder)
	holder.global_position = from
	var box := _box()
	# (`dark`: a black core in the coloured sheath, Meteor Fist's crackle)
	var mats: Array = [_glow_mat(color, 0.6), _star_mat(Color(0.02, 0.0, 0.02), 1.0, true) if dark else _glow_mat(color.lerp(Color.WHITE, 0.75), 1.0)]
	if dark:
		mats[1].billboard_mode = BaseMaterial3D.BILLBOARD_DISABLED
	var lines: Array = [pts]
	if l > 1.5:
		for f in range(2):
			var at: Vector3 = pts[rng.randi_range(1, pts.size() - 2)]
			var fork_to := at + (dir * 0.5 + side * rng.randf_range(-0.5, 0.5) + up * rng.randf_range(-0.3, 0.4)).normalized() * l * 0.25
			lines.append([at, at.lerp(fork_to, 0.5) + up * rng.randf_range(-0.08, 0.08), fork_to])
	for li in range(lines.size()):
		var line: Array = lines[li]
		var w := width * (1.0 if li == 0 else 0.55)
		for i in range(line.size() - 1):
			var a: Vector3 = line[i]
			var b: Vector3 = line[i + 1]
			var s := b - a
			if s.length() < 0.01:
				continue
			for layer in [[w, 0], [w * 0.4, 1]]:
				var mi := MeshInstance3D.new()
				mi.mesh = box
				mi.material_override = mats[layer[1]]
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				holder.add_child(mi)
				mi.global_transform = Transform3D(Basis.looking_at(s.normalized(), up), a + s * 0.5).scaled_local(Vector3(layer[0], layer[0], s.length() + float(layer[0]) * 0.5))
	# (a flicker: bright, a dip, bright again, then gone)
	var tw := holder.create_tween()
	tw.tween_method(func(x: float):
		var k := (1.0 - x * x) * (0.35 if x > 0.15 and x < 0.3 else 1.0)
		mats[0].albedo_color.a = 0.6 * k
		mats[1].albedo_color.a = k, 0.0, 1.0, life)
	tw.tween_callback(holder.queue_free)


## A star of light (a blade's edge catching it before a strike, a hit landing).
func glint(pos: Vector3, color: Color = Color.WHITE, size: float = 0.8) -> void:
	if flipbooks:
		flash(pos, size * 1.8, color, "glint", 0.2)
		return
	_burst(pos, 1, _spark_mat, size, 0.2, {"radius": 0.01, "vel_min": 0.0, "vel_max": 0.0, "gravity": Vector3.ZERO,
		"grow": true, "color": Color(color.r, color.g, color.b, 1.0)})
	_burst(pos, 1, _impact_mat, size * 0.6, 0.12, {"radius": 0.01, "vel_min": 0.0, "vel_max": 0.0, "gravity": Vector3.ZERO,
		"grow": true, "color": Color(1, 1, 1, 0.9)})


## Water heaving up out of the ground in curling tentacles (the Kraken's Wake):
## they lash up, hang a beat, and fall back as spray.
func water_tentacles(pos: Vector3, height: float = 3.0, color: Color = Color(0.3, 0.7, 1.0), count: int = 4, seed_v: int = 0) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam and cam.global_position.distance_to(pos) > BURST_RANGE:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(color.r, color.g, color.b, 0.8)
	var foam := _glow_mat(color.lerp(Color.WHITE, 0.75), 0.7)
	var mb := MeshBuilder.new()
	for k in range(count):
		var a := TAU * k / count + rng.randf_range(-0.4, 0.4)
		var out := Vector3(cos(a), 0, sin(a))
		var side := out.cross(Vector3.UP)
		var h := height * rng.randf_range(0.75, 1.15)
		var base := out * rng.randf_range(0.3, 0.7)
		var ctrl := out * rng.randf_range(1.2, 1.8) + Vector3.UP * h * 0.75
		var tip := out * rng.randf_range(0.2, 0.8) + side * rng.randf_range(-0.8, 0.8) + Vector3.UP * h
		var pts := MeshBuilder.curve_points(base, ctrl, tip, 10)
		mb.add_tube(mat, pts, 0.34, 0.05, 6, 1.0)
		mb.add_tube(foam, pts, 0.14, 0.02, 4, 1.0)
	var holder := Node3D.new()
	_scene_root().add_child(holder)
	holder.global_position = pos
	var inst := mb.to_instance("Tentacles")
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.add_child(inst)
	holder.scale = Vector3(1.0, 0.05, 1.0)
	var tw := holder.create_tween()
	tw.tween_property(holder, "scale", Vector3.ONE, 0.16).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.tween_interval(0.22)
	tw.tween_property(holder, "scale", Vector3(1.15, 0.15, 1.15), 0.32).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(mat, "albedo_color:a", 0.0, 0.32)
	tw.parallel().tween_property(foam, "albedo_color:a", 0.0, 0.32)
	tw.tween_callback(holder.queue_free)
	spray(pos + Vector3.UP * 0.2, Vector3.UP, 18, color.lerp(Color.WHITE, 0.6), 7.0)
	ring(pos, Vector3.UP, 2.4, color.lerp(Color.WHITE, 0.4), 0.4)


## A ribbon of water swept round an arc (the cutlass's water slashes): centred on `center`
## in the plane of `u` (where it starts) and `v` (the way it sweeps), `sweep` radians round,
## drawn on over `draw` s, then breaking up into droplets by `life`.
func water_arc(center: Vector3, u: Vector3, v: Vector3, radius: float = 1.5, sweep: float = PI, width: float = 0.5,
		draw: float = 0.1, life: float = 0.6, color: Color = Color(0.3, 0.72, 1.0), seed_v: int = 0) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam and cam.global_position.distance_to(center) > BURST_RANGE:
		return
	var r := WaterRibbon.new()
	r.center = center
	r.u = u.normalized()
	r.v = v.normalized()
	r.radius = radius
	r.sweep = sweep
	r.width = width
	r.draw = draw
	r.life = life
	r.color = color
	r.seed_v = seed_v
	_scene_root().add_child(r)


## A run of water lying along the ground from `from` to `to` (the path of a dash).
func water_wake(from: Vector3, to: Vector3, width: float = 0.6, life: float = 0.7, color: Color = Color(0.3, 0.72, 1.0), seed_v: int = 0) -> void:
	var cam := get_viewport().get_camera_3d()
	if (to - from).length() < 0.3 or cam and cam.global_position.distance_to(from) > BURST_RANGE:
		return
	var r := WaterRibbon.new()
	r.line = true
	r.center = from + Vector3(0, 0.06, 0)
	r.to = to + Vector3(0, 0.06, 0)
	r.width = width
	r.draw = 0.07
	r.life = life
	r.color = color
	r.seed_v = seed_v
	_scene_root().add_child(r)


## One of the cutlass's drawn-water sheets (gen_water_fx.py: water_slash, water_swirl,
## water_curl) played once at `pos`, rolled up to `spin` degrees either way. Unlit: the
## awakened sea keeps its colour at night.
func water_burst(pos: Vector3, sheet: String, size: float = 2.0, life: float = 0.5, spin: float = 30.0) -> void:
	flipbook(pos, sheet, 1, size, life, {"radius": 0.01, "vel_min": 0.0, "vel_max": 0.0, "gravity": Vector3.ZERO,
		"damping": 0.0, "spin": spin, "fade": 0.9, "lit": false})


## The katana's drawn slash, laid along the path the blade in `body`'s hand really takes over
## the next `secs` (a PetalRibbon; gen_katana_fx.py): a thin crescent of steel, or with the
## element awakened a billowing cloud that sheds petals. `thrust`: along the blade's line (a
## stab). Other screens lay their own along their copy of the body, which plays the same swing.
func katana_slash(body: Node3D, secs: float, awake: bool = false, width: float = 0.34, thrust: bool = false, seed_v: int = 0) -> void:
	drawn_slash(body, "katana", secs, awake, width, thrust, seed_v)


## A weapon's drawn slash (PetalRibbon.LOOKS: a tree's id) laid along the path the blade in `body`'s hand (`left`:
## the off hand's) takes over the next `secs`; the axe's along its bit.
func drawn_slash(body: Node3D, kind: String, secs: float, awake: bool = false, width: float = 0.34, thrust: bool = false, seed_v: int = 0,
		left: bool = false) -> void:
	if AnimLab.clean or not body is Humanoid:
		return
	var cam := get_viewport().get_camera_3d()
	if cam and cam.global_position.distance_to(body.global_position) > BURST_RANGE:
		return
	var r := PetalRibbon.new()
	r.body = body
	r.kind = kind
	r.emit = secs
	r.awake = awake
	r.width = width
	r.thrust = thrust
	r.seed_v = seed_v
	r.left = left
	r.linger = (0.48 if awake else 0.3) if kind == "axe" else (0.42 if awake else 0.26)
	body.add_child(r)


## One of the katana's drawn sheets (gen_katana_fx.py: steel_slash, katana_slash, katana_cloud)
## played once at `pos`, rolled up to `spin` degrees either way. Unlit, like the drawn water.
func katana_burst(pos: Vector3, sheet: String, size: float = 1.6, life: float = 0.45, spin: float = 30.0) -> void:
	drawn_burst(pos, sheet, size, life, spin)


## One drawn sheet (the katana's, gen_katana_fx.py; the axe's, gen_axe_fx.py: axe_slash,
## ember_slash, ember_cloud) played once at `pos`, rolled up to `spin` degrees either way. Unlit.
func drawn_burst(pos: Vector3, sheet: String, size: float = 1.6, life: float = 0.45, spin: float = 30.0) -> void:
	flipbook(pos, sheet, 1, size, life, {"radius": 0.01, "vel_min": 0.0, "vel_max": 0.0, "gravity": Vector3.ZERO,
		"damping": 0.0, "spin": spin, "fade": 0.9, "lit": false})


## Drawn cinders thrown along `dir` (the axe's element): each flares white-hot and cools to a
## dull red speck as it slows and drifts up. One burst, unlit.
func cinders(pos: Vector3, dir: Vector3, amount: int = 6, speed: float = 3.0, size: float = 0.16) -> void:
	flipbook(pos, "cinder", amount, size, 0.85, {"radius": 0.18, "direction": dir.normalized(), "spread": 45.0,
		"vel_min": speed * 0.4, "vel_max": speed, "gravity": Vector3(0, 1.4, 0), "damping": 2.6, "hold": true,
		"scale_min": 0.7, "scale_max": 1.3, "explosiveness": 0.9, "fade": 0.85, "lit": false})


var _ash_mat: StandardMaterial3D


## The drawn cinder on a quad of `size` (BladeEmbers' emitter): each plays the sheet once over its life.
func cinder_quad(size: float) -> QuadMesh:
	return _quad(size, _flip_mat("cinder"))


func _ash() -> StandardMaterial3D:
	if _ash_mat == null:
		_ash_mat = _flip_mat("ash").duplicate()
		_ash_mat.particles_anim_loop = true
	return _ash_mat


## The drawn ash flake on a quad of `size` (BladeEmbers' emitter).
func ash_quad(size: float) -> QuadMesh:
	return _quad(size, _ash())


## Flakes of ash let go along `dir`, tumbling as they drift slowly down (dimmed at night).
func ash(pos: Vector3, dir: Vector3, amount: int = 4, speed: float = 1.0, size: float = 0.16) -> void:
	var k := _night_k()
	var cfg := {"radius": 0.3, "direction": dir.normalized(), "spread": 60.0, "vel_min": speed * 0.3, "vel_max": speed,
		"gravity": Vector3(0, -0.5, 0), "damping": 2.0, "hold": true, "scale_min": 0.7, "scale_max": 1.2, "explosiveness": 0.7,
		"ramp": _flip_ramp(Color(k, k, k), 0.0, 0.7), "start": 1.0, "spin": 180.0}
	var p := _burst(pos, amount, _ash(), size, 2.0, cfg)
	if p:
		_flip_setup(p, cfg)
		p.anim_speed_min = 1.0
		p.anim_speed_max = 2.0


## A run of the katana's drawn strip along `from` to `to` (the path of a dash or a blink), drawn on
## over `secs`, standing up off the line (crest up) so it reads from behind.
func katana_line(from: Vector3, to: Vector3, width: float = 0.5, awake: bool = false, secs: float = 0.08, seed_v: int = 0) -> void:
	var cam := get_viewport().get_camera_3d()
	if (to - from).length() < 0.3 or cam and cam.global_position.distance_to(from) > BURST_RANGE:
		return
	var path: Array = []
	for i in 12:
		var p := from.lerp(to, float(i) / 11.0)
		path.append([p - Vector3.UP * 0.4, p])
	_katana_path(path, width, awake, secs, seed_v)


## The katana's drawn strip swept round an arc (centred on `center` in the plane of `u`, where it
## starts, and `v`, the way it sweeps; `sweep` radians round), drawn on over `secs`, its crest outside.
func katana_arc(center: Vector3, u: Vector3, v: Vector3, radius: float = 2.0, sweep: float = PI, width: float = 0.8,
		awake: bool = false, secs: float = 0.12, seed_v: int = 0) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam and cam.global_position.distance_to(center) > BURST_RANGE:
		return
	var path: Array = []
	var n := clampi(int(absf(sweep) * radius / 0.35), 8, 64)
	for i in n + 1:
		var a := sweep * float(i) / n
		path.append([center, center + (u.normalized() * cos(a) + v.normalized() * sin(a)) * radius])
	_katana_path(path, width, awake, secs, seed_v)


## A weapon's drawn strip (PetalRibbon.LOOKS: "katana", "axe") swept round an arc like katana_arc, the crest outside.
func drawn_arc(kind: String, center: Vector3, u: Vector3, v: Vector3, radius: float = 2.0, sweep: float = PI, width: float = 0.8,
		awake: bool = false, secs: float = 0.12, seed_v: int = 0) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam and cam.global_position.distance_to(center) > BURST_RANGE:
		return
	var path: Array = []
	var n := clampi(int(absf(sweep) * radius / 0.35), 8, 64)
	for i in n + 1:
		var a := sweep * float(i) / n
		path.append([center, center + (u.normalized() * cos(a) + v.normalized() * sin(a)) * radius])
	_katana_path(path, width, awake, secs, seed_v, kind)


func _katana_path(path: Array, width: float, awake: bool, secs: float, seed_v: int, kind: String = "katana") -> void:
	var r := PetalRibbon.new()
	r.kind = kind
	r.fixed = path
	r.emit = secs
	r.awake = awake
	r.width = width
	r.seed_v = seed_v
	r.linger = 0.5 if awake else 0.3
	_scene_root().add_child(r)


var _sakura_mat: StandardMaterial3D


func _sakura() -> StandardMaterial3D:
	if _sakura_mat == null:
		_sakura_mat = _flip_mat("sakura").duplicate()
		_sakura_mat.particles_anim_loop = true
	return _sakura_mat


## The drawn petal on a quad of `size` (BladePetals' emitter).
func sakura_quad(size: float) -> QuadMesh:
	return _quad(size, _sakura())


## Drawn sakura petals thrown along `dir`, turning over and over as they drift down (the
## katana's element; `petals` is the plain tinted kind other things throw).
func sakura(pos: Vector3, dir: Vector3, amount: int = 6, speed: float = 3.0, size: float = 0.26, area: float = 0.25) -> void:
	var cfg := {"radius": area, "direction": dir.normalized(), "spread": 55.0, "vel_min": speed * 0.35, "vel_max": speed,
		"gravity": Vector3(0, -1.2, 0), "damping": 2.4, "hold": true, "scale_min": 0.7, "scale_max": 1.2, "explosiveness": 0.85,
		"ramp": _flip_ramp(Color(_night_k() * 0.35 + 0.65, _night_k() * 0.35 + 0.65, _night_k() * 0.35 + 0.65), 0.0, 0.75), "start": 1.0, "spin": 180.0}
	var p := _burst(pos, amount, _sakura(), size, 1.8, cfg)
	if p:
		_flip_setup(p, cfg)
		p.anim_speed_min = 1.5
		p.anim_speed_max = 2.5


## Droplets of water thrown along `dir` that fall back (spray without its mist).
func droplets(pos: Vector3, dir: Vector3, amount: int = 6, color: Color = Color(0.85, 0.95, 1.0), speed: float = 4.0) -> void:
	_burst(pos, amount, _dust_mat, 0.16, 0.6, {"radius": 0.1, "direction": dir.normalized(), "spread": 35.0,
		"vel_min": speed * 0.5, "vel_max": speed, "gravity": Vector3(0, -12.0, 0), "damping": 0.8, "grow": false,
		"hold": true, "color": Color(color.r, color.g, color.b, 0.95)})


## A blow landing with the weapon's element awakened (its tree's second mastery
## passive): the tree's material thrown off the hit along `dir`.
func elem_hit(tree: String, pos: Vector3, dir: Vector3) -> void:
	var edge := tree_col(tree, EDGE)
	var accent := tree_col(tree, ACCENT)
	# (the drawn elements: their slash cut through them and a ring in place of the old material)
	if flipbooks and DRAWN.has(tree):
		drawn_burst(pos + dir * 0.15, DRAWN[tree] + "_slash", 1.5, 0.32, 180.0)
		ring(pos, dir, 0.8, edge, 0.16, 0.16)
		return
	match tree:
		"sword":
			spray(pos, dir + Vector3.UP * 0.3, 8, accent, 5.0)
			ring(pos, dir, 0.9, edge, 0.18, 0.2)
		"katana":
			# a drawn crescent of cloud cut through them, a puff, petals thrown off
			katana_burst(pos + dir * 0.15, "katana_slash", 1.8, 0.35, 180.0)
			katana_burst(pos + dir * 0.4 + Vector3.UP * 0.2, "katana_cloud", 1.1, 0.45, 40.0)
			sakura(pos, dir + Vector3.UP * 0.4, 5, 3.0)
		"axe":
			# a drawn crescent of fire bitten through them, a gout of it, cinders thrown off
			drawn_burst(pos + dir * 0.15, "ember_slash", 1.9, 0.35, 180.0)
			drawn_burst(pos + dir * 0.4 + Vector3.UP * 0.2, "ember_cloud", 1.1, 0.45, 40.0)
			cinders(pos, dir + Vector3.UP * 0.4, 5, 3.5)
		"dual":
			twin_cross(pos, dir, 0.45, edge, accent, 0.2)
			motes(pos, dir + Vector3.UP * 0.3, 6, accent, 3.5)
		"corsair":
			powder_burst(pos, dir, 0.6, edge)
		"dagger":
			shadow_wisps(pos, dir + Vector3.UP * 0.3, 6, edge, 3.0)
			ring(pos, dir, 0.8, edge, 0.16, 0.14)
		"dual_dagger":
			poison(pos, 3, 0.3)
			motes(pos, dir + Vector3.UP * 0.3, 5, accent, 3.5)
			ring(pos, dir, 0.8, edge, 0.16, 0.14)
		"polearm":
			bolt(pos, pos + (dir + Vector3.UP * 0.6).normalized() * 0.9, edge, 0.06, 0.14, randi() % 1000)
			muzzle_sparks(pos, dir, 6, edge)
			ring(pos, dir, 0.8, accent, 0.16, 0.14)
		"hammer":
			debris(pos, dir + Vector3.UP * 0.5, 5, accent, 4.0)
			ring(pos, dir, 1.0, edge, 0.2, 0.22)
			dust(pos, 3, 0.5)
		"dual_axe":
			frost(pos, dir + Vector3.UP * 0.4, 7, 3.5)
			ring(pos, dir, 0.8, edge, 0.16, 0.18)
		"greatsword":
			gust(pos, dir + Vector3.UP * 0.2, 7, 4.0)
			ring(pos, dir, 1.0, edge, 0.18, 0.14)
		"black_leg":
			heat(pos, dir + Vector3.UP * 0.3, 6, 3.5)
			ring(pos, dir, 0.9, edge, 0.16, 0.2)
		_:
			sparkle(pos, 6, accent)
			ring(pos, dir, 0.8, edge, 0.18, 0.2)


## A flash over the whole screen (an ultimate's moment), for a camera near `at`.
func screen_flash(at: Vector3, color: Color = Color(1, 1, 1, 0.5), secs: float = 0.25) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null or cam.global_position.distance_to(at) > 35.0:
		return
	var layer := CanvasLayer.new()
	layer.layer = 60
	var r := ColorRect.new()
	r.color = color
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(r)
	_scene_root().add_child(layer)
	var tw := layer.create_tween().set_ignore_time_scale(true)
	tw.tween_property(r, "color:a", 0.0, secs).set_ease(Tween.EASE_IN)
	tw.tween_callback(layer.queue_free)


# --------------------------------------------------------------------------
# Slash trails
# --------------------------------------------------------------------------
## A strike's trail traced by the real blade (moves with a swing path): the weapons in
## `body`'s hands draw a fading ribbon for `secs` (the off hand's in `color_l` if given:
## the dual blades' paired trails). Other screens replay it on their copy of the body,
## which plays the same animation.
func blade_swoosh(body: Node3D, secs: float, color: Color = Color(0.45, 0.75, 1.0), color_l: Color = Color(0, 0, 0, 0)) -> void:
	# (the anim lab's clean view already draws the blade's trail)
	if AnimLab.clean or not body is Humanoid:
		return
	var t := BladeTrail.new()
	t.body = body
	t.emit = secs
	t.color = color
	t.color_l = color_l if color_l.a > 0.0 else color
	t.life = 0.14
	body.add_child(t)


## kind: "right" (right-to-left), "left" (backhand), "spin" (full circle),
## "overhead" (vertical chop). The trail is parented to `follow` (the player
## model) so it sweeps with the character.
func slash(follow: Node3D, kind: String, duration: float = 0.25, color: Color = Color(0.45, 0.75, 1.0)) -> void:
	# (the anim lab's clean view swaps these arcs for the blade's own trail)
	if AnimLab.clean:
		return
	var mi := MeshInstance3D.new()
	mi.mesh = _slash_mesh(kind)
	mi.material_override = _slash_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	follow.add_child(mi)
	mi.position = Vector3(0, 1.05, 0)
	mi.set_instance_shader_parameter("progress", 0.0)
	mi.set_instance_shader_parameter("fade", 1.0)
	if not color.is_equal_approx(Color(0.45, 0.75, 1.0)):
		mi.set_instance_shader_parameter("edge_override", Color(color.r, color.g, color.b, 1.0))
	var tail := 0.85 if kind == "spin" else 0.55
	var tw := mi.create_tween()
	tw.tween_method(func(v: float): mi.set_instance_shader_parameter("progress", v), 0.0, 1.0 + tail, duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.parallel().tween_method(func(v: float): mi.set_instance_shader_parameter("fade", v), 1.0, 0.0, duration).set_delay(duration * 0.45)
	tw.tween_callback(mi.queue_free)


func _slash_mesh(kind: String) -> ArrayMesh:
	if _slash_meshes.has(kind):
		return _slash_meshes[kind]
	# arc in the plane spanned by u (angle 0) and v (angle +90 deg)
	var u := Vector3.RIGHT
	var v := Vector3.FORWARD
	var a0 := -0.5
	var a1 := PI + 0.5
	var r0 := 0.45
	var r1 := 1.75
	var tilt := Basis()
	match kind:
		"right":
			tilt = Basis(Vector3.FORWARD, 0.28)
		"left":
			a0 = PI + 0.5
			a1 = -0.5
			tilt = Basis(Vector3.FORWARD, -0.28)
		"kesa_r":
			# katana: the long diagonal of the first cut
			a0 = PI + 0.5
			a1 = -0.5
			tilt = Basis(Vector3.FORWARD, 0.75)
			r1 = 2.15
		"sweep_l":
			# katana: the wide, nearly flat second cut
			a0 = -0.6
			a1 = PI + 0.6
			tilt = Basis(Vector3.FORWARD, -0.12)
			r1 = 2.15
		"iai":
			# katana drawing cut (same way as sweep_l): the widest, flattest arc
			a0 = -0.8
			a1 = PI + 0.75
			tilt = Basis(Vector3.FORWARD, -0.06)
			r0 = 0.5
			r1 = 2.7
		"spin":
			# the spin finisher turns clockwise seen from above, starting on the right
			a0 = 0.2
			a1 = 0.2 - TAU
			r1 = 2.0
		"under":
			# katana air attack: from up on the left, down under the feet and up
			# out to the right (the plane leaned forward: it cuts ahead and below)
			u = Vector3.RIGHT
			v = Vector3.UP
			a0 = deg_to_rad(160.0)
			a1 = deg_to_rad(380.0)
			tilt = Basis(Vector3.RIGHT, 0.65)
			r0 = 0.5
			r1 = 2.2
		"overhead":
			u = Vector3.FORWARD
			v = Vector3.UP
			a0 = deg_to_rad(150.0)
			a1 = deg_to_rad(-55.0)
			r0 = 0.5
			r1 = 1.9
	if kind == "thrust":
		return _thrust_mesh()
	var segs := 28
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	for i in range(segs + 1):
		var t := float(i) / segs
		var a := lerpf(a0, a1, t)
		var d := (u * cos(a) + v * sin(a))
		verts.append(tilt * (d * r0))
		verts.append(tilt * (d * r1))
		uvs.append(Vector2(t, 0.0))
		uvs.append(Vector2(t, 1.0))
		if i < segs:
			var b := i * 2
			idx.append_array([b, b + 1, b + 2, b + 1, b + 3, b + 2])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_slash_meshes[kind] = mesh
	return mesh


## Straight streak forward for thrusts: narrow at the tip, sweeping out along
## its length with the same progress/fade shader as the arcs.
func _thrust_mesh() -> ArrayMesh:
	var segs := 12
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	for i in range(segs + 1):
		var t := float(i) / segs
		var z := -lerpf(0.35, 2.4, t)
		var w := lerpf(0.16, 0.03, t)
		var p := Vector3(0.18, 0.12, z)
		verts.append(p + Vector3(-w, -w * 0.4, 0))
		verts.append(p + Vector3(w, w * 0.4, 0))
		uvs.append(Vector2(t, 0.0))
		uvs.append(Vector2(t, 1.0))
		if i < segs:
			var b := i * 2
			idx.append_array([b, b + 1, b + 2, b + 1, b + 3, b + 2])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_slash_meshes["thrust"] = mesh
	return mesh


# --------------------------------------------------------------------------
# Sounds
# --------------------------------------------------------------------------
## Positional one-shot on the SFX bus. pitch_jitter randomizes pitch +-.
func sfx(sound_name: String, pos: Vector3, volume_db: float = 0.0, pitch_jitter: float = 0.08, pitch: float = 1.0) -> void:
	if not _streams.has(sound_name):
		return
	# (past its max_distance nobody hears it: don't make it)
	var cam := get_viewport().get_camera_3d()
	if cam and cam.global_position.distance_squared_to(pos) > 64.0 * 64.0:
		return
	var p := AudioStreamPlayer3D.new()
	p.stream = _streams[sound_name]
	p.bus = "SFX"
	p.volume_db = volume_db
	p.unit_size = 6.0
	p.max_distance = 60.0
	p.pitch_scale = pitch * randf_range(1.0 - pitch_jitter, 1.0 + pitch_jitter)
	_scene_root().add_child(p)
	p.global_position = pos
	p.play()
	p.finished.connect(p.queue_free)
