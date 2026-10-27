class_name StillPoint
extends Node
## Tempo Will's Still Point (WillArts): the foes within reach of where it was found move and strike at half speed for a
## few seconds. Started on every machine (Net._all_will "still"): the host, which runs the foes, lets each one think and
## move only every other physics tick; every screen plays their bodies at half speed and leaves a pale afterimage now
## and then. Their state is put back when it ends (or they're gone).

const SLOW := 0.5
const TRAIL_EVERY := 15
const TRAIL := Color(0.75, 0.85, 1.0)

var _left := 0.0
## [foe, it was physics-processing when slowed]
var _foes: Array = []
var _n := 0


static func start(center: Vector3, reach: float, secs: float) -> StillPoint:
	var tree := Engine.get_main_loop() as SceneTree
	var sp := StillPoint.new()
	sp.name = "StillPoint"
	sp._left = secs
	for e in tree.get_nodes_in_group("enemies"):
		if e is Node3D and BurnStatus.alive(e) and (e as Node3D).global_position.distance_to(center) <= reach:
			sp._foes.append([e, e.is_physics_processing()])
	tree.current_scene.add_child(sp)
	return sp


static func slowed(e: Node) -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	for sp in tree.current_scene.get_children():
		if sp is StillPoint and (sp as StillPoint)._foes.any(func(f): return f[0] == e):
			return true
	return false


func _ready() -> void:
	for f in _foes:
		var h := (f[0] as Node).get("humanoid") as Humanoid
		if h:
			h.time_k = SLOW


func _physics_process(delta: float) -> void:
	_left -= delta
	_n += 1
	_foes = _foes.filter(func(f): return is_instance_valid(f[0]))
	for f in _foes:
		var e := f[0] as Node3D
		if Net.is_host() and f[1]:
			e.set_physics_process(_n % 2 == 0)
		if (_n + e.get_instance_id()) % TRAIL_EVERY == 0:
			var h := e.get("humanoid") as Humanoid
			if h:
				FX.afterimage(h, TRAIL, 0.3)
	if _left <= 0.0:
		_end()


func _end() -> void:
	for f in _foes:
		var e := f[0] as Node
		if Net.is_host() and f[1]:
			e.set_physics_process(true)
		var h := e.get("humanoid") as Humanoid
		if h:
			h.time_k = 1.0
	_foes.clear()
	queue_free()
