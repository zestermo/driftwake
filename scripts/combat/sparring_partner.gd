class_name SparringPartner
extends Node
## The training yard's sparring partner (1.24 crew techniques; single player only): a captain-style AI that steps in at
## your side when you use a crew technique that throws a crewmate within YARD_NEAR of a training dummy with nobody
## else around, plays the crewmate's side, and leaves once you're YARD_LEAVE from it. It's on your side: nothing hits
## it and its landings hit the foes. This node is its brain: it stands there, and once a second checks you're near.

const YARD_NEAR := 14.0
const YARD_LEAVE := 30.0
const CHECK_EVERY := 1.0
const NODE_NAME := "SparringPartner"
## How far to your right it steps in (m).
const SIDE := 1.8

var captain: Node3D
var _t := 0.0


## The sparring partner at `p`'s side (stepping in, or called over), or null outside a yard or in co-op.
static func at_side(p) -> Node3D:
	var net: Node = p.get_node("/root/Net")
	if net.coop() or not in_yard(p):
		return null
	var root: Node = p.get_tree().current_scene
	var right: Vector3 = p.player_model.global_basis.x
	right.y = 0.0
	var at: Vector3 = p.global_position + right.normalized() * SIDE + Vector3(0, 0.05, 0)
	var yaw: float = p.player_model.rotation.y
	var mate = root.get_node_or_null(NODE_NAME)
	if mate == null:
		var brain := SparringPartner.new()
		brain.captain = p
		var rng := RandomNumberGenerator.new()
		rng.seed = 1124
		var look: Dictionary = CharacterLook.random_look(rng)
		look["name"] = "Sparring Partner"
		mate = Player.spawn_ai(root, look, at, yaw, brain, NODE_NAME)
		_befriend(mate)
	else:
		mate.state_machine.force_state("Idle", {})
		mate.global_position = at
		mate.velocity = Vector3.ZERO
		mate.player_model.rotation.y = yaw
		mate.reset_physics_interpolation()
	net.fx("puff_ring", [at, "dust_low", 5, 0.3, 0.8, 0.6, Color(0.85, 0.8, 0.7, 0.8), 3.0])
	return mate


## Near a training dummy.
static func in_yard(p: Node3D) -> bool:
	for d in p.get_tree().get_nodes_in_group("training_dummies"):
		if (d as Node3D).global_position.distance_to(p.global_position) <= YARD_NEAR:
			return true
	return false


## On the captain's side: out of the enemies' groups and the co-op sync, its blows on the foes, nothing landing on it.
static func _befriend(mate) -> void:
	mate.sparring = true
	for g in ["enemies", "rivals", "net_sync"]:
		mate.remove_from_group(g)
	mate.hurtbox.collision_layer = 0
	mate.hurtbox.set_deferred("monitorable", false)
	mate.sword_hitbox.collision_mask = mate.foe_mask()


func _process(delta: float) -> void:
	_t += delta
	if _t < CHECK_EVERY:
		return
	_t = 0.0
	var me := get_parent() as Node3D
	if captain == null or not is_instance_valid(captain) or captain.global_position.distance_to(me.global_position) > YARD_LEAVE:
		me.queue_free()
