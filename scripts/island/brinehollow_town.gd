extends Node3D
## Brinehollow's town after dark and by day (BrinehollowLife builds it as "TownLife"): every TICK s it sets the
## market street's murmur (by day), the Salted Gull's common room (busy at night, a few at lunch), Haldor's
## hammer (his working hours), the street's paper lanterns (glowing at night) and chimney smoke (made and kept
## going only within SMOKE_R of the camera). All local to each screen, from the shared clock (Weather.hour).

const TICK := 0.5
const SMOKE_R := 60.0
const SMOKE_OFF_R := 80.0
const FAR_R := 220.0
const HAMMER_FROM := 7.5
const HAMMER_TO := 18.0

## [AudioStreamPlayer3D, "day" | "night", base dB]
var beds: Array = []
var anvil: AudioStreamPlayer3D
## [chimney Marker3D, its smoke once made]
var chimneys: Array = []
var stair_post: Node3D
var lanterns_day: Node3D
var lanterns_night: Node3D
var _t := 0.0
var _strikes := 0
var _strike_t := 0.0


## Busy by day: nobody before 6:30, everyone by 8, thinning from 18:30, gone by 20:30.
static func day_gain(h: float) -> float:
	return clampf((h - 6.5) / 1.5, 0.0, 1.0) * clampf((20.5 - h) / 2.0, 0.0, 1.0)


## The Gull: a few at lunch, filling from 17:00, full 19:30 to half past midnight, empty by 1:30.
static func night_gain(h: float) -> float:
	if h < 1.5:
		return clampf(1.5 - h, 0.0, 1.0)
	if h < 11.0:
		return 0.0
	if h < 17.0:
		return 0.25
	return lerpf(0.25, 1.0, clampf((h - 17.0) / 2.5, 0.0, 1.0))


func _process(delta: float) -> void:
	_t -= delta
	if _strike_t > 0.0 or _strikes > 0:
		_strike_t -= delta
		if _strikes > 0 and _strike_t <= 0.0:
			anvil.play()
			_strikes -= 1
			_strike_t = randf_range(0.55, 0.75) if _strikes > 0 else randf_range(3.0, 9.0)
	if _t > 0.0:
		return
	_t = TICK
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var at := cam.global_position
	var h: float = Weather.hour()
	var near := at.distance_to(global_position) < FAR_R
	for b in beds:
		var p: AudioStreamPlayer3D = b[0]
		var g := day_gain(h) if b[1] == "day" else night_gain(h)
		var on := near and g > 0.02
		if on:
			p.volume_db = float(b[2]) + linear_to_db(g)
		if p.playing != on:
			if on:
				p.play(randf() * p.stream.get_length())
			else:
				p.stop()
	if anvil:
		var working := near and h >= HAMMER_FROM and h < HAMMER_TO and at.distance_to(anvil.global_position) < anvil.max_distance
		if working and _strikes == 0 and _strike_t <= 0.0:
			_strikes = randi_range(3, 7)
		elif not working:
			_strikes = 0
			_strike_t = 0.0
	var night := NightLight.is_night()
	if lanterns_night and lanterns_night.visible != night:
		lanterns_night.visible = night
		lanterns_day.visible = not night
	var lit := false
	for c in chimneys:
		var m: Node3D = c[0]
		var d := at.distance_to(m.global_position)
		if c[1] == null and d < SMOKE_R and not lit:
			c[1] = FX.chimney_smoke(m, Vector3.ZERO)
			lit = true
		elif c[1] != null:
			var s = c[1]
			var on := d < SMOKE_OFF_R
			if s.emitting != on:
				s.emitting = on
