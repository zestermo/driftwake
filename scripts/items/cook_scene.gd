class_name CookScene
extends Node3D
## The cooking game seen in first person (CookGameScreen): a counter set out in front of the captain with
## a pot and its spoon, a pan over a little brazier and a plate that slides across, and a camera at the
## captain's eyes that looks at whichever one the beat (CookTiming) is on. Only this screen's captain sees
## it (cooking is each captain's own); it runs while the tree is paused in single player. Built from boxes
## and cylinders (MeshBuilder), one warm light from the brazier while it's up.

## The counter's top centre is the origin; -Z away from the captain, +X to their right.
const POT := Vector3(-0.27, 0.0, -0.06)
const PAN := Vector3(0.27, 0.0, -0.06)
const PLATE_Z := 0.17
const PLATE_RUN := 0.3
const EYE := Vector3(0.0, 0.6, 0.5)
const RIM := 0.1
const HELD_Y := 0.2

## Ingredient tags' colours in the pot and on the plate.
const TAG_COL := {"fish": Color(0.95, 0.66, 0.5), "meat": Color(0.62, 0.28, 0.2), "grain": Color(0.93, 0.86, 0.66),
	"fruit": Color(0.98, 0.58, 0.2), "greens": Color(0.36, 0.62, 0.28), "spice": Color(0.82, 0.24, 0.14),
	"island": Color(0.9, 0.5, 0.7)}
const RAW := Color(0.92, 0.62, 0.58)
const SEARED := Color(0.5, 0.26, 0.14)

var timing: CookTiming
var cam: Camera3D
var _prev_cam: Camera3D
var _hidden: Node3D
## The HUD layers hidden while it's up (the compass and the loot line over the counter).
var _huds: Array = []
var _look := Vector3.ZERO
var _spoon: Node3D
var _mark: Node3D
var _broth: Node3D
var _flames: Array = []
var _food: MeshInstance3D
var _food_mat: ShaderMaterial
var _plate: Node3D
var _held: Node3D
var _served: Node3D
var _light: OmniLight3D
## A flip in the air: seconds left, and how well it was timed.
var _flip_t := 0.0
var _flip_s := 1.0
var _mark_pulse := 0.0
var _t := 0.0
var _col := Color.WHITE


## Set out in front of `p` (their feet and facing) for meal `meal_id`; the camera goes to their eyes.
static func make(p: Node3D, meal_id: String) -> CookScene:
	var s := CookScene.new()
	s.process_mode = Node.PROCESS_MODE_ALWAYS
	s._col = colour_of(meal_id)
	var fwd: Vector3 = -p.global_transform.basis.z
	var model = p.get("body_model")
	if model is Node3D:
		fwd = (model as Node3D).global_transform.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized() if fwd.length() > 0.01 else Vector3.FORWARD
	p.get_tree().current_scene.add_child(s)
	var at := p.global_position + fwd * 0.5 + Vector3(0, 0.95, 0)
	s.global_transform = Transform3D(Basis.looking_at(fwd, Vector3.UP), at)
	s._build()
	s._enter(p)
	return s


## The dish's colour: its ingredients' colours mixed.
static func colour_of(meal_id: String) -> Color:
	var r: Dictionary = Food.MEALS.get(meal_id, {}).get("recipe", {})
	var c := Color(0, 0, 0)
	var n := 0.0
	for tag in r.keys():
		c += TAG_COL.get(tag, Color.WHITE) * float(r[tag])
		n += float(r[tag])
	return Color(c.r / n, c.g / n, c.b / n) if n > 0.0 else Color(0.85, 0.6, 0.35)


func _enter(p: Node3D) -> void:
	_prev_cam = get_viewport().get_camera_3d()
	cam = Camera3D.new()
	cam.fov = 52.0
	cam.near = 0.03
	add_child(cam)
	cam.position = EYE
	_look = Vector3(0, 0, 0.02)
	cam.look_at(to_global(_look), Vector3.UP)
	cam.make_current()
	# (the head would be in the way)
	var model = p.get("body_model")
	if model is Node3D and (model as Node3D).visible:
		_hidden = model
		_hidden.visible = false
	for h in get_tree().get_nodes_in_group("hud"):
		if h is CanvasLayer and (h as CanvasLayer).visible:
			(h as CanvasLayer).visible = false
			_huds.append(h)


