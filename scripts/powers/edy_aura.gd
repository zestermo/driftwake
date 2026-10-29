class_name EdyAura
extends Node
## An Edy aura on a body (EdyTypes), in the captain's type's colour and look, faded in, burning for `secs`, faded out.
## (1.26, docs/v1_26_plan.md: the whole-body glow and the tall flame were too big, Storm's worst; Zach picked the Edy
## tree mock's subtle sketches) Small effects off the limbs, by look:
##   haze       Still: soft puffs drifting up slowly off the limb
##   crackle    Ember: quick sparks flicking up and out
##   shimmer    Crown: brief twinkling glints round it
##   lightning  Storm: short jagged arcs snapping off the limb (EdyArcs) and a few sparks
##   swirl      Tide: motes orbiting the limb
## Where: "arms" (Infuse) the hands; "legs" (Infuse in the kicking stance) the feet; "body" (a big Edy move's flare) and
## "reinforce" hands and feet; Reinforce also lays its disc underfoot in the type's shape (shaders/psx/edy_ground.gdshader:
## it sits on the ground; when the feet leave it, it lingers where they stood and fades). Shown on every screen through
## FX.edy_aura (Net.fx). A second call on a body with one running extends it and widens it to the bigger part.
## `flash_on` makes it flare a moment (Reinforce shrugging off a blow). GPU particles (an emitter a limb), the arcs a few
## line segments a few times a second; the CPU only fades it. Sound: a held aura (Infuse, Reinforce: HUM_MIN or longer)
## channels its type's hum (edy_hum_<type>, looped, faded with it); a short flare whooshes once (edy_flash).

const GROUND := preload("res://shaders/psx/edy_ground.gdshader")
const RIM := preload("res://shaders/psx/edy_aura.gdshader")
## (Zach: "a little bit of aura") the outline's strength and width: a light glow on the limbs at work (the whole body
## for Reinforce), not the full blaze it was.
const RIM_K := 0.45
const RIM_GROW := 0.015
const LOOKS := {"haze": 0, "crackle": 1, "shimmer": 2, "lightning": 3, "swirl": 4}
const RANK := {"arms": 0, "legs": 0, "body": 1, "reinforce": 2}
const FADE_IN := 0.18
const FADE_OUT := 0.45
const FLASH_DECAY := 3.0
const DISC := 1.5
## A held aura hums; shorter ones are flares and whoosh.
const HUM_MIN := 3.0
const HUM_DB := -10.0
## The ground disc: how fast it fades after the feet leave it, and comes back on landing.
const GROUND_OUT := 4.0
const GROUND_IN := 7.0
## A foot's emitter sits this far down the shin from the knee.
const FOOT_DOWN := 0.45
## The cylinder round a limb the particles are born on (m).
const LIMB_R := 0.08
## Storm's arcs: one every ARC_EVERY s a limb (random within), lit ARC_LIFE s, from a point on the limb to another on it or a limb within ARC_REACH.
const ARC_EVERY := Vector2(0.06, 0.22)
## How far an arc reaches to another limb (m).
const ARC_REACH := 0.9
const ARC_LIFE := 0.07

var part := "body"
var left := 0.0
var look := "haze"
var color := Color.WHITE
var _t := 0.0
var _flash := 0.0
var _ground: ShaderMaterial
var _rim: ShaderMaterial
var _shells: Array[MeshInstance3D] = []
var _emitters: Array[GPUParticles3D] = []
var _anchors: Array[Node3D] = []
var _disc: MeshInstance3D
var _mover: CharacterBody3D
var _ground_k := 0.0
var _last_y := 0.0
var _hum: AudioStreamPlayer3D
var _arcs: MeshInstance3D
var _arc_mesh: ImmediateMesh
var _arc_next: Array = []
var _arc_live: Array = []
var _rng := RandomNumberGenerator.new()
static var _dot_tex: Texture2D
static var _soft_tex: Texture2D


