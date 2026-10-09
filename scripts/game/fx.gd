extends Node
## One-shot visual + audio effects (autoload "FX"): dust puffs and rings,
## sparkles, hit impacts, sword slash trails and positional sounds.
## Everything is spawned on demand and frees itself.

const SLASH_SHADER := preload("res://shaders/psx/slash_trail.gdshader")
const SOUNDS := {
	"whoosh": "res://assets/audio/whoosh.wav",
	"whoosh_big": "res://assets/audio/whoosh_big.wav",
	"hit": "res://assets/audio/hit.wav",
	"step": "res://assets/audio/step.wav",
	"jump": "res://assets/audio/jump.wav",
	"land": "res://assets/audio/land.wav",
	"chitter": "res://assets/audio/chitter.wav",
	"bug_hiss": "res://assets/audio/bug_hiss.wav",
	"thud": "res://assets/audio/thud.wav",
	"coin": "res://assets/audio/coin.wav",
	"splash": "res://assets/audio/splash.wav",
	"blip_high": "res://assets/audio/blip_high.wav",
	"blip_low": "res://assets/audio/blip_low.wav",
	"gunshot": "res://assets/audio/gunshot.wav",
	"parry": "res://assets/audio/parry.wav",
	"fire_burst": "res://assets/audio/fire_burst.wav",
	"fire_blast": "res://assets/audio/fire_blast.wav",
	"crunch": "res://assets/audio/crunch.wav",
	"howl": "res://assets/audio/howl.wav",
	"haki": "res://assets/audio/haki.wav",
	"block": "res://assets/audio/block.wav",
	"peril": "res://assets/audio/peril.wav",
	"bell": "res://assets/audio/bell.wav",
	"cannon": "res://assets/audio/cannon.wav",
	"cannon_hit": "res://assets/audio/cannon_hit.wav",
	"horn": "res://assets/audio/horn.wav",
	"roar": "res://assets/audio/roar.wav",
	"rope": "res://assets/audio/rope.wav",
	"splash_big": "res://assets/audio/splash_big.wav",
	"wood_crack": "res://assets/audio/wood_crack.wav",
}

var _dust_mat: StandardMaterial3D
var _spark_mat: StandardMaterial3D
var _impact_mat: StandardMaterial3D
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
var _streams: Dictionary = {}
var _slash_meshes: Dictionary = {}


func _ready() -> void:
	_dust_mat = _billboard_mat("res://assets/textures/fx/dust.png", false)
	_spark_mat = _billboard_mat("res://assets/textures/fx/sparkle.png", true)
	_impact_mat = _billboard_mat("res://assets/textures/fx/impact.png", true)
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
	for k in SOUNDS.keys():
		_streams[k] = load(SOUNDS[k])


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
	if _tele_mat == null:
		_tele_mat = StandardMaterial3D.new()
		_tele_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_tele_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_tele_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_tele_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		_tele_mat.vertex_color_use_as_albedo = true
		_ring_mesh = _annulus(0.88, 1.0)
		_disc_mesh = _annulus(0.0, 1.0)
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
	_burst(pos, amount, _dust_mat, size, 0.55, {
		"radius": 0.15, "spread": 70.0, "vel_min": 0.5, "vel_max": 1.4, "gravity": Vector3(0, 0.4, 0), "damping": 3.0})


