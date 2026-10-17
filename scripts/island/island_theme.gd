class_name IslandTheme
extends RefCounted
## How a theme's islands are made (GenIsland): the land's shape and the plants and rocks on
## it, read from the theme's file through the registry (IslandThemes; ThemeDef.land says what
## the def holds). The chain only rolls registered themes.


static func has(theme: String) -> bool:
	return IslandThemes.has(theme)


static func def(theme: String) -> Dictionary:
	return IslandThemes.of(theme).land


## The meshes a theme's islands use, built once per theme (main thread, before GenIsland.prepare).
static var _meshes := {}


static func meshes(theme: String) -> Dictionary:
	if not _meshes.has(theme):
		_meshes[theme] = IslandThemes.of(theme).meshes()
	return _meshes[theme]
