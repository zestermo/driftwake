extends Node3D
class_name Island

@export var island_name: String = "Unknown Island"
@export var island_type: String = "wild"

var is_generated: bool = false
var dock_position: Vector3 = Vector3.ZERO
var spawn_points: Array[Marker3D] = []
var loot_spawns: Array[Marker3D] = []


func _ready() -> void:
	var sp_node := get_node_or_null("SpawnPoints")
	if sp_node:
		for child in sp_node.get_children():
			if child is Marker3D:
				spawn_points.append(child)

	var ls_node := get_node_or_null("LootSpawns")
	if ls_node:
		for child in ls_node.get_children():
			if child is Marker3D:
				loot_spawns.append(child)
