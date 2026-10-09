extends RefCounted
## How the HUD, the log pose and the sea chart show a chain island: its
## theme's colour and little icon, and how dangerous it is for a captain of
## a given level (easy / even / hard / deadly).

const NEEDLE_COLORS := [Color(0.92, 0.18, 0.14), Color(0.3, 0.55, 1.0)]
const THEME_COLORS := {
	"jungle": Color(0.3, 0.88, 0.45),
	"snow": Color(0.85, 0.95, 1.0),
	"desert": Color(1.0, 0.76, 0.32),
	"forest": Color(0.66, 0.78, 0.3),
}
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
	var c: Color = THEME_COLORS[theme]
	return c.darkened(0.5) if paper else c


## The theme's icon, about `s` px from its middle `p` to each edge.
static func icon(ci: CanvasItem, p: Vector2, theme: String, s: float, col: Color) -> void:
	match theme:
		"jungle":
			# a palm: a leaning trunk and fronds drooping off its top
			var top := p + Vector2(s * 0.3, -s * 0.6)
			ci.draw_line(p + Vector2(-s * 0.2, s), top, col, 1.0)
			for a in [-2.6, -1.9, -1.2, -0.5]:
				var tip := top + Vector2(cos(a), sin(a) + 0.9) * s * 0.75
				ci.draw_line(top, tip, col, 1.0)
		"snow":
			for i in range(3):
				var d := Vector2.from_angle(PI * 0.5 + i * PI / 3.0) * s
				ci.draw_line(p - d, p + d, col, 1.0)
		"desert":
			ci.draw_circle(p, s * 0.45, col)
			for i in range(8):
				var d := Vector2.from_angle(i * PI * 0.25)
				ci.draw_line(p + d * s * 0.65, p + d * s, col, 1.0)
		"forest":
			ci.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -s), p + Vector2(s * 0.7, s * 0.45), p + Vector2(-s * 0.7, s * 0.45)]), col)
			ci.draw_line(p + Vector2(0, s * 0.45), p + Vector2(0, s), col, 1.0)


## What the log pose points at for this screen's captain (none without one).
static func targets(gm: Node) -> Array:
	if gm.player == null or not is_instance_valid(gm.player) or not gm.player.has_log_pose():
		return []
	return gm.log_pose_targets()
