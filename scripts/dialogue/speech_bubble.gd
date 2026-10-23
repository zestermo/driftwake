class_name SpeechBubble
extends Label3D
## A line said out loud in a fight (a rival's taunt, a crewmate's cheer): over the speaker's head, typed out with
## voice blips at their pitch, then gone. One per speaker (a new line replaces the last). FX.speech plays it, so
## through Net.fx every screen hears it.

const CHARS_PER_S := 40.0
const HOLD := 1.4
const HEAD_Y := 2.3

var line := ""
var pitch := 1.0
var _shown := 0.0
var _left := 0.0
var _blip: AudioStreamPlayer3D


static func say(who: Node3D, text: String, pitch_: float = 1.0) -> SpeechBubble:
	if who == null or not is_instance_valid(who) or not who.is_inside_tree() or text == "":
		return null
	var old := who.get_node_or_null("SpeechBubble") as SpeechBubble
	if old:
		old.name = "SpeechBubbleOld"
		old.queue_free()
	var b := SpeechBubble.new()
	b.name = "SpeechBubble"
	b.line = text
	b.pitch = pitch_
	who.add_child(b)
	return b


func _ready() -> void:
	font = load("res://assets/fonts/PixelifySans-Regular.woff2")
	font_size = 30
	pixel_size = 0.006
	outline_size = 12
	outline_modulate = Color(0.05, 0.04, 0.03)
	modulate = Color(1, 0.97, 0.88)
	billboard = BaseMaterial3D.BILLBOARD_ENABLED
	texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	no_depth_test = true
	width = 380.0
	autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	visibility_range_end = 40.0
	position = Vector3(0, HEAD_Y, 0)
	text = ""
	_left = line.length() / CHARS_PER_S + HOLD
	_blip = AudioStreamPlayer3D.new()
	_blip.stream = load("res://assets/audio/blip.wav")
	_blip.volume_db = -8.0
	_blip.max_distance = 30.0
	add_child(_blip)


func _process(delta: float) -> void:
	var prev := int(_shown)
	_shown = minf(_shown + delta * CHARS_PER_S, line.length())
	if int(_shown) > prev:
		text = line.substr(0, int(_shown))
		if prev % 3 == 0 and line[int(_shown) - 1] != " ":
			_blip.pitch_scale = pitch * randf_range(0.92, 1.08)
			_blip.play()
	_left -= delta
	if _left < 0.3:
		modulate.a = maxf(_left / 0.3, 0.0)
	if _left <= 0.0:
		queue_free()
