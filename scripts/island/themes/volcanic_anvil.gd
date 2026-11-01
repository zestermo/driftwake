extends Node3D
## A smith's anvil ringing in the forge town (VolcanicTown): every `beat` s of game time, while the local captain is
## within EAR m, the hammer's ring (one of four takes) and a spit of embers. Ambience, each screen its own.

const EAR := 45.0
var beat := 1.3
var _t := 0.0
var _snd: AudioStreamPlayer3D


func _ready() -> void:
	_snd = AudioStreamPlayer3D.new()
	var takes := AudioStreamRandomizer.new()
	takes.playback_mode = AudioStreamRandomizer.PLAYBACK_RANDOM_NO_REPEATS
	takes.random_pitch = 1.05
	for k in range(4):
		takes.add_stream(-1, load("res://assets/audio/anvil_%d.wav" % (k + 1)))
	_snd.stream = takes
	_snd.unit_size = 5.0
	_snd.max_distance = EAR
	_snd.volume_db = -4.0
	_snd.bus = "SFX"
	add_child(_snd)


func _physics_process(delta: float) -> void:
	_t += delta
	if _t < beat:
		return
	_t = 0.0
	var p := get_tree().get_first_node_in_group("player") as Node3D
	if p == null or p.global_position.distance_to(global_position) > EAR:
		return
	_snd.play()
	FX.embers(global_position, Vector3.UP, 5, Color(1.0, 0.55, 0.15), 3.0)
