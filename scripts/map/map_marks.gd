class_name MapMarks
extends RefCounted
## Marks other systems put on the held map (the tracked quest's goal, ...), on this screen only: call it
## on every machine that should show one. Drawn on the island page and on the sea chart (pinned to the
## chart's edge off it), in ink by kind:
##   "quest" - a red ring round a star (the tracked quest), "spot" - a small ring, "x" - an X.
## MapMarks.put("quest", world_position, "quest", "Find Morrow's ring"); MapMarks.clear("quest").

const KINDS := ["quest", "spot", "x"]
## id -> {"at": Vector2 (world x/z), "kind", "label"}
static var marks := {}


static func put(id: String, at: Vector3, kind := "quest", label := "") -> void:
	if not kind in KINDS:
		push_error("MapMarks.put: no kind \"%s\" (%s)" % [kind, KINDS])
		return
	marks[id] = {"at": Vector2(at.x, at.z), "kind": kind, "label": label}


static func clear(id: String) -> void:
	marks.erase(id)


static func has(id: String) -> bool:
	return marks.has(id)


## Every mark and where it goes on a page ([mark, page px]): `to_page` takes world x/z.
static func placed(to_page: Callable) -> Array:
	return marks.values().map(func(m): return [m, to_page.call(m["at"])])


## Each mark at `to_page.call(world x/z)` on `ci` (labels with `font`).
static func draw_all(ci: CanvasItem, to_page: Callable, font: Font) -> void:
	var red := Color(0.72, 0.14, 0.08)
	for e in placed(to_page):
		var m: Dictionary = e[0]
		var c: Vector2 = e[1]
		match str(m["kind"]):
			"quest":
				ci.draw_arc(c, 7.0, 0.0, TAU, 16, red, 2.0)
				var star := PackedVector2Array()
				for k in range(10):
					star.append(c + Vector2.from_angle(-PI * 0.5 + k * PI / 5.0) * (4.0 if k % 2 == 0 else 1.8))
				ci.draw_colored_polygon(star, red)
			"spot":
				ci.draw_arc(c, 4.0, 0.0, TAU, 12, red, 1.0)
			"x":
				ci.draw_line(c + Vector2(-4, -4), c + Vector2(4, 4), red, 2.0)
				ci.draw_line(c + Vector2(-4, 4), c + Vector2(4, -4), red, 2.0)
		if str(m["label"]) != "":
			ci.draw_string(font, c + Vector2(9, 3), str(m["label"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, red)
