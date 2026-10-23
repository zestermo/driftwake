class_name WantedPoster
extends Node3D
## Wanted posters on a notice board (Bounty: from Wanted up): the most wanted captains' names and bounties, pinned
## over the board's papers. Empty (no meshes, no labels) until a captain is wanted, so a board looks as it always
## did before; it looks again every CHECK s (a captain's bounty only changes after a fight).

const CHECK := 2.0
const MAX := 2
const PAPER := Color(0.9, 0.78, 0.55)
const INK := Color(0.16, 0.11, 0.08)
const RED := Color(0.62, 0.1, 0.08)

var _t := CHECK
var _shown := ""


func _process(delta: float) -> void:
	_t += delta
	if _t < CHECK:
		return
	_t = 0.0
	var wanted := []
	for c in get_tree().get_nodes_in_group("players"):
		var b := int(c.get("bounty")) if c.get("bounty") != null else 0
		if Bounty.tier_of(b) >= 1:
			wanted.append([b, str(c.call("display_name")) if c.has_method("display_name") else "Captain"])
	wanted.sort_custom(func(a, b): return int(a[0]) > int(b[0]))
	wanted = wanted.slice(0, MAX)
	var key := str(wanted)
	if key == _shown:
		return
	_shown = key
	for ch in get_children():
		ch.queue_free()
	for i in range(wanted.size()):
		_poster(Vector3((float(i) - (wanted.size() - 1) * 0.5) * 0.62, 0.0, 0.0), str(wanted[i][1]), int(wanted[i][0]))


## One poster at `at` (the board's face): the paper, then WANTED, the name and the bounty.
func _poster(at: Vector3, who: String, b: int) -> void:
	var paper := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.52, 0.66)
	paper.mesh = q
	paper.material_override = PSXMat.flat(PAPER)
	paper.position = at
	paper.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	paper.visibility_range_end = 40.0
	add_child(paper)
	for l in [["WANTED", 0.22, 32, RED], [who, 0.02, 26, INK], [Bounty.fmt(b), -0.15, 30, INK], ["gold", -0.25, 18, INK]]:
		var lb := Label3D.new()
		lb.text = str(l[0])
		lb.font = load("res://assets/fonts/PixelifySans-Regular.woff2")
		lb.font_size = int(l[2])
		lb.pixel_size = 0.0035
		lb.modulate = l[3]
		lb.outline_size = 0
		lb.width = 140.0
		lb.autowrap_mode = TextServer.AUTOWRAP_OFF if l[0] == "WANTED" else TextServer.AUTOWRAP_WORD_SMART
		lb.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		lb.position = at + Vector3(0, float(l[1]), 0.004)
		lb.visibility_range_end = 25.0
		add_child(lb)
