class_name Jam
extends Node3D
## A captain's instrument on every machine (the Player's child "Jam", the puppets' too): carried on the back
## (the whistle in the belt) when worn, played from the emote wheel. Playing holds the body action
## "music_<kind>" (InstrumentPoses), puts the hands on the instrument by IK after each pose, and plays that
## instrument's stem of a tune (Instruments.TUNES) from a 3D player at the chest.
## The tune runs on the shared clock: where it is = (Net.time() - t0) mod its length. Alone, a captain picks a
## tune at random and starts it; with someone playing within JOIN_R, they take that tune and its t0 and fade
## in over FADE_BEATS at the same spot. Every machine plays every jammer's stem from that clock, so the band
## is in step on every screen; small drift is nudged out by pitch, a slip (a hitch) jumps on the next bar line.
## Moving, any other action (an attack, a dodge, drawing), a hit or a state change stops it.
## Co-op: Net.event "jam" [kind, tune, t0] / "stop", the jam resent every RESEND s (late joiners hear it).
## The Music bus ducks (an Amplify "JamDuck" on it) while you or a captain within DUCK_R plays.

const JOIN_R := 20.0
const DUCK_R := 30.0
const DUCK_DB := -12.0
const RESEND := 3.0
const FADE_BEATS := 2.0
const VOLUME_DB := -2.0
## Drift: nudged by pitch (at most PITCH_K) past NUDGE s, a jump on the next bar line past SLIP s.
const NUDGE := 0.012
const PITCH_K := 0.012
const SLIP := 0.15
const IK_IN := 0.3

## Carried, in torso space: [position, basis] per kind (pushed out past an axe on the back).
const BACK := {
	"concertina": [Vector3(0.0, 0.26, 0.2), Basis()],
	"fiddle": [Vector3(0.1, 0.02, 0.16), Basis(Vector3.BACK, 0.42) * Basis(Vector3.RIGHT, PI * 0.5)],
	"whistle": [Vector3(0.085, 0.15, -0.135), Basis(Vector3.BACK, 0.35) * Basis(Vector3.RIGHT, -PI * 0.5)],
	"bodhran": [Vector3(0.0, 0.34, 0.185), Basis(Vector3.BACK, 0.2)],
	"gurdy": [Vector3(0.02, 0.24, 0.185), Basis(Vector3.BACK, 0.5) * Basis(Vector3(0, -1, 0), Vector3(0, 0, 1), Vector3(-1, 0, 0))],
}

var player
var playing := false
var kind := ""
var tune := -1
var t0 := 0.0
var _audio: AudioStreamPlayer3D
var _len := 1.0
var _gain := 0.0
var _gain_rate := 1.0
var _resend := 0.0
var _w := 0.0
var _seek_at := -1.0
var _back: MeshInstance3D
var _parts: Dictionary = {}
var _built := ""
var _built_on: Node = null

static var _duck: AudioEffectAmplify


func _ready() -> void:
	process_priority = 10
	position = Vector3(0, 1.35, 0)
	_audio = AudioStreamPlayer3D.new()
	_audio.name = "Tune"
	_audio.bus = "SFX"
	_audio.unit_size = 8.0
	_audio.max_distance = 55.0
	_audio.volume_db = -80.0
	add_child(_audio)
	if player.is_local:
		player.hurtbox.hit_received.connect(func(_h, _a): stop())


func _exit_tree() -> void:
	if player.is_local and _duck:
		_duck.volume_db = 0.0


func _body() -> Humanoid:
	return player.body_model


## The instrument worn (its kind), "" for none.
func worn() -> String:
	var b := _body()
	var k := str(b.look.get("instrument", "none")) if b else "none"
	return "" if k == "none" else k


func can_play() -> bool:
	return worn() != "" and player.is_free() and player.is_on_floor() and not player.is_swimming()


func toggle() -> void:
	if playing:
		stop()
	else:
		start()


## Start playing (the local captain): a nearby jam's tune at its place, or a tune of our own.
func start() -> void:
	if playing or not can_play():
		return
	if player.armed:
		player.sheathe_weapon(true)
	var near := nearby_jam()
	var fade := 0.15
	if near:
		_begin(worn(), near.tune, near.t0)
		fade = beat_len() * FADE_BEATS
	else:
		_begin(worn(), randi() % Instruments.TUNES.size(), Net.time())
	_gain_rate = 1.0 / fade
	_body().hold("music_" + kind)
	_send()


