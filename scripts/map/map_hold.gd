class_name MapHold
extends Node
## The held map (M). One per local captain (GameManager.register_player). M on foot (or at the helm:
## you let go of the wheel) puts the captain in MapState: they unroll the map at the chest and the
## camera tilts down onto it over the right shoulder (CameraRig.set_map); M again rolls it up.
## The page is sea_chart.gd drawn into a SubViewport (`page`, at its own pixel size, only while it's
## out) and shown on the sheet. Every captain holding a map (a map_* action on their body: puppets'
## come over the wire) gets the sheet between their hands, a crewmate's with a sketch on it. While
## it's up the mouse is a pen on the page: LMB sets a mark, RMB takes one off, C clears yours, the wheel
## goes between the island and the chart; pushed past the page's side it turns the captain.

const PAGE := preload("res://scripts/ui/sea_chart.gd")
const SHEET := preload("res://shaders/map_parchment.gdshader")
## The sheet: half its size (m; the page's shape), the rolls' radius.
const HALF := Vector2(0.3, 0.171)
const ROLL_R := 0.017
const PAPER := Color(0.86, 0.79, 0.62)
## Mouse px (screen) per page px of the pen, and radians of turn per page px pushed past the side.
const PEN := 0.55
const TURN := 0.004

var player
var page: Control
var cursor := Vector2.ZERO
var _vp: SubViewport
var _up := false
## player instance id -> [sheet Node3D, page MeshInstance3D, left roll]
var _sheets := {}
static var _sheet_mesh: ArrayMesh
static var _roll_mesh: ArrayMesh
static var _sketch: ImageTexture


static func attach(p: Node) -> void:
	var m := MapHold.new()
	m.name = "MapHold"
	m.player = p
	p.add_child(m)


static func of(p: Node) -> MapHold:
	return p.get_node("MapHold")


func _ready() -> void:
	# (after the bodies have posed this frame)
	process_priority = 50
	_vp = SubViewport.new()
	_vp.name = "MapPage"
	_vp.size = Vector2i(PAGE.SIZE)
	_vp.disable_3d = true
	_vp.gui_disable_input = true
	_vp.snap_2d_transforms_to_pixel = true
	_vp.snap_2d_vertices_to_pixel = true
	_vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_vp.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(_vp)
	page = PAGE.new()
	page.theme = UIStyle.get_theme()
	_vp.add_child(page)


func is_up() -> bool:
	return _up


## The player's CameraRig (null while another camera's current: the ship's at the helm).
func _rig():
	var cam := get_viewport().get_camera_3d()
	return cam.get_parent().get_parent() if cam and cam.is_in_group("player_camera") else null


## M: out if the captain's free to read it, away if it's out.
func toggle() -> void:
	var st: String = player.current_state_name()
	if st == "Map":
		player.state_machine.current_state.put_away()
	elif st == "Helm" or (st in ["Idle", "Move", "Crouch"] and player.context == Player.Context.ON_FOOT and player.is_on_floor()):
		player.state_machine.force_state("Map", {})


## (MapState) it's coming out: the page wakes and opens where we are, the camera comes over.
func opened() -> void:
	_up = true
	cursor = PAGE.SIZE * 0.5
	_vp.process_mode = Node.PROCESS_MODE_INHERIT
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	page.on_open()
	page.pen = cursor
	var rig = _rig()
	if rig:
		rig.set_map(_sheet(player)[0])


## (MapState) it's going away: the camera goes back; the page sleeps.
func closed() -> void:
	_up = false
	_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_vp.process_mode = Node.PROCESS_MODE_DISABLED
	var rig = _rig()
	if rig:
		rig.set_map(null)


## Render tools: the page awake and opened where we are without the captain taking it out (or asleep
## again); `image()` is what it shows a frame later.
func preview(on: bool) -> void:
	_vp.process_mode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS if on else SubViewport.UPDATE_DISABLED
	if on:
		page.on_open()


