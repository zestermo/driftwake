extends Node3D
class_name Island

@export var island_name: String = "Unknown Island"
@export var island_type: String = "wild"

var is_generated: bool = false
var dock_position: Vector3 = Vector3.ZERO
var spawn_points: Array[Marker3D] = []
var loot_spawns: Array[Marker3D] = []


## The ground and its bookkeeping, as the island kit (KitContext) sees it. Island
## space; pure data, so a worker's prepare may call them. StarterIsland and
## GenIsland override every one.
func hv(_p: Vector2) -> float:
	push_error("%s has no hv" % name)
	return 0.0


## hv as (x, z): what NPCs walk on (NPC.ground_func).
func walk_height(_x: float, _z: float) -> float:
	push_error("%s has no walk_height" % name)
	return 0.0


func reserve(_p: Vector2, _r: float) -> void:
	push_error("%s has no reserve" % name)


## Within `pad` of anything reserved (only reserves smaller than `under` count).
func excluded(_p: Vector2, _pad: float, _under := INF) -> bool:
	push_error("%s has no excluded" % name)
	return false


func path_dist(_p: Vector2) -> float:
	push_error("%s has no path_dist" % name)
	return 0.0


## A name for something of this island in the save (chests opened, ...).
func save_key(key: String) -> String:
	push_error("%s has no save_key for %s" % [name, key])
	return key


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
