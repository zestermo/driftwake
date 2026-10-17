extends Node3D
## A windmill's sails turning on their local Z by the shared sea clock (every screen sees them at the same
## angle), only while they're on screen.

@export var speed := 0.45


func _ready() -> void:
	var n := VisibleOnScreenNotifier3D.new()
	n.aabb = AABB(Vector3(-6.5, -6.5, -1.0), Vector3(13.0, 13.0, 2.0))
	add_child(n)
	n.screen_entered.connect(set_process.bind(true))
	n.screen_exited.connect(set_process.bind(false))
	set_process(false)


func _process(_delta: float) -> void:
	rotation.z = fposmod(Ocean.clock() * speed, TAU)
