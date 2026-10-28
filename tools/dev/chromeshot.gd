extends SceneTree
## The whimsical menu chrome on one sheet (UIStyle / UIChrome): the night sky, the beam with its hanging signs and
## nameplate, parchment and slate panels, planks in every state, ribbons, rules, keycaps, the key board and the
## blackletter at 9 / 18 / 27, on the real menu canvas (PixelCanvas). Args: <out.png> [WxH] (default
## tools/dev/out/chrome.png at 1280x720, the 640x360 canvas; 1600x900 is the 800x450 one).
var out := "res://tools/dev/out/chrome.png"
var frames := 0
var sheet: Control
var t := 0.0


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		out = a[0]
	if a.size() > 1:
		var wh := a[1].split("x")
		DisplayServer.window_set_size(Vector2i(int(wh[0]), int(wh[1])))
		root.size = Vector2i(int(wh[0]), int(wh[1]))
	var host := Control.new()
	host.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(host)
	var pc = load("res://scripts/ui/pixel_canvas.gd").new()
	host.add_child(pc)
	sheet = Control.new()
	sheet.set_anchors_preset(Control.PRESET_FULL_RECT)
	sheet.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sheet.draw.connect(_draw_sheet)
	pc.ui.add_child(sheet)
	var vb := VBoxContainer.new()
	vb.position = Vector2(12, 40)
	vb.size = Vector2(190, 0)
	vb.add_theme_constant_override("separation", 4)
	var parch := PanelContainer.new()
	parch.add_theme_stylebox_override("panel", UIStyle.parchment())
	parch.custom_minimum_size = Vector2(190, 0)
	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", 4)
	parch.add_child(pv)
	pv.add_child(UIStyle.title("Katana", 18, true))
	pv.add_child(UIStyle.ribbon("Mastery 14 of 30"))
	pv.add_child(UIStyle.rule())
	var body := UIStyle.label("Big nodes come by themselves at their mastery level.", 12, UIStyle.PARCH_INK)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD
	body.custom_minimum_size = Vector2(160, 0)
	pv.add_child(body)
	pv.add_child(UIStyle.ribbon("Coming next", true))
	pv.add_child(UIStyle.key_hint("K", "CLOSE", true))
	vb.add_child(parch)
	pc.ui.add_child(vb)
	var slate := PanelContainer.new()
	slate.add_theme_stylebox_override("panel", UIStyle.panel())
	slate.position = Vector2(214, 40)
	var sv := VBoxContainer.new()
	sv.add_theme_constant_override("separation", 4)
	slate.add_child(sv)
	sv.add_child(UIStyle.title("Paused"))
	for s in ["Resume", "Options", "Quit to Title"]:
		sv.add_child(UIStyle.button(s, 120))
	var dis := UIStyle.button("Locked", 120)
	dis.disabled = true
	sv.add_child(dis)
	sv.add_child(HSeparator.new())
	var le := LineEdit.new()
	le.text = "Captain Wren"
	sv.add_child(le)
	var sl := HSlider.new()
	sl.custom_minimum_size = Vector2(120, 14)
	sl.value = 60
	sv.add_child(sl)
	sv.add_child(UIStyle.key_hint("TAB", "NEXT"))
	pc.ui.add_child(slate)


func _draw_sheet() -> void:
	var s := sheet.size
	UIStyle.draw_sky(sheet, Rect2(Vector2.ZERO, s), t)
	var tabs := [["Captain", UIStyle.tab_icon("crown")], ["Combat", UIStyle.tab_icon("swords")], ["Adventure", UIStyle.tab_icon("compass")],
		["Loadout", UIStyle.tab_icon("chest")], ["Powers", UIStyle.tab_icon("fruit")]]
	UIStyle.draw_topbar(sheet, s.x, tabs, 1, t, 12, 0.28)
	var x := 360.0
	var y := 44.0
	for k in ["plank", "plank_hover", "plank_pressed", "plank_dim"]:
		sheet.draw_style_box(UIStyle.chrome(k), Rect2(x, y, 70, 18))
		sheet.draw_string(UIStyle.SILK, Vector2(x + 6, y + 12), k.trim_prefix("plank_").to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 8,
			UIStyle.WOOD_INK if k in ["plank_hover", "plank_pressed"] else UIStyle.PARCH)
		y += 22.0
	sheet.draw_style_box(UIStyle.chrome("plank"), Rect2(x, y, 70, 18))
	sheet.draw_style_box(UIStyle.chrome("plank_focus"), Rect2(x, y, 70, 18))
	sheet.draw_string(UIStyle.SILK, Vector2(x + 6, y + 12), "FOCUS", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, UIStyle.PARCH)
	UIStyle.draw_ribbon(sheet, Vector2(450, 44), "Skill bar", true)
	UIStyle.draw_ribbon(sheet, Vector2(450, 62), "How it grows")
	UIStyle.draw_rule(sheet, Rect2(450, 80, 150, 7))
	UIStyle.draw_hints(sheet, Vector2(452, 104), [["ENTER", "BUY"], ["Q/E", "TAB"]], UIStyle.SILK)
	sheet.draw_style_box(UIStyle.chrome("paper"), Rect2(450, 114, 150, 30))
	sheet.draw_string(UIStyle.SILK, Vector2(458, 133), "PAPER TOOLTIP", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, UIStyle.PARCH_INK)
	sheet.draw_style_box(UIStyle.chrome("slate"), Rect2(450, 150, 150, 40))
	UIStyle.draw_coin(sheet, Vector2(470, 170), "30")
	UIStyle.draw_star(sheet, Vector2(500, 170), 7, UIChrome.TWINKLE, true)
	UIStyle.draw_star(sheet, Vector2(516, 170), 5, UIStyle.GILT)
	UIStyle.draw_title(sheet, Vector2(360, 230), "Driftwake 9", 9)
	UIStyle.draw_title(sheet, Vector2(360, 256), "Skill Trees 18", 18)
	UIStyle.draw_title(sheet, Vector2(360, 292), "Swimming 27", 27)
	UIStyle.draw_title(sheet, Vector2(520, 230), "on paper", 18, HORIZONTAL_ALIGNMENT_LEFT, -1, true)
	UIStyle.draw_board(sheet, s.y - UIChrome.BOARD_H, s.x, [["A/D", "WEAPON"], ["MOUSE", "INSPECT"], ["ENTER", "BUY A STEP"], ["K", "CLOSE"]])


func _process(d: float) -> bool:
	t += d
	frames += 1
	sheet.queue_redraw()
	if frames == 30:
		var path := ProjectSettings.globalize_path(out) if out.begins_with("res://") else out
		root.get_texture().get_image().save_png(path)
		print("saved ", path)
		quit()
	return false
