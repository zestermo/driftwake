extends RefCounted
## How the HUD, the log pose and the sea chart show a chain island: its
## theme's colour and little icon (ThemeDef.color, glyph), and how dangerous
## it is for a captain of a given level (easy / even / hard / deadly).

const NEEDLE_COLORS := [Color(0.92, 0.18, 0.14), Color(0.3, 0.55, 1.0)]
const DANGER := [
	["easy", Color(0.55, 0.9, 0.45)],
	["even", Color(0.95, 0.9, 0.5)],
	["hard", Color(1.0, 0.6, 0.25)],
	["deadly", Color(1.0, 0.3, 0.25)],
]


## [word, colour] for an island of level `isle_lv` to a captain of `my_lv`.
static func danger(isle_lv: int, my_lv: int) -> Array:
	var gap := isle_lv - my_lv
	if gap <= -2:
		return DANGER[0]
	if gap <= 2:
		return DANGER[1]
	if gap <= 5:
		return DANGER[2]
	return DANGER[3]


## The theme's colour; `paper` darkens it to read on the parchment chart.
static func theme_color(theme: String, paper: bool = false) -> Color:
	var c: Color = IslandThemes.of(theme).color
	return c.darkened(0.5) if paper else c


## The theme's icon, about `s` px from its middle `p` to each edge.
static func icon(ci: CanvasItem, p: Vector2, theme: String, s: float, col: Color) -> void:
	IslandThemes.of(theme).glyph.call(ci, p, s, col)


## What the log pose points at for this screen's captain (none without one).
static func targets(gm: Node) -> Array:
	if gm.player == null or not is_instance_valid(gm.player) or not gm.player.has_log_pose():
		return []
	return gm.log_pose_targets()