## The aura on `body` (a Humanoid) for `secs`, in `color` and `look` (EdyTypes' look name).
static func show_on(body: Node3D, which: String, secs: float, color_: Color, look_: String) -> EdyAura:
	if body == null or not is_instance_valid(body):
		return null
	var a := body.get_node_or_null("EdyAura") as EdyAura
	var rebuild := false
	if a == null:
		a = EdyAura.new()
		a.name = "EdyAura"
		a.part = which
		a._ground = ShaderMaterial.new()
		a._ground.shader = GROUND
		a._ground.set_shader_parameter("strength", 0.0)
		a._rim = ShaderMaterial.new()
		a._rim.shader = RIM
		a._rim.set_shader_parameter("strength", 0.0)
		a._rim.set_shader_parameter("grow", RIM_GROW)
		body.add_child(a)
		rebuild = true
	elif int(RANK.get(which, 1)) > int(RANK.get(a.part, 1)):
		a.part = which
		rebuild = true
	rebuild = rebuild or a.look != look_ or a.color != color_
	a.left = maxf(a.left, secs)
	a.look = look_
	a.color = color_
	a._ground.set_shader_parameter("color", color_)
	a._ground.set_shader_parameter("look", int(LOOKS.get(look_, 0)))
	a._rim.set_shader_parameter("color", color_)
	a._rim.set_shader_parameter("look", int(LOOKS.get(look_, 0)))
	if rebuild:
		a._build(body)
	if secs >= HUM_MIN:
		a._start_hum(body, look_)
	else:
		var fx := body.get_node_or_null("/root/FX")
		if fx:
			fx.sfx("edy_flash", body.global_position + Vector3(0, 1.0, 0), -6.0, 0.08)
	return a


## The type's channelling hum, looped on the body while the aura's held (its type from the look name).
func _start_hum(body: Node3D, look_: String) -> void:
	var typ := ""
	for id in EdyTypes.TYPES:
		if str(EdyTypes.TYPES[id]["look"]) == look_:
			typ = id
	var path := "res://assets/audio/edy_hum_%s.wav" % typ
	if typ == "" or not ResourceLoader.exists(path):
		return
	if _hum == null or not is_instance_valid(_hum):
		_hum = AudioStreamPlayer3D.new()
		_hum.name = "EdyHum"
		_hum.bus = "SFX"
		_hum.unit_size = 5.0
		_hum.max_distance = 40.0
		body.add_child(_hum)
		_hum.position = Vector3(0, 1.0, 0)
	var st := (load(path) as AudioStreamWAV).duplicate() as AudioStreamWAV
	st.loop_mode = AudioStreamWAV.LOOP_FORWARD
	st.loop_begin = 0
	st.loop_end = st.data.size() / 2
	_hum.stream = st
	_hum.volume_db = -60.0
	_hum.play()


## The aura on `body` flares for a moment.
static func flash_on(body: Node3D) -> void:
	var a := body.get_node_or_null("EdyAura") as EdyAura if body else null
	if a:
		a._flash = 1.0


func _build(body: Node3D) -> void:
	_clear()
	_rng.seed = body.get_instance_id()
	# a light glowing outline on the limbs at work, the whole body for Reinforce
	for mi in _meshes(body):
		var s := MeshInstance3D.new()
		s.name = "EdyShell"
		s.mesh = mi.mesh
		s.material_override = _rim
		s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if mi.skin:
			s.skin = mi.skin
			s.skeleton = NodePath("../" + str(mi.skeleton))
		mi.add_child(s)
		_shells.append(s)
	# (Zach: wrapped round the limbs like the mock) a cylinder of emission along each forearm (down to the hand) and
	# each shin (down to the foot): the anchor at its middle, the length from the bone below it
	var limbs: Array = []
	if part in ["arms", "body", "reinforce"]:
		limbs.append_array([["fore_r", "hand_r", "EdyHand"], ["fore_l", "hand_l", "EdyHand"]])
	if part in ["legs", "body", "reinforce"]:
		limbs.append_array([["shin_r", "", "EdyFoot"], ["shin_l", "", "EdyFoot"]])
	for l in limbs:
		var bone = body.get(l[0])
		if not (bone is Node3D):
			continue
		var tip = body.get(l[1]) if str(l[1]) != "" else null
		var length := absf((tip as Node3D).position.y) if tip is Node3D else FOOT_DOWN
		var anchor := Node3D.new()
		anchor.name = str(l[2]) + "At"
		(bone as Node3D).add_child(anchor)
		anchor.position = Vector3(0, -length * 0.5, 0)
		_anchors.append(anchor)
		var e := _emitter(str(l[2]), length)
		anchor.add_child(e)
		_emitters.append(e)
	if look == "lightning":
		_arc_mesh = ImmediateMesh.new()
		_arcs = MeshInstance3D.new()
		_arcs.name = "EdyArcs"
		_arcs.mesh = _arc_mesh
		_arcs.top_level = true
		_arcs.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_arcs.extra_cull_margin = 4.0
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.vertex_color_use_as_albedo = true
		m.no_depth_test = false
		_arcs.material_override = m
		body.add_child(_arcs)
		_arc_next = []
		for i in range(_anchors.size()):
			_arc_next.append(_rng.randf_range(0.0, ARC_EVERY.y))
	if part == "reinforce":
		var d := QuadMesh.new()
		d.size = Vector2.ONE * DISC * 2.0
		d.orientation = PlaneMesh.FACE_Y
		_disc = MeshInstance3D.new()
		_disc.name = "EdyGround"
		_disc.mesh = d
		_disc.material_override = _ground
		_disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_disc.extra_cull_margin = 2.0
		body.add_child(_disc)
		_disc.top_level = true
		_disc.global_position = body.global_position + Vector3(0, 0.04, 0)
		var n: Node = body
		while n and not (n is CharacterBody3D):
			n = n.get_parent()
		_mover = n as CharacterBody3D


