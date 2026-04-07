extends Area3D
class_name Hurtbox

signal hit_received(hit_data: HitData, attacker: Node)


func take_hit(data: HitData, attacker: Node) -> void:
	hit_received.emit(data, attacker)
