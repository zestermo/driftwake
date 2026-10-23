class_name Decoy
extends Node3D
## Afterimage (Acrobatics): a pale copy of the captain left standing where they dodged from. Made on every screen by
## FX.decoy (Net.fx); on the host it lures the foes after that captain within LURE_REACH (PirateGrunt.lure): they
## swing at it instead, and the blow that lands shatters it (FX.decoy_break, through Net.fx). It holds, flickers and
## fades over its life.

const LURE_REACH := 7.0
const COLOR := Color(0.72, 0.86, 1.0)

var captain: Node3D
var spot := Vector3.ZERO
var life := 1.6
var _t := 0.0
var _mat: StandardMaterial3D


static func spawn(root: Node, body: Node3D, secs: float) -> Decoy:
	var d := Decoy.new()
	d.name = "Decoy"
	d.life = secs
	root.add_child(d)
	d.global_transform = Transform3D.IDENTITY
	d.spot = body.global_position
	d.captain = _captain_of(body)
	d._copy(body)
	d.add_to_group("decoys")
	d._lure()
	return d


func _lure() -> void:
	if not Net.is_host():
		return
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.has_method("lure") and (e as Node3D).global_position.distance_to(spot) < LURE_REACH:
			e.call("lure", self)


static func _captain_of(body: Node) -> Node3D:
	var n := body
	while n != null and not n.is_in_group("players"):
		n = n.get_parent()
	return n as Node3D


## The decoy nearest `at` within `reach` m, or null.
static func near(tree: SceneTree, at: Vector3, reach: float) -> Decoy:
	var best: Decoy = null
	for d in tree.get_nodes_in_group("decoys"):
		var dd := d as Decoy
		if dd.spot.distance_to(at) < reach:
			reach = dd.spot.distance_to(at)
			best = dd
	return best


func alive() -> bool:
	return is_inside_tree() and _t < life


func _copy(body: Node3D) -> void:
	_mat = StandardMaterial3D.new()
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.albedo_color = Color(COLOR.r, COLOR.g, COLOR.b, 0.6)
	var n := 0
	var skels := {}
	for mi in body.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null or not m.is_visible_in_tree():
			continue
		var c: MeshInstance3D = FX.still_copy(m, self, skels)
		c.material_override = _mat
		c.visibility_range_end = 60.0
		n += 1
		if n > 40:
			break


func _process(delta: float) -> void:
	_t += delta
	var k := _t / life
	var a := 0.6
	if k > 0.6:
		# flickering out: on and off, fainter each time
		a = (0.5 if int(_t * 18.0) % 2 == 0 else 0.15) * (1.0 - (k - 0.6) / 0.4)
	_mat.albedo_color.a = a
	if _t >= life:
		queue_free()


## Struck: it bursts into pale shards and is gone.
func shatter() -> void:
	var at := spot + Vector3(0, 1.0, 0)
	FX.flash(at, 1.4, Color(0.85, 0.93, 1.0), "glint", 0.18)
	FX.ring(at, Vector3.UP, 1.3, Color(0.8, 0.9, 1.0, 0.8), 0.28, 0.06)
	FX.sparkle(at, 14, COLOR)
	FX.sfx("parry", at, -8.0, 0.05, 1.5)
	remove_from_group("decoys")
	queue_free()
