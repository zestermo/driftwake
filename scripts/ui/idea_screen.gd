extends PanelContainer
## Suggest an idea (GameMenu screen "idea", from the pause menu): a QR of driftwake://idea?v=<version>&t=<seconds
## played> that the companion phone app opens as its Ideas form, filled in. Local only, the same for a co-op guest.

const QR := preload("res://scripts/ui/qr_code.gd")
## UI pixels per QR module.
const MODULE_PX := 5

var _qr: TextureRect
var _link: Label


func _init(back: Callable) -> void:
	set_anchors_preset(Control.PRESET_CENTER)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	add_theme_stylebox_override("panel", UIStyle.panel(UIStyle.BG, UIStyle.BORDER, 12))
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	add_child(vb)
	vb.add_child(UIStyle.title("Suggest an Idea"))
	_qr = TextureRect.new()
	_qr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_qr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_qr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_qr.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vb.add_child(_qr)
	var say := UIStyle.label("Scan with your phone to send an idea from the Driftwake app")
	say.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(say)
	_link = UIStyle.label("", 12, UIStyle.TEXT_DIM)
	_link.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(_link)
	var b := UIStyle.button("Back", 120)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(back)
	vb.add_child(b)


static func link() -> String:
	var version := str(ProjectSettings.get_setting("application/config/version"))
	var gm := (Engine.get_main_loop() as SceneTree).root.get_node("GameManager")
	return "driftwake://idea?v=%s&t=%d" % [version.uri_encode(), int(gm.play_time)]


## Redrawn on every open: the play time moves on.
func on_open() -> void:
	_link.text = link()
	var img := QR.image(QR.encode(_link.text))
	_qr.texture = ImageTexture.create_from_image(img)
	_qr.custom_minimum_size = Vector2(img.get_size() * MODULE_PX)
