class_name Seagull
extends Node3D
## A herring gull: glides in and lands, struts and pecks, caws with its head
## thrown back and beak wide, then flaps off and climbs away (and frees
## itself). Built in code, faces -Z. The wake-up (WakeState) uses one.

enum { GLIDE_IN, PERCH, FLY_OFF }

const FLY_IN_TIME := 1.6
const CAW_TIME := 0.5

var state: int = PERCH
var _t: float = 0.0
var _caw: float = -1.0
var _from: Vector3
var _to: Vector3
var _away: Vector3
var _yaw: float = 0.0
var _head: Node3D
var _jaw: Node3D
var _wing_l: Node3D
var _wing_r: Node3D
var _peck: float = 0.0


func _ready() -> void:
	var white := PSXMat.lit("", Color(0.95, 0.95, 0.93))
	var grey := PSXMat.lit("", Color(0.62, 0.66, 0.7))
	var black := PSXMat.lit("", Color(0.08, 0.08, 0.09))
	var beak := PSXMat.lit("", Color(0.98, 0.78, 0.2))
	var red := PSXMat.lit("", Color(0.85, 0.15, 0.1))
	var leg := PSXMat.lit("", Color(0.9, 0.62, 0.45))
	var rng := RandomNumberGenerator.new()
	var mb := MeshBuilder.new()
	mb.add_blob(white, Transform3D(Basis(), Vector3(0, 0.2, 0.0)), Vector3(0.085, 0.08, 0.19), rng, 0.0, 3, 7)
	mb.add_blob(grey, Transform3D(Basis(), Vector3(0, 0.245, 0.03)), Vector3(0.08, 0.04, 0.15), rng, 0.0, 3, 7)
	var tail := Transform3D(Basis(Vector3.RIGHT, PI * 0.5 - 0.15), Vector3(0, 0.23, 0.16))
	mb.add_extrude(white, tail, PackedVector2Array([Vector2(-0.05, 0), Vector2(0.05, 0), Vector2(0.035, 0.12), Vector2(-0.035, 0.12)]), 0.012, 4.0)
	for s in [-1.0, 1.0]:
		mb.add_box(leg, Transform3D(Basis(), Vector3(s * 0.035, 0.065, 0.02)), Vector3(0.014, 0.13, 0.014), 4.0, Color.WHITE, false)
		mb.add_box(leg, Transform3D(Basis(), Vector3(s * 0.035, 0.006, -0.01)), Vector3(0.04, 0.012, 0.06), 4.0, Color.WHITE, false)
	add_child(mb.to_instance("Body"))
	_head = Node3D.new()
	_head.position = Vector3(0, 0.29, -0.15)
	add_child(_head)
	var hb := MeshBuilder.new()
	hb.add_blob(white, Transform3D(Basis(), Vector3(0, 0.02, -0.02)), Vector3(0.055, 0.055, 0.065), rng, 0.0, 3, 6)
	for s in [-1.0, 1.0]:
		hb.add_box(black, Transform3D(Basis(), Vector3(s * 0.045, 0.035, -0.04)), Vector3(0.012, 0.014, 0.014), 4.0, Color.WHITE, false)
	hb.add_cone(beak, Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(0, 0.02, -0.07)), 0.016, 0.085, 5, 4.0)
	_head.add_child(hb.to_instance("Head"))
	_jaw = Node3D.new()
	_jaw.position = Vector3(0, 0.005, -0.07)
	_head.add_child(_jaw)
	var jb := MeshBuilder.new()
	jb.add_box(beak, Transform3D(Basis(), Vector3(0, 0, -0.035)), Vector3(0.022, 0.012, 0.07), 4.0, Color.WHITE, false)
	jb.add_box(red, Transform3D(Basis(), Vector3(0, -0.004, -0.055)), Vector3(0.024, 0.008, 0.016), 4.0, Color.WHITE, false)
	_jaw.add_child(jb.to_instance("Jaw"))
	# wings: grey plates with black tips, hinged at the shoulder (x out, z back)
	for s in [-1.0, 1.0]:
		var w := Node3D.new()
		w.position = Vector3(s * 0.07, 0.25, -0.02)
		add_child(w)
		var wb := MeshBuilder.new()
		var flat := Basis(Vector3.RIGHT, PI * 0.5)
		var inner := PackedVector2Array([Vector2(0, -0.07), Vector2(0.32, -0.05), Vector2(0.34, 0.06), Vector2(0, 0.09)])
		var tip := PackedVector2Array([Vector2(0.32, -0.05), Vector2(0.58, 0.02), Vector2(0.34, 0.06)])
		if s < 0.0:
			for i in range(inner.size()):
				inner[i].x = -inner[i].x
			for i in range(tip.size()):
				tip[i].x = -tip[i].x
		wb.add_extrude(grey, Transform3D(flat, Vector3.ZERO), inner, 0.012, 4.0)
		wb.add_extrude(black, Transform3D(flat, Vector3.ZERO), tip, 0.01, 4.0)
		w.add_child(wb.to_instance("Wing"))
		if s < 0.0:
			_wing_l = w
		else:
			_wing_r = w
	_fold(1.0)


