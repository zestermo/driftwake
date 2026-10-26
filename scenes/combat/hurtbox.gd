extends Area3D
class_name Hurtbox

signal hit_received(hit_data: HitData, attacker: Node)


# Hitboxes and projectiles find hurtboxes; a hurtbox only needs to be found, and a monitoring area costs Jolt every tick.
func _init() -> void:
	monitoring = false


func _ready() -> void:
	collision_mask = 0


func take_hit(data: HitData, attacker: Node) -> void:
	attacker = Duel.blame(owner, attacker)
	var k := GearStats.versus(attacker, owner)
	if k != 1.0:
		data = data.duplicate()
		data.damage *= k
	# co-op: another machine's captain, or (on a client) an enemy the host
	# runs - the hit is sent there instead
	var net := get_node_or_null("/root/Net")
	if net and net.active and net.route_hit(self, data, attacker):
		return
	hit_received.emit(data, attacker)