func image() -> Image:
	return _vp.get_texture().get_image()


## Which way the captain faces while reading (the camera's over the right shoulder).
func facing() -> Vector3:
	var rig = _rig()
	var yaw: float = rig.rotation.y - rig.MAP_YAW * rig.map_blend() if rig else player.player_model.rotation.y
	return Vector3(-sin(yaw), 0.0, -cos(yaw))


func _input(event: InputEvent) -> void:
	if not player.is_local or player.input_locked or get_tree().paused or GameMenu.is_open():
		return
	if event.is_action_pressed("sea_chart"):
		toggle()
		get_viewport().set_input_as_handled()
		return
	if not _up:
		return
	if event is InputEventMouseMotion:
		var to: Vector2 = cursor + event.screen_relative * PEN * float(Settings.get_value("controls", "mouse_sensitivity"))
		var lim := Vector2(PAGE.SIZE) - Vector2(4, 4)
		var past := to.x - clampf(to.x, 4.0, lim.x)
		cursor = to.clamp(Vector2(4, 4), lim)
		page.pen = cursor
		var rig = _rig()
		if rig and past != 0.0:
			rig.rotate_y(-past * TURN)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed:
		page.press(event.button_index, cursor)
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_C:
		page.clear_marks()
		get_viewport().set_input_as_handled()


func _exit_tree() -> void:
	for e in _sheets.values():
		if is_instance_valid(e[0]):
			(e[0] as Node).queue_free()


# --------------------------------------------------------------------------
# The sheet in the hands of every captain reading a map
# --------------------------------------------------------------------------
func _process(_delta: float) -> void:
	# (the camera comes in where our head is: it's hidden till the camera's back)
	var rig = _rig()
	var head: Node3D = player.body_model.head
	if head.visible == (rig != null and rig.on_map()):
		head.visible = not head.visible
	for p in get_tree().get_nodes_in_group("players"):
		var reading := str(p.body_model.current_action()).begins_with("map_")
		if reading:
			_place(p, _sheet(p))
		elif _sheets.has(p.get_instance_id()):
			(_sheets[p.get_instance_id()][0] as Node3D).visible = false
	for id in _sheets.keys():
		if not is_instance_valid(_sheets[id][0]):
			_sheets.erase(id)


## Between the hands: the right roll in the right hand, the left in the left, the sheet as wide open
## as they are apart, turned up to the reader's eyes.
func _place(p: Node, e: Array) -> void:
	var body: Node3D = p.body_model
	var inv := body.global_transform.affine_inverse()
	var a: Vector3 = inv * (body.hand_l as Node3D).global_position
	var b: Vector3 = inv * (body.hand_r as Node3D).global_position
	var eye: Vector3 = inv * (body.head as Node3D).global_position
	var x := b - a
	var apart := x.length()
	x /= maxf(apart, 0.001)
	var t := (eye - (a + b) * 0.5).normalized()
	var cam := get_viewport().get_camera_3d()
	if p == player and _up and cam:
		# (ours tilts half way to the camera over the shoulder, to be read)
		t = (t + (inv * cam.global_position - (a + b) * 0.5).normalized()).normalized()
	var n := (t - x * t.dot(x)).normalized()
	var o := b - x * HALF.x
	(e[0] as Node3D).visible = true
	(e[0] as Node3D).transform = Transform3D(Basis(x, n.cross(x), n), o)
	var open := clampf(apart / (HALF.x * 2.0), 0.0, 1.0)
	((e[1] as MeshInstance3D).material_override as ShaderMaterial).set_shader_parameter("open", open)
	(e[2] as Node3D).position.x = HALF.x - HALF.x * 2.0 * open