func stop() -> void:
	if not playing:
		return
	_end()
	var b := _body()
	if b and b.current_action().begins_with("music_"):
		b.stop_action()
	if player.is_local:
		Net.event(self, "stop", [])


## The nearest captain within JOIN_R already playing (their Jam), or null.
func nearby_jam() -> Jam:
	var best: Jam = null
	var bd := JOIN_R
	for p in get_tree().get_nodes_in_group("players"):
		if p == player or not is_instance_valid(p):
			continue
		var j := (p as Node).get_node_or_null("Jam") as Jam
		var d := (p as Node3D).global_position.distance_to(player.global_position)
		if j and j.playing and d < bd:
			best = j
			bd = d
	return best


func _begin(k: String, tn: int, t: float) -> void:
	kind = k
	tune = tn
	t0 = t
	playing = true
	_w = 0.0
	_seek_at = -1.0
	_resend = RESEND
	var s: AudioStreamOggVorbis = load(Instruments.tune_path(tune, kind))
	s.loop = true
	_len = s.get_length()
	_audio.stream = s
	_audio.pitch_scale = 1.0
	_gain = 0.0
	_gain_rate = 1.0 / (beat_len() * FADE_BEATS)
	_audio.volume_db = -80.0
	_audio.play(where())


func _end() -> void:
	playing = false
	_gain_rate = 4.0


func _send() -> void:
	if player.is_local:
		Net.event(self, "jam", [kind, tune, t0])


func net_event(what: String, args: Array) -> void:
	match what:
		"jam":
			if not playing or kind != str(args[0]) or tune != int(args[1]) or absf(t0 - float(args[2])) > 0.001:
				_begin(str(args[0]), int(args[1]), float(args[2]))
		"stop":
			_end()


## Seconds into the tune now (the shared clock).
func where() -> float:
	return fposmod(Net.time() - t0, _len)


func tune_info() -> Array:
	return Instruments.TUNES[tune]


func bar_len() -> float:
	return _len / float(tune_info()[3])


func beat_len() -> float:
	return bar_len() / float(tune_info()[2])


## Beats since the tune began (the poses keep time with it).
func beats() -> float:
	return (Net.time() - t0) / beat_len()


func _process(delta: float) -> void:
	var b := _body()
	if b == null:
		return
	if playing and player.is_local and _interrupted(b):
		stop()
	var k := kind if playing else worn()
	_models(b, k)
	if playing:
		b.set_meta("jam_beat", beats())
		_w = minf(_w + delta / IK_IN, 1.0)
		_play_pose(b)
	elif _back:
		_place_back(b)
	_sound(delta)
	if playing and player.is_local:
		_resend -= delta
		if _resend <= 0.0:
			_resend = RESEND
			_send()
	if player.is_local:
		_duck_music(delta)


func _interrupted(b: Humanoid) -> bool:
	return b.current_action() != "music_" + kind or Vector2(player.velocity.x, player.velocity.z).length() > 0.5 \
		or not (player.current_state_name() in ["Idle", "Move"] and player.is_free()) or worn() != kind


# --------------------------------------------------------------------------
# Sound: the stem on the shared clock, faded in and out, kept in step
# --------------------------------------------------------------------------
func _sound(delta: float) -> void:
	var target := 1.0 if playing else 0.0
	_gain = move_toward(_gain, target, _gain_rate * delta)
	if _gain <= 0.0:
		if _audio.playing:
			_audio.stop()
		_audio.volume_db = -80.0
		return
	_audio.volume_db = VOLUME_DB + linear_to_db(maxf(_gain, 0.0001))
	if not playing or not _audio.playing:
		return
	var heard := _audio.get_playback_position() + AudioServer.get_time_since_last_mix()
	var err := wrapf(heard - where(), -_len * 0.5, _len * 0.5)
	if absf(err) > SLIP:
		# a slip: jump on the next bar line (where the music turns anyway)
		if _seek_at < 0.0:
			_seek_at = ceilf(where() / bar_len()) * bar_len()
		elif fposmod(where() - _seek_at, _len) < 0.25 * bar_len():
			_audio.seek(where())
			_seek_at = -1.0
		return
	_seek_at = -1.0
	_audio.pitch_scale = 1.0 - clampf(err * 0.5, -PITCH_K, PITCH_K) if absf(err) > NUDGE else 1.0


