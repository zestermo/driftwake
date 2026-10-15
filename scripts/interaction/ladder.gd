class_name Ladder
extends Node3D
## Rope ladder hanging down a ship's side, a dock or a tower: swim up to it (or
## stand at its foot) and press F or Space to grab on, or F at its head on deck
## to climb down (ClimbState).
## Local frame: the origin is where you step off at the top (deck / dock
## surface, at the edge), the ladder hangs down along -Y, +Z faces the water
## (where the climber is) and -Z points onto the deck.

## How far the rungs go down below the origin.
@export var length: float = 2.4
## A rail / bulwark to climb over at the top (its height above the origin).
@export var rail: float = 0.0
## How far onto the deck the climb ends.
@export var deck_depth: float = 0.8
## Pulled up (rolled at its head, out of reach) until this world flag is set
## (GameManager.world_flags), then let down. Set before it enters the tree.
var lock_flag := ""

var interactable: Interactable
var _mesh: MeshInstance3D
var _bundle: MeshInstance3D
var _stowed := false
var _age := 0.0


func _ready() -> void:
	add_to_group("ladders")
	_build_mesh()
	interactable = Interactable.new()
	interactable.name = "Climb"
	interactable.collision_layer = 512
	interactable.collision_mask = 0
	interactable.usable_in_water = true
	interactable.prompt_text = "Climb the ladder"
	interactable.reach_test = func(feet: Vector3) -> bool: return in_reach(feet) or at_head(feet)
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.6, length + 1.0, 1.6)
	cs.shape = box
	interactable.add_child(cs)
	interactable.position = Vector3(0, rail - (length + rail) * 0.5, 0.6)
	add_child(interactable)
	interactable.interacted.connect(_on_use)
	set_physics_process(lock_flag != "" and not GameManager.world_flags.has(lock_flag))
	if is_physics_processing():
		_stowed = true
		_mesh.scale.y = 0.04
		_mesh.visible = false
		interactable.enabled = false
		var mb := MeshBuilder.new()
		var rope := PSXMat.lit("rope")
		mb.add_cylinder(rope, Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(0.36, 0.12, 0.08)), 0.13, 0.13, 0.72, 6, 1.0)
		for x in [-0.24, 0.24]:
			mb.add_box(rope, Transform3D(Basis.IDENTITY, Vector3(x, 0.08, -0.04)), Vector3(0.05, 0.05, 0.3), 1.0, Color.WHITE, false, false)
		_bundle = mb.to_instance("Bundle")
		add_child(_bundle)


func _physics_process(delta: float) -> void:
	_age += delta
	if _stowed and GameManager.world_flags.has(lock_flag):
		_let_down(_age > 2.0)


## Pulled up out of reach (lock_flag not set yet)?
func stowed() -> bool:
	return _stowed


## Unrolled down from its head (a rattle of rungs), or at once (a loaded world).
func _let_down(roll: bool) -> void:
	_stowed = false
	set_physics_process(false)
	interactable.enabled = true
	_mesh.visible = true
	if _bundle:
		_bundle.queue_free()
		_bundle = null
	if not roll:
		_mesh.scale.y = 1.0
		return
	var tw := create_tween()
	tw.tween_property(_mesh, "scale:y", 1.0, 1.1).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	FX.sfx("rope", global_position, -2.0, 0.1, 0.8)
	FX.sfx("whoosh", global_position + Vector3.DOWN * length * 0.5, -6.0, 0.1, 0.7)


func _build_mesh() -> void:
	var mb := MeshBuilder.new()
	var rope := PSXMat.lit("rope")
	var wood := PSXMat.lit("planks_dark")
	var top := rail
	var bottom := -length
	for x in [-0.24, 0.24]:
		mb.add_box(rope, Transform3D(Basis.IDENTITY, Vector3(x, (top + bottom) * 0.5, 0.08)), Vector3(0.05, top - bottom, 0.05), 1.0, Color.WHITE, false, false)
	var y := top - 0.15
	while y > bottom + 0.05:
		mb.add_box(wood, Transform3D(Basis.IDENTITY, Vector3(0, y, 0.08)), Vector3(0.56, 0.05, 0.07), 1.0, Color.WHITE, false, false)
		y -= 0.34
	# hooks over the top edge
	if rail > 0.0:
		for x in [-0.24, 0.24]:
			mb.add_box(rope, Transform3D(Basis.IDENTITY, Vector3(x, top + 0.02, -0.04)), Vector3(0.05, 0.05, 0.24), 1.0, Color.WHITE, false, false)
	_mesh = mb.to_instance("LadderMesh")
	add_child(_mesh)


## Close enough (in front of the rungs) to grab on?
func in_reach(p: Vector3) -> bool:
	var l := to_local(p)
	return not _stowed and absf(l.x) < 0.9 and l.z > -0.2 and l.z < 1.5 and l.y < rail - 0.6 and l.y > -length - 2.2


## On deck (or the dock) right at its head, inside the rail?
func at_head(p: Vector3) -> bool:
	var l := to_local(p)
	return not _stowed and absf(l.x) < 0.7 and l.z < 0.05 and l.z > -1.0 and absf(l.y) < 0.5


func _on_use(player: Player) -> void:
	if player.is_swimming() or (player.is_free() and player.is_on_floor() and (at_head(player.global_position) or in_reach(player.global_position))):
		player.start_climb({"kind": "ladder", "ladder": self})
