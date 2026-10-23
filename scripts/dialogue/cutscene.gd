class_name Cutscene
extends Node
## A short staged scene (1.19's rival crews first, the intro, later story beats): a run of camera shots with lines
## spoken as subtitles in the letterbox (typewriter text with voice blips), the captain's control held. Skippable
## (Interact or Esc); in co-op every screen plays its own copy (Net._all_cutscene builds it from a kind and its args
## on each machine) and it's skipped once every captain has pressed skip (a "waiting for N more" chip).
##
## A shot (a Dictionary, every key optional):
##   "secs": 2.0                                    how long it holds (at least as long as its line takes)
##   "cam": [from, look]                            where the camera sits and what it looks at: a Vector3, or a
##                                                  Node3D (its position; for "from" plus "off" in its frame)
##   "off": Vector3(0, 1.6, -3)                     "from" relative to a node: right, up, forward (-Z) of it
##   "to": [from, look]                             where the camera eases to over the shot (a slow dolly)
##   "fov": 60.0
##   "say": {"who": Node3D, "name": "Vey", "text": "...", "pitch": 0.9}   a line, subtitled with its speaker's name
##   "act": [humanoid_holder, "action"]             an action played as the shot starts (Humanoid.play)
##   "call": Callable                               called as the shot starts
## All on game time (frames' delta), never the wall clock.

signal finished(skipped: bool)

## The scene playing, or null (brains, the HUD and control check it).
static var active: Cutscene = null

const CHARS_PER_S := 38.0
const LINE_HOLD := 1.1
const BAR := 0.15   # the letterbox bars, as a share of the screen's height (the bottom one holds the line)

var shots: Array = []
var kind := ""
var _i := -1
var _t := 0.0
var _len := 0.0
var _cam: Camera3D
var _prev_cam: Camera3D
var _from := [Vector3.ZERO, Vector3.FORWARD]
var _to := [Vector3.ZERO, Vector3.FORWARD]
var _bars: CanvasLayer
var _chip: Label
var _bubble: Label        # the line (a subtitle in the bottom bar)
var _name_tag: Label
var _speaker: Node3D
var _line := ""
var _shown := 0.0
var _blip: AudioStreamPlayer
var _pitch := 1.0
var _voted := false
var _done := false


## The shots of a scene by kind, built from `args` (node keys, names...) the same on every machine (co-op plays it
## through Net._all_cutscene). Kinds: "test" (args: [speaker key]: two shots and a line), "rival_meet" (RivalEncounter).
static func scripted(tree: SceneTree, kind: String, args: Array) -> Array:
	var net := tree.root.get_node_or_null("Net")
	match kind:
		"test":
			var who = net.node_of(str(args[0])) if net and args.size() > 0 else null
			return [
				{"secs": 1.2, "cam": [who, who], "off": Vector3(1.2, 1.7, 3.0)},
				{"secs": 1.0, "cam": [who, who], "off": Vector3(-0.8, 1.6, 2.2),
					"say": {"who": who, "name": "Test", "text": "Hold there, captain.", "pitch": 0.9}},
			]
		"rival_meet":
			return RivalEncounter.meet_shots(tree, args)
	return []


## Play `shots` here (single player, or one machine's copy in co-op). `kind` names it for co-op skip votes.
static func play(tree: SceneTree, shot_list: Array, kind_: String = "") -> Cutscene:
	if active and is_instance_valid(active):
		active.end(true)
	var c := Cutscene.new()
	c.name = "Cutscene"
	c.shots = shot_list
	c.kind = kind_
	tree.current_scene.add_child(c)
	return c


func _ready() -> void:
	active = self
	_prev_cam = get_viewport().get_camera_3d()
	_cam = Camera3D.new()
	_cam.name = "CutsceneCam"
	_cam.fov = 60.0
	if _prev_cam:
		_cam.cull_mask = _prev_cam.cull_mask
		_cam.environment = _prev_cam.environment
		_cam.attributes = _prev_cam.attributes
		_cam.global_transform = _prev_cam.global_transform
	add_child(_cam)
	_cam.make_current()
	_hold_captain(true)
	_build_ui()
	_next()


func _build_ui() -> void:
	_bars = CanvasLayer.new()
	_bars.layer = 50
	add_child(_bars)
	for top in [true, false]:
		var r := ColorRect.new()
		r.color = Color.BLACK
		r.anchor_left = 0.0
		r.anchor_right = 1.0
		r.anchor_top = 0.0 if top else 1.0 - BAR
		r.anchor_bottom = BAR if top else 1.0
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_bars.add_child(r)
	_chip = Label.new()
	_chip.anchor_left = 1.0
	_chip.anchor_right = 1.0
	_chip.anchor_top = 1.0
	_chip.anchor_bottom = 1.0
	_chip.offset_left = -300.0
	_chip.offset_right = -14.0
	_chip.offset_top = -30.0
	_chip.offset_bottom = -8.0
	_chip.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_chip.add_theme_color_override("font_color", Color(0.85, 0.82, 0.7))
	_chip.text = "F / Esc: skip"
	_bars.add_child(_chip)
	# the line as a subtitle in the bottom bar (a bubble over a head reads at play distance, not in a close-up)
	_name_tag = _label2d(13, Color(1.0, 0.78, 0.4), 1.0 - BAR + 0.012, 1.0 - BAR + 0.05)
	_bubble = _label2d(16, Color(1, 0.97, 0.88), 1.0 - BAR + 0.05, 1.0 - 0.012)
	_blip = AudioStreamPlayer.new()
	_blip.stream = load("res://assets/audio/blip.wav")
	_blip.volume_db = -10.0
	_blip.bus = "UI"
	add_child(_blip)