## The music ducks while a jam is on near you.
func _duck_music(delta: float) -> void:
	if _duck == null:
		var bus := AudioServer.get_bus_index("Music")
		if bus < 0:
			return
		_duck = AudioEffectAmplify.new()
		_duck.resource_name = "JamDuck"
		_duck.volume_db = 0.0
		AudioServer.add_bus_effect(bus, _duck)
	var on := false
	for p in get_tree().get_nodes_in_group("players"):
		var j := (p as Node).get_node_or_null("Jam") as Jam
		if j and j.playing and (p as Node3D).global_position.distance_to(player.global_position) < DUCK_R:
			on = true
	_duck.volume_db = move_toward(_duck.volume_db, DUCK_DB if on else 0.0, (24.0 if on else 8.0) * delta)


static func music_duck_db() -> float:
	return _duck.volume_db if _duck else 0.0


# --------------------------------------------------------------------------
# Models: on the back, or in the hands (placed in torso space, the hands IK'd onto them)
# --------------------------------------------------------------------------
func _models(b: Humanoid, k: String) -> void:
	if k == _built and _built_on == b.torso and (k == "" or is_instance_valid(_back)):
		_show(playing)
		return
	for n in [_back] + _parts.values():
		if n != null and is_instance_valid(n):
			(n as Node).queue_free()
	_back = null
	_parts.clear()
	_built = k
	_built_on = b.torso
	if k == "":
		return
	_back = MeshInstance3D.new()
	_back.name = "Carried"
	_back.mesh = Instruments.mesh(k)
	b.torso.add_child(_back)
	var names: Dictionary = {"concertina": {"end_r": "end", "end_l": "end", "bellows": "bellows"}, "fiddle": {"body": "", "bow": "bow"},
		"whistle": {"body": ""}, "bodhran": {"body": "", "tipper": "tipper"}, "gurdy": {"body": "body", "crank": "crank"}}[k]
	for pn in names.keys():
		var mi := MeshInstance3D.new()
		mi.name = "Played_" + pn
		mi.mesh = Instruments.mesh(k, names[pn])
		(b.head if k == "whistle" else b.torso).add_child(mi)
		_parts[pn] = mi
	_show(playing)


## Played, it's in the hands; carried, on the back unless the captain hides their equipment (look "equip_hidden").
func _show(held: bool) -> void:
	if _back:
		_back.visible = not held and not _body().look.get("equip_hidden", false)
	for n in _parts.values():
		(n as Node3D).visible = held


func _place_back(b: Humanoid) -> void:
	var e: Array = BACK[_built]
	var at: Vector3 = e[0]
	# an axe rides on the back too: hang it out over the axe's haft
	if _built != "whistle" and b.weapon and is_instance_valid(b.weapon) and b.weapon.get_parent() and b.weapon.get_parent().name == "BackSocket":
		at.z += 0.05
	_back.transform = Transform3D(e[1], at)


