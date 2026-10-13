extends SceneTree
## The game's gilt frames (UIStyle.frame_image) as PNGs for the website's border-image rules
## (web/site/img/ui/, one image pixel per art pixel; style.css scales them 2x, pixelated), and a
## contact sheet of them 8x at tools/dev/out/palette/frames_x8.png.

const FRAMES := [
	["panel", UIStyle.BG, UIStyle.BORDER, "panel"],
	["btn", UIStyle.SUN, UIStyle.BORDER_DIM, "plank"],
	["btn-hover", UIStyle.HILITE, UIStyle.SUN, "plank"],
	["btn-down", UIStyle.SUN, UIStyle.BORDER_DIM, "pressed"],
	["chip", UIStyle.CORAL, UIStyle.BORDER_DIM, "plank"],
	["chip-hover", UIStyle.SUN, UIStyle.BORDER_DIM, "plank"],
	["plank", UIStyle.BG_DARK, UIStyle.BORDER_DIM, "plank"],
	["plank-hover", UIStyle.HILITE, UIStyle.SUN, "plank"],
	["page", UIStyle.CREAM, UIStyle.BORDER_DIM, "well"],
]


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://web/site/img/ui"))
	var sheet := Image.create(48 * 3, 48 * ceili(FRAMES.size() / 3.0), false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.3, 0.3, 0.3))
	for i in range(FRAMES.size()):
		var f: Array = FRAMES[i]
		var path := "res://web/site/img/ui/%s.png" % f[0]
		var img: Image = UIStyle.frame_image(f[1], f[2], f[3])
		img.save_png(path)
		sheet.blend_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i(48 * (i % 3) + 2, 48 * (i / 3) + 2))
		print("wrote ", path)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tools/dev/out/palette"))
	sheet.resize(sheet.get_width() * 8, sheet.get_height() * 8, Image.INTERPOLATE_NEAREST)
	sheet.save_png("res://tools/dev/out/palette/frames_x8.png")
	quit()
