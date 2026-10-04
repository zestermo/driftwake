extends Area3D
class_name Hurtbox

signal hit_received(hit_data: HitData, attacker: Node)


func take_hit(data: HitData, attacker: Node) -> void:
	# co-op: another machine's captain, or (on a client) an enemy the host
	# runs - the hit is sent there instead
	var net := get_node_or_null("/root/Net")
	if net and net.active and net.route_hit(self, data, attacker):
		return
	hit_received.emit(data, attacker)
