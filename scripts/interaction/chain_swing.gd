class_name ChainSwing
extends SwingRope
## A chain hanging from a broken bridge's cable (its origin where it hangs from; it hangs
## along -Y). F at the bridge's broken end (`grab_from`) takes it, and so does jumping
## into it; SwingState's rope mode swings you across. Jump to let go, or ride it on
## until your feet find the far side. A captain swinging on another screen pulls it too.

## Where a captain stands to take it with F (global), set before it enters the tree.
var grab_from := Vector3.INF
## In the air within this of its lower part: caught.
const CATCH := 1.35
const GRAB_REACH := 1.4
var _cool := 0.0
var _pulled := false


func _ready() -> void:
	var mb := MeshBuilder.new()
	var iron := PSXMat.lit("metal", Color(0.46, 0.4, 0.36))
	var y := -0.04
	var k := 0
	while y > -length + 0.1:
		var b := Basis(Vector3.UP, PI * 0.5 * (k % 2))
		for sx in [-1.0, 1.0]:
			mb.add_box(iron, Transform3D(b, Vector3(sx * 0.045, y - 0.09, 0)), Vector3(0.025, 0.2, 0.03), 1.0, Color.WHITE, false, false)
		for sy in [0.0, -0.18]:
			mb.add_box(iron, Transform3D(b, Vector3(0, y + sy, 0)), Vector3(0.115, 0.025, 0.03), 1.0, Color.WHITE, false, false)
		y -= 0.16
		k += 1
	# a heavy ring at its end to hold on by
	mb.add_tube(iron, MeshBuilder.curve_points(Vector3(-0.12, -length, 0), Vector3(0, -length - 0.32, 0), Vector3(0.12, -length, 0)), 0.035, 0.035, 4, 1.0)
	mb.add_box(iron, Transform3D(Basis.IDENTITY, Vector3(0, -length + 0.02, 0)), Vector3(0.26, 0.05, 0.05), 1.0, Color.WHITE, false, false)
	_mesh = mb.to_instance("Chain")
	add_child(_mesh)
	interactable = Interactable.new()
	interactable.name = "Grab"
	interactable.collision_layer = 512
	interactable.collision_mask = 0
	interactable.prompt_text = "Grab the chain"
	interactable.reach_test = func(feet: Vector3) -> bool: return feet.distance_to(grab_from) < GRAB_REACH
	var cs := CollisionShape3D.new()
	var sp := SphereShape3D.new()
	sp.radius = GRAB_REACH
	cs.shape = sp
	interactable.add_child(cs)
	interactable.position = to_local(grab_from)
	add_child(interactable)
	interactable.interacted.connect(_on_grab)


func _physics_process(delta: float) -> void:
	_cool -= delta
	var p := get_tree().get_first_node_in_group("player") as Player
	if p == null:
		return
	var st := p.current_state_name()
	if st == "Swing":
		_cool = 0.8
		return
	if _cool > 0.0 or not st in ["Jump", "Fall"]:
		return
	var hand := p.global_position + Vector3.UP * 1.4
	var q := Geometry3D.get_closest_point_to_segment(hand, end_point(), global_position + Vector3.DOWN * maxf(length - 2.8, 0.0))
	if hand.distance_to(q) < CATCH:
		_on_grab(p)


## Another captain swinging on it (their machine swings them): the chain follows their hand.
func _process(_delta: float) -> void:
	var who: Node3D = null
	for c in Net.all_players():
		if not (c as Node).is_in_group("player") and str(c.call("current_state_name")) == "Swing" and (c as Node3D).global_position.distance_to(global_position) < length + 2.5:
			who = c
	if who:
		point_to((who.get("body_model") as Humanoid).hand_r.global_position)
		_pulled = true
	elif _pulled:
		_pulled = false
		hang()