func _play_pose(b: Humanoid) -> void:
	var bt := beats()
	var sub := float(tune_info()[4])
	var tg := b.torso.global_transform
	var body_b := b.global_basis
	var pole_r := body_b * Vector3(1.0, -1.0, 0.3)
	var pole_l := body_b * Vector3(-1.0, -1.0, 0.3)
	match kind:
		"concertina":
			var bar := float(tune_info()[2])
			var open := 0.5 - 0.5 * cos(TAU * bt / bar)
			var bl := 0.085 + 0.08 * open
			var rock := Basis(Vector3.BACK, 0.1 * sin(PI * bt / bar))
			var c := Vector3(0, 0.31, -0.29)
			var half := bl * 0.5 + Instruments.END_W * 0.5
			_put("end_r", Transform3D(rock, c + rock * Vector3(half, 0, 0)))
			_put("end_l", Transform3D(rock * Basis(Vector3.UP, PI), c - rock * Vector3(half, 0, 0)))
			_put("bellows", Transform3D(rock * Basis().scaled(Vector3(bl, 1, 1)), c - rock * Vector3(bl * 0.5, 0, 0)))
			_reach(b, true, tg * (c + rock * Vector3(half + 0.035, -0.035, 0)), pole_r)
			_reach(b, false, tg * (c - rock * Vector3(half + 0.035, 0.035, 0)), pole_l)
		"fiddle":
			var fb := Basis.looking_at(Vector3(-0.55, 0.02, -0.83).normalized(), Vector3.UP) * Basis(Vector3.BACK, -0.45)
			var fx := Transform3D(fb, Vector3(-0.08, 0.46, -0.07))
			_put("body", fx)
			# down bow and up bow, a stroke a beat
			var tri := 1.0 - absf(fposmod(bt, 2.0) - 1.0)
			var s := 0.14 + 0.44 * tri
			var c := fx * Instruments.FIDDLE_BOWED
			var across := fb * Vector3(1.0, 0.35, 0.3).normalized()
			var frog := c + across * s
			_put("bow", Transform3D(Basis.looking_at(-across, fb * Vector3.UP), frog + fb * Vector3(0, -0.006, 0)))
			_reach(b, true, tg * frog, pole_r)
			var finger := 0.012 * sin(PI * floorf(bt * sub) * 1.7)
			_reach(b, false, tg * (fx * (Instruments.FIDDLE_STOP + Vector3(0, -0.03, finger))), body_b * Vector3(-0.3, -1.0, -0.2))
		"whistle":
			var wx := Transform3D(Basis.looking_at(Vector3(0, -0.5, -0.87).normalized(), Vector3(0, 0.87, -0.5)), Vector3(0, 0.06, -0.145))
			_put("body", wx)
			var hg := b.head.global_transform
			var lift := 0.004 * sin(PI * floorf(bt * sub) * 2.3)
			_reach(b, false, hg * (wx * Vector3(0, -0.018 + lift, -0.145)), pole_l)
			_reach(b, true, hg * (wx * Vector3(0, -0.018 - lift, -0.225)), pole_r)
		"bodhran":
			var n := Vector3(0.62, 0.0, -0.78).normalized()
			var db := Basis.looking_at(-n, Vector3.UP)
			var dx := Transform3D(db, Vector3(-0.2, 0.3, -0.25))
			_put("body", dx)
			# the tipper rocks in the wrist: one end down the skin, the other back up, a stroke a sub-beat
			var sp := fposmod(bt * sub, 2.0)
			var stroke := cos(PI * sp)
			var near := 1.0 - absf(sin(PI * sp))
			var g := Vector3(0.05, 0.07 * stroke, 0.075 + 0.05 * (1.0 - near))
			var tip := Basis(Vector3.BACK, 0.5 * stroke) * Basis(Vector3.UP, PI * 0.5) * Basis(Vector3.RIGHT, 0.35 * stroke)
			_put("tipper", Transform3D(db * tip, dx * g))
			_reach(b, true, tg * (dx * g), pole_r)
			_reach(b, false, tg * (dx * Vector3(-0.02, 0.04, -0.07)), body_b * Vector3(-1.0, -0.6, 0.6))
		"gurdy":
			var gb := Basis(Vector3.BACK, -0.15) * Basis(Vector3.RIGHT, -0.3)
			var gx := Transform3D(gb, Vector3(0.0, 0.12, -0.24))
			_put("body", gx)
			var turn := TAU * bt * 0.75
			_put("crank", gx * Transform3D(Basis(Vector3.RIGHT, turn), Instruments.CRANK_AT))
			_reach(b, true, tg * (gx * (Instruments.CRANK_AT + Basis(Vector3.RIGHT, turn) * Vector3(0.062, Instruments.CRANK_ARM, 0))), pole_r)
			var key := 0.035 * sin(PI * floorf(bt * sub) * 1.3)
			_reach(b, false, tg * (gx * (Instruments.KEYS_AT + Vector3(key, -0.01, -0.03))), body_b * Vector3(-0.6, -1.0, -0.4))


func _put(part: String, xf: Transform3D) -> void:
	(_parts[part] as Node3D).transform = xf


## The hand onto the instrument, eased in over IK_IN from where the pose put it.
func _reach(b: Humanoid, right: bool, target: Vector3, pole: Vector3) -> void:
	var hand := b.hand_r if right else b.hand_l
	b.reach_hand(right, hand.global_position.lerp(target, _w * _w * (3.0 - 2.0 * _w)), pole)
