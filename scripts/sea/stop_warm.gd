extends Node3D
## Holds a stop back until its crew's bodies are built on a worker thread (Humanoid.prebuild), then makes it
## (`make`) and goes: no hitch when a sea leg's big ship appears mid-voyage.

var looks: Array = []
var make: Callable


func _ready() -> void:
	Humanoid.prebuild(looks)


func _process(_delta: float) -> void:
	if Humanoid.prebuilt_for(looks):
		make.call()
		queue_free()
