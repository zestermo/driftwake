class_name GroundLayer
extends Node
## Footprints in snow and sand, shared by both (made by Weather beside the rain; each screen its own):
## every captain this machine sees (puppets too, from their synced positions) presses a print where each
## foot comes down on a theme's soft ground (KitStyle "ground_prints": "snow" or "sand"), and kicks up a
## puff of the flipbook's powder or sand. The prints are pixels in one small texture wrapped over the
## world (shaders/world/ground_prints.gdshaderinc), painted here a few pixels a step and sent up at most
## every SEND_EVERY s; the terrain shader darkens them, the snow layer (a pass over a snow island's
## terrain, snow_layer.gdshader: you wade through it) opens where they are. They fade over LIFE s on the
## shader's side, so nothing here runs per pixel. Not decals: Forward+ shares its clustered slots between
## lights and decals, and a trail of decals would eat the lamps'.

const PX := 12.0
const SIZE := 512
const SEND_EVERY := 0.1
## How long a print lasts (s), by ground.
const LIFE := {"snow": 70.0, "sand": 45.0}
## A boot print (m): half its length and half its width; how far each foot sits off the middle.
## (bigger than a real boot: at the game camera's distance a true-size print is a few pixels)
const HALF_LEN := 0.21
const HALF_W := 0.095
const FOOT_OFF := 0.14
## The puff kicked up: the sheet's tint by ground.
const PUFF := {"snow": Color(1.0, 1.0, 1.0, 0.85), "sand": Color(0.95, 0.85, 0.66, 0.85)}

## Breath in the cold: how often, how near the camera, its mist's tint.
const BREATH_EVERY := 2.8
const BREATH_RANGE := 30.0
const BREATH := Color(1.0, 1.0, 1.0, 0.4)

static var _inst: GroundLayer

var tex: ImageTexture
var _img: Image
var _clock := 0.0
var _dirty := false
var _send_t := 0.0
var _sent := 0.0
var _breath_t := 1.0
## What the shaders' ground_prints_at was last set to.
var shader_at := Vector4.ZERO
## The ground's kind where the camera is ("" off), from Weather's zone.
var kind := ""


func _ready() -> void:
	_inst = self
	_img = Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	tex = ImageTexture.create_from_image(_img)
	RenderingServer.global_shader_parameter_set("ground_prints", tex)
	RenderingServer.global_shader_parameter_set("ground_prints_at", Vector4.ZERO)


func _exit_tree() -> void:
	if _inst == self:
		_inst = null
	RenderingServer.global_shader_parameter_set("ground_prints_at", Vector4.ZERO)


func _process(delta: float) -> void:
	kind = str(Weather._zone_style["ground_prints"]) if float(Weather._zone[1]) > 0.5 else ""
	if kind == "":
		return
	_clock += delta
	if kind == "snow":
		_breathe(delta)
	_send_t -= delta
	if _send_t > 0.0:
		return
	_send_t = SEND_EVERY
	if _dirty:
		_dirty = false
		tex.update(_img)
	_sent = fmod(floorf(_clock * 4.0), 65536.0)
	shader_at = Vector4(_sent, float(LIFE[kind]), 0.0, 0.0)
	RenderingServer.global_shader_parameter_set("ground_prints_at", shader_at)


## In the cold every captain near the camera breathes out a little mist now and then (local juice, puppets too).
func _breathe(delta: float) -> void:
	_breath_t -= delta
	if _breath_t > 0.0:
		return
	_breath_t = BREATH_EVERY
	var cam := get_viewport().get_camera_3d()
	var i := 0
	for c in get_tree().get_nodes_in_group("players"):
		i += 1
		var bm = c.get("body_model")
		if bm == null or bm.swimming or bm.diving or cam == null or cam.global_position.distance_to(c.global_position) > BREATH_RANGE:
			continue
		var head: Node3D = bm.head
		var fwd := -head.global_basis.z
		var at := head.global_position + fwd * 0.2 - Vector3(0, 0.06, 0)
		# (each captain out of step with the next)
		get_tree().create_timer(0.37 * (i - 1), false).timeout.connect(func():
			if is_instance_valid(head):
				FX.puff(at, "mist", 1, 0.32, 1.0, BREATH, 0.35, fwd + Vector3(0, 0.25, 0)))


