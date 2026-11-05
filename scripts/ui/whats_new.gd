extends PanelContainer
## "What's new" on the title screen: the version's big changes. Shown by itself
## the first time a new version is opened (SEEN_FILE), and from the version
## ribbon or the menu after that.

const SEEN_FILE := "user://whats_new_seen.txt"

## [heading, line] for this version.
const NOTES := [
	["Menus on a controller", "A ring cursor you steer with the left stick in every menu (A clicks, X right-clicks), the D-pad and A/B work in menus and conversations, and ending a talk with A no longer makes you jump."],
	["Your keys", "Options > Controls lets you rebind every key and mouse button; prompts and the skill bar show your keys."],
	["Cleaner skill maps", "Every branch in its own lane with nothing overlapping, over a drifting pixel sea; menus sized better at 1080p."],
	["Slides and air", "Steep hills slide you on your own, stood up like surfing. Acrobatics now grows from jumps, air time, tall drops and blows struck mid-air."],
	["Fists and slingshot", "Shockwave Palm, Rising Dragon and Hundred Fists hit with more weight; the Diving Fist can't be spammed and finds its foe. The slingshot is held left-handed, in line with the camera, with a heavier draw."],
	["Fixes", "The lighthouse no longer leaves you stuck sideways, Bag of Tricks fires from the drawn band, and three axe moves play their own animations again."],
]


static func version() -> String:
	return str(ProjectSettings.get_setting("application/config/version", ""))


## Not yet seen for this version?
static func unseen() -> bool:
	if not FileAccess.file_exists(SEEN_FILE):
		return true
	return FileAccess.get_file_as_string(SEEN_FILE).strip_edges() != version()


static func mark_seen() -> void:
	var f := FileAccess.open(SEEN_FILE, FileAccess.WRITE)
	f.store_string(version())


signal closed

var _close: Button


func _init() -> void:
	custom_minimum_size = Vector2(400, 0)
	set_anchors_preset(Control.PRESET_CENTER)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	add_theme_stylebox_override("panel", UIStyle.panel())
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	add_child(vb)
	var t := UIStyle.title("What's new in v%s" % version())
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(t)
	var page := PanelContainer.new()
	page.add_theme_stylebox_override("panel", UIStyle.frame(UIStyle.CREAM, UIStyle.BORDER_DIM, 6, "well"))
	vb.add_child(page)
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(368, 226)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	page.add_child(sc)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 3)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(list)
	for n in NOTES:
		list.add_child(UIStyle.label(str(n[0]), 12, Color(UIStyle.BG, 1.0)))
		var l := UIStyle.label(str(n[1]), 8, UIStyle.INK)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD
		l.custom_minimum_size = Vector2(348, 0)
		list.add_child(l)
	_close = UIStyle.button("Set sail", 120)
	_close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_close.pressed.connect(func():
		visible = false
		mark_seen()
		closed.emit())
	vb.add_child(_close)


func show_notes() -> void:
	visible = true
	UIStyle.fit_to_screen.call_deferred(self)
	_close.call_deferred("grab_focus")
