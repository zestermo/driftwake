extends Node
## Game settings (autoload "Settings"). Single source of truth for every option,
## persisted to user://settings.cfg. Other systems read values with get_value()
## and react to the `changed` signal.

signal changed(section: String, key: String, value: Variant)

const PATH := "user://settings.cfg"

const DEFAULTS := {
	"video": {
		"fullscreen": false,
		"pixelate": true,       # the 3D on PSX.GRID (960x540); off = native resolution
		"dither": true,
		"wobble": 1.0,          # vertex snapping strength 0..1
		"warp": 0.0,            # affine texture warp 0..1 (off by default since v3)
		"fov": 75.0,
		"show_fps": false,
		"perf_overlay": false,  # F8
		"fine_ui": true,        # menus on a finer pixel canvas (960x540 at 1080p) where the window allows; off = 640x360
	},
	"audio": {
		"master": 0.8,
		"sfx": 1.0,
		"ambience": 0.8,
		"ui": 0.8,
		"music": 0.6,
	},
	"controls": {
		"mouse_sensitivity": 1.0,
		"invert_y": false,
		"pad_look_sensitivity": 1.0,
		"pad_look_deadzone": 0.15,
		"pad_move_deadzone": 0.2,
	},
	"gameplay": {
		"camera_shake": 1.0,    # 0..1 (was a toggle: saved true/false load as 1/0)
		"name_tags": true,
		"reticle": true,
		"pad_skills": true,    # on a pad: which skill is on which LB button, bottom left
	},
}

const BUSES := ["SFX", "Ambience", "UI", "Music"]

var _values: Dictionary = {}
var _deps


## Run by a test or tool (`--script res://tools/dev/...`: its own SceneTree is the main loop), not played.
static func tool_run() -> bool:
	return Engine.get_main_loop().get_script() != null


## Gameplay grabs the mouse; a test or render tool never does (it would lock the PC while it runs).
static func capture_mouse() -> void:
	if not tool_run():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _init() -> void:
	var out := OS.get_environment("DRIFTWAKE_DEPS_OUT")
	if out != "":
		_deps = load("res://scripts/game/dep_record.gd").new(out)


func _exit_tree() -> void:
	if _deps:
		_deps.write()
		_deps = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_values = DEFAULTS.duplicate(true)
	_load()
	_ensure_buses()
	_apply_audio()
	# a test or render tool with a window open must not blast the game's sound at whoever's at the PC
	if tool_run():
		AudioServer.set_bus_mute(0, true)
	# web: Ctrl+W closes the browser tab (no page can stop it), so dodge is C there (and crouch X, loadouts Y)
	if OS.has_feature("web"):
		var c := InputEventKey.new()
		c.physical_keycode = KEY_C
		InputMap.action_erase_events("dodge")
		InputMap.action_add_event("dodge", c)
		var x := InputEventKey.new()
		x.physical_keycode = KEY_X
		InputMap.action_erase_events("crouch")
		InputMap.action_add_event("crouch", x)
		var y := InputEventKey.new()
		y.physical_keycode = KEY_Y
		InputMap.action_erase_events("loadout")
		InputMap.action_add_event("loadout", y)


func get_value(section: String, key: String) -> Variant:
	return _values.get(section, {}).get(key, DEFAULTS.get(section, {}).get(key))


func set_value(section: String, key: String, value: Variant, save_now: bool = true) -> void:
	if not _values.has(section):
		_values[section] = {}
	if _values[section].get(key) == value:
		return
	_values[section][key] = value
	if section == "audio":
		_apply_audio()
	changed.emit(section, key, value)
	if save_now:
		save()


func reset_section(section: String) -> void:
	for key in DEFAULTS[section].keys():
		set_value(section, key, DEFAULTS[section][key], false)
	save()


func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "version", VERSION)
	for section in _values.keys():
		for key in _values[section].keys():
			cfg.set_value(section, key, _values[section][key])
	cfg.save(PATH)


func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	for section in cfg.get_sections():
		if not _values.has(section):
			continue
		for key in cfg.get_section_keys(section):
			if _values[section].has(key):
				var v = cfg.get_value(section, key)
				# keep the default's type (ConfigFile may hand back ints for floats)
				var d = DEFAULTS[section][key]
				if d is float:
					v = float(v)
				elif d is int:
					v = int(v)
				elif d is bool:
					v = bool(v)
				_values[section][key] = v
	# v3: affine texture warp made textures slide with the camera - off unless
	# someone turned it up themselves
	if int(cfg.get_value("meta", "version", 1)) < 3:
		if absf(float(_values["video"]["warp"]) - 0.6) < 0.01:
			_values["video"]["warp"] = 0.0
	# v4: the resolution presets became one pixelation toggle (every grid but "Off (native)", index 3, is on)
	if int(cfg.get_value("meta", "version", 1)) < 4:
		_values["video"]["pixelate"] = int(cfg.get_value("video", "psx_preset", 4)) != 3
		save()


const VERSION := 4


func _ensure_buses() -> void:
	for bus_name in BUSES:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			var idx := AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, "Master")
	# a broadside, a boss roar and the music together mustn't clip
	if AudioServer.get_bus_effect_count(0) == 0:
		var lim := AudioEffectHardLimiter.new()
		lim.ceiling_db = -0.5
		lim.release = 0.12
		AudioServer.add_bus_effect(0, lim)
	# the music dips a few dB under the loudest sounds near you (cannons, roars, big hits), not footsteps
	var mus := AudioServer.get_bus_index("Music")
	if AudioServer.get_bus_effect_count(mus) == 0:
		var duck := AudioEffectCompressor.new()
		duck.sidechain = &"SFX"
		duck.threshold = -12.0
		duck.ratio = 2.5
		duck.attack_us = 8000.0
		duck.release_ms = 450.0
		AudioServer.add_bus_effect(mus, duck)


func _apply_audio() -> void:
	_set_bus("Master", float(get_value("audio", "master")))
	_set_bus("SFX", float(get_value("audio", "sfx")))
	_set_bus("Ambience", float(get_value("audio", "ambience")))
	_set_bus("UI", float(get_value("audio", "ui")))
	_set_bus("Music", float(get_value("audio", "music")))


func _set_bus(bus_name: String, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx == -1:
		return
	AudioServer.set_bus_mute(idx, linear <= 0.001)
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(linear, 0.001)))