## The clock in quarter seconds as the shaders last had it (a print made since is never "from the future" there).
func _q() -> float:
	return _sent


## A captain's foot came down (Player._on_footstep) on `surface`: a print, and a puff kicked up
## (`strength` 0: sneaking, no puff). True when the ground was soft here (the caller's dust is skipped).
static func step(body: Node3D, surface: String, foot: int, strength: float, running: bool) -> bool:
	if _inst == null or _inst.kind == "" or surface != _inst.kind:
		return false
	var bm := body.get("body_model") as Node3D
	var fwd := -bm.global_basis.z if bm else -body.global_basis.z
	fwd = Vector3(fwd.x, 0.0, fwd.z).normalized()
	var side := Vector3(-fwd.z, 0.0, fwd.x) * (FOOT_OFF if foot % 2 == 0 else -FOOT_OFF)
	var at := body.global_position + side
	_inst.stamp(at, fwd)
	if strength > 0.0:
		var back := -fwd * (1.2 if running else 0.5)
		FX.puff(at + Vector3(0, 0.12, 0), _inst.kind, 2 if running else 1, 0.75 if running else 0.5, 0.7 if running else 0.55,
			PUFF[_inst.kind], 0.9 if running else 0.6, Vector3.UP + back)
	return true


## True where `surface` is this island's soft ground (a landing's puff ring is its powder, not dust).
static func soft(surface: String) -> bool:
	return _inst != null and _inst.kind != "" and surface == _inst.kind


## A print at world `at` pointing along `fwd` (unit, flat).
func stamp(at: Vector3, fwd: Vector3) -> void:
	var born := int(fmod(_q(), 65536.0))
	var g := float(born >> 8) / 255.0
	var b := float(born & 255) / 255.0
	var right := Vector2(-fwd.z, fwd.x)
	var f2 := Vector2(fwd.x, fwd.z)
	var c := Vector2(at.x, at.z)
	var reach := ceili((HALF_LEN + 0.05) * PX)
	var cx := floori(at.x * PX)
	var cz := floori(at.z * PX)
	for dz in range(-reach, reach + 1):
		for dx in range(-reach, reach + 1):
			var px := cx + dx
			var pz := cz + dz
			var d := Vector2((px + 0.5) / PX, (pz + 0.5) / PX) - c
			var u := d.dot(f2) / HALF_LEN
			var v := d.dot(right) / HALF_W
			# (the heel a little narrower than the ball of the foot)
			var w := 1.0 - 0.25 * clampf(-u, 0.0, 1.0)
			if u * u + (v / w) * (v / w) > 1.0:
				continue
			var tile := ((px >> 9) & 15) | (((pz >> 9) & 15) << 4)
			_img.set_pixel(px & (SIZE - 1), pz & (SIZE - 1), Color(1.0, g, b, tile / 255.0))
	_dirty = true


## How deep the print at world `at` is now, 0..1, as the shader reads it.
func print_at(at: Vector3) -> float:
	if kind == "":
		return 0.0
	var px := floori(at.x * PX)
	var pz := floori(at.z * PX)
	var t := _img.get_pixel(px & (SIZE - 1), pz & (SIZE - 1))
	var tile := ((px >> 9) & 15) | (((pz >> 9) & 15) << 4)
	if t.r <= 0.0 or roundi(t.a * 255.0) != tile:
		return 0.0
	var born := roundf(t.g * 255.0) * 256.0 + roundf(t.b * 255.0)
	var age := fmod(fmod(_q(), 65536.0) - born + 65536.0, 65536.0) * 0.25
	var life := float(LIFE[kind])
	var k := t.r * (1.0 - smoothstep(life * 0.5, life, age))
	return floorf(k * 3.0 + 0.5) / 3.0
