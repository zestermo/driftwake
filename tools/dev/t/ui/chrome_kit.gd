extends SceneTree
## The whimsical chrome: every UIChrome kind is a 9-slice with hard pixel edges, the menus' theme uses it
## (slate panels, plank buttons, blackletter titles), and the tab bar returns a sign per tab, the active one lower.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var step := 0
var until := 0
var fails := 0
var probe: Control
var rects: Array = []


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self)


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			var soft := 0
			for kind in UIChrome.KINDS.keys():
				var sb: StyleBoxTexture = UIStyle.chrome(kind)
				var img: Image = sb.texture.get_image()
				for y in range(img.get_height()):
					for x in range(img.get_width()):
						var a := img.get_pixel(x, y).a
						if a > 0.0 and a < 0.3 and kind not in ["beam", "plank_focus", "parchment", "paper", "slate"]:
							soft += 1
				check("%s is a %dx%d 9-slice" % [kind, img.get_width(), img.get_height()], img.get_width() >= 8 and img.get_height() >= 3)
			check("no faint stray pixels in the solid kinds", soft == 0)
			var th: Theme = UIStyle.get_theme()
			check("panels are slate in rope", th.get_stylebox("panel", "PanelContainer") == UIStyle.panel())
			check("buttons are wooden planks", th.get_stylebox("normal", "Button") == UIStyle.chrome("plank", 5, 3))
			check("titles are blackletter", UIStyle.title("Paused").get_theme_font("font") == UIStyle.TITLE_FONT)
			for id in ["crown", "swords", "compass", "chest", "fruit"]:
				check("tab icon %s is 16 px" % id, UIStyle.tab_icon(id).get_size() == Vector2(16, 16))
			probe = Control.new()
			probe.set_anchors_preset(Control.PRESET_FULL_RECT)
			probe.draw.connect(func():
				rects = UIStyle.draw_topbar(probe, probe.size.x, [["Captain", UIStyle.tab_icon("crown")], ["Combat", UIStyle.tab_icon("swords")],
					["Adventure", UIStyle.tab_icon("compass")], ["Loadout", UIStyle.tab_icon("chest")]], 1, 0.0, 12, 0.3))
			root.add_child(probe)
			until = TK.wait_ticks(4)
		1:
			check("a sign per tab", rects.size() == 4)
			if rects.size() == 4:
				check("the active sign hangs lower", rects[1].position.y > rects[0].position.y and rects[1].position.y > rects[2].position.y)
				check("signs left to right without touching", rects[0].end.x < rects[1].position.x and rects[2].end.x < rects[3].position.x)
			return TK.done(fails)
	step += 1
	return false
