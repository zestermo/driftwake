class_name ShipRigging
extends Node3D
## The ratlines up one side of the mast to the crow's nest (HullBuilder lays
## them out; this node sits at the ship model's origin, so its local space is
## ship-local). F at the foot climbs up, F at the top in the nest climbs down
## (ClimbState's "rig" path).

## +1 starboard, -1 port.
@export var side: float = 1.0

var bottom: Vector3
var top: Vector3
var up_zone: Interactable
var down_zone: Interactable


func _ready() -> void:
	bottom = Vector3(side * HullBuilder.RIG_BOTTOM.x, HullBuilder.RIG_BOTTOM.y, HullBuilder.RIG_BOTTOM.z)
	top = Vector3(side * HullBuilder.RIG_TOP.x, HullBuilder.RIG_TOP.y, HullBuilder.RIG_TOP.z)
	up_zone = _zone("ClimbUp", "Press F to climb the rigging", deck_spot() + Vector3(0, 0.6, 0), 1.0)
	down_zone = _zone("ClimbDown", "Press F to climb down", nest_spot() + Vector3(side * 0.25, 0.6, 0), 0.7)
	up_zone.interacted.connect(func(p: Player): _climb(p, true))
	down_zone.interacted.connect(func(p: Player): _climb(p, false))


func _zone(n: String, prompt: String, at: Vector3, r: float) -> Interactable:
	var z := Interactable.new()
	z.name = n
	z.collision_layer = 512
	z.collision_mask = 0
	z.prompt_text = prompt
	var cs := CollisionShape3D.new()
	var sp := SphereShape3D.new()
	sp.radius = r
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
	return Vector3(side * 0.55, HullBuilder.NEST_Y - 0.03, HullBuilder.MAST_Z + 0.45)


## The climbing line, held a little inboard of the ropes (ship-local).
func hold(k: float) -> Vector3:
	return bottom.lerp(top, k) + Vector3(-side * 0.32, 0.0, 0.0)


func _climb(p: Player, up: bool) -> void:
	if p.is_free():
		p.start_climb({"kind": "rig", "rig": self, "up": up})
