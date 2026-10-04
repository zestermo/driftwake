class_name CoinPickup
extends Node3D
## A gold coin knocked loose from a defeated creature. It pops out, bounces,
## spins on the ground and flies to you when you walk close.

const GOLD_PATH := "res://resources/items/gold.tres"
const MAGNET_RANGE := 2.8
const LIFETIME := 120.0

static var _mesh: ArrayMesh
static var _gold: ItemData

var vel := Vector3.ZERO
var _t: float = 0.0
var _landed: bool = false
var _ground_y: float = 0.0
var _player: Node3D
var _pull: float = 0.0


## Throw `count` coins out from `pos`.
static func spawn(tree: SceneTree, pos: Vector3, count: int) -> void:
	var root: Node = tree.current_scene if tree.current_scene else tree.root
	for i in range(count):
		var c := CoinPickup.new()
		c.name = "Coin"
		root.add_child(c)
		c.global_position = pos
		var a := randf() * TAU
		var r := randf_range(0.9, 2.0)
		c.vel = Vector3(cos(a) * r, randf_range(3.6, 5.0), sin(a) * r)


func _ready() -> void:
	if _mesh == null:
		var mb := MeshBuilder.new()
		var m := PSXMat.lit("", Color(1.0, 0.8, 0.3), {"emission": Color(0.55, 0.38, 0.08), "emission_energy": 0.7})
		mb.add_cylinder(m, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 0, -0.011)), 0.07, 0.07, 0.022, 8, 0.5, Color.WHITE, true, true, false)
		_mesh = mb.commit()
	var mi := MeshInstance3D.new()
	mi.mesh = _mesh
	add_child(mi)
	rotation.y = randf() * TAU


func _physics_process(delta: float) -> void:
	_t += delta
	rotate_y(delta * 4.5)
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node3D
	# fly to the player once you're close (after it has popped out)
	if _player and _t > 0.5:
		var target := _player.global_position + Vector3(0, 0.8, 0)
		var d := target - global_position
		if d.length() < MAGNET_RANGE or _pull > 0.0:
			_pull = minf(_pull + delta * 3.0, 1.0)
			global_position += d.normalized() * minf(d.length(), (4.0 + 10.0 * _pull) * delta)
			if d.length() < 0.45:
				_collect()
			return
	if not _landed:
		vel.y -= 14.0 * delta
		var from := global_position
		var to := from + vel * delta
		var q := PhysicsRayQueryParameters3D.create(from + Vector3.UP * 0.05, to + Vector3.DOWN * 0.1, 1)
		var hit := get_world_3d().direct_space_state.intersect_ray(q)
		if hit.is_empty():
			global_position = to
		else:
			global_position = (hit["position"] as Vector3) + Vector3.UP * 0.12
			if vel.y < -2.5:
				vel = Vector3(vel.x * 0.5, -vel.y * 0.35, vel.z * 0.5)
			else:
				_landed = true
				_ground_y = global_position.y
	else:
		global_position.y = _ground_y + 0.03 + sin(_t * 3.0) * 0.03
	if _t > LIFETIME:
		queue_free()


func _collect() -> void:
	if _gold == null:
		_gold = load(GOLD_PATH)
	var inv := _player.get_node_or_null("InventoryComponent") as InventoryComponent
	if inv == null or not inv.add_item(_gold, 1):
		_pull = 0.0
		return
	FX.sfx("coin", global_position, -4.0, 0.12)
	FX.sparkle(global_position, 4, Color(1.0, 0.85, 0.35))
	queue_free()
