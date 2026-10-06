extends Node
## Game settings (autoload "Settings"). Single source of truth for every option,
## persisted to user://settings.cfg. Other systems read values with get_value()
## and react to the `changed` signal.

signal changed(section: String, key: String, value: Variant)

const PATH := "user://settings.cfg"

const DEFAULTS := {
	"video": {
		"fullscreen": false,
		"psx_preset": 4,        # index into PSX.PRESETS (4 = 960x540, the default since v2)
		"dither": true,
		"wobble": 1.0,          # vertex snapping strength 0..1
		"warp": 0.0,            # affine texture warp 0..1 (off by default since v3)
		"fov": 75.0,
		"show_fps": false,
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
	},
	"gameplay": {
		"camera_shake": 1.0,    # 0..1 (was a toggle: saved true/false load as 1/0)
		"name_tags": true,
		"reticle": true,
	},
}

const BUSES := ["SFX", "Ambience", "UI", "Music"]

var _values: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_values = DEFAULTS.duplicate(true)
	_load()
	_ensure_buses()
	_apply_audio()


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
	# v2: 640x360 made distant things too hard to make out - move players who
	# never changed it to the sharper 960x540 grid (once)
	if int(cfg.get_value("meta", "version", 1)) < 2:
		if int(_values["video"]["psx_preset"]) == 0:
			_values["video"]["psx_preset"] = 4
	# v3: affine texture warp made textures slide with the camera - off unless
	# someone turned it up themselves
	if int(cfg.get_value("meta", "version", 1)) < 3:
		if absf(float(_values["video"]["warp"]) - 0.6) < 0.01:
			_values["video"]["warp"] = 0.0
		save()


const VERSION := 3


func _ensure_buses() -> void:
	for bus_name in BUSES:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			var idx := AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, "Master")


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