## Done: the camera back where it was, the captain seen again, the set gone.
func leave() -> void:
	if is_instance_valid(_hidden):
		_hidden.visible = true
	for h in _huds:
		if is_instance_valid(h):
			h.visible = true
	if is_instance_valid(_prev_cam):
		_prev_cam.make_current()
	queue_free()


func _build() -> void:
	var wood := PSXMat.lit("planks", Color(0.85, 0.72, 0.58))
	var iron := PSXMat.lit("metal", Color(0.42, 0.42, 0.46))
	var dark := PSXMat.flat(Color(0.12, 0.11, 0.1))
	var mb := MeshBuilder.new()
	# the counter (a board on two trestles)
	mb.add_box(wood, Transform3D(Basis(), Vector3(0, -0.03, 0.02)), Vector3(1.1, 0.06, 0.64), 0.5, Color.WHITE, false)
	for x in [-0.45, 0.45]:
		mb.add_box(wood, Transform3D(Basis(), Vector3(x, -0.5, 0.02)), Vector3(0.06, 0.88, 0.5), 0.5, Color(0.8, 0.8, 0.8))
	# the pot: iron outside, dark inside, two lugs
	mb.add_cylinder(iron, Transform3D(Basis(), POT), 0.11, 0.13, 0.15, 12, 0.5, Color.WHITE, false)
	mb.add_cylinder(dark, Transform3D(Basis(), POT + Vector3(0, 0.005, 0)), 0.1, 0.12, 0.14, 12, 0.5, Color.WHITE, false)
	for sx in [-1.0, 1.0]:
		mb.add_box(iron, Transform3D(Basis(), POT + Vector3(sx * 0.145, 0.12, 0)), Vector3(0.03, 0.02, 0.05))
	# the brazier under the pan: a squat iron bowl, coals
	mb.add_cylinder(iron, Transform3D(Basis(), PAN), 0.09, 0.12, 0.07, 10, 0.5, Color(0.6, 0.6, 0.6))
	mb.add_cylinder(PSXMat.glow(Color(1.0, 0.4, 0.1), 2.0), Transform3D(Basis(), PAN + Vector3(0, 0.07, 0)), 0.105, 0.105, 0.005, 10)
	# three prongs holding the pan
	for i in range(3):
		var a := TAU * i / 3.0
		mb.add_box(iron, Transform3D(Basis(), PAN + Vector3(cos(a) * 0.11, 0.1, sin(a) * 0.11)), Vector3(0.012, 0.07, 0.012))
	# the pan
	mb.add_cylinder(iron, Transform3D(Basis(), PAN + Vector3(0, 0.13, 0)), 0.1, 0.115, 0.03, 12, 0.5, Color(0.7, 0.7, 0.75), false)
	mb.add_cylinder(dark, Transform3D(Basis(), PAN + Vector3(0, 0.132, 0)), 0.1, 0.1, 0.003, 12)
	mb.add_box(wood, Transform3D(Basis(), PAN + Vector3(0.2, 0.15, 0.02)), Vector3(0.16, 0.02, 0.025))
	# where the plate's to stop: a chalk tick on the board
	mb.add_box(PSXMat.flat(Color(0.95, 0.92, 0.8)), Transform3D(Basis(), Vector3(0, 0.001, PLATE_Z + 0.12)), Vector3(0.012, 0.002, 0.05))
	add_child(mb.to_instance("Set"))
	# the broth (turns slowly) with bits in it
	_broth = Node3D.new()
	_broth.position = POT + Vector3(0, 0.12, 0)
	add_child(_broth)
	var bb := MeshBuilder.new()
	bb.add_cylinder(PSXMat.flat(_col.darkened(0.15)), Transform3D(), 0.105, 0.105, 0.004, 12)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in range(7):
		var a := rng.randf() * TAU
		var r := rng.randf_range(0.02, 0.08)
		bb.add_box(PSXMat.flat(_col.lightened(rng.randf_range(0.0, 0.3))), Transform3D(Basis(Vector3.UP, a), Vector3(cos(a) * r, 0.006, sin(a) * r)), Vector3(0.022, 0.01, 0.018))
	_broth.add_child(bb.to_instance("Broth"))
	# the spoon: its pivot at the pot's middle, the bowl on a radius, the handle up and out
	_spoon = Node3D.new()
	_spoon.position = POT + Vector3(0, 0.12, 0)
	add_child(_spoon)
	var sb := MeshBuilder.new()
	sb.add_cylinder(wood, Transform3D(Basis(), Vector3(0.065, 0.0, 0)), 0.022, 0.026, 0.012, 6)
	sb.add_box(wood, Transform3D(Basis(Vector3.BACK, 0.5), Vector3(0.11, 0.09, 0)), Vector3(0.016, 0.2, 0.016))
	_spoon.add_child(sb.to_instance("Spoon"))
	# the mark on the rim: a glint the spoon must pass
	_mark = Node3D.new()
	_mark.position = POT + Vector3(0, 0.155, 0)
	add_child(_mark)
	var mk := MeshBuilder.new()
	mk.add_cylinder(PSXMat.glow(Color(1.0, 0.85, 0.35), 3.0), Transform3D(Basis(), Vector3(RIM + 0.02, 0, 0)), 0.018, 0.018, 0.012, 6)
	_mark.add_child(mk.to_instance("Mark"))
	# flames licking the pan, taller as the heat rises
	for i in range(3):
		var f := Node3D.new()
		var a := TAU * (i + 0.5) / 3.0
		f.position = PAN + Vector3(cos(a) * 0.1, 0.06, sin(a) * 0.1)
		add_child(f)
		var fb := MeshBuilder.new()
		fb.add_cone(PSXMat.glow(Color(1.0, 0.55 + 0.1 * i, 0.15), 2.5), Transform3D(), 0.04, 0.09, 5)
		f.add_child(fb.to_instance("Flame"))
		_flames.append(f)
	# the food in the pan: its own material, raw to seared with the heat
	var food_b := MeshBuilder.new()
	_food_mat = PSXMat.flat(Color.WHITE).duplicate() as ShaderMaterial
	food_b.add_cylinder(_food_mat, Transform3D(), 0.06, 0.055, 0.025, 8, 0.5, Color.WHITE, true, true)
	_food = food_b.to_instance("Food")
	_food.position = PAN + Vector3(0, 0.135, 0)
	add_child(_food)
	_food_mat.set_shader_parameter("tint_mul", RAW)
	# the plate, and the portion held over the tick, ready to drop
	_plate = Node3D.new()
	_plate.position = Vector3(-PLATE_RUN, 0.0, PLATE_Z)
	add_child(_plate)
	var pb := MeshBuilder.new()
	pb.add_cylinder(PSXMat.flat(Color(0.95, 0.93, 0.86)), Transform3D(), 0.1, 0.11, 0.014, 12)
	pb.add_cylinder(PSXMat.flat(Color(0.35, 0.5, 0.75)), Transform3D(Basis(), Vector3(0, 0.016, 0)), 0.1, 0.1, 0.002, 12)
	pb.add_cylinder(PSXMat.flat(Color(0.95, 0.93, 0.86)), Transform3D(Basis(), Vector3(0, 0.019, 0)), 0.085, 0.085, 0.002, 12)
	_plate.add_child(pb.to_instance("Plate"))
	_held = _portion()
	_held.position = Vector3(0, HELD_Y, PLATE_Z)
	add_child(_held)
	_held.visible = false
	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.7, 0.45)
	_light.light_energy = 0.9
	_light.omni_range = 1.6
	_light.position = Vector3(0, 0.45, 0.15)
	add_child(_light)


