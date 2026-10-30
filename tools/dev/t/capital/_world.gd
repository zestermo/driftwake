extends Node
## t/capital's (and t/canal's) stand-in for WorldGenerator ("world_gen"): a real chain from a seed, and the royal capital (or the canal city) built on
## the stage, far off, when a test asks (build_capital), registered as a standing chain island.

var chain_islands := {}
var starter_island = null
var c


func _ready() -> void:
	add_to_group("world_gen")


func chain():
	return c


func chain_ready() -> bool:
	return true


func standing(_isl: Node) -> bool:
	return true


func build_capital(at: Vector3) -> Node3D:
	var n: Dictionary = c.node(c.capital_id())
	var isl = load("res://scripts/island/capital_island.gd").new()
	isl.name = "Isle%d" % int(n["id"])
	isl.position = at
	get_parent().add_child(isl)
	isl.build(n)
	chain_islands[int(n["id"])] = isl
	return isl


## The stage's own stand-in goes; this one takes its place with the chain of `chain_seed`.
static func take_over(stage: Node, chain_seed: int) -> Node:
	var old := stage.get_node("NoIslands")
	old.remove_from_group("world_gen")
	old.queue_free()
	var w: Node = load("res://tools/dev/t/capital/_world.gd").new()
	w.name = "CapitalWorld"
	w.c = load("res://scripts/world/chain.gd").make(chain_seed, Vector2(150, 150), Vector2(0, -1))
	stage.add_child(w)
	return w


## The canal city (1.21), built the same way (t/canal uses this world too).
func build_canal(at: Vector3) -> Node3D:
	var n: Dictionary = {}
	for x in c.nodes:
		if x.get("canal", false):
			n = x
	var isl = load("res://scripts/island/canal_island.gd").new()
	isl.name = "Isle%d" % int(n["id"])
	isl.position = at
	get_parent().add_child(isl)
	isl.build(n)
	chain_islands[int(n["id"])] = isl
	return isl


## (1.27) The Admiralty's stronghold (StrongholdIsland), off the chain, built here.
func build_stronghold(at: Vector3) -> Node3D:
	var n: Dictionary = c.node(c.stronghold_id())
	var isl = load("res://scripts/island/stronghold_island.gd").new()
	isl.name = "Isle%d" % int(n["id"])
	isl.position = at
	get_parent().add_child(isl)
	isl.build(n)
	chain_islands[int(n["id"])] = isl
	return isl
