class_name UIStyle
extends RefCounted
## Shared PSX UI look: dark panels with a gold pixel border (matches the dialogue box).

const BG := Color(0.04, 0.05, 0.09, 0.92)
const BG_LIGHT := Color(0.1, 0.11, 0.16, 0.95)
const BORDER := Color(0.86, 0.74, 0.45)
const BORDER_DIM := Color(0.45, 0.4, 0.28)
const TEXT := Color(0.95, 0.93, 0.86)
const TEXT_DIM := Color(0.62, 0.6, 0.55)
const ACCENT := Color(1.0, 0.85, 0.35)

static var _theme: Theme


static func box(bg: Color = BG, border: Color = BORDER, pad: int = 6, width: int = 2) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(width)
	sb.set_corner_radius_all(0)
	sb.content_margin_left = pad
	sb.content_margin_right = pad
	sb.content_margin_top = maxi(pad - 2, 0)
	sb.content_margin_bottom = maxi(pad - 2, 0)
	return sb


static func get_theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	# Ligatures off: Pixelify's "fi" ligature turns "Outfit" into "OutAt".
	var fv := FontVariation.new()
	fv.base_font = load("res://assets/fonts/PixelifySans-Regular.woff2")
	var ts := TextServerManager.get_primary_interface()
	fv.opentype_features = {ts.name_to_tag("liga"): 0, ts.name_to_tag("clig"): 0}
	t.default_font = fv
	t.default_font_size = 16
	t.set_color("font_color", "Label", TEXT)
	t.set_stylebox("panel", "Panel", box())
	t.set_stylebox("panel", "PanelContainer", box())
	# Buttons
	t.set_stylebox("normal", "Button", box(BG_LIGHT, BORDER_DIM, 8, 1))
	t.set_stylebox("hover", "Button", box(Color(0.2, 0.17, 0.1, 0.95), BORDER, 8, 1))
	t.set_stylebox("pressed", "Button", box(Color(0.3, 0.24, 0.12, 0.95), ACCENT, 8, 1))
	t.set_stylebox("focus", "Button", box(Color(0, 0, 0, 0), ACCENT, 8, 1))
	t.set_stylebox("disabled", "Button", box(BG, Color(0.25, 0.25, 0.25), 8, 1))
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", ACCENT)
	t.set_color("font_pressed_color", "Button", ACCENT)
	t.set_color("font_focus_color", "Button", ACCENT)
	t.set_color("font_disabled_color", "Button", Color(0.4, 0.4, 0.4))
	# Sliders
	var track := box(Color(0.02, 0.02, 0.03), BORDER_DIM, 0, 1)
	track.content_margin_top = 3
	track.content_margin_bottom = 3
	t.set_stylebox("slider", "HSlider", track)
	var fill := box(BORDER, BORDER, 0, 0)
	fill.content_margin_top = 3
	fill.content_margin_bottom = 3
	t.set_stylebox("grabber_area", "HSlider", fill)
	t.set_stylebox("grabber_area_highlight", "HSlider", fill)
	var grab := _square_icon(8, ACCENT, Color(0.2, 0.14, 0.05))
	t.set_icon("grabber", "HSlider", grab)
	t.set_icon("grabber_highlight", "HSlider", _square_icon(8, Color.WHITE, Color(0.2, 0.14, 0.05)))
	# Tooltips / separators
	t.set_stylebox("separator", "HSeparator", box(BORDER_DIM, BORDER_DIM, 0, 0))
	t.set_constant("separation", "HSeparator", 6)
	_theme = t
	return t


static func _square_icon(size: int, fill: Color, edge: Color) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(fill)
	for i in range(size):
		img.set_pixel(i, 0, edge)
		img.set_pixel(i, size - 1, edge)
		img.set_pixel(0, i, edge)
		img.set_pixel(size - 1, i, edge)
	return ImageTexture.create_from_image(img)


static func label(text: String, size: int = 16, color: Color = TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


static func title(text: String) -> Label:
	var l := label(text, 32, ACCENT)
	l.add_theme_font_override("font", load("res://assets/fonts/PixelifySans-SemiBold.woff2"))
	l.add_theme_color_override("font_outline_color", Color(0.1, 0.05, 0.02))
	l.add_theme_constant_override("outline_size", 6)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


static func button(text: String, min_width: float = 0.0) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(min_width, 0)
	b.focus_mode = Control.FOCUS_ALL
	return b