## A heaped portion of the dish.
func _portion() -> Node3D:
	var b := MeshBuilder.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	b.add_blob(PSXMat.flat(_col), Transform3D(Basis(), Vector3(0, 0.025, 0)), Vector3(0.06, 0.03, 0.05), rng)
	for i in range(4):
		var a := TAU * i / 4.0 + 0.3
		b.add_box(PSXMat.flat(_col.lightened(0.25)), Transform3D(Basis(Vector3.UP, a), Vector3(cos(a) * 0.03, 0.05, sin(a) * 0.03)), Vector3(0.02, 0.012, 0.02))
	return b.to_instance("Portion")


## A press landed (CookGameScreen): the beat's own motion for it.
## `plate_x`: where the plate was when it was pressed (the beat's over by now).
func pressed(beat: String, s: float, plate_x: float = 0.0) -> void:
	match beat:
		"stir":
			_mark_pulse = 0.35 if s > 0.0 else 0.0
		"flip":
			_flip_t = 0.5
			_flip_s = s
		"plate":
			_plate.position.x = plate_x * PLATE_RUN
			_drop(s)


## The portion drops onto the plate where it is (off-centre: it lands askew on the rim).
func _drop(s: float) -> void:
	_held.visible = false
	_served = _portion()
	_plate.add_child(_served)
	var off := -_plate.position.x
	_served.position = Vector3(clampf(off, -0.08, 0.08), 0.02, 0)
	if s < 0.6:
		_served.rotation = Vector3(0.0, 0.0, -signf(off) * 0.35)


