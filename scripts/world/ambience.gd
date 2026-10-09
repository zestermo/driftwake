extends Node
class_name Ambience
## The sound of where you are, mixed every frame for the local captain (each
## machine hears its own): surf on a shore, the open sea's swell away from
## land, and aboard the ship the water rushing past her hull (louder and
## higher the faster she goes), waves slapping her at rest and her timbers
## creaking; the wind (with the weather, stronger at sea, under way and up
## the mast, quieter inland) and the rigging whistling in it.
##
## Where the shore is: twice a second the sea depth is probed at eight points
## 30 m round you and eight at 90 m. Land and water mixed = a shore; all water
## = open sea; all land = inland (quiet).

const LOOPS := {
	"shore": "shore_surf_loop", "sea": "sea_swell_loop", "wash": "hull_wash_loop",
	"slap": "hull_slap_loop", "creak": "ship_creak_loop", "wind": "wind_loop", "rig": "rigging_wind_loop",
}
## Each loop's level at full strength.
const TOP_DB := {"shore": -7.0, "sea": -11.0, "wash": -9.0, "slap": -12.0, "creak": -13.0, "wind": -10.0, "rig": -13.0}
const PROBE_EVERY := 0.5

var _players := {}
var _land_near := 0.0
var _land_far := 0.0
var _probe_t := 0.0


func _ready() -> void:
	for k in LOOPS:
		_players[k] = _loop_player("res://assets/audio/%s.wav" % LOOPS[k])


func _loop_player(path: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	var s := (load(path) as AudioStreamWAV).duplicate() as AudioStreamWAV
	s.loop_mode = AudioStreamWAV.LOOP_FORWARD
	s.loop_begin = 0
	s.loop_end = int(s.data.size() / 2)
	p.stream = s
	p.bus = "Ambience" if AudioServer.get_bus_index("Ambience") >= 0 else "Master"
	p.volume_db = -60.0
	add_child(p)
	return p


func _process(delta: float) -> void:
	var me := get_tree().get_first_node_in_group("player") as Node3D
	var want := {"shore": 0.0, "sea": 0.0, "wash": 0.0, "slap": 0.0, "creak": 0.0, "wind": 0.0, "rig": 0.0}
	if me != null and me.is_inside_tree():
		_probe_t -= delta
		if _probe_t <= 0.0:
			_probe_t = PROBE_EVERY
			_probe(me.global_position)
		_mix(me, want, delta)
	for k in want:
		_level(k, want[k], delta)


## How much land is round you, near and far (0 all sea .. 1 all land).
func _probe(at: Vector3) -> void:
	var ship := get_tree().get_first_node_in_group("ship") as CollisionObject3D
	var skip: Array = [ship.get_rid()] if ship else []
	var near := 0
	var far := 0
	for i in range(8):
		var a := TAU * i / 8.0
		var d := Vector3(cos(a), 0.0, sin(a))
		# (probed from high up: from sea level the ray starts inside a hill)
		if float(Ocean.depth_at(Vector3(at.x, 80.0, at.z) + d * 30.0, skip, true)) < 0.25:
			near += 1
		if float(Ocean.depth_at(Vector3(at.x, 80.0, at.z) + d * 90.0, skip, true)) < 0.25:
			far += 1
	_land_near = near / 8.0
	_land_far = far / 8.0


func _mix(me: Node3D, want: Dictionary, _delta: float) -> void:
	var wx := get_node_or_null("/root/Weather")
	var wind: float = float(wx.get("wind")) if wx else 0.3
	var storm: float = float(wx.get("storm")) if wx else 0.0
	var cloud: float = float(wx.get("in_cloud")) if wx else 0.0
	var ship := get_tree().get_first_node_in_group("ship") as Node3D
	var aboard: bool = ship != null and ship.call("aboard", me.global_position)
	var spd: float = absf(float(ship.get("speed"))) if aboard else 0.0
	var mixed_near := 4.0 * _land_near * (1.0 - _land_near)
	var mixed_far := 4.0 * _land_far * (1.0 - _land_far)
	var inland := _land_near * _land_far
	var at_sea := (1.0 - _land_near) * (1.0 - _land_far)
	# surf where land meets water (fainter from a little way off)
	want["shore"] = clampf(maxf(mixed_near * 1.3, mixed_far * 0.6), 0.0, 1.0)
	want["sea"] = clampf(at_sea + (0.5 if aboard else 0.0) + (0.4 if me.call("is_swimming") else 0.0), 0.0, 1.0) * (0.6 + 0.4 * minf(storm + wind, 1.0))
	if aboard:
		want["wash"] = clampf(spd / 9.0, 0.0, 1.0)
		want["slap"] = clampf(1.0 - spd / 4.0, 0.0, 1.0) * 0.8
		want["creak"] = clampf(0.45 + spd / 20.0 + storm * 0.4, 0.0, 1.0)
	# the wind: always a breath at sea, more with the weather, under way and up high
	var high := clampf((me.global_position.y - 2.0) / 14.0, 0.0, 1.0)
	want["wind"] = clampf((0.12 + wind * 0.55 + storm * 0.45 + high * 0.35 + spd / 30.0 + cloud * 0.5) * (1.0 - 0.55 * inland), 0.0, 1.0)
	if aboard:
		want["rig"] = clampf((wind - 0.25) * 1.4 + storm * 0.6 + spd / 22.0 + high * 0.5, 0.0, 1.0)
	(_players["wash"] as AudioStreamPlayer).pitch_scale = lerpf(0.85, 1.25, clampf(spd / 13.0, 0.0, 1.0))
	(_players["wind"] as AudioStreamPlayer).pitch_scale = lerpf(0.9, 1.15, clampf(wind + storm * 0.5, 0.0, 1.0))


func _level(k: String, v: float, delta: float) -> void:
	var p := _players[k] as AudioStreamPlayer
	var to := -60.0 if v < 0.02 else linear_to_db(v) + float(TOP_DB[k])
	p.volume_db = move_toward(p.volume_db, to, 24.0 * delta)
	if p.volume_db > -55.0 and not p.playing:
		p.play()
	elif p.volume_db <= -59.0 and p.playing:
		p.stop()
