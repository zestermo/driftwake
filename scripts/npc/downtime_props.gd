class_name DowntimeProps
extends Node
## What a downtime loop holds (DowntimePoses and ClipPlayer call ensure() each frame they pose one): an open book, a mallet and
## a lock to fiddle with, a rod. Made on every screen from the body's action (so a crewmate's puppet holds it
## too), and gone the frame the body does something else.

## action -> the props it holds
const HOLDS := {"clip_read": ["crate", "book"], "dt_tinker": ["crate", "mallet", "lock"], "dt_fish": ["rod"], "dt_fish_reel": ["rod"]}

## The open book in the torso's frame.
const BOOK_AT := Vector3(0, 0.27, -0.36)

var body
var held: Array = []
var _meshes: Array = []


static func ensure(h, n: String) -> void:
	if not HOLDS.has(n):
		return
	var pr = h.get_node_or_null("DowntimeProps")
	if pr and pr.held == HOLDS[n]:
		return
	if pr:
		pr.free()
	pr = DowntimeProps.new()
	pr.name = "DowntimeProps"
	pr.body = h
	pr.held = HOLDS[n]
	h.add_child(pr)
	for what in pr.held:
		pr._add(what)


func _process(_d: float) -> void:
	if not HOLDS.has(body.current_action()) or HOLDS[body.current_action()] != held:
		queue_free()


func _exit_tree() -> void:
	for m in _meshes:
		if is_instance_valid(m):
			m.queue_free()


func _add(what: String) -> void:
	var mb := MeshBuilder.new()
	var parent: Node3D = body.hand_r
	var xf := Transform3D.IDENTITY
	match what:
		"book":
			# open in front of the chest between the hands, the spine away from you, tilted up to the eyes
			var cover := PSXMat.flat(Color(0.42, 0.16, 0.1))
			var page := PSXMat.flat(Color(0.9, 0.85, 0.7))
			for s in [-1.0, 1.0]:
				var b := Basis(Vector3.FORWARD, s * 0.2)
				mb.add_box(cover, Transform3D(b, Vector3(s * 0.08, 0, 0)), Vector3(0.16, 0.012, 0.22), 1.0)
				mb.add_box(page, Transform3D(b, Vector3(s * 0.075, 0.012, 0)), Vector3(0.145, 0.014, 0.2), 1.0)
			parent = body.torso
			xf = Transform3D(Basis(Vector3.RIGHT, 0.7), BOOK_AT)
		"mallet":
			var wood := PSXMat.lit("bark")
			mb.add_tube(wood, PackedVector3Array([Vector3(0, 0, 0.06), Vector3(0, 0, -0.2)]), 0.012, 0.012, 4, 1.0)
			mb.add_box(PSXMat.flat(Color(0.35, 0.33, 0.3)), Transform3D(Basis(), Vector3(0, 0, -0.22)), Vector3(0.08, 0.04, 0.04), 1.0)
		"lock":
			mb.add_box(PSXMat.flat(Color(0.55, 0.42, 0.18)), Transform3D(Basis(), Vector3(0, 0.03, -0.06)), Vector3(0.08, 0.06, 0.1), 1.0)
			mb.add_box(PSXMat.flat(Color(0.25, 0.25, 0.27)), Transform3D(Basis(), Vector3(0, 0.07, -0.06)), Vector3(0.03, 0.03, 0.06), 1.0)
			parent = body.hand_l
		"crate":
			# what you sit on (Downtime.seat_of's 0.45), under the hips
			var wood := PSXMat.lit("planks", Color(0.8, 0.68, 0.5))
			mb.add_box(wood, Transform3D(Basis(), Vector3(0, 0.21, 0.08)), Vector3(0.46, 0.42, 0.4), 1.0)
			mb.add_box(PSXMat.lit("planks", Color(0.6, 0.48, 0.32)), Transform3D(Basis(), Vector3(0, 0.43, 0.08)), Vector3(0.5, 0.03, 0.44), 1.0)
			parent = body
		"rod":
			var tip := Vector3(0, 0.7, -2.3)
			mb.add_tube(PSXMat.lit("bark"), PackedVector3Array([Vector3(0, 0, 0.25), tip]), 0.025, 0.02, 4, 1.0)
			mb.add_tube(PSXMat.flat(Color(0.85, 0.85, 0.8)), PackedVector3Array([tip, tip + Vector3(0, -2.6, -0.3)]), 0.006, 0.006, 3, 1.0)
	var mi := mb.to_instance("Downtime_" + what)
	mi.transform = xf
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	_meshes.append(mi)