func _process(delta: float) -> void:
	_t += delta
	var beat := timing.current() if timing else ""
	# where to look: the pot, the pan, the plate; the plate at the end
	var want := Vector3(0, 0, PLATE_Z)
	match beat:
		"stir":
			want = POT + Vector3(0, 0.06, 0.03)
		"flip":
			want = PAN + Vector3(0, 0.08, 0.03)
		"plate":
			want = Vector3(0, 0.05, PLATE_Z)
	_look = _look.lerp(want, clampf(5.0 * delta, 0.0, 1.0))
	cam.position = EYE + Vector3(_look.x * 0.35, 0, 0)
	cam.look_at(to_global(_look), Vector3.UP)
	# the stir
	_broth.rotation.y -= delta * 0.6
	if beat == "stir":
		_spoon.rotation.y = -timing.spoon_angle()
		_mark.rotation.y = -timing.mark_angle()
		_mark.visible = true
	else:
		_mark.visible = false
		_spoon.rotation.y -= delta * 1.2
	_mark_pulse = maxf(_mark_pulse - delta, 0.0)
	_mark.scale = Vector3.ONE * (1.0 + 0.25 * sin(_t * 9.0) * 0.3 + _mark_pulse * 2.5)
	# the heat: flames grow, the food sears
	var h := timing.heat() if beat == "flip" else (0.25 if beat == "stir" else 0.15)
	for i in range(_flames.size()):
		var f: Node3D = _flames[i]
		f.scale = Vector3(1.0, 0.5 + 1.6 * h + 0.15 * sin(_t * 17.0 + i * 2.1), 1.0)
	if beat == "flip":
		_food_mat.set_shader_parameter("tint_mul", RAW.lerp(SEARED, clampf(timing.heat(), 0.0, 1.0)))
	_light.light_energy = 0.7 + 0.5 * h + 0.06 * sin(_t * 23.0)
	# a flip in the air: up, over, down
	if _flip_t > 0.0:
		_flip_t = maxf(_flip_t - delta, 0.0)
		var u := 1.0 - _flip_t / 0.5
		_food.position = PAN + Vector3(0, 0.135 + sin(u * PI) * (0.08 + 0.12 * _flip_s), 0)
		_food.rotation.x = u * PI * (1.0 if _flip_s > 0.3 else 0.5)
	# the plate sweeps under the held portion
	_held.visible = beat == "plate"
	if beat == "plate":
		_plate.position.x = timing.plate_x() * PLATE_RUN
		_held.position.y = HELD_Y + 0.01 * sin(_t * 6.0)