## Glide in from `from` and land at `to`, facing `face_yaw`.
func land(from: Vector3, to: Vector3, face_yaw: float) -> void:
	_from = from
	_to = to
	_yaw = face_yaw
	state = GLIDE_IN
	_t = 0.0
	global_position = from


func caw() -> void:
	_caw = 0.0
	FX.sfx("gull", global_position, -2.0, 0.06)


## Take off and fly away along `dir` (flat), climbing.
func fly_off(dir: Vector3) -> void:
	_away = Vector3(dir.x, 0, dir.z).normalized()
	state = FLY_OFF
	_t = 0.0
	_from = global_position
	FX.sfx("whoosh", global_position, -14.0, 0.1, 1.6)


## 1 = wings folded along the back, 0 = spread.
func _fold(k: float) -> void:
	_wing_l.rotation = Vector3(0, lerpf(0.0, -1.35, k), lerpf(0.0, -0.35, k))
	_wing_r.rotation = Vector3(0, lerpf(0.0, 1.35, k), lerpf(0.0, 0.35, k))


func _flap(phase: float, amp: float) -> void:
	_fold(0.0)
	var f := sin(phase) * amp
	_wing_l.rotation.z = -f
	_wing_r.rotation.z = f


func _process(delta: float) -> void:
	_t += delta
	match state:
		GLIDE_IN:
			var k := clampf(_t / FLY_IN_TIME, 0.0, 1.0)
			var p := _from.lerp(_to, k)
			p.y += sin(k * PI) * 0.6 * (1.0 - k)
			global_position = p
			var d := _to - _from
			rotation = Vector3(0, atan2(-d.x, -d.z), 0)
			if k < 0.75:
				_flap(_t * 9.0, 0.25)
			else:
				_flap(_t * 18.0, 0.7 * (1.0 - k) * 4.0)
			if k >= 1.0:
				state = PERCH
				_t = 0.0
				rotation.y = _yaw
				_fold(1.0)
		PERCH:
			_fold(1.0)
			# now and then a peck at the sand, a turn of the head
			_peck = maxf(_peck - delta, 0.0)
			if _peck <= 0.0 and _caw < 0.0 and fmod(_t, 2.3) < delta:
				_peck = 0.35
			_head.rotation = Vector3(-0.9 * sin(_peck / 0.35 * PI) if _peck > 0.0 else 0.0, sin(_t * 1.3) * 0.5, 0)
		FLY_OFF:
			_flap(_t * 16.0, 0.85)
			var up := minf(_t, 0.3) * 2.0 + maxf(_t - 0.3, 0.0) * 2.2
			global_position = _from + _away * (_t * 1.5 + _t * _t * 2.0) + Vector3.UP * up
			rotation = Vector3(-0.25, atan2(-_away.x, -_away.z), sin(_t * 2.0) * 0.15)
			if _t > 7.0:
				queue_free()
	if _caw >= 0.0:
		_caw += delta
		var c := sin(clampf(_caw / CAW_TIME, 0.0, 1.0) * PI)
		_head.rotation.x = 0.85 * c
		_head.rotation.y = 0.0
		_jaw.rotation.x = 0.6 * c
		if _caw >= CAW_TIME:
			_caw = -1.0
			_jaw.rotation.x = 0.0
