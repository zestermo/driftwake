class_name ChargeTarget
extends Node3D
## (1.30) A spot a powder charge blows open: a gate, a barricade, a wall marked "charge here" (a painted ring and
## cross on it). A captain using a charge within REACH of one plants it there instead of on the ground; the charge's
## blast (the host's) breaches every target in its radius. Breached on every machine (Net.event), then `breached`
## fires everywhere and, unless the maker handles it, the target's meshes and colliders go with a burst of rubble.
## CONTRACT (for the stronghold and anything else with doors to blow):
##   ChargeTarget.attach(target, spot, normal, opts) -> ChargeTarget   spot/normal in target's space; opts:
##       "needs" (charges to break it, 1), "remove" (true: hide target's meshes, turn its colliders off), "mark" (true)
##   signal breached(by: Node)      every machine (by: the captain whose charge did it, null on a guest's copy)
##   t.done                         breached already
##   t.breach_now()                 (a late joiner, a save) breached quietly, no effects
##   ChargeTarget.near(at, r)       the unbreached spot nearest `at` within r (null none)
##   ChargeTarget.blast(at, r, by)  (host) a charge going off: every unbreached target within r takes one
## Nothing runs per frame.

signal breached(by: Node)

const GROUP := "charge_targets"
## A charge used this close to a target's spot goes on it.
const REACH := 2.6
const MARK := Color(0.82, 0.16, 0.1, 0.9)

var target: Node3D
var needs := 1
var remove := true
var taken := 0
var done := false
var _mark: MeshInstance3D
static var _mark_mesh: ArrayMesh


static func attach(on: Node3D, spot: Vector3, normal: Vector3, opts := {}) -> ChargeTarget:
	var t := ChargeTarget.new()
	t.name = "ChargeTarget"
	t.target = on
	t.needs = int(opts.get("needs", 1))
	t.remove = bool(opts.get("remove", true))
	on.add_child(t)
	var n := normal.normalized()
	t.transform = Transform3D(Basis.looking_at(-n, Vector3.UP if absf(n.y) < 0.95 else Vector3.FORWARD), spot)
	if opts.get("mark", true):
		t._mark = MeshInstance3D.new()
		t._mark.mesh = mark_mesh()
		t._mark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		t._mark.visibility_range_end = 70.0
		t._mark.position = Vector3(0, 0, 0.03)
		t.add_child(t._mark)
	return t


func _ready() -> void:
	add_to_group(GROUP)


## The way out of the surface the charge sits on.
func normal() -> Vector3:
	return global_basis.z


static func near(at: Vector3, r: float) -> ChargeTarget:
	var best: ChargeTarget = null
	var bd := r
	for n in Engine.get_main_loop().get_nodes_in_group(GROUP):
		var t := n as ChargeTarget
		if t.done:
			continue
		var d := t.global_position.distance_to(at)
		if d < bd:
			bd = d
			best = t
	return best


static func blast(at: Vector3, r: float, by: Node) -> void:
	for n in Engine.get_main_loop().get_nodes_in_group(GROUP):
		var t := n as ChargeTarget
		if not t.done and t.global_position.distance_to(at) <= r:
			t._take(by)


func _take(by: Node) -> void:
	taken += 1
	if taken < needs:
		FX.debris(global_position, normal(), 8, Color(0.4, 0.35, 0.3), 5.0)
		return
	_breach(by, true)
	Net.event(self, "breach", [Net.key_of(by)])


func net_event(what: String, args: Array) -> void:
	if what == "breach":
		_breach(Net.node_of(str(args[0])), true)


func breach_now() -> void:
	_breach(null, false)


func _breach(by: Node, show: bool) -> void:
	if done:
		return
	done = true
	taken = needs
	if _mark:
		_mark.visible = false
	if show:
		var at := global_position
		FX.debris(at, normal(), 26, Color(0.42, 0.36, 0.3), 9.0)
		FX.debris(at + Vector3.UP, normal(), 14, Color(0.3, 0.22, 0.15), 7.0)
		FX.dust(at, 14, 1.6)
		FX.sfx("wood_crack", at, 0.0, 0.1, 0.8)
	if remove:
		_hide(target)
	breached.emit(by)


static func _hide(n: Node) -> void:
	for c in n.get_children():
		if c is ChargeTarget:
			continue
		if c is GeometryInstance3D:
			(c as GeometryInstance3D).visible = false
		elif c is CollisionShape3D:
			(c as CollisionShape3D).set_deferred("disabled", true)
		_hide(c)


## The painted mark: a ring with a cross in it, ~0.9 m across, lying in the spot's XY plane.
static func mark_mesh() -> ArrayMesh:
	if _mark_mesh:
		return _mark_mesh
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.BACK)
	var seg := 16
	for i in range(seg):
		var a0 := TAU * i / seg
		var a1 := TAU * (i + 1) / seg
		var o0 := Vector3(cos(a0), sin(a0), 0) * 0.45
		var o1 := Vector3(cos(a1), sin(a1), 0) * 0.45
		var i0 := o0 * 0.8
		var i1 := o1 * 0.8
		_quad(st, i0, o0, o1, i1)
	for d in [Vector3(1, 1, 0).normalized(), Vector3(1, -1, 0).normalized()]:
		var s: Vector3 = Vector3(-d.y, d.x, 0) * 0.045
		_quad(st, -d * 0.34 - s, d * 0.34 - s, d * 0.34 + s, -d * 0.34 + s)
	_mark_mesh = st.commit()
	_mark_mesh.surface_set_material(0, PSXMat.decal(MARK, {}))
	return _mark_mesh


static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	# (both windings: seen from either side of whatever it's painted on)
	for v in [a, b, c, a, c, d, a, c, b, a, d, c]:
		st.set_uv(Vector2(v.x, v.y) + Vector2(0.5, 0.5))
		st.add_vertex(v)