## A chimney's thin smoke, rising and drifting for good (under `parent`).
func chimney_smoke(parent: Node3D, pos: Vector3) -> CPUParticles3D:
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
	mi.mesh = _splat_mesh(directed)
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
func _splat_mesh(directed: bool) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	var blobs := [[Vector2.ZERO, 1.0]]
	for i in range(randi_range(1, 3)):
		var a := randf() * TAU
		blobs.append([Vector2(cos(a), sin(a)) * randf_range(0.35, 0.7), randf_range(0.45, 0.8)])
	for i in range(randi_range(4, 10)):
		var a := randf_range(-0.9, 0.9) if directed and randf() < 0.75 else randf() * TAU
		blobs.append([Vector2(cos(a), sin(a)) * randf_range(1.1, 2.6), randf_range(0.06, 0.26)])
	for bl in blobs:
		var c: Vector2 = bl[0]
		var r: float = bl[1]
		var seg := 14 if r > 0.4 else 6
		var ph1 := randf() * TAU
		var ph2 := randf() * TAU
		var rim: Array = []
		for k in range(seg):
			var a := float(k) / seg * TAU
			var lump := 1.0 + 0.22 * sin(3.0 * a + ph1) + 0.12 * sin(5.0 * a + ph2)
			rim.append(c + Vector2(cos(a), sin(a)) * r * lump * randf_range(0.9, 1.08))
		var mid := Color(0.9, 0.9, 0.9)
		for k in range(seg):
			var p0: Vector2 = rim[k]
			var p1: Vector2 = rim[(k + 1) % seg]
			st.set_color(mid)
			st.add_vertex(Vector3(c.x, 0, c.y))
			st.set_color(Color.WHITE)
			st.add_vertex(Vector3(p1.x, 0, p1.y))
			st.add_vertex(Vector3(p0.x, 0, p0.y))
	for i in range(randi_range(2, 5)):
		var a := randf_range(-0.7, 0.7) if directed else randf() * TAU
		var dv := Vector2(cos(a), sin(a))
		var side := Vector2(-dv.y, dv.x) * randf_range(0.08, 0.16)
		var tip := dv * randf_range(1.25, 1.75)
		st.set_color(Color.WHITE)
		for p in [dv * 0.7 + side, tip, dv * 0.7 - side]:
			st.add_vertex(Vector3(p.x, 0, p.y))
	return st.commit()


func sparkle(pos: Vector3, amount: int = 8, color: Color = Color(1.0, 0.95, 0.6)) -> void:
	_burst(pos, amount, _spark_mat, 0.22, 0.6, {
		"radius": 0.25, "spread": 180.0, "vel_min": 1.0, "vel_max": 2.8, "gravity": Vector3(0, -3.0, 0),
		"damping": 2.0, "grow": false, "color": Color(color.r, color.g, color.b, 1.0)})


## Sea spray: white droplets thrown up and falling back (bow wave, wake).
func splash(pos: Vector3, amount: int = 4, size: float = 0.6) -> void:
	_burst(pos, amount, _dust_mat, size, 0.7, {
		"radius": 0.3, "spread": 35.0, "vel_min": 1.2, "vel_max": 2.6, "gravity": Vector3(0, -7.0, 0), "damping": 0.5,
		"color": Color(0.92, 0.97, 1.0, 0.85)})


## Powder smoke: soft grey puffs that swell, drift up and linger.
func smoke(pos: Vector3, amount: int = 6, size: float = 0.8, life: float = 1.6) -> void:
	_burst(pos, amount, _dust_mat, size, life, {
		"radius": 0.15, "spread": 70.0, "vel_min": 0.2, "vel_max": 0.8, "gravity": Vector3(0, 0.45, 0),
		"damping": 1.2, "explosiveness": 0.9, "color": Color(0.72, 0.72, 0.7, 0.75)})


## Gunshot sparks: a hot spray out of the muzzle along `dir`.
func muzzle_sparks(pos: Vector3, dir: Vector3, amount: int = 10) -> void:
	_burst(pos, amount, _spark_mat, 0.16, 0.3, {
		"radius": 0.04, "direction": dir, "spread": 16.0, "vel_min": 5.0, "vel_max": 10.0,
		"gravity": Vector3(0, -4.0, 0), "damping": 6.0, "grow": false, "color": Color(1.0, 0.75, 0.35)})


## Hit impact: a flash plus a spray of sparks.
func impact(pos: Vector3, color: Color = Color(1.0, 0.9, 0.55)) -> void:
	_burst(pos, 1, _impact_mat, 0.9, 0.12, {"radius": 0.01, "vel_min": 0.0, "vel_max": 0.0, "gravity": Vector3.ZERO,
		"grow": true, "color": Color(1, 1, 1, 1)})
	_burst(pos, 10, _spark_mat, 0.18, 0.4, {"radius": 0.1, "spread": 180.0, "vel_min": 3.0, "vel_max": 6.0,
		"gravity": Vector3(0, -9.0, 0), "damping": 4.0, "grow": false, "color": color})


