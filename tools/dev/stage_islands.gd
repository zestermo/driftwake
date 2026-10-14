extends Node
## The stage's stand-in for WorldGenerator ("world_gen"): no Brinehollow, no chain, no islands built.

var chain_islands := {}
var starter_island = null


func _ready() -> void:
	add_to_group("world_gen")


func chain():
	return null


func chain_ready() -> bool:
	return true


func standing(_isl: Node) -> bool:
	return true
