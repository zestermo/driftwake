class_name ShipRigging
extends Node3D
## The ratlines up one side of the mast to the crow's nest (HullBuilder lays
## them out; this node sits at the ship model's origin, so its local space is
## ship-local). F at the foot grabs on, F in the nest by the gap in its rail
## grabs on at the top; ClimbState's "rig" climb does the rest.

## +1 starboard, -1 port.
@export var side: float = 1.0

var bottom: Vector3
var top: Vector3
var up_zone: Interactable
var down_zone: Interactable


func _ready() -> void:
	bottom = Vector3(side * HullBuilder.RIG_BOTTOM.x, HullBuilder.RIG_BOTTOM.y, HullBuilder.RIG_BOTTOM.z)
	top = Vector3(side * HullBuilder.RIG_TOP.x, HullBuilder.RIG_TOP.y, HullBuilder.RIG_TOP.z)
	up_zone = _zone("ClimbUp", "Climb the rigging", deck_spot() + Vector3(0, 0.9, 0), 0.8)
	down_zone = _zone("ClimbDown", "Climb down the rigging", nest_spot() + Vector3(side * 0.3, 0.9, 0), 0.7)
	up_zone.interacted.connect(func(p: Player): _climb(p, true))
	down_zone.interacted.connect(func(p: Player): _climb(p, false))


func _zone(n: String, prompt: String, at: Vector3, reach: float) -> Interactable:
	var z := Interactable.new()
	z.name = n
	z.collision_layer = 512
	z.collision_mask = 0
	z.prompt_text = prompt
	z.reach = reach
	var cs := CollisionShape3D.new()
	var sp := SphereShape3D.new()
	sp.radius = reach
	cs.shape = sp
	z.add_child(cs)
	z.position = at
	add_child(z)
	return z


## Where you stand on deck at the foot of the ratlines (ship-local).
func deck_spot() -> Vector3:
	return Vector3(side * 3.05, HullBuilder.DECK_Y, HullBuilder.MAST_Z + 0.75)


## Where you step off into the crow's nest (ship-local).
func nest_spot() -> Vector3:
	return Vector3(side * 0.95, HullBuilder.NEST_Y - 0.03, HullBuilder.MAST_Z + 0.35)


## The gap in the nest's rail the ratlines come up through (ship-local).
func nest_gap() -> Vector3:
	return Vector3(side * (HullBuilder.NEST_R - 0.1), HullBuilder.NEST_Y + 0.3, HullBuilder.MAST_Z)


## Your feet on the ratlines at k (0 the rail, 1 the nest): on the outboard
## side of the shrouds, facing in (ship-local).
func hold(k: float) -> Vector3:
	return bottom.lerp(top, k) + Vector3(side * 0.3, 0.0, 0.0)


func _climb(p: Player, up: bool) -> void:
	if p.is_free():
		p.start_climb({"kind": "rig", "rig": self, "up": up})