func _sheet(p: Node) -> Array:
	var id := p.get_instance_id()
	if _sheets.has(id) and is_instance_valid(_sheets[id][0]):
		return _sheets[id]
	_meshes()
	var root := Node3D.new()
	root.name = "MapSheet"
	var mi := MeshInstance3D.new()
	mi.name = "Sheet"
	mi.mesh = _sheet_mesh
	var m := ShaderMaterial.new()
	m.shader = SHEET
	m.set_shader_parameter("half_w", HALF.x)
	m.set_shader_parameter("paper", PAPER)
	m.set_shader_parameter("page", _vp.get_texture() if p == player else _sketch)
	mi.material_override = m
	root.add_child(mi)
	var rolls: Array = []
	for side in [1.0, -1.0]:
		var r := MeshInstance3D.new()
		r.name = "Roll"
		r.mesh = _roll_mesh
		r.position.x = HALF.x * side
		root.add_child(r)
		rolls.append(r)
	for c in [mi] + rolls:
		(c as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		(c as GeometryInstance3D).visibility_range_end = 60.0
	(p.body_model as Node).add_child(root)
	_sheets[id] = [root, mi, rolls[1]]
	return _sheets[id]


## The sheet (a grid bowed a little away from the reader, front +Z, the page's top edge at +Y) and a roll.
static func _meshes() -> void:
	if _sheet_mesh:
		return
	var mb := MeshBuilder.new()
	var mat := StandardMaterial3D.new()
	const NX := 10
	const NY := 3
	var pt := func(i: int, j: int) -> Vector3:
		var u := float(i) / NX
		return Vector3((u * 2.0 - 1.0) * HALF.x, (1.0 - float(j) / NY * 2.0) * HALF.y, -0.025 * (1.0 - pow(u * 2.0 - 1.0, 2.0)))
	for j in range(NY):
		for i in range(NX):
			mb.add_quad(mat, pt.call(i, j), pt.call(i + 1, j), pt.call(i + 1, j + 1), pt.call(i, j + 1),
				Vector2(float(i) / NX, float(j) / NY), Vector2(float(i + 1) / NX, float(j) / NY),
				Vector2(float(i + 1) / NX, float(j + 1) / NY), Vector2(float(i) / NX, float(j + 1) / NY), Color.WHITE, Vector3.BACK)
	_sheet_mesh = mb.commit()
	var rb := MeshBuilder.new()
	var tall := HALF.y * 2.0 + 0.03
	rb.add_cylinder(PSXMat.lit("", Color(0.74, 0.62, 0.42)), Transform3D(Basis(), Vector3(0, -tall * 0.5, 0)), ROLL_R, ROLL_R, tall, 6, 1.0, Color.WHITE, true, true)
	var wood := PSXMat.lit("", Color(0.36, 0.22, 0.12))
	for s in [-1.0, 1.0]:
		rb.add_cylinder(wood, Transform3D(Basis(), Vector3(0, s * tall * 0.5 - (0.018 if s < 0.0 else 0.0), 0)), ROLL_R * 0.75, ROLL_R * 0.75, 0.018, 6, 1.0, Color.WHITE, true, true)
	_roll_mesh = rb.commit()
	_sketch = ImageTexture.create_from_image(_sketch_image())


## A crewmate's map seen from outside: ink coasts and a dotted course on the paper.
static func _sketch_image() -> Image:
	var img := Image.create(56, 32, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var ink := Color(0.3, 0.2, 0.12)
	for c in [[Vector2(16, 14), 7.0], [Vector2(38, 20), 5.0], [Vector2(44, 9), 3.0]]:
		for k in range(40):
			var a := TAU * k / 40.0
			var r: float = c[1] * (1.0 + 0.2 * sin(a * 3.0 + c[0].x))
			img.set_pixelv(Vector2i((c[0] + Vector2(cos(a), sin(a)) * r).round()), ink)
	for k in range(9):
		img.set_pixelv(Vector2i(20 + k * 2, 16 + int(k / 3.0)), Color(0.72, 0.14, 0.08))
	return img
