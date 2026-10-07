class_name SwingRope
extends Node3D
## A rope hanging from the yard (its origin is where it's made fast; it hangs
## along -Y). Grab it (F at its end) to swing across the deck, out over the
## side or onto a ship alongside; jump to let go. SwingState's rope mode does
## the swinging and points the rope at the swinger's hand.

@export var length: float = 11.5

var interactable: Interactable
var _mesh: MeshInstance3D


func _ready() -> void:
	var mb := MeshBuilder.new()
	var rope := PSXMat.lit("rope")
	mb.add_box(rope, Transform3D(Basis(), Vector3(0, -length * 0.5, 0)), Vector3(0.06, length, 0.06), 2.0, Color.WHITE, false, false)
	# a knot at the end to hold on by
	mb.add_box(rope, Transform3D(Basis(), Vector3(0, -length + 0.12, 0)), Vector3(0.14, 0.2, 0.14), 1.0)
	_mesh = mb.to_instance("Rope")
	add_child(_mesh)
	interactable = Interactable.new()
	interactable.name = "Grab"
	interactable.collision_layer = 512
	interactable.collision_mask = 0
	interactable.prompt_text = "Press F to grab the rope"
	var cs := CollisionShape3D.new()
	var sp := SphereShape3D.new()
	sp.radius = 1.1
	cs.shape = sp
	interactable.add_child(cs)
	# (down at the deck, where a captain standing under the rope's end is)
	interactable.position = Vector3(0, -length - 1.95, 0)
	add_child(interactable)
	interactable.interacted.connect(_on_grab)


func _on_grab(player: Player) -> void:
	if player.is_free():
		player.state_machine.force_state("Swing", {"rope": self})


## The rope's end in the world, hanging straight down from where it's made fast.
func end_point() -> Vector3:
	return global_position + Vector3.DOWN * length


## Swinging: the rope runs from its fastening to `hand`.
func point_to(hand: Vector3) -> void:
	var d := global_position - hand
	if d.length() < 0.1:
		return
	var up := d.normalized()
	var side := up.cross(Vector3.FORWARD if absf(up.z) < 0.9 else Vector3.RIGHT).normalized()
	# (the mesh hangs along its -Y: stretched or shortened to reach the hand)
	var b := Basis(side, up * minf(d.length() / length, 1.0), side.cross(up))
	_mesh.global_transform = Transform3D(b, global_position)
	interactable.enabled = false


## Let go: hanging straight down again.
func hang() -> void:
	_mesh.transform = Transform3D.IDENTITY
	interactable.enabled = true