## One limb's particles in the look (world-space trails as the limb moves).
func _emitter(n: String, length: float) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.name = n
	p.local_coords = false
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.visibility_aabb = AABB(Vector3(-1.5, -1.5, -1.5), Vector3(3, 3, 3))
	var pm := ParticleProcessMaterial.new()
	# round the limb: a ring stretched along it (the bone's Y), particles born on its skin
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	pm.emission_ring_axis = Vector3.UP
	pm.emission_ring_height = length
	pm.emission_ring_radius = LIMB_R
	pm.emission_ring_inner_radius = LIMB_R * 0.8
	pm.gravity = Vector3.ZERO
	var hot := color.lightened(0.45)
	var ramp := Gradient.new()
	var size := 0.05
	var soft := false
	match look:
		"haze":
			p.amount = 18
			p.lifetime = 1.1
			pm.direction = Vector3.UP
			pm.spread = 25.0
			pm.initial_velocity_min = 0.15
			pm.initial_velocity_max = 0.35
			pm.scale_min = 1.0
			pm.scale_max = 1.8
			size = 0.14
			soft = true
			ramp.set_color(0, Color(color.lightened(0.3), 0.0))
			ramp.add_point(0.3, Color(color.lightened(0.3), 0.45))
			ramp.set_color(ramp.get_point_count() - 1, Color(color, 0.0))
		"crackle":
			p.amount = 30
			p.lifetime = 0.5
			pm.direction = Vector3.UP
			pm.spread = 55.0
			pm.initial_velocity_min = 0.8
			pm.initial_velocity_max = 1.8
			pm.gravity = Vector3(0, 1.2, 0)
			pm.damping_min = 1.0
			pm.damping_max = 2.0
			size = 0.035
			ramp.set_color(0, Color(1.0, 0.95, 0.7, 1.0))
			ramp.add_point(0.35, Color(hot, 1.0))
			ramp.set_color(ramp.get_point_count() - 1, Color(color.darkened(0.3), 0.0))
		"shimmer":
			p.amount = 14
			p.lifetime = 0.55
			pm.initial_velocity_min = 0.02
			pm.initial_velocity_max = 0.08
			pm.scale_min = 0.6
			pm.scale_max = 1.4
			size = 0.06
			ramp.set_color(0, Color(hot, 0.0))
			# (gold glints that twinkle, a hint of white at their peaks: white wash would lose the colour)
			ramp.add_point(0.2, Color(hot.lerp(Color.WHITE, 0.25), 0.9))
			ramp.add_point(0.45, Color(color, 0.25))
			ramp.add_point(0.65, Color(hot.lerp(Color.WHITE, 0.2), 0.8))
			ramp.set_color(ramp.get_point_count() - 1, Color(color, 0.0))
		"swirl":
			p.amount = 22
			p.lifetime = 0.9
			pm.orbit_velocity_min = 0.9
			pm.orbit_velocity_max = 1.3
			pm.direction = Vector3.UP
			pm.spread = 10.0
			pm.initial_velocity_min = 0.1
			pm.initial_velocity_max = 0.25
			size = 0.04
			ramp.set_color(0, Color(hot, 0.0))
			ramp.add_point(0.2, Color(hot, 1.0))
			ramp.set_color(ramp.get_point_count() - 1, Color(color, 0.0))
		_:
			# lightning: a few white-violet sparks; the arcs do the rest
			p.amount = 12
			p.lifetime = 0.25
			pm.direction = Vector3.UP
			pm.spread = 180.0
			pm.initial_velocity_min = 0.6
			pm.initial_velocity_max = 1.4
			size = 0.03
			ramp.set_color(0, Color(Color.WHITE, 1.0))
			ramp.set_color(ramp.get_point_count() - 1, Color(hot, 0.0))
	var gt := GradientTexture1D.new()
	gt.gradient = ramp
	pm.color_ramp = gt
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2.ONE * size
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if not soft else BaseMaterial3D.BLEND_MODE_MIX
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = _soft() if soft else _dot()
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	q.material = m
	p.draw_pass_1 = q
	p.amount_ratio = 0.0
	return p


