extends RadialWheel
## The emote wheel: hold T, move the mouse toward an emote, let go of T (or click) to do it
## (RadialWheel: the ring, the planks, picking). Player.emote does the rest.

const ORDER := EmotePoses.ORDER


func _init() -> void:
	action = "emote"
	title = "Emotes"


## The emotes on the wheel now: ORDER, plus "play" (start or stop the worn instrument: Jam) when one is worn.
func _list() -> Array:
	var want: Array = ORDER.duplicate()
	if player.jam.worn() != "":
		want.append("play")
	return want


func _label(id) -> String:
	if id == "play":
		return "Stop" if player.jam.playing else "Play"
	return EmotePoses.LABELS[id]


func _do(id) -> void:
	if id == "play":
		player.jam.toggle()
	else:
		player.emote(id)