## Parry: a white flash where the blades meet, a hot spray of sparks thrown
## back toward the attacker (`dir`) and a few slow glints hanging in the air.
func parry_sparks(pos: Vector3, dir: Vector3) -> void:
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
	var t := holder.get_tree().create_timer(secs + 2.0)
	t.timeout.connect(func():
		if is_instance_valid(holder):
			holder.queue_free())


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
	_burst(pos, amount, _flame_mat, size, life, {"radius": radius, "spread": 35.0, "vel_min": 1.0, "vel_max": 2.6,
		"gravity": Vector3(0, 2.5, 0), "damping": 2.0, "explosiveness": 0.85, "ramp": _flame_ramp})


## A ring of fire racing outward along the ground (fire ring, inferno).
func fire_ring(pos: Vector3, radius: float = 4.0, amount: int = 40) -> void:
	var speed := radius / 0.35
	_burst(pos + Vector3(0, 0.25, 0), amount, _flame_mat, 0.9, 0.5, {"ring_radius": 0.4, "spread": 8.0,
		"direction": Vector3(0, 0.15, 0), "vel_min": speed * 0.85, "vel_max": speed, "radial": 0.0,
		"gravity": Vector3(0, 3.0, 0), "damping": speed * 1.6, "ramp": _flame_ramp})
	flame(pos + Vector3(0, 0.3, 0), 14, 1.0, 0.6, 0.6)


## The ultimate: a column of fire and a rolling wave of flame along the ground.
func fire_pillar(pos: Vector3, radius: float = 7.0) -> void:
	_burst(pos, 36, _flame_mat, 1.6, 1.1, {"radius": 0.8, "spread": 12.0, "vel_min": 6.0, "vel_max": 13.0,
		"gravity": Vector3(0, -2.0, 0), "damping": 3.0, "explosiveness": 0.9, "ramp": _flame_ramp})
	fire_ring(pos, radius, 70)
	impact(pos + Vector3(0, 1.0, 0), Color(1.0, 0.7, 0.3))
	smoke(pos + Vector3(0, 1.5, 0), 10, 1.8, 2.6)


## A flame emitter that keeps burning until freed (fire zones, burning
## enemies, the fireball's trail). world: particles stay where they were
## emitted (trails); otherwise they ride with the parent.
func flame_emitter(parent: Node3D, radius: float = 0.3, amount: int = 16, size: float = 0.5, life: float = 0.6, world: bool = false) -> CPUParticles3D:
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
	"axe": [Color(1.0, 0.9, 0.6), Color(1.0, 0.5, 0.15), Color(0.55, 0.42, 0.3)],
	"dual": [Color(0.95, 0.98, 1.0), Color(0.35, 0.9, 0.95), Color(0.75, 0.45, 1.0)],
	"pistol": [Color(1.0, 0.95, 0.75), Color(1.0, 0.75, 0.25), Color(0.7, 0.7, 0.68)],
	"unarmed": [Color(1.0, 1.0, 1.0), Color(1.0, 0.95, 0.85), Color(0.95, 0.75, 0.45)],
	"haki": [Color(1.0, 0.85, 0.85), Color(0.9, 0.12, 0.18), Color(0.1, 0.02, 0.04)],
}
const CORE := 0
const EDGE := 1
const ACCENT := 2

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
	_burst(pos, maxi(amount / 3, 2), _dust_mat, 0.55, 0.55, {"radius": 0.2, "direction": dir.normalized(), "spread": 40.0,
		"vel_min": 0.6, "vel_max": 1.6, "gravity": Vector3(0, 0.3, 0), "damping": 2.0, "color": Color(color.r, color.g, color.b, 0.45)})


## Power drawn in to `pos` from all round (a wind-up, a charge): motes on a
## sphere of `radius` rushing to the middle over `secs`.
func gather(pos: Vector3, radius: float = 1.2, color: Color = Color.WHITE, secs: float = 0.4, amount: int = 16) -> void:
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


## A star of light (a blade's edge catching it before a strike, a hit landing).
func glint(pos: Vector3, color: Color = Color.WHITE, size: float = 0.8) -> void:
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
## `body`'s hands draw a fading ribbon for `secs`. Other screens replay it on their copy of
## the body, which plays the same animation.
func blade_swoosh(body: Node3D, secs: float, color: Color = Color(0.45, 0.75, 1.0)) -> void:
	# (the anim lab's clean view already draws the blade's trail)
	if AnimLab.clean or not body is Humanoid:
		return
	var t := BladeTrail.new()
	t.body = body
	t.emit = secs
	t.color = color
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
