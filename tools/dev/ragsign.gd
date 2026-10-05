extends SceneTree
var frames := 0
var rag: Ragdoll
var shin: Node3D
var leg: Node3D
var phase := 0
var mn := 9.0
var mx := -9.0
func _setup() -> void:
	var root := Node3D.new()
	get_root().add_child(root)
	current_scene = root
	leg = Node3D.new(); root.add_child(leg); leg.position = Vector3(0, 3, 0)
	leg.scale = Vector3(1.2,1.2,1.2)
	shin = Node3D.new(); leg.add_child(shin); shin.position = Vector3(0, -0.4, 0); shin.rotation.x = -0.5
	rag = Ragdoll.create(self)
	var a: RigidBody3D = rag.add_part("leg", leg, {"capsule": [Vector3.ZERO, Vector3(0,-0.4,0), 0.08]}, 5.0)
	a.freeze = true
	rag.add_part("shin", shin, {"capsule": [Vector3.ZERO, Vector3(0,-0.4,0), 0.06]}, 3.0, "leg", {"x": [-2.5, 0.0]})
func _process(_d: float) -> bool:
	frames += 1
	if frames == 1:
		_setup()
		return false
	var b: RigidBody3D = rag.body("shin")
	mn = minf(mn, shin.rotation.x); mx = maxf(mx, shin.rotation.x)
	if frames == 5:
		b.angular_velocity = leg.global_basis.orthonormalized().x * 25.0
	if frames == 60:
		print("after +X spin: shin.x=", shin.rotation.x)
		b.angular_velocity = leg.global_basis.orthonormalized().x * -25.0
	if frames == 120:
		print("min/max ", mn, " ", mx, " after -X spin: shin.x=", shin.rotation.x, " scale=", shin.global_basis.get_scale())
		return true
	return false
