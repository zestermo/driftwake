class_name NightLight
extends OmniLight3D
## A lamp's real light: on from dusk to dawn (or always), no shadows, faded
## out with distance so only the ones near the camera cost anything.

const DUSK := 18.5
const DAWN := 6.0

var always := false
var _check := 0.0


static func make(color: Color, energy: float, light_range: float, all_day: bool = false) -> NightLight:
	var l := NightLight.new()
	l.name = "NightLight"
	l.light_color = color
	l.light_energy = energy
	l.omni_range = light_range
	l.always = all_day
	return l


func _ready() -> void:
	shadow_enabled = false
	distance_fade_enabled = true
	distance_fade_begin = 45.0
	distance_fade_length = 15.0
	_update()


func _process(delta: float) -> void:
	_check -= delta
	if _check <= 0.0:
		_check = 1.0
		_update()


func _update() -> void:
	var h: float = Weather.hour()
	visible = always or h >= DUSK or h < DAWN
