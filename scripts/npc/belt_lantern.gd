class_name BeltLantern
extends Node3D
## A small brass lantern hung from a captain's belt at the back of the right hip, clear
## of the sheaths (Humanoid.wear_lantern; it never takes a hand). It swings
## on its strap as a pendulum driven by the body's motion (verlet against the torso's
## drawn transform, like SpringChains) and settles when you stand still. Lit: a warm
## OmniLight, no shadows. Who lights it: Player._lantern_tick.

const STRAP := 0.06
const SCALE := 0.42
## Hook to the lantern's middle (the swinging length).
const ARM := STRAP + 0.3 * SCALE
const STEP := 1.0 / 60.0
const DAMP := 0.03
## How much of the body's speeding up and slowing down the lantern feels (the rest it's carried with).
const INERTIA := 0.35
## How far it may swing in toward the body (m, local x and z) and up from hanging straight (rad).
const IN_MAX := 0.015
const SWING_MAX := 1.1
const COLOR := Color(1.0, 0.72, 0.42)
const ENERGY := 1.0
const RANGE := 9.0

var lit := false
var _swing: Node3D
var _mesh: MeshInstance3D
var _light: OmniLight3D
## The lantern's middle from the hook (world axes; relative, so float precision holds far
## out at sea), its last step's, and the hook's last place and speed.
var _x := Vector3.INF
var _px := Vector3.ZERO
var _hook := Vector3.ZERO
var _hv := Vector3.ZERO
var _kick := Vector3.ZERO
var _acc := 0.0
var _t := 0.0
var _glass_on: Material = PSXMat.glow(Color(1.0, 0.8, 0.45), 2.6)
var _glass_off: Material = PSXMat.lit("", Color(0.42, 0.33, 0.2))


func _init() -> void:
	name = "BeltLantern"
	_swing = Node3D.new()
	_swing.name = "Swing"
	add_child(_swing)
	var mb := MeshBuilder.new()
	var brass := PSXMat.lit("metal", Color(0.92, 0.68, 0.3))
	mb.add_box(PSXMat.lit("", Color(0.3, 0.2, 0.12)), Transform3D(Basis.IDENTITY, Vector3(0, -STRAP * 0.5, 0)), Vector3(0.02, STRAP + 0.02, 0.012), 1.0)
	model(mb, Transform3D(Basis.IDENTITY, Vector3(0, -STRAP - 0.53 * SCALE, 0)), SCALE, brass, _glass_on)
	_mesh = mb.to_instance("Lantern")
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_swing.add_child(_mesh)
	_light = OmniLight3D.new()
	_light.name = "Light"
	_light.light_color = COLOR
	_light.light_energy = ENERGY
	_light.omni_range = RANGE
	_light.omni_attenuation = 0.7
	_light.shadow_enabled = false
	_light.distance_fade_enabled = true
	_light.distance_fade_begin = 40.0
	_light.distance_fade_length = 12.0
	# (out from the hip, not inside the lantern: so close, it would burn the thigh white)
	_light.position = Vector3(0.28, -0.12, -0.05)
	add_child(_light)
	set_lit(false)


