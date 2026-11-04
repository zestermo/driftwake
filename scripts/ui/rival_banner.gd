class_name RivalBanner
extends PanelContainer
## (1.30, docs/v1_30_plan.md "Rival crews") A rival crew's ship has anchored: their named banner slammed in across the
## upper middle of the HUD (their flag, the crew's name big, their captain and epithet, the captain's call-out), held a
## few seconds, gone. Every machine shows its own (Net._all_rival_arrive).

const HOLD := 4.5


class Flag extends Control:
	var colour := Color.WHITE

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, colour.darkened(0.55))
		draw_rect(r.grow(-2.0), colour)
		var bone := Color(0.95, 0.93, 0.86)
		var c := size * Vector2(0.5, 0.42)
		draw_line(c + Vector2(-9, 3), c + Vector2(9, 12), bone, 2.0)
		draw_line(c + Vector2(9, 3), c + Vector2(-9, 12), bone, 2.0)
		draw_circle(c, 5.0, bone)
		draw_rect(Rect2(c + Vector2(-3, 3), Vector2(6, 3)), bone)
		draw_circle(c + Vector2(-2, -0.5), 1.3, colour.darkened(0.6))
		draw_circle(c + Vector2(2, -0.5), 1.3, colour.darkened(0.6))


## Shows crew `crew`'s banner on the HUD with their captain's `callout` (null: no HUD here).
static func show_on(tree: SceneTree, crew: String, callout: String) -> RivalBanner:
	var hud := tree.get_first_node_in_group("hud")
	if hud == null:
		return null
	for old in tree.get_nodes_in_group("rival_banner"):
		old.queue_free()
	var b := RivalBanner.new()
	b.build(crew, callout)
	hud.add_child(b)
	b.play()
	return b


func build(crew: String, callout: String) -> void:
	name = "RivalBanner"
	add_to_group("rival_banner")
	var c: Dictionary = RivalCrews.crew(crew)
	add_theme_stylebox_override("panel", UIStyle.chrome("slate", 12, 8))
	set_anchors_preset(Control.PRESET_CENTER_TOP)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	offset_top = 140.0
	custom_minimum_size = Vector2(440, 0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 10)
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(hb)
	var flag := Flag.new()
	flag.name = "Flag"
	flag.colour = c["flag"]
	flag.custom_minimum_size = Vector2(44, 30)
	flag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(flag)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 1)
	hb.add_child(vb)
	var ep := UIStyle.label("A rival crew drops anchor", 8, UIStyle.TEXT_DIM)
	ep.name = "Kicker"
	vb.add_child(ep)
	var nm := UIStyle.title(str(c["name"]).to_upper(), 24)
	nm.name = "Name"
	nm.add_theme_color_override("font_color", (c["flag"] as Color).lerp(Color.WHITE, 0.35))
	vb.add_child(nm)
	var cap := UIStyle.label("Captain %s, %s" % [c["captain"], c["title"]], 12, UIStyle.TEXT)
	cap.name = "Captain"
	vb.add_child(cap)
	var say := UIStyle.label("\"%s\"" % callout, 12, Color(0.98, 0.82, 0.55))
	say.name = "Callout"
	say.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	say.custom_minimum_size = Vector2(360, 0)
	vb.add_child(say)


func play() -> void:
	modulate.a = 0.0
	pivot_offset = size * 0.5
	scale = Vector2(1.4, 1.4)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "modulate:a", 1.0, 0.2)
	tw.tween_property(self, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.chain().tween_interval(HOLD)
	tw.chain().tween_property(self, "modulate:a", 0.0, 0.6)
	tw.chain().tween_callback(queue_free)