## A hard little pixel dot (sparks, glints, motes) and a soft round puff (haze), made once.
static func _dot() -> Texture2D:
	if _dot_tex == null:
		var img := Image.create(4, 4, false, Image.FORMAT_RGBA8)
		img.fill(Color.WHITE)
		for c in [Vector2i(0, 0), Vector2i(3, 0), Vector2i(0, 3), Vector2i(3, 3)]:
			img.set_pixelv(c, Color(1, 1, 1, 0))
		_dot_tex = ImageTexture.create_from_image(img)
	return _dot_tex


static func _soft() -> Texture2D:
	if _soft_tex == null:
		var n := 8
		var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
		for y in range(n):
			for x in range(n):
				var d := Vector2(x - 3.5, y - 3.5).length() / 3.5
				img.set_pixel(x, y, Color(1, 1, 1, clampf(1.0 - d, 0.0, 1.0)))
		_soft_tex = ImageTexture.create_from_image(img)
	return _soft_tex


func _clear() -> void:
	for s in _shells:
		if is_instance_valid(s):
			s.queue_free()
	_shells.clear()
	for a in _anchors:
		if is_instance_valid(a):
			a.queue_free()
	_anchors.clear()
	_emitters.clear()
	if is_instance_valid(_arcs):
		_arcs.queue_free()
	_arcs = null
	_arc_live.clear()
	if is_instance_valid(_disc):
		_disc.queue_free()
	_disc = null


## (the emitters hang off the body's bones: they go with the aura however it's removed)
func _exit_tree() -> void:
	_clear()
	if _hum and is_instance_valid(_hum):
		_hum.queue_free()


func _process(delta: float) -> void:
	_t += delta
	left -= delta
	_flash = maxf(_flash - delta * FLASH_DECAY, 0.0)
	var k := minf(_t / FADE_IN, 1.0) if left > 0.0 else clampf(1.0 + left / FADE_OUT, 0.0, 1.0)
	for e in _emitters:
		if is_instance_valid(e):
			e.amount_ratio = clampf(k * (0.75 + 0.25 * _flash), 0.0, 1.0)
			e.speed_scale = 1.0 + _flash
			e.emitting = k > 0.02
	if _hum and is_instance_valid(_hum):
		_hum.volume_db = HUM_DB + linear_to_db(maxf(k, 0.001))
	_rim.set_shader_parameter("strength", k * RIM_K * (1.0 + _flash))
	_ground.set_shader_parameter("strength", k * _ground_k * 0.7)
	if is_instance_valid(_disc):
		var body := get_parent() as Node3D
		# on the ground: under the feet; off it, left where they stood, fading
		# (a crewmate's captain on this screen is a puppet with no floor test: still in height means grounded)
		var y := body.global_position.y
		var local: bool = _mover != null and bool(_mover.get("is_local"))
		var grounded := _mover == null or (_mover.is_on_floor() if local else absf(y - _last_y) < 1.2 * delta)
		_last_y = y
		if grounded:
			_disc.global_position = body.global_position + Vector3(0, 0.04, 0)
		_ground_k = move_toward(_ground_k, 1.0 if grounded else 0.0, delta * (GROUND_IN if grounded else GROUND_OUT))
	if is_instance_valid(_arcs):
		_arcs_tick(delta, k)
	if left <= -FADE_OUT:
		queue_free()