## A centred label across the screen between two heights (shares of the screen), in the bottom bar.
func _label2d(size: int, col: Color, top: float, bottom: float) -> Label:
	var l := Label.new()
	l.add_theme_font_override("font", load("res://assets/fonts/PixelifySans-Regular.woff2"))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.anchor_left = 0.12
	l.anchor_right = 0.88
	l.anchor_top = top
	l.anchor_bottom = bottom
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.visible = false
	_bars.add_child(l)
	return l


## The local captain's control (and every AI brain, which checks `active`) held while it plays.
func _hold_captain(on: bool) -> void:
	var p := get_tree().get_first_node_in_group("player")
	if p and p.get("input_locked") != null:
		p.set("input_locked", on)


func _next() -> void:
	_i += 1
	if _i >= shots.size():
		end(false)
		return
	var s: Dictionary = shots[_i]
	_t = 0.0
	_from = _resolve(s.get("cam", []), s.get("off", Vector3.ZERO))
	_to = _resolve(s.get("to", []), s.get("off", Vector3.ZERO)) if s.has("to") else _from
	if s.has("fov"):
		_cam.fov = float(s["fov"])
	_place(0.0)
	_say(s.get("say", {}))
	_len = maxf(float(s.get("secs", 2.0)), _line.length() / CHARS_PER_S + LINE_HOLD if _line != "" else 0.0)
	if s.has("act"):
		var a: Array = s["act"]
		var h = a[0].get("humanoid") if a[0].get("humanoid") != null else a[0].get("body_model")
		if h and is_instance_valid(h):
			h.play(str(a[1]))
	if s.has("call"):
		(s["call"] as Callable).call()


func _on_node(c) -> bool:
	return c is Array and (c as Array).any(func(v): return v is Node3D)


## [from, look] for a shot's "cam"/"to" (the current one held if it gives none).
func _resolve(c, off: Vector3) -> Array:
	if not (c is Array) or (c as Array).size() < 2:
		return [_cam.global_position, _cam.global_position - _cam.global_basis.z]
	return [_point(c[0], off), _point(c[1], Vector3.ZERO, true)]


func _point(v, off: Vector3, look := false) -> Vector3:
	if v is Node3D and is_instance_valid(v):
		var n := v as Node3D
		var b := n.global_basis.orthonormalized()
		var base := n.global_position + (Vector3(0, 1.45, 0) if look else Vector3.ZERO)
		return base + b.x * off.x + Vector3.UP * off.y - b.z * off.z
	return v if v is Vector3 else Vector3.ZERO


func _place(k: float) -> void:
	# a shot on a node follows it every frame (a deck rolling in a swell, a captain walking)
	var s: Dictionary = shots[_i] if _i >= 0 and _i < shots.size() else {}
	if _on_node(s.get("cam")) or _on_node(s.get("to")):
		_from = _resolve(s.get("cam", []), s.get("off", Vector3.ZERO))
		_to = _resolve(s.get("to", []), s.get("off", Vector3.ZERO)) if s.has("to") else _from
	var e := k * k * (3.0 - 2.0 * k)
	var from: Vector3 = (_from[0] as Vector3).lerp(_to[0], e)
	var look: Vector3 = (_from[1] as Vector3).lerp(_to[1], e)
	if from.distance_squared_to(look) < 0.0001:
		look = from + Vector3.FORWARD
	_cam.global_position = from
	_cam.look_at(look, Vector3.UP)


func _say(d: Dictionary) -> void:
	_line = str(d.get("text", ""))
	_shown = 0.0
	_speaker = d.get("who") as Node3D
	_pitch = float(d.get("pitch", 1.0))
	_bubble.visible = _line != ""
	_name_tag.visible = _line != "" and str(d.get("name", "")) != ""
	_name_tag.text = str(d.get("name", ""))
	_bubble.text = ""


func _process(delta: float) -> void:
	if _done:
		return
	_t += delta
	_place(clampf(_t / maxf(_len, 0.01), 0.0, 1.0))
	if _line != "":
		var prev := int(_shown)
		_shown = minf(_shown + delta * CHARS_PER_S, _line.length())
		if int(_shown) > prev:
			_bubble.text = _line.substr(0, int(_shown))
			if prev % 3 == 0 and _line[mini(int(_shown) - 1, _line.length() - 1)] != " ":
				_blip.pitch_scale = _pitch * randf_range(0.92, 1.08)
				_blip.play()
	if _t >= _len:
		_next()


func _unhandled_input(event: InputEvent) -> void:
	if _done or _voted or not event.is_pressed() or event.is_echo():
		return
	if event.is_action("interact") or event.is_action("ui_cancel") or event.is_action("pause"):
		get_viewport().set_input_as_handled()
		_voted = true
		var net := get_node_or_null("/root/Net")
		if net and net.active:
			net.cutscene_skip(kind)
			_chip.text = "Skip: waiting for the crew"
		else:
			end(true)


## Show how many captains still have to press skip (co-op).
func set_waiting(n: int) -> void:
	if _chip and _voted:
		_chip.text = "Skip: waiting for %d more" % n


func end(skipped: bool) -> void:
	if _done:
		return
	_done = true
	_hold_captain(false)
	if _prev_cam and is_instance_valid(_prev_cam):
		_prev_cam.make_current()
	if active == self:
		active = null
	finished.emit(skipped)
	queue_free()


func _exit_tree() -> void:
	if active == self:
		active = null
		_hold_captain(false)