## A lantern into `mb` at `xf`, its foot at the origin (0.53 m tall at s 1); ShipLights hangs the same one.
## (Kept free of Buildings & co: test scripts naming Humanoid compile before the autoloads those use.)
static func model(mb: MeshBuilder, xf: Transform3D, s: float, frame: Material, glass: Material) -> void:
	var circle := MeshBuilder.profile_circle(6)
	var sx := xf * Transform3D(Basis.from_scale(Vector3.ONE * s), Vector3.ZERO)
	mb.add_loft(frame, sx, [[0.0, 0.13, 0.13], [0.04, 0.13, 0.13], [0.055, 0.1, 0.1]], circle, 2.0, Color.WHITE, true, true)
	mb.add_loft(glass, sx, [[0.055, 0.095, 0.095], [0.18, 0.112, 0.112], [0.3, 0.095, 0.095]], circle, 2.0)
	mb.add_loft(frame, sx, [[0.3, 0.12, 0.12], [0.34, 0.12, 0.12], [0.43, 0.05, 0.05], [0.47, 0.03, 0.03]], circle, 2.0, Color.WHITE, false, true)
	for i in range(4):
		var o := Vector3(cos(TAU * (i + 0.5) / 4.0), 0, sin(TAU * (i + 0.5) / 4.0))
		beam(mb, frame, sx * (o * 0.12 + Vector3.UP * 0.05), sx * (o * 0.14 + Vector3.UP * 0.18), 0.018 * s)
		beam(mb, frame, sx * (o * 0.14 + Vector3.UP * 0.18), sx * (o * 0.12 + Vector3.UP * 0.31), 0.018 * s)
	var ring := PackedVector3Array()
	for i in range(7):
		var a := PI * i / 6.0
		ring.append(sx * Vector3(cos(a) * 0.06, 0.46 + sin(a) * 0.07, 0))
	mb.add_tube(frame, ring, 0.012 * s, -1.0, 4, 2.0)


## A square bar `t` thick from a to b (Buildings.beam_between's).
static func beam(mb: MeshBuilder, mat: Material, a: Vector3, b: Vector3, t: float) -> void:
	var d := b - a
	mb.add_box(mat, Transform3D(Basis.looking_at(d.normalized(), Vector3.UP if absf(d.normalized().y) < 0.95 else Vector3.FORWARD), (a + b) * 0.5), Vector3(t, t, d.length()), 0.6)


func set_lit(on: bool) -> void:
	lit = on
	_light.visible = on
	_mesh.set_surface_override_material(_glass_surface(), _glass_on if on else _glass_off)


## The glass is the lantern's second material (after the strap and the brass).
func _glass_surface() -> int:
	return _mesh.mesh.get_surface_count() - 1


func _process(delta: float) -> void:
	_t += delta
	if lit:
		_light.light_energy = ENERGY * (1.0 + 0.06 * sin(_t * 7.3) + 0.04 * sin(_t * 12.9 + 1.7))
	var g := get_global_transform_interpolated()
	var arm := ARM * g.basis.get_scale().x
	var moved := g.origin - _hook
	_hook = g.origin
	if _x == Vector3.INF or moved.length() > 1.5 or delta <= 0.0:
		_x = Vector3.DOWN * arm
		_px = _x
		_hv = Vector3.ZERO
		_kick = Vector3.ZERO
	else:
		# the hook speeding up or slowing down: the lantern keeps (some of) its own speed
		var hv := moved / delta
		_kick += (hv - _hv) * INERTIA * STEP
		_hv = hv
	_acc = minf(_acc + delta, STEP * 4.0)
	while _acc >= STEP:
		_acc -= STEP
		var nx := _x + (_x - _px) * (1.0 - DAMP) + Vector3(0, -9.8, 0) * STEP * STEP - _kick
		_kick = Vector3.ZERO
		_px = _x
		_x = _limit(g.basis, nx, arm)
	var dir := (g.basis.inverse() * _x).normalized()
	_swing.basis = Basis(Quaternion(Vector3.DOWN, dir)) if dir.dot(Vector3.DOWN) > -0.999 else Basis()


## On the strap's length from the hook, never into the leg, never up over the belt.
func _limit(b: Basis, r: Vector3, arm: float) -> Vector3:
	var d := b.inverse() * r
	d.x = maxf(d.x, -IN_MAX)
	d.z = maxf(d.z, -IN_MAX)
	d = d.normalized()
	if d.angle_to(Vector3.DOWN) > SWING_MAX:
		var axis := Vector3.DOWN.cross(d)
		d = Vector3.DOWN.rotated(axis.normalized(), SWING_MAX) if axis.length_squared() > 1e-8 else Vector3.DOWN
	return (b * d).normalized() * arm
