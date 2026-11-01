class_name GadgetThrow
extends Node3D
## A thrown gadget in flight: an arc from the hand to where it lands (a fuse spark trailing a smoke pellet), then
## its GadgetZone. Runs on every screen (the thrower's own, the others from its event); it lives only while flying.

## Flight time: a base and so much a metre; the arc's height likewise.
const SECS := [0.32, 0.028]
const ARC := [0.8, 0.14]

var gid := ""
var by: Node
var tier := 0
var _from := Vector3.ZERO
var _to := Vector3.ZERO
var _secs := 0.5
var _arc := 1.0
var _t := 0.0
var _mesh: MeshInstance3D
var _spin := Vector3.ZERO


static func launch(tree: SceneTree, g: String, t: int, from: Vector3, to: Vector3, thrower: Node = null) -> GadgetThrow:
	var n := GadgetThrow.new()
	n.by = thrower
	n.gid = g
	n.tier = t
	n._from = from
	n._to = to
	var d := from.distance_to(to)
	n._secs = SECS[0] + SECS[1] * d
	n._arc = ARC[0] + ARC[1] * d
	(tree.current_scene if tree.current_scene else tree.root).add_child(n)
	n.global_position = from
	return n


func _ready() -> void:
	_mesh = MeshInstance3D.new()
	_mesh.mesh = GadgetModels.mesh(gid, tier)
	_mesh.scale = Vector3.ONE * 1.6
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mesh)
	_spin = Vector3(randf_range(8.0, 14.0), randf_range(-4.0, 4.0), randf_range(3.0, 7.0))
	FX.sfx("whoosh", _from, -10.0, 0.1, 1.3)
	reset_physics_interpolation()


func _physics_process(delta: float) -> void:
	_t += delta
	var u := minf(_t / _secs, 1.0)
	global_position = _from.lerp(_to, u) + Vector3.UP * (4.0 * _arc * u * (1.0 - u))
	_mesh.rotation += _spin * delta
	if gid in ["smoke", "flash", "star", "pepper", "lantern_bomb"] and Engine.get_physics_frames() % 3 == 0:
		FX.puff(global_position, "dust", 1, 0.25, 0.4, Color(1.0, 0.8, 0.5, 0.8), 0.2)
	if u >= 1.0:
		var who: Node = by if by and is_instance_valid(by) else null
		if gid == "decoy":
			GadgetDecoy.landed(get_tree(), tier, _to, who)
		else:
			GadgetZone.spawn(get_tree(), gid, tier, _to, who)
		queue_free()