## Storm: short jagged arcs snapping off each limb, a few a second, lit a moment each (world space).
func _arcs_tick(delta: float, k: float) -> void:
	for i in range(_anchors.size()):
		_arc_next[i] = float(_arc_next[i]) - delta * (1.0 + _flash * 2.0)
		if _arc_next[i] <= 0.0 and k > 0.2 and is_instance_valid(_anchors[i]):
			_arc_next[i] = _rng.randf_range(ARC_EVERY.x, ARC_EVERY.y)
			# (anywhere along the limb)
			var from: Vector3 = _anchors[i].global_position + _anchors[i].global_basis.y.normalized() * _rng.randf_range(-0.18, 0.18)
			# (Zach: the arcs land on the body) from one point on the limb to another on it, or to a limb near it (a hand
			# to the other, a foot to a hand), bowing out a little and jagged between
			var to: Vector3 = _anchors[i].global_position + _anchors[i].global_basis.y.normalized() * _rng.randf_range(-0.2, 0.2)
			var j := _rng.randi() % _anchors.size()
			if j != i and is_instance_valid(_anchors[j]) and _rng.randf() < 0.4 and _anchors[j].global_position.distance_to(from) < ARC_REACH:
				to = _anchors[j].global_position + _anchors[j].global_basis.y.normalized() * _rng.randf_range(-0.15, 0.15)
			elif to.distance_to(from) < 0.12:
				to = from - _anchors[i].global_basis.y.normalized() * 0.25
			var body_c: Vector3 = (get_parent() as Node3D).global_position + Vector3(0, 1.0, 0)
			var out := ((from + to) * 0.5 - body_c)
			out = out.normalized() if out.length() > 0.01 else Vector3.UP
			var bow := _rng.randf_range(0.05, 0.16) * k
			var pts: Array = [from]
			var n := 5
			for s in range(1, n):
				var u := float(s) / n
				var mid := from.lerp(to, u) + out * bow * sin(u * PI)
				pts.append(mid + Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1), _rng.randf_range(-1, 1)) * 0.035)
			pts.append(to)
			_arc_live.append([pts, ARC_LIFE])
	var keep: Array = []
	for a in _arc_live:
		a[1] = float(a[1]) - delta
		if a[1] > 0.0:
			keep.append(a)
	_arc_live = keep
	_arc_mesh.clear_surfaces()
	if _arc_live.is_empty():
		return
	_arc_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	for a in _arc_live:
		var pts: Array = a[0]
		# (a bright core and a coloured line a hair beside it: thick enough to read at a distance)
		for pass_ in [[Color.WHITE.lerp(color.lightened(0.5), 0.3), Vector3.ZERO], [color.lightened(0.15), Vector3(0.012, 0.012, 0.0)], [color.lightened(0.15), Vector3(-0.012, -0.008, 0.01)]]:
			for s in range(pts.size() - 1):
				_arc_mesh.surface_set_color(pass_[0])
				_arc_mesh.surface_add_vertex(pts[s] + pass_[1])
				_arc_mesh.surface_set_color(pass_[0])
				_arc_mesh.surface_add_vertex(pts[s + 1] + pass_[1])
	_arc_mesh.surface_end()


## The meshes the outline goes on: the whole body for Reinforce; otherwise the arms (forearms, hands, the arm skin and
## what's held). (The legs are one skinned surface with the body, so the kicking stance's outline stays off them: its
## feet carry the particles.)
func _meshes(body: Node3D) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	if part == "legs":
		return out
	var roots: Array = [body]
	if part != "reinforce":
		roots = []
		for k in ["fore_r", "hand_r", "fore_l", "hand_l"]:
			var b = body.get(k)
			if b is Node3D:
				roots.append(b)
		var torso = body.get("torso")
		if torso is Node3D and (torso as Node3D).get_node_or_null("ArmBody") is MeshInstance3D:
			out.append((torso as Node3D).get_node("ArmBody"))
	for r in roots:
		if r is MeshInstance3D and not str(r.name).begins_with("Edy"):
			out.append(r)
		for c in (r as Node).find_children("*", "MeshInstance3D", true, false):
			if not str(c.name).begins_with("Edy") and (c as MeshInstance3D).mesh != null and (c as MeshInstance3D).visible:
				out.append(c)
	return out
