class_name FarFigures
extends MultiMeshInstance3D
## Townsfolk far off as one draw call (2026-10-25 GPU pass): a lod rig whose owner allows it (NPCs, villagers,
## Brinehollow's folk: Humanoid.far_figure) hides its body past ON_R from the camera (back inside OFF_R) and is drawn
## as an instance of this MultiMesh: a simple figure in its colours (top, legs, skin, hair) that the shader
## (shaders/world/far_figure.gdshader) walks, sits and moves on between the rows the rig writes when it would have
## posed. A body is ~19 draws (its shadows already off past 28 m); every figure together is one. Cosmetic and each
## screen's own: nothing is sent. The rows go to the server once a frame, just before the draw, so a body and its
## figure never both miss a frame.

const ON_R := 40.0
const OFF_R := 35.0
const CAP := 256
## Floats a row (TRANSFORM_3D, colours, custom data).
const ROW := 20
## A stride's cycle (two steps) per this many m (the shader's GAIT).
const GAIT := 1.25

static var _it: FarFigures
## The figures' clock (the shader's `now`), seconds.
var now := 0.0
## The rows (the server's copy can't be read back headless): tests read them.
var rows := PackedFloat32Array()
## Slots in use.
var used := 0
var _free: Array[int] = []
var _top := 0
var _dirty := false
var _mat: ShaderMaterial


## The scene's figures, made (under the root) the first time one's wanted.
static func shared(from: Node) -> FarFigures:
	if _it == null or not is_instance_valid(_it):
		_it = FarFigures.new()
		from.get_tree().root.add_child.call_deferred(_it)
	return _it


func _init() -> void:
	name = "FarFigures"
	process_priority = -1000
	top_level = true
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	custom_aabb = AABB(Vector3(-1e5, -1e5, -1e5), Vector3(2e5, 2e5, 2e5))
	_mat = ShaderMaterial.new()
	_mat.shader = load("res://shaders/world/far_figure.gdshader")
	material_override = _mat
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	mm.mesh = mesh()
	mm.instance_count = CAP
	mm.visible_instance_count = 0
	multimesh = mm
	rows.resize(CAP * ROW)


func _ready() -> void:
	RenderingServer.frame_pre_draw.connect(_send)


func _exit_tree() -> void:
	if RenderingServer.frame_pre_draw.is_connected(_send):
		RenderingServer.frame_pre_draw.disconnect(_send)


func _process(delta: float) -> void:
	now += delta
	_mat.set_shader_parameter("now", now)


func _send() -> void:
	if not _dirty:
		return
	_dirty = false
	multimesh.buffer = rows
	multimesh.visible_instance_count = _top


## A free slot (-1 when full: that body just stays a body).
func take() -> int:
	var i := -1
	if not _free.is_empty():
		i = _free.pop_back()
	elif _top < CAP:
		i = _top
		_top += 1
	if i >= 0:
		used += 1
	return i


func drop(i: int) -> void:
	if i < 0:
		return
	for k in range(12):
		rows[i * ROW + k] = 0.0
	_free.append(i)
	used -= 1
	_dirty = true


## Slot i's row from body h: where it is, its heading and height, its colours (`paint`, from paint_of), its speed
## along its heading, the ground covered (`dist`, wrapped to a stride) and sat at `seat` (< 0: standing).
func put(i: int, h: Node3D, paint: Color, speed: float, dist: float, seat: float) -> void:
	var xf := h.global_transform
	var o := i * ROW
	var b := xf.basis
	var p := xf.origin
	var r := [b.x.x, b.y.x, b.z.x, p.x, b.x.y, b.y.y, b.z.y, p.y, b.x.z, b.y.z, b.z.z, p.z,
		paint.r, paint.g, paint.b, paint.a, now, speed, fposmod(dist, GAIT), 1.0 + seat if seat >= 0.0 else 0.0]
	for k in range(ROW):
		rows[o + k] = r[k]
	_dirty = true


## A look's figure colours, each sRGB colour packed 8 bits a channel into a float (exact up to 2^24): top, legs,
## skin, hair (a hat's colour under a hat).
static func paint_of(lk: Dictionary) -> Color:
	var skin: Color = lk.get("skin", Color(0.85, 0.65, 0.5))
	var top: Color = lk.get("top_color", Color.WHITE)
	if str(lk.get("coat", "none")) != "none":
		top = lk.get("coat_color", top)
	elif str(lk.get("top", "")) == "bare":
		top = skin
	var hair: Color = lk.get("hair_color", Color(0.15, 0.1, 0.07))
	if str(lk.get("hat", "none")) != "none":
		hair = lk.get("hat_color", hair)
	elif str(lk.get("hair", "")) in ["bald", "none"]:
		hair = skin
	return Color(pack(top), pack(lk.get("legs_color", Color(0.3, 0.27, 0.25))), pack(skin), pack(hair))


static func pack(c: Color) -> float:
	return float(c.r8 * 65536 + c.g8 * 256 + c.b8)


## The figure, facing -z, its feet at 0: boxes, each vertex's UV.x its part (the shader's numbering).
static func mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for s: float in [-1.0, 1.0]:
		_box(st, 1, Vector3(s * 0.1, 0.65, 0.0), Vector3(0.15, 0.43, 0.17))
		_box(st, 2, Vector3(s * 0.1, 0.25, 0.0), Vector3(0.13, 0.4, 0.15))
		_box(st, 7, Vector3(s * 0.1, 0.03, -0.03), Vector3(0.13, 0.06, 0.22))
		_box(st, 3, Vector3(s * 0.225, 1.15, 0.0), Vector3(0.09, 0.54, 0.11))
		_box(st, 4, Vector3(s * 0.225, 0.83, 0.0), Vector3(0.08, 0.1, 0.09))
	_box(st, 8, Vector3(0.0, 0.93, 0.0), Vector3(0.32, 0.2, 0.2))
	_box(st, 0, Vector3(0.0, 1.23, 0.0), Vector3(0.36, 0.4, 0.22))
	_box(st, 0, Vector3(0.0, 1.045, 0.0), Vector3(0.33, 0.05, 0.2))
	_box(st, 5, Vector3(0.0, 1.47, 0.0), Vector3(0.1, 0.1, 0.1))
	_box(st, 5, Vector3(0.0, 1.62, 0.0), Vector3(0.2, 0.24, 0.22))
	_box(st, 6, Vector3(0.0, 1.76, 0.015), Vector3(0.22, 0.06, 0.25))
	_box(st, 6, Vector3(0.0, 1.64, 0.1), Vector3(0.22, 0.2, 0.05))
	st.index()
	return st.commit()


static func _box(st: SurfaceTool, part: int, c: Vector3, size: Vector3) -> void:
	var h := size * 0.5
	for f in [[Vector3.RIGHT, Vector3.UP, Vector3.BACK], [Vector3.LEFT, Vector3.UP, Vector3.FORWARD], [Vector3.UP, Vector3.BACK, Vector3.RIGHT],
			[Vector3.DOWN, Vector3.FORWARD, Vector3.RIGHT], [Vector3.BACK, Vector3.UP, Vector3.LEFT], [Vector3.FORWARD, Vector3.UP, Vector3.RIGHT]]:
		var n: Vector3 = f[0]
		var u: Vector3 = f[1]
		var v: Vector3 = f[2]
		var q := [n - u - v, n - u + v, n + u + v, n + u - v]
		for k in [0, 1, 2, 0, 2, 3]:
			st.set_normal(n)
			st.set_uv(Vector2(part, 0.0))
			st.add_vertex(c + (q[k] as Vector3) * h)
