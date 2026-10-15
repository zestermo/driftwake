class_name WorldLatch
extends Node3D
## Sets world flag `flag` (GameManager.world_flags: saved with the world, the host's in
## co-op) for everyone the first time this machine's captain stands within `radius` of
## it (flat) and no more than `below` under it.

var flag := ""
var radius := 10.0
var below := 2.0


func _physics_process(_delta: float) -> void:
	if GameManager.world_flags.has(flag):
		return
	var p := get_tree().get_first_node_in_group("player") as Node3D
	if p == null:
		return
	var d := p.global_position - global_position
	if Vector2(d.x, d.z).length() < radius and d.y > -below:
		Net.world_flag(flag)
