class_name LogPose
extends Node3D
## The log pose on a captain's left wrist (look key "log_pose"): a glass ball
## in a brass cradle on a leather band, a needle inside for each island it has
## set on (GameManager.log_pose_targets()). Unset, the needle drifts about.

const BALL_R := 0.042
const NEEDLE_LEN := 0.07
const COLORS := [Color(0.85, 0.12, 0.1), Color(0.15, 0.35, 0.9)]

var needles: Array[Node3D] = []
var _ball: Node3D
var _t: float = 0.0


## On the forearm `fore` (the arm runs down -y), the band round it at `y`
## with radius `band_r`; the ball sits on the back of the wrist (-z).
static func attach(fore: Node3D, y: float, band_r: float) -> LogPose:
	var lp := LogPose.new()
	lp.name = "LogPose"
	lp.position = Vector3(0, y, 0)
	fore.add_child(lp)
	lp._build(band_r)
	return lp


func _build(band_r: float) -> void:
	var leather := PSXMat.lit("leather", Color(0.45, 0.28, 0.16))
	var brass := PSXMat.lit("metal", Color(0.95, 0.75, 0.35))
	var mb := MeshBuilder.new()
	mb.add_loft(leather, Transform3D.IDENTITY, [[-0.02, band_r, band_r], [0.02, band_r, band_r]], MeshBuilder.profile_oct(0.5), 3.0, Color.WHITE, false, false, true, false, true)
	# the cradle: a cup on the band, a cap over the ball, two posts between
	var out := Basis(Vector3.RIGHT, -PI * 0.5)
	var base_z := -band_r
	var centre := base_z - 0.012 - BALL_R
	mb.add_cylinder(brass, Transform3D(out, Vector3(0, 0, base_z + 0.002)), 0.028, 0.024, 0.014, 8, 3.0)
	mb.add_cylinder(brass, Transform3D(out, Vector3(0, 0, centre - BALL_R - 0.002)), 0.014, 0.008, 0.01, 6, 3.0)
	for s in [-1.0, 1.0]:
		mb.add_box(brass, Transform3D(Basis(), Vector3(s * (BALL_R + 0.004), 0, centre)), Vector3(0.006, 0.008, BALL_R * 2.2), 3.0, Color.WHITE, false)
	add_child(mb.to_instance("Cradle"))
	_ball = Node3D.new()
	_ball.name = "Ball"
	_ball.position = Vector3(0, 0, centre)
	add_child(_ball)
	for i in range(2):
		var n := Node3D.new()
		n.name = "Needle%d" % i
		var nb := MeshBuilder.new()
		nb.add_box(PSXMat.flat(COLORS[i]), Transform3D(Basis(), Vector3(0, 0, -NEEDLE_LEN * 0.25)), Vector3(0.006, 0.004, NEEDLE_LEN * 0.5), 3.0, Color.WHITE, false)
		nb.add_box(PSXMat.flat(Color(0.12, 0.12, 0.14)), Transform3D(Basis(), Vector3(0, 0, NEEDLE_LEN * 0.25)), Vector3(0.006, 0.004, NEEDLE_LEN * 0.5), 3.0, Color.WHITE, false)
		n.add_child(nb.to_instance("Mesh"))
		n.visible = i == 0
		_ball.add_child(n)
		needles.append(n)
	var glass := MeshInstance3D.new()
	glass.name = "Glass"
	var gb := MeshBuilder.new()
	gb.add_blob(_glass_mat(), Transform3D.IDENTITY, Vector3.ONE * BALL_R, RandomNumberGenerator.new(), 0.0, 5, 10, 1.0)
	glass.mesh = gb.commit()
	glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ball.add_child(glass)


static var _glass: StandardMaterial3D


static func _glass_mat() -> StandardMaterial3D:
	if _glass == null:
		_glass = StandardMaterial3D.new()
		_glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_glass.albedo_color = Color(0.75, 0.92, 1.0, 0.3)
		_glass.roughness = 0.08
		_glass.metallic_specular = 1.0
		_glass.rim_enabled = true
		_glass.rim = 0.6
	return _glass


func _process(delta: float) -> void:
	_t += delta
	# (by path: BodyBuilder loads this before the autoloads exist in --script tools)
	var gm := get_node_or_null("/root/GameManager")
	var targets: Array = gm.log_pose_targets() if gm else []
	var here := _ball.global_position
	for i in range(needles.size()):
		var n := needles[i]
		n.visible = i < maxi(targets.size(), 1)
		if not n.visible:
			continue
		var dir: Vector3
		if targets.is_empty():
			var a := _t * 0.7 + sin(_t * 1.9) * 1.4
			dir = Vector3(sin(a), 0, cos(a))
		else:
			var p: Vector2 = targets[i]["pos"]
			dir = Vector3(p.x - here.x, 0, p.y - here.z).normalized()
			# a little tremble, like a needle floating in water
			dir = dir.rotated(Vector3.UP, sin(_t * 7.0 + i * 2.0) * 0.04)
		n.global_basis = Basis.looking_at(dir, Vector3.UP)
