class_name InlandPool
extends Node3D
## Still water away from the sea (a waterfall's pool, a spring, a sinkhole):
## while it's in the tree, Ocean.surface_at counts it, so you swim in it like
## the sea. Its origin is the middle of the surface; `radius` reaches the banks
## (past them the ground stands above the water, so nothing floats there).

var radius := 6.0


static func make(r: float) -> InlandPool:
	var p := InlandPool.new()
	p.name = "Pool"
	p.radius = r
	return p


func _enter_tree() -> void:
	var g := global_position
	Ocean.pools[get_instance_id()] = Vector4(g.x, g.z, radius, g.y)


func _exit_tree() -> void:
	Ocean.pools.erase(get_instance_id())
