class_name WillSight
extends Node3D
## Sense seen through walls, on the captain's own screen only: a small marker drawn over everything (no depth test)
## on each thing it shows, following it. Glimpse (WillArts): foes and closed chests within GLIMPSE_REACH for a few
## seconds. Weak Point (WillPowers): a boss's unbroken parts (BeastParts) while one is within WEAK_REACH.

const GLIMPSE_REACH := 40.0
const WEAK_REACH := 40.0
const MAX := 24
const FOE := Color(0.75, 0.5, 1.0)
const CHEST := Color(1.0, 0.82, 0.3)
const PART := Color(1.0, 0.42, 0.3)

var _left := INF
## [Callable() -> Vector3 (INF: gone), marker]
var _marks: Array = []
static var _mats: Dictionary = {}
static var _mesh: Mesh


static func glimpse(p: Node3D, secs: float) -> WillSight:
	var s := _make(p, "Glimpse")
	s._left = secs
	var at := p.global_position
	for e in p.get_tree().get_nodes_in_group("enemies"):
		if e is Node3D and BurnStatus.alive(e) and (e as Node3D).global_position.distance_to(at) <= GLIMPSE_REACH:
			var n := e as Node3D
			s.add(func(): return n.global_position + Vector3(0, 2.1, 0) if is_instance_valid(n) and BurnStatus.alive(n) else Vector3.INF, FOE)
	for b in p.get_tree().get_nodes_in_group("loot_bags"):
		var bag := b as LootBag
		if bag.save_id != "" and not bag.rolled and bag.global_position.distance_to(at) <= GLIMPSE_REACH:
			s.add(func(): return bag.global_position + Vector3(0, 0.8, 0) if is_instance_valid(bag) and not bag.rolled else Vector3.INF, CHEST)
	return s


## A boss's parts (its BeastParts), shown until freed.
static func weak_points(p: Node3D, boss: Node3D, parts: BeastParts) -> WillSight:
	var s := _make(p, "WeakPoint")
	for n in parts.parts.keys():
		var nm: String = n
		s.add(func(): return parts.where(nm, p.global_position) if is_instance_valid(boss) and BurnStatus.alive(boss) and not parts.broken(nm) else Vector3.INF, PART)
	return s


static func _make(p: Node3D, nm: String) -> WillSight:
	var s := WillSight.new()
	s.name = nm
	p.get_tree().current_scene.add_child(s)
	return s


func add(where: Callable, col: Color) -> void:
	if _marks.size() >= MAX:
		return
	var m := MeshInstance3D.new()
	m.mesh = _diamond()
	m.material_override = _mat(col)
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(m)
	_marks.append([where, m])


func _process(delta: float) -> void:
	_left -= delta
	for mk in _marks:
		var at: Vector3 = (mk[0] as Callable).call()
		(mk[1] as MeshInstance3D).visible = at != Vector3.INF
		if at != Vector3.INF:
			(mk[1] as MeshInstance3D).global_position = at
	if _left <= 0.0:
		queue_free()


static func _diamond() -> Mesh:
	if _mesh == null:
		var sm := SphereMesh.new()
		sm.radius = 0.16
		sm.height = 0.42
		sm.radial_segments = 4
		sm.rings = 2
		_mesh = sm
	return _mesh


static func _mat(col: Color) -> StandardMaterial3D:
	var k := col.to_html()
	if not _mats.has(k):
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.no_depth_test = true
		m.albedo_color = col
		m.render_priority = 10
		_mats[k] = m
	return _mats[k]
