extends Node
## Background music (autoload "Music"). Picks a track from what's going on
## around your captain and crossfades to it:
##   title   - the title screen
##   island  - on foot, nothing hostile around
##   sea     - at the helm / a cannon, or out on the open sea
##   combat  - enemies fighting you (or a pirate ship hunting you) nearby
##   boss    - a boss fight close by
## plus a short victory fanfare (victory()) that ducks the music for a moment.
## Volume: the "Music" bus (Options > Audio > Music).

const TRACKS := {
	"title": "res://assets/audio/music_title.ogg",
	"island": "res://assets/audio/music_island.ogg",
	"sea": "res://assets/audio/music_sea.ogg",
	"combat": "res://assets/audio/music_combat.ogg",
	"boss": "res://assets/audio/music_boss.ogg",
}
const VICTORY := "res://assets/audio/music_victory.ogg"
const BASE_DB := -5.0
const FADE := 1.8
const FAST_FADE := 0.7
## Fighting keeps the combat track on for a while after the last enemy.
const COMBAT_HOLD := 6.0
## Back to a calm track this soon after leaving it: it carries on where it was
## (a fight doesn't restart the island theme); the fight tracks always start over.
const RESUME_WITHIN := 120.0

var current: String = ""
## Force a track (tests, cutscenes); "" = automatic.
var override: String = ""

var _a: AudioStreamPlayer
var _b: AudioStreamPlayer
var _active: AudioStreamPlayer
var _sting: AudioStreamPlayer
var _streams: Dictionary = {}
var _check_t: float = 0.0
var _combat_hold: float = 0.0
var _duck: float = 0.0
var _fade_rate: float = 1.0 / FADE
var _left: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_a = _player("MusicA")
	_b = _player("MusicB")
	_active = _a
	_sting = _player("Sting")
	_sting.volume_db = BASE_DB + 1.0


func _player(n: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.name = n
	p.bus = "Music" if AudioServer.get_bus_index("Music") >= 0 else "Master"
	p.volume_db = -80.0
	add_child(p)
	return p


func _stream(track: String) -> AudioStream:
	if _streams.has(track):
		return _streams[track]
	var path: String = TRACKS.get(track, "")
	var s: AudioStream = null
	if path != "" and ResourceLoader.exists(path):
		s = load(path)
		if s is AudioStreamOggVorbis:
			(s as AudioStreamOggVorbis).loop = true
		elif s is AudioStreamWAV:
			(s as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
	_streams[track] = s
	return s


## Switch to a track (crossfade). Same track: nothing happens.
func play(track: String, fast: bool = false) -> void:
	if track == current:
		return
	var now := Time.get_ticks_msec() * 0.001
	if current != "" and _active.playing:
		_left[current] = [_active.get_playback_position(), now]
	current = track
	_fade_rate = 1.0 / (FAST_FADE if fast else FADE)
	var s := _stream(track)
	var next := _b if _active == _a else _a
	next.stop()
	if s:
		next.stream = s
		next.volume_db = -60.0
		var left: Array = _left.get(track, [0.0, -INF])
		next.play(float(left[0]) if track not in ["combat", "boss"] and now - float(left[1]) < RESUME_WITHIN else 0.0)
	_active = next


## A short fanfare (a boss beaten); the music dips under it.
func victory() -> void:
	if not ResourceLoader.exists(VICTORY):
		return
	_sting.stream = load(VICTORY)
	_sting.play()
	_duck = 5.5


func _process(delta: float) -> void:
	_check_t -= delta
	if _check_t <= 0.0:
		_check_t = 0.5
		var want := override if override != "" else _pick(0.5)
		if want != current:
			play(want, want in ["combat", "boss"])
	_duck = maxf(_duck - delta, 0.0)
	var target := BASE_DB - (14.0 if _duck > 0.0 else 0.0)
	for p in [_a, _b]:
		var ap := p as AudioStreamPlayer
		if ap == _active and ap.playing:
			ap.volume_db = move_toward(ap.volume_db, target, 60.0 * _fade_rate * delta)
		elif ap.playing:
			ap.volume_db = move_toward(ap.volume_db, -60.0, 60.0 * _fade_rate * delta)
			if ap.volume_db <= -59.0:
				ap.stop()


## What fits right now.
func _pick(dt: float) -> String:
	var tree := get_tree()
	var cs := tree.current_scene
	if cs == null or tree.get_first_node_in_group("title_screen") != null:
		return "title"
	var me := tree.get_first_node_in_group("player") as Node3D
	if me == null:
		return current if current != "" else "title"
	var pos := me.global_position
	for b in tree.get_nodes_in_group("bosses"):
		if is_instance_valid(b) and b.has_method("in_combat") and b.in_combat() and (b as Node3D).global_position.distance_to(pos) < 55.0:
			_combat_hold = COMBAT_HOLD
			return "boss"
	var fighting := false
	for e in tree.get_nodes_in_group("enemies"):
		if is_instance_valid(e) and e.has_method("in_combat") and e.in_combat() and (e as Node3D).global_position.distance_to(pos) < 30.0:
			if not (e.has_method("is_dead") and e.is_dead()):
				fighting = true
				break
	if not fighting:
		for s in tree.get_nodes_in_group("enemy_ships"):
			if is_instance_valid(s) and s.in_combat() and (s as Node3D).global_position.distance_to(pos) < 170.0:
				fighting = true
				break
	if fighting:
		_combat_hold = COMBAT_HOLD
		return "combat"
	_combat_hold -= dt
	if _combat_hold > 0.0 and current == "combat":
		return "combat"
	var ctx = me.get("context")
	if ctx != null and int(ctx) != 0:
		return "sea"
	var ship := tree.get_first_node_in_group("ship") as Node3D
	if ship and pos.distance_to(ship.global_position) < 9.0 and absf(float(ship.get("speed"))) > 1.5:
		return "sea"
	# out on the open water, far from the home island
	if me.has_method("is_swimming") and me.is_swimming():
		return "sea" if current == "sea" else (current if current != "" else "island")
	var ec := EnemyShip.safe_center
	if Vector2(pos.x - ec.x, pos.z - ec.z).length() > EnemyShip.SAFE_RADIUS + 40.0:
		var near_fort := false
		for f in tree.get_nodes_in_group("forts"):
			if (f as Node3D).global_position.distance_to(pos) < 45.0:
				near_fort = true
		return "island" if near_fort else "sea"
	return "island"
