extends Interactable
class_name Seat
## A spot a captain can sit on (F): benches, stools, log seats, crates, chairs.
## Its origin is the middle of the seat's top; `height` is how far that is above
## the floor the feet rest on. `face` (in the parent's frame) is the way the
## sitter faces; Vector3.ZERO = either way across the parent's local Z (a bench
## or a log), the side you come from. One captain per seat (Net.request_seat).

const KEY := "seat:"

var height: float = 0.47
var face := Vector3.ZERO


## A seat on `parent` at `at` (parent-local, the top of the seat).
static func add(parent: Node3D, at: Vector3, h: float, facing := Vector3.ZERO) -> Seat:
	var s := Seat.new()
	s.name = "Seat%d" % parent.get_children().filter(func(c): return c is Seat).size()
	s.height = h
	s.face = facing
	s.position = at
	s.collision_layer = 512
	s.collision_mask = 0
	s.monitoring = false
	s.prompt_text = "Sit"
	s.reach = 0.95
	var cs := CollisionShape3D.new()
	var sp := SphereShape3D.new()
	sp.radius = 0.7
	cs.shape = sp
	s.add_child(cs)
	parent.add_child(s)
	return s


## Both ends of a bench / log (along the parent's local X, `spread` either side of the middle).
static func pair(parent: Node3D, top: float, spread: float, facing := Vector3.ZERO) -> void:
	for x in [-spread, spread]:
		add(parent, Vector3(x, top, 0.0), top, facing)


## Turn every seat on `parent` one way (a bench at a table faces it).
static func face_all(parent: Node3D, facing: Vector3) -> void:
	for c in parent.get_children():
		if c is Seat:
			(c as Seat).face = facing


func _ready() -> void:
	add_to_group("seats")
	interacted.connect(_on_interact)


# (Net by path, untyped captain: tools that build props compile this before the autoloads exist)
func _on_interact(player) -> void:
	if not player.is_free() or not player.is_on_floor():
		return
	var net := get_node("/root/Net")
	if net.active and not net.request_seat(self):
		return  # the host answers (Player.take_seat)
	player.sit(self)


func in_reach(feet: Vector3) -> bool:
	var net := get_node("/root/Net")
	var h: int = net.seat_holder(self)
	return (h == 0 or h == net.my_id()) and super(feet) and not _npc_sitting()


var _npc_ms: int = -100000
var _npc_on: bool = false


## A seated villager (a tavern regular, Pell on his bench) already has this spot (checked once a second).
func _npc_sitting() -> bool:
	var now := Time.get_ticks_msec()
	if now - _npc_ms < 1000:
		return _npc_on
	_npc_ms = now
	_npc_on = false
	for n in get_tree().get_nodes_in_group("npcs"):
		var hm = n.get("humanoid")
		if hm and hm.seated and Vector2(hm.global_position.x - global_position.x, hm.global_position.z - global_position.z).length() < 0.55:
			_npc_on = true
			break
	return _npc_on


## Where the sitter faces (world, flat) when they sit down from `from`.
func facing_for(from: Vector3) -> Vector3:
	var b := (get_parent() as Node3D).global_basis.orthonormalized()
	var f := b * face if face != Vector3.ZERO else b.z * (1.0 if (from - global_position).dot(b.z) >= 0.0 else -1.0)
	f.y = 0.0
	return f.normalized()


## Where the feet go: under the seat's top.
func floor_point() -> Vector3:
	return global_position - Vector3.UP * height


## The seat on the wire: its place in the world (or on the crew's ship) rounded,
## the same on every machine without relying on node names.
func seat_key() -> String:
	var t := Transform3D.IDENTITY
	var n: Node = self
	var tag := "w"
	while n is Node3D:
		if n.is_in_group("ship"):
			tag = "s"
			break
		t = (n as Node3D).transform * t
		n = n.get_parent()
	var p := t.origin
	return "%s%s:%.1f,%.1f,%.1f" % [KEY, tag, p.x, p.y, p.z]


static func find(tree: SceneTree, key: String) -> Seat:
	for s in tree.get_nodes_in_group("seats"):
		if (s as Seat).seat_key() == key:
			return s
	return null
