class_name LifePools
extends RefCounted
## What a theme's people say and are called: names, the named characters' roles,
## ambient barks, rumours and quest texts. Tokens in {braces} are filled by
## IslandLife (fill). The table is the theme's (ThemeDef.life, e.g.
## scripts/island/themes/jungle_life.gd), read through the registry.


static func of(theme: String) -> Dictionary:
	return IslandThemes.of(theme).life


## `line` with each {token} replaced from `with`.
static func fill(line: String, with: Dictionary) -> String:
	for k in with.keys():
		line = line.replace("{%s}" % k, str(with[k]))
	return line
