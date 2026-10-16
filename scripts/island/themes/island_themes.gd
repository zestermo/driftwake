class_name IslandThemes
extends RefCounted
## The island themes the game has (scripts/island/themes/<theme>_theme.gd, each a ThemeDef), the
## one place a theme is registered: a new theme is its file and its line in SCRIPTS, nothing in
## the hubs. One path per line, so two themes landing at once merge cleanly. The declared order
## is the chain's (Chain._pick_theme walks it), which is why it's a const and never a folder
## listing. Every theme is loaded and checked together on first use, which is on the main thread
## (Chain._build and IslandTheme.meshes come before any worker reads of()/all()).

const SCRIPTS := [
	"res://scripts/island/themes/jungle_theme.gd",
	"res://scripts/island/themes/snow_theme.gd",
]

static var _all: Array = []
static var _by_name := {}


## Every theme, in declared order.
static func all() -> Array:
	if _all.is_empty():
		_load()
	return _all


static func of(theme: String) -> ThemeDef:
	if _all.is_empty():
		_load()
	if not _by_name.has(theme):
		push_error("IslandThemes: no theme called %s (registered: %s)" % [theme, _by_name.keys()])
		return null
	return _by_name[theme]


static func has(theme: String) -> bool:
	if _all.is_empty():
		_load()
	return _by_name.has(theme)


static func _load() -> void:
	var loaded: Array = []
	var by := {}
	for path in SCRIPTS:
		var t: ThemeDef = load(path).new()
		var gaps := t.missing()
		if not gaps.is_empty():
			push_error("IslandThemes: theme %s (%s) leaves unset: %s" % [t.name if t.name != "" else "?", path, gaps])
			assert(false)
		if by.has(t.name):
			push_error("IslandThemes: two themes called %s (%s and %s)" % [t.name, path, (by[t.name] as ThemeDef).get_script().resource_path])
			assert(false)
		by[t.name] = t
		loaded.append(t)
	_by_name = by
	_all = loaded
