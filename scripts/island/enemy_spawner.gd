extends Node
class_name EnemySpawner

@export var enemy_scene: PackedScene
@export var max_enemies: int = 5

var active_enemies: Array[Node] = []
var island: Island


func _ready() -> void:
	island = get_parent() as Island


func spawn_enemies() -> void:
	if not enemy_scene or not island:
		return
	for point in island.spawn_points:
		if active_enemies.size() >= max_enemies:
			break
		var enemy: Node = enemy_scene.instantiate()
		enemy.global_position = point.global_position
		island.add_child(enemy)
		active_enemies.append(enemy)


func _process(_delta: float) -> void:
	active_enemies = active_enemies.filter(func(e: Node) -> bool: return is_instance_valid(e))
